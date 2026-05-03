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

// Test Adder
//
// This test covers:
// - Test 1: Basic Add Operation
// - Test 2: Add with Carry
// - Test 3: Result Stability
// - Test 4: Multiple Sequential Operations
// - Test 5: Operand Boundary Values
// - Test 6: Carry Bits[31:1] Always Zero

module test_adder();

`include "test_base.inc"

logic[31:0] sum, carry;
logic[31:0] temp_sum, temp_carry;

initial begin
    $display("\n");
    $display("================================================================================");
    $display(" TEST: test_adder");
    $display("================================================================================");

    power_up();
    delay_ns(1000);

    //==========================================================================
    // Test 1: Basic Add Operation
    //==========================================================================
    $display("\n[%t] ===== Test 1: Basic Add Operation =====", $time);

    perform_and_check_addition(
        .a(32'h00000100),
        .b(32'h00000200),
        .expected_sum(32'h00000300),
        .expected_carry(32'h00000000),
        .test_name("Basic addition: 0x100 + 0x200")
    );

    delay_ns(200);

    //==========================================================================
    // Test 2: Add with Carry
    //==========================================================================
    $display("\n[%t] ===== Test 2: Add with Carry =====", $time);

    perform_and_check_addition(
        .a(32'hFFFFFFFF),
        .b(32'h00000001),
        .expected_sum(32'h00000000),
        .expected_carry(32'h00000001),
        .test_name("Addition with carry: 0xFFFFFFFF + 0x1")
    );

    delay_ns(200);

    perform_and_check_addition(
        .a(32'h80000000),
        .b(32'h80000000),
        .expected_sum(32'h00000000),
        .expected_carry(32'h00000001),
        .test_name("Addition with carry: 0x80000000 + 0x80000000")
    );

    delay_ns(200);

    //==========================================================================
    // Test 3: Result Stability
    //==========================================================================
    $display("\n[%t] ===== Test 3: Result Stability =====", $time);

    // Perform an addition
    perform_addition(32'h12345678, 32'h87654321, sum, carry);

    // Read results multiple times and verify they remain stable
    $display("[%t] Verifying result stability (multiple reads)...", $time);

    for (int i = 0; i < 5; i++) begin
        delay_ns(100);
        read_results(temp_sum, temp_carry);
        check_value(temp_sum, sum, $sformatf("Result stability check %0d - sum", i));
        check_value(temp_carry, carry, $sformatf("Result stability check %0d - carry", i));
    end

    delay_ns(200);

    //==========================================================================
    // Test 4: Multiple Sequential Operations
    //==========================================================================
    $display("\n[%t] ===== Test 4: Multiple Sequential Operations =====", $time);

    // Operation 1
    perform_and_check_addition(
        .a(32'h11111111),
        .b(32'h22222222),
        .expected_sum(32'h33333333),
        .expected_carry(32'h00000000),
        .test_name("Multiple ops - operation 1")
    );

    delay_ns(100);

    // Operation 2 - different operands
    perform_and_check_addition(
        .a(32'hAAAAAAAA),
        .b(32'h55555555),
        .expected_sum(32'hFFFFFFFF),
        .expected_carry(32'h00000000),
        .test_name("Multiple ops - operation 2")
    );

    delay_ns(100);

    // Operation 3 - with carry
    perform_and_check_addition(
        .a(32'hF0000000),
        .b(32'h20000000),
        .expected_sum(32'h10000000),
        .expected_carry(32'h00000001),
        .test_name("Multiple ops - operation 3")
    );

    delay_ns(200);

    //==========================================================================
    // Test 5: Operand Boundary Values
    //==========================================================================
    $display("\n[%t] ===== Test 5: Operand Boundary Values =====", $time);

    // Both operands zero
    perform_and_check_addition(
        .a(32'h00000000),
        .b(32'h00000000),
        .expected_sum(32'h00000000),
        .expected_carry(32'h00000000),
        .test_name("Boundary: 0 + 0")
    );

    delay_ns(100);

    // Both operands max
    perform_and_check_addition(
        .a(32'hFFFFFFFF),
        .b(32'hFFFFFFFF),
        .expected_sum(32'hFFFFFFFE),
        .expected_carry(32'h00000001),
        .test_name("Boundary: MAX + MAX")
    );

    delay_ns(100);

    // Zero plus max
    perform_and_check_addition(
        .a(32'h00000000),
        .b(32'hFFFFFFFF),
        .expected_sum(32'hFFFFFFFF),
        .expected_carry(32'h00000000),
        .test_name("Boundary: 0 + MAX")
    );

    delay_ns(100);

    // Max plus zero
    perform_and_check_addition(
        .a(32'hFFFFFFFF),
        .b(32'h00000000),
        .expected_sum(32'hFFFFFFFF),
        .expected_carry(32'h00000000),
        .test_name("Boundary: MAX + 0")
    );

    delay_ns(100);

    // Mid-range values
    perform_and_check_addition(
        .a(32'h80000000),
        .b(32'h7FFFFFFF),
        .expected_sum(32'hFFFFFFFF),
        .expected_carry(32'h00000000),
        .test_name("Boundary: MID + (MID-1)")
    );

    delay_ns(100);

    // Powers of 2
    perform_and_check_addition(
        .a(32'h00000001),
        .b(32'h00000001),
        .expected_sum(32'h00000002),
        .expected_carry(32'h00000000),
        .test_name("Boundary: 1 + 1")
    );

    delay_ns(100);

    perform_and_check_addition(
        .a(32'h80000000),
        .b(32'h80000001),
        .expected_sum(32'h00000001),
        .expected_carry(32'h00000001),
        .test_name("Boundary: 0x80000000 + 0x80000001")
    );

    delay_ns(200);

    //==========================================================================
    // Test 6: Carry Bits[31:1] Always Zero
    //==========================================================================
    $display("\n[%t] ===== Test 6: Carry Bits[31:1] Always Zero =====", $time);

    // Case 1: No carry - 0x100 + 0x200
    perform_and_check_addition(32'h00000100, 32'h00000200, 32'h00000300, 32'h00000000, "No carry case");
    read_carry(carry);
    check_value(carry & 32'hFFFFFFFE, 32'h00000000, "No carry: bits[31:1] are zero");

    delay_ns(100);

    // Case 2: With carry - 0xFFFFFFFF + 0x1
    perform_and_check_addition(32'hFFFFFFFF, 32'h00000001, 32'h00000000, 32'h00000001, "With carry case");
    read_carry(carry);
    check_value(carry & 32'hFFFFFFFE, 32'h00000000, "With carry: bits[31:1] are zero");

    delay_ns(100);

    // Case 3: Max carry scenario - 0xFFFFFFFF + 0xFFFFFFFF
    perform_and_check_addition(32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFE, 32'h00000001, "Max carry case");
    read_carry(carry);
    check_value(carry & 32'hFFFFFFFE, 32'h00000000, "Max carry: bits[31:1] are zero");

    //==========================================================================
    // Test Summary
    //==========================================================================
    delay_ns(1000);
    power_down();

    $display("\n[%t] Test completed", $time);
    report_pass_fail_status();

    $finish;
end

endmodule // test_adder
