"""Acceptance budgets for this PC's four-player, 30-FPS native soak test."""
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
failures = []
summary_path = root / "summary.json"
if not summary_path.exists() or not json.loads(summary_path.read_text(encoding="utf-8-sig")).get("ok"):
    failures.append("native launcher did not confirm integrity and clean shutdown")
for name in ["host", "guest-1", "guest-2", "guest-3"]:
    report = json.loads((root / "reports" / f"{name}.json").read_text(encoding="utf-8-sig"))
    if report["status"] != "PASS" or report["code"] or not report["scenario_complete"]:
        failures.append(f"{name}: incomplete: {report['code']}")
    if report["frame"].get("p95_ms", 99999) > 80:
        failures.append(f"{name}: frame p95 {report['frame'].get('p95_ms')} ms > 80 ms")
    if name != "host":
        actions = report["actions"]
        if actions["count"] < 30 or actions.get("p95_ms", 99999) > 250:
            failures.append(f"{name}: action p95 {actions.get('p95_ms')} ms > 250 ms, count={actions['count']}")
        if report["snapshot_loads"] != 1:
            failures.append(f"{name}: unexpected world reload count {report['snapshot_loads']}")
        if not report["checks"].get("native_integrity") or report["checks"].get("max_tool_load", 0) < 1:
            failures.append(f"{name}: native cargo/machine/tool integrity witness missing")
print(json.dumps({"ok": not failures, "failures": failures}, indent=2))
sys.exit(bool(failures))
