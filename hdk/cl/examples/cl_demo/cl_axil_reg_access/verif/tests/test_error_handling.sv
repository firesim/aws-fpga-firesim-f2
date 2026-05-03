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

// Test Error Handling
//
// This test covers:
// - Test 1: Read from Invalid Addresses
// - Test 2: Write to Invalid Addresses
// - Test 3: Misaligned Address Access
// - Test 4: Verify System Still Functions After Invalid Accesses

module test_error_handling();

`include "test_base.inc"

logic[31:0] rdata;
logic[31:0] saved_operand_a, saved_operand_b;
logic[31:0] sum, carry;

initial begin
    $display("\n");
    $display("================================================================================");
    $display(" TEST: test_error_handling");
    $display("================================================================================");

    power_up();
    delay_ns(1000);

    //==========================================================================
    // Test 1: Read from Invalid Addresses
    //==========================================================================
    $display("\n[%t] ===== Test 1: Read from Invalid Addresses =====", $time);

    // Read from address 0x14 (first invalid address after control_status)
    $display("[%t] Reading from invalid address 0x14...", $time);
    read_address(64'h14, rdata);
    check_value(rdata, `INVALID_ADDR_RESP, "Invalid address 0x14 response");

    delay_ns(100);

    // Read from address 0x20
    $display("[%t] Reading from invalid address 0x20...", $time);
    read_address(64'h20, rdata);
    check_value(rdata, `INVALID_ADDR_RESP, "Invalid address 0x20 response");

    delay_ns(100);

    // Read from address 0x100 (far out of range)
    $display("[%t] Reading from invalid address 0x100...", $time);
    read_address(64'h100, rdata);
    check_value(rdata, `INVALID_ADDR_RESP, "Invalid address 0x100 response");

    delay_ns(100);

    // Read from address 0xFFF0
    $display("[%t] Reading from invalid address 0xFFF0...", $time);
    read_address(64'hFFF0, rdata);
    check_value(rdata, `INVALID_ADDR_RESP, "Invalid address 0xFFF0 response");

    delay_ns(200);

    //==========================================================================
    // Test 2: Write to Invalid Addresses
    //==========================================================================
    $display("\n[%t] ===== Test 2: Write to Invalid Addresses =====", $time);

    // First, set valid registers to known values
    $display("[%t] Setting valid registers to known values...", $time);
    write_operands(32'h12345678, 32'h87654321);
    delay_ns(100);

    // Save the values
    read_operand_a(saved_operand_a);
    read_operand_b(saved_operand_b);

    // Write to invalid address 0x14
    $display("[%t] Writing to invalid address 0x14...", $time);
    write_address(64'h14, 32'hDEADBEEF);
    delay_ns(100);

    // Verify valid registers are unchanged
    read_operand_a(rdata);
    check_value(rdata, saved_operand_a, "operand_a unchanged after invalid write");
    read_operand_b(rdata);
    check_value(rdata, saved_operand_b, "operand_b unchanged after invalid write");

    delay_ns(100);

    // Write to invalid address 0x20
    $display("[%t] Writing to invalid address 0x20...", $time);
    write_address(64'h20, 32'hCAFEBABE);
    delay_ns(100);

    // Verify valid registers are still unchanged
    read_operand_a(rdata);
    check_value(rdata, saved_operand_a, "operand_a unchanged after invalid write 0x20");

    delay_ns(100);

    // Write to invalid address 0x100
    $display("[%t] Writing to invalid address 0x100...", $time);
    write_address(64'h100, 32'hBAADF00D);
    delay_ns(100);

    // Verify valid registers are still unchanged
    read_operand_b(rdata);
    check_value(rdata, saved_operand_b, "operand_b unchanged after invalid write 0x100");

    delay_ns(200);

    //==========================================================================
    // Test 3: Misaligned Address Access
    //==========================================================================
    $display("\n[%t] ===== Test 3: Misaligned Address Access =====", $time);

    // Note: Behavior with misaligned addresses may vary by design
    // This test documents the behavior

    // Try reading from address 0x01 (misaligned by 1 byte)
    $display("[%t] Reading from misaligned address 0x01...", $time);
    read_address(64'h01, rdata);
    $display("[%t] Misaligned read 0x01 returned: 0x%08x", $time, rdata);
    // Document behavior but don't necessarily check for specific value

    delay_ns(100);

    // Try reading from address 0x02 (misaligned by 2 bytes)
    $display("[%t] Reading from misaligned address 0x02...", $time);
    read_address(64'h02, rdata);
    $display("[%t] Misaligned read 0x02 returned: 0x%08x", $time, rdata);

    delay_ns(100);

    // Try reading from address 0x03 (misaligned by 3 bytes)
    $display("[%t] Reading from misaligned address 0x03...", $time);
    read_address(64'h03, rdata);
    $display("[%t] Misaligned read 0x03 returned: 0x%08x", $time, rdata);

    delay_ns(100);

    // Try reading from address 0x05 (misaligned, between operand_a and operand_b)
    $display("[%t] Reading from misaligned address 0x05...", $time);
    read_address(64'h05, rdata);
    $display("[%t] Misaligned read 0x05 returned: 0x%08x", $time, rdata);

    delay_ns(100);

    // Try writing to misaligned address
    $display("[%t] Writing to misaligned address 0x01...", $time);
    write_address(64'h01, 32'h11111111);
    delay_ns(100);

    // Check if any valid registers were affected
    read_operand_a(rdata);
    $display("[%t] operand_a after misaligned write: 0x%08x", $time, rdata);

    delay_ns(200);

    //==========================================================================
    // Test 4: Verify System Still Functions After Invalid Accesses
    //==========================================================================
    $display("\n[%t] ===== Test 4: Verify System Still Functions After Invalid Accesses =====", $time);

    // Perform a normal operation to verify system is still functional
    write_operands(32'h00000100, 32'h00000200);
    delay_ns(100);

    trigger_addition();
    delay_ns(200);

    read_results(sum, carry);

    check_value(sum, 32'h00000300, "Normal operation after error tests");
    check_value(carry, 32'h00000000, "Normal carry after error tests");

    //==========================================================================
    // Test Summary
    //==========================================================================
    delay_ns(1000);
    power_down();

    $display("\n[%t] Test completed", $time);
    report_pass_fail_status();

    $finish;
end

endmodule // test_error_handling
