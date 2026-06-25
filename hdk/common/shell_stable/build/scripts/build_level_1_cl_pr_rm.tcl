# =============================================================================
# F2 Nested DFX: PR RM Build (Reconfigurable Module implementation)
#
# Uses an abstract shell from a prior PR base build to implement only
# the changed inner RM. The abstract shell contains the locked static
# design with the inner RP as a black box.
#
# Flow:
#   1. Open abstract shell checkpoint
#   2. Read the new RM synthesis checkpoint into the inner RP cell
#   3. Apply constraints
#   4. Implement (opt + place + phys_opt + route) — only RM is placed/routed
#   5. pr_recombine to restore WRAPPER/CL as the single RP
#   6. Write final post_route DCP for tarball generation
#
# Environment variables required:
#   PR_ABSTRACT_SHELL_DCP - Path to abstract shell DCP from base build
#   PR_PARTITION_CELL - Hierarchical path to the inner RP cell
#   PR_MODULE_NAME - Name of the new RM module
# =============================================================================


###############################################################################
print "PR RM Build: Opening abstract shell"
###############################################################################

set pr_abstract_shell $::env(PR_ABSTRACT_SHELL_DCP)
set pr_cell $::env(PR_PARTITION_CELL)
set pr_module_name $::env(PR_MODULE_NAME)

puts "Abstract shell: $pr_abstract_shell"
puts "Partition cell: $pr_cell"
puts "RM module name: $pr_module_name"

open_checkpoint $pr_abstract_shell

# Check if the partition cell is a black-box; if not, force it.
# pr_subdivide creates the abstract shell in-memory, but the black-box
# state may not survive write_checkpoint/open_checkpoint round-tripping.
set bb_cells [get_cells -quiet -hierarchical -filter {IS_BLACKBOX == 1}]
puts "Black-box cells after opening abstract shell: $bb_cells"

if {[llength [get_cells -quiet $pr_cell -filter {IS_BLACKBOX == 1}]] == 0} {
    puts "WARNING: $pr_cell is not a black-box. Forcing black-box with update_design."
    update_design -cell $pr_cell -black_box
    # Lock static routing so only the RM cell is re-implemented
    lock_design -level routing
}

###############################################################################
print "PR RM Build: Loading RM synthesis checkpoint into $pr_cell"
###############################################################################

# The RM synth DCP was produced by synth_cl_firesim_pr_rm.tcl
set rm_synth_dcp ${checkpoints_dir}/${CL}.${TAG}.post_synth.dcp
puts "Reading RM synth DCP: $rm_synth_dcp"

read_checkpoint -cell $pr_cell $rm_synth_dcp

###############################################################################
print "PR RM Build: Applying constraints"
###############################################################################

# MMCM Clock recipe constraints
source $HDK_SHELL_DIR/build/scripts/aws_clock_properties.tcl

# Floorplan constraints
read_xdc ${HDK_SHELL_DIR}/build/constraints/${SHELL_MODE}_level_1_fp_cl.xdc
read_xdc ${constraints_dir}/${SHELL_MODE}_cl_pnr_user.xdc

###############################################################################
print "PR RM Build: Optimizing RM"
###############################################################################
opt_design

print "Writing post-opt RM checkpoint"
write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.rm_post_opt.dcp

report_timing -delay_type max \
              -path_type full_clock_expanded \
              -max_paths 10 \
              -nworst 1 \
              -input_pins \
              -slice_pins \
              -sort_by group \
              -significant_digits 3 \
              -file ${reports_dir}/${CL}.${TAG}.rm_post_opt_timing.rpt

###############################################################################
print "PR RM Build: Placing RM"
###############################################################################
place_design -directive $PLACE_DIRECT

print "Writing post-place RM checkpoint"
write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.rm_post_place.dcp

report_timing -delay_type max \
              -path_type full_clock_expanded \
              -max_paths 10 \
              -nworst 1 \
              -input_pins \
              -slice_pins \
              -sort_by group \
              -significant_digits 3 \
              -file ${reports_dir}/${CL}.${TAG}.rm_post_place_timing.rpt

###############################################################################
print "PR RM Build: Physical optimization of RM"
###############################################################################
phys_opt_design -directive $PHY_OPT_DIRECT

print "Writing post-phys_opt RM checkpoint"
write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.rm_post_phys_opt.dcp

###############################################################################
print "PR RM Build: Routing RM"
###############################################################################
route_design -directive $ROUTE_DIRECT -tns_cleanup -timing_summary

print "Writing post-route RM checkpoint"

set failPath [check_timing_path]
if {$failPath>0} {
    puts "WARNING: RM has timing violations after route"
}

write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.rm_post_route.dcp

report_timing -delay_type max \
              -path_type full_clock_expanded \
              -max_paths 10 \
              -nworst 1 \
              -input_pins \
              -slice_pins \
              -sort_by group \
              -significant_digits 3 \
              -file ${reports_dir}/${CL}.${TAG}.rm_post_route_timing.rpt

###############################################################################
print "PR RM Build: Reporting host clock frequency (inherited from base build)"
###############################################################################
# The host MMCM is in the locked static shell — we cannot adjust it in RM builds.
# Report the current frequency for informational purposes.
set rm_mmcms [get_cells -hierarchical -filter {REF_NAME =~ MMCME*} -quiet]
foreach m $rm_mmcms {
    if {[string match "*clk_wiz_0_firesim*" $m]} {
        set rm_mult_f    [get_property CLKFBOUT_MULT_F $m]
        set rm_div_clk   [get_property DIVCLK_DIVIDE $m]
        set rm_out_div_f [get_property CLKOUT0_DIVIDE_F $m]
        set rm_input_freq 250.0
        set rm_clkin_pin [get_pins -of_objects $m -filter {REF_PIN_NAME == CLKIN1} -quiet]
        if {$rm_clkin_pin ne ""} {
            set rm_clkin_period [get_property PERIOD [get_clocks -of_objects $rm_clkin_pin -quiet] -quiet]
            if {$rm_clkin_period ne "" && $rm_clkin_period > 0} {
                set rm_input_freq [expr {1000.0 / $rm_clkin_period}]
            }
        }
        set rm_vco_freq [expr {$rm_input_freq * $rm_mult_f / $rm_div_clk}]
        set rm_host_freq [expr {$rm_vco_freq / $rm_out_div_f}]
        puts "  Host clock (from base build): ${rm_host_freq} MHz"
        puts "  MMCM: $m (MULT=$rm_mult_f, DIV=$rm_div_clk, OUT_DIV=$rm_out_div_f)"
        break
    }
}

###############################################################################
print "PR RM Build: pr_recombine — restoring WRAPPER/CL as RP"
###############################################################################

pr_recombine -cell WRAPPER/CL

# Write the final combined DCP (full CL with new RM)
# This is the same format as a normal build's post_route DCP
if {$failPath>0} {
    write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.post_route.VIOLATED.dcp
} else {
    write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.post_route.dcp
}

write_debug_probes -no_partial_ltxfile -force ${checkpoints_dir}/${TAG}.debug_probes.ltx

###############################################################################
print "Finished PR RM build for ${CL} — RM: ${pr_module_name}"
###############################################################################

close_design
