namespace eval ::test::sync {
    set descrition \
        "Send AT%SYNC (point to point) periodically. Log the correction\n\
        returned by AT%SYNC command."
}
proc ::test::sync::run {duration period ips} {
    set test sync
    ::test_helper::begin

    set sync_done 0
    while {!$sync_done} {
        foreach sid $::rcv_sids {
            ::test_helper::time_sync

            if {[expr [clock seconds] - $ts_start + $period - 3] >= $duration} {
                set sync_done 1
                break
            }

            ::test_helper::show_eta 

            # to compensate -timeout subtract 3
            sleep [expr $period - 3]
        }
    }

    ::test_helper::finish
}

