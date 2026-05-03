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

// Test Control Bits
//
// This test covers:
// - Test 1: Ready Assertion After Start
// - Test 2: Ready Deassertion After Both Reads
// - Test 3a: Ready With Partial Result Reads (Read Sum Only)
// - Test 3b: Ready With Partial Result Reads (Read Carry Only)
// - Test 4: Start While Ready = 1
// - Test 5: Write Control with bit[0]=0 (No-Op)
// - Test 6: Write Control with Garbage Bits
// - Test 7: Multiple Reads of Same Result Register
// - Test 8: Multiple Start-Read Cycles

module test_control_bits();

`include "test_base.inc"

logic ready;
logic[31:0] sum, carry;

initial begin
    $display("\n");
    $display("================================================================================");
    $display(" TEST: test_control_bits");
    $display("================================================================================");

    power_up();
    delay_ns(1000);

    //==========================================================================
    // Test 1: Ready Assertion After Start
    //==========================================================================
    $display("\n[%t] ===== Test 1: Ready Assertion After Start =====", $time);

    // Set operands
    write_operands(32'h00001000, 32'h00002000);
    delay_ns(100);

    // Check ready is 0 before start
    check_ready(ready);
    check_bit(ready, 1'b0, "Ready before start");

    // Trigger addition
    trigger_addition();
    delay_ns(200);

    // Check ready is now 1
    check_ready(ready);
    check_bit(ready, 1'b1, "Ready after start");

    delay_ns(200);

    //==========================================================================
    // Test 2: Ready Deassertion After Both Reads
    //==========================================================================
    $display("\n[%t] ===== Test 2: Ready Deassertion After Both Reads =====", $time);

    // Start fresh with new operation
    write_operands(32'h00000A00, 32'h00000B00);
    delay_ns(100);

    trigger_addition();
    delay_ns(200);

    // Verify ready is 1
    check_ready(ready);
    check_bit(ready, 1'b1, "Ready before reading results");

    // Read sum only (not carry yet)
    read_sum(sum);
    delay_ns(100);

    // Ready should still be 1
    check_ready(ready);
    check_bit(ready, 1'b1, "Ready after reading sum only");

    // Now read carry
    read_carry(carry);
    delay_ns(100);

    // Ready should now be 0 (both results have been read)
    check_ready(ready);
    check_bit(ready, 1'b0, "Ready after reading both sum and carry");

    delay_ns(200);

    //==========================================================================
    // Test 3a: Ready With Partial Result Reads
    //==========================================================================
    $display("\n[%t] ===== Test 3: Ready With Partial Result Reads =====", $time);

    // New operation
    write_operands(32'h11111111, 32'h22222222);
    delay_ns(100);

    trigger_addition();
    delay_ns(200);

    // Verify ready is 1
    check_ready(ready);
    check_bit(ready, 1'b1, "Ready before partial read");

    // Read only sum (not carry)
    read_sum(sum);
    delay_ns(100);

    // Ready should remain 1 (carry not read yet)
    check_ready(ready);
    check_bit(ready, 1'b1, "Ready after reading only sum");

    // Perform another operation WITHOUT reading carry from previous
    $display("[%t] Starting new operation without reading previous carry...", $time);
    write_operands(32'h33333333, 32'h44444444);
    delay_ns(100);

    trigger_addition();
    delay_ns(200);

    // Ready should be 1 for new operation
    check_ready(ready);
    check_bit(ready, 1'b1, "Ready after new operation (previous carry not read)");

    // Clean up by reading results
    read_results(sum, carry);

    delay_ns(200);

    //==========================================================================
    // Test 3b: Read Carry Only
    //==========================================================================
    $display("\n[%t] ===== Test 3: Read Carry Only =====", $time);

    // New operation
    write_operands(32'hAAAAAAAA, 32'h55555555);
    delay_ns(100);

    trigger_addition();
    delay_ns(200);

    // Read only carry (not sum)
    read_carry(carry);
    delay_ns(100);

    // Ready should remain 1 (sum not read yet)
    check_ready(ready);
    check_bit(ready, 1'b1, "Ready after reading only carry");

    // Now read sum to complete
    read_sum(sum);
    delay_ns(100);

    // Ready should now be 0
    check_ready(ready);
    check_bit(ready, 1'b0, "Ready after reading both (carry first)");

    delay_ns(200);

    //==========================================================================
    // Test 4: Start While Ready = 1
    //==========================================================================
    $display("\n[%t] ===== Test 4: Start While Ready = 1 =====", $time);

    // First operation
    write_operands(32'h10000000, 32'h20000000);
    delay_ns(100);

    trigger_addition();
    delay_ns(200);

    // Verify ready is 1
    check_ready(ready);
    check_bit(ready, 1'b1, "Ready after first operation");

    // Start second operation WITHOUT reading results from first
    $display("[%t] Starting second operation while ready=1...", $time);
    write_operands(32'h00000001, 32'h00000002);
    delay_ns(100);

    trigger_addition();
    delay_ns(200);

    // Ready should still be 1
    check_ready(ready);
    check_bit(ready, 1'b1, "Ready after second operation (first not read)");

    // Read results - should be from second operation
    read_results(sum, carry);
    check_value(sum, 32'h00000003, "Second operation result (first overwritten)");
    check_value(carry, 32'h00000000, "Second operation carry");

    delay_ns(100);

    // Ready should now be 0
    check_ready(ready);
    check_bit(ready, 1'b0, "Ready after reading second operation results");

    delay_ns(200);

    //==========================================================================
    // Test 5: Write Control with bit[0]=0 (No-Op)
    //==========================================================================
    $display("\n[%t] ===== Test 5: Write Control with bit[0]=0 (No-Op) =====", $time);

    // Previous sum from Test 4: 0x00000003
    write_operands(32'h00000100, 32'h00000200);
    delay_ns(100);

    // Write 0 to control_status - should NOT trigger
    write_control_status(32'h00000000);
    delay_ns(200);

    check_ready(ready);
    check_bit(ready, 1'b0, "Ready after writing 0 to control");

    read_sum(sum);
    check_value(sum, 32'h00000003, "Sum should be persistent (no new computation)");

    delay_ns(200);

    //==========================================================================
    // Test 6: Write Control with Garbage Bits (0xFFFFFFFE, 0xFFFFFFFF)
    //==========================================================================
    $display("\n[%t] ===== Test 6: Write Control with Garbage Bits =====", $time);

    write_operands(32'h00001000, 32'h00002000);
    delay_ns(100);

    // Write 0xFFFFFFFE (bit[0]=0) - should NOT trigger
    write_control_status(32'hFFFFFFFE);
    delay_ns(200);

    check_ready(ready);
    check_bit(ready, 1'b0, "Ready after 0xFFFFFFFE (bit[0]=0)");

    read_sum(sum);
    check_value(sum, 32'h00000003, "Sum should be persistent (no trigger)");

    // Write 0xFFFFFFFF (bit[0]=1) - SHOULD trigger
    write_control_status(32'hFFFFFFFF);
    delay_ns(200);

    check_ready(ready);
    check_bit(ready, 1'b1, "Ready after 0xFFFFFFFF (bit[0]=1)");

    read_sum(sum);
    check_value(sum, 32'h00003000, "Sum after garbage bits trigger");

    read_carry(carry);
    check_value(carry, 32'h00000000, "Carry after garbage bits trigger");

    delay_ns(200);

    //==========================================================================
    // Test 7: Multiple Reads of Same Result Register
    //==========================================================================
    $display("\n[%t] ===== Test 7: Multiple Reads of Same Result Register =====", $time);

    // Part A: Read sum 3 times, then carry
    write_operands(32'h00000500, 32'h00000600);
    trigger_addition();
    delay_ns(200);

    read_sum(sum);
    read_sum(sum);
    read_sum(sum);
    delay_ns(100);

    check_ready(ready);
    check_bit(ready, 1'b1, "Ready after 3x sum reads (carry not read)");

    read_carry(carry);
    delay_ns(100);

    check_ready(ready);
    check_bit(ready, 1'b0, "Ready after carry read");

    delay_ns(200);

    // Part B: Read carry 3 times, then sum
    write_operands(32'h00000700, 32'h00000800);
    trigger_addition();
    delay_ns(200);

    read_carry(carry);
    read_carry(carry);
    read_carry(carry);
    delay_ns(100);

    check_ready(ready);
    check_bit(ready, 1'b1, "Ready after 3x carry reads (sum not read)");

    read_sum(sum);
    delay_ns(100);

    check_ready(ready);
    check_bit(ready, 1'b0, "Ready after sum read");

    delay_ns(200);

    //==========================================================================
    // Test 8: Multiple Start-Read Cycles
    //==========================================================================
    $display("\n[%t] ===== Test 8: Multiple Start-Read Cycles =====", $time);

    for (int i = 0; i < 3; i++) begin
        $display("[%t] Cycle %0d...", $time, i);

        // Write operands
        write_operands(32'h00000100 * (i+1), 32'h00000200 * (i+1));
        delay_ns(100);

        // Trigger
        trigger_addition();
        delay_ns(200);

        // Check ready
        check_ready(ready);
        check_bit(ready, 1'b1, $sformatf("Ready in cycle %0d", i));

        // Read results
        read_results(sum, carry);
        delay_ns(100);

        // Check ready cleared
        check_ready(ready);
        check_bit(ready, 1'b0, $sformatf("Ready cleared in cycle %0d", i));

        delay_ns(200);
    end

    //==========================================================================
    // Test Summary
    //==========================================================================
    delay_ns(1000);
    power_down();

    $display("\n[%t] Test completed", $time);
    report_pass_fail_status();

    $finish;
end

endmodule // test_control_bits
