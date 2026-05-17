# Amazon FPGA Runtime AMI Builder
#
# Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

f2_runtime_utils_install_help() {
cat << 'EOF'
SYNOPSIS
    install_f2_runtime_utils.sh [-h]

DESCRIPTION
    Installs distribution-specific runtime dependencies and utilities for the F2 platform.
    Requires root/sudo privileges for installation.

EOF
    exit 1
}

while getopts ":h" opt; do
  case $opt in
    h) f2_runtime_utils_install_help;;
    \?) echo "ERROR: Invalid option -$OPTARG" >&2 && exit 1;;
  esac
done

. $(git rev-parse --show-toplevel)/shared/bin/set_common_functions.sh

common_packages_to_install=(
    bzip2
    csh
    environment-modules
    gcc
    gdb
    git
    git-lfs
    nvme-cli
    numactl
    pciutils
    perl
    python3-pip
    tcl
    tmux
    unzip
    wget
    xauth
)

ubuntu_utils_to_install=(
    build-essential
    devmem2
    dkms
    libjpeg-turbo8-dev
    libopencv-dev
    libpng-dev
    libsecret-1-dev
    libtiff5-dev
    libtinfo6
    libx11-6
    libx11-dev
    libxi6
    libxkbfile-dev
    libxrender1
    libxtst6
    linux-headers-$(uname -r)
    ocl-icd-libopencl1
    ocl-icd-opencl-dev
    opencl-headers
    python3.12-venv
    screen
    tcl-dev
)

rhel_utils_to_install=(
    cmake
    epel-release
    gcc-c++
    gdb
    kernel-devel
    kernel-headers
    libjpeg-turbo-devel
    libpng-devel
    libsecret-devel
    libstdc++
    libtiff-devel
    libtiff
    libX11-devel
    libX11
    libXi
    libxkbfile
    libXrender
    libXtst
    ncurses-libs
    ncurses-compat-libs
    ocl-icd
    tcl-devel
)

utils_to_install=""
install_command=""

info_msg "Installing runtime dependencies for the F2 platform!"

if is_ubuntu; then
    sudo apt update
    info_msg "Installing dependencies for Ubuntu!"
    utils_to_install=("${ubuntu_utils_to_install[@]}")
    export DEBIAN_FRONTEND="noninteractive"
elif is_rocky_linux; then
    info_msg "Installing dependencies for Rocky Linux!"
    utils_to_install=("${rhel_utils_to_install[@]}")
else
    err_msg "Couldn't find a package list for this distro!"
    exit 1
fi

install_command=$(get_install_command)
check_for_empty_var "install_command" "$install_command" "Package manager detection failed!" || exit 1

info_msg "Installing common packages: ${common_packages_to_install[*]}"
if ! $install_command "${common_packages_to_install[@]}"; then
    err_msg "Failed to install common packages: ${common_packages_to_install[*]}"
    exit 1
fi

info_msg "Installing distribution-specific utilities: ${utils_to_install[*]}"
if ! $install_command "${utils_to_install[@]}"; then
    err_msg "Failed to install utilities: ${utils_to_install[*]}"
    exit 1
fi

info_msg "F2 runtime utilities installed successfully!"
