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
// File          : axi_if.sv
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// AXI4 interface
//--------------------------------------------------------------------------------------
import uvm_pkg::*;
`include "uvm_macros.svh"

import axi_utils_pkg::*;
`include "../utils/clk_defines.sv"

//===========================================================================//
interface axi_if (input logic clk);
//===========================================================================//
// INTERFACE SIGNALS ============================  //
// ============================================== //
	// Global signals:
	logic 	rst_n;						//	async active low reset

	// Write address channel:
	wire 	[ID_WIDTH-1:0]awid;			//	write address id
	wire 	[ADDR_WIDTH-1:0]awaddr;		//	write addres
	wire 	[7:0]awlen;					//	burst length - num of transfers in burst
	wire 	[2:0]awsize;				//	burst size - size of each transfer in burst
	wire 	[1:0]awburst;				//	burst type
	wire 	awlock;						//	lock type - additional info about transfer
	wire 	[3:0]awcache;				//	memory type
	wire 	[2:0]awprot;				//	protection type
	wire 	[3:0]awqos;					//	quality of service
	wire 	[3:0] awregion;				//	region identifier
	wire 	awuser;						//	user defined signal
	wire 	awvalid;					//	write address valid
	wire 	awready;					//	write address ready 

	// Write data channel:
	wire 	[ID_WIDTH-1:0]wid;			//	write id
	wire 	[DATA_WIDTH-1:0]wdata;		//	write data
	wire 	[STRB_WIDTH-1:0]wstrb;		//	write strobe - every byte gets one, indicates valid data
	wire 	wlast;						//	write last
	wire 	wuser;						//	user defined signal
	wire 	wvalid;						//	write valid
	wire 	wready;						//	write ready 

	// Write response channel:
	wire 	[ID_WIDTH-1:0]bid;			//	response id
	wire 	[1:0]bresp;					//	write response
	wire 	buser;						//	user defined signal
	wire 	bvalid;						//	write response valid
	wire 	bready;						//	response ready

	// Read address channel:
	wire 	[ID_WIDTH-1:0]arid;			//	read address id
	wire 	[ADDR_WIDTH-1:0]araddr;		// 	read addres
	wire 	[7:0]arlen;					//	burst length - num of transfers
	wire 	[2:0]arsize;				//	burst size - size of each tran
	wire 	[1:0]arburst;				//	burst type
	wire 	arlock;						//	lock type - additional info ab
	wire 	[3:0]arcache;				//	memory type
	wire 	[2:0]arprot;				//	protection type
	wire 	[3:0]arqos;					//	quality of service
	wire 	[3:0]arregion;				//	region identifier
	wire 	aruser;						//	user defined signal
	wire 	arvalid;					//	read address valid
	wire 	arready;					// 	read address ready 

	// Read data channel:
	wire 	[ID_WIDTH-1:0]rid;			//	read id
	wire 	[DATA_WIDTH-1:0]rdata;		//	read data
	wire 	[1:0]rresp;					//	read response
	wire 	rlast;						//	read last
	wire 	ruser;						//	user defined signal
	wire 	rvalid;						//	read valid
	wire 	rready;						//	read ready 

// FUNCTIONS & TASKS ============================  //
// ============================================== //
	task delay(int cycles);
		`uvm_info("IF", "Delay . . . ", UVM_DEBUG)
		repeat(cycles) @(posedge clk);
	endtask : delay

// CLOCKING BLOCKS ==============================  //
// ============================================== //
	clocking mstr_cb @(posedge clk);
		default input #1step output `TDRIVE;
		input awready, wready, bid, bresp, buser, bvalid, arready, rid, rdata, rresp, rlast, ruser, rvalid;
		output  
		awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awregion, awuser, awvalid,
		wid, wdata, wstrb, wlast, wuser, wvalid, bready, arid, araddr, arlen, arsize, arburst, arlock, 
		arcache, arprot, arqos, arregion, aruser, arvalid, rready;
	endclocking
	
	clocking slv_cb @(posedge clk);
		default input #1step output `TDRIVE;
		input   
		awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awregion, awuser, awvalid,
		wid, wdata, wstrb, wlast, wuser, wvalid, bready, arid, araddr, arlen, arsize, arburst, arlock, 
		arcache, arprot, arqos, arregion, aruser, arvalid, rready;
		output awready, wready, bid, bresp, buser, bvalid, arready, rid, rdata, rresp, rlast, ruser, rvalid;
	endclocking
	
	clocking mon_cb @(posedge clk);
		default input #1step;
		input 
		awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awregion, awuser, awvalid,
		wid, wdata, wstrb, wlast, wuser, wvalid, bready, arid, araddr, arlen, arsize, arburst, arlock, arcache,
		arprot, arqos, arregion, aruser, arvalid, rready, awready, wready, bid, bresp, buser, bvalid, arready, 
		rid, rdata, rresp, rlast, ruser, rvalid;
	endclocking

// PROPERTIES & ASSERTIONS ======================  //
// ============================================== //
	property prop_max_wr_range;
		@(posedge clk) (8*(2**awsize)*(awlen+1) == 4096);
	endproperty

	property prop_max_rd_range;
		@(posedge clk) (8*(2**arsize)*(arlen+1) == 4096);
	endproperty

	//	legal values for len based on burst:
	property prop_legal_awlen;
		@(posedge clk) $rose(awvalid) |->
		((awburst == FIXED) && awlen inside {[0:15]}) ||
		((awburst == INCR)  && awlen inside {[0:256]})||
		((awburst == WRAP)  && awlen inside {1, 3, 7, 15}); 
	endproperty

	property prop_legal_arlen;
		@(posedge clk) $rose(arvalid) |->
		((arburst == FIXED) && arlen inside {[0:15]}) ||		
		((arburst == INCR)  && arlen inside {[0:256]})||
		((arburst == WRAP)  && arlen inside {1, 3, 7, 15}); 
	endproperty

	//	reset toggle:
	property prop_reset_toggle;
		@(posedge clk) !rst_n |-> ##[1:$] $rose(rst_n);
	endproperty

	//	reset activate functionality:
	property prop_reset_low;
		@(negedge rst_n) 1'b1 |=> @(posedge clk) (awvalid == 1'b0 && 
												  wvalid  == 1'b0 &&
												  bvalid  == 1'b0 &&
												  arvalid == 1'b0 &&
												  rvalid  == 1'b0);
	endproperty

	//	earliest point of signals to be raised is one clock cycle after deassertion of reset:
	property prop_reset_high;
		@(posedge clk) rst_n |=>  @(posedge clk) (awvalid == 1'b1 || 
								   				  wvalid  == 1'b1 ||
								   				  bvalid  == 1'b1 ||
								   				  arvalid == 1'b1 ||
								   				  rvalid  == 1'b1);
	endproperty

	//	checks for response delay of slave module for write and read requests:
	property prop_bvalid_delay;
		@(posedge clk) disable iff (!rst_n) ($fell(wlast) && $fell(wvalid)) |-> ##[1:MAX_WRITE_DELAY] $rose(bvalid); 
	endproperty

	property prop_rvalid_delay;
		@(posedge clk) disable iff (!rst_n) $fell(arvalid) |-> ##[1:MAX_READ_DELAY] $rose(rvalid); 
	endproperty

	//	bvalid signal can be raised only after wvalid, wready and wlast were asserted:
	property prop_bvalid_assert;
		@(posedge clk) disable iff (!rst_n) ($rose(wlast) && (wready == 1'b1) && (wvalid == 1'b1)) |=> 
											strong(($fell(wlast) && $fell(wvalid)) ##[0:$] $rose(bvalid));
	endproperty

	//	rvalid signal can be raised only after arvalid and arready were asserted:
	property prop_rvalid_assert;
		@(posedge clk) disable iff (!rst_n) ($rose(arvalid) && (arready == 1'b1)) |=> 
											strong($fell(arvalid) ##[0:$] $rose(rvalid));
	endproperty

	//	last signals are raised one clock cycle before valid goes low:
	property prop_wlast_func;
		@(posedge clk) disable iff (!rst_n) $fell(wvalid) |-> ($past(wlast) == 1'b1);
	endproperty

	property prop_rlast_func;
		@(posedge clk) disable iff (!rst_n) $fell(rvalid) |-> ($past(rlast) == 1'b1);
	endproperty

	//	valid signals must remain high one at least one clock cycle after assertion of ready:
	property prop_awvalid_deassert;
		@(posedge clk) disable iff (!rst_n) $fell(awvalid) |-> $past(awready, 1);
	endproperty

	property prop_wvalid_deassert;
		@(posedge clk) disable iff (!rst_n) $fell(wvalid) |-> $past(wready, 1);
	endproperty

	property prop_bvalid_deassert;
		@(posedge clk) disable iff (!rst_n) $fell(bvalid) |-> $past(bready, 1);
	endproperty

	property prop_arvalid_deassert;
		@(posedge clk) disable iff (!rst_n) $fell(arvalid) |-> $past(arready, 1);
	endproperty

	property prop_rvalid_deassert;
		@(posedge clk) disable iff (!rst_n) $fell(rvalid) |-> $past(rready, 1);
	endproperty

	//	wvalid signal remain stable throughout burst (until last wsignal):
	property prop_wvalid_stable;
		@(posedge clk) disable iff (!rst_n) $rose(wvalid) |-> strong(wvalid[*1:$] ##0 wlast);
	endproperty

	//	channel signals are stable upon raise of valid, and remain until transfer occurs:
	//	write address channel:
	property prop_wa_stable;
		@(posedge clk) disable iff (!rst_n) $rose(awvalid) |=> ($stable(awid) 	  &&
																$stable(awaddr)   &&
																$stable(awlen)	  &&
																$stable(awsize)	  &&
																$stable(awburst)  &&
																$stable(awlock)	  &&
																$stable(awcache)  &&
																$stable(awprot)	  &&
																$stable(awqos)	  &&
																$stable(awregion) &&
																$stable(awuser)) throughout awready[->1];
	endproperty

	//	write data channel:
	property prop_wd_stable;
		@(posedge clk) disable iff (!rst_n) $rose(wvalid) |-> if (!wready)
																##1 ($stable(wid) 	&&
															   		$stable(wdata)	&&
															   		$stable(wstrb)	&&
															   		$stable(wuser)) throughout wready[->1];

	endproperty

	//	write response channel:
	property prop_wr_stable;
		@(posedge clk) disable iff (!rst_n) $rose(bvalid) |=> ($stable(bid) 	&&
															   $stable(bresp)	&&
															   $stable(buser)) throughout bready[->1];
	endproperty

	// read address channel:
	property prop_ra_stable;
		@(posedge clk) disable iff (!rst_n) $rose(arvalid) |=> ($stable(arid)     &&
																$stable(araddr)   &&
																$stable(arlen)	  &&
																$stable(arsize)	  &&
																$stable(arburst)  &&
																$stable(arlock)	  &&
																$stable(arcache)  &&
																$stable(arprot)	  &&
																$stable(arqos)	  &&
																$stable(arregion) &&
																$stable(aruser)) throughout arready[->1];
	endproperty

	//	read data channel:
	property prop_rd_stable;
		@(posedge clk) disable iff (!rst_n) $rose(rvalid) |-> if (!rready)
																##1 ($stable(rid) 	&&
															   		$stable(rdata)	&&
															   		$stable(rresp)	&&
															   		$stable(ruser)) throughout rready[->1];
	endproperty


	cov_reset_toggle: 		cover property(prop_reset_toggle);	
	cov_reset_high: 		cover property(prop_reset_high);
	cov_write_delay:  		cover property(prop_bvalid_delay);
	cov_read_delay:   		cover property(prop_rvalid_delay);
	cov_wlast: 		  		cover property(prop_wlast_func);
	cov_rlast: 		  		cover property(prop_rlast_func);
	cov_awvalid: 	  		cover property(prop_awvalid_deassert);
	cov_wvalid: 	  		cover property(prop_wvalid_deassert);
	cov_bvalid: 	  		cover property(prop_bvalid_deassert);
	cov_arvalid: 	  		cover property(prop_arvalid_deassert);
	cov_rvalid: 	  		cover property(prop_rvalid_deassert);
	cov_max_wr_range:		cover property(prop_max_wr_range);
	cov_max_rd_range:		cover property(prop_max_rd_range);

	check_reset_low: 		assert property(prop_reset_low);
	check_bvalid_assert:	assert property(prop_bvalid_assert);
	check_rvalid_assert:	assert property(prop_rvalid_assert);
	check_wa_stable: 		assert property(prop_wa_stable);
	check_wd_stable: 		assert property(prop_wd_stable);
	check_wr_stable: 		assert property(prop_wr_stable);
	check_rd_stable: 		assert property(prop_rd_stable);
	check_ra_stable: 		assert property(prop_ra_stable);
	check_wvalid_stable: 	assert property(prop_wvalid_stable);
	check_legal_awlen: 		assert property(prop_legal_awlen);
	check_legal_arlen: 		assert property(prop_legal_arlen);

endinterface : axi_if