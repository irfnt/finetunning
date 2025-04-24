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

    # Initialize metrics
    set setup_slacks [list]
    set hold_slacks [list]
    set harmful_skew_values [list]
    set total_harmful_skew 0.0
    set max_harmful_skew 0.0
    set min_harmful_skew 0.0
    set harmful_skew_count 0

    # Get timing paths with violations
    set setup_paths [get_timing_paths -slack_lesser_than 0 -max_paths 1000 -delay_type max]
    set hold_paths [get_timing_paths -slack_lesser_than 0 -max_paths 1000 -delay_type min]

    # Process setup paths
    if {[sizeof_collection $setup_paths] > 0} {
        foreach_in_collection path $setup_paths {
            incr harmful_skew_count [process_path $path $fh "Setup" setup_slacks harmful_skew_values total_harmful_skew max_harmful_skew min_harmful_skew]
        }
    }

    # Process hold paths
    if {[sizeof_collection $hold_paths] > 0} {
        foreach_in_collection path $hold_paths {
            incr harmful_skew_count [process_path $path $fh "Hold" hold_slacks harmful_skew_values total_harmful_skew max_harmful_skew min_harmful_skew]
        }
    }

    # Calculate statistics
    set num_setup [llength $setup_slacks]
    set num_hold [llength $hold_slacks]
    set total_slacks [expr {$num_setup + $num_hold}]

    # Setup violations stats
    set setup_tns 0.0
    set setup_avg 0.0
    if {$num_setup > 0} {
        set setup_tns [expr [join $setup_slacks +]]
        set setup_avg [expr {$setup_tns / $num_setup}]
    }

    # Hold violations stats
    set hold_tns 0.0
    set hold_avg 0.0
    if {$num_hold > 0} {
        set hold_tns [expr [join $hold_slacks +]]
        set hold_avg [expr {$hold_tns / $num_hold}]
    }

    # Harmful skew stats
    set num_harmful [llength $harmful_skew_values]
    set avg_harmful 0.0
    set median_harmful 0.0
    if {$num_harmful > 0} {
        set avg_harmful [expr {$total_harmful_skew / $num_harmful}]
        set sorted_harmful [lsort -real $harmful_skew_values]
        set median_harmful [median $sorted_harmful]
        set max_harmful_skew [lindex [lsort -real -decreasing $harmful_skew_values] 0]
        set min_harmful_skew [lindex [lsort -real $harmful_skew_values] 0]
    }

    # Summary
    puts "\n----------------------------------------"
    puts $fh "\n----------------------------------------"
    
    # Timing Violation Statistics
    puts "Timing Violation Statistics:"
    puts "Total Negative Slack (TNS):"
    puts "  Setup: [format "%10.3f" $setup_tns] ns"
    puts "  Hold:  [format "%10.3f" $hold_tns] ns"
    puts "  Total: [format "%10.3f" [expr {$setup_tns + $hold_tns}]] ns\n"
    
    puts "Average Negative Slack:"
    puts "  Setup: [format "%10.3f" $setup_avg] ns"
    puts "  Hold:  [format "%10.3f" $hold_avg] ns"
    puts "  Overall: [format "%10.3f" [expr {($setup_tns + $hold_tns) / $total_slacks}]] ns\n"

    # Harmful Skew Statistics
    puts "Harmful Skew Statistics:"
    puts "Total Harmful Skew:    [format "%10.3f" $total_harmful_skew] ns"
    puts "Maximum Harmful Skew:  [format "%10.3f" $max_harmful_skew] ns"
    puts "Minimum Harmful Skew:  [format "%10.3f" $min_harmful_skew] ns"
    puts "Average Harmful Skew:  [format "%10.3f" $avg_harmful] ns"
    puts "Median Harmful Skew:   [format "%10.3f" $median_harmful] ns"
    puts "Paths with Harmful Skew: $harmful_skew_count"

    # File output
    puts $fh "Timing Violation Statistics:"
    puts $fh "Total Negative Slack (TNS):"
    puts $fh "  Setup: [format "%10.3f" $setup_tns] ns"
    puts $fh "  Hold:  [format "%10.3f" $hold_tns] ns"
    puts $fh "  Total: [format "%10.3f" [expr {$setup_tns + $hold_tns}]] ns\n"
    
    puts $fh "Average Negative Slack:"
    puts $fh "  Setup: [format "%10.3f" $setup_avg] ns"
    puts $fh "  Hold:  [format "%10.3f" $hold_avg] ns"
    puts $fh "  Overall: [format "%10.3f" [expr {($setup_tns + $hold_tns) / $total_slacks}]] ns\n"

    puts $fh "Harmful Skew Statistics:"
    puts $fh "Total Harmful Skew:    [format "%10.3f" $total_harmful_skew] ns"
    puts $fh "Maximum Harmful Skew:  [format "%10.3f" $max_harmful_skew] ns"
    puts $fh "Minimum Harmful Skew:  [format "%10.3f" $min_harmful_skew] ns"
    puts $fh "Average Harmful Skew:  [format "%10.3f" $avg_harmful] ns"
    puts $fh "Median Harmful Skew:   [format "%10.3f" $median_harmful] ns"
    puts $fh "Paths with Harmful Skew: $harmful_skew_count"

    close $fh
    puts "\nReport saved to $report_file"
    return 0
}

proc process_path {path fh violation_type slack_list_var harmful_skew_values_var total_harmful_skew_var max_harmful_var min_harmful_var} {
    upvar $slack_list_var slack_list
    upvar $harmful_skew_values_var harmful_skew_values
    upvar $total_harmful_skew_var total_harmful_skew
    upvar $max_harmful_var max_harmful
    upvar $min_harmful_var min_harmful

    # Initialize defaults
    set skew "N/A"
    set harmful_skew 0.0
    set path_name "Unknown Path"
    set slack 0.0

    # Get slack first
    if {[catch {set slack [get_attribute $path slack]} err] || ![string is double $slack]} {
        puts $fh "Warning: Could not retrieve valid slack for path"
        return 0
    }
    lappend slack_list $slack

    # Get path endpoints
    set startpoint [get_attribute $path startpoint]
    set endpoint [get_attribute $path endpoint]
    if {$startpoint == "" || $endpoint == ""} {
        puts $fh "Warning: Invalid path endpoints"
        return 0
    }

    # Get clock information
    set launch_clock [get_attribute $path startpoint_clock]
    set capture_clock [get_attribute $path endpoint_clock]
    if {$launch_clock == "" || $capture_clock == ""} {
        puts $fh "Warning: Missing clock information for path"
        return 0
    }

    # Check clock domains
    set launch_clock_name [get_attribute $launch_clock name]
    set capture_clock_name [get_attribute $capture_clock name]
    if {$launch_clock_name ne $capture_clock_name} {
        set path_name "[get_attribute $startpoint full_name] -> [get_attribute $endpoint full_name]"
        puts $fh "Warning: Cross-clock path ($launch_clock_name -> $capture_clock_name)"
        puts [format "%-80s | %8s | %8.3f | %-6s | %8s" \
              $path_name "N/A" $slack $violation_type "N/A"]
        puts $fh [format "%-80s | %8s | %8.3f | %-6s | %8s" \
                  $path_name "N/A" $slack $violation_type "N/A"]
        return 0
    }

    # Get clock latencies
    set launch_delay [get_attribute $path startpoint_clock_latency]
    set capture_delay [get_attribute $path endpoint_clock_latency]
    if {![string is double $launch_delay] || ![string is double $capture_delay]} {
        puts $fh "Warning: Invalid clock latencies for path"
        return 0
    }

    # Calculate skew and harmful skew
    set skew [expr {double($capture_delay) - double($launch_delay)}]
    set harmful_skew 0.0

    if {$violation_type == "Setup" && $skew < 0} {
        set harmful_skew [expr {abs($skew)}]
    } elseif {$violation_type == "Hold" && $skew > 0} {
        set harmful_skew $skew
    }

    # Update metrics if harmful skew exists
    if {$harmful_skew > 0} {
        lappend harmful_skew_values $harmful_skew
        set total_harmful_skew [expr {$total_harmful_skew + $harmful_skew}]
        
        # Update max/min harmful skew
        if {$harmful_skew > $max_harmful || $num_harmful == 0} {
            set max_harmful $harmful_skew
        }
        if {$harmful_skew < $min_harmful || $num_harmful == 0} {
            set min_harmful $harmful_skew
        }
    }

    # Format path name
    set path_name "[get_attribute $startpoint full_name] -> [get_attribute $endpoint full_name]"

    # Output results
    puts [format "%-80s | %8.3f | %8.3f | %-6s | %8.3f" \
          $path_name $skew $slack $violation_type $harmful_skew]
    puts $fh [format "%-80s | %8.3f | %8.3f | %-6s | %8.3f" \
              $path_name $skew $slack $violation_type $harmful_skew]

    return [expr {$harmful_skew > 0 ? 1 : 0}]
}

proc median {sorted_list} {
    set len [llength $sorted_list]
    if {$len == 0} {return 0.0}
    set mid [expr {$len / 2}]
    if {$len % 2 == 0} {
        return [expr {([lindex $sorted_list [expr {$mid - 1}]] + [lindex $sorted_list $mid]) / 2.0}]
    } else {
        return [lindex $sorted_list $mid]
    }
}

# Execute the procedure
calculate_harmful_skew