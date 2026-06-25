#!/usr/bin/env python3
"""PR metadata management for FireSim F2 Nested DFX builds.

Generates metadata during PR base builds and validates consistency
during RM builds. Metadata is stored alongside the abstract shell
DCP for S3 caching and cross-machine reuse.

Usage:
    # After PR base build completes — generate metadata
    python3 pr_metadata.py generate \
        --checkpoints_dir /path/to/checkpoints \
        --frequency 60 \
        --strategy TIMING \
        --shell_mode small_shell \
        --pr_module_name BestOffsetPrefetcher \
        [--vivado_version 2024.2] \
        [--discovered_cell_file /path/to/discovered_pr_cell.txt]

    # Before PR RM build — validate abstract shell compatibility
    python3 pr_metadata.py validate \
        --checkpoints_dir /path/to/base/checkpoints \
        --frequency 60
"""

import argparse
import hashlib
import json
import os
import sys
from datetime import datetime
from pathlib import Path


DEVICE = "xcvu47p-fsvh2892-2-e"


def extract_module_port_signature(filepath: str) -> str:
    """Extract the module port declaration (header) from a split-verilog file.

    Returns the text from 'module <name>(' through the closing ');' of the
    port list. This captures the module name, port directions, types, widths,
    and names — everything that defines the interface — but excludes the
    internal implementation (wires, assigns, instantiations, always blocks).

    If the PR module changes but the parent's ports stay the same, the parent's
    signature hash won't change, avoiding false positives.
    """
    import re
    text = Path(filepath).read_text()
    # Match from 'module <name>' through the port list closing ');'
    # The port list may span many lines and contain nested parens in comments
    m = re.search(r'(module\s+\w+\s*\(.*?\);)', text, re.DOTALL)
    return m.group(1) if m else ""


def compute_port_signature_checksums(cl_dir: str, exclude_modules: list = None) -> dict:
    """Compute SHA256 checksums of module port signatures from split-verilog.

    Only hashes the module port declaration (name + ports), not the internal
    implementation. This means:
    - If a parent module (e.g. TLPrefetcher) instantiates a different child
      (BestOffsetPrefetcher vs CyclicStridePrefetcher), the parent's hash
      won't change as long as its own ports are unchanged.
    - Only true interface changes (added/removed/resized ports) are detected.

    Modules listed in exclude_modules are skipped entirely (the PR module
    itself, which is expected to have a different interface in RM builds).
    """
    checksums = {}
    exclude_modules = exclude_modules or []
    exclude_basenames = {f"{m}.sv" for m in exclude_modules}

    split_dir = Path(cl_dir) / "design" / "split-verilog"
    if not split_dir.is_dir():
        return checksums

    for f in sorted(split_dir.glob("*.sv")):
        if f.name in exclude_basenames:
            continue
        sig = extract_module_port_signature(str(f))
        if sig:
            relpath = str(f.relative_to(cl_dir))
            h = hashlib.sha256(sig.encode()).hexdigest()
            checksums[relpath] = h

    return checksums


def generate_metadata(args):
    """Generate pr_metadata.json after a PR base build."""
    checkpoints_dir = args.checkpoints_dir

    # Read discovered cell path if available
    pr_module_name = args.pr_module_name
    partition_cell = args.partition_cell or ""

    if args.discovered_cell_file and os.path.exists(args.discovered_cell_file):
        with open(args.discovered_cell_file) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    parts = line.split(":", 1)
                    if len(parts) == 2:
                        pr_module_name = parts[0].strip()
                        partition_cell = parts[1].strip()

    # Compute source checksums if CL_DIR is available.
    # Exclude the PR module itself — its RTL is expected to differ between
    # base and RM builds. Only the static shell modules need to match.
    cl_dir = os.environ.get("CL_DIR", "")
    exclude_modules = [pr_module_name] if pr_module_name else []
    source_checksums = compute_port_signature_checksums(cl_dir, exclude_modules) if cl_dir else {}

    # Read adjusted frequency if available (from post-route MMCM adjustment)
    adjusted_freq = ""
    adjusted_freq_file = os.path.join(checkpoints_dir, "adjusted_host_frequency.txt")
    if os.path.exists(adjusted_freq_file):
        with open(adjusted_freq_file) as f:
            adjusted_freq = f.read().strip()

    metadata = {
        "format_version": 3,
        "platform": "f2",
        "build_timestamp": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
        "vivado_version": args.vivado_version or "",
        "device": DEVICE,
        "frequency_mhz": args.frequency,
        "adjusted_frequency_mhz": adjusted_freq,
        "strategy": args.strategy,
        "shell_mode": args.shell_mode,
        "pr_modules": [{
            "module_name": pr_module_name,
            "partition_cell": partition_cell,
        }],
        "source_checksums": source_checksums,
    }

    output_path = os.path.join(checkpoints_dir, "pr_metadata.json")
    with open(output_path, "w") as f:
        json.dump(metadata, f, indent=2)

    print(f"PR metadata written to: {output_path}")
    print(f"  Module: {pr_module_name}")
    print(f"  Partition cell: {partition_cell}")
    print(f"  Source files checksummed: {len(source_checksums)}")


def validate_metadata(args):
    """Validate abstract shell compatibility before RM build."""
    checkpoints_dir = args.checkpoints_dir
    metadata_path = os.path.join(checkpoints_dir, "pr_metadata.json")

    if not os.path.exists(metadata_path):
        print(f"WARNING: No PR metadata found at {metadata_path}")
        print("  Cannot validate abstract shell compatibility.")
        return

    with open(metadata_path) as f:
        metadata = json.load(f)

    print("=" * 50)
    print("PR ABSTRACT SHELL VALIDATION")
    print("=" * 50)
    if "build_timestamp" in metadata:
        print(f"  Base build: {metadata['build_timestamp']}")

    has_warnings = False

    # Validate frequency
    stored_freq = str(metadata.get("frequency_mhz", ""))
    if stored_freq and stored_freq != str(args.frequency):
        has_warnings = True
        print(f"WARNING: Frequency mismatch: base='{stored_freq}' current='{args.frequency}'")

    # Validate Vivado version
    stored_vivado = metadata.get("vivado_version", "")
    if stored_vivado and args.vivado_version and stored_vivado != args.vivado_version:
        has_warnings = True
        print(f"WARNING: Vivado version mismatch: base='{stored_vivado}' current='{args.vivado_version}'")

    # Validate device
    stored_device = metadata.get("device", "")
    if stored_device and stored_device != DEVICE:
        has_warnings = True
        print(f"WARNING: Device mismatch: base='{stored_device}' expected='{DEVICE}'")

    # Report PR module info
    pr_modules = metadata.get("pr_modules", [])
    pr_module_names = []
    for mod in pr_modules:
        name = mod.get("module_name", "unknown")
        pr_module_names.append(name)
        print(f"  PR module: {name}")
        print(f"  Partition cell: {mod.get('partition_cell', 'unknown')}")

    # Validate static shell checksums: compare per-module hashes from the
    # base build against the current RM build's modules (excluding the PR
    # module itself, which is expected to differ).
    stored_checksums = metadata.get("source_checksums", {})
    cl_dir = os.environ.get("CL_DIR", "")
    if stored_checksums and cl_dir:
        # Exclude the base build's PR module AND the current RM module
        exclude = list(set(pr_module_names + (args.pr_module_names or [])))
        current_checksums = compute_port_signature_checksums(cl_dir, exclude)

        # Only compare files present in both (split-verilog paths)
        mismatched = []
        for path, base_hash in stored_checksums.items():
            if path in current_checksums and current_checksums[path] != base_hash:
                mismatched.append(path)

        if mismatched:
            has_warnings = True
            print(f"WARNING: {len(mismatched)} static module(s) differ from base build:")
            for p in mismatched[:10]:
                print(f"  - {p}")
            if len(mismatched) > 10:
                print(f"  ... and {len(mismatched) - 10} more")
        else:
            matched = sum(1 for p in stored_checksums if p in current_checksums)
            print(f"  Static shell checksums OK ({matched} modules verified)")

    if not has_warnings:
        print("  Abstract shell validation passed.")

    print("=" * 50)

    if has_warnings:
        sys.exit(2)


def main():
    parser = argparse.ArgumentParser(description="F2 PR metadata management")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # generate subcommand
    gen = subparsers.add_parser("generate", help="Generate PR metadata after base build")
    gen.add_argument("--checkpoints_dir", required=True)
    gen.add_argument("--frequency", required=True)
    gen.add_argument("--strategy", required=True)
    gen.add_argument("--shell_mode", default="small_shell")
    gen.add_argument("--pr_module_name", required=True)
    gen.add_argument("--partition_cell", default="")
    gen.add_argument("--vivado_version", default="")
    gen.add_argument("--discovered_cell_file", default="",
                     help="File with module:cell_path from build_level_1_cl_pr_base.tcl")

    # validate subcommand
    val = subparsers.add_parser("validate", help="Validate abstract shell before RM build")
    val.add_argument("--checkpoints_dir", required=True)
    val.add_argument("--frequency", default="")
    val.add_argument("--vivado_version", default="")
    val.add_argument("--pr_module_names", nargs="*", default=[],
                     help="Current RM module name(s) to exclude from checksum comparison")

    args = parser.parse_args()

    if args.command == "generate":
        generate_metadata(args)
    elif args.command == "validate":
        validate_metadata(args)


if __name__ == "__main__":
    main()
