# File: calc_harmful_skew.tcl
# Purpose: Calculate harmful skew in Synopsys IC Compiler for paths with timing violations
# Assumes design is loaded, constraints applied, and CTS completed

proc calculate_harmful_skew {{max_paths 100} {clock ""}} {
    # Validate design setup
    if {[sizeof_collection [get_clocks *]] == 0} {
        puts "Error: No clocks defined. Check SDC file."
        return
    }
    if {[check_timing -verbose] != ""} {
        puts "Warning: Timing constraints may be incomplete. Check with 'check_timing'."
    }
    if {[check_clock_tree] != ""} {
        puts "Warning: Clock tree synthesis may not be complete. Check with 'check_clock_tree'."
    }

    # Open report file with timestamp
    set timestamp [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
    set report_file "harmful_skew_report_${timestamp}.txt"
    set fh [open $report_file w]
    puts $fh "Harmful Skew Analysis Report - [clock format [clock seconds]]"
    puts $fh "----------------------------"
    puts $fh "Path | Skew (ns) | Slack (ns) | Violation Type | Harmful Skew (ns)"

    # Output header to console
    puts "Harmful Skew Analysis Report"
    puts "----------------------------"
    puts "Path | Skew (ns) | Slack (ns) | Violation Type | Harmful Skew (ns)"

    # Initialize counters
    set setup_violations 0
    set hold_violations 0

    # Step 1: Get setup and hold paths with negative slack
    set setup_paths [get_timing_paths -slack_lesser_than 0 -max_paths $max_paths -delay_type max]
    set hold_paths [get_timing_paths -slack_lesser_than 0 -max_paths $max_paths -delay_type min]
    if {$clock != ""} {
        set setup_paths [get_timing_paths -slack_lesser_than 0 -max_paths $max_paths -delay_type max -clock $clock]
        set hold_paths [get_timing_paths -slack_lesser_than 0 -max_paths $max_paths -delay_type min -clock $clock]
    }

    # Step 2: Process setup paths
    foreach_in_collection path $setup_paths {
        if {![process_path $path $fh "Setup"]} {
            continue
        }
        incr setup_violations
    }

    # Step 3: Process hold paths
    foreach_in_collection path $hold_paths {
        if {![process_path $path $fh "Hold"]} {
            continue
        }
        incr hold_violations
    }

    # Step 4: Summary
    set total_violations [expr {$setup_violations + $hold_violations}]
    if {$total_violations == 0} {
        puts "No timing violations found. All paths have positive slack."
        puts $fh "No timing violations found. All paths have positive slack."
    } else {
        puts "----------------------------"
        puts "Setup Violations: $setup_violations"
        puts "Hold Violations: $hold_violations"
        puts "Total Paths with Harmful Skew: $total_violations"
        puts $fh "----------------------------"
        puts $fh "Setup Violations: $setup_violations"
        puts $fh "Hold Violations: $hold_violations"
        puts $fh "Total Paths with Harmful Skew: $total_violations"
    }

    close $fh
    puts "Report saved to $report_file"
}

# Helper procedure to process a single timing path
proc process_path {path fh violation_type} {
    # Get startpoint (launch) and endpoint (capture)
    set startpoint [get_attribute $path startpoint]
    set endpoint [get_attribute $path endpoint]

    # Get clock pins
    set launch_clock_pin [get_pins -of_objects $startpoint -filter "is_clock_pin==true"]
    set capture_clock_pin [get_pins -of_objects $endpoint -filter "is_clock_pin==true"]

    if {$launch_clock_pin == "" || $capture_clock_pin == ""} {
        puts $fh "Warning: No clock pins for path from [get_attribute $startpoint name] to [get_attribute $endpoint name]"
        return 0
    }

    # Get clock arrival times using more robust method
    set launch_arrival ""
    set capture_arrival ""
    catch {
        set launch_arrival [get_attribute [get_timing_path -to $launch_clock_pin] arrival]
        set capture_arrival [get_attribute [get_timing_path -to $capture_clock_pin] arrival]
    }
    if {$launch_arrival == "" || $capture_arrival == ""} {
        puts $fh "Warning: Could not retrieve clock arrivals for path from [get_attribute $startpoint name] to [get_attribute $endpoint name]"
        return 0
    }

    # Calculate skew
    set skew [expr {$capture_arrival - $launch_arrival}]

    # Get slack
    set slack [get_attribute $path slack]

    # Calculate harmful skew based on violation type
    set harmful_skew 0
    if {$violation_type == "Setup" && $skew > 0} {
        set harmful_skew $skew
    } elseif {$violation_type == "Hold" && $skew < 0} {
        set harmful_skew $skew
    }

    # Format path name
    set path_name "[get_attribute $startpoint name] -> [get_attribute $endpoint name]"

    # Output results only if harmful skew is non-zero
    if {$harmful_skew != 0} {
        puts [format "%s | %.3f | %.3f | %s | %.3f" \
              $path_name $skew $slack $violation_type $harmful_skew]
        puts $fh [format "%s | %.3f | %.3f | %s | %.3f" \
                  $path_name $skew $slack $violation_type $harmful_skew]
        return 1
    }
    return 0
}

# Execute the procedure
calculate_harmful_skew