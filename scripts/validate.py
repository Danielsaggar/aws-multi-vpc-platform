"""Reproducible offline checks. Never runs an authenticated AWS plan."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(args):
    env = {k: v for k, v in os.environ.items() if not k.upper().startswith(("AWS_", "TF_VAR_", "TF_CLI_ARGS"))}
    env.update(AWS_CONFIG_FILE=os.devnull, AWS_SHARED_CREDENTIALS_FILE=os.devnull, AWS_EC2_METADATA_DISABLED="true")
    subprocess.run(args, cwd=ROOT, env=env, check=True)


def terraform():
    run(["terraform", "fmt", "-check", "-recursive", "modules"])
    for directory in (ROOT, ROOT / "bootstrap"):
        run(["terraform", f"-chdir={directory}", "fmt", "-check"])
        run(["terraform", f"-chdir={directory}", "init", "-backend=false", "-input=false", "-lockfile=readonly"])
        run(["terraform", f"-chdir={directory}", "validate", "-no-color"])
        run(["terraform", f"-chdir={directory}", "test", "-no-color"])


def docs():
    required = ["REQUIREMENTS", "DECISIONS", "ARCHITECTURE", "BOOTSTRAP", "DEPLOYMENT", "FLOCI", "VALIDATION_MATRIX", "OPERATIONS", "LIMITATIONS", "COSTS"]
    for name in required:
        path = ROOT / "docs" / f"{name}.md"
        assert path.exists() and len(path.read_text(encoding="utf-8")) > 100, path
    print("Documentation inventory passed")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("suite", choices=["terraform", "docs", "costs", "all"])
    args = parser.parse_args()
    if args.suite in ("all", "terraform"):
        terraform()
        run([sys.executable, "-m", "unittest", "discover", "-s", "tests/unit", "-v"])
    if args.suite in ("all", "docs"):
        docs()
    if args.suite in ("all", "costs"):
        import zipfile
        import xml.etree.ElementTree as ET
        with zipfile.ZipFile(ROOT / "docs/costs.xlsx") as book:
            assert "xl/workbook.xml" in book.namelist()
            sheet = ET.fromstring(book.read("xl/worksheets/sheet1.xml"))
            assert sheet.findall(".//{http://schemas.openxmlformats.org/spreadsheetml/2006/main}f")
        print("Cost workbook exists and contains formulas")


if __name__ == "__main__":
    main()
