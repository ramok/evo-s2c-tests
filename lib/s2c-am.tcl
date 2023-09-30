namespace eval ::am {
    namespace export connect sendim flush_all
}

proc ::am::connect {ip} {
    msg note "Connect to $ip:$::port($ip)\n"
    while {[catch {spawn -open [socket $ip $::port($ip)]} err]} {
        msg warn "$ip:$::port($ip): $err. Try reconnect in 1 sec\n"
        sleep 1
    }
    fconfigure $spawn_id -translation binary
    set ::sid2ip($spawn_id) $ip:$::port($ip)
    return $spawn_id
}

proc ::am::disconnect {sid} {
    msg note "Disconnect from $::sid2ip($sid)\n"
    catch {
        exp_close -i $sid
        expect -i $sid eof
    }
    unset ::sid2ip($sid)
}

proc ::am::send {sid cmd} {
    ::log::log $::sid2ip($sid) "$cmd" 1
    msg info  "$::sid2ip($sid) => $cmd"
    exp_send -i $sid -- $cmd
}

proc ::am::send_ims {sid sendtime payload} {
    ::am::send $sid "AT*SENDIMS,[string length $payload],255,$sendtime,$payload\n"
}

proc ::am::send_sync {sid addr} {
    ::am::send $sid "AT%SYNC,$addr,10\n"
}

proc ::am::reset_all {sids} {
    flush_all $::sids
    foreach sid $sids {
        catch {::am::send $sid "ATZ4\n"}
        expect -i $sid -timeout 1 -re .+ exp_continue timeout
        catch {::am::send $sid "AT%RESET\n"}
        expect -i $sid -timeout 1 -re .+ exp_continue timeout
    }
}

proc ::am::flush_all {sids} {
    msg note "Flushing data from all modems... "
    expect -timeout 1 -i $sids -re .+ {
        msg dbg "\n$::sid2ip($expect_out(spawn_id)) flushed: $expect_out(buffer)"
        exp_continue
    } timeout
    msg note "done\n"
}

proc ::am::get_timeout_buffer {sid} {
    set out {}
    expect -timeout 1 -i $sid -re .+ {
        lappend out $expect_out(buffer)
    }
    return [join $out]
}

proc ::am::send_all {sids cmds} {
    foreach cmd-repl $cmds {
        foreach sid $sids {
            set cmd  [subst [lindex ${cmd-repl} 0]]
            set answ {(?:\[\*])?OK}

            if {[llength ${cmd-repl}] > 1} {
                set answ [lindex ${cmd-repl} 1]
            }

            #exp_internal 1
            catch {::am::send $sid "$cmd\n"}
            expect -timeout 2 -i $sid -re "^$answ\r\n" {
                if {[llength ${cmd-repl}] > 2} {
                    # create array name in [lindex ${cmd-repl} 2] with index $sid
                    set [lindex ${cmd-repl} 2]($sid) $expect_out(1,string)
                }
            } -re {ERROR NO CONTROL\r\n} {
                ::am::send $sid "AT@CTRL\n"
                expect -timeout 1 -i $sid -re {OK\r\n} {
                } timeout {
                    die "Can't get expected replay on command \"$cmd\", In buffer: [::am::get_timeout_buffer $sid]\n"
                }
                ::am::send $sid "$cmd\n"
                exp_continue
            } timeout {
                die "Can't get expected replay on command \"$cmd\", In buffer: [::am::get_timeout_buffer $sid]\n"
            } eof {
                die "Connection close\n"
            }
        }
    }
}

proc ::am::check_modems {} {
    msg note "Checking modem configuration\n"

    # mute log output
    set ll $::opt(loglevel)
    set ::opt(loglevel) {err warn}

    foreach ip $::ips {
        lappend ::sids [connect $ip]
    }
    flush_all $::sids

    exp_internal 0
    # catch "+++AT:12:ERROR EFAULT\r\n" if tests runned on wires
    foreach sid $::sids {
        expect_before -i $sid -ex {+++AT:12:ERROR EFAULT\r\n}
    }
    ::am::send_all $::sids $::opt(check-cmds)

    # we need local version of sid2ip,
    # becouse ::am::disconnect clean it up
    array set sid2ip [array get ::sid2ip]
    foreach sid $::sids {
        ::am::disconnect $sid
    }
    set ::opt(loglevel) $ll

    foreach sid $::sids {
        msg note "$sid2ip($sid): fw: $::ver_fw($sid)\n"

        set ::opt(no-evins) 1
        if {!$::opt(no-evins)} {
            foreach s [lmap {p1 p2 p3 p4 p5} [split $::ver_evins($sid) ,] {join [list $p1 $p2 $p3 $p4 $p5]}] {
                msg note "$sid2ip($sid): evins: $s\n"
            }
            regexp {evins_proprietary:(0\.[\d+])} $::ver_evins($sid) -> ver
            if {![info exist ver] || \
                    ![string is double $ver] || \
                $ver < $::opt(evins-ver-min)} {
                if {![info exist ver]} {
                    set ver unknown
                }
                die "Evins version $ver, but should be not less then $::opt(evins-ver-min)\n"
            }
        }
    }
    array unset sid2ip 
    array unset ::ver_fw
    array unset ::ver_evins
    unset ::sids
}

namespace import ::am::*

