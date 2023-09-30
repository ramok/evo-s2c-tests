#!/bin/sh
# vim: ft=tcl
# the next line restarts using expect \
    exec tclsh "$0" "$@"

namespace eval ::test::ims {
    set descrition \
        "Send IMS every Y seconds during X hours to collect data\n\
        about mutual clock drift between a transmitter and receivers"
}

proc ::test::ims::run {duration period ips} {
    set test ims
    ::test_helper::begin

    set payload 0
    ::am::send_ims $::snd_sid {} $payload
    set rep_rate [expr $period * 1000000]

    set eta_note_cnt 5
    #exp_internal 1
    set timeout -1 
    expect -i $::snd_sid -re {(SENDEND,\d+,ims,(\d+),.*?)\r\n} {
        if {[expr [clock seconds] - $ts_start] > $duration} {
            set timeout $period
            msg note "Test will end in $period seconds\n"
            exp_continue
        } else {
            set ts {}
            if {[info exist expect_out(2,string)]} {
                set ts $expect_out(2,string)
            }
            ::am::send_ims $::snd_sid [expr $ts + $rep_rate] $payload
            if {$eta_note_cnt <= 0} {
                set eta_note_cnt 5
                ::test_helper::show_eta 
            }
            incr eta_note_cnt -1
            exp_continue
        }
    } -re {(EXPIREDIMS.*?)\r\n} {
        if {[expr [clock seconds] - $ts_start] > $duration} {
            set timeout $period
            msg note "Test will end in $period seconds\n"
            exp_continue
        } else {
            incr payload
            ::log::log $::sid2ip($expect_out(spawn_id)) "$expect_out(1,string)\n"
            ::am::send_ims $::snd_sid {} $payload
            exp_continue
        }
    } -re {(CANCELEDIM.*?)\r\n} {
        if {[expr [clock seconds] - $ts_start] > $duration} {
            set timeout $period
            msg note "Test will end in $period seconds\n"
            exp_continue
        } else {
            incr payload
            ::log::log $::sid2ip($expect_out(spawn_id)) "$expect_out(1,string)\n"
            ::am::send_ims $::snd_sid [expr $ts + $rep_rate] $payload
            exp_continue
        }
    } -re {OK\r\n} { exp_continue
    } -re {^([^\r\n]*)\r\n} {
        ::log::log $::sid2ip($expect_out(spawn_id)) "$expect_out(1,string)\n"
        exp_continue
    } eof {
        msg warn "$::sid2ip($expect_out(spawn_id)) EOF\n"
    } -i ::rcv_sids -re {^([^\r\n]*)\r\n} {
        ::log::log $::sid2ip($expect_out(spawn_id)) "$expect_out(1,string)\n"
        exp_continue
    } timeout {
        # test done
    } full_buffer { exp_continue
    } eof {         msg warn "$::sid2ip($expect_out(spawn_id)) EOF\n"
    }

    ::test_helper::finish
}


