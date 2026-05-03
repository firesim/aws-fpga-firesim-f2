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

// FSM Coverage Module - Bind module for cl_axil_reg_access FSM verification
// Provides functional coverage and SVA assertions for FSM behavior

module cl_axil_fsm_coverage ();

    // Hierarchical references to DUT signals
    wire clk           = cl_axil_reg_access.clk_main_a0;
    wire rst_n         = cl_axil_reg_access.rst_main_n;
    wire [2:0] current_state = cl_axil_reg_access.current_state;

    // State encodings matching DUT
    localparam logic [2:0] IDLE       = 3'd0;
    localparam logic [2:0] WRITE_WAIT = 3'd1;
    localparam logic [2:0] WRITE      = 3'd2;
    localparam logic [2:0] WRITE_RESP = 3'd3;
    localparam logic [2:0] READ       = 3'd4;

    // Track previous state for transition coverage
    logic [2:0] prev_state;

    always_ff @(posedge clk) begin
        prev_state <= current_state;
    end

    // =========================================================================
    // Covergroup: FSM State and Transition Coverage
    // =========================================================================
    covergroup fsm_cg @(posedge clk);
        cp_state: coverpoint current_state {
            bins idle       = {IDLE};
            bins write_wait = {WRITE_WAIT};
            bins write      = {WRITE};
            bins write_resp = {WRITE_RESP};
            bins read       = {READ};
        }

        cp_transitions: coverpoint current_state {
            bins idle_to_idle       = (IDLE       => IDLE);
            bins idle_to_write_wait = (IDLE       => WRITE_WAIT);
            bins idle_to_write      = (IDLE       => WRITE);
            bins idle_to_read       = (IDLE       => READ);
            bins ww_to_ww           = (WRITE_WAIT => WRITE_WAIT);
            bins ww_to_write        = (WRITE_WAIT => WRITE);
            bins write_to_wresp     = (WRITE      => WRITE_RESP);
            bins wresp_to_wresp     = (WRITE_RESP => WRITE_RESP);
            bins wresp_to_idle      = (WRITE_RESP => IDLE);
            bins read_to_read       = (READ       => READ);
            bins read_to_idle       = (READ       => IDLE);
        }
    endgroup

    fsm_cg fsm_cg_inst = new();

    // =========================================================================
    // SVA Assertions
    // =========================================================================

    // Assert: No invalid state
    assert_valid_state: assert property (
        @(posedge clk) disable iff (!rst_n)
        current_state inside {IDLE, WRITE_WAIT, WRITE, WRITE_RESP, READ}
    ) else $error("Invalid state detected: %0d", current_state);

    // Assert: Legal transitions from IDLE
    assert_legal_transition_from_idle: assert property (
        @(posedge clk) disable iff (!rst_n)
        (prev_state == IDLE) |-> (current_state inside {IDLE, WRITE_WAIT, WRITE, READ})
    ) else $error("Illegal transition from IDLE to %0d", current_state);

    // Assert: Legal transitions from WRITE_WAIT
    assert_legal_transition_from_write_wait: assert property (
        @(posedge clk) disable iff (!rst_n)
        (prev_state == WRITE_WAIT) |-> (current_state inside {WRITE_WAIT, WRITE})
    ) else $error("Illegal transition from WRITE_WAIT to %0d", current_state);

    // Assert: Legal transitions from WRITE
    assert_legal_transition_from_write: assert property (
        @(posedge clk) disable iff (!rst_n)
        (prev_state == WRITE) |-> (current_state == WRITE_RESP)
    ) else $error("Illegal transition from WRITE to %0d", current_state);

    // Assert: Legal transitions from WRITE_RESP
    assert_legal_transition_from_write_resp: assert property (
        @(posedge clk) disable iff (!rst_n)
        (prev_state == WRITE_RESP) |-> (current_state inside {WRITE_RESP, IDLE})
    ) else $error("Illegal transition from WRITE_RESP to %0d", current_state);

    // Assert: Legal transitions from READ
    assert_legal_transition_from_read: assert property (
        @(posedge clk) disable iff (!rst_n)
        (prev_state == READ) |-> (current_state inside {READ, IDLE})
    ) else $error("Illegal transition from READ to %0d", current_state);

    // Assert: Reset initializes to IDLE
    assert_reset_to_idle: assert property (
        @(posedge clk)
        $fell(rst_n) |=> (current_state == IDLE)
    ) else $error("State not IDLE after reset");

    // =========================================================================
    // Coverage Report
    // =========================================================================
    final begin
        $display("FSM State Coverage: %.2f%%", fsm_cg_inst.cp_state.get_coverage());
        $display("FSM Transition Coverage: %.2f%%", fsm_cg_inst.cp_transitions.get_coverage());
    end

endmodule // cl_axil_fsm_coverage

// ============================================================================
// Bind Statement
// ============================================================================
bind cl_axil_reg_access cl_axil_fsm_coverage fsm_cov_inst();
