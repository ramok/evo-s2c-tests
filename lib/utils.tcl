proc rand {min max} {
    return [expr {int(rand() * ($max - $min + 1) + $min)}]
}

proc check_for_following {type} {
    global argv0
    if {![llength [uplevel set argv]]} {
        send_error "$argv0: [uplevel set flag] requires following $type"
        exit 2
    }
}

proc lrotate {xs {n 1}} {
    if {$n == 0 || [llength $xs] == 0 } {return $xs}
    set n [expr {$n % [llength $xs]}]
    return [concat [lrange $xs $n end] [lrange $xs 0 [expr {$n - 1}]]]
}

proc canonize_ip {ip_} {
    regexp {^((?:(?:\d{1,3}\.){3}\d{1,3})|\d{1,3}):?(\d+)?$} $ip_ -> ip port
    if {![info exist ip] || $ip == {}} {
        die "Expect \"$ip_\" as IP in formar <digit>.<digit>.<digit>.<digit> or 192.168.0.<digit>. optional port \":<digit>\""
    }
    if {$port == {}} {
        set port 9200
    }
    if {[regexp {^\d+$} $ip]} {
        set ip 192.168.0.$ip
    }
    set ::port($ip) $port
    return $ip
}

proc sec2date {sec} {
    clock format $sec -format {%d-%m-%Y %H:%M:%S}
}

proc timeunit2sec {unit} {
    regexp {^(\d+)([mhd])$} $unit -> digit suffix
    switch -regexp -- $unit {
        {\d+m} { return [expr $digit * 60] }
        {\d+h} { return [expr $digit * 60 * 60] }
        {\d+d} { return [expr $digit * 60 * 60 * 24] }
        {\d+}  { return $unit }
        {*}    { return {} }
    }
}

proc sec2human {in_sec} {
    if {$in_sec <= 60} { return "$in_sec sec" }
    set out {}
    if {[set mday [expr int($in_sec / (24 * 60 * 60))]] != 0} { lappend out "$mday day" }
    if {[set hour [expr int($in_sec / (60 * 60) % 24)]] != 0} { lappend out "$hour hour"}
    if {[set min  [expr int(($in_sec / 60) % 60)]]      != 0} { lappend out "$min min"  }
    if {[set sec  [expr int($in_sec % 60)]]             != 0} { lappend out "$sec sec"  }
    return "$in_sec sec ([join $out { }])"
}

proc human_eta_time {start duration msg_fmt} {
    return [format $msg_fmt [sec2human [expr $start + $duration - [clock seconds]]]]
}

proc ask_yes {msg} {
    set rc 1

    while 1 {
        msg ask "$msg \[Y|n]: "
        expect_user -re {^[Yy]?\n} {
            set rc 1
            break
        } -re {^[Nn]\n} {
            set rc 0
            break
        } -re {.*\n} {
        }
    }

    return $rc
}

############## end: help function ######################

