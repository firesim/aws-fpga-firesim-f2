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

// Test Arithmetic Operations
//
// This test covers:
// - Test 1: Simple addition operations
// - Test 2: Addition with larger numbers
// - Test 3: Addition with carry generation
// - Test 4: Maximum value handling
// - Test 5: Zero value operations
// - Test 6: One operand zero
// - Test 7: Random value testing

module test_arithmetic_operations();

`include "test_base.inc"

initial begin
    $display("\n");
    $display("================================================================================");
    $display(" TEST: test_arithmetic_operations");
    $display("================================================================================");

    // Power up FPGA
    $display("[%t] ===== Starting Arithmetic Operations Test =====", $time);
    power_up();
    delay_ns(1000);

    // Verify reset values
    $display("[%t] Verifying reset values...", $time);
    verify_reset_values();

    // Test 1: Simple addition (5 + 3 = 8)
    $display("[%t] ===== Test 1: Simple Addition =====", $time);
    perform_and_check_addition(
        .a(32'd5),
        .b(32'd3),
        .expected_sum(32'd8),
        .expected_carry(32'h0),
        .test_name("5 + 3 = 8")
    );

    // Test 2: Addition with larger numbers
    $display("[%t] ===== Test 2: Larger Numbers =====", $time);
    perform_and_check_addition(
        .a(32'd1000),
        .b(32'd2000),
        .expected_sum(32'd3000),
        .expected_carry(32'h0),
        .test_name("1000 + 2000 = 3000")
    );

    // Test 3: Addition with carry
    $display("[%t] ===== Test 3: Addition with Carry =====", $time);
    perform_and_check_addition(
        .a(32'hFFFFFFFF),
        .b(32'h00000001),
        .expected_sum(32'h00000000),
        .expected_carry(32'h00000001),
        .test_name("0xFFFFFFFF + 0x1 = 0x0 (carry=1)")
    );

    // Test 4: Maximum values
    $display("[%t] ===== Test 4: Maximum Values =====", $time);
    perform_and_check_addition(
        .a(32'hFFFFFFFF),
        .b(32'hFFFFFFFF),
        .expected_sum(32'hFFFFFFFE),
        .expected_carry(32'h00000001),
        .test_name("0xFFFFFFFF + 0xFFFFFFFF")
    );

    // Test 5: Zero values
    $display("[%t] ===== Test 5: Zero Values =====", $time);
    perform_and_check_addition(
        .a(32'h0),
        .b(32'h0),
        .expected_sum(32'h0),
        .expected_carry(32'h0),
        .test_name("0 + 0 = 0")
    );

    // Test 6: One operand zero
    $display("[%t] ===== Test 6: One Operand Zero =====", $time);
    perform_and_check_addition(
        .a(32'd100),
        .b(32'h0),
        .expected_sum(32'd100),
        .expected_carry(32'h0),
        .test_name("100 + 0 = 100")
    );

    // Test 7: Random values
    $display("[%t] ===== Test 7: Random Values =====", $time);
    for (int i = 0; i < 10; i++) begin
        logic[31:0] rand_a, rand_b, exp_sum, exp_carry;
        logic[32:0] result;

        rand_a = $urandom();
        rand_b = $urandom();
        result = {1'b0, rand_a} + {1'b0, rand_b};
        exp_sum = result[31:0];
        exp_carry = {31'h0, result[32]};

        perform_and_check_addition(
            .a(rand_a),
            .b(rand_b),
            .expected_sum(exp_sum),
            .expected_carry(exp_carry),
            .test_name($sformatf("Random[%0d]: 0x%08x + 0x%08x", i, rand_a, rand_b))
        );
    end

    $display("[%t] ===== All Addition Tests Complete =====", $time);

    //==========================================================================
    // Test Summary
    //==========================================================================
    delay_ns(1000);
    power_down();

    $display("\n[%t] Test completed", $time);
    report_pass_fail_status();

    $finish;
end

endmodule // test_arithmetic_operations
