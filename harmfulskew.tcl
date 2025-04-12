proc find_harmful_skew {clock_name} {
    # Get timing paths with negative slack
    set paths [report_timing -delay_type max -slack_lesser_than 0 -return_paths]
    foreach_in_collection path $paths {
        set launch_pin [get_attribute $path startpoint_clock_pin]
        set capture_pin [get_attribute $path endpoint_clock_pin]
        set slack [get_attribute $path slack]
        set launch_latency [get_attribute $launch_pin arrival_time]
        set capture_latency [get_attribute $capture_pin arrival_time]
        set skew [expr $capture_latency - $launch_latency]
        if {$slack < 0 && $skew > 0} {
            puts "Harmful Skew (Setup): $skew ns, Slack: $slack ns"
            puts "  Launch Pin: $launch_pin, Capture Pin: $capture_pin"
        } elseif {$slack < 0 && $skew < 0} {
            puts "Harmful Skew (Hold): $skew ns, Slack: $slack ns"
            puts "  Launch Pin: $launch_pin, Capture Pin: $capture_pin"
        }
    }
}
# Execute
find_harmful_skew clk

