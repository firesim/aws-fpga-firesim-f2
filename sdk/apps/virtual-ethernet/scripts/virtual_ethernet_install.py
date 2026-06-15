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
import glob
import logging
import os
import platform
import sys

dpdk_git = "https://github.com/DPDK/dpdk.git"

# Use a SHA that is "known good" for SPP testing
dpdk_ver = "v24.03"

# Patch file directories
dpdk_patches_dir = "../patches/spp-dpdk"

# Logger
logger = logging.getLogger("logger")

UBUNTU = "Ubuntu"
ROCKY_LINUX = "Rocky Linux"
AMAZON_LINUX = "Amazon Linux"


def print_success(scripts_path, install_path):
    logger.info(
        "\nDPDK installation and build complete!\n"
        "A simple loopback test may be run via the following steps:\n"
        "  sudo fpga-load-local-image -S 0 -I <SDE loopback CL AGFI>\n"
        f"  sudo {scripts_path}/virtual_ethernet_setup.py {install_path}/dpdk 0\n"
        f"  cd {install_path}/dpdk\n"
        "  sudo ./build/app/dpdk-testpmd -l 0-1  -- --port-topology=loop --auto-start --tx-first --stats-period=3"
    )


def cmd_exec(cmd):
    # Execute the cmd, check the return and exit on failures
    ret = os.system(cmd)
    if ret:
        logger.error(f"{cmd=} failed with {ret=}, exiting")
        sys.exit(1)


def install_dpdk_dep():
    installed_distro = platform.freedesktop_os_release().get(
        "NAME",
        "ERROR",
    )
    if installed_distro not in {UBUNTU, ROCKY_LINUX, AMAZON_LINUX}:
        logger.error("Unsupported operating system detected! Exiting!")
        exit(1)

    if UBUNTU in installed_distro:
        cmd_exec("sudo apt -y install libnuma-dev")
        cmd_exec("sudo apt -y install libpcap-dev")
        cmd_exec("sudo apt -y install meson")
        cmd_exec("sudo apt -y install python3-pyelftools")
    elif ROCKY_LINUX in installed_distro or AMAZON_LINUX in installed_distro:
        cmd_exec("sudo yum -y install numactl-devel.x86_64")
        if ROCKY_LINUX in installed_distro:
            cmd_exec("sudo dnf -y install dnf-plugins-core")
            cmd_exec("sudo dnf config-manager --set-enabled powertools || sudo dnf config-manager --set-enabled crb")
        cmd_exec("sudo yum -y install libpcap-devel")
        cmd_exec("sudo yum -y install meson")
        if AMAZON_LINUX in installed_distro:
            cmd_exec("pip3 install pyelftools")
        else:
            # Rocky Linux supported here
            cmd_exec("sudo dnf -y install epel-release")
            cmd_exec("sudo dnf -y install python3-pyelftools")


def install_dpdk(install_path):
    logger.debug(f"install_dpdk: {install_path=}")

    if os.path.exists(install_path):
        # Allow the user to remove an already existing install_path
        logger.error(f"{install_path=} already exists.\nPlease specify a different directory or remove the existing directory, exiting")
        sys.exit(1)

    # Install DPDK dependencies
    install_dpdk_dep()

    # Stash away the current working directory
    cwd = os.getcwd()
    scripts_path = os.path.dirname(os.path.abspath(sys.argv[0]))
    logger.debug(f"{scripts_path=}")

    # Make the install_path directory
    cmd_exec(f"mkdir {install_path}")

    # Construct the path to the dpdk git patch files
    dpdk_patches_path = f"{scripts_path}/{dpdk_patches_dir}"
    logger.info(f"Patches will be installed from {dpdk_patches_path}")

    # Read in the patch filenames
    dpdk_patchfiles = []
    patchfiles_log = []
    for patchfile in sorted(glob.iglob(f"{dpdk_patches_path}/000*.patch")):
        patchfiles_log.append(f"found {patchfile=}")
        dpdk_patchfiles.append(os.path.abspath(patchfile))
    logger.debug("\n".join(patchfiles_log))

    # cd to the install_path directory
    os.chdir(install_path)
    logger.info(f"Cloning {dpdk_ver} version of {dpdk_git} into {install_path}")
    cmd_exec(f"git clone -b {dpdk_ver} {dpdk_git}")

    # cd to the dpdk directory
    os.chdir("dpdk")

    # Apply the patches
    patches_log = []
    for patchfile in dpdk_patchfiles:
        patches_log.append(f"Applying patch from {patchfile=}")
        cmd_exec(f"git am {patchfile}")
    logger.info("\n".join(patches_log))

    # Configure the DPDK build
    cmd_exec("meson -Dexamples=all build")
    cmd_exec("ninja -C build")

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
    parser = argparse.ArgumentParser(description="Installs the DPDK (master) and applies DPDK SPP PMD related patches.")
    parser.add_argument(
        "install_path",
        metavar="INSTALL_DIR",
        type=str,
        help="specify the full installation directory path",
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
    install_dpdk(args.install_path)


if __name__ == "__main__":
    main()
