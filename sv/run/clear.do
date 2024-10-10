quit -sim
if {[ file exists "work" ]} {
	vdel -all -lib work
	set log_files [glob *.log]
	foreach log $log_files {
		if { $log != "run_log.log"} {
			erase $log
		} else {
			close [open $log "w+"]
		}
	}
}