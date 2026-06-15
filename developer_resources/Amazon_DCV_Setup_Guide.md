# Using EC2 Instances with a GUI

## Table of Contents

- [What is Amazon DCV?](#what-is-amazon-dcv)
- [Installing the Amazon DCV Server on an Amazon EC2 Instance](#installing-the-amazon-dcv-server-on-an-amazon-ec2-instance)
  - [Prerequisites](#prerequisites)
  - [Amazon DCV Server Installation](#amazon-dcv-server-installation)
  - [Post-Installation Checks](#post-installation-checks)
  - [Setting a Password for Your Sessions](#setting-a-password-for-your-sessions)
  - [Setting Security Rules to Allow Traffic on Port 8443](#setting-security-rules-to-allow-traffic-on-port-8443)
- [Amazon DCV Client Installation](#amazon-dcv-client-installation)
- [Basic Session Management](#basic-session-management)
  - [Quick Session Startup](#quick-session-startup)

## What is Amazon DCV?

[Amazon DCV](https://docs.aws.amazon.com/dcv/latest/adminguide/what-is-dcv.html) is a high-performance remote
display protocol that provides customers with a secure way to deliver remote desktops and application streaming
from any cloud or data center to any device, over varying network conditions. With Amazon DCV and Amazon EC2,
customers can run graphics-intensive applications remotely on EC2 instances and stream the results to simpler
client machines, eliminating the need for expensive dedicated workstations.

This guide helps customers developing for AWS F2 instances create a virtual desktop running on EC2 instances
based on the [FPGA Developer AMI](../User_Guide_AWS_EC2_FPGA_Development_Kit.md#fpga-developer-ami).
The FPGA Developer AMI has pre-installed tools which are license free. Combined with DCV, this enables
development using Vivado or Vitis' graphical Integrated Design Environment (IDE), which provides an intuitive
graphical user interface (GUI) to visualize FPGA development in the cloud.

## Installing the Amazon DCV Server on an Amazon EC2 Instance

### Prerequisites

1. [Instance and IAM Configuration for DCV Licensing](https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-license.html#dcv-lic-req)
2. [Dependency Installation](https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-prereq.html#linux-prereq-gui)
    - ⚠️  DO NOT PERFORM STEP 3! Upgrading may impact the stability of development kit software!
3. [Protocol Setup](https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-prereq.html#linux-prereq-wayland)
4. [Driver Installation and Setting Virtual Display Resolution](https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-prereq.html#linux-prereq-nongpu)

### Amazon DCV Server Installation

In the [install procedure described here](https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-server.html#linux-server-install), follow steps 1 through 5, 7, and 8.
When step 9 is reached, do the following:

``` bash
    sudo apt --fix-broken install
    sudo apt install -y mesa-utils
    sudo dpkg -i nice-dcv-gl_2024.0.1096-1_amd64.ubuntu<2404 or 2004>.deb
```

### Post-Installation Checks

[This section of the post-installation check](https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-checks.html#checks-xserver) should be run to ensure that all aspects of the setup are working as expected.

> **Note:** After running `sudo dcvgldiag`, errors like the ones below may appear. If the instance type in use does not have an Nvidia or AMD GPU attached to it, messages like "No NVIDIA card found" can be safely disregarded. This will not affect the ability to view or access the graphical desktop via remote session.

```text
Amazon DCV 2025.0 (r20103) - Diagnostic Script
============================================

Date:             Tue, 24 Mar 2026 21:43:25 +0000

Host:             ip-012-34-56-789
Architecture:     x86_64
Operating System: Ubuntu 24.04.1 LTS
Kernel Version:   6.8.0-1021-aws
Nvidia GPU:       unknown
Nvidia Driver:    unknown
Runlevel:         5

X configuration file: /etc/X11/xorg.conf

DCV GL (GLVND) is enabled for 64 bit applications.

Running tests: ............ DONE

ERROR (1/4)

  There are no devices in '/etc/X11/xorg.conf' configured to use the NVIDIA driver.

  Please, check the X Server configuration.


ERROR (2/4)

  DCV cannot access the 3D X Server [:0.0].

  Please, stop the 3D X Server and disable DCV with 'dcvgladmin disable'.
Then enable DCV with 'dcvgladmin enable' and restart the 3D X Server.


ERROR (3/4)

  The 3D X Server [:0.0] does not support the GLX extension

  Please, check your X server configuration and restart it.


ERROR (4/4)

  The 3D X Server [:0.0] does not run with depth 24

  Please, check your X server configuration and restart it.


WARNING (1/2)

  The X server configuration does not contain the "UseDisplayDevice" "none" option. Ignore this warning if a monitor is connected to the video card adapter.

  In case there is no monitor connected to the video card adapter associated to DISPLAY=:0.0, you may need to add the "UseDisplayDevice" "none" option to the appropriate "Device" section (of the '/etc/X11/xorg.conf' file.


WARNING (2/2)

  No NVIDIA card found

  Please, check a NVIDIA card is installed.



There are 4 errors and 2 warnings.

A detailed report about the tests is available in '/home/ubuntu/nice-dcv-2025.0-20103-ubuntu2404-x86_64/nice-dcv-2025.0-20103-ubuntu2404-x86_64/dcvgldiag-19NNNr'
```

### Setting a Password for Your Sessions

In order to connect to an Amazon DCV session, a password must be set for the user on the EC2 instance.
This can be done with this command:

``` bash
sudo passwd $USER
```

### Setting Security Rules to Allow Traffic on Port 8443

In order for Amazon DCV to communicate with the EC2 instance, TCP and UDP traffic must be allowed on port 8443.
This can be accomplished by updating the security group used to launch the instance.

## Basic Session Management on EC2 (Server Side)

To begin, run the following commands on the EC2 instance:

``` bash
sudo systemctl isolate multi-user.target (Ubuntu 20.04 only)
sudo systemctl restart dcvserver.service
sudo systemctl restart dcvsessionlauncher.service
```
Next, refer to the [session management user guide here](https://docs.aws.amazon.com/dcv/latest/adminguide/managing-sessions.html). This guide will provide all of the information needed to customize and manage Amazon DCV sessions.

### Quick Session Startup

To start a session, use the following command:

``` bash
dcv create-session $your_session_number
dcv list-sessions
Session: '1' (owner:ubuntu type:virtual)
```

Sessions may be given any number, but no two sessions may have the same number.

## (Optional) Amazon DCV Client Installation (Client Side)

The [Amazon DCV client](https://www.amazondcv.com/) should be installed on the local machine and is used to view the virtual desktop on the EC2 instance.

## Connecting to the Session (Client Side)

In the DCV Client Viewer application, enter the connection details:
- **Hostname or IP Address**: Can be the public IP of the EC2 instance or the full URL format `https://user@ec2_instance_ip_address:8443`

- Click `Connect`, then click "Trust and Connect"

Sessions can be accessed using the Amazon DCV client on the local machine or via the [DCV console in your web browser](https://docs.aws.amazon.com/dcv/latest/userguide/using-connecting-browser-connect.html).

Enter `https://user@ec2_instance_ip_address:8443` into the `Hostname or IP Address` box and click `Connect`. Next, click "Trust and Connect".

Enter the password set in [Post-Installation Checks](#post-installation-checks) in the `Password` box and click `Login`.

At this point, the session should begin and a virtual desktop will be displayed after a brief delay.

Now, open a terminal and run the following command: `source /etc/profile.d/default_module.sh`. The GUI-enabled EC2 Instance is now ready to use.

``` bash
ubuntu@ip-1-2-3-4:~$ source /etc/profile.d/default_module.sh
ubuntu@ip-1-2-3-4:~$ vivado -version
vivado v2024.1 (64-bit)
```

