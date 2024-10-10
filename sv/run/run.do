set TESTNAME axi_fixed_test ; list
set CMDS 10 ; list 
set VERBOSITY UVM_LOW ; list 
set SEED random ; list

if {$argc == 1} {
	set TESTNAME $1
}

if {$argc == 2} {
	set TESTNAME $1
	set CMDS $2
}

if {$argc == 3} {
	set TESTNAME $1
	set CMDS $2
	set VERBOSITY $3
}

if {$argc == 4} {
	set TESTNAME $1
	set CMDS $2
	set VERBOSITY $3
	set SEED $4
}
echo "###########################\ntest = ${TESTNAME}\ntransactions = ${CMDS}\nverbosity = ${VERBOSITY}\nseed = ${SEED}\n###########################"

vsim -cvgperinstance -vopt -voptargs="+acc=rn" -solvefaildebug -uvmcontrol=all "+UVM_NO_RELNOTES" "+UVM_VERBOSITY=$VERBOSITY" "+UVM_TESTNAME=$TESTNAME" -GNUM_OF_CMD=$CMDS -classdebug -coverage -sva -t 1ps -onfinish stop "+nowarnTFMPC" -l run_log.log -sv_seed $SEED work.axi_testbench
#"+UVM_CONFIG_DB_TRACE" 

add log -r /*
coverage save -onexit -testname $TESTNAME coverage_report.ucdb
run -all

## coverage report:
coverage report -cvg -details -htmldir covhtmlreport -assert -directive -html coverage_report.ucdb