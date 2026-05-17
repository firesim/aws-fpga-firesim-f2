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

#include "fpga_pci.h"
#include "fpga_mgmt.h"
#include "utils/lcd.h"

#include "cl_axil_reg_access_def.h"
#include "cl_axil_reg_access_utils.h"

static const struct logger *logger = &logger_stdout;

void usage(const char *program_name)
{
    printf("usage: %s [--slot <slot>] [--a <value>] [--b <value>]\n", program_name);
}

int main(int argc, char **argv)
{
    int rc;
    int slot_id = 0;
    uint32_t value_a = 10;
    uint32_t value_b = 20;
    uint32_t sum, carry;
    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

    // Parse command line arguments
    for (int i = 1; i < argc; i++)
    {
        if (strncmp(argv[i], "--slot", sizeof("--slot") - 1) == 0 && i + 1 < argc)
        {
            slot_id = atoi(argv[++i]);
        }
        else if (strncmp(argv[i], "--a", sizeof("--a") - 1) == 0 && i + 1 < argc)
        {
            value_a = atoi(argv[++i]);
        }
        else if (strncmp(argv[i], "--b", sizeof("--b") - 1) == 0 && i + 1 < argc)
        {
            value_b = atoi(argv[++i]);
        }
        else
        {
            usage(argv[0]);
            return 1;
        }
    }

    // Initialize logging
    rc = log_init("test_sum");
    fail_on(rc, out, "Unable to initialize the log.");
    rc = log_attach(logger, NULL, 0);
    fail_on(rc, out, "Unable to attach to the log.");

    // Initialize FPGA management library
    rc = fpga_mgmt_init();
    fail_on(rc, out, "Unable to initialize the fpga_mgmt library");

    printf("===================================================\n");
    printf("Running test_sum\n");
    printf("===================================================\n");
    printf("slot_id = %d\n", slot_id);
    printf("value_a = %u\n", value_a);
    printf("value_b = %u\n", value_b);
    printf("===================================================\n");

    // Attach to PCIe BAR
    rc = fpga_pci_attach(slot_id, CL_AXIL_DEMO_APP_PF, CL_AXIL_DEMO_BAR_ID, CL_AXIL_DEMO_PCI_FLAGS, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d\nCheck if the CL_DEMO AFI is properly loaded", slot_id);

    // Perform addition and validate
    rc = cl_add_validate(pci_bar_handle, value_a, value_b, &sum, &carry);
    fail_on(rc, out, "Addition validation failed");

    printf("Result: sum = %u, carry = %u\n", sum, carry);
    printf("TEST PASSED\n");

out:
    return rc;
}
