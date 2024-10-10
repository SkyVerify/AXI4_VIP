#### SET PARAMETERS ####
########################
set CUR_DIR 	[ pwd ]
set ROOT_DIR 	"../"
set SRC_DIR 	"../../src/verilog-axi/rtl"
set UVM_SRC 	"C:/modeltech64_10.7/verilog_src/uvm-1.2/src"

#### PRE COMPILE ACTIONS ####
#############################
do clear.do
vlib work
vmap work  

#### RTL COMPILE ####
#####################
set sfiles "src_files.txt"
set sfilesId [open $sfiles "w"]
set src_files [glob $SRC_DIR/*.v]
foreach file $src_files {
    puts $sfilesId "${file}"
}
close $sfilesId

vlog -l src_log.log -timescale "1ns/100ps" -f ./src_files.txt

#### UVM COMPILE ####
#####################
#vlog -l uvm_log.log -sv -incr $UVM_SRC/uvm_pkg.sv +incdir+$UVM_SRC

## UTILS ##
vlog -l axi_utils_log.log -sv -incr +incdir+$ROOT_DIR/top/utils +incdir+$UVM_SRC $ROOT_DIR/top/utils/axi_utils_pkg.sv 

## IFs ##
vlog -l axi_master_if_log.log -sv -incr +incdir+$ROOT_DIR/top/axi_agent +incdir+$UVM_SRC $ROOT_DIR/top/axi_agent/axi_if.sv 

## Agents ##
vlog -l axi_log.log -sv -incr +incdir+$ROOT_DIR/top/axi_agent +incdir+$UVM_SRC $ROOT_DIR/top/axi_agent/axi_agent_pkg.sv

## ENV, TESTS, SEQUENCES ##
vlog -l env_log.log -sv -incr +incdir+$ROOT_DIR/top/env +incdir+$UVM_SRC $ROOT_DIR/top/env/env_pkg.sv
vlog -l seq_log.log -sv -incr +incdir+ROOT_DIR/top/sequences +incdir+$UVM_SRC $ROOT_DIR/top/sequences/axi_seq_lib.sv 
vlog -l test_log.log -sv -incr +incdir+$ROOT_DIR/top/tests +incdir+$UVM_SRC $ROOT_DIR/top/tests/axi_test_lib.sv 

## TESTBENCH ##
vlog -l tb_log.log -sv -timescale "1ns/100ps" $ROOT_DIR/testbench/axi_testbench.v