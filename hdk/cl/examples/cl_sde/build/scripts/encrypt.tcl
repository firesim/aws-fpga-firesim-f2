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

# Remove any previously encrypted files, that may no longer be used
if {[llength [glob -nocomplain -dir $src_post_enc_dir *]] != 0} {
  eval file delete -force [glob $src_post_enc_dir/*]
}


#---- Developer would replace this section with design files ----
## Change file names and paths below to reflect your CL area. DO NOT include AWS RTL files.

set UNUSED_TEMPLATES_DIR $HDK_SHELL_DESIGN_DIR/interfaces

file copy -force $UNUSED_TEMPLATES_DIR/unused_flr_template.inc        $src_post_enc_dir
file copy -force $UNUSED_TEMPLATES_DIR/unused_ddr_template.inc        $src_post_enc_dir
file copy -force $UNUSED_TEMPLATES_DIR/unused_cl_sda_template.inc     $src_post_enc_dir
file copy -force $UNUSED_TEMPLATES_DIR/unused_apppf_irq_template.inc  $src_post_enc_dir

file copy -force $CL_DIR/design/ila_axi4_wrapper.sv                   $src_post_enc_dir
file copy -force $CL_DIR/design/sde_pkg.sv                            $src_post_enc_dir
file copy -force $CL_DIR/design/sde.sv                                $src_post_enc_dir
file copy -force $CL_DIR/design/sde_c2h.sv                            $src_post_enc_dir
file copy -force $CL_DIR/design/sde_c2h_axis.sv                       $src_post_enc_dir
file copy -force $CL_DIR/design/sde_c2h_buf.sv                        $src_post_enc_dir
file copy -force $CL_DIR/design/sde_c2h_cfg.sv                        $src_post_enc_dir
file copy -force $CL_DIR/design/sde_c2h_data.sv                       $src_post_enc_dir
file copy -force $CL_DIR/design/sde_h2c.sv                            $src_post_enc_dir
file copy -force $CL_DIR/design/sde_h2c_axis.sv                       $src_post_enc_dir
file copy -force $CL_DIR/design/sde_h2c_buf.sv                        $src_post_enc_dir
file copy -force $CL_DIR/design/sde_h2c_cfg.sv                        $src_post_enc_dir
file copy -force $CL_DIR/design/sde_h2c_data.sv                       $src_post_enc_dir
file copy -force $CL_DIR/design/sde_wb.sv                             $src_post_enc_dir
file copy -force $CL_DIR/design/sde_desc.sv                           $src_post_enc_dir
file copy -force $CL_DIR/design/sde_pm.sv                             $src_post_enc_dir
file copy -force $CL_DIR/design/sde_ps_acc.sv                         $src_post_enc_dir
file copy -force $CL_DIR/design/sde_ps.sv                             $src_post_enc_dir
file copy -force $CL_DIR/design/cl_sde_defines.vh                     $src_post_enc_dir
file copy -force $CL_DIR/design/cl_id_defines.vh                      $src_post_enc_dir
file copy -force $CL_DIR/design/cl_pkt_tst.sv                         $src_post_enc_dir
file copy -force $CL_DIR/design/cl_tst.sv                             $src_post_enc_dir
file copy -force $CL_DIR/design/cl_sde_srm.sv                         $src_post_enc_dir
file copy -force $CL_DIR/design/cl_sde.sv                             $src_post_enc_dir
file copy -force $CL_DIR/design/axi_prot_chk.sv                       $src_post_enc_dir

#---- End of section replaced by Developer ---


# Make sure files have write permissions for the encryption
exec chmod +w {*}[glob ${src_post_enc_dir}/*]

# Optional encryption
if {$ENCRYPT} {
  print "Encryption enabled. Encrypting HDL files and DCPs."
  encrypt -k ${HDK_SHELL_DIR}/build/scripts/vivado_keyfile.txt      -lang verilog -quiet [glob -nocomplain -- ${src_post_enc_dir}/*.{v,sv,vh,inc}]
  encrypt -k ${HDK_SHELL_DIR}/build/scripts/vivado_vhdl_keyfile.txt -lang vhdl    -quiet [glob -nocomplain -- ${src_post_enc_dir}/*.vhd?]
} else {
  print "Encryption disabled."
}
