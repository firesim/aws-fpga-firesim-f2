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

// Test Stress AXI-Lite
//
// This test covers:
// - Test 1: Back-to-Back Write Transactions
// - Test 2: Alternating Write Transactions
// - Test 3: Back-to-Back Read Transactions
// - Test 4: Alternating Read Transactions
// - Test 5: Mixed Read/Write Transactions
// - Test 6: Sequential Complete Operations
// - Test 7: Read All Registers Sequentially
// - Test 8: Rapid Operations Stress Test

module test_stress_axil();

`include "test_base.inc"

logic[31:0] rdata;
logic[31:0] test_values[10];
logic[31:0] sum, carry;
logic[31:0] ctrl_stat;

initial begin
    $display("\n");
    $display("================================================================================");
    $display(" TEST: test_stress_axil");
    $display("================================================================================");

    power_up();
    delay_ns(1000);

    // Generate test values
    for (int i = 0; i < 10; i++) begin
        test_values[i] = 32'h10000000 + (i * 32'h01010101);
    end

    //==========================================================================
    // Test 1: Back-to-Back Write Transactions
    //==========================================================================
    $display("\n[%t] ===== Test 1: Back-to-Back Write Transactions =====", $time);

    // Write to operand_a multiple times with minimal delay
    $display("[%t] Performing back-to-back writes to operand_a...", $time);
    for (int i = 0; i < 10; i++) begin
        write_operand_a(test_values[i]);
        // Minimal or no delay between writes
    end

    delay_ns(100);

    // Verify last write took effect
    read_operand_a(rdata);
    check_value(rdata, test_values[9], "Last write in back-to-back sequence");

    delay_ns(100);

    // Write to operand_b multiple times with minimal delay
    $display("[%t] Performing back-to-back writes to operand_b...", $time);
    for (int i = 0; i < 10; i++) begin
        write_operand_b(test_values[i]);
    end

    delay_ns(100);

    // Verify last write
    read_operand_b(rdata);
    check_value(rdata, test_values[9], "Last write to operand_b");

    delay_ns(200);

    //==========================================================================
    // Test 2: Alternating Write Transactions
    //==========================================================================
    $display("\n[%t] ===== Test 2: Alternating Writes =====", $time);

    // Alternate between operand_a and operand_b writes
    $display("[%t] Alternating writes between operand_a and operand_b...", $time);
    for (int i = 0; i < 5; i++) begin
        write_operand_a(32'hAAAA0000 + i);
        write_operand_b(32'h55550000 + i);
    end

    delay_ns(100);

    // Verify final values
    read_operand_a(rdata);
    check_value(rdata, 32'hAAAA0004, "Alternating writes - operand_a");

    read_operand_b(rdata);
    check_value(rdata, 32'h55550004, "Alternating writes - operand_b");

    delay_ns(200);

    //==========================================================================
    // Test 3: Back-to-Back Read Transactions
    //==========================================================================
    $display("\n[%t] ===== Test 3: Back-to-Back Read Transactions =====", $time);

    // Set known values
    write_operands(32'h12345678, 32'h87654321);
    delay_ns(100);

    // Perform multiple back-to-back reads
    $display("[%t] Performing back-to-back reads from operand_a...", $time);
    for (int i = 0; i < 10; i++) begin
        read_operand_a(rdata);
        check_value(rdata, 32'h12345678, $sformatf("Back-to-back read %0d", i));
    end

    delay_ns(100);

    // Back-to-back reads from operand_b
    $display("[%t] Performing back-to-back reads from operand_b...", $time);
    for (int i = 0; i < 10; i++) begin
        read_operand_b(rdata);
        check_value(rdata, 32'h87654321, $sformatf("Back-to-back read %0d", i));
    end

    delay_ns(200);

    //==========================================================================
    // Test 4: Alternating Read Transactions
    //==========================================================================
    $display("\n[%t] ===== Test 4: Alternating Reads =====", $time);

    // Alternate between reading different registers
    $display("[%t] Alternating reads between registers...", $time);
    for (int i = 0; i < 5; i++) begin
        read_operand_a(rdata);
        check_value(rdata, 32'h12345678, $sformatf("Alt read %0d - operand_a", i));

        read_operand_b(rdata);
        check_value(rdata, 32'h87654321, $sformatf("Alt read %0d - operand_b", i));
    end

    delay_ns(200);

    //==========================================================================
    // Test 5: Mixed Read/Write Transactions
    //==========================================================================
    $display("\n[%t] ===== Test 5: Mixed Read/Write Transactions =====", $time);

    // Perform rapid sequence of reads and writes
    $display("[%t] Performing mixed read/write sequence...", $time);
    for (int i = 0; i < 5; i++) begin
        // Write
        write_operand_a(32'h11110000 + i);

        // Read back immediately
        read_operand_a(rdata);
        check_value(rdata, 32'h11110000 + i, $sformatf("Mixed R/W %0d", i));

        // Write to different register
        write_operand_b(32'h22220000 + i);

        // Read back
        read_operand_b(rdata);
        check_value(rdata, 32'h22220000 + i, $sformatf("Mixed R/W %0d - operand_b", i));
    end

    delay_ns(200);

    //==========================================================================
    // Test 6: Sequential Complete Operations
    //==========================================================================
    $display("\n[%t] ===== Test 6: Sequential Complete Operations =====", $time);

    // Perform multiple complete addition operations rapidly
    $display("[%t] Performing sequential additions...", $time);
    for (int i = 0; i < 5; i++) begin
        write_operands(32'h1000 * (i+1), 32'h2000 * (i+1));
        trigger_addition();
        delay_ns(200);  // Small delay for operation

        read_results(sum, carry);
        $display("[%t] Operation %0d: 0x%08x + 0x%08x = 0x%08x (carry: 0x%08x)",
                 $time, i, 32'h1000 * (i+1), 32'h2000 * (i+1), sum, carry);
    end

    delay_ns(200);

    //==========================================================================
    // Test 7: Read All Registers Sequentially
    //==========================================================================
    $display("\n[%t] ===== Test 7: Read All Registers Sequentially =====", $time);

    // Set all writable registers
    write_operands(32'hFEEDBEEF, 32'hDEADC0DE);
    delay_ns(100);

    // Perform addition
    trigger_addition();
    delay_ns(200);

    // Read all registers in sequence with minimal delay
    $display("[%t] Reading all registers sequentially...", $time);
    read_operand_a(rdata);
    $display("[%t] operand_a: 0x%08x", $time, rdata);

    read_operand_b(rdata);
    $display("[%t] operand_b: 0x%08x", $time, rdata);

    read_sum(rdata);
    $display("[%t] sum: 0x%08x", $time, rdata);

    read_carry(rdata);
    $display("[%t] carry: 0x%08x", $time, rdata);

    read_control_status(ctrl_stat);
    $display("[%t] control_status: 0x%08x", $time, ctrl_stat);

    delay_ns(200);

    //==========================================================================
    // Test 8: Rapid Operations Stress Test
    //==========================================================================
    $display("\n[%t] ===== Test 8: Rapid Operations Stress Test =====", $time);

    // Perform many operations rapidly
    $display("[%t] Performing 20 rapid operations...", $time);
    for (int i = 0; i < 20; i++) begin
        write_operands($urandom, $urandom);
        trigger_addition();
        delay_ns(100);
        read_results(sum, carry);
        // Minimal delay between operations
    end

    $display("[%t] Stress test completed", $time);

    //==========================================================================
    // Test Summary
    //==========================================================================
    delay_ns(1000);
    power_down();

    $display("\n[%t] Test completed", $time);
    report_pass_fail_status();

    $finish;
end

endmodule // test_stress_axil
