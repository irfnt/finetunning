# File: output_harmful_skew.tcl
# Purpose: Output only harmful skew values in Synopsys IC Compiler

puts "Extracting harmful skew values..."

set clock_name "clk"  ;# Replace with your clock name
if {![get_clocks $clock_name -quiet]} {
    puts "Error: Clock $clock_name not found."
    return
}

set paths [get_timing_paths -max_paths 1000 -slack_lesser_than 0.0]
set harmful_skew_count 0

puts "Harmful Skew Values:"
puts "--------------------"
foreach_in_collection path $paths {
    set launch_point [get_attribute $path startpoint]
    set capture_point [get_attribute $path endpoint]
    set launch_clock_pin [get_pins -of_objects $launch_point -filter "is_clock_pin==true"]
    set capture_clock_pin [get_pins -of_objects $capture_point -filter "is_clock_pin==true"]

    if {$launch_clock_pin == "" || $capture_clock_pin == ""} {
        continue
    }

    set launch_arrival [get_attribute [get_timing_arcs -to $launch_clock_pin] arrival]
    set capture_arrival [get_attribute [get_timing_arcs -to $capture_clock_pin] arrival]
    set skew [expr $capture_arrival - $launch_arrival]

    set setup_slack [get_attribute $path slack]
    set hold_path [get_timing_paths -from $launch_point -to $capture_point -delay_type min]
    set hold_slack [get_attribute $hold_path slack]

    if {$setup_slack < 0 || $hold_slack < 0} {
        incr harmful_skew_count
        puts "Path $harmful_skew_count: $skew ns ([expr {$setup_slack < 0 ? "Setup" : "Hold"}] Violation)"
    }
}

puts "--------------------"
puts "Total Harmful Skew Paths: $harmful_skew_count"