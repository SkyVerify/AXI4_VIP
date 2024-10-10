//---------------------------------------------------------------------------------------
// This VIP was created by Yosef Belyatsky @https://github.com/SkyVerify
// see AXI4_VIP.pdf for additional information and usage. 
//
// Hope this will be useful as a reference, learning/exercise material or part of a bigger project.
// Use with own responsibility and caution! 
// If you integrate this VIP or part of it in your project please note there is no guarantee 
// or warranty of any kind, express or implied, including but not limited to the warranties
// of merchantability, fitness for particular purpose and noninfringement.
//
// For any comments, bugs, issues or questions feel free to contact via yosefbel92@gmail.com
//--------------------------------------------------------------------------------------
// File          : axi_testbench.v
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// AXI4 back-to-back testbench
//--------------------------------------------------------------------------------------

import uvm_pkg::*;
import env_pkg::*;
import axi_test_lib::*;
import axi_utils_pkg::*;
`include "../top/utils/clk_defines.sv"
//===========================================================================//
module axi_testbench();
//===========================================================================//
// VARIABLES ====================================  //
// ============================================== //
	reg clk;

// CLK GENERATORS ===============================  //
// ============================================== //
	always #(`CYCLE/2) clk = ~clk; 

// INTERFACES ===================================  //
// ============================================== //
	axi_if axi_master_if(.clk(clk));
	axi_if axi_slave_if(.clk(clk));

// DUT ==========================================  //
// ============================================== //
	assign axi_slave_if.rst_n = axi_master_if.rst_n;
	assign axi_slave_if.wid   = axi_master_if.wid;
	if (DUT_EXIST == 0)begin
		assign axi_master_if.awready 	= axi_slave_if.awready;
		assign axi_master_if.wready 	= axi_slave_if.wready;
		assign axi_master_if.bid 		= axi_slave_if.bid;
		assign axi_master_if.bresp 		= axi_slave_if.bresp;
		assign axi_master_if.buser 		= axi_slave_if.buser;
		assign axi_master_if.bvalid		= axi_slave_if.bvalid;
		assign axi_master_if.arready 	= axi_slave_if.arready;
		assign axi_master_if.rid 		= axi_slave_if.rid;
		assign axi_master_if.rdata 		= axi_slave_if.rdata;
		assign axi_master_if.rresp 		= axi_slave_if.rresp;
		assign axi_master_if.rlast 		= axi_slave_if.rlast;
		assign axi_master_if.ruser 		= axi_slave_if.ruser;
		assign axi_master_if.rvalid 	= axi_slave_if.rvalid;

		assign axi_slave_if.awid 		= axi_master_if.awid;
		assign axi_slave_if.awaddr 		= axi_master_if.awaddr;
		assign axi_slave_if.awlen 		= axi_master_if.awlen;
		assign axi_slave_if.awsize 		= axi_master_if.awsize;
		assign axi_slave_if.awburst 	= axi_master_if.awburst;
		assign axi_slave_if.awlock 		= axi_master_if.awlock;
		assign axi_slave_if.awcache 	= axi_master_if.awcache;
		assign axi_slave_if.awprot 		= axi_master_if.awprot;
		assign axi_slave_if.awqos 		= axi_master_if.awqos;
		assign axi_slave_if.awregion 	= axi_master_if.awregion;
		assign axi_slave_if.awuser 		= axi_master_if.awuser;
		assign axi_slave_if.awvalid 	= axi_master_if.awvalid;
		assign axi_slave_if.wdata 		= axi_master_if.wdata;
		assign axi_slave_if.wstrb 		= axi_master_if.wstrb;
		assign axi_slave_if.wlast 		= axi_master_if.wlast;
		assign axi_slave_if.wuser 		= axi_master_if.wuser;
		assign axi_slave_if.wvalid 		= axi_master_if.wvalid;
		assign axi_slave_if.bready 		= axi_master_if.bready;
		assign axi_slave_if.arid 		= axi_master_if.arid;
		assign axi_slave_if.araddr 		= axi_master_if.araddr;
		assign axi_slave_if.arlen 		= axi_master_if.arlen;
		assign axi_slave_if.arsize 		= axi_master_if.arsize;
		assign axi_slave_if.arburst 	= axi_master_if.arburst;
		assign axi_slave_if.arlock 		= axi_master_if.arlock;
		assign axi_slave_if.arcache 	= axi_master_if.arcache;
		assign axi_slave_if.arprot 		= axi_master_if.arprot;
		assign axi_slave_if.arqos 		= axi_master_if.arqos;
		assign axi_slave_if.arregion 	= axi_master_if.arregion;
		assign axi_slave_if.aruser 		= axi_master_if.aruser;
		assign axi_slave_if.arvalid 	= axi_master_if.arvalid;
		assign axi_slave_if.rready 		= axi_master_if.rready;
	end
	else begin
		axi_ram dut(
			.clk  				(clk),
			.rst				(axi_master_if.rst_n)
				   );
	end

// MAIN =========================================  //
// ============================================== //
	initial begin
		clk <= 1'b0;
		uvm_config_db#(virtual axi_if)::set(null, "uvm_test_top", "axi_master_if", axi_master_if);	
		uvm_config_db#(virtual axi_if)::set(null, "uvm_test_top", "axi_slave_if", axi_slave_if);	
		run_test();
	end

endmodule : axi_testbench