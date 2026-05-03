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

#pragma once

// Register offsets
#define CL_AXIL_REG_OFFSET_A         0x00  // RW : Holds unsigned 32b operand A
#define CL_AXIL_REG_OFFSET_B         0x04  // RW : Holds unsigned 32b operand B
#define CL_AXIL_REG_OFFSET_SUM       0x08  // RO : Holds 32b sum integer
#define CL_AXIL_REG_OFFSET_CARRY     0x0C  // RO : LSB Holds carry output from addition
#define CL_AXIL_REG_OFFSET_CONTROL   0x10  // RW : bit[0] Start — write 1 to trigger addition; bit[1] Ready — read-only, set when result is ready, cleared after both Sum and Carry are read

// Control reg masks
#define CONTROL_READY_MASK 0x02
#define CONTROL_START_MASK 0x01
// FPGA Slot 0
#define SLOT_ID 0

// PCIe BAR (PF0-BAR0 for OCL registers). See https://awsdocs-fpga-f2.readthedocs-hosted.com/latest/hdk/docs/AWS-Fpga-Pcie-Memory-Map.html
#define CL_AXIL_DEMO_APP_PF      0
#define CL_AXIL_DEMO_BAR_ID      0
#define CL_AXIL_DEMO_PCI_FLAGS   0  // Write combining disabled
