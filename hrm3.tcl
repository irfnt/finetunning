# File: calc_harmful_skew.tcl
# Purpose: Calculate harmful skew in Synopsys IC Compiler for paths with timing violations
# Assumes design is loaded, constraints applied, and CTS completed

proc calculate_harmful_skew {} {
    # Validate design setup
    if {[sizeof_collection [get_clocks *]] == 0} {
        puts "Error: No clocks defined. Check SDC file."
        return
    }

    # Open report file
    set report_file "harmful_skew_report.txt"
    set fh [open $report_file w]
    puts $fh "Harmful Skew Analysis Report - [clock format [clock seconds]]"
    puts $fh "----------------------------"
    puts $fh "Path | Skew (ns) | Slack (ns) | Violation Type | Harmful Skew (ns)"

    # Output header to console
    puts "Harmful Skew Analysis Report"
    puts "----------------------------"
    puts "Path | Skew (ns) | Slack (ns) | Violation Type | Harmful Skew (ns)"

    # Initialize counters
    set harmful_skew_count 0

    # Step 1: Get setup paths with negative slack (max delay)
    set setup_paths [get_timing_paths -slack_lesser_than 0 -max_paths 100 -delay_type max]
    set hold_paths [get_timing_paths -slack_lesser_than 0 -max_paths 100 -delay_type min]

    # Step 2: Process setup paths
    foreach_in_collection path $setup_paths {
        if {![process_path $path $fh "Setup" harmful_skew_count]} {
            continue
        }
        incr harmful_skew_count
    }

    # Step 3: Process hold paths
    foreach_in_collection path $hold_paths {
        if {![process_path $path $fh "Hold" harmful_skew_count]} {
            continue
        }
        incr harmful_skew_count
    }

    # Step 4: Summary
    if {$harmful_skew_count == 0} {
        puts "No timing violations found. All paths have positive slack."
        puts $fh "No timing violations found. All paths have positive slack."
    } else {
        puts "----------------------------"
        puts "Total Paths with Harmful Skew: $harmful_skew_count"
        puts $fh "----------------------------"
        puts $fh "Total Paths with Harmful Skew: $harmful_skew_count"
    }

    close $fh
    puts "Report saved to $report_file"
}

# Helper procedure to process a single timing path
proc process_path {path fh violation_type harmful_skew_count} {
    upvar $harmful_skew_count count

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

    # Get clock arrival times
    set launch_arrival [get_attribute [get_timing_arcs -to $launch_clock_pin] arrival]
    set capture_arrival [get_attribute [get_timing_arcs -to $capture_clock_pin] arrival]

    if {$launch_arrival == "" || $capture_arrival == ""} {
        puts $fh "Warning: Could not retrieve clock arrivals for path from [get_attribute $startpoint name] to [get_attribute $endpoint name]"
        return 0
    }

    # Calculate skew
    set skew [expr $capture_arrival - $launch_arrival]

    # Get slack
    set slack [get_attribute $path slack]

    # Harmful skew is the skew value itself for paths with negative slack
    set harmful_skew $skew

    # Format path name
    set path_name "[get_attribute $startpoint name] -> [get_attribute $endpoint name]"

    # Output results
    puts [format "%s | %.3f | %.3f | %s | %.3f" \
          $path_name $skew $slack $violation_type $harmful_skew]
    puts $fh [format "%s | %.3f | %.3f | %s | %.3f" \
              $path_name $skew $slack $violation_type $harmful_skew]

    return 1
}

# Execute the procedure
calculate_harmful_skew