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

rocky_python_update_help() {
cat << 'EOF'
SYNOPSIS
    update_rocky_python.sh [-h]

DESCRIPTION
    Updates Python 3 to version 3.12 on Rocky Linux systems.
    Sets Python 3.12 as the default python3 alternative.
    Requires root/sudo privileges for installation.
EOF
    exit 1
}

while getopts ":h" opt; do
  case $opt in
    h) rocky_python_update_help;;
    \?) echo "ERROR: Invalid option -$OPTARG" >&2 && exit 1;;
  esac
done

if ! [[ $(cat /etc/os-release) == *"Rocky Linux"* ]]; then
    echo "ERROR: This script is for use on Rocky Linux only!"
    echo "ERROR: Exiting!"
    exit 1
fi

sudo dnf install -y python3.12-devel
sudo dnf install -y python3.12-pip
sudo dnf config-manager --set-enabled powertools
sudo dnf install -y libpcap-devel gcc make
sudo alternatives --set python3 /usr/bin/python3.12
sudo ln -sf /usr/bin/pip3.12 /usr/bin/pip3
/usr/bin/pip3.12 install distro

echo "INFO: Rocky 8.10 Python3 update complete!"
