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

// Test AXI-Lite Registers
//
// This test covers:
// - Test 1: Register Reset Values
// - Test 2: Basic Write and Read Transactions
// - Test 3: Read-Only Register Protection
// - Test 4: Write-Then-Read Sequences
// - Test 5: Operands Persist After Addition

module test_axil_registers();

`include "test_base.inc"

logic[31:0] rdata;
logic[31:0] wdata;

initial begin
    $display("\n");
    $display("================================================================================");
    $display(" TEST: test_axil_registers");
    $display("================================================================================");

    // Power up the FPGA
    $display("[%t] Powering up FPGA...", $time);
    power_up();
    delay_ns(1000);

    //==========================================================================
    // Test 1: Verify Reset Values
    //==========================================================================
    $display("\n[%t] ===== Test 1: Register Reset Values =====", $time);
    verify_reset_values();

    //==========================================================================
    // Test 2: Basic Write and Read Transactions
    //==========================================================================
    $display("\n[%t] ===== Test 2: Basic Write/Read =====", $time);

    // Write operand_a
    $display("[%t] Writing operand_a register...", $time);
    wdata = 32'hA5A5A5A5;
    write_operand_a(wdata);
    delay_ns(100);

    // Basic Read Transaction - Read back operand_a
    read_operand_a(rdata);
    check_value(rdata, wdata, "operand_a write/read");

    // Write operand_b
    $display("[%t] Writing operand_b register...", $time);
    wdata = 32'h5A5A5A5A;
    write_operand_b(wdata);
    delay_ns(100);

    // Read back operand_b
    read_operand_b(rdata);
    check_value(rdata, wdata, "operand_b write/read");

    //==========================================================================
    // Test 3: Read-Only Register Protection
    //==========================================================================
    $display("\n[%t] ===== Test 3: Read-Only Register Protection =====", $time);

    // Try to write to sum register (should be ignored)
    $display("[%t] Attempting to write to read-only sum register...", $time);
    write_address(`ADDR_SUM, 32'hDEADDEAD);
    delay_ns(100);

    // Read back sum - should still be 0 (not changed)
    read_sum(rdata);
    check_value(rdata, 32'h0, "sum register protection");

    // Try to write to carry register (should be ignored)
    $display("[%t] Attempting to write to read-only carry register...", $time);
    write_address(`ADDR_CARRY, 32'hBEEFBEEF);
    delay_ns(100);

    // Read back carry - should still be 0 (not changed)
    read_carry(rdata);
    check_value(rdata, 32'h0, "carry register protection");

    //==========================================================================
    // Test 4: Write-Then-Read Sequences
    //==========================================================================
    $display("\n[%t] ===== Test 4: Write-Then-Read Sequences =====", $time);

    // Test pattern 1
    wdata = 32'h12345678;
    write_operand_a(wdata);
    delay_ns(50);
    read_operand_a(rdata);
    check_value(rdata, wdata, "write-then-read pattern 1");

    // Test pattern 2
    wdata = 32'hFEDCBA98;
    write_operand_b(wdata);
    delay_ns(50);
    read_operand_b(rdata);
    check_value(rdata, wdata, "write-then-read pattern 2");

    // Test pattern 3 - all 0s
    wdata = 32'h00000000;
    write_operand_a(wdata);
    delay_ns(50);
    read_operand_a(rdata);
    check_value(rdata, wdata, "write-then-read all 0s");

    // Test pattern 4 - all 1s
    wdata = 32'hFFFFFFFF;
    write_operand_b(wdata);
    delay_ns(50);
    read_operand_b(rdata);
    check_value(rdata, wdata, "write-then-read all 1s");

    //==========================================================================
    // Test 5: Operands Persist After Addition
    //==========================================================================
    $display("\n[%t] ===== Test 5: Operands Persist After Addition =====", $time);

    // Setup operands
    write_operand_a(32'hAABBCCDD);
    write_operand_b(32'h11223344);
    delay_ns(100);

    // First addition
    trigger_addition();
    delay_ns(200);

    // Read results to return module to ready state (values discarded)
    read_sum(rdata);
    read_carry(rdata);

    // Verify operands unchanged
    read_operand_a(rdata);
    check_value(rdata, 32'hAABBCCDD, "operand_a persists after addition");
    read_operand_b(rdata);
    check_value(rdata, 32'h11223344, "operand_b persists after addition");

    // Second addition without writing new operands
    trigger_addition();
    delay_ns(200);

    // Verify sum is correct (same result since operands unchanged)
    read_sum(rdata);
    check_value(rdata, 32'hBBDE0021, "sum correct after second addition");

    //==========================================================================
    // Test Summary
    //==========================================================================
    delay_ns(1000);
    power_down();

    $display("\n[%t] Test completed", $time);
    report_pass_fail_status();

    $finish;
end

endmodule // test_axil_registers
