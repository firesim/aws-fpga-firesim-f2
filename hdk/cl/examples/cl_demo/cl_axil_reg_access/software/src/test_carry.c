// ============================================================================
// Amazon FPGA Hardware Development Kit
//
// Copyright 2026 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Amazon Software License (the "License"). You may not use
// this file except in compliance with the License. A copy of the License is
// located at
//
//    http://aws.amazon.com/asl/
//
// or in the "license" file accompanying this file. This file is distributed on
// an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
// implied. See the License for the specific language governing permissions and
// limitations under the License.
// ============================================================================

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

#include "fpga_pci.h"
#include "fpga_mgmt.h"
#include "utils/lcd.h"

#include "cl_axil_reg_access_def.h"
#include "cl_axil_reg_access_utils.h"

static const struct logger *logger = &logger_stdout;

int main(int argc, char **argv)
{
    int rc = 0;
    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;
    uint32_t sum, carry;
    uint32_t value_a, value_b;
    int num_operations = 1000;
    int valid_carry_count = 0;

    // Initialize logging
    rc = log_init("test_carry");
    fail_on(rc, out, "Unable to initialize the log.");
    rc = log_attach(logger, NULL, 0);
    fail_on(rc, out, "Unable to attach to the log.");

    // Initialize FPGA management library
    rc = fpga_mgmt_init();
    fail_on(rc, out, "Unable to initialize the fpga_mgmt library");

    // Attach to PCIe BAR
    rc = fpga_pci_attach(SLOT_ID, CL_AXIL_DEMO_APP_PF, CL_AXIL_DEMO_BAR_ID, CL_AXIL_DEMO_PCI_FLAGS, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d\nCheck if the CL_DEMO AFI is properly loaded", SLOT_ID);

    srand(time(NULL));

    for (int i = 0; i < num_operations; i++)
    {
        value_a = rand() + 1;
        value_b = 0xFFFFFFFF; // Fixed to max value to force carry
        rc = cl_add_validate(pci_bar_handle, value_a, value_b, &sum, &carry);
        fail_on(rc, out, "Failed sum check on loop. Attempt n= %d", i);
        valid_carry_count += carry;
    }

    fail_on(valid_carry_count != num_operations, out,
            "Failed, not all operations returned carry == 1. N operations with carry = %d",
            valid_carry_count);

    printf("PASS all operations. Number of carry positive operations = %d\n",
           valid_carry_count);
    printf("TEST PASSED\n");

out:
    return rc;
}
