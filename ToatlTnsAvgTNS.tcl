proc calc_tns_avg {} {
    # Run QoR report
    report_qor > qor_report.rpt
    set tns 0
    set num_paths 0
    # Parse report (simplified; adjust regex based on report format)
    set fp [open "qor_report.rpt" r]
    while {[gets $fp line] >= 0} {
        if {[regexp {Total Negative Slack.*: (-\d+\.\d+)} $line match tns_val]} {
            set tns $tns_val
        }
        if {[regexp {Number of Violating Paths.*: (\d+)} $line match path_count]} {
            set num_paths $path_count
        }
    }
    close $fp
    puts "Total Negative Slack (TNS): $tns ns"
    if {$num_paths > 0} {
        set avg_tns [expr $tns / $num_paths]
        puts "Average TNS: $avg_tns ns/path"
    } else {
        puts "No violating paths found."
    }
}
# Execute
calc_tns_avg