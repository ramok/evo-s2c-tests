namespace eval ::test::pcsync {
    set descrition \
        "Sync physical clock of main modem with PC clock and on remote modems.\n\
        Checking periodically physical clock syncing with PC in main modem"
}

proc ::test::pcsync::run {duration period ips} {
    set test pcsync
    ::test_helper::begin

    set period 60
    set pcsync_done 0
    while {!$pcsync_done} {
        # 1. sync.sh  PC with modem
        ::log::log $::sid2ip($::snd_sid) "Test '$test'\[1]: sync $::sid2ip($::snd_sid) physical clock with PC clock\n"
        ::test_helper::pc_sync

        ::log::log $::sid2ip($::snd_sid) "Test '$test'\[2]: sync $::sid2ip($::snd_sid) physical clock with remote modems\n"
        # step 2. AT%SYNC  1 -> {2,3,4}
        foreach sid $::rcv_sids {
            ::test_helper::time_sync
        }

        set check_cnt 5
        for {set i 0} {$i < $check_cnt} {incr i} {
            # 3. check_sync.sh 1 -> {1,2,3}
            ::log::log $::sid2ip($::snd_sid) \
                "Test '$test'\[3]: check $::sid2ip($::snd_sid) physical clock syncing with PC \[[expr $i + 1]/$check_cnt]\n"

            flush_all [list $::snd_sid $::rcv_sids]
            foreach sid $::rcv_sids {
                ::test_helper::pc_check_sync
            }

            if {[expr [clock seconds] - $ts_start + $period] >= $duration} {
                set pcsync_done 1
                break
            }

            # 4. sleep 1m
            if {$i < [expr $check_cnt - 1]} {
                ::test_helper::show_eta
                sleep $period
            }

            # 5. goto 3 for 5 times
        }
    }


    ::test_helper::finish
}
