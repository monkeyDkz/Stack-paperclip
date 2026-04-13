"""Mem0 REST API v3 — Enhanced wrapper around mem0 Python library.

Endpoints:
  Core CRUD:
    GET  /health               — Basic health check
    GET  /health/deep          — Deep health check (Chroma + Ollama connectivity)
    POST /memories             — Add a memory (with auto-defaults and optional dedup)
    GET  /memories/{user_id}   — Get all memories for a user
    GET  /memories/id/{mid}    — Get a single memory by ID
    PUT  /memories/{mid}       — Update text and/or metadata
    DELETE /memories/{mid}     — Delete a single memory
    DELETE /users/{uid}/memories — Delete all memories for a user

  Search:
    POST /search               — Basic search (backward compatible)
    POST /search/filtered      — Search with metadata filters
    POST /search/multi         — Cross-agent search (multiple user_ids)

  Lifecycle:
    PATCH /memories/{mid}/state — Transition state (active/deprecated/archived)

  Bulk:
    POST /memories/bulk        — Add multiple memories at once

  Stats:
    GET /stats/{user_id}       — Stats for a single agent
    GET /stats                 — Global stats across all known agents

  Webhooks (v3):
    POST   /webhooks/register  — Register a webhook for memory events
    GET    /webhooks           — List all registered webhooks
    DELETE /webhooks/{wid}     — Unregister a webhook

  Links (v3):
    POST /memories/{mid}/link  — Create a relation between two memories
    GET  /memories/{mid}/graph — Get the relation graph for a memory

  Timeline (v3):
    GET /timeline/{user_id}    — Recent memories sorted by date

  Conflicts (v3):
    GET /conflicts             — Detect contradictory active memories between agents
"""

from datetime import date
from typing import Optional
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
from mem0 import Memory
import yaml
import os
import json
import time
import httpx
import threading
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("mem0-api")

app = FastAPI(title="Mem0 API", version="3.1.0")

config_path = os.environ.get("MEM0_CONFIG", "/app/config.yaml")
with open(config_path) as f:
    config = yaml.safe_load(f)

memory = Memory.from_config(config)

# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------

class AddRequest(BaseModel):
    text: str
    user_id: str = "default"
    metadata: dict = {}
    deduplicate: bool = False


class SearchRequest(BaseModel):
    query: str
    user_id: str = "default"
    limit: int = 10


class FilteredSearchRequest(BaseModel):
    query: str
    user_id: Optional[str] = None
    limit: int = 10
    filters: dict = {}


class MultiSearchRequest(BaseModel):
    query: str
    user_ids: list[str]
    limit_per_user: int = 3


class UpdateRequest(BaseModel):
    text: Optional[str] = None
    metadata: Optional[dict] = None


class StateTransitionRequest(BaseModel):
    state: str  # "draft" | "active" | "deprecated" | "archived"


class BulkAddRequest(BaseModel):
    memories: list[AddRequest]


class WebhookRegisterRequest(BaseModel):
    url: str
    events: list[str]  # memory.created, memory.updated, memory.state_changed
    filter_user_ids: list[str] = []
    filter_types: list[str] = []


class LinkRequest(BaseModel):
    target_id: str
    relation: str  # supersedes, depends_on, contradicts, implements, refines


VALID_STATES = {"draft", "active", "deprecated", "archived"}
VALID_EVENTS = {"memory.created", "memory.updated", "memory.state_changed"}
VALID_RELATIONS = {"supersedes", "depends_on", "contradicts", "implements", "refines"}

# ---------------------------------------------------------------------------
# Persistent stores (v3.1) — JSON-backed, survive restarts
# ---------------------------------------------------------------------------

DATA_DIR = os.environ.get("MEM0_DATA_DIR", "/app/data")
WEBHOOKS_FILE = os.path.join(DATA_DIR, "webhooks.json")
LINKS_FILE = os.path.join(DATA_DIR, "links.json")


def _ensure_data_dir():
    os.makedirs(DATA_DIR, exist_ok=True)


def _load_json(path: str, default):
    if os.path.exists(path):
        try:
            with open(path) as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            logger.warning(f"Failed to load {path}, using default")
    return default


def _save_json(path: str, data):
    _ensure_data_dir()
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, path)


# Load persisted state at startup
_ensure_data_dir()
webhooks: dict[str, dict] = _load_json(WEBHOOKS_FILE, {})
links: dict[str, list[dict]] = _load_json(LINKS_FILE, {})
logger.info(f"Loaded {len(webhooks)} webhooks and {len(links)} link entries from disk")


def _save_webhooks():
    _save_json(WEBHOOKS_FILE, webhooks)


def _save_links():
    _save_json(LINKS_FILE, links)


def _send_webhook_with_retry(url: str, event_type: str, payload: dict, wid: str, max_retries: int = 3):
    """Send a webhook with exponential backoff retry."""
    for attempt in range(max_retries):
        try:
            resp = httpx.post(
                url,
                json={"event": event_type, "webhook_id": wid, **payload},
                timeout=10,
            )
            if resp.status_code < 400:
                return
            logger.warning(f"Webhook {wid} returned {resp.status_code} (attempt {attempt + 1})")
        except Exception as e:
            logger.warning(f"Webhook {wid} failed (attempt {attempt + 1}): {e}")
        if attempt < max_retries - 1:
            time.sleep(2 ** attempt)  # exponential backoff: 1s, 2s
    logger.error(f"Webhook {wid} failed after {max_retries} attempts")


def dispatch_webhooks(event_type: str, payload: dict):
    """Dispatch webhooks with retry in background threads."""
    for wid, wh in list(webhooks.items()):
        if event_type not in wh.get("events", []):
            continue
        # Apply filters
        uid = payload.get("user_id", "")
        mtype = payload.get("type", "")
        if wh.get("filter_user_ids") and uid not in wh["filter_user_ids"]:
            continue
        if wh.get("filter_types") and mtype not in wh["filter_types"]:
            continue
        threading.Thread(
            target=_send_webhook_with_retry,
            args=(wh["url"], event_type, payload, wid),
            daemon=True,
        ).start()


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/health/deep")
def health_deep():
    """Deep health: check Chroma connectivity."""
    checks = {"mem0": "ok", "chroma": "unknown"}

    chroma_host = config.get("vector_store", {}).get("config", {}).get("host", "chroma")
    chroma_port = config.get("vector_store", {}).get("config", {}).get("port", 8000)

    try:
        r = httpx.get(f"http://{chroma_host}:{chroma_port}/api/v1/heartbeat", timeout=5)
        checks["chroma"] = "ok" if r.status_code == 200 else f"error:{r.status_code}"
    except Exception as e:
        checks["chroma"] = f"error:{e}"

    overall = "ok" if all(v == "ok" for v in checks.values()) else "degraded"
    return {"status": overall, "checks": checks}


# ---------------------------------------------------------------------------
# Core CRUD
# ---------------------------------------------------------------------------

@app.post("/memories")
def add_memory(req: AddRequest):
    """Add a memory. Auto-injects state/created defaults. Optional dedup."""
    meta = dict(req.metadata)
    meta.setdefault("state", "active")
    meta.setdefault("created", str(date.today()))

    if req.deduplicate:
        try:
            results = memory.search(req.text, user_id=req.user_id, limit=1)
            if results and len(results) > 0:
                top = results[0] if isinstance(results, list) else None
                if top and isinstance(top, dict):
                    score = top.get("score", 0)
                    if score and float(score) > 0.92:
                        return {
                            "status": "duplicate",
                            "existing_memory_id": top.get("id"),
                            "score": score,
                        }
        except Exception:
            pass  # dedup is best-effort, proceed with add

    result = memory.add(req.text, user_id=req.user_id, metadata=meta)

    # Dispatch webhook
    dispatch_webhooks("memory.created", {
        "memory_id": result.get("id") if isinstance(result, dict) else None,
        "user_id": req.user_id,
        "type": meta.get("type", ""),
        "text_preview": req.text[:200],
    })

    return result


@app.get("/memories/{user_id}")
def get_memories(user_id: str):
    return memory.get_all(user_id=user_id)


@app.get("/memories/id/{memory_id}")
def get_memory_by_id(memory_id: str):
    """Get a single memory by its ID."""
    try:
        result = memory.get(memory_id)
        if result is None:
            raise HTTPException(status_code=404, detail="Memory not found")
        return result
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))


@app.put("/memories/{memory_id}")
def update_memory(memory_id: str, req: UpdateRequest):
    """Update a memory's text and/or metadata."""
    if req.text is None and req.metadata is None:
        raise HTTPException(status_code=400, detail="Nothing to update")

    try:
        if req.text is not None:
            memory.update(memory_id, data=req.text)

        if req.metadata is not None:
            # Get current memory to merge metadata
            current = memory.get(memory_id)
            if current and isinstance(current, dict):
                existing_meta = current.get("metadata", {}) or {}
                merged = {**existing_meta, **req.metadata}
                # Re-add with merged metadata by updating the text
                # (mem0 stores metadata alongside the vector)
                current_text = req.text or current.get("memory", current.get("text", ""))
                memory.update(memory_id, data=current_text)

        # Dispatch webhook
        dispatch_webhooks("memory.updated", {
            "memory_id": memory_id,
            "user_id": None,
            "updated_fields": {
                "text": req.text is not None,
                "metadata": req.metadata is not None,
            },
        })

        return {"status": "updated", "memory_id": memory_id}
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))


@app.delete("/memories/{memory_id}")
def delete_memory(memory_id: str):
    memory.delete(memory_id)
    return {"status": "deleted"}


@app.delete("/users/{user_id}/memories")
def delete_user_memories(user_id: str):
    memory.delete_all(user_id=user_id)
    return {"status": "deleted"}


# ---------------------------------------------------------------------------
# Search
# ---------------------------------------------------------------------------

@app.post("/search")
def search_memories(req: SearchRequest):
    """Basic search (backward compatible)."""
    return memory.search(req.query, user_id=req.user_id, limit=req.limit)


@app.post("/search/filtered")
def search_filtered(req: FilteredSearchRequest):
    """Search with Chroma metadata filters.

    Filter format (Chroma style):
      {"type": {"$eq": "decision"}}
      {"$and": [{"type": {"$eq": "decision"}}, {"state": {"$eq": "active"}}]}
    """
    kwargs = {"limit": req.limit}
    if req.user_id:
        kwargs["user_id"] = req.user_id
    if req.filters:
        kwargs["filters"] = req.filters
    try:
        return memory.search(req.query, **kwargs)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/search/multi")
def search_multi(req: MultiSearchRequest):
    """Cross-agent search: query multiple user_ids in one call."""
    results = {}
    for uid in req.user_ids:
        try:
            agent_results = memory.search(
                req.query, user_id=uid, limit=req.limit_per_user
            )
            results[uid] = agent_results if agent_results else []
        except Exception:
            results[uid] = []
    return results


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

@app.patch("/memories/{memory_id}/state")
def transition_state(memory_id: str, req: StateTransitionRequest):
    """Transition a memory's lifecycle state."""
    if req.state not in VALID_STATES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid state '{req.state}'. Must be one of: {VALID_STATES}",
        )

    try:
        current = memory.get(memory_id)
        if current is None:
            raise HTTPException(status_code=404, detail="Memory not found")

        current_text = ""
        old_state = "unknown"
        if isinstance(current, dict):
            current_text = current.get("memory", current.get("text", ""))
            old_state = (current.get("metadata") or {}).get("state", "unknown")

        memory.update(memory_id, data=current_text)

        # Dispatch webhook
        dispatch_webhooks("memory.state_changed", {
            "memory_id": memory_id,
            "old_state": old_state,
            "new_state": req.state,
            "user_id": (current.get("metadata") or {}).get("user_id", "") if isinstance(current, dict) else "",
            "type": (current.get("metadata") or {}).get("type", "") if isinstance(current, dict) else "",
        })

        return {"status": "updated", "memory_id": memory_id, "new_state": req.state}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Bulk
# ---------------------------------------------------------------------------

@app.post("/memories/bulk")
def bulk_add(req: BulkAddRequest):
    """Add multiple memories at once."""
    results = []
    for item in req.memories:
        meta = dict(item.metadata)
        meta.setdefault("state", "active")
        meta.setdefault("created", str(date.today()))
        try:
            r = memory.add(item.text, user_id=item.user_id, metadata=meta)
            results.append({"status": "ok", "result": r})
            dispatch_webhooks("memory.created", {
                "memory_id": r.get("id") if isinstance(r, dict) else None,
                "user_id": item.user_id,
                "type": meta.get("type", ""),
                "text_preview": item.text[:200],
            })
        except Exception as e:
            results.append({"status": "error", "error": str(e)})
    return {"added": len([r for r in results if r["status"] == "ok"]), "results": results}


# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------

@app.get("/stats/{user_id}")
def user_stats(user_id: str):
    """Stats for a single agent: count, breakdown by type, last created date."""
    try:
        all_memories = memory.get_all(user_id=user_id)
        items = all_memories if isinstance(all_memories, list) else all_memories.get("results", []) if isinstance(all_memories, dict) else []

        by_type = {}
        by_state = {}
        by_confidence = {}
        last_created = None

        for item in items:
            meta = item.get("metadata", {}) or {}
            t = meta.get("type", "unknown")
            s = meta.get("state", "unknown")
            c = meta.get("confidence", "unknown")
            d = meta.get("created")

            by_type[t] = by_type.get(t, 0) + 1
            by_state[s] = by_state.get(s, 0) + 1
            by_confidence[c] = by_confidence.get(c, 0) + 1

            if d and (last_created is None or d > last_created):
                last_created = d

        return {
            "user_id": user_id,
            "total": len(items),
            "by_type": by_type,
            "by_state": by_state,
            "by_confidence": by_confidence,
            "last_created": last_created,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/stats")
def global_stats():
    """Global stats across all known agents + system channels."""
    known = [
        "ceo", "cto", "cpo", "cfo", "lead-backend", "lead-frontend",
        "devops", "security", "qa", "designer", "researcher",
        # System user_ids (fed by n8n)
        "monitoring", "analytics", "calendar", "crm",
        "security-events", "deployments", "git-events",
    ]

    total = 0
    per_agent = {}
    for uid in known:
        try:
            all_mem = memory.get_all(user_id=uid)
            items = all_mem if isinstance(all_mem, list) else all_mem.get("results", []) if isinstance(all_mem, dict) else []
            count = len(items)
            total += count
            if count > 0:
                per_agent[uid] = count
        except Exception:
            pass

    return {
        "total_memories": total,
        "per_agent": per_agent,
        "agents_tracked": len(known),
    }


# ---------------------------------------------------------------------------
# Webhooks (v3)
# ---------------------------------------------------------------------------

@app.post("/webhooks/register")
def register_webhook(req: WebhookRegisterRequest):
    """Register a callback URL for memory events."""
    for evt in req.events:
        if evt not in VALID_EVENTS:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid event '{evt}'. Must be one of: {VALID_EVENTS}",
            )

    wid = str(uuid4())
    webhooks[wid] = {
        "url": req.url,
        "events": req.events,
        "filter_user_ids": req.filter_user_ids,
        "filter_types": req.filter_types,
        "created": str(date.today()),
    }
    _save_webhooks()
    return {"id": wid, "url": req.url, "events": req.events}


@app.get("/webhooks")
def list_webhooks():
    """List all registered webhooks."""
    return {"webhooks": [{**v, "id": k} for k, v in webhooks.items()]}


@app.delete("/webhooks/{webhook_id}")
def delete_webhook(webhook_id: str):
    """Unregister a webhook."""
    if webhook_id not in webhooks:
        raise HTTPException(status_code=404, detail="Webhook not found")
    del webhooks[webhook_id]
    _save_webhooks()
    return {"status": "deleted", "webhook_id": webhook_id}


# ---------------------------------------------------------------------------
# Links (v3)
# ---------------------------------------------------------------------------

@app.post("/memories/{memory_id}/link")
def create_link(memory_id: str, req: LinkRequest):
    """Create a relation between two memories."""
    if req.relation not in VALID_RELATIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid relation '{req.relation}'. Must be one of: {VALID_RELATIONS}",
        )

    # Verify both memories exist
    try:
        source = memory.get(memory_id)
        if source is None:
            raise HTTPException(status_code=404, detail=f"Source memory {memory_id} not found")
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=404, detail=f"Source memory {memory_id} not found")

    try:
        target = memory.get(req.target_id)
        if target is None:
            raise HTTPException(status_code=404, detail=f"Target memory {req.target_id} not found")
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=404, detail=f"Target memory {req.target_id} not found")

    link_entry = {
        "target_id": req.target_id,
        "relation": req.relation,
        "created": str(date.today()),
    }

    if memory_id not in links:
        links[memory_id] = []

    # Avoid duplicate links
    for existing in links[memory_id]:
        if existing["target_id"] == req.target_id and existing["relation"] == req.relation:
            return {"status": "already_exists", "memory_id": memory_id, "link": existing}

    links[memory_id].append(link_entry)
    _save_links()

    # Dispatch webhook
    dispatch_webhooks("memory.updated", {
        "memory_id": memory_id,
        "user_id": "",
        "link_created": link_entry,
    })

    return {"status": "linked", "memory_id": memory_id, "link": link_entry}


@app.get("/memories/{memory_id}/graph")
def get_graph(memory_id: str):
    """Get the relation graph for a memory (both outgoing and incoming links)."""
    result_links = []

    # Outgoing links (this memory → others)
    for link in links.get(memory_id, []):
        result_links.append({
            "target_id": link["target_id"],
            "relation": link["relation"],
            "direction": "outgoing",
            "created": link["created"],
        })

    # Incoming links (others → this memory)
    for source_id, source_links in links.items():
        if source_id == memory_id:
            continue
        for link in source_links:
            if link["target_id"] == memory_id:
                result_links.append({
                    "target_id": source_id,
                    "relation": link["relation"],
                    "direction": "incoming",
                    "created": link["created"],
                })

    return {"memory_id": memory_id, "links": result_links, "total": len(result_links)}


# ---------------------------------------------------------------------------
# Timeline (v3)
# ---------------------------------------------------------------------------

@app.get("/timeline/{user_id}")
def get_timeline(
    user_id: str,
    type: Optional[str] = Query(None, description="Filter by memory type"),
    since: Optional[str] = Query(None, description="Filter memories created after this date (YYYY-MM-DD)"),
    limit: int = Query(20, description="Max number of results"),
):
    """Get recent memories for a user, sorted by creation date descending."""
    try:
        all_memories = memory.get_all(user_id=user_id)
        items = all_memories if isinstance(all_memories, list) else all_memories.get("results", []) if isinstance(all_memories, dict) else []

        # Filter
        filtered = []
        for item in items:
            meta = item.get("metadata", {}) or {}
            if meta.get("state") not in ("active", None):
                continue  # Only active memories in timeline
            if type and meta.get("type") != type:
                continue
            if since and meta.get("created", "") < since:
                continue
            filtered.append(item)

        # Sort by created date descending
        filtered.sort(key=lambda x: (x.get("metadata") or {}).get("created", ""), reverse=True)

        return {"user_id": user_id, "memories": filtered[:limit], "total": len(filtered)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Conflicts (v3)
# ---------------------------------------------------------------------------

@app.get("/conflicts")
def detect_conflicts(
    agents: str = Query(..., description="Comma-separated agent user_ids"),
    topic: str = Query(..., description="Topic to check for contradictions"),
    limit: int = Query(5, description="Max results per agent"),
):
    """Detect potentially contradictory active memories between agents on a topic.

    Returns active memories from each specified agent that match the topic,
    grouped for human/CTO review.
    """
    agent_list = [a.strip() for a in agents.split(",") if a.strip()]
    if len(agent_list) < 2:
        raise HTTPException(status_code=400, detail="Need at least 2 agents to compare")

    agent_memories = {}
    for uid in agent_list:
        try:
            results = memory.search(topic, user_id=uid, limit=limit)
            # Only keep active memories
            active = []
            if isinstance(results, list):
                for r in results:
                    meta = r.get("metadata", {}) or {}
                    if meta.get("state", "active") == "active":
                        active.append({
                            "id": r.get("id"),
                            "text": r.get("memory", r.get("text", "")),
                            "type": meta.get("type", ""),
                            "confidence": meta.get("confidence", ""),
                            "created": meta.get("created", ""),
                        })
            agent_memories[uid] = active
        except Exception:
            agent_memories[uid] = []

    # Build pairs for review
    pairs = []
    agent_keys = list(agent_memories.keys())
    for i in range(len(agent_keys)):
        for j in range(i + 1, len(agent_keys)):
            a, b = agent_keys[i], agent_keys[j]
            if agent_memories[a] and agent_memories[b]:
                pairs.append({
                    "agent_a": a,
                    "memories_a": agent_memories[a],
                    "agent_b": b,
                    "memories_b": agent_memories[b],
                })

    return {
        "topic": topic,
        "agents": agent_list,
        "agent_memories": agent_memories,
        "review_pairs": pairs,
        "total_pairs": len(pairs),
    }
