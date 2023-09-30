namespace eval ::log {
}

proc ::log::main_init {} {
    file mkdir $::opt(log-dir)/
    set fname $::opt(log-dir)/main.log
    set ::log::fd [open $fname a]
}

proc ::log::main_log {msg} {
    puts -nonewline $::log::fd $msg
}

proc ::log::main_deinit {} {
    catch {
        ::close $::log::fd
        unset ::log::fd
    }
}

proc ::log::test_init {test timestamp ip} {
    set ::log::dir $::opt(log-dir)/$test/[clock format $timestamp -format {%d-%m-%Y_%H-%M-%S}]_$ip
    file mkdir $::log::dir
    msg note "Create $::log::dir/\n"
}

proc ::log::test_deinit {} {
    unset ::log::dir
}

proc ::log::log {ip msg {quiet 0}} {
    if {![info exist ::log::dir]} {
        return
    }
    if {!$quiet} {
        msg norm "$ip: $msg"
    }
    set fname $::log::dir/$ip.log
    set fd [open $fname a]
    puts -nonewline $fd $msg
    ::close $fd
}
