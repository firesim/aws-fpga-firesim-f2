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

xvc_install_help() {
cat << 'EOF'
SYNOPSIS
    install_xilinx_virtual_cable.sh -v VERSION [-h]

DESCRIPTION
    Installs the specified version of the Xilinx Virtual Cable driver.
    Requires installation of Vivado Lab Edition.
    Requires root/sudo privileges for installation.

OPTIONS
    -v VERSION
        Version of the Xilinx Virtual Cable driver to install (optional)
        Supported version(s):
          - 2025.1
          - 2025.2
        Default value:
            2025.2

EXAMPLES
    Install Xilinx Virtual Cable driver 2025.2:
        $ ./install_xilinx_virtual_cable.sh (defaults to version 2025.2)
        $ ./install_xilinx_virtual_cable.sh -v 2025.1
EOF
    exit 1

}

. $(git rev-parse --show-toplevel)/shared/bin/set_common_functions.sh
. $(git rev-parse --show-toplevel)/shared/bin/set_common_env_vars.sh

vivado_lab_edition_version="2025.2"
while getopts ":hv:" opt; do
  case $opt in
    h) xvc_install_help;;
    v) vivado_lab_edition_version="$OPTARG";;
    :) err_msg "Option -$OPTARG requires a value!" >&2; xvc_install_help;;
    \?) err_msg "Invalid option -$OPTARG" >&2; xvc_install_help;;
  esac
done


cd $HOME

vivado_install_path=$(sed -n 's/^Destination=//p' "${AWS_FPGA_REPO_DIR}/developer_resources/runtime_ami_builder/install_config.txt")
if ! check_for_empty_var "vivado_install_path" \
                         "$vivado_install_path" \
                         "Invalid Vivado Lab Edition install path: ${vivado_install_path}!"; then
    exit 1
fi
vivado_version_loc="${vivado_install_path}/${vivado_lab_edition_version}/Vivado_Lab"
if [[ ! -d "${vivado_version_loc}" ]]; then
    err_msg "No Vivado Lab Edition v${vivado_lab_edition_version} installation detected at ${vivado_version_loc}!"
    err_msg "Xilinx Virtual Cable requires a Vivado Lab Edition install!"
    exit 1
fi

driver_zip_file="xvc_pcie.zip"
driver_zip_file_loc="${vivado_version_loc}/data/xicom/drivers/pcie/${driver_zip_file}"
driver_executable="xvc_pcie"
driver_executable_loc="${vivado_version_loc}/bin/${driver_executable}"

info_msg "Driver zip file: ${driver_zip_file}"
info_msg "Driver zip file location: ${driver_zip_file_loc}"
info_msg "Driver executable: ${driver_executable}"
info_msg "Driver executable location: ${driver_executable_loc}"

if ! unzip $driver_zip_file_loc; then
    err_msg "Couldn't unzip driver archive!"
    err_msg "Exiting!"
    exit 1
fi

cd driver_v0.4

# Sed wizardry that replaces the default PCIE_VENDOR_ID, PCIE_DEVICE_ID,
# bar_index, and bar_offset with the ones we show here:
# https://awsdocs-fpga-f2.readthedocs-hosted.com/latest/hdk/docs/Virtual-JTAG-XVC.html#install-xvc-driver-on-f2-instances
sed -i 's/\r$//' xvc_pcie_user_config.h # First, remove any existing Windows line endings
sed -i '
    s/#define PCIE_VENDOR_ID.*/#define PCIE_VENDOR_ID  0x1D0F/
    s/#define PCIE_DEVICE_ID.*/#define PCIE_DEVICE_ID  0x9248/
    /^[[:space:]]*\.bar_index[[:space:]]*=/s/= 0x[0-9A-Fa-f]*,/= 0x2,/
    /^[[:space:]]*\.bar_offset[[:space:]]*=/s/= 0x[0-9A-Fa-f]*,/= 0x0000,/
' xvc_pcie_user_config.h

install_cmd=$(get_install_command)
packages="gcc make"
if is_ubuntu; then
    sed -i '/class_create/ s/class_create(THIS_MODULE,/class_create(/' xvc_pcie_driver_base.c
    packages="${packages} linux-headers-$(uname -r) build-essential"
else
    packages="${packages} kernel-devel-$(uname -r) kernel-headers"
fi
${install_cmd} ${packages}

if ! sudo make install; then
    err_msg "Couldn't build and install the XVC PCIe driver!"
    err_msg "Exiting!"
    exit 1
fi

info_msg "Built and installed XVC PCIe driver!"

if ! sudo depmod -a; then
    err_msg "Couldn't update the kernel modules!"
    err_msg "Exiting!"
    exit 1
fi

info_msg "Updated the kernel modules!"

if ! sudo modprobe xilinx_xvc_pci_driver; then
    err_msg "Couldn't load the XVC PCIe driver!"
    err_msg "Exiting!"
    exit 1
fi

info_msg "Initialized the XVC PCIe driver!"

if [[ -z $(lsmod | grep xilinx_xvc_pci_driver) ]]; then
    err_msg "Couldn't load the xvc driver!"
    err_msg "Exiting!"
    exit 1
fi

info_msg "XVC PCIe driver loaded and active!"

set +e
# Now we need to run the program that exercises the driver, cat its output to a file
# then exit after some time has elapsed.
timeout --kill-after=2s 20s sudo stdbuf -o0 -e0 $driver_executable_loc &> output.txt
set -e

if [[ -e output.txt ]]; then
    cat output.txt
fi

if [[ -s output.txt ]] ; then
    info_msg "XVC PCIe application executed!"
    rm output.txt
else
    err_msg "Unable to run driver executable after installation! Exit code: $?"
    err_msg "Exiting!"
    exit 1
fi

info_msg "XVC PCIe driver installation complete!"

exit 0
