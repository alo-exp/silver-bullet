#!/usr/bin/env python3
"""Assign every review finding to exactly one fix package; report gaps and per-package lists."""
import glob
import json
import os
import re
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))

# Default package per review area (overridden per id below).
AREA_DEFAULT = {
    "R1": "G1", "R2": "G2", "R3": "G4", "R4": "G5", "R5": "H4a", "R6": "H4b", "R7": "H2",
    "R8": "H5", "R9": "H6", "R10": "H7", "R10b": "H7", "R11": "H8a", "R12": "H8b",
    "R13": "H3", "R14": "H9", "R15": "H10", "R16": "H11",
}

OVERRIDES = {
    # F1 output & paths
    "R2-28": "F1", "R3-05": "F1", "R3-21": "F1", "R1-29": "F1", "R3-27": "F1",
    # F2 input & shell analysis
    "R1-01": "F2", "R1-02": "F2", "R1-03": "F2", "R1-05": "F2", "R1-06": "F2", "R1-12": "F2",
    "R1-28": "F2", "R2-02": "F2", "R2-03": "F2", "R3-10": "F2", "R4-04": "F2", "R5-05": "F2",
    # G1 delivery gates (cross-area)
    "R3-02": "G1", "R4-01": "G1", "R13-08": "G1", "R13-09": "G1", "R8-13": "G1", "R13-10": "G1",
    "R13-20": "G1", "R10-29": "G1", "R3-09": "G1", "R16-06": "G1",
    # G2 planning floor & protected files
    "R3-01": "G2", "R3-13": "G2", "R1-07": "G2",
    # G3 stop / prompt / override
    "R4-07": "G3", "R4-08": "G3", "R4-12": "G3", "R4-13": "G3", "R4-14": "G3", "R5-06": "G3",
    "R10-03": "G3",
    # G3 stop/prompt (R2 defaults to G2)
    "R2-09": "G3", "R2-10": "G3", "R2-11": "G3", "R2-17": "G3", "R2-19": "G3", "R2-22": "G3",
    "R2-23": "G3", "R2-24": "G3", "R2-25": "G3", "R2-30": "G3", "R2-32": "G3", "R2-36": "G3",
    # G4 session / state / recording / project-code execution
    "R2-12": "G4", "R8-07": "G4", "R8-08": "G4", "R1-23": "G4", "R10b-03": "G4", "R16-01": "G4",
    # G5 orchestrator
    "R9-05": "G5", "R9-31": "G5", "R10-02": "G5",
    # G6 RFL & delegation
    "R4-09": "G6", "R4-10": "G6", "R4-11": "G6", "R4-15": "G6", "R4-16": "G6", "R4-20": "G6",
    "R4-21": "G6", "R4-22": "G6", "R4-23": "G6", "R4-24": "G6", "R4-25": "G6", "R4-31": "G6",
    "R4-32": "G6", "R8-14": "G6", "R8-15": "G6", "R8-26": "G6", "R10b-05": "G6", "R10b-06": "G6",
    # H1 host adapters / bridges
    "R7-01": "H1", "R7-03": "H1", "R7-05": "H1", "R7-16": "H1", "R7-17": "H1", "R7-18": "H1",
    "R7-22": "H1", "R7-31": "H1", "R7-32": "H1", "R3-31": "H1",
    # H2 installers (pruner)
    "R8-16": "H2",
    # H3 release / CI
    "R8-18": "H3", "R8-19": "H3", "R9-22": "H3", "R7-30": "H3",
    # H5 packaging
    "R10b-04": "H5", "R10b-19": "H5",
    # H8 research
    "R10b-01": "H8b", "R10b-02": "H8b", "R10b-16": "H8a",
    # H9 e2e harness
    "R3-24": "H9",
    # H10 test infra
    "R6-15": "H10",
}

RUNNING = {"F1", "F2", "H2", "H3", "H4a", "H5", "H8a", "H8b"}


def main():
    rows = []
    for path in glob.glob(os.path.join(HERE, "R*.json")):
        area = os.path.basename(path)[:-5]
        if not re.fullmatch(r"R\d+b?", area):
            continue
        data = json.load(open(path))
        for f in data.get("findings", []):
            rows.append((area, f))
    packages = defaultdict(list)
    for area, f in rows:
        fid = f["id"]
        pkg = OVERRIDES.get(fid) or AREA_DEFAULT.get(area)
        packages[pkg].append(f)
    sev = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    out = {}
    for pkg in sorted(packages):
        items = sorted(packages[pkg], key=lambda f: (sev.get(f["severity"], 9), f["id"]))
        out[pkg] = [f["id"] for f in items]
        c = {s: sum(1 for f in items if f["severity"] == s) for s in sev}
        state = "running" if pkg in RUNNING else "pending"
        print(f"{pkg:<4} {state:<8} {len(items):>3} findings  crit {c['critical']} high {c['high']} med {c['medium']} low {c['low']}")
    json.dump(out, open(os.path.join(HERE, "packages.json"), "w"), indent=1)
    print("total", sum(len(v) for v in out.values()))
    if len(sys.argv) > 1:
        for f_area, f in rows:
            if (OVERRIDES.get(f["id"]) or AREA_DEFAULT.get(f_area)) == sys.argv[1]:
                print(f"  {f['id']} [{f['severity']}] {f['title'][:150]}")


if __name__ == "__main__":
    main()
