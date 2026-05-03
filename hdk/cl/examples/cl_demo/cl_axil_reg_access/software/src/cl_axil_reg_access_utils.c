// =============================================================================
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
// =============================================================================

#include <stdbool.h>
#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include "fpga_pci.h"
#include "utils/lcd.h"
#include "cl_axil_reg_access_def.h"
#include "cl_axil_reg_access_utils.h"

#define MAX_ATTEMPTS 1000

int cl_add(pci_bar_handle_t pci_bar_handle, uint32_t op_a, uint32_t op_b,
           uint32_t *sum, uint32_t *carry)
{
    int rc;
    uint32_t status;
    int attempts = 0;

    fail_on_with_code(!sum, out, rc, FPGA_ERR_SOFTWARE_PROBLEM, "Invalid sum pointer");
    fail_on_with_code(!carry, out, rc, FPGA_ERR_SOFTWARE_PROBLEM, "Invalid carry pointer");

    // Write op_a value into CL_AXIL_REG_OFFSET_A
    rc = fpga_pci_poke(pci_bar_handle, CL_AXIL_REG_OFFSET_A, op_a);
    fail_on(rc, out, "Unable to write to CL_AXIL_REG_OFFSET_A");

    // Write op_b value into CL_AXIL_REG_OFFSET_B
    rc = fpga_pci_poke(pci_bar_handle, CL_AXIL_REG_OFFSET_B, op_b);
    fail_on(rc, out, "Unable to write to CL_AXIL_REG_OFFSET_B");

    // Write CONTROL_START_MASK to trigger the addition
    rc = fpga_pci_poke(pci_bar_handle, CL_AXIL_REG_OFFSET_CONTROL, CONTROL_START_MASK);
    fail_on(rc, out, "Unable to write to CL_AXIL_REG_OFFSET_CONTROL");

    // Wait until the operation is complete (READY bit set)
    bool is_ready;
    do
    {
        rc = fpga_pci_peek(pci_bar_handle, CL_AXIL_REG_OFFSET_CONTROL, &status);
        fail_on(rc, out, "Unable to read from CL_AXIL_REG_OFFSET_CONTROL");
        is_ready = status & CONTROL_READY_MASK;
        if (!is_ready)
        {
            usleep(1000);
        }
        attempts++;
    } while (!is_ready && (attempts < MAX_ATTEMPTS));

    fail_on(attempts >= MAX_ATTEMPTS, out, "Timeout waiting for ready flag");
    fail_on((status & CONTROL_START_MASK) != 0, out, "CONTROL_START_MASK still high after ready");

    // Read CL_AXIL_REG_OFFSET_SUM value
    rc = fpga_pci_peek(pci_bar_handle, CL_AXIL_REG_OFFSET_SUM, sum);
    fail_on(rc, out, "Unable to read from CL_AXIL_REG_OFFSET_SUM");

    // Read CL_AXIL_REG_OFFSET_CARRY value
    rc = fpga_pci_peek(pci_bar_handle, CL_AXIL_REG_OFFSET_CARRY, carry);
    fail_on(rc, out, "Unable to read from CL_AXIL_REG_OFFSET_CARRY");

    // Verify control register cleared
    rc = fpga_pci_peek(pci_bar_handle, CL_AXIL_REG_OFFSET_CONTROL, &status);
    fail_on(rc, out, "Unable to read from CL_AXIL_REG_OFFSET_CONTROL");
    fail_on(status != 0, out, "Control register not cleared, value: 0x%08x", status);

    return 0;

out:
    return rc;
}

int cl_add_validate(pci_bar_handle_t pci_bar_handle, uint32_t op_a, uint32_t op_b,
                    uint32_t *sum, uint32_t *carry)
{
    int rc;

    fail_on_with_code(!sum, out, rc, FPGA_ERR_SOFTWARE_PROBLEM, "Invalid sum pointer");
    fail_on_with_code(!carry, out, rc, FPGA_ERR_SOFTWARE_PROBLEM, "Invalid carry pointer");

    // Perform addition using the CL
    rc = cl_add(pci_bar_handle, op_a, op_b, sum, carry);
    fail_on(rc, out, "cl_add failed");

    // Generate golden model output
    uint64_t golden_sum = (uint64_t)op_a + (uint64_t)op_b;

    // Compare CL vs Golden Model
    uint64_t cl_sum = *sum + ((uint64_t)(*carry) << 32);
    if (golden_sum == cl_sum)
    {
        rc = 0;
        printf("PASS: %u + %u = %u (carry = %u)\n", op_a, op_b, *sum, *carry);
    }
    else
    {
        rc = FPGA_ERR_SOFTWARE_PROBLEM;
        printf("FAIL: %u + %u = %u (carry = %u) | Expected: 0x%016lx, Got: 0x%016lx\n",
               op_a, op_b, *sum, *carry, golden_sum, cl_sum);
    }

out:
    return rc;
}
