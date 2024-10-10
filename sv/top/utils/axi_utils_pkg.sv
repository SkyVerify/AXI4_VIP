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
// File          : axi_utils_pkg.sv
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// AXI4 utilities package ; consists parameters, enums, and mutual functions
//--------------------------------------------------------------------------------------
package axi_utils_pkg;

// INCLUDES =====================================  //
// ============================================== //
	import uvm_pkg::*;
	`include "uvm_macros.svh"	
	
	`include "clk_defines.sv"
	`include "memory.sv"
	
// ENV DEFINES ==================================  //
// ============================================== //
	//	TESTBENCH parameters
	parameter DUT_EXIST 		= 0;						//	1 - RTL DUT connection ; 0 - Back-to-back with active slave 
	//	AXI parameters
	parameter DATA_WIDTH 		= 32;
	parameter ADDR_WIDTH 		= 16;
	parameter STRB_WIDTH 		= (DATA_WIDTH / 8);
	parameter ID_WIDTH 	 		= 8;
	//	MEMORY parameters
	parameter MEM_WIDTH  		= 8;						//	width of every cell in the memory (affects write_axi and read_axi functions)
	parameter MEM_WORD 			= (MEM_WIDTH / 8); 			//	bytes per word in memory ; used in write/read_axi to store words in memory according to cell size
	parameter FIFO_DEPTH		= 32;						// 	if the memory is made of fifos, determine depth of each one 
	parameter WR_RD_PRI 		= 1;						//	write/read priority ; 1'b1 = write over read, 1'b0 = read over write	
	//	number of cycles it takes for memory to respond to write/read request ; used in axi_if to verify response timing:
	parameter MAX_WRITE_DELAY 	= 10;
	parameter MAX_READ_DELAY 	= 10;


// ENUMS ========================================  //
// ============================================== //	
	//	axi channel encoding:
	typedef enum int {WRITE_ADDR=0, WRITE_DATA=1, WRITE_RESP=2, READ_ADDR=3, READ_DATA=4} axi_channel_e;
	
	//	memory type encoding:
	typedef enum bit {FIFO = 1'b0, SAM_RAM = 1'b1} mem_type_e;
	
	//	burst types encoding ; page 45-46 in spec
	typedef enum bit[1:0] {FIXED=2'b00, INCR=2'b01, WRAP=2'b10, Reserved=2'b11} axi_burst_e;
	
	//	response encoding ; page 54 in spec
	typedef enum bit[1:0] {OKAY=2'b00, EXOKAY=2'b01, SLVERR=2'b10, DECERR=2'b11} axi_resp_e; 
	
// FUNCTIONS ====================================  //
// ============================================== //	
	function logic [ADDR_WIDTH-1:0] align_addr(logic [ADDR_WIDTH-1:0]addr, int size);
	//	This function recieves an address and alignes, if necassary, by size (representing bytes):
		automatic logic [ADDR_WIDTH-1:0]aligned = addr;
		`uvm_info("align_addr", $sformatf("addr before alignment = 0x%h", aligned), UVM_DEBUG)
		case(size)
			// 16 bit alignment:
			2: aligned[0] = 0;
			// 32 bit alignmnet:
			4: aligned[1:0] = 0;
			// 64 bit alignmnet:
			8: aligned[2:0] = 0;
			// 128 bit alignmnet:
			16: aligned[3:0] = 0;
			// 256 bit alignmnet:
			32: aligned[4:0] = 0;
			// 512 bit alignmnet:
			64: aligned[5:0] = 0;
			// 1024 bit alignmnet:
			128: aligned[6:0] = 0;
			default: `uvm_info("align_addr", "address is already aligned", UVM_DEBUG)
		endcase
		`uvm_info("align_addr", $sformatf("addr after alignment = 0x%h", aligned), UVM_DEBUG)
		return aligned;
	endfunction : align_addr

endpackage : axi_utils_pkg