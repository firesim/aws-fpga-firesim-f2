# =============================================================================
# F2 Post-Route Host Clock Frequency Adjustment
#
# Adjusts the FireSim host clock MMCM (clk_wiz_0_firesim) output divider
# based on post-route timing slack. If the design has positive WNS (slack),
# the clock frequency can be increased. If WNS is negative (timing violation),
# the frequency is decreased to meet timing.
#
# The MMCM divider is modified in the live Vivado design context. The caller
# is responsible for writing the checkpoint after this proc returns.
#
# This proc does NOT write bitstreams or checkpoints — F2 uses DCP tarballs,
# not direct bitstream generation.
#
# Usage:
#   source adjust_host_frequency.tcl
#   set adjusted_freq [adjust_host_frequency $desired_host_frequency]
#
# Args:
#   desired_freq_mhz - The originally requested host frequency
#   margin_ns        - Timing margin to preserve (default 0.5 ns)
#   min_freq_mhz     - Floor frequency; error if adjusted below this
#
# Returns: the adjusted frequency in MHz, or "" on failure.
# =============================================================================

proc adjust_host_frequency { desired_freq_mhz {margin_ns 0.5} {min_freq_mhz 10.0} } {

    # Compute WNS/WHS from the current open design
    set WNS 0.0
    set WHS 0.0
    set setup_path [get_timing_paths -max_paths 1 -nworst 1 -setup -quiet]
    if {$setup_path ne ""} {
        set WNS [get_property SLACK $setup_path]
    }
    set hold_path [get_timing_paths -max_paths 1 -nworst 1 -hold -quiet]
    if {$hold_path ne ""} {
        set WHS [get_property SLACK $hold_path]
    }

    puts "=========================================="
    puts "HOST FREQUENCY ADJUSTMENT"
    puts "  Desired frequency: ${desired_freq_mhz} MHz"
    puts "  WNS: ${WNS} ns  WHS: ${WHS} ns"
    puts "=========================================="

    # Find the FireSim host clock MMCM (clk_wiz_0_firesim)
    set all_mmcms [get_cells -hierarchical -filter {REF_NAME =~ MMCME*} -quiet]
    if {[llength $all_mmcms] == 0} {
        puts "WARNING: No MMCM found in design, cannot adjust frequency."
        return $desired_freq_mhz
    }

    set host_mmcm ""
    foreach m $all_mmcms {
        if {[string match "*clk_wiz_0_firesim*" $m]} {
            set host_mmcm $m
            break
        }
    }
    if {$host_mmcm eq ""} {
        puts "WARNING: Could not find clk_wiz_0_firesim MMCM. Available MMCMs:"
        foreach m $all_mmcms { puts "  $m" }
        puts "Skipping frequency adjustment."
        return $desired_freq_mhz
    }

    # Read current MMCM configuration
    set mult_f    [get_property CLKFBOUT_MULT_F $host_mmcm]
    set div_clk   [get_property DIVCLK_DIVIDE $host_mmcm]
    set out_div_f [get_property CLKOUT0_DIVIDE_F $host_mmcm]

    # Determine MMCM input frequency from the clock pin
    set input_freq_mhz 250.0
    set clkin_pin [get_pins -of_objects $host_mmcm -filter {REF_PIN_NAME == CLKIN1} -quiet]
    if {$clkin_pin ne ""} {
        set clkin_period [get_property PERIOD [get_clocks -of_objects $clkin_pin -quiet] -quiet]
        if {$clkin_period ne "" && $clkin_period > 0} {
            set input_freq_mhz [expr {1000.0 / $clkin_period}]
        }
    }

    set vco_freq [expr {$input_freq_mhz * $mult_f / $div_clk}]
    set current_freq [expr {$vco_freq / $out_div_f}]
    set current_period [expr {1000.0 / $current_freq}]

    puts "  MMCM: $host_mmcm"
    puts "  Input freq:       ${input_freq_mhz} MHz"
    puts "  CLKFBOUT_MULT_F:  $mult_f"
    puts "  DIVCLK_DIVIDE:    $div_clk"
    puts "  CLKOUT0_DIVIDE_F: $out_div_f"
    puts "  VCO freq:         ${vco_freq} MHz"
    puts "  Current freq:     ${current_freq} MHz (period ${current_period} ns)"

    # new_period = current_period + margin - WNS
    # If WNS > 0 (positive slack), period decreases → frequency increases
    # If WNS < 0 (violation), period increases → frequency decreases
    set new_period [expr {$current_period + $margin_ns - $WNS}]
    set ideal_freq [expr {1000.0 / $new_period}]

    puts "  Target period:    ${new_period} ns (${ideal_freq} MHz, margin=${margin_ns} ns)"

    # CLKOUT0_DIVIDE_F has 0.125 (1/8) granularity; round UP for safety
    set ideal_div [expr {$vco_freq / $ideal_freq}]
    set new_div_f [expr {ceil($ideal_div * 8.0) / 8.0}]
    if {$new_div_f < 1.0} { set new_div_f 1.0 }
    if {$new_div_f > 128.0} { set new_div_f 128.0 }

    set new_freq [expr {$vco_freq / $new_div_f}]
    set new_period_actual [expr {1000.0 / $new_freq}]

    puts "  New CLKOUT0_DIVIDE_F: $new_div_f (was $out_div_f)"
    puts "  New freq:         ${new_freq} MHz (period ${new_period_actual} ns)"

    if {$new_freq < $min_freq_mhz} {
        puts "ERROR: Adjusted frequency ${new_freq} MHz is below minimum ${min_freq_mhz} MHz."
        return ""
    }

    set freq_delta [expr {abs($new_freq - $current_freq)}]
    if {$freq_delta < 0.5} {
        puts "  No significant frequency change needed (delta ${freq_delta} MHz)."
        set new_freq $current_freq
    } else {
        if {$new_freq > $current_freq} {
            puts "  INCREASING frequency: ${current_freq} -> ${new_freq} MHz (+${freq_delta} MHz)"
        } else {
            puts "  DECREASING frequency: ${current_freq} -> ${new_freq} MHz (-${freq_delta} MHz)"
        }
        set_property CLKOUT0_DIVIDE_F $new_div_f $host_mmcm
        puts "  Applied CLKOUT0_DIVIDE_F = $new_div_f to $host_mmcm"
    }

    # Write adjusted frequency to a file for downstream tools (metadata, bitbuilder)
    global checkpoints_dir
    if {[info exists checkpoints_dir]} {
        set freq_file "${checkpoints_dir}/adjusted_host_frequency.txt"
        set fp [open $freq_file w]
        puts $fp $new_freq
        close $fp
        puts "  Wrote adjusted frequency to: $freq_file"
    }

    puts "  Frequency adjustment complete. Caller should write checkpoint."
    puts "=========================================="

    return $new_freq
}
