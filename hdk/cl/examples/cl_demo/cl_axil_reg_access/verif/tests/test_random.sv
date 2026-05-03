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


// Test Random
//
// This test covers:
// - Test 1: Random Operands with Golden Model
// - Test 2: Random Control Flow
// - Test 3: Random Boundary Cases

module test_random();

`include "test_base.inc"

// Default test parameters
int num_iterations = 100;
int seed_value = 0;

// Statistics
int operations_passed = 0;
int operations_failed = 0;

logic[31:0] a, b, sum, carry;
logic[31:0] expected_sum, expected_carry;
logic[32:0] expected_result;
int case_type, operation_type;
bit test_passed = 1;

initial begin
    $display("\n");
    $display("================================================================================");
    $display(" TEST: test_random");
    $display("================================================================================");

    // Get number of iterations from plusargs if specified
    if ($value$plusargs("num_iterations=%d", num_iterations)) begin
        $display("[%t] Using %0d iterations from plusargs", $time, num_iterations);
    end else begin
        $display("[%t] Using default %0d iterations", $time, num_iterations);
    end

    // Get seed if specified
    if ($value$plusargs("seed=%d", seed_value)) begin
        $display("[%t] Using seed %0d from plusargs", $time, seed_value);
    end else begin
        seed_value = $urandom;
        $display("[%t] Using random seed: %0d", $time, seed_value);
    end

    power_up();
    delay_ns(1000);

    //==========================================================================
    // Test 1: Random Operands with Golden Model
    //==========================================================================
    $display("\n[%t] ===== Test 1: Random Operands with Golden Model =====", $time);
    $display("[%t] Running %0d random addition operations...", $time, num_iterations);

    for (int i = 0; i < num_iterations; i++) begin

        // Generate random operands
        a = $urandom;
        b = $urandom;

        // Calculate expected result using golden model (software)
        expected_result = {1'b0, a} + {1'b0, b};
        expected_sum = expected_result[31:0];
        expected_carry = {31'h0, expected_result[32]};

        // Perform operation on DUT
        perform_addition(a, b, sum, carry);

        // Check results
        if (sum !== expected_sum) begin
            $error("[%t] ERROR: Iteration %0d - Sum mismatch", $time, i);
            $display("        Operands: 0x%08x + 0x%08x", a, b);
            $display("        Expected sum: 0x%08x", expected_sum);
            $display("        Actual sum:   0x%08x", sum);
            error_count++;
            test_passed = 0;
            operations_failed++;
        end

        if (carry !== expected_carry) begin
            $error("[%t] ERROR: Iteration %0d - Carry mismatch", $time, i);
            $display("        Operands: 0x%08x + 0x%08x", a, b);
            $display("        Expected carry: 0x%08x", expected_carry);
            $display("        Actual carry:   0x%08x", carry);
            error_count++;
            test_passed = 0;
            operations_failed++;
        end

        if (test_passed) begin
            operations_passed++;
            // Verbose output - can enable for debugging
            // $display("[%t] Iteration %0d PASS: 0x%08x + 0x%08x = 0x%08x (carry: 0x%08x)",
            //          $time, i, a, b, sum, carry);
        end

        // Progress indicator every 10 iterations
        if ((i > 0) && (i % 10 == 0)) begin
            $display("[%t] Progress: %0d/%0d iterations completed", $time, i, num_iterations);
        end

        // Small delay between iterations
        delay_ns(50);
    end

    $display("\n[%t] Random test completed", $time);
    $display("        Operations passed: %0d", operations_passed);
    $display("        Operations failed: %0d", operations_failed);
    $display("        Pass rate: %0.2f%%", (operations_passed * 100.0) / num_iterations);

    delay_ns(200);

    //==========================================================================
    // Test 2: Random Control Flow
    //==========================================================================
    $display("\n[%t] ===== Test 2: Random Control Flow =====", $time);
    $display("[%t] Testing random sequences of operations...", $time);

    for (int i = 0; i < 20; i++) begin

        operation_type = $urandom % 4;

        case (operation_type)
            0: begin
                // Normal operation with both reads
                a = $urandom;
                b = $urandom;
                perform_addition(a, b, sum, carry);
            end

            1: begin
                // Operation with only sum read
                a = $urandom;
                b = $urandom;
                write_operands(a, b);
                trigger_addition();
                delay_ns(200);
                read_sum(sum);
            end

            2: begin
                // Operation with only carry read
                a = $urandom;
                b = $urandom;
                write_operands(a, b);
                trigger_addition();
                delay_ns(200);
                read_carry(carry);
            end

            3: begin
                // Multiple writes before trigger
                for (int j = 0; j < 3; j++) begin
                    write_operands($urandom, $urandom);
                end
                trigger_addition();
                delay_ns(200);
                read_results(sum, carry);
            end
        endcase

        // Verbose output - can enable for debugging
        // $display("[%t] Random flow iteration %0d, type %0d completed", $time, i, operation_type);

        delay_ns(100);
    end

    $display("[%t] Random control flow test completed", $time);

    delay_ns(200);

    //==========================================================================
    // Test 3: Random Boundary Cases
    //==========================================================================
    $display("\n[%t] ===== Test 3: Random Boundary Cases =====", $time);

    // Generate operations with boundary numbers
    for (int i = 0; i < 10; i++) begin
        case_type = $urandom % 5;

        case (case_type)
            0: begin  // Large numbers
                a = 32'hFFFF0000 | ($urandom & 32'h0000FFFF);
                b = 32'hFFFF0000 | ($urandom & 32'h0000FFFF);
            end

            1: begin  // Small numbers
                a = 32'h0000FFFF & $urandom;
                b = 32'h0000FFFF & $urandom;
            end

            2: begin  // Powers of 2
                a = 32'h1 << ($urandom % 32);
                b = 32'h1 << ($urandom % 32);
            end

            3: begin  // One operand near max
                a = 32'hFFFFFFFF - ($urandom % 256);
                b = $urandom;
            end

            4: begin  // Completely random
                a = $urandom;
                b = $urandom;
            end
        endcase

        // Golden model
        expected_result = {1'b0, a} + {1'b0, b};

        perform_addition(a, b, sum, carry);

        check_value(sum, expected_result[31:0], $sformatf("Boundary case %0d - sum", i));
        check_value(carry, {31'h0, expected_result[32]}, $sformatf("Boundary case %0d - carry", i));

        delay_ns(100);
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

endmodule // test_random
