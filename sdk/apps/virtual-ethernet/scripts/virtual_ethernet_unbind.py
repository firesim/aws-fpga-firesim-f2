#!/usr/bin/env python3

# Amazon FPGA Hardware Development Kit
#
# Copyright 2026 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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


import argparse
import logging
import os
import subprocess
import sys

dpdk_devbind = "./usertools/dpdk-devbind.py"

# Logger
logger = logging.getLogger("logger")


def check_output(args, stderr=None):
    return subprocess.Popen(args, stdout=subprocess.PIPE, stderr=stderr).communicate()[0]


def cmd_exec(cmd, check_return=True):
    # Execute the cmd, check the return and exit on failures
    ret = os.system(cmd)
    if check_return and ret:
        logger.error(f"{cmd=} failed with {ret=}, exiting")
        sys.exit(1)


def fpga_slot_str2dbdf(fpga_slot_str):
    dbdf = "None"
    found = False
    cmd = "fpga-describe-local-image-slots"
    # Exec the command first to give an error message
    # if the SDK hasn't been installed.
    cmd_exec(f"{cmd} >/dev/null 2>&1")
    fpga_slots = check_output(cmd).splitlines()
    for slot_str in fpga_slots:
        logger.debug(f"{slot_str=}")
        fields = slot_str.split()
        if len(fields) < 5:
            continue
        (_, slot_num, _, _, dbdf) = fields[:5]
        if slot_num.decode() == fpga_slot_str:
            found = True
            break
    if not found:
        logger.error(f"Could not find {fpga_slot_str=}")
        dbdf = "None"
    return dbdf if isinstance(dbdf, str) else dbdf.decode()


def unbind_fpga(dpdk_path, fpga_slot_str):
    logger.debug(f"unbind_fpga: {dpdk_path=}, {fpga_slot_str=}")

    if not os.path.exists(dpdk_path):
        logger.error(
            f"{dpdk_path=} does not exist.\nPlease specify a dpdk directory that was installed via virtual-ethernet-install.py, exiting"
        )
        sys.exit(1)

    fpga_dbdf = fpga_slot_str2dbdf(fpga_slot_str)
    if fpga_dbdf == "None":
        logger.error(f"Could not get DBDF for {fpga_slot_str=}")
        sys.exit(1)

    # Stash away the current working directory
    cwd = os.getcwd()
    scripts_path = os.path.dirname(os.path.abspath(sys.argv[0]))
    logger.debug(f"scripts directory path is {scripts_path}")

    # cd to the dpdk_path directory
    os.chdir(dpdk_path)

    if not os.path.exists(dpdk_devbind):
        logger.error(
            f"{dpdk_devbind=} does not exist.\nPlease specify a dpdk directory that was installed via virtual-ethernet-install.py, exiting"
        )
        sys.exit(1)

    logger.info(f"Unbinding FPGA device at {fpga_dbdf}")

    # Unbind the FPGA device from its current driver
    cmd_exec(f"{dpdk_devbind} -u {fpga_dbdf}")

    # cd back to the original directory
    os.chdir(cwd)

    # Print a success message
    logger.info(f"\nFPGA device unbind complete!\nDevice {fpga_dbdf} has been unbound from its driver.")


def setup_logging(debug=False):
    logging_level = logging.DEBUG if debug else logging.INFO
    logging_format = "%(levelname)s:%(asctime)s: %(message)s"
    logger.setLevel(logging_level)
    fh = logging.StreamHandler()
    fh.setLevel(logging_level)
    formatter = logging.Formatter(logging_format)
    fh.setFormatter(formatter)
    logger.addHandler(fh)


def parse_arguments():
    parser = argparse.ArgumentParser(description="Unbinds FPGA device from its current driver using DPDK devbind.")
    parser.add_argument(
        "dpdk_path",
        metavar="DPDK_DIR",
        type=str,
        help="specify the full DPDK directory path",
    )
    parser.add_argument(
        "fpga_slot",
        metavar="FPGA_IMAGE_SLOT",
        type=str,
        help="specify the fpga-image-slot.  See fpga-describe-local-image --fpga-image-slot for more info.",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        required=False,
        help="Enable debug messages",
    )
    return parser.parse_args()


def main():
    args = parse_arguments()
    setup_logging(args.debug)
    unbind_fpga(args.dpdk_path, args.fpga_slot)


if __name__ == "__main__":
    main()
