package axi_agent_pkg;
	
	import uvm_pkg::*;
	`include "uvm_macros.svh"
	import axi_utils_pkg::*;

	`include "axi_seq_item.svh"
	`include "../utils/axi_memory.svh"
	`include "axi_agent_config.svh"
	`include "axi_driver.svh"
	`include "axi_monitor.svh"
	`include "axi_coverage_collector.svh"
	`include "axi_master_driver.svh"
	`include "axi_slave_driver.svh"
	`include "axi_agent.svh"

endpackage