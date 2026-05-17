# =============================================================================
# Amazon FPGA Hardware Development Kit
#
# Copyright 2026 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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


# Common header
source ${HDK_SHELL_DIR}/build/scripts/synth_cl_header.tcl


###############################################################################
print "Reading encrypted user source files"
###############################################################################

#---- Replace with your own commands -----

# Reading the .sv and .v files, as proper designs would not require reading
# .vh, nor .inc files
read_verilog -sv [glob ${src_post_enc_dir}/*.{s,}v]

#---- End of section to be replaced ----

###############################################################################
print "Reading CL IP blocks"
###############################################################################

#---- User would uncomment and/or list IPs required in their design ----

read_ip ${HDK_IP_SRC_DIR}/axi_register_slice_light/axi_register_slice_light.xci
read_ip ${HDK_IP_SRC_DIR}/cl_debug_bridge/cl_debug_bridge.xci
read_ip ${HDK_IP_SRC_DIR}/ila_axil/ila_axil.xci

#---- End of section uncommented by the User ----

###############################################################################
print "Reading user constraints"
###############################################################################

#---- Replace with your own commands -----

read_xdc [ list \
  ${constraints_dir}/cl_synth_user.xdc \
  ${constraints_dir}/cl_timing_user.xdc
]

set_property PROCESSING_ORDER LATE [get_files cl_synth_user.xdc]
set_property PROCESSING_ORDER LATE [get_files cl_timing_user.xdc]

#---- End of section to be replaced ----


###############################################################################
print "Starting synthesis of customer's design ${CL}"
###############################################################################
update_compile_order -fileset sources_1

synth_design -mode out_of_context \
             -top ${CL} \
             -verilog_define XSDB_SLV_DIS \
             -part ${DEVICE_TYPE} \
             -keep_equivalent_registers

###############################################################################
print "Connecting ILA"
###############################################################################

#---- Replace with your own commands -----

# set cl_ila_cells [get_cells -hier *ILA*]
# if {$cl_ila_cells != ""} {
#   connect_debug_cores -master [get_cells [get_debug_cores -filter {NAME=~*CL_DEBUG_BRIDGE*}]] \
#                       -slaves $cl_ila_cells
# }

#---- End of section to be replaced ----


# Common footer
source ${HDK_SHELL_DIR}/build/scripts/synth_cl_footer.tcl
