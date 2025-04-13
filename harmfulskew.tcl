# Script to calculate harmful skew in IC Compiler
# Assumes design is loaded, constraints applied, and CTS completed

proc calculate_harmful_skew {} {
    # Get all timing paths with negative slack (potential violations)
    set paths [get_timing_paths -slack_lesser_than 0 -max_paths 100]

    # Check if paths exist
    if {[llength $paths] == 0} {
        puts "No timing violations found. All paths have positive slack."
        return
    }

    # Output header
    puts "Harmful Skew Analysis Report"
    puts "----------------------------"
    puts "Path | Skew (ns) | Slack (ns) | Violation Type | Harmful Skew (ns)"

    # Iterate through each timing path
    foreach_in_collection path $paths {
        # Get startpoint (launch) and endpoint (capture)
        set startpoint [get_attribute $path startpoint]
        set endpoint [get_attribute $path endpoint]

        # Get clock arrival times
        set launch_clock_pin [get_attribute $startpoint clock_pin]
        set capture_clock_pin [get_attribute $endpoint clock_pin]

        # Extract clock arrival times (in ns)
        set launch_arrival 0
        set capture_arrival 0
        if {$launch_clock_pin != "" && $capture_clock_pin != ""} {
            set launch_arrival [get_attribute [get_timing_arcs -to $startpoint] arrival]
            set capture_arrival [get_attribute [get_timing_arcs -to $endpoint] arrival]
        } else {
            puts "Warning: Could not retrieve clock pins for path from $startpoint to $endpoint"
            continue
        }

        # Calculate skew (capture - launch)
        set skew [expr $capture_arrival - $launch_arrival]

        # Get slack and path type (setup or hold)
        set slack [get_attribute $path slack]
        set path_type [get_attribute $path path_type]

        # Calculate harmful skew
        set harmful_skew 0
        if {$path_type == "max"} {
            # Setup violation
            # Harmful skew is how much negative skew exceeds allowable margin
            set clock_period [get_attribute [get_attribute $path clock] period]
            set data_path_delay [get_attribute $path data_path_delay]
            set setup_time [get_attribute $endpoint setup]
            set max_allowable_skew [expr $clock_period - $data_path_delay - $setup_time]
            if {$skew < $max_allowable_skew} {
                set harmful_skew [expr $max_allowable_skew - $skew]
            }
        } elseif {$path_type == "min"} {
            # Hold violation
            # Harmful skew is how much positive skew exceeds allowable margin
            set min_data_path_delay [get_attribute $path data_path_delay]
            set hold_time [get_attribute $endpoint hold]
            set max_allowable_skew [expr $min_data_path_delay - $hold_time]
            if {$skew > $max_allowable_skew} {
                set harmful_skew [expr $skew - $max_allowable_skew]
            }
        }

        # Report results
        puts [format "%s -> %s | %.3f | %.3f | %s | %.3f" \
              [get_attribute $startpoint name] \
              [get_attribute $endpoint name] \
              $skew $slack $path_type $harmful_skew]
    }
}

# Execute the procedure
calculate_harmful_skew

# Optional: Save report to a file
redirect -file harmful_skew_report.txt {calculate_harmful_skew}
