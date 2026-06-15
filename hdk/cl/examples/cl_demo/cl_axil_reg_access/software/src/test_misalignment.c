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

#define OUT_BOUND_ADDR 0xF0

static const struct logger *logger = &logger_stdout;

int main(int argc, char **argv)
{
    int rc;
    uint32_t value_read;
    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

    // Initialize logging
    rc = log_init("test_misalignment");
    fail_on(rc, out, "Unable to initialize the log.");
    rc = log_attach(logger, NULL, 0);
    fail_on(rc, out, "Unable to attach to the log.");

    // Initialize FPGA management library
    rc = fpga_mgmt_init();
    fail_on(rc, out, "Unable to initialize the fpga_mgmt library");

    // Attach to PCIe BAR (PF0-BAR0 for OCL registers)
    rc = fpga_pci_attach(SLOT_ID, CL_AXIL_DEMO_APP_PF, CL_AXIL_DEMO_BAR_ID, CL_AXIL_DEMO_PCI_FLAGS, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d\nCheck if the CL_DEMO AFI is properly loaded", SLOT_ID);

    printf("===================================================\n");
    printf("Misalignment Behavior Demonstration\n");
    printf("NOTE: This test demonstrates PCIe misalignment behavior.\n");
    printf("      Output values are NOT validated - for observation only.\n");
    printf("===================================================\n\n");

    // Write test pattern to CL_AXIL_REG_OFFSET_A
    printf("Writing 0x12345678 to CL_AXIL_REG_OFFSET_A (offset 0x00)\n");
    rc = fpga_pci_poke(pci_bar_handle, CL_AXIL_REG_OFFSET_A, 0x12345678);
    fail_on(rc, out, "Unable to write to CL_AXIL_REG_OFFSET_A");

    printf("\n--- Misaligned Reads (demonstrating byte rotation) ---\n");

    // Read from misaligned addresses
    rc = fpga_pci_peek(pci_bar_handle, CL_AXIL_REG_OFFSET_A + 1, &value_read);
    fail_on(rc, out, "Unable to read from offset CL_AXIL_REG_OFFSET_A+1");
    printf("Read @ CL_AXIL_REG_OFFSET_A+1 (0x%08x): 0x%08x\n", CL_AXIL_REG_OFFSET_A + 1, value_read);

    rc = fpga_pci_peek(pci_bar_handle, CL_AXIL_REG_OFFSET_A + 2, &value_read);
    fail_on(rc, out, "Unable to read from offset CL_AXIL_REG_OFFSET_A+2");
    printf("Read @ CL_AXIL_REG_OFFSET_A+2 (0x%08x): 0x%08x\n", CL_AXIL_REG_OFFSET_A + 2, value_read);

    rc = fpga_pci_peek(pci_bar_handle, CL_AXIL_REG_OFFSET_A + 3, &value_read);
    fail_on(rc, out, "Unable to read from offset CL_AXIL_REG_OFFSET_A+3");
    printf("Read @ CL_AXIL_REG_OFFSET_A+3 (0x%08x): 0x%08x\n", CL_AXIL_REG_OFFSET_A + 3, value_read);

    printf("\n--- Out-of-Range Address Reads ---\n");

    rc = fpga_pci_peek(pci_bar_handle, OUT_BOUND_ADDR, &value_read);
    fail_on(rc, out, "Unable to read from address OUT_BOUND_ADDR");
    printf("Read @ 0x%08x: 0x%08x\n", OUT_BOUND_ADDR, value_read);

    rc = fpga_pci_peek(pci_bar_handle, OUT_BOUND_ADDR, &value_read);
    fail_on(rc, out, "Unable to read from address OUT_BOUND_ADDR");
    printf("Read @ 0x%08x: 0x%08x\n", OUT_BOUND_ADDR, value_read);

    rc = fpga_pci_peek(pci_bar_handle, OUT_BOUND_ADDR, &value_read);
    fail_on(rc, out, "Unable to read from address OUT_BOUND_ADDR");
    printf("Read @ 0x%08x: 0x%08x\n", OUT_BOUND_ADDR, value_read);

    printf("\n===================================================\n");
    printf("Test completed - behavior demonstrated\n");
    printf("===================================================\n");
    printf("TEST PASSED\n");

    rc = 0;

out:
    return rc;
}
