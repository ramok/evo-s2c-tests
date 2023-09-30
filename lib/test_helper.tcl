namespace eval ::test_helper:: {
}

proc ::test_helper::parse_name_tests {in} {
    set tests [split $in ,]
    foreach test $tests {
        switch -re $test {
            {all|ims|sync|pcsync} {}
            default {
                die "Unknown test name. Must be 'all' or 'ims' or 'sync' or 'pcsync'"
            }
        }
    }

    if {[llength $tests] != 1 && [lsearch -exact $tests all] != -1} {
        die "'all' can be only one test"
    }

    if {$tests == {all}} {
        set tests {ims sync pcsync}
    }

    return $tests
}

proc ::test_helper::begin {} {
    uplevel 1 {
        set ts_start [clock seconds]

        set snd_ip [lindex $ips 0]
        set rcv_ip [lrange $ips 1 end]

        msg stage "test '$test' start. Duration: $duration sec"
        msg info "Transmit from: $snd_ip:$::port($snd_ip)\n"
        msg info "Recevice in:\n"
        foreach ip $rcv_ip {
            msg info "  $ip:$::port($ip)\n"
        }


        set ::sids {}
        foreach ip $ips {
            lappend ::sids [connect $ip]
        }
        set ::snd_sid  [lindex $::sids 0]
        set ::rcv_sids [lindex $::sids 1 end]

        ::log::test_init $test $ts_start $snd_ip

        flush_all [list $::snd_sid {*}$::rcv_sids]

        ::am::send_all $::sids $::opt(init-cmds)
    }
}

proc ::test_helper::finish {} {
    msg stage "test done"
    uplevel 1 {
        ::am::reset_all $::sids
        foreach sid $::sids {
            ::am::disconnect $sid
        }
        unset ::sids
        ::log::test_deinit
    }
}

proc ::test_helper::time_sync_reset_resend {} {
    uplevel 1 {
            if {$try_again > 0} {

                ::am::send $::snd_sid "AT%RESET\n"
                expect -timeout 2 -i $::snd_sid -re "%RESET,done\r\n"

                incr try_again -1
                msg note "will retry in 3 sec \[[expr 3 - $try_again]/3]\n"
                sleep 3
                ::am::send_sync $::snd_sid $::sid2laddr($sid)
                exp_continue
            }
    }
}
proc ::test_helper::time_sync {} {
    uplevel 1 {
        ::am::send_sync $::snd_sid $::sid2laddr($sid)

        set try_again 3
        set time_sync_done 0
        set timeout 10
        expect -i $::snd_sid -re {(%SYNC,\d+,[-\d]+,.*?)\r\n} {
            ::log::log $::sid2ip($expect_out(spawn_id)) "$expect_out(1,string)\n"
            # need to collect logs in remote nodes
            set timeout 3 
            set time_sync_done 1
            exp_continue
        } -re {(%SYNC,\d+,(failed|busy))\r\n} {
            ::log::log $::sid2ip($expect_out(spawn_id)) "$expect_out(1,string)\n"
            ::test_helper::time_sync_reset_resend
        } -re {OK\r\n} { exp_continue
        } -re {^([^\r\n]*)\r\n} {
            ::log::log $::sid2ip($expect_out(spawn_id)) "$expect_out(1,string)\n"
            exp_continue
        } timeout {
            msg note "Timeout. done: $time_sync_done, timeout $timeout\n"
            if {!$time_sync_done} {
                ::test_helper::time_sync_reset_resend
            }
        } eof {        msg warn "$::sid2ip($expect_out(spawn_id)) EOF\n"
        } -i ::rcv_sids -re {^([^\r\n]*)\r\n} {
            ::log::log $::sid2ip($expect_out(spawn_id)) "$expect_out(1,string)\n"
            exp_continue
        } timeout {
        } full_buffer { exp_continue
        } eof {         msg warn "$::sid2ip($expect_out(spawn_id)) EOF\n"
        }
    }
}

proc ::test_helper::show_eta {} {
    uplevel 1 {
        msg note [join [list \
            "Test '$test': [human_eta_time $ts_start $duration "%s left"]." \
            "Delay for a $period sec." \
            "Tests run ETA [human_eta_time $::tests_run_time_start $::tests_run_time_est "%s left"]\n" \
        ]]
    }
}

proc ::test_helper::pc_sync {} {
    uplevel 1 {
        ::test_helper::pc_check_sync

        # set the time offset
        # NOTE: not use ::am::send for speed
        set at_rto "AT!RTO[expr $off + $t_o]\n"
        msg info  "$::sid2ip($::snd_sid) => $at_rto"
        send -i $::snd_sid -- $at_rto
        expect -i $::snd_sid -re {RTO,(\d+)\r\n} {
            msg note "RTO set $expect_out(1,string) done\n"
            exp_continue
        } -re {OK\r\n} {
        }

        ::test_helper::pc_check_sync
    }
}

proc ::test_helper::pc_check_sync {} {
    uplevel 1 {
        ::am::send_all [list $::snd_sid] { {AT@ZX0} }

        set rate 19200
        set rate 10000000
        set at_rtc "AT?RTC\n"

        # local time in microseconds (before ?RTC request)
        set t1 [clock microseconds]

        # request ?RTC from the modem
        # NOTE: not use ::am::send for speed
        msg info  "$::sid2ip($::snd_sid) => $at_rtc"
        send -i $::snd_sid -- $at_rtc
        expect -i $::snd_sid -re {(\d+)\r\n} {
            set t_m $expect_out(1,string)
        }

        # local time in microseconds (after ?RTC request) 
        set t2  [clock microseconds]

        # message length (transmitted) in bytes
        set l1  [string length $at_rtc]
        # message transmission duration in microseconds
        set md1 [expr 1000000*10*$l1/$rate]

        # message length (transmitted and received) in bytes
        set l   [expr [string length $t_m] + 2]
        # message transmission duration in microseconds
        set md  [expr 1000000*10*$l/$rate]

        # round trip time
        set delta [expr ($t2 - $t1-$md) / 2]

        # request ?RTO (the time offset)
        # NOTE: not use ::am::send for speed
        msg info  "$::sid2ip($::snd_sid) => AT?RTO\n"
        send -i $::snd_sid -- "AT?RTO\n"
        expect -i $::snd_sid -re {(\d+)\r\n} {
            set t_o $expect_out(1,string)
        }

        # time offset between PC and the modem
        set off [expr $t1 + $delta + $md1 - $t_m]

        ::log::log $::sid2ip($::snd_sid) "delta: $delta, offset: $off, T1: $t1, Tm: $t_m, To: $t_o, MD: $md, L: $l)\n"
        ::am::send_all [list $::snd_sid] { {AT@ZX1} }
    }
}

############# end: test helpers ###################################

