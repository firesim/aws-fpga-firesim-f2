# F2 Jupyter Notebooks

Interactive notebooks for learning FPGA development on EC2 F2 instances.

| Notebook | Description |
|----------|-------------|
| [00_introduction.ipynb](https://github.com/aws/aws-fpga/blob/f2/sdk/notebooks/00_introduction.ipynb) | F2 platform overview and environment setup |
| [01_cl_axil_reg_access.ipynb](https://github.com/aws/aws-fpga/blob/f2/sdk/notebooks/01_cl_axil_reg_access.ipynb) | AXI-Lite register access — load an AFI, read/write FPGA registers from Python |

## Prerequisites

- A running **EC2 F2 instance** (e.g., f2.6xlarge) with the [FPGA Developer AMI](https://awsdocs-fpga-f2.readthedocs-hosted.com/latest/User-Guide-AWS-EC2-FPGA-Development-Kit.html#fpga-developer-ami)
  > If not using the FPGA Developer AMI, ensure Python 3 and the `venv` module are installed.

## Setup

### 1. Connect to the F2 instance with SSH tunneling

From your local machine, SSH into the instance with port forwarding. Add `-L 8888:localhost:8888` to the SSH command shown in the [EC2 Console](https://console.aws.amazon.com/ec2/) under **Instances → Connect → SSH client**:

```bash
ssh -i <path-to-key.pem> <user>@<host> -L 8888:localhost:8888
```

### 2. Build the SDK and Cython bindings

From the **repository root** on the F2 instance:

```bash
source sdk_setup.sh
```

### 3. Start the Jupyter server

```bash
cd sdk/notebooks
./start_jupyter.sh
```

The terminal will display a URL like:

```
http://localhost:8888/tree?token=abc123...
```

### 4. Open the notebooks

Open that URL in your **local machine's browser**. Navigate to the desired notebook and run the cells in order.

> ⚠️ **Cost reminder:** F2 instances incur charges while running. **Stop or terminate your instance** from the [EC2 Console](https://console.aws.amazon.com/ec2/) when finished.
