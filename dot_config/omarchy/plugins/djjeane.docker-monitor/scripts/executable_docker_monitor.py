#!/usr/bin/env python3
"""Collect Docker container status and resource usage."""

from __future__ import annotations

import json
import subprocess
import sys


def run(cmd: list[str]) -> str:
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        return result.stdout.strip()
    except Exception:
        return ""


def parse_labels(label_str: str) -> dict[str, str]:
    labels = {}
    for pair in label_str.split(","):
        if "=" in pair:
            k, v = pair.split("=", 1)
            labels[k.strip()] = v.strip()
    return labels


def list_containers() -> list[dict]:
    fmt = '{{json .}}'
    raw = run(["docker", "ps", "-a", "--no-trunc", "--format", fmt])
    if not raw:
        return []
    containers = []
    for line in raw.splitlines():
        try:
            data = json.loads(line)
            labels = parse_labels(data.get("Labels", ""))
            project = labels.get("com.docker.compose.project", "")
            containers.append({
                "id": data.get("ID", "")[:12],
                "name": data.get("Names", ""),
                "image": data.get("Image", ""),
                "state": data.get("State", "").lower(),
                "status": data.get("Status", ""),
                "ports": data.get("Ports", ""),
                "project": project,
            })
        except json.JSONDecodeError:
            continue
    return containers


def get_stats() -> dict[str, dict]:
    fmt = '{{json .}}'
    raw = run(["docker", "stats", "--no-stream", "--no-trunc", "--format", fmt])
    if not raw:
        return {}
    stats = {}
    for line in raw.splitlines():
        try:
            data = json.loads(line)
            cid = data.get("ID", "")[:12]
            cpu_str = data.get("CPUPerc", "0%").rstrip("%")
            mem_str = data.get("MemPerc", "0%").rstrip("%")
            try:
                cpu = float(cpu_str)
            except ValueError:
                cpu = 0.0
            try:
                mem_pct = float(mem_str)
            except ValueError:
                mem_pct = 0.0
            stats[cid] = {
                "cpu": round(cpu, 1),
                "memPct": round(mem_pct, 1),
                "memUsage": data.get("MemUsage", ""),
                "netIO": data.get("NetIO", ""),
                "blockIO": data.get("BlockIO", ""),
            }
        except json.JSONDecodeError:
            continue
    return stats


def main() -> int:
    containers = list_containers()
    stats = get_stats()

    running = 0
    stopped = 0
    paused = 0

    for c in containers:
        s = c["state"]
        if s == "running":
            running += 1
        elif s == "paused":
            paused += 1
        else:
            stopped += 1

        if c["id"] in stats:
            c.update(stats[c["id"]])
        else:
            c["cpu"] = 0.0
            c["memPct"] = 0.0
            c["memUsage"] = ""
            c["netIO"] = ""
            c["blockIO"] = ""

    groups: dict[str, list[dict]] = {}
    for c in containers:
        key = c["project"] or ""
        groups.setdefault(key, []).append(c)

    group_list = []
    for key in sorted(groups, key=lambda k: (k == "", k)):
        g = groups[key]
        g_running = sum(1 for c in g if c["state"] == "running")
        group_list.append({
            "project": key if key else "standalone",
            "running": g_running,
            "total": len(g),
            "containers": g,
        })

    result = {
        "summary": {
            "running": running,
            "stopped": stopped,
            "paused": paused,
            "total": len(containers),
        },
        "containers": containers,
        "groups": group_list,
    }

    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
