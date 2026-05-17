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


#---- Developr would replace this section with design files ----
## Change file names and paths below to reflect your CL area. DO NOT include AWS RTL files.

set UNUSED_TEMPLATES_DIR $HDK_SHELL_DESIGN_DIR/interfaces

file copy -force $CL_DIR/design/cl_axi_ctl.sv                               $src_post_enc_dir
file copy -force $CL_DIR/design/cl_kernel_ctl.sv                            $src_post_enc_dir
file copy -force $CL_DIR/design/cl_kernel_regs.sv                           $src_post_enc_dir
file copy -force $CL_DIR/design/cl_kernel_req.sv                            $src_post_enc_dir
file copy -force $CL_DIR/design/cl_clk_freq.sv                              $src_post_enc_dir
file copy -force $CL_DIR/design/cl_hbm_perf_kernel.sv                       $src_post_enc_dir
file copy -force $CL_DIR/design/cl_mem_hbm_axi4.sv                          $src_post_enc_dir
file copy -force $CL_DIR/design/cl_mem_hbm_wrapper.sv                       $src_post_enc_dir
file copy -force $CL_DIR/design/cl_mem_ocl_dec.sv                           $src_post_enc_dir
file copy -force $CL_DIR/design/cl_mem_pcis_dec.sv                          $src_post_enc_dir
file copy -force $CL_DIR/design/cl_mem_perf_defines.vh                      $src_post_enc_dir
file copy -force $CL_DIR/design/cl_id_defines.vh                            $src_post_enc_dir
file copy -force $CL_DIR/design/cl_mem_perf.sv                              $src_post_enc_dir

# RTL source from CL_DRAM_HBM_DMA
file copy -force $CL_DIR/../cl_dram_hbm_dma/design/cl_tst.sv                $src_post_enc_dir
file copy -force $CL_DIR/../cl_dram_hbm_dma/design/cl_int_tst.sv            $src_post_enc_dir
file copy -force $CL_DIR/../cl_dram_hbm_dma/design/mem_scrb.sv              $src_post_enc_dir
file copy -force $CL_DIR/../cl_dram_hbm_dma/design/cl_tst_scrb.sv           $src_post_enc_dir
file copy -force $CL_DIR/../cl_dram_hbm_dma/design/axil_slave.sv            $src_post_enc_dir
file copy -force $CL_DIR/../cl_dram_hbm_dma/design/cl_int_slv.sv            $src_post_enc_dir
file copy -force $CL_DIR/../cl_dram_hbm_dma/design/cl_pcim_mstr.sv          $src_post_enc_dir
file copy -force $CL_DIR/../cl_dram_hbm_dma/design/cl_vio.sv                $src_post_enc_dir
file copy -force $CL_DIR/../cl_dram_hbm_dma/design/cl_ila.sv                $src_post_enc_dir
file copy -force $CL_DIR/../cl_dram_hbm_dma/design/cl_sda_slv.sv            $src_post_enc_dir
file copy -force $CL_DIR/../cl_dram_hbm_dma/design/cl_dram_dma_axi_mstr.sv  $src_post_enc_dir
file copy -force $CL_DIR/../cl_dram_hbm_dma/design/cl_dram_dma_pkg.sv       $src_post_enc_dir

#---- End of section replaced by Developr ---


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
