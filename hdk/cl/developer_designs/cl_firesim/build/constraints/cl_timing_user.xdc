# =============================================================================
# Amazon FPGA Hardware Development Kit
#
# Copyright 2024 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#    http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions and
# limitations under the License.
# =============================================================================

#################################################################################
### Generated Clocks
#################################################################################
# Alias of Shell interface clock
set clk_main_a0 [get_clocks -of_objects [get_ports clk_main_a0]]

# Alias of Firesim internal clock (AWS_CLK_GEN clk_extra_a1 = 125 MHz under A1 recipe)
set clk_firesim [get_clocks -of_objects \
    [get_pins -of_objects \
        [get_cells -hierarchical -regexp {.*AWS_CLK_GEN/CLK_GRP_A_EN_I.CLK_MMCM_A_I/inst/CLK_CORE_DRP_I/clk_inst/mmcme4_adv_inst}] \
        -filter {NAME=~*CLKOUT0}]]


###############################################################################
# FireSim reset synchronizer false paths
###############################################################################
# The FireSim reset synchronizer registers (now clocked by AWS_CLK_GEN
# clk_extra_a1) have async CLR pins driven from rst_main_n in the shell clock
# domain.  These are standard CDC reset synchronizers.
set_false_path -to [get_pins -hierarchical *pre_sync_rst_n_firesim_reg/CLR]
set_false_path -to [get_pins -hierarchical *rst_firesim_n_sync_reg/CLR]

# FROM MEM_PERF TIMING.XDC:
#################################################################################
### Clock Groups
#################################################################################
# false path inside sh_ddr
set_false_path -from [get_pins -of_objects \
                          [get_cells -hierarchical -filter { NAME =~ *ram_reg*}] -filter {REF_PIN_NAME == CLK}] \
               -to   [get_cells -hierarchical -filter { NAME =~ *rd_do_reg[*]}]

set_clock_groups -asynchronous \
    -group [get_clocks clk_main_a0] \
    -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME=~*SH_DDR/genblk1.IS_DDR_PRESENT.DDR4_0/inst/u_ddr4_infrastructure/gen_mmcme4.u_mmcme_adv_inst/CLKOUT0}]]


# XPM CDC:
set_false_path -from \
    [get_pins -of_objects \
         [get_cells -hierarchical -filter {PRIMITIVE_SUBGROUP==LUTRAM && NAME=~ *gnuram_async_fifo.xpm_fifo_base_inst*}]\
         -filter {REF_PIN_NAME == CLK}] \
    -to \
    [get_cells -hierarchical -filter {NAME =~ *doutb*reg* && PRIMITIVE_TYPE =~ REGISTER* && RTL_RAM_TYPE == "" }]
# END MEM_PERF TIMING.XDC

set_clock_groups -asynchronous -group [get_clocks clk_main_a0] \
    -group $clk_firesim

#################################################################################
### Timing Exceptions
#################################################################################
set_multicycle_path -from [get_pins -regexp -filter {NAME =~ ".*\/C"} -of_objects [get_cells -hierarchical -regexp -filter { NAME =~  ".*PIPE_DDR_STAT0.*pipe_reg\[3\].*" }]] -setup 2
set_multicycle_path -from [get_pins -regexp -filter {NAME =~ ".*\/C"} -of_objects [get_cells -hierarchical -regexp -filter { NAME =~  ".*PIPE_DDR_STAT0.*pipe_reg\[3\].*" }]] -hold 1
set_multicycle_path -from [get_pins -regexp -filter {NAME =~ ".*\/C"} -of_objects [get_cells -hierarchical -regexp -filter { NAME =~  ".*PIPE_DDR_STAT_ACK0.*pipe_reg\[3\].*" }]] -setup 2
set_multicycle_path -from [get_pins -regexp -filter {NAME =~ ".*\/C"} -of_objects [get_cells -hierarchical -regexp -filter { NAME =~  ".*PIPE_DDR_STAT_ACK0.*pipe_reg\[3\].*" }]] -hold 1


###############################################################################
# Shell reset (rst_main_n) false paths to CL synchronizer CLR pins
###############################################################################
# rst_main_n is driven by an FDRE in the static partition (clk_main_a0 domain).
# It fans out to the async CLR pins of synchronizer registers inside the CL
# partition.  These are proper reset synchronizer chains — the recovery timing
# across the partition boundary is inherently asynchronous and safe to exclude.
set_false_path -to [get_pins -quiet -hierarchical -filter {NAME =~ */rst_main_n_sync_reg/CLR}]
set_false_path -to [get_pins -quiet -hierarchical -filter {NAME =~ */rst_main_n_sync_reg_replica/CLR}]
set_false_path -to [get_pins -hierarchical *ddr_ready_pre_sync_meta_reg/CLR]
set_false_path -to [get_pins -hierarchical *ddr_ready_sync_reg/CLR]

###############################################################################
# Blanket false-path for DDR4 MMCM output clock (mmcm_clkout0)
###############################################################################
# set_false_path -from [get_clocks -of_objects [get_pins -hierarchical -regexp {*mmcm_clkout0}]]
# set_false_path -to   [get_clocks -of_objects [get_pins -hierarchical -regexp {*mmcm_clkout0}]]

###############################################################################
# False-path between clk_main_a0 and its CL partition-boundary copy
###############################################################################
set_false_path -from [get_clocks -quiet {WRAPPER/CL/clk_main_a0}] -to [get_clocks clk_main_a0]
set_false_path -from [get_clocks clk_main_a0] -to [get_clocks -quiet {WRAPPER/CL/clk_main_a0}]