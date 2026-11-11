#!/usr/bin/env python3
"""Stdlib artifact-checker for RevoCred card audit (not an app feature).
Checks: slug sets equal + no dups, catalog count==14 by actual input,
reference counts reconciled, cited local evidence exists, JSON/CSV counts match,
no unsupported fully_verified claims. Run from workdir: python3 output/verify_audit.py
"""
import csv
import json
import os
import sys
from collections import Counter
from pathlib import Path

def fail(msg):
    print(f"FAIL: {msg}")
    return False

def main():
    # Resolve workdir: parent of output/ if script is in output/, else cwd
    here = Path(__file__).resolve()
    if here.parent.name == "output":
        work = here.parent.parent
    else:
        work = Path.cwd()
    inv_path = work / "inventory.json"
    audit_path = work / "output" / "card-audit.json"
    csv_path = work / "output" / "card-audit.csv"
    ok = True

    if not inv_path.exists():
        print(f"FAIL: missing {inv_path}")
        return 1
    if not audit_path.exists():
        print(f"FAIL: missing {audit_path}")
        return 1
    if not csv_path.exists():
        print(f"FAIL: missing {csv_path}")
        return 1

    inv = json.loads(inv_path.read_text(encoding="utf-8"))
    aud = json.loads(audit_path.read_text(encoding="utf-8"))

    inv_slugs = [c["slug"] for c in inv.get("catalog", [])]
    aud_slugs = [r.get("slug") for r in aud.get("records", [])]

    # 1. catalog count == 14 by actual input
    if len(inv.get("catalog", [])) != 14:
        ok = fail(f"inventory catalog count is {len(inv.get('catalog', []))}, expected 14") and False
    else:
        print(f"OK: inventory catalog count = 14")
    if len(aud_slugs) != 14:
        ok = fail(f"audit records count is {len(aud_slugs)}, expected 14")
    else:
        print(f"OK: audit records count = 14")

    # 2. no duplicates
    if len(set(inv_slugs)) != len(inv_slugs):
        ok = fail(f"duplicate slugs in inventory: {[k for k,v in Counter(inv_slugs).items() if v>1]}")
    else:
        print("OK: no duplicates in inventory slugs")
    if len(set(aud_slugs)) != len(aud_slugs):
        ok = fail(f"duplicate slugs in audit: {[k for k,v in Counter(aud_slugs).items() if v>1]}")
    else:
        print("OK: no duplicates in audit slugs")

    # 3. slug sets exactly equal
    if set(inv_slugs) != set(aud_slugs):
        ok = fail(f"slug sets differ. missing={sorted(set(inv_slugs)-set(aud_slugs))} extra={sorted(set(aud_slugs)-set(inv_slugs))}")
    else:
        print(f"OK: slug sets exactly equal ({len(inv_slugs)} slugs)")

    # 4. reference counts reconciled
    ref = inv.get("reference_index", [])
    actual_counter = Counter(r.get("terms_status") for r in ref)
    actual_total = len(ref)
    summary = aud.get("reference_summary", {})
    sum_total = summary.get("total")
    sum_by = summary.get("by_terms_status", {})
    print(f"INFO: actual reference total={actual_total} by={dict(actual_counter)}")
    print(f"INFO: audit summary total={sum_total} by={sum_by}")
    if sum_total != actual_total:
        ok = fail(f"reference total mismatch: audit {sum_total} vs inventory {actual_total}")
    else:
        print("OK: reference total reconciled")
    # compare each status
    for k, v in actual_counter.items():
        if sum_by.get(k) != v:
            ok = fail(f"reference terms_status '{k}' mismatch: audit {sum_by.get(k)} vs actual {v}")
    for k in sum_by:
        if k not in actual_counter:
            ok = fail(f"audit references unknown terms_status '{k}'")
    if ok:
        print("OK: reference counts grouped by terms_status reconciled")

    # 5. cited local evidence exists
    missing = []
    for rec in aud.get("records", []):
        for p in rec.get("evidence_paths", []):
            fp = work / p
            if not fp.exists():
                missing.append(f"{rec.get('slug')}:{p}")
    if missing:
        ok = fail(f"cited local evidence missing ({len(missing)}): {missing[:10]}")
    else:
        print(f"OK: all cited local evidence exists")

    # 6. JSON/CSV counts match
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = list(csv.DictReader(f))
    csv_slugs = [r.get("slug") for r in reader]
    print(f"INFO: csv data rows={len(reader)} slugs={csv_slugs}")
    if len(reader) != len(aud.get("records", [])):
        ok = fail(f"JSON/CSV count mismatch: json {len(aud.get('records', []))} vs csv {len(reader)}")
    else:
        print("OK: JSON/CSV counts match")
    if set(csv_slugs) != set(aud_slugs):
        ok = fail(f"CSV slugs differ from JSON. missing={sorted(set(aud_slugs)-set(csv_slugs))} extra={sorted(set(csv_slugs)-set(aud_slugs))}")
    else:
        print("OK: CSV slugs match JSON")
    if len(set(csv_slugs)) != len(csv_slugs):
        ok = fail("duplicate slugs in CSV")
    else:
        print("OK: no duplicates in CSV")

    # 7. no unsupported fully_verified claims
    bad = [r.get("slug") for r in aud.get("records", []) if "fully_verified" in str(r.get("verification_state", "")).lower()]
    if bad:
        ok = fail(f"unsupported fully_verified claims in: {bad}")
    else:
        print("OK: no unsupported fully_verified claims (verification_state)")

    print("PASS" if ok else "FAIL")
    return 0 if ok else 1

if __name__ == "__main__":
    sys.exit(main())
