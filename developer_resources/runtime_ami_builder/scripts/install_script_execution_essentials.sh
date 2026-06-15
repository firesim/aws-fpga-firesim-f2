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

script_execution_essentials_help() {
cat << 'EOF'
SYNOPSIS
    install_script_execution_essentials.sh [-h]

DESCRIPTION
    Installs essential tools required to execute other installer scripts in the runtime AMI builder.
    Requires root/sudo privileges for installation.

EOF
    exit 1
}

while getopts ":h" opt; do
  case $opt in
    h) script_execution_essentials_help;;
    \?) echo "ERROR: Invalid option -$OPTARG" >&2 && exit 1;;
  esac
done

# Base Rock AMI doesn't come with git like Ubuntu does
. $(git rev-parse --show-toplevel)/shared/bin/set_common_functions.sh
. $(git rev-parse --show-toplevel)/shared/bin/set_common_env_vars.sh

install_command=$(get_install_command)
check_for_empty_var "install_command" "$install_command" "Package manager detection failed!" || exit 1

$install_command zip
$install_command wget
if is_ubuntu; then
    sudo apt-get update
    $install_command build-essential
else
    sudo dnf groupinstall -y "Development tools"
fi

info_msg "Individual installer script essentials installed successfully!"
