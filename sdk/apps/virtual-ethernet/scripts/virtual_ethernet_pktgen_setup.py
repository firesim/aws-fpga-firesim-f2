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
import platform
import subprocess
import sys

# DPDK make config target
make_tgt = "x86_64-native-linuxapp-gcc"
try:
    if "aarch64" in platform.processor():
        make_tgt = "arm64-armv8a-linuxapp-gcc"
except AttributeError:
    pass

dpdk_devbind = "./usertools/dpdk-devbind.py"
num_2mb_hugepages = 16384

# Logger
logger = logging.getLogger("logger")


def print_success(scripts_path, install_path):
    logger.info(
        "\nDPDK setup complete!\n"
        "pktgen-dpdk may be run via the following steps:\n"
        f"  cd {install_path}/pktgen-dpdk\n"
        f"  sudo ./app/{make_tgt}/pktgen -l 0,1 -n 4 --proc-type auto --log-level 7 "
        f"--socket-mem 2048 --file-prefix pg -- -T -P -m [1].0 "
        f"-f {scripts_path}/pktgen-ena.pkt"
    )


def check_output(args, stderr=None):
    return subprocess.Popen(args, stdout=subprocess.PIPE, stderr=stderr).communicate()[0]


def cmd_exec(cmd, check_return=True):
    # Execute the cmd, check the return and exit on failures
    ret = os.system(cmd)
    if check_return and ret:
        logger.error(f"{cmd=} failed with {ret=}, exiting")
        sys.exit(1)


def setup_dpdk(install_path, eni_dbdf, eni_ethdev):
    logger.debug(f"{install_path=}")

    if not os.path.exists(install_path):
        logger.error(
            f"{install_path=} does not exist.\n"
            "Please specify a directory that was installed via virtual-ethernet-pktgen-install.py, exiting"
        )
        sys.exit(1)

    if eni_dbdf == "None" or eni_ethdev == "None":
        logger.error(f"{eni_dbdf=}, {eni_ethdev=} is invalid, exiting")
        sys.exit(1)

    if eni_ethdev == "eth0":
        logger.error(
            f"Using {eni_ethdev=} for pktgen will disrupt your primary network interface\n"
            "Please specify a different eni_ethdev such as eth1, exiting"
        )
        sys.exit(1)

    # Stash away the current working directory
    cwd = os.getcwd()
    scripts_path = os.path.dirname(os.path.abspath(sys.argv[0]))
    logger.debug(f"{scripts_path=}")

    # cd to the install_path directory
    os.chdir(f"{install_path}")

    if not os.path.exists(dpdk_devbind):
        logger.error(
            f"{dpdk_devbind=} does not exist.\n"
            "Please specify a directory that was installed via virtual-ethernet-pktgen-install.py, exiting"
        )
        sys.exit(1)

    # Mount '/mnt/huge', if needed
    if not os.path.exists("/mnt/huge"):
        cmd_exec("mkdir /mnt/huge")

    cmd_exec("mount -t hugetlbfs nodev /mnt/huge")

    # Configure hugepages
    cmd_exec(f"echo {num_2mb_hugepages} > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages")

    cmd_exec("modprobe vfio enable_unsafe_noiommu_mode=1")
    cmd_exec("modprobe vfio-pci")

    # Bind the ENI device to to DPDK
    cmd_exec(f"ip link set {eni_ethdev} down")
    cmd_exec(f"python3 {dpdk_devbind} --bind=vfio-pci {eni_dbdf}")

    # cd back to the original directory
    os.chdir(cwd)

    # Print a success message
    print_success(scripts_path, install_path)


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
    parser = argparse.ArgumentParser(description="Sets up DPDK for pktgen-dpdk use.")
    parser.add_argument(
        "install_path",
        metavar="INSTALL_DIR",
        type=str,
        help="specify the full installation directory path that was used as an argument to virtual-ethernet-pktgen-install.py",
    )
    parser.add_argument(
        "--eni_dbdf",
        metavar="ENI_DBDF",
        type=str,
        default="None",
        help="specify the ENI DBDF. e.g. see 'lspci' output '0000:00:04.0' for Ethernet controller device 1d0f:ec20",
    )
    parser.add_argument(
        "--eni_ethdev",
        metavar="ENI_ETHDEV",
        type=str,
        default="None",
        help="specify the ENI Ethernet device. e.g. see 'ifconfig' output and the 'eth1' device",
    )
    parser.add_argument("--debug", action="store_true", required=False, help="Enable debug messages")
    return parser.parse_args()


def main():
    args = parse_arguments()
    setup_logging(args.debug)
    setup_dpdk(args.install_path, args.eni_dbdf, args.eni_ethdev)


if __name__ == "__main__":
    main()
