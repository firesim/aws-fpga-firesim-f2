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

// Test Reset
//
// This test covers:
// - Test 1: Reset in IDLE State
// - Test 2: Reset During Computation
// - Test 3: Verify Operation After Reset
// - Test 4: Multiple Reset Cycles
// - Test 5: Rapid Reset Sequence
// - Test 6: Reset with Partial Reads

module test_reset();

`include "test_base.inc"

logic[31:0] rdata;
logic ready;
logic[31:0] sum, carry;

initial begin
    $display("\n");
    $display("================================================================================");
    $display(" TEST: test_reset");
    $display("================================================================================");

    //==========================================================================
    // Test 1: Reset in IDLE State
    //==========================================================================
    $display("\n[%t] ===== Test 1: Reset in IDLE State =====", $time);

    // Power up
    power_up();
    delay_ns(1000);

    // Verify reset values
    $display("[%t] Verifying initial reset values...", $time);
    verify_reset_values();

    // Write some data to registers
    $display("[%t] Writing data to registers...", $time);
    write_operands(32'hAABBCCDD, 32'h11223344);
    delay_ns(100);

    // Verify data was written
    read_operand_a(rdata);
    check_value(rdata, 32'hAABBCCDD, "operand_a before reset");

    delay_ns(100);

    // Power down (reset)
    $display("[%t] Performing reset (power down/up)...", $time);
    power_down();
    delay_ns(500);

    // Power up again
    power_up();
    delay_ns(1000);

    // Verify all registers are back to 0
    $display("[%t] Verifying registers cleared after reset...", $time);
    verify_reset_values();

    delay_ns(200);

    //==========================================================================
    // Test 2: Reset During Computation
    //==========================================================================
    $display("\n[%t] ===== Test 2: Reset During Computation =====", $time);

    // Write operands and trigger operation
    $display("[%t] Starting computation...", $time);
    write_operands(32'h12345678, 32'h87654321);
    delay_ns(100);

    trigger_addition();
    delay_ns(100);

    // Verify ready flag is set
    check_ready(ready);
    check_bit(ready, 1'b1, "Ready before reset");

    // Immediately reset (power down/up)
    $display("[%t] Resetting during active computation...", $time);
    power_down();
    delay_ns(500);

    power_up();
    delay_ns(1000);

    // Verify all registers cleared (including ready flag)
    $display("[%t] Verifying all registers cleared...", $time);
    verify_reset_values();

    // Verify ready flag is cleared
    check_ready(ready);
    check_bit(ready, 1'b0, "Ready cleared after reset");

    delay_ns(200);

    //==========================================================================
    // Test 3: Verify Operation After Reset
    //==========================================================================
    $display("\n[%t] ===== Test 3: Verify Operation After Reset =====", $time);

    // Perform normal operation to verify functionality
    perform_addition(32'h00000100, 32'h00000200, sum, carry);

    check_value(sum, 32'h00000300, "Operation after reset - sum");
    check_value(carry, 32'h00000000, "Operation after reset - carry");

    delay_ns(200);

    //==========================================================================
    // Test 4: Multiple Reset Cycles
    //==========================================================================
    $display("\n[%t] ===== Test 4: Multiple Reset Cycles =====", $time);

    for (int i = 0; i < 3; i++) begin
        $display("\n[%t] Reset cycle %0d...", $time, i);

        // Write unique data
        write_operands(32'h1000 * (i+1), 32'h2000 * (i+1));
        delay_ns(100);

        // Trigger operation
        trigger_addition();
        delay_ns(100);

        // Verify ready
        check_ready(ready);
        check_bit(ready, 1'b1, $sformatf("Ready in cycle %0d", i));

        // Reset
        $display("[%t] Resetting...", $time);
        power_down();
        delay_ns(500);

        power_up();
        delay_ns(1000);

        // Verify reset
        verify_reset_values();

        // Verify ready cleared
        check_ready(ready);
        check_bit(ready, 1'b0, $sformatf("Ready cleared in cycle %0d", i));

        delay_ns(200);
    end

    //==========================================================================
    // Test 5: Rapid Reset Sequence
    //==========================================================================
    $display("\n[%t] ===== Test 5: Rapid Reset Sequence =====", $time);

    // Write data
    write_operands(32'hAAAAAAAA, 32'h55555555);
    delay_ns(100);

    // Multiple quick resets
    for (int i = 0; i < 2; i++) begin
        $display("[%t] Rapid reset %0d...", $time, i);
        power_down();
        delay_ns(200);
        power_up();
        delay_ns(500);
    end

    // Verify registers still clear properly
    verify_reset_values();

    // Verify system still functional
    perform_addition(32'h00000001, 32'h00000001, sum, carry);
    check_value(sum, 32'h00000002, "Operation after rapid resets");

    //==========================================================================
    // Test 6: Reset with Partial Reads
    //==========================================================================
    $display("\n[%t] ===== Test 6: Reset with Partial Reads =====", $time);

    // Perform operation
    write_operands(32'h11111111, 32'h22222222);
    delay_ns(100);

    trigger_addition();
    delay_ns(200);

    // Read only sum (not carry)
    read_sum(sum);
    $display("[%t] Read sum before reset: 0x%08x", $time, sum);

    // Reset before reading carry
    $display("[%t] Resetting before reading carry...", $time);
    power_down();
    delay_ns(500);

    power_up();
    delay_ns(1000);

    // Verify everything cleared
    verify_reset_values();

    // Verify system functional
    perform_addition(32'hFFFFFFFF, 32'h00000001, sum, carry);
    check_value(sum, 32'h00000000, "Sum after reset with partial reads");
    check_value(carry, 32'h00000001, "Carry after reset with partial reads");

    //==========================================================================
    // Test Summary
    //==========================================================================
    delay_ns(1000);
    power_down();

    $display("\n[%t] Test completed", $time);
    report_pass_fail_status();

    $finish;
end

endmodule // test_reset
