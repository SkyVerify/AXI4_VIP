#### SET PARAMETERS ####
########################
set DATE			[clock format [clock seconds] -format {%d-%h-%y}]
set CUR_DIR 		[ pwd ]
set REG_DIR			$CUR_DIR/regression/$DATE
set TRANSACTIONS	100

######## TESTS #########
########################
set testList {
	axi_connectivity_test
	axi_corner_cases_test
	axi_fixed_test
	axi_incr_test
	axi_wrap_test
}

##### CREATE DIR #######
########################
if {[ file exists $REG_DIR ]} {
	file delete -force $REG_DIR
}
file mkdir $REG_DIR
file mkdir $REG_DIR/logs
file mkdir $REG_DIR/coverage

######## MAIN ##########
########################
do compile.do
foreach test $testList {
	do run.do $test $TRANSACTIONS
	quit -sim
	file rename -force sim_log.log $REG_DIR/logs/${test}_log.log
	file rename -force coverage_report.ucdb $REG_DIR/coverage/${test}_coverage_report.ucdb
}

###### COVERAGE ########
########################
cd $REG_DIR/coverage
vcover merge -64 merged_coverage_report.ucdb *.ucdb
vsim -cvgperinstance -viewcov merged_coverage_report.ucdb -do "coverage report -cvg -details -htmldir covhtmlreport -assert -directive -html"

####### SUMMARY ########
########################
cd $REG_DIR/logs
set summary "../regression_summary.txt"
set summaryId [open $summary "w"]
set log_files [glob *.log]

foreach log $log_files {
	set f [open $log r]
	set fd [read $f]
	set flines [split $fd "\n"]
   	set status [lsearch -all -inline $flines {TEST STATUS:*}]
   	set test_name [string trim [lindex [split $log "."] 0] "_log"]
   	set test_status [string trim [lindex [split $status ":"] 1] "{}"]
   	set result "${test_name}\t${test_status}"
    puts $summaryId $result

	close $f
}
close $summaryId
exit