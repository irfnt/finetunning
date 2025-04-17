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

        # Get the clocks associated with startpoint and endpoint
        set launch_clock [get_attribute $startpoint clock]
        set capture_clock [get_attribute $endpoint clock]

        # Initialize clock arrival times
        set launch_arrival 0
        set capture_arrival 0

        # Check if clocks are defined for startpoint and endpoint
        if {$launch_clock == "" || $capture_clock == ""} {
            puts "Warning: Could not retrieve clock for path from [get_attribute $startpoint name] to [get_attribute $endpoint name]"
            continue
        }

        # Get clock network latency (arrival time) to the startpoint and endpoint
        # Use get_clock_network_latency to get the clock arrival times
        set launch_arrival [get_clock_network_latency -clock $launch_clock -to $startpoint]
        set capture_arrival [get_clock_network_latency -clock $capture_clock -to $endpoint]

        # If clock latency cannot be retrieved, skip the path
        if {$launch_arrival == "" || $capture_arrival == ""} {
            puts "Warning: Could not retrieve clock latency for path from [get_attribute $startpoint name] to [get_attribute $endpoint name]"
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
            set clock_period [get_attribute $launch_clock period]
            set data_path_delay [get_attribute $path data_delay]
            set setup_time [get_attribute $endpoint setup]

            # Check if attributes are retrieved successfully
            if {$clock_period == "" || $data_path_delay == "" || $setup_time == ""} {
                puts "Warning: Could not retrieve timing attributes for path from [get_attribute $startpoint name] to [get_attribute $endpoint name]"
                continue
            }

            set max_allowable_skew [expr $clock_period - $data_path_delay - $setup_time]
            if {$skew < $max_allowable_skew} {
                set harmful_skew [expr $max_allowable_skew - $skew]
            }
        } elseif {$path_type == "min"} {
            # Hold violation
            # Harmful skew is how much positive skew exceeds allowable margin
            set min_data_path_delay [get_attribute $path data_delay]
            set hold_time [get_attribute $endpoint hold]

            # Check if attributes are retrieved successfully
            if {$min_data_path_delay == "" || $hold_time == ""} {
                puts "Warning: Could not retrieve timing attributes for path from [get_attribute $startpoint name] to [get_attribute $endpoint name]"
                continue
            }

            set max_allowable_skew [expr $min_data_path_delay - $hold_time]
            if {$skew > $max_allowable_skew} {
                set harmful_skew [expr $skew - $max_allowable_skew]
            }
        } else {
            puts "Warning: Unknown path type for path from [get_attribute $startpoint name] to [get_attribute $endpoint name]"
            continue
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