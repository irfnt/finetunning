# File: calc_harmful_skew.tcl
# Purpose: Calculate harmful skew in Synopsys IC Compiler for paths with timing violations
# Assumes design is loaded, constraints applied, and CTS completed

proc calculate_harmful_skew {} {
    # Validate design setup
    if {[sizeof_collection [get_clocks *]] == 0} {
        puts "Error: No clocks defined. Check SDC file."
        return 1
    }

    # Open report file
    set report_file "harmful_skew_report.txt"
    set fh [open $report_file w]
    puts $fh "Harmful Skew Analysis Report - [clock format [clock seconds]]"
    puts $fh "----------------------------------------"
    puts $fh "Path | Skew (ns) | Slack (ns) | Violation Type | Harmful Skew (ns)"

    # Output header to console
    puts "Harmful Skew Analysis Report"
    puts "----------------------------------------"
    puts "Path | Skew (ns) | Slack (ns) | Violation Type | Harmful Skew (ns)"

    # Initialize counters
    set harmful_skew_count 0

    # Get timing paths with violations
    set setup_paths [get_timing_paths -slack_lesser_than 0 -max_paths 1000 -delay_type max]
    set hold_paths [get_timing_paths -slack_lesser_than 0 -max_paths 1000 -delay_type min]

    # Process setup paths
    if {[sizeof_collection $setup_paths] > 0} {
        foreach_in_collection path $setup_paths {
            incr harmful_skew_count [process_path $path $fh "Setup"]
        }
    }

    # Process hold paths
    if {[sizeof_collection $hold_paths] > 0} {
        foreach_in_collection path $hold_paths {
            incr harmful_skew_count [process_path $path $fh "Hold"]
        }
    }

    # Summary
    puts "----------------------------------------"
    puts $fh "----------------------------------------"
    if {$harmful_skew_count == 0} {
        puts "No harmful skew found. Skew did not contribute to timing violations."
        puts $fh "No harmful skew found. Skew did not contribute to timing violations."
    } else {
        puts "Total Paths with Harmful Skew: $harmful_skew_count"
        puts $fh "Total Paths with Harmful Skew: $harmful_skew_count"
    }

    close $fh
    puts "Report saved to $report_file"
    return 0
}

proc process_path {path fh violation_type} {
    # Get startpoint and endpoint
    set startpoint [get_attribute $path startpoint]
    set endpoint [get_attribute $path endpoint]
    
    if {$startpoint == "" || $endpoint == ""} {
        puts $fh "Warning: Invalid startpoint or endpoint for path"
        return 0
    }

    # Get clock information
    set launch_clock [get_attribute $path startpoint_clock]
    set capture_clock [get_attribute $path endpoint_clock]
    
    if {$launch_clock == "" || $capture_clock == ""} {
        puts $fh "Warning: No clock information for path from [get_attribute $startpoint full_name] to [get_attribute $endpoint full_name]"
        return 0
    }

    # Check if clocks are the same
    set launch_clock_name [get_attribute $launch_clock name]
    set capture_clock_name [get_attribute $capture_clock name]
    if {$launch_clock_name ne $capture_clock_name} {
        set path_name "[get_attribute $startpoint full_name] -> [get_attribute $endpoint full_name]"
        puts $fh "Warning: Cross-clock path ($launch_clock_name -> $capture_clock_name). Skipping skew calculation."
        puts [format "%-80s | %8s | %8s | %-6s | %8s" \
              $path_name "N/A" "N/A" $violation_type "N/A"]
        puts $fh [format "%-80s | %8s | %8s | %-6s | %8s" \
                  $path_name "N/A" "N/A" $violation_type "N/A"]
        return 0
    }

    # Get clock network delays
    set launch_delay [get_attribute $path startpoint_clock_latency]
    set capture_delay [get_attribute $path endpoint_clock_latency]
    
    if {$launch_delay == "" || $capture_delay == ""} {
        puts $fh "Warning: Missing clock latencies for path from [get_attribute $startpoint full_name] to [get_attribute $endpoint full_name]"
        return 0
    }

    # Validate numeric latencies
    if {[catch {expr {$launch_delay + $capture_delay}}]} {
        puts $fh "Warning: Non-numeric clock latencies for path from [get_attribute $startpoint full_name] to [get_attribute $endpoint full_name]"
        return 0
    }

    # Calculate skew
    set skew [expr {double($capture_delay) - double($launch_delay)}]
    
    # Get slack
    if {[catch {set slack [get_attribute $path slack]} err]} {
        puts $fh "Warning: Could not retrieve slack: $err"
        return 0
    }

    # Determine harmful skew
    set harmful_skew 0.0
    if {$violation_type == "Setup"} {
        if {$skew < 0} {
            set harmful_skew [expr {abs($skew)}]
        }
    } elseif {$violation_type == "Hold"} {
        if {$skew > 0} {
            set harmful_skew $skew
        }
    } else {
        puts $fh "Error: Invalid violation type '$violation_type'"
        return 0
    }

    # Format path name
    set path_name "[get_attribute $startpoint full_name] -> [get_attribute $endpoint full_name]"

    # Output results
    puts [format "%-80s | %8.3f | %8.3f | %-6s | %8.3f" \
          $path_name $skew $slack $violation_type $harmful_skew]
    puts $fh [format "%-80s | %8.3f | %8.3f | %-6s | %8.3f" \
              $path_name $skew $slack $violation_type $harmful_skew]

    # Return 1 if harmful skew contributed to violation
    return [expr {$harmful_skew > 0 ? 1 : 0}]
}

# Execute the procedure
calculate_harmful_skew