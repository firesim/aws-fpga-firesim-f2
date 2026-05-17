"""
* Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
*
* Licensed under the Apache License, Version 2.0 (the "License"). You may
* not use this file except in compliance with the License. A copy of the
* License is located at
*
*     http://aws.amazon.com/apache2.0/
*
* or in the "license" file accompanying this file. This file is distributed
* on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
* express or implied. See the License for the specific language governing
* permissions and limitations under the License.

* This example demonstrates various FPGA management operations using the C API, including:
* - Clearing FPGA image slots
* - Loading and managing Amazon FPGA Images (AFIs)
* - Setting and reading virtual DIP switches
* - Handling AFI caches
*
* 0. Prerequisites: This example must be run on an F2 instance with an FPGA. Source the sdk
*    by navigating to the root of this repo and running `source ./sdk_setup.sh`.
* 1. The example initializes the FPGA management wrapper
* 2. Demonstrates clearing a local image from an FPGA slot
* 3. Loads a specific AFI (Streaming Data Engine CL Example)
* 4. Shows both synchronous and asynchronous clearing of local images
* 5. Demonstrates setting and reading virtual DIP switches
* 6. Illustrates the use of the CLEAR_AFI_CACHE flag
* 7. Performs synchronous loading of a local image
* 8. Uses describe_local_image to verify and display FPGA status and metrics
"""

from typing import Any

from fpga_mgmt_wrapper import FpgaMgmt
from utils import convert_info_to_json, setup_logger


def main() -> None:
    setup_logger()

    get_hw_metrics = 1 << 1
    clear_afi_cache = 1 << 8

    fpga_mgmt_wrapper = FpgaMgmt()

    slot = 0
    image_info: dict[str, Any] = fpga_mgmt_wrapper.clear_local_image(slot)

    status: str = image_info["status"]
    while status == "busy":
        status = fpga_mgmt_wrapper.describe_local_image(slot, get_hw_metrics)["status"]

    public_cl_sde_afi_id = "agfi-0925b211f5a81b071"
    print(f"Loading AFI for SDE (Streaming Data Engine) CL Example: {public_cl_sde_afi_id}\n")

    fpga_mgmt_wrapper.load_local_image(slot, public_cl_sde_afi_id)
    fpga_mgmt_wrapper.set_cmd_delay_msec(value=100000)

    info: dict[str, Any] = fpga_mgmt_wrapper.describe_local_image(slot, get_hw_metrics)
    print(f"Info {convert_info_to_json(info)}\n")

    print("Clearing local image synchronously\n")
    fpga_mgmt_wrapper.clear_local_image_sync(slot, timeout=60000, delay_msec=2)

    vdip_value = 1 << 5
    print(f"Setting the dip switch at {vdip_value}")
    fpga_mgmt_wrapper.set_vDIP(slot, vdip_value)

    vdip_status: int = fpga_mgmt_wrapper.get_vDIP_status(slot)
    print(f"Dip switch state: {vdip_status}\n")

    print("Describing image before CLEAR_AFI_CACHE flag is set")
    info = fpga_mgmt_wrapper.describe_local_image(slot, get_hw_metrics)
    print(f"Info {info['metrics']['cached_agfis']}")

    info = fpga_mgmt_wrapper.describe_local_image(slot, clear_afi_cache)
    print(f"Info {info['metrics']['cached_agfis']}\n")

    print("Clearing local image synchronously\n")
    fpga_mgmt_wrapper.clear_local_image_sync(slot, timeout=60000, delay_msec=2)

    print("Loading local image synchronously\n")
    fpga_mgmt_wrapper.load_local_image_sync_flags(slot, public_cl_sde_afi_id, get_hw_metrics, timeout=60000, delay_msec=2)

    info = fpga_mgmt_wrapper.describe_local_image(slot, get_hw_metrics)
    print(f"Info {convert_info_to_json(info)}")


if __name__ == "__main__":
    main()
