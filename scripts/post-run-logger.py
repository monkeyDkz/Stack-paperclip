#!/usr/bin/env python3
"""Post-run logger: parse Paperclip ndjson log, save summary to Mem0 + SiYuan."""

import argparse
import json
import subprocess
import sys
import urllib.request
from datetime import datetime

COMPANY_ID = "7c6f8a64-083b-4ff3-a478-b523b0b87b0d"

AGENTS = {
    "ceo": {"id": "bd91f3cc-472e-4add-b480-1b1f4dabb042", "notebook": "20260320194608-s5u2t4r", "path": "/decisions"},
    "cto": {"id": "0d3160d7-6fea-4633-944a-0ca41210d8e2", "notebook": "20260320194607-hgogt71", "path": "/adr"},
    "cpo": {"id": "6b800922-3d71-4ddb-896c-bb20d81a4116", "notebook": "20260320194607-fqaoh9q", "path": "/prd"},
    "cfo": {"id": "44499293-c6bd-4b02-ad23-4274842e679f", "notebook": "20260320194608-s5u2t4r", "path": "/finance"},
    "lead-backend": {"id": "30388859-12b5-4907-8c77-c1fb2a520e78", "notebook": "20260320194607-6xo3cuc", "path": "/backend"},
    "lead-frontend": {"id": "45861453-a2e2-4044-94af-abffe6e72a54", "notebook": "20260320194607-6xo3cuc", "path": "/frontend"},
    "devops": {"id": "cf87ed4e-21a3-424a-b8d1-29e5436f643a", "notebook": "20260320194607-gbsqq20", "path": "/devops"},
    "security": {"id": "882a767a-8295-4f35-9865-14a0142adb26", "notebook": "20260320194608-8roxki3", "path": "/audits"},
    "qa": {"id": "436026bf-b23c-4e0b-a952-94ad0a577fac", "notebook": "20260320194607-6xo3cuc", "path": "/qa"},
    "designer": {"id": "c3146739-1ca8-455b-87cb-c5f8841ab5c2", "notebook": "20260320194607-pvfpeoz", "path": "/specs"},
    "researcher": {"id": "0400e565-6dc4-434c-be96-d8735eec4a2b", "notebook": "20260320194607-9j2zaos", "path": "/research"},
    "growth-lead": {"id": "3ebd54af-e9b1-40db-94d5-2bb0824799f4", "notebook": "20260320194608-s5u2t4r", "path": "/growth"},
    "seo": {"id": "4626220e-c5b6-44b5-9f6c-eed11e64bee1", "notebook": "20260320194608-s5u2t4r", "path": "/seo"},
    "content-writer": {"id": "b708cea0-22fa-44ca-92d8-c5cc033d2991", "notebook": "20260320194608-s5u2t4r", "path": "/content"},
    "data-analyst": {"id": "049131ad-7030-4950-9dc2-ea09ba813f45", "notebook": "20260320194608-s5u2t4r", "path": "/analytics"},
    "sales": {"id": "ab8d419a-72b9-4b62-9b9f-c5d61bf8543e", "notebook": "20260320194608-s5u2t4r", "path": "/sales"},
}

MEM0_URL = "http://localhost:8050"
SIYUAN_URL = "http://localhost:6806"
SIYUAN_AUTH_CODE = ""


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def http_post(url, payload, headers=None):
    """POST JSON, return parsed response body."""
    hdrs = {"Content-Type": "application/json"}
    if headers:
        hdrs.update(headers)
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, headers=hdrs, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read().decode())
    except Exception as exc:
        print(f"[post-run-logger] HTTP error {url}: {exc}", file=sys.stderr)
        return None


def read_ndjson(agent_id, run_id):
    """Read the ndjson log from the Paperclip container."""
    log_path = f"/paperclip/instances/default/data/run-logs/{COMPANY_ID}/{agent_id}/{run_id}.ndjson"
    try:
        result = subprocess.run(
            ["docker", "exec", "paperclip", "cat", log_path],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode != 0:
            print(f"[post-run-logger] warn: log not found ({log_path})", file=sys.stderr)
            return None
        return result.stdout
    except subprocess.TimeoutExpired:
        print("[post-run-logger] warn: docker exec timed out", file=sys.stderr)
        return None
    except FileNotFoundError:
        print("[post-run-logger] warn: docker command not found", file=sys.stderr)
        return None


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

def parse_log(raw_ndjson):
    """Parse ndjson lines and return structured data."""
    tool_calls = []  # list of dicts: tool, status, command
    issues = []
    mem0_saves = []
    errors = []

    for line in raw_ndjson.strip().splitlines():
        if not line.strip():
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue

        chunk = entry.get("chunk", "")
        stream = entry.get("stream", "stdout")

        # Try to parse chunk as JSON (it may be plain text)
        try:
            part = json.loads(chunk)
        except (json.JSONDecodeError, TypeError):
            part = None

        if part is None:
            # Not JSON — check for error markers in stderr
            if stream == "stderr" and chunk.strip():
                errors.append(chunk.strip()[:200])
            continue

        part_type = part.get("type")

        if part_type == "tool_use":
            tool_name = part.get("tool", part.get("name", "unknown"))
            state = part.get("state", {})
            status = state.get("status", "unknown")
            inp = state.get("input", {})
            command = inp.get("command", "")
            tool_calls.append({
                "tool": tool_name,
                "status": status,
                "command": command[:100] if command else "",
            })
            # Detect issue creation
            if command and "POST" in command and "/issues" in command:
                issues.append(command[:100])
            # Detect Mem0 saves
            if command and "POST" in command and "/memories" in command:
                mem0_saves.append(command[:100])
            # Collect errors
            if status == "error":
                error_msg = state.get("error", command[:100] if command else tool_name)
                errors.append(f"[{tool_name}] {error_msg}"[:200])

        elif part_type == "text":
            # Plain text output — nothing special to extract
            pass

    return tool_calls, issues, mem0_saves, errors


def build_summary(agent_name, run_id, status, tool_calls, issues, mem0_saves, errors):
    """Build summary dict."""
    completed = sum(1 for t in tool_calls if t["status"] == "completed")
    errored = sum(1 for t in tool_calls if t["status"] == "error")
    total = len(tool_calls)

    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    issue_list = ", ".join(issues) if issues else "none"

    text_line = (
        f"Run {now}: {total} tools ({completed} ok, {errored} err). "
        f"Issues: {issue_list}. Status: {status}."
    )

    return {
        "text": text_line,
        "total": total,
        "completed": completed,
        "errored": errored,
        "date": now,
        "issue_list": issue_list,
    }


# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

def save_to_mem0(agent_name, run_id, status, summary):
    """POST summary to Mem0."""
    payload = {
        "text": summary["text"],
        "user_id": agent_name,
        "metadata": {
            "type": "run-log",
            "run_id": run_id,
            "status": status,
            "tools_count": summary["total"],
            "errors_count": summary["errored"],
        },
    }
    resp = http_post(f"{MEM0_URL}/memories", payload)
    if resp:
        print(f"[post-run-logger] Mem0 saved for {agent_name}")
    else:
        print(f"[post-run-logger] Mem0 save failed for {agent_name}", file=sys.stderr)


def save_to_siyuan(agent_name, agent_cfg, run_id, status, summary, tool_calls, issues, errors):
    """Create a doc in SiYuan with the run summary."""
    # Login
    token = None
    login_resp = http_post(f"{SIYUAN_URL}/api/system/loginAuth", {"authCode": SIYUAN_AUTH_CODE})
    if login_resp and login_resp.get("code") == 0:
        token = login_resp.get("data", {}).get("token", "")

    headers = {}
    if token:
        headers["Authorization"] = f"Token {token}"

    # Build markdown
    date_slug = datetime.now().strftime("%Y-%m-%d-%H%M")
    md_lines = [
        f"# Run {agent_name} — {summary['date']}",
        f"Status: {status} | Tools: {summary['total']}",
        "",
        "## Tool Calls",
    ]
    for i, tc in enumerate(tool_calls, 1):
        cmd_display = tc["command"] if tc["command"] else tc["tool"]
        md_lines.append(f"{i}. [{tc['status']}] {cmd_display}")

    md_lines.append("")
    md_lines.append("## Issues")
    if issues:
        for iss in issues:
            md_lines.append(f"- {iss}")
    else:
        md_lines.append("- Aucune")

    md_lines.append("")
    md_lines.append("## Errors")
    if errors:
        for err in errors:
            md_lines.append(f"- {err}")
    else:
        md_lines.append("- Aucune")

    markdown = "\n".join(md_lines)

    doc_path = f"{agent_cfg['path']}/runs/{date_slug}"
    payload = {
        "notebook": agent_cfg["notebook"],
        "path": doc_path,
        "markdown": markdown,
    }
    resp = http_post(f"{SIYUAN_URL}/api/filetree/createDocWithMd", payload, headers)
    if resp and resp.get("code") == 0:
        print(f"[post-run-logger] SiYuan doc created: {doc_path}")
    else:
        print(f"[post-run-logger] SiYuan save failed for {agent_name}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Post-run logger for Paperclip agents")
    parser.add_argument("agent_name", help="Agent name (e.g. ceo, cto)")
    parser.add_argument("run_id", help="Run UUID")
    parser.add_argument("--status", choices=["succeeded", "failed"], default="succeeded")
    args = parser.parse_args()

    agent_name = args.agent_name
    run_id = args.run_id
    status = args.status

    if agent_name not in AGENTS:
        print(f"[post-run-logger] error: unknown agent '{agent_name}'", file=sys.stderr)
        sys.exit(1)

    agent_cfg = AGENTS[agent_name]

    # 1. Read log
    raw = read_ndjson(agent_cfg["id"], run_id)
    if raw is None:
        # No log — still record the run with empty data
        tool_calls, issues, mem0_saves, errors = [], [], [], []
    else:
        # 2. Parse
        tool_calls, issues, mem0_saves, errors = parse_log(raw)

    # 3. Build summary
    summary = build_summary(agent_name, run_id, status, tool_calls, issues, mem0_saves, errors)

    # 4. Save to Mem0
    save_to_mem0(agent_name, run_id, status, summary)

    # 5. Save to SiYuan
    save_to_siyuan(agent_name, agent_cfg, run_id, status, summary, tool_calls, issues, errors)

    # 6. Stdout summary for orchestrator
    print(f"[post-run-logger] {agent_name}/{run_id}: {summary['text']}")


if __name__ == "__main__":
    main()
