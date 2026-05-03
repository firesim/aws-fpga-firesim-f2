#!/usr/bin/env python3

# =============================================================================
# Amazon FPGA Hardware Development Kit
#
# Copyright 2024 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#    http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions and
# limitations under the License.
# =============================================================================

import os
from argparse import ArgumentParser
from glob import glob

XSIM = "xsim"
VCS = "vcs"
QUESTA = "questa"
INCLUDE_SYNTAX = {XSIM: "-include ", VCS: "+incdir+", QUESTA: "+incdir+"}


def main(args) -> None:
    generated_file_list = get_generated_file_list(args.cl_dir, args.simulator)
    update_sim_file_list(args.cl_dir, args.simulator, generated_file_list)


def get_generated_file_list(cl_dir, simulator):
    all_file_objects: list[str] = glob(f"{cl_dir}/design/**", recursive=True)
    all_file_paths = [obj for obj in all_file_objects if os.path.isfile(obj)]
    all_dir_paths = [obj for obj in all_file_objects if os.path.isdir(obj)]

    generated_file_list = [""]
    for dir_path in all_dir_paths:
        generated_file_list.append(INCLUDE_SYNTAX[simulator.lower()] + dir_path.replace(cl_dir, "$CL_DIR"))

    generated_file_list.append("")
    for file_path in all_file_paths:
        if not file_path.endswith("h") and not file_path.endswith("md"):
            generated_file_list.append(file_path.replace(cl_dir, "$CL_DIR"))

    return generated_file_list + [""]


def update_sim_file_list(cl_dir, simulator, generated_file_list):
    in_generate_block = False
    sim_file_list_path = f"{cl_dir}/verif/scripts/top.{simulator.lower()}.f"
    lines = []
    with open(sim_file_list_path) as f:
        for line in f:
            if "BEGIN AUTO-GENERATE" in line:
                in_generate_block = True
                lines.append(line)
                for generated_line in generated_file_list:
                    lines.append(generated_line + "\n")
                continue

            if in_generate_block and "END AUTO-GENERATE" in line:
                in_generate_block = False

            if not in_generate_block:
                lines.append(line)

    with open(sim_file_list_path, "w") as f:
        f.writelines(lines)


parser = ArgumentParser(
    prog="Generate Simulation File List",
    description="Gerneate a file list in `$CL_DIR/verif/scripts` for a specific simulator",
)
parser.add_argument("--simulator", dest="simulator", required=True)
parser.add_argument("--cl_dir", dest="cl_dir", required=True)


if __name__ == "__main__":
    args = parser.parse_args()
    main(args)
