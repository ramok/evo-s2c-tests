############## start: message helpers ######################
namespace eval ::msg {
    namespace export c msg err die warn ok \
        hexdump hexdump_ascii bindump beep

    array set c {
        none  "\033\[0m"    white "\033\[1;37m"
        red   "\033\[0;31m" lred  "\033\[1;31m"
        grn   "\033\[0;32m" lgrn  "\033\[1;32m"
        yel   "\033\[0;33m" lyel  "\033\[1;33m"
        mag   "\033\[0;35m" lmag  "\033\[1;35m"
        lblue "\033\[1;36m" cyan  "\033\[0;36m"
    }

    # https://en.wikipedia.org/wiki/ANSI_escape_code
    array set esc {
        erase-line-to-end   "\033\[0K"
        erase-line-to-start "\033\[1K"
        erase-line          "\033\[2K"
    }

    variable show_prefix_state 1
    variable prefix "\[clock format \[clock seconds] -format {%d-%m-%Y %H:%M:%S}]: "
}

proc ::msg::msg {type msg {out stdout}} {
    if {[lsearch -exact $::opt(loglevel) $type] == -1} {
        return
    }
    
    switch $type {
        err     {set col $::msg::c(lred)}
        warn    {set col $::msg::c(lmag)}
        info    {set col $::msg::c(white)}
        note    {set col $::msg::c(cyan)}
        norm    {set col {}}
        todo    {set col $::msg::c(red)}
        detail  {set col $::msg::c(cyan)}
        dbg     {set col $::msg::c(mag)}
        ask     {set col $::msg::c(lyel)}
        pass    {set col $::msg::c(lgrn)}
        stage   {
            set col $::msg::c(grn)
            set msg "\r* $msg =================\n"
        }   
        default {set col {}}
    }   
    
    set prefix $::msg::c(none)[subst $::msg::prefix]$col
    regsub -all {\r} $msg \&$prefix msg
    regsub -all {\n([^\n])} $msg "\n$prefix\\1" msg
    regsub -all {\n\n} $msg "\n$prefix\n" msg
    if {$::msg::show_prefix_state} {
        set msg $prefix$msg
    } else {
        set msg $col$msg
    }   

    if {[regexp {[\n\r]$} $msg]} {
        set ::msg::show_prefix_state 1
    } else {
        set ::msg::show_prefix_state 0
    }   
    
    puts -nonewline $out $msg$::msg::c(none)
    flush $out
    if {[info exist ::log::fd]} {
        puts -nonewline $::log::fd $msg$::msg::c(none)
        flush $::log::fd
    }
}   

proc ::msg::die {msg} {
    set d [info frame -1]

    if {[dict exist $d proc]} {
        set prefix [dict get $d proc]:
    } else {
        set prefix $::opt(progname):
    }

    msg err "$prefix[dict get $d line]: $msg\n" stderr
    exit 1
}

proc ::msg::err {msg} {
    msg warn "error: $msg\n"
    flush stdout
}

proc ::msg::warn {msg} {
    msg warn "warning: $msg\n"
    flush stdout
}

proc ::msg::ok {} {
    msg pass "\r ok$::msg::esc(erase-line-to-end)\n"
}

proc ::msg::hexdump string {
    binary scan $string H* hex
    regexp -all -inline .. $hex
}

proc ::msg::hexdump_ascii {string {shift {}}} {
    for {set i 0} {$i < [string length $string]} {incr i 16} {
        set row [string range $string $i [expr {$i + 15}]]
        binary scan $row H* hex
        set hex [regsub -all {(.{2})} [format %-32s $hex] {\1 }]
        set row [regsub -all {[^[:print:]]} $row .]
        puts [format "$shift%08x: %s %-16s" $i $hex $row]
    }
}

proc ::msg::bindump string {
    binary scan $string b* bin
    regexp -all -inline .{8} $bin
}

proc ::msg::beep {} {
    after 0 {
        send_tty "\x07"
        for {set i 0} {$i < 3} {incr i} {
            sleep 1
            send_tty "\x07"
        }
    }
}

namespace import ::msg::*
