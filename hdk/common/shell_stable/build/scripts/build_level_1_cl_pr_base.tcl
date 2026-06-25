# =============================================================================
# F2 Nested DFX: PR Base Build
#
# Extends the normal CL implementation flow with nested DFX support.
# After the standard full build (link + opt + place + route), this script:
#   1. Discovers the inner RP cell from PR_MODULE_NAME
#   2. Sets HD.RECONFIGURABLE on the inner cell
#   3. Uses pr_subdivide to push reconfigurability from WRAPPER/CL to the inner module
#   4. Writes an abstract shell for the inner RP
#   5. Uses pr_recombine to restore WRAPPER/CL as the single RP
#   6. Writes the final post_route DCP for tarball generation
#
# Environment variables required:
#   PR_MODULE_NAME - Name of the module to become the inner RP (e.g., BestOffsetPrefetcher)
#   PR_PARTITION_CELL - (optional) Explicit hierarchical path to the cell
# =============================================================================


# --- Phase 1: Standard CL Implementation (same as build_level_1_cl.tcl) ---

# AWS shell DCP location
set AWS_DCP_DIR "${HDK_SHELL_DIR}/build/checkpoints/from_aws/"


###############################################################################
print "Start linking customer design ${CL}"
###############################################################################
add_files ${AWS_DCP_DIR}/cl_bb_routed.${SHELL_MODE}.dcp
add_files ${checkpoints_dir}/${CL}.${TAG}.post_synth.dcp

set_property SCOPED_TO_CELLS {WRAPPER/CL} \
             [get_files ${checkpoints_dir}/${CL}.${TAG}.post_synth.dcp]

link_design -mode default \
            -reconfig_partitions {WRAPPER/CL} \
            -top top

print "Writing post-link design checkpoint"
write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.post_link.dcp

#######################################
# MMCM Clock recipe constraints
#######################################
source $HDK_SHELL_DIR/build/scripts/aws_clock_properties.tcl

#######################################
# Floorplan Constraints
#######################################
read_xdc ${HDK_SHELL_DIR}/build/constraints/${SHELL_MODE}_level_1_fp_cl.xdc
read_xdc ${constraints_dir}/${SHELL_MODE}_cl_pnr_user.xdc

# Optional, MIG placement training
source ${HDK_SHELL_DIR}/build/scripts/ddr_io_train.tcl

###############################################################################
print "Start optimizing customer design ${CL}"
###############################################################################
opt_design

# Work Around 2025.1 HBM DONT TOUCH issue
if {[llength [get_cells -quiet WRAPPER/CL/CL_HBM/HBM_PRESENT_EQ_1.HBM_WRAPPER_I/HBM_CORE_I/inst]] > 0} {
    puts "INFO: HBM found, setting DONT_TOUCH to 0"
    set_property DONT_TOUCH 0 [get_cells WRAPPER/CL/CL_HBM/HBM_PRESENT_EQ_1.HBM_WRAPPER_I/HBM_CORE_I/inst]
}

print "Writing post-opt design checkpoint and report"
write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.post_opt.dcp

report_timing -delay_type max \
              -path_type full_clock_expanded \
              -max_paths 10 \
              -nworst 1 \
              -input_pins \
              -slice_pins \
              -sort_by group \
              -significant_digits 3 \
              -file ${reports_dir}/${CL}.${TAG}.post_opt_timing.rpt


###############################################################################
print "Start placing customer design ${CL}"
###############################################################################
place_design -directive $PLACE_DIRECT -no_bufg_opt

print "Writing post-place design checkpoint and report"
write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.post_place.dcp

report_timing -delay_type max \
              -path_type full_clock_expanded \
              -max_paths 10 \
              -nworst 1 \
              -input_pins \
              -slice_pins \
              -sort_by group \
              -significant_digits 3 \
              -file $reports_dir/${CL}.${TAG}.post_place_timing.rpt


###############################################################################
print "Start physical-optimizing customer design ${CL}"
###############################################################################
phys_opt_design -directive $PHY_OPT_DIRECT

print "Writing post-phy_opt design checkpoint and report"
write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.post_phys_opt.dcp

report_timing -delay_type max \
              -path_type full_clock_expanded \
              -max_paths 10 \
              -nworst 1 \
              -input_pins \
              -slice_pins \
              -sort_by group \
              -significant_digits 3 \
              -file $reports_dir/${CL}.${TAG}.post_phy_opt_timing.rpt


###############################################################################
print "Start routing customer design ${CL}"
###############################################################################
route_design -directive $ROUTE_DIRECT -tns_cleanup -timing_summary

set failPath [check_timing_path]

report_timing -delay_type max \
              -path_type full_clock_expanded \
              -max_paths 10 \
              -nworst 1 \
              -input_pins \
              -slice_pins \
              -sort_by group \
              -significant_digits 3 \
              -file ${reports_dir}/${CL}.${TAG}.post_route_timing.rpt

write_debug_probes -no_partial_ltxfile -force ${checkpoints_dir}/${TAG}.debug_probes.ltx

###############################################################################
print "Adjusting host clock frequency based on post-route timing"
###############################################################################
source $HDK_SHELL_DIR/build/scripts/adjust_host_frequency.tcl
set adjusted_freq [adjust_host_frequency $desired_host_frequency]
if {$adjusted_freq eq ""} {
    print "ERROR: Frequency adjustment failed — design cannot meet minimum frequency."
}

# Write post-route DCP with adjusted MMCM (before PR modifications)
print "Writing post-route design checkpoint"
if {$failPath>0} {
    write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.post_route.VIOLATED.dcp
} else {
    write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.post_route.dcp
}

# Save a copy of the full routed design (with adjusted frequency) before PR modifications
write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.full_routed.dcp

# --- Phase 2: Nested DFX — Create abstract shell for inner RP ---

###############################################################################
print "Starting Nested DFX setup for PR base build"
###############################################################################

# Get PR module name from environment
set pr_module_name $::env(PR_MODULE_NAME)
puts "PR module name: $pr_module_name"

# Auto-discover partition cell path if not provided
if {[info exists ::env(PR_PARTITION_CELL)] && $::env(PR_PARTITION_CELL) ne ""} {
    set pr_cell $::env(PR_PARTITION_CELL)
    puts "Using provided PR partition cell: $pr_cell"
} else {
    puts "Auto-discovering partition cell for module: $pr_module_name"
    set discovered_cells [get_cells -hierarchical -filter "REF_NAME == $pr_module_name"]
    if {[llength $discovered_cells] == 0} {
        error "Could not find cell with REF_NAME == $pr_module_name in the design"
    }
    if {[llength $discovered_cells] > 1} {
        puts "WARNING: Multiple cells found for $pr_module_name:"
        foreach c $discovered_cells {
            puts "  $c"
        }
        puts "Using first: [lindex $discovered_cells 0]"
    }
    set pr_cell [lindex $discovered_cells 0]
    puts "Discovered PR partition cell: $pr_cell"
}

# Save the cell path as a plain string BEFORE pr_subdivide.
# pr_subdivide reloads the design context, which invalidates Vivado cell
# object references (causing $pr_cell to become "null"). By capturing the
# hierarchical path as a string, we preserve it across the design reload.
set pr_cell_path [get_property NAME [get_cells $pr_cell]]
puts "Saved PR cell path as string: $pr_cell_path"

# Write discovered path for metadata generation
set fp [open "${checkpoints_dir}/discovered_pr_cell.txt" w]
puts $fp "${pr_module_name}:${pr_cell_path}"
close $fp
puts "Wrote discovered PR cell path to ${checkpoints_dir}/discovered_pr_cell.txt"

###############################################################################
print "Step 1: Setting HD.RECONFIGURABLE on inner module"
###############################################################################

# The CL synth DCP path (needed for pr_subdivide)
set cl_synth_dcp ${checkpoints_dir}/${CL}.${TAG}.post_synth.dcp

###############################################################################
print "Step 2: pr_subdivide — push reconfigurability from WRAPPER/CL to inner module"
###############################################################################

# pr_subdivide takes a routed design with WRAPPER/CL as RP and
# creates a nested RP at the inner module level.
# The CL synth DCP is used as a reference for the CL hierarchy.
pr_subdivide -cell WRAPPER/CL -subcells [list $pr_cell_path] $cl_synth_dcp

puts "pr_subdivide complete. Inner module $pr_cell_path is now a nested RP."

###############################################################################
print "Step 3: Save abstract shell checkpoint for inner RP"
###############################################################################

# After pr_subdivide, the design IS an abstract shell — the inner cell is a
# black box and the surrounding static logic is locked/routed. Vivado will
# reject write_abstract_shell on a design that is already abstract, so we
# simply save this state as a checkpoint. RM builds will open this checkpoint,
# read_checkpoint -cell the new RM, implement, and pr_recombine.
write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.abstract_shell.dcp

puts "Abstract shell checkpoint written to ${checkpoints_dir}/${CL}.${TAG}.abstract_shell.dcp"

###############################################################################
print "Step 4: pr_recombine — restore WRAPPER/CL as the RP for final DCP"
###############################################################################

pr_recombine -cell WRAPPER/CL

# Write the final recombined checkpoint (this is what goes into the tarball)
write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.post_route.dcp

###############################################################################
print "Finished PR base build for ${CL} with nested DFX on ${pr_module_name} (cell: ${pr_cell_path})"
###############################################################################

close_design
