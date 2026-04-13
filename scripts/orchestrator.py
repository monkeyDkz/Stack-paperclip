#!/usr/bin/env python3
"""
Paperclip Orchestrator v2 — Micro-task sequential agent execution.

5 consolidated agents (strategist, architect, developer, operator, creator)
replace the original 16. The orchestrator reads issues from Paperclip,
routes each to the right agent, runs it via `opencode run`, and
post-processes results to SiYuan + Mem0.

Usage:
    python3 orchestrator.py status              # Show issues + agents
    python3 orchestrator.py cascade             # Run up to 5 tasks
    python3 orchestrator.py cascade 10          # Run up to 10 tasks
    python3 orchestrator.py run                 # Daemon: cascade every 3 min
    python3 orchestrator.py run --interval 300  # Daemon: every 5 min
    python3 orchestrator.py route               # Show which agent handles each issue
"""

import json
import time
import subprocess
import urllib.request
import urllib.error
import urllib.parse
import http.cookiejar
import logging
import signal
import sys
import os
import re
import textwrap
from datetime import datetime, timezone


# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
GREEN = "\033[32m"
RED = "\033[31m"
YELLOW = "\033[33m"
BLUE = "\033[34m"
CYAN = "\033[36m"
BOLD = "\033[1m"
DIM = "\033[2m"
RESET = "\033[0m"


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
PAPERCLIP_URL = "http://localhost:8060"
COMPANY_ID = "7c6f8a64-083b-4ff3-a478-b523b0b87b0d"
ADMIN_EMAIL = "admin@paperclip.local"
ADMIN_PASSWORD = "paperclip-admin"
SIYUAN_URL = "http://localhost:6806"
SIYUAN_TOKEN = "paperclip-siyuan-token"
MEM0_URL = "http://localhost:8050"
PROMPT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "prompt-templates-v2")
LMS_BIN = os.path.expanduser("~/.lmstudio/bin/lms")

# Models
MODEL_GENERAL = "qwen/qwen3-30b-a3b-2507"
MODEL_CODE = "qwen3-coder-30b-a3b-instruct-mlx"

# Agent configuration
AGENT_CONFIG = {
    "strategist": {
        "model": MODEL_GENERAL,
        "lmstudio_model": f"lmstudio/{MODEL_GENERAL}",
        "keywords": ["strateg", "prd", "roadmap", "prioris", "budget", "decision",
                      "specs fonctionnelles", "business", "vision", "objectif", "kpi"],
        "prompt_file": "strategist.txt",
        "siyuan_notebook": "20260320194608-s5u2t4r",
        "siyuan_prefix": "strategist",
    },
    "architect": {
        "model": MODEL_GENERAL,
        "lmstudio_model": f"lmstudio/{MODEL_GENERAL}",
        "keywords": ["architect", "adr", "api", "schema", "database", "infra",
                      "stack", "review", "technique", "specs technique"],
        "prompt_file": "architect.txt",
        "siyuan_notebook": "20260320194608-hgogt71",
        "siyuan_prefix": "architect",
    },
    "developer": {
        "model": MODEL_CODE,
        "lmstudio_model": f"lmstudio/{MODEL_CODE}",
        "keywords": ["develop", "code", "implement", "fix", "bug", "test",
                      "frontend", "backend", "composant", "page", "refactor"],
        "prompt_file": "developer.txt",
        "siyuan_notebook": "20260320194608-hgogt71",
        "siyuan_prefix": "developer",
    },
    "operator": {
        "model": MODEL_GENERAL,
        "lmstudio_model": f"lmstudio/{MODEL_GENERAL}",
        "keywords": ["deploy", "docker", "ci/cd", "monitor", "securit", "backup",
                      "devops", "infra", "nginx", "pipeline", "cert"],
        "prompt_file": "operator.txt",
        "siyuan_notebook": "20260320194608-hgogt71",
        "siyuan_prefix": "operator",
    },
    "creator": {
        "model": MODEL_GENERAL,
        "lmstudio_model": f"lmstudio/{MODEL_GENERAL}",
        "keywords": ["design", "ux", "ui", "seo", "content", "marketing", "copy",
                      "sales", "growth", "wireframe", "persona", "redaction"],
        "prompt_file": "creator.txt",
        "siyuan_notebook": "20260320194608-s5u2t4r",
        "siyuan_prefix": "creator",
    },
}

# Old agent IDs -> new agent routing
OLD_AGENT_ROUTING = {
    "bd91f3cc-472e-4add-b480-1b1f4dabb042": "strategist",   # ceo
    "0d3160d7-6fea-4633-944a-0ca41210d8e2": "architect",     # cto
    "6b800922-3d71-4ddb-896c-bb20d81a4116": "strategist",    # cpo
    "44499293-c6bd-4b02-ad23-4274842e679f": "strategist",    # cfo
    "30388859-12b5-4907-8c77-c1fb2a520e78": "developer",     # lead-backend
    "45861453-a2e2-4044-94af-abffe6e72a54": "developer",     # lead-frontend
    "cf87ed4e-21a3-424a-b8d1-29e5436f643a": "operator",      # devops
    "882a767a-8295-4f35-9865-14a0142adb26": "operator",      # security
    "436026bf-b23c-4e0b-a952-94ad0a577fac": "developer",     # qa
    "c3146739-1ca8-455b-87cb-c5f8841ab5c2": "creator",       # designer
    "0400e565-6dc4-434c-be96-d8735eec4a2b": "architect",     # researcher
    "3ebd54af-e9b1-40db-94d5-2bb0824799f4": "creator",       # growth-lead
    "4626220e-c5b6-44b5-9f6c-eed11e64bee1": "creator",       # seo
    "b708cea0-22fa-44ca-92d8-c5cc033d2991": "creator",       # content-writer
    "049131ad-7030-4950-9dc2-ea09ba813f45": "strategist",    # data-analyst
    "ab8d419a-72b9-4b62-9b9f-c5d61bf8543e": "creator",       # sales
}

# Paperclip agent IDs used by each v2 agent (for wakeup compatibility)
AGENT_PAPERCLIP_IDS = {
    "strategist": "bd91f3cc-472e-4add-b480-1b1f4dabb042",  # CEO
    "architect":  "0d3160d7-6fea-4633-944a-0ca41210d8e2",  # CTO
    "developer":  "30388859-12b5-4907-8c77-c1fb2a520e78",  # lead-backend
    "operator":   "cf87ed4e-21a3-424a-b8d1-29e5436f643a",  # devops
    "creator":    "c3146739-1ca8-455b-87cb-c5f8841ab5c2",   # designer
}


# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
LOG_FILE = "/tmp/paperclip-orchestrator.log"


class ColorFormatter(logging.Formatter):
    LEVEL_COLORS = {
        logging.DEBUG: DIM,
        logging.INFO: GREEN,
        logging.WARNING: YELLOW,
        logging.ERROR: RED,
        logging.CRITICAL: f"{RED}{BOLD}",
    }

    def format(self, record: logging.LogRecord) -> str:
        ts = datetime.fromtimestamp(record.created).strftime("%H:%M:%S")
        color = self.LEVEL_COLORS.get(record.levelno, "")
        level = record.levelname.ljust(7)
        return f"{DIM}[{ts}]{RESET} {color}[{level}]{RESET} {record.getMessage()}"


class PlainFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        ts = datetime.fromtimestamp(record.created).strftime("%H:%M:%S")
        level = record.levelname.ljust(7)
        return f"[{ts}] [{level}] {record.getMessage()}"


def setup_logging() -> logging.Logger:
    logger = logging.getLogger("orchestrator")
    logger.setLevel(logging.DEBUG)

    if not logger.handlers:
        stdout_handler = logging.StreamHandler(sys.stdout)
        stdout_handler.setLevel(logging.INFO)
        stdout_handler.setFormatter(ColorFormatter())
        logger.addHandler(stdout_handler)

        file_handler = logging.FileHandler(LOG_FILE, encoding="utf-8")
        file_handler.setLevel(logging.DEBUG)
        file_handler.setFormatter(PlainFormatter())
        logger.addHandler(file_handler)

    return logger


log = setup_logging()


# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------
class PaperclipOrchestrator:

    def __init__(self) -> None:
        self._shutdown = False
        self._cookie_jar = http.cookiejar.CookieJar()
        self._opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self._cookie_jar)
        )
        self._current_model = None
        signal.signal(signal.SIGINT, self._handle_signal)
        signal.signal(signal.SIGTERM, self._handle_signal)

    # -- signal handling ----------------------------------------------------

    def _handle_signal(self, signum: int, frame) -> None:
        name = signal.Signals(signum).name
        log.warning(f"Received {name} -- shutting down gracefully")
        self._shutdown = True

    # -- HTTP layer ---------------------------------------------------------

    def _http_request(self, url: str, method: str = "GET",
                      data: dict | None = None,
                      headers: dict | None = None,
                      timeout: int = 120,
                      use_opener: bool = True) -> dict | list | None:
        """Low-level HTTP request. Returns parsed JSON or None."""
        hdrs = {"Content-Type": "application/json"}
        if headers:
            hdrs.update(headers)

        body = json.dumps(data).encode() if data is not None else None
        req = urllib.request.Request(url, data=body, headers=hdrs, method=method)

        try:
            if use_opener:
                resp = self._opener.open(req, timeout=timeout)
            else:
                resp = urllib.request.urlopen(req, timeout=timeout)
            raw = resp.read().decode("utf-8", errors="replace")
        except urllib.error.HTTPError as exc:
            raw_err = exc.read().decode("utf-8", errors="replace") if exc.fp else ""
            log.error(f"HTTP {method} {url} -> {exc.code}: {raw_err[:300]}")
            return None
        except (urllib.error.URLError, OSError) as exc:
            log.error(f"HTTP {method} {url} -> connection error: {exc}")
            return None

        if not raw.strip():
            return {}

        cleaned = re.sub(r'[\x00-\x1f\x7f]', ' ', raw)
        try:
            return json.loads(cleaned)
        except json.JSONDecodeError:
            log.error(f"HTTP {method} {url} -> invalid JSON ({len(raw)} bytes)")
            log.debug(f"Raw: {raw[:500]}")
            return None

    def api(self, method: str, path: str, data: dict | None = None) -> dict | list | None:
        """Paperclip API call with cookie auth."""
        url = f"{PAPERCLIP_URL}{path}"
        headers = {"Origin": PAPERCLIP_URL}
        return self._http_request(url, method, data, headers, use_opener=True)

    def login(self) -> bool:
        """Authenticate with Paperclip. Returns True on success."""
        log.info("Authenticating with Paperclip API...")
        result = self.api("POST", "/api/auth/sign-in/email", {
            "email": ADMIN_EMAIL,
            "password": ADMIN_PASSWORD,
        })
        if result is None:
            log.error("Login failed")
            return False
        log.info("Authenticated successfully")
        return True

    # -- issue management ---------------------------------------------------

    def get_issues(self, status: str = "todo,in_progress") -> list[dict]:
        """Return list of issues filtered by status."""
        path = f"/api/companies/{COMPANY_ID}/issues?status={status}"
        result = self.api("GET", path)
        if result is None:
            return []
        if isinstance(result, list):
            return result
        return result.get("issues", result.get("data", []))

    def update_issue(self, issue_id: str, data: dict) -> bool:
        """Update an issue. Returns True on success."""
        result = self.api("PATCH", f"/api/issues/{issue_id}", data)
        return result is not None

    # -- routing ------------------------------------------------------------

    def route_issue(self, issue: dict) -> str:
        """Determine which v2 agent should handle an issue."""
        # 1. Check assigneeAgentId against old agent mapping
        assignee_id = issue.get("assigneeAgentId") or issue.get("assigneeId")
        if not assignee_id and isinstance(issue.get("assignee"), dict):
            assignee_id = issue["assignee"].get("id")

        if assignee_id and assignee_id in OLD_AGENT_ROUTING:
            return OLD_AGENT_ROUTING[assignee_id]

        # 2. Keyword match on title + description
        text = (
            (issue.get("title", "") + " " + issue.get("description", ""))
            .lower()
        )

        best_agent = None
        best_score = 0

        for agent_name, config in AGENT_CONFIG.items():
            score = sum(1 for kw in config["keywords"] if kw in text)
            if score > best_score:
                best_score = score
                best_agent = agent_name

        if best_agent and best_score > 0:
            return best_agent

        # 3. Default
        return "strategist"

    # -- prompt building ----------------------------------------------------

    def build_prompt(self, agent_name: str, issue: dict) -> str:
        """Build the complete prompt for an agent by filling in the template."""
        config = AGENT_CONFIG[agent_name]
        prompt_path = os.path.join(PROMPT_DIR, config["prompt_file"])

        try:
            with open(prompt_path, "r", encoding="utf-8") as f:
                template = f.read()
        except FileNotFoundError:
            log.error(f"Prompt template not found: {prompt_path}")
            return ""

        title = issue.get("title", "No title")
        description = issue.get("description", "")
        issue_id = issue.get("id", "")

        task_description = f"{title}\n\n{description}" if description else title

        prompt = template.replace("{task_description}", task_description)
        prompt = prompt.replace("{task_title}", title)
        prompt = prompt.replace("{issue_id}", issue_id)

        return prompt

    # -- model management ---------------------------------------------------

    def ensure_model(self, model_name: str) -> bool:
        """Ensure the correct model is loaded in LM Studio."""
        if self._current_model == model_name:
            log.debug(f"Model {model_name} already loaded")
            return True

        log.info(f"Loading model: {model_name}")

        # Unload all models
        try:
            subprocess.run(
                [LMS_BIN, "unload", "--all"],
                capture_output=True, text=True, timeout=30,
            )
        except (subprocess.TimeoutExpired, FileNotFoundError) as exc:
            log.warning(f"lms unload failed: {exc}")

        # Load the new model
        try:
            result = subprocess.run(
                [LMS_BIN, "load", model_name, "-c", "65536", "--gpu", "max", "-y"],
                capture_output=True, text=True, timeout=120,
            )
            if result.returncode != 0:
                log.error(f"lms load failed: {result.stderr}")
                return False
        except (subprocess.TimeoutExpired, FileNotFoundError) as exc:
            log.error(f"lms load error: {exc}")
            return False

        # Wait for server to be ready (poll /v1/models)
        for attempt in range(30):
            try:
                resp = self._http_request(
                    "http://localhost:1234/v1/models",
                    method="GET", use_opener=False, timeout=5,
                )
                if resp and isinstance(resp, dict) and resp.get("data"):
                    self._current_model = model_name
                    log.info(f"Model {model_name} ready")
                    return True
            except Exception:
                pass
            time.sleep(2)

        log.error(f"Model {model_name} failed to become ready after 60s")
        return False

    # -- agent execution ----------------------------------------------------

    def run_agent(self, agent_name: str, issue: dict) -> dict:
        """
        Execute a micro-task via Paperclip:
        1. Swap model in LM Studio
        2. Update agent model in Paperclip
        3. Wake agent via Paperclip API
        4. Poll until done
        5. Return result (SiYuan + Mem0 handled by Paperclip hooks)
        """
        config = AGENT_CONFIG[agent_name]
        issue_title = issue.get("title", "untitled")
        issue_id = issue.get("id", "unknown")
        paperclip_agent_id = AGENT_PAPERCLIP_IDS.get(agent_name, "")
        start = time.time()

        log.info(f"{CYAN}[{agent_name}]{RESET} Starting: {issue_title}")

        if not paperclip_agent_id:
            log.error(f"No Paperclip agent ID for {agent_name}")
            return {"status": "error", "duration": 0, "output": "No agent ID",
                    "agent": agent_name, "issue_id": issue_id}

        # 1. Ensure correct model in LM Studio
        if not self.ensure_model(config["model"]):
            return {"status": "error", "duration": time.time() - start,
                    "output": "Failed to load model", "agent": agent_name,
                    "issue_id": issue_id}

        # 2. Update agent model in Paperclip
        lmstudio_model = config["lmstudio_model"]
        self.api("PATCH", f"/api/agents/{paperclip_agent_id}", {
            "adapterType": "opencode_local",
            "adapterConfig": {"model": lmstudio_model},
            "status": "idle",
        })

        # 3. Wake agent via Paperclip
        log.info(f"{CYAN}[{agent_name}]{RESET} Waking via Paperclip ({lmstudio_model})")
        wake_result = self.api("POST", f"/api/agents/{paperclip_agent_id}/wakeup", {
            "source": "on_demand",
            "triggerDetail": "manual",
            "reason": f"Cascade: {issue_title}",
            "issueId": issue_id,
            "contextSnapshot": {
                "issueId": issue_id,
                "issueTitle": issue_title,
                "issueDescription": issue.get("description", ""),
            },
        })

        if not wake_result or not wake_result.get("id"):
            log.error(f"{CYAN}[{agent_name}]{RESET} Wakeup failed: {wake_result}")
            return {"status": "error", "duration": time.time() - start,
                    "output": f"Wakeup failed: {wake_result}", "agent": agent_name,
                    "issue_id": issue_id}

        run_id = wake_result.get("id", "?")
        log.info(f"{CYAN}[{agent_name}]{RESET} Run {run_id[:8]}... started")

        # 4. Poll until agent is done (max 600s)
        max_wait = 600
        poll_interval = 10
        while True:
            elapsed = time.time() - start
            if elapsed > max_wait:
                log.error(f"{CYAN}[{agent_name}]{RESET} Timeout after {elapsed:.0f}s")
                # Force reset
                self.api("PATCH", f"/api/agents/{paperclip_agent_id}", {"status": "idle"})
                return {"status": "timeout", "duration": elapsed,
                        "output": "Timeout", "agent": agent_name, "issue_id": issue_id}

            time.sleep(poll_interval)
            agent_data = self.api("GET", f"/api/agents/{paperclip_agent_id}")
            if not agent_data:
                continue
            agent_status = agent_data.get("status", "unknown")

            if agent_status == "idle":
                duration = time.time() - start
                log.info(f"{GREEN}[{agent_name}]{RESET} Completed in {duration:.0f}s")
                return {"status": "done", "duration": duration,
                        "output": f"Run {run_id} succeeded", "agent": agent_name,
                        "issue_id": issue_id}

            if agent_status == "error":
                duration = time.time() - start
                log.error(f"{RED}[{agent_name}]{RESET} Error after {duration:.0f}s")
                return {"status": "error", "duration": duration,
                        "output": f"Run {run_id} failed", "agent": agent_name,
                        "issue_id": issue_id}

            if self._shutdown:
                return {"status": "cancelled", "duration": time.time() - start,
                        "output": "Shutdown", "agent": agent_name, "issue_id": issue_id}

    # -- post-processing ----------------------------------------------------

    def _slugify(self, text: str) -> str:
        """Convert text to a URL-safe slug."""
        slug = text.lower().strip()
        slug = re.sub(r'[^a-z0-9\s-]', '', slug)
        slug = re.sub(r'[\s]+', '-', slug)
        slug = re.sub(r'-+', '-', slug)
        return slug[:60].strip('-')

    def _write_siyuan(self, agent_name: str, issue: dict,
                       result: dict) -> bool:
        """Write a summary document to SiYuan. Returns True on success."""
        config = AGENT_CONFIG[agent_name]
        notebook = config["siyuan_notebook"]
        prefix = config["siyuan_prefix"]

        title = issue.get("title", "untitled")
        date_str = datetime.now().strftime("%Y-%m-%d")
        slug = self._slugify(title)
        path = f"/{prefix}/{date_str}-{slug}"

        duration = result.get("duration", 0)
        output_summary = (result.get("output", "") or "")[:2000]

        markdown = textwrap.dedent(f"""\
            # {title}

            ## Agent: {agent_name}
            ## Status: {result.get('status', 'unknown')}
            ## Duration: {duration:.0f}s

            ## Result
            {output_summary}
        """)

        # Login to SiYuan via curl (cookie-based auth)
        cookie_file = "/tmp/siyuan-orchestrator.txt"
        try:
            login = subprocess.run(
                ["curl", "-sf", "-X", "POST",
                 f"{SIYUAN_URL}/api/system/loginAuth",
                 "-H", "Content-Type: application/json",
                 "-c", cookie_file,
                 "-d", json.dumps({"authCode": SIYUAN_TOKEN})],
                capture_output=True, text=True, timeout=10,
            )
            if login.returncode != 0:
                log.warning("SiYuan login failed")
                return False
        except Exception as exc:
            log.warning(f"SiYuan login error: {exc}")
            return False

        # Create document with cookie
        try:
            doc = subprocess.run(
                ["curl", "-sf", "-X", "POST",
                 f"{SIYUAN_URL}/api/filetree/createDocWithMd",
                 "-H", "Content-Type: application/json",
                 "-b", cookie_file,
                 "-d", json.dumps({
                     "notebook": notebook,
                     "path": path,
                     "markdown": markdown,
                 })],
                capture_output=True, text=True, timeout=10,
            )
            if doc.returncode != 0:
                log.warning(f"SiYuan doc creation failed for {path}")
                return False
        except Exception as exc:
            log.warning(f"SiYuan doc error: {exc}")
            return False

        log.info(f"SiYuan doc created: {path}")
        return True

    def _write_mem0(self, agent_name: str, issue: dict,
                     result: dict) -> bool:
        """Write a memory to Mem0. Returns True on success."""
        title = issue.get("title", "untitled")
        status = result.get("status", "unknown")
        duration = result.get("duration", 0)

        text = f"TASK {status.upper()}: {title} (duration: {duration:.0f}s)"

        resp = self._http_request(
            f"{MEM0_URL}/memories",
            method="POST",
            data={
                "text": text,
                "user_id": agent_name,
                "metadata": {
                    "type": "task_result",
                    "project": "site-agence",
                    "issue_id": issue.get("id", ""),
                    "status": status,
                },
            },
            use_opener=False,
        )

        if resp is None:
            log.warning("Mem0 write failed")
            return False

        log.debug(f"Mem0 memory saved for {agent_name}")
        return True

    def post_process(self, agent_name: str, issue: dict, result: dict) -> None:
        """After agent completes: SiYuan + Mem0 + update issue status."""
        issue_id = issue.get("id", "")

        # 1. Write to SiYuan
        self._write_siyuan(agent_name, issue, result)

        # 2. Write to Mem0
        self._write_mem0(agent_name, issue, result)

        # 3. Update issue status
        if result.get("status") == "done":
            output_preview = (result.get("output", "") or "")[:200]
            self.update_issue(issue_id, {
                "status": "done",
                "comment": f"[orchestrator-v2] {agent_name} completed. {output_preview}",
            })
            log.info(f"Issue {issue_id} marked done")
        elif result.get("status") in ("error", "timeout"):
            self.update_issue(issue_id, {
                "status": "todo",
                "comment": f"[orchestrator-v2] {agent_name} failed: {result.get('status')}. Will retry.",
            })
            log.warning(f"Issue {issue_id} kept as todo (agent failed)")

    # -- cascade ------------------------------------------------------------

    def run_cascade(self, max_tasks: int = 5) -> dict:
        """
        Main cascade loop:
        1. Get all todo issues sorted by priority
        2. For each (up to max_tasks):
           a. route_issue -> determine agent
           b. run_agent -> execute
           c. post_process -> SiYuan + Mem0 + mark done
        """
        cascade_start = time.time()
        tasks_completed = []
        tasks_failed = []

        log.info(f"{BOLD}{BLUE}=== CASCADE v2 START (max_tasks={max_tasks}) ==={RESET}")

        # Get todo issues
        issues = self.get_issues("todo")
        if not issues:
            log.info("No todo issues found. Nothing to do.")
            return self._cascade_summary(cascade_start, tasks_completed, tasks_failed)

        log.info(f"Found {len(issues)} todo issue(s)")

        # Process up to max_tasks
        for i, issue in enumerate(issues[:max_tasks]):
            if self._shutdown:
                log.warning("Shutdown requested, stopping cascade")
                break

            title = issue.get("title", "untitled")
            issue_id = issue.get("id", "unknown")

            # Route
            agent_name = self.route_issue(issue)
            log.info(f"{BOLD}[{i+1}/{min(len(issues), max_tasks)}]{RESET} "
                     f"{title} -> {CYAN}{agent_name}{RESET}")

            # Execute
            result = self.run_agent(agent_name, issue)

            # Post-process
            self.post_process(agent_name, issue, result)

            if result["status"] == "done":
                tasks_completed.append((agent_name, title, result["duration"]))
            else:
                tasks_failed.append((agent_name, title, result["status"]))

            log.info("")

        return self._cascade_summary(cascade_start, tasks_completed, tasks_failed)

    def _cascade_summary(self, start: float, completed: list, failed: list) -> dict:
        total = time.time() - start
        log.info(f"{BOLD}{BLUE}=== CASCADE v2 COMPLETE ==={RESET}")
        log.info(f"  Duration:   {total:.0f}s ({total / 60:.1f}min)")
        log.info(f"  Completed:  {len(completed)}")
        for agent, title, dur in completed:
            log.info(f"    {GREEN}{agent}{RESET}: {title} ({dur:.0f}s)")
        if failed:
            log.info(f"  Failed:     {len(failed)}")
            for agent, title, status in failed:
                log.info(f"    {RED}{agent}{RESET}: {title} ({status})")
        return {
            "duration": total,
            "completed": completed,
            "failed": failed,
        }

    # -- daemon loop --------------------------------------------------------

    def run_loop(self, interval: int = 180) -> None:
        """Infinite loop: cascade, sleep, repeat."""
        log.info(f"{BOLD}Orchestrator v2 daemon starting{RESET} (interval={interval}s)")

        while not self._shutdown:
            try:
                self.run_cascade()
            except Exception:
                log.exception("Cascade error (will retry next cycle)")

            # Interruptible sleep
            log.info(f"Sleeping {interval}s until next cascade...")
            sleep_end = time.time() + interval
            while time.time() < sleep_end and not self._shutdown:
                time.sleep(1)

        log.info("Orchestrator stopped")

    # -- display commands ---------------------------------------------------

    def show_status(self) -> None:
        """Show all todo/in_progress issues with their routed agent."""
        issues = self.get_issues("todo,in_progress")

        print(f"\n{BOLD}{'Status':<14} {'Agent':<14} {'Title'}{RESET}")
        print("-" * 72)

        if not issues:
            print("  (no issues found)")
        else:
            for issue in issues:
                status = issue.get("status", "?")
                title = issue.get("title", "untitled")[:50]
                agent = self.route_issue(issue)

                if status == "todo":
                    sc = YELLOW
                elif status == "in_progress":
                    sc = CYAN
                else:
                    sc = ""

                print(f"  {sc}{status:<12}{RESET} {CYAN}{agent:<12}{RESET} {title}")

        print(f"\n  Total: {len(issues)} issue(s)\n")

    def show_routes(self) -> None:
        """Show routing table: which agent handles each issue."""
        issues = self.get_issues("todo,in_progress")

        # Group by agent
        by_agent: dict[str, list[str]] = {name: [] for name in AGENT_CONFIG}

        for issue in issues:
            agent = self.route_issue(issue)
            title = issue.get("title", "untitled")
            by_agent[agent].append(title)

        print(f"\n{BOLD}Issue Routing (v2){RESET}")
        print("-" * 60)

        for agent_name in AGENT_CONFIG:
            titles = by_agent[agent_name]
            model = AGENT_CONFIG[agent_name]["model"]
            print(f"\n  {CYAN}{BOLD}{agent_name}{RESET} ({model})")
            if titles:
                for t in titles:
                    print(f"    - {t[:55]}")
            else:
                print(f"    {DIM}(no issues){RESET}")

        print()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main() -> None:
    args = sys.argv[1:]

    if not args or args[0] in ("-h", "--help", "help"):
        print(__doc__)
        sys.exit(0)

    command = args[0]
    orch = PaperclipOrchestrator()

    # Login for all commands
    if not orch.login():
        log.error("Cannot proceed without authentication")
        sys.exit(1)

    if command == "status":
        orch.show_status()

    elif command == "cascade":
        max_tasks = 5
        if len(args) > 1:
            try:
                max_tasks = int(args[1])
            except ValueError:
                log.error(f"Invalid max_tasks: {args[1]}")
                sys.exit(1)
        orch.run_cascade(max_tasks=max_tasks)

    elif command == "run":
        interval = 180
        if "--interval" in args:
            idx = args.index("--interval")
            if idx + 1 < len(args):
                try:
                    interval = int(args[idx + 1])
                except ValueError:
                    log.error(f"Invalid interval: {args[idx + 1]}")
                    sys.exit(1)
        orch.run_loop(interval=interval)

    elif command == "route":
        orch.show_routes()

    else:
        print(f"{RED}Unknown command: {command}{RESET}")
        print("Commands: status, cascade, run, route")
        sys.exit(1)


if __name__ == "__main__":
    main()
