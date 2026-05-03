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


`include "common_base_test.svh"
`include "cl_axil_reg_access_defines.vh"

`ifndef CL_AXIL_TEST_BASE
`define CL_AXIL_TEST_BASE
import tb_type_defines_pkg::*;

// Invalid address for testing
localparam logic[63:0] ADDR_INVALID = 64'h14;

//==============================================================================
// Helper Tasks - Register Access
//==============================================================================

// Write to operand_a register
task write_operand_a(input logic[31:0] data);
    tb.poke_ocl(.addr(`ADDR_OPERAND_A), .data(data));
endtask

// Write to operand_b register
task write_operand_b(input logic[31:0] data);
    tb.poke_ocl(.addr(`ADDR_OPERAND_B), .data(data));
endtask

// Read from operand_a register
task read_operand_a(output logic[31:0] data);
    logic[63:0] rdata;
    tb.peek_ocl(.addr(`ADDR_OPERAND_A), .data(rdata));
    data = rdata[31:0];
endtask

// Read from operand_b register
task read_operand_b(output logic[31:0] data);
    logic[63:0] rdata;
    tb.peek_ocl(.addr(`ADDR_OPERAND_B), .data(rdata));
    data = rdata[31:0];
endtask

// Read from sum register
task read_sum(output logic[31:0] data);
    logic[63:0] rdata;
    tb.peek_ocl(.addr(`ADDR_SUM), .data(rdata));
    data = rdata[31:0];
endtask

// Read from carry register
task read_carry(output logic[31:0] data);
    logic[63:0] rdata;
    tb.peek_ocl(.addr(`ADDR_CARRY), .data(rdata));
    data = rdata[31:0];
endtask

// Write to control/status register
task write_control_status(input logic[31:0] data);
    tb.poke_ocl(.addr(`ADDR_CONTROL_STATUS), .data(data));
endtask

// Read from control/status register
task read_control_status(output logic[31:0] data);
    logic[63:0] rdata;
    tb.peek_ocl(.addr(`ADDR_CONTROL_STATUS), .data(rdata));
    data = rdata[31:0];
endtask

// Trigger addition operation (write start bit)
task trigger_addition();
    write_control_status(32'h00000001);  // Set bit[0] = 1 (start)
endtask

// Check ready flag from control/status register
task check_ready(output logic ready);
    logic[31:0] ctrl_stat;
    read_control_status(ctrl_stat);
    ready = ctrl_stat[1];  // bit[1] is ready flag
endtask

// Write both operands
task write_operands(input logic[31:0] a, input logic[31:0] b);
    write_operand_a(a);
    write_operand_b(b);
endtask

// Read both results
task read_results(output logic[31:0] sum, output logic[31:0] carry);
    read_sum(sum);
    read_carry(carry);
endtask

//==============================================================================
// Helper Tasks - Complete Operations
//==============================================================================

// Perform complete addition operation and return results
task perform_addition(
    input logic[31:0] a,
    input logic[31:0] b,
    output logic[31:0] sum,
    output logic[31:0] carry
);
    // Write operands
    write_operands(a, b);

    // Trigger operation
    trigger_addition();

    // Small delay for operation to complete
    #100ns;

    // Read results
    read_results(sum, carry);
endtask

// Perform addition and verify results
task perform_and_check_addition(
    input logic[31:0] a,
    input logic[31:0] b,
    input logic[31:0] expected_sum,
    input logic[31:0] expected_carry,
    input string test_name
);
    logic[31:0] actual_sum, actual_carry;

    $display("[%t] TEST: %s", $time, test_name);
    $display("        Operands: 0x%08x + 0x%08x", a, b);

    perform_addition(a, b, actual_sum, actual_carry);

    $display("        Expected: sum=0x%08x, carry=0x%08x", expected_sum, expected_carry);
    $display("        Actual:   sum=0x%08x, carry=0x%08x", actual_sum, actual_carry);

    if (actual_sum !== expected_sum) begin
        $error("[%t] ERROR: %s - sum mismatch", $time, test_name);
        error_count++;
    end

    if (actual_carry !== expected_carry) begin
        $error("[%t] ERROR: %s - carry mismatch", $time, test_name);
        error_count++;
    end

    if (actual_sum === expected_sum && actual_carry === expected_carry) begin
        $display("        PASS: %s", test_name);
    end
endtask

//==============================================================================
// Helper Tasks - Checking and Validation
//==============================================================================

// Check if value matches expected
task check_value(
    input logic[31:0] actual,
    input logic[31:0] expected,
    input string msg
);
    if (actual !== expected) begin
        $error("[%t] ERROR: %s", $time, msg);
        $display("        Expected: 0x%08x", expected);
        $display("        Actual:   0x%08x", actual);
        error_count++;
    end else begin
        $display("[%t] PASS: %s", $time, msg);
    end
endtask

// Check if bit matches expected
task check_bit(
    input logic actual,
    input logic expected,
    input string msg
);
    if (actual !== expected) begin
        $error("[%t] ERROR: %s", $time, msg);
        $display("        Expected: %b", expected);
        $display("        Actual:   %b", actual);
        error_count++;
    end else begin
        $display("[%t] PASS: %s", $time, msg);
    end
endtask

// Read and verify register value
task verify_register(
    input logic[63:0] addr,
    input logic[31:0] expected,
    input string reg_name
);
    logic[63:0] rdata;
    tb.peek_ocl(.addr(addr), .data(rdata));
    check_value(rdata[31:0], expected, $sformatf("%s register", reg_name));
endtask

// Verify all registers are at reset values (0x0)
task verify_reset_values();
    $display("[%t] Verifying reset values...", $time);
    verify_register(`ADDR_OPERAND_A, 32'h0, "operand_a");
    verify_register(`ADDR_OPERAND_B, 32'h0, "operand_b");
    verify_register(`ADDR_SUM, 32'h0, "sum");
    verify_register(`ADDR_CARRY, 32'h0, "carry");
    verify_register(`ADDR_CONTROL_STATUS, 32'h0, "control_status");
endtask

//==============================================================================
// Utility Tasks
//==============================================================================

// Power up helper
task power_up();
    tb.power_up();
endtask

// Power down helper
task power_down();
    tb.power_down();
endtask

// Delay in nanoseconds
task delay_ns(input int ns);
    #(ns * 1ns);
endtask

// Read from arbitrary address
task read_address(input logic[63:0] addr, output logic[31:0] data);
    logic[63:0] rdata;
    tb.peek_ocl(.addr(addr), .data(rdata));
    data = rdata[31:0];
endtask

// Write to arbitrary address
task write_address(input logic[63:0] addr, input logic[31:0] data);
    tb.poke_ocl(.addr(addr), .data(data));
endtask

`endif // CL_AXIL_TEST_BASE
