# Script to calculate harmful skew in IC Compiler
# Assumes design is loaded, constraints applied, and CTS completed

proc calculate_harmful_skew {} {
    # Get all timing paths with negative slack (potential violations)
    set paths [get_timing_paths -slack_lesser_than 0 -max_paths 100]

    # Check if paths exist
    if {[sizeof_collection $paths] == 0} {
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

        # Get the cells of startpoint and endpoint
        set startpoint_cell [get_cells -of $startpoint]
        set endpoint_cell [get_cells -of $endpoint]

        # Get the clock pins of the cells
        set launch_clock_pins [get_pins -of $startpoint_cell -filter "is_clock_pin"]
        set capture_clock_pins [get_pins -of $endpoint_cell -filter "is_clock_pin"]

        if {[llength $launch_clock_pins] == 0 || [llength $capture_clock_pins] == 0} {
            puts "Warning: Could not retrieve clock pins for path from [get_attribute $startpoint name] to [get_attribute $endpoint name]"
            continue
        }
        set launch_clock_pin [lindex $launch_clock_pins 0]
        set capture_clock_pin [lindex $capture_clock_pins 0]

        # Extract clock arrival times (in ns)
        set launch_arrival [get_attribute $launch_clock_pin arrival]
        set capture_arrival [get_attribute $capture_clock_pin arrival]

        # Calculate skew (capture - launch)
        set skew [expr $capture_arrival - $launch_arrival]

        # Get slack and path type (setup or hold)
        set slack [get_attribute $path slack]
        set path_type [get_attribute $path path_type]

        # Check if the path is within a single clock domain
        set clocks [get_attribute $path clocks]
        if {[llength $clocks] != 1} {
            puts "Warning: Path from [get_attribute $startpoint name] to [get_attribute $endpoint name] involves multiple clocks. Skipping."
            continue
        }
        set clock_period [get_attribute [lindex $clocks 0] period]

        # Get data path delay
        set data_path_delay [get_attribute $path data_path_delay]

        # Get setup or hold time from library model
        set lib_pin [get_lib_pins -of $endpoint]
        if {[llength $lib_pin] == 0} {
            puts "Warning: Could not get library pin for endpoint [get_attribute $endpoint name]"
            continue
        }
        set lib_pin [lindex $lib_pin 0]

        # Calculate harmful skew
        set harmful_skew 0
        if {$path_type == "max"} {
            # Setup violation
            set setup_time [get_attribute $lib_pin setup_threshold]
            set S_min [expr $data_path_delay + $setup_time - $clock_period]
            if {$skew < $S_min} {
                set harmful_skew [expr $S_min - $skew]
            }
        } elseif {$path_type == "min"} {
            # Hold violation
            set hold_time [get_attribute $lib_pin hold_threshold]
            set S_max [expr $data_path_delay - $hold_time]
            if {$skew > $S_max} {
                set harmful_skew [expr $skew - $S_max]
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