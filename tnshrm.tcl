# Script to calculate TNS, Average TNS, and Harmful Skew for clock path timing violations in IC Compiler
# Assumes design is loaded, constraints applied, and CTS completed

proc calculate_timing_metrics {} {
    # Initialize variables
    set tns 0.0
    set violation_count 0
    set harmful_skew_list {}

    # Get all timing paths with negative slack for clock paths (setup and hold)
    set paths [get_timing_paths -slack_lesser_than 0 -max_paths 1000 -path_type full_clock_expanded]

    # Check if paths exist
    if {[llength $paths] == 0} {
        puts "No timing violations found in clock paths."
        return
    }

    # Output header
    puts "Timing Violation Analysis Report"
    puts "--------------------------------"
    puts "Path | Skew (ns) | Slack (ns) | Violation Type | Harmful Skew (ns)"

    # Iterate through each timing path
    foreach_in_collection path $paths {
        # Get startpoint (launch) and endpoint (capture)
        set startpoint [get_attribute $path startpoint]
        set endpoint [get_attribute $path endpoint]

        # Ensure startpoint and endpoint are valid
        if {$startpoint == "" || $endpoint == ""} {
            puts "Warning: Invalid startpoint or endpoint for a path. Skipping."
            continue
        }

        # Get clock arrival times
        set launch_clock_pin [get_attribute $startpoint clock_pin]
        set capture_clock_pin [get_attribute $endpoint clock_pin]

        # Extract clock arrival times (in ns)
        set launch_arrival 0.0
        set capture_arrival 0.0
        if {$launch_clock_pin != "" && $capture_clock_pin != ""} {
            # Get arrival times for clock pins
            set launch_arcs [get_timing_arcs -to $startpoint]
            set capture_arcs [get_timing_arcs -to $endpoint]
            if {$launch_arcs != "" && $capture_arcs != ""} {
                set launch_arrival [get_attribute $launch_arcs arrival]
                set capture_arrival [get_attribute $capture_arcs arrival]
            } else {
                puts "Warning: Could not retrieve timing arcs for $startpoint -> $endpoint. Skipping."
                continue
            }
        } else {
            puts "Warning: Could not retrieve clock pins for $startpoint -> $endpoint. Skipping."
            continue
        }

        # Calculate skew (capture - launch)
        set skew [expr $capture_arrival - $launch_arrival]

        # Get slack and path type (setup or hold)
        set slack [get_attribute $path slack]
        set path_type [get_attribute $path path_type]

        # Update TNS and violation count
        if {$slack < 0} {
            set tns [expr $tns + $slack]
            incr violation_count
        }

        # Calculate harmful skew
        set harmful_skew 0.0
        if {$path_type == "max"} {
            # Setup violation (negative skew is harmful)
            set clock_period [get_attribute [get_attribute $path clock] period]
            set data_path_delay [get_attribute $path data_path_delay]
            set setup_time [get_attribute $endpoint setup]
            set max_allowable_skew [expr $clock_period - $data_path_delay - $setup_time]
            if {$skew < $max_allowable_skew} {
                set harmful_skew [expr $max_allowable_skew - $skew]
            }
        } elseif {$path_type == "min"} {
            # Hold violation (positive skew is harmful)
            set min_data_path_delay [get_attribute $path data_path_delay]
            set hold_time [get_attribute $endpoint hold]
            set max_allowable_skew [expr $min_data_path_delay - $hold_time]
            if {$skew > $max_allowable_skew} {
                set harmful_skew [expr $skew - $max_allowable_skew]
            }
        }

        # Store harmful skew for summary
        lappend harmful_skew_list $harmful_skew

        # Report path details
        puts [format "%s -> %s | %.3f | %.3f | %s | %.3f" \
              [get_attribute $startpoint name] \
              [get_attribute $endpoint name] \
              $skew $slack $path_type $harmful_skew]
    }

    # Calculate Average TNS
    set avg_tns 0.0
    if {$violation_count > 0} {
        set avg_tns [expr $tns / $violation_count]
    }

    # Calculate Average Harmful Skew
    set total_harmful_skew 0.0
    set harmful_count 0
    foreach hs $harmful_skew_list {
        if {$hs > 0.0} {
            set total_harmful_skew [expr $total_harmful_skew + $hs]
            incr harmful_count
        }
    }
    set avg_harmful_skew 0.0
    if {$harmful_count > 0} {
        set avg_harmful_skew [expr $total_harmful_skew / $harmful_count]
    }

    # Summary report
    puts "\nSummary"
    puts "-------"
    puts [format "Total Negative Slack (TNS): %.3f ns" $tns]
    puts [format "Number of Violating Paths: %d" $violation_count]
    puts [format "Average TNS: %.3f ns" $avg_tns]
    puts [format "Average Harmful Skew: %.3f ns" $avg_harmful_skew]
}

# Execute the procedure
calculate_timing_metrics

# Save report to a file
redirect -file timing_metrics_report.txt {calculate_timing_metrics}