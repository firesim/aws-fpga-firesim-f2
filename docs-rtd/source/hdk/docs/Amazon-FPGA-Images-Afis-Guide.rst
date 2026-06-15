Amazon FPGA Images (AFIs) Guide
===============================

Overview
--------

Amazon FPGA Images (AFIs) are the compiled and encrypted FPGA designs
that can be loaded onto AWS FPGA instances (F2). This guide explains how
to create, manage, and understand AFIs in the AWS ecosystem.

What are AFIs and AGFIs?
------------------------

AWS provides two important identifiers when creating AFIs:

.. list-table::
   :header-rows: 1
   :widths: auto

   * - Identifier
     - Scope
     - Usage
     - Example
   * - **AFI ID** (`FpgaImageId`)
     - Regional
     - Managing AFIs via AWS EC2 CLI/SDK APIs
     - ``afi-06d0ffc989feeea2a``
   * - **AGFI ID** (`FpgaImageGlobalId`)
     - Global
     - Loading AFIs onto FPGA slots from within instances
     - ``agfi-0f0e045f919413242``

Amazon FPGA Image (AFI)
~~~~~~~~~~~~~~~~~~~~~~~

An AFI is a compiled, encrypted, and signed FPGA design that can be
loaded onto AWS FPGA instances. AFIs are created from Design Checkpoint
(DCP) files generated during the FPGA development process. An AFI ID is
a regional identifier that changes when an AFI is copied across regions.

Amazon Global FPGA Image ID (AGFI)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The AGFI is a **globally unique identifier** that references a specific
AFI across all AWS regions enabling seamless AFI/AMI combinations. It’s
used by FPGA management tools within EC2 instances to load or manage
AFIs on FPGA slots.

AFI Creation Methods
--------------------

Prerequisites
~~~~~~~~~~~~~

- Design Checkpoint (DCP) tarball file
- Required AWS permissions

Option 1: Programmatic AFI Creation (Recommended)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The AWS FPGA HDK provides a Python script for streamlined AFI creation
once a DCP is generated. Developers can call
`create_afi.py <https://github.com/aws/aws-fpga/tree/f2/hdk/scripts/create_afi.py>`__ (with required Python
modules included in `start_venv.sh <https://github.com/aws/aws-fpga/tree/f2/hdk/scripts/start_venv.sh>`__)
without any arguments to interactively input their AFI parameters:

.. code-block:: bash

   source $AWS_FPGA_REPO_DIR/hdk/scripts/start_venv.sh
   $AWS_FPGA_REPO_DIR/hdk/scripts/create_afi.py

Alternatively, developers can read more in the help menu on how to pass
all parameters in together:

.. code-block:: bash

   $AWS_FPGA_REPO_DIR/hdk/scripts/create_afi.py --help

Option 2: Manual AFI Creation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For more control over the AFI creation process, manually submit the DCP
file using the AWS CLI tool.

Step 1: Prepare Shell Environment
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Set up the user shell environment variables:

.. code-block:: bash

   export DCP_BUCKET_NAME='user-dcp-bucket-name'
   export DCP_FOLDER_NAME='user-dcp-folder'
   export LOGS_BUCKET_NAME='user-logs-bucket-name'
   export LOGS_FOLDER_NAME='user-logs-folder'
   export REGION='aws-region-code-eg-us-east-1'
   export DCP_TARBALL_TO_INGEST='path/to/user/YYYY_MM_DD-HHMMSS.Developer_CL.tar'

**Note**: Confirm the region supports FPGA images by checking the
`Amazon EC2 instance types by Region
index <https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-instance-regions.html>`__

Step 2: Create S3 Storage
^^^^^^^^^^^^^^^^^^^^^^^^^

Create S3 buckets and upload the DCP file:

.. code-block:: bash

   # Create S3 bucket for DCP files
   aws s3 mb s3://${DCP_BUCKET_NAME} --region ${REGION}

   # Create folder for DCP files
   aws s3 mb s3://${DCP_BUCKET_NAME}/${DCP_FOLDER_NAME}/

   # Upload DCP tarball to S3
   aws s3 cp ${DCP_TARBALL_TO_INGEST} s3://${DCP_BUCKET_NAME}/${DCP_FOLDER_NAME}/

Create storage for AFI creation logs:

.. code-block:: bash

   # Create folder for logs
   aws s3 mb s3://${LOGS_BUCKET_NAME}/${LOGS_FOLDER_NAME}/ --region ${REGION}

   # Create placeholder file to establish the folder structure
   touch LOGS_FILES_GO_HERE.txt
   aws s3 cp LOGS_FILES_GO_HERE.txt s3://${LOGS_BUCKET_NAME}/${LOGS_FOLDER_NAME}/

**Important**: The trailing ``/`` is required after folder names in S3
paths.

Step 3: Submit AFI Creation Request
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

   export DCP_TARBALL_NAME=$(basename ${DCP_TARBALL_TO_INGEST})
   export CL_DESIGN_NAME='user-design-name'
   export CL_DESIGN_DESCRIPTION="Description of the FPGA design"

   # Submit AFI creation request
   aws ec2 create-fpga-image \
       --name ${CL_DESIGN_NAME} \
       --description "${CL_DESIGN_DESCRIPTION}" \
       --input-storage-location Bucket=${DCP_BUCKET_NAME},Key=${DCP_FOLDER_NAME}/${DCP_TARBALL_NAME} \
       --logs-storage-location Bucket=${LOGS_BUCKET_NAME},Key=${LOGS_FOLDER_NAME}/ \
       --region ${REGION}

   # expected response format:
   {
       "FpgaImageId": "afi-09953582f46c45b17",
       "FpgaImageGlobalId": "agfi-0925b211f5a81b071"
   }

The `create-fpga-images
API <https://docs.aws.amazon.com/cli/latest/reference/ec2/create-fpga-image.html#output>`__
or `AWS CLI FPGA Commands <./AWS-CLI-FPGA-Commands.html>`__ documentation
can be used to interpret results.

Monitoring AFI Creation
-----------------------

Check AFI Status
~~~~~~~~~~~~~~~~

Use the AFI ID returned by the ``create-fpga-image`` command to monitor
the creation progress:

.. code-block:: bash

   aws ec2 describe-fpga-images --fpga-image-ids afi-09953582f46c45b17 --region ${REGION}

The `describe-fpga-images
API <https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-fpga-images.html#output>`__
or `AWS CLI FPGA Commands <./AWS-CLI-FPGA-Commands.html>`__ documentation
can be used to interpret results.

Wait for AFI Generation with Email Notifications
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The ``create-fpga-image`` command submits a customer’s DCP to AWS to
create an AFI in the background. This process can take hours depending
on the size of the design. The ``wait_for_afi.py`` script will wait for
the process to complete and optionally send an email with the results.
The return code of the script will be 0 if the AFI was successfully
created. The script uses the `AWS Simple Notification Service
(SNS) <https://docs.aws.amazon.com/sns/latest/dg/welcome.html>`__ to
send email notifications which requires permissions to create an SNS
topic, add a subscription, and publish to the SNS topic. By default the
topic name used is ``CREATE_AFI`` but the topic name can be changed
using the ``--sns-topic`` option.

**Example usage:**

.. code-block:: bash

   # Wait for AFI without email notification
   wait_for_afi.py --afi afi-09953582f46c45b17

   # Wait and send email notification when complete
   wait_for_afi.py --afi afi-09953582f46c45b17 --max-minutes 120 \
                   --email user@example.com --sns-topic MY_TOPIC

**Note:** When using ``create_afi.py`` in interactive mode, users will
be prompted whether to receive email notifications during the AFI
generation process.

Using AFIs in FPGA Instances
----------------------------

Once an AFI is ``available``, load it onto FPGA slots within F2
instances using the **AGFI ID**:

.. code-block:: bash

   # Load AFI onto FPGA slot 0
   sudo fpga-load-local-image -S 0 -I agfi-0925b211f5a81b071

   # Verify AFI is loaded
   sudo fpga-describe-local-image -S 0

Troubleshooting
---------------

- **AFI creation fails**: Check the logs in the designated S3 logs
  folder
- **S3 permissions**: Verify the AWS credentials have appropriate S3 and
  EC2 permissions
- **DCP file format**: Ensure the DCP tarball follows `AWS FPGA HDK
  requirements <./../README.html#step-4-build-cl-design-check-point-dcp>`__
- For any issues with the devkit documentation or code, please open a
  `GitHub issue <https://github.com/aws/aws-fpga/issues>`__ with all
  steps to reproduce
- For questions about F2 instances, please open a `re:Post issue with
  the ‘FPGA Development’
  tag <https://repost.aws/tags/TAc7ofO5tbQRO57aX1lBYbjA/fpga-development>`__

`Back to Home <../../index.html>`__
