# RM-only Out-of-Context Synthesis for F2 Nested DFX
#
# Stripped-down version of synth_cl_firesim.tcl that only synthesizes
# the reconfigurable module (RM) out-of-context. Used for PR RM builds
# where only the inner module changes.

# PR_MODULE_NAME must be set via environment variable
if {![info exists ::env(PR_MODULE_NAME)]} {
    error "PR_MODULE_NAME environment variable not set"
}
set pr_module_name $::env(PR_MODULE_NAME)

# CL_MODULE: Set default if not already defined
if {![info exists CL_MODULE]} {
    set CL_MODULE "cl_firesim"
}
set VDEFINES ""

# Common header (creates in-memory project, reads AWS components and constraints)
source ${HDK_SHELL_DIR}/build/scripts/synth_cl_header.tcl


###############################################################################
print "RM OOC Synthesis: Reading source codes for module $pr_module_name"
###############################################################################

# Generate IP instantiated in Golden-Gate generated RTL
file mkdir $CL_DIR/design/ipgen
set ipgen_scripts [glob -nocomplain $CL_DIR/design/FireSim-generated.*.ipgen.tcl]
foreach script $ipgen_scripts {
    source $script
}

# Generate targets for all IPs
generate_target all [get_ips]
synth_ip [get_ips]

########################################
## Generate clocks based on Recipe
########################################
puts "AWS FPGA: ([clock format [clock seconds] -format %T]) Calling aws_gen_clk_constraints.tcl"
source $HDK_SHELL_DIR/build/scripts/aws_gen_clk_constraints.tcl

#############################
## Read design files
#############################
set ENC_SRC_DIR $CL_DIR/build/src_post_encryption

set_property include_dirs [list \
    ${CL_DIR}/design \
    ${CL_DIR}/../common/design \
] [current_fileset]

puts "AWS FPGA: ([clock format [clock seconds] -format %T]) Reading design files for RM OOC synthesis"

# Prefer split-verilog (one file per module) for RM OOC synthesis.
# This avoids reading the full monolithic design file and is cleaner
# for out-of-context synthesis where only the RM hierarchy is needed.
set split_verilog_dir "${CL_DIR}/design/split-verilog"
if {[file isdirectory $split_verilog_dir] && [llength [glob -nocomplain ${split_verilog_dir}/*.sv]] > 0} {
    set sv_files [glob ${split_verilog_dir}/*.sv]
    puts "Using split-verilog sources ([llength $sv_files] module files)"
    read_verilog -sv $sv_files
} else {
    puts "Split-verilog not available, falling back to monolithic design files"
    read_verilog -sv [glob ${CL_DIR}/design/*.{s,}v]
}

###############################################################################
print "Reading CL IP blocks (same as full synth)"
###############################################################################

# Clocking IP's
read_ip ${HDK_SHELL_DESIGN_DIR}/../../ip/cl_ip/cl_ip.srcs/sources_1/ip/clk_mmcm_a/clk_mmcm_a.xci
read_ip ${HDK_SHELL_DESIGN_DIR}/../../ip/cl_ip/cl_ip.srcs/sources_1/ip/clk_mmcm_b/clk_mmcm_b.xci
read_ip ${HDK_SHELL_DESIGN_DIR}/../../ip/cl_ip/cl_ip.srcs/sources_1/ip/clk_mmcm_c/clk_mmcm_c.xci
read_ip ${HDK_SHELL_DESIGN_DIR}/../../ip/cl_ip/cl_ip.srcs/sources_1/ip/clk_mmcm_hbm/clk_mmcm_hbm.xci
read_ip ${HDK_SHELL_DESIGN_DIR}/../../ip/cl_ip/cl_ip.srcs/sources_1/ip/cl_clk_axil_xbar/cl_clk_axil_xbar.xci
read_ip ${HDK_SHELL_DESIGN_DIR}/../../ip/cl_ip/cl_ip.srcs/sources_1/ip/cl_sda_axil_xbar/cl_sda_axil_xbar.xci

# AXI Register Slice IP's
read_ip ${HDK_IP_SRC_DIR}/cl_axi_register_slice/cl_axi_register_slice.xci
read_ip ${HDK_IP_SRC_DIR}/cl_axi_register_slice_light/cl_axi_register_slice_light.xci
read_ip ${HDK_IP_SRC_DIR}/src_register_slice/src_register_slice.xci
read_ip ${HDK_IP_SRC_DIR}/dest_register_slice/dest_register_slice.xci
read_ip ${HDK_IP_SRC_DIR}/axi_register_slice/axi_register_slice.xci
read_ip ${HDK_IP_SRC_DIR}/axi_register_slice_light/axi_register_slice_light.xci
read_ip ${HDK_IP_SRC_DIR}/cl_axi_register_slice_256/cl_axi_register_slice_256.xci
read_ip ${HDK_IP_SRC_DIR}/cl_axi3_256b_reg_slice/cl_axi3_256b_reg_slice.xci

read_ip ${HDK_IP_SRC_DIR}/cl_debug_bridge/cl_debug_bridge.xci
read_ip ${HDK_IP_SRC_DIR}/ila_1/ila_1.xci
read_ip ${HDK_IP_SRC_DIR}/ila_vio_counter/ila_vio_counter.xci
read_ip ${HDK_IP_SRC_DIR}/vio_0/vio_0.xci

read_ip [ list \
  ${HDK_IP_SRC_DIR}/axi_clock_converter_0/axi_clock_converter_0.xci \
  $CL_DIR/ip/axi_clock_converter_dramslim/axi_clock_converter_dramslim.xci \
  $CL_DIR/ip/axi_clock_converter_oclnew/axi_clock_converter_oclnew.xci \
  $CL_DIR/ip/axi_clock_converter_512_wide/axi_clock_converter_512_wide.xci \
  $CL_DIR/ip/axi_clock_converter_512_pcim/axi_clock_converter_512_pcim.xci \
  $CL_DIR/ip/axi_dwidth_converter_0/axi_dwidth_converter_0.xci
]

read_ip [ list \
  ${HDK_IP_SRC_DIR}/cl_axi_clock_converter/cl_axi_clock_converter.xci \
  ${HDK_IP_SRC_DIR}/cl_axi_clock_converter_light/cl_axi_clock_converter_light.xci
]

read_ip [ list \
  ${HDK_IP_SRC_DIR}/cl_ddr4_32g/cl_ddr4_32g.xci \
  ${HDK_IP_SRC_DIR}/cl_ddr4_32g_ap/cl_ddr4_32g_ap.xci \
  ${HDK_IP_SRC_DIR}/cl_ddr4/cl_ddr4.xci \
  ${HDK_IP_SRC_DIR}/cl_ddr4_64g_ap/cl_ddr4_64g_ap.xci
]
read_ip [ list \
 ${HDK_IP_SRC_DIR}/cl_axi_interconnect/cl_axi_interconnect.xci \
 ${HDK_IP_SRC_DIR}/cl_axi_interconnect_64G_ddr/cl_axi_interconnect_64G_ddr.xci
]

###############################################################################
print "Reading user constraints"
###############################################################################

read_xdc [ list \
  ${constraints_dir}/cl_synth_user.xdc \
  ${constraints_dir}/cl_timing_user.xdc
]

set_property PROCESSING_ORDER LATE [get_files cl_synth_user.xdc]
set_property PROCESSING_ORDER LATE [get_files cl_timing_user.xdc]

# FireSim custom clocking
source $CL_DIR/build/scripts/synth_firesim_clk_wiz.tcl

#===============================================================================
# IP regeneration for F2 (same as full synth)
#===============================================================================
upgrade_ip [get_ips axi_clock_converter_512_wide]
reset_target {all} [get_ips axi_clock_converter_512_wide]
set_property CONFIG.ID_WIDTH 16 [get_ips axi_clock_converter_512_wide]
generate_target {all} [get_ips axi_clock_converter_512_wide]
synth_ip [get_ips axi_clock_converter_512_wide]

upgrade_ip [get_ips axi_dwidth_converter_0]
reset_target {all} [get_ips axi_dwidth_converter_0]
set_property CONFIG.FIFO_MODE {0} [get_ips axi_dwidth_converter_0]
generate_target {all} [get_ips axi_dwidth_converter_0]
synth_ip [get_ips axi_dwidth_converter_0]

upgrade_ip [get_ips axi_clock_converter_dramslim]
reset_target {all} [get_ips axi_clock_converter_dramslim]
generate_target {all} [get_ips axi_clock_converter_dramslim]
synth_ip [get_ips axi_clock_converter_dramslim]

upgrade_ip [get_ips axi_clock_converter_oclnew]
reset_target {all} [get_ips axi_clock_converter_oclnew]
generate_target {all} [get_ips axi_clock_converter_oclnew]
synth_ip [get_ips axi_clock_converter_oclnew]

upgrade_ip [get_ips axi_clock_converter_512_pcim]
reset_target {all} [get_ips axi_clock_converter_512_pcim]
generate_target {all} [get_ips axi_clock_converter_512_pcim]
synth_ip [get_ips axi_clock_converter_512_pcim]

#===============================================================================

set_property USED_IN {synthesis implementation OUT_OF_CONTEXT} [get_files generated_cl_clocks_aws.xdc]
set_property PROCESSING_ORDER EARLY  [get_files generated_cl_clocks_aws.xdc]

########################
# RM OOC Synthesis
########################

###############################################################################
print "Starting OOC synthesis of RM module: $pr_module_name"
###############################################################################
update_compile_order -fileset sources_1

synth_design -mode out_of_context \
             -top $pr_module_name \
             -verilog_define XSDB_SLV_DIS \
             -part ${DEVICE_TYPE} \
             -keep_equivalent_registers

set failval [catch {exec grep "FAIL" failfast.csv}]
if { $failval==0 } {
    puts "AWS FPGA: FATAL ERROR--Resource utilization error; check failfast.csv for details"
    exit 1
}

set timestamp [clock format [clock seconds] -format "%y_%m_%d-%H%M%S"]
puts "AWS FPGA: ([clock format [clock seconds] -format %T]) writing RM post synth checkpoint."
write_checkpoint -force ${checkpoints_dir}/${pr_module_name}.post_synth.dcp

report_utilization -hierarchical -hierarchical_percentages -file ${reports_dir}/${timestamp}.${pr_module_name}.post_synth_utilization.rpt

source ${HDK_SHELL_DIR}/build/scripts/synth_cl_footer.tcl
