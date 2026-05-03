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
pktgen_git = "git://dpdk.org/apps/pktgen-dpdk"
numa_git = "https://github.com/numactl/numactl.git"

# Use a version that is "known good" for use with pktgen
dpdk_ver = "v24.03"
pktgen_ver = "pktgen-24.03.1"
numa_ver = "v2.0.12"

# Patch file directory
patches_dir = "../patches/pktgen-dpdk"

# DPDK make target
make_tgt = "x86_64-native-linuxapp-gcc"

# Logger
logger = logging.getLogger("logger")


def print_success(scripts_path, install_path):
    logger.info(
        "pktgen-dpdk installation and build complete!\n"
        "pktgen-dpdk may be setup via the following step:\n"
        f"  sudo {scripts_path}/virtual_ethernet_pktgen_setup.py {install_path} "
        "--eni_dbdf <ENI_DBDF> --eni_ethdev <ENI_ETHDEV>"
    )


def cmd_exec(cmd):
    # Execute the cmd, check the return and exit on failures
    ret = os.system(cmd)
    if ret:
        logger.error(f"{cmd=} failed with {ret=}, exiting")
        sys.exit(1)


def install_dpdk_dep():
    installed_distro = platform.freedesktop_os_release().get("NAME", "")
    if "Ubuntu" in installed_distro:
        cmd_exec("sudo apt -y install libnuma-dev")
        cmd_exec("sudo apt -y install libpcap-dev")
        cmd_exec("sudo apt -y install meson")
        cmd_exec("sudo apt -y install python3-pyelftools")
        cmd_exec("sudo apt -y install autoconf")
        cmd_exec("sudo apt -y install libtool")
    else:
        cmd_exec("sudo yum -y install numactl-devel")
        if "Rocky" in installed_distro:
            cmd_exec("sudo dnf -y install dnf-plugins-core")
            cmd_exec("sudo dnf config-manager --set-enabled powertools || sudo dnf config-manager --set-enabled crb")
        cmd_exec("sudo yum -y install libpcap-devel")
        cmd_exec("sudo yum -y install meson")
        cmd_exec("sudo yum -y install python3-pyelftools")
        cmd_exec("sudo yum -y install autoconf")
        cmd_exec("sudo yum -y install libtool")


def install_pktgen_dpdk(install_path):
    logger.debug(f"{install_path=}")

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

    # Construct the path to the git patch files
    patches_path = f"{scripts_path}/{patches_dir}"
    logger.info(f"Patches will be installed from {patches_path}")
    # Read in the pktgen patch filenames
    patchfiles = []
    patchfiles_log = []
    for patchfile in sorted(glob.iglob(f"{patches_path}/000*.patch")):
        patchfiles_log.append(f"found {patchfile=} for pktgen")
        patchfiles.append(os.path.abspath(patchfile))
    if patchfiles_log:
        logger.debug("\n".join(patchfiles_log))
    # Read in the dpdk patch filenames
    dpdk_patchfiles = []
    dpdk_patchfiles_log = []
    for dpdk_patchfile in sorted(glob.iglob(f"{patches_path}/dpdk*.patch")):
        dpdk_patchfiles_log.append(f"found {dpdk_patchfile=}")
        dpdk_patchfiles.append(os.path.abspath(dpdk_patchfile))
    if dpdk_patchfiles_log:
        logger.debug("\n".join(dpdk_patchfiles_log))

    # cd to the install_path directory
    os.chdir(install_path)

    # Clone the DPDK repo
    os.chdir(install_path)
    logger.info(f"Cloning {dpdk_ver} version of {dpdk_git} into {install_path}")
    cmd_exec(f"git clone -b {dpdk_ver} {dpdk_git}")

    # cd to the dpdk directory
    os.chdir("dpdk")

    # Apply the patches
    patches_log = []
    for dpdk_patchfile in dpdk_patchfiles:
        patches_log.append(f"Applying patch for {dpdk_patchfile=}")
        cmd_exec(f"git apply {dpdk_patchfile}")
    logger.info("\n".join(patches_log))

    # Configure the DPDK build
    cmd_exec("meson build")
    cmd_exec("ninja -C build")
    os.chdir("build")
    cmd_exec("sudo meson install")

    # Clone the numactl repo
    os.chdir(install_path)
    logger.info(f"Cloning {numa_ver} version of {numa_git} into {install_path}")
    cmd_exec(f"git clone -b {numa_ver} {numa_git}")

    # cd to the numactl directory
    os.chdir("numactl")

    # Configure the numactl build
    cmd_exec("./autogen.sh")
    cmd_exec("./configure")
    cmd_exec("make")
    cmd_exec("sudo make install")

    # Clone the pktgen-dpdk repo
    os.chdir(install_path)
    logger.info(f"Cloning {pktgen_ver} version of {pktgen_git} into {install_path}")
    cmd_exec(f"git clone -b {pktgen_ver} {pktgen_git}")

    # cd to the pktgen-dpdk directory
    os.chdir("pktgen-dpdk")

    # Apply the patches
    patches_log = []
    for patchfile in patchfiles:
        patches_log.append(f"Applying patch for {patchfile=}")
        cmd_exec(f"git apply {patchfile}")
    if patches_log:
        logger.info("\n".join(patches_log))

    # Build pktgen-dpdk
    cmd_exec("meson build")
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
    parser = argparse.ArgumentParser(description="Installs pktgen-dpdk and applies pktgen related patches for ENA use.")
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
    install_pktgen_dpdk(args.install_path)


if __name__ == "__main__":
    main()
