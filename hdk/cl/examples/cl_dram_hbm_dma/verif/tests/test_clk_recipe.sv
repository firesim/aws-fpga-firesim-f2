// ============================================================================
// Amazon FPGA Hardware Development Kit
//
// Copyright 2024 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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


module test_clk_recipe();
   import tb_type_defines_pkg::*;

   `include "base_test_utils.svh";

   initial begin

      //power up with Clock Recipe A0
      $display("power up with Clock Recipe A0 \n");
      tb.power_up(.clk_recipe_a(ClockRecipe::A0));

      // delay before checking the clocks
      #500ns;

      //Starts checking clock frequency.
      tb.set_chk_clk_freq(.chk_freq(1'b1));

      #2000ns;

      //Stop checking clock frequency.
      tb.set_chk_clk_freq(.chk_freq(1'b0));

      // Power down
      tb.power_down();

      #500ns;
      //power up with Clock Recipe A1
      $display("power up with Clock Recipe A1 \n");
      tb.power_up(.clk_recipe_a(ClockRecipe::A1));

      // delay before checking the clocks
      #500ns;

      //Starts checking clock frequency.
      tb.set_chk_clk_freq(.chk_freq(1'b1));

      #2000ns;

      //Stop checking clock frequency.
      tb.set_chk_clk_freq(.chk_freq(1'b0));

      tb.power_down();

      #500ns;
      //power up with Clock Recipe A2
      $display("power up with Clock Recipe A2 \n");
      tb.power_up(.clk_recipe_a(ClockRecipe::A2));

      // delay before checking the clocks
      #500ns;

      //Starts checking clock frequency.
      tb.set_chk_clk_freq(.chk_freq(1'b1));

      #2000ns;

      //Stop checking clock frequency.
      tb.set_chk_clk_freq(.chk_freq(1'b0));

      tb.power_down();

      if (tb.chk_clk_err_cnt()) begin
         error_count++;
         $error("[%t] : Observed clock errors", $realtime);
      end

      report_pass_fail_status();

      $finish;
   end // initial begin

endmodule // test_clk_recipe
