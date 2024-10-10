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
// File          : axi_coverage_collector.svh
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// AXI4 agent coverage collector class;
// cg_axi_control  	- control covergroup to cover stimulus for write, read, burst types, len and size
// cg_b/rresp_vals 	- response covergroup to cover all response types
// cg_addr_vals 	- addr covergroup to cover wrap condition, corner cases and address ranges (ADDR_RANGE_SPLIT for #of groups)
// cg_*_onehot 		- cover bus connectivity by onehot stimulus
//--------------------------------------------------------------------------------------

// COVERGROUPS ==================================  //
// ============================================== //
covergroup cg_axi_control with function sample(bit wr_rd_op, axi_burst_e burst, logic [7:0]len, logic [2:0]size);

	RW 		: coverpoint wr_rd_op 	{
										bins WRITE = {1'b1};
										bins READ  = {1'b0};
		 						   	}
	BURST	: coverpoint burst    	{ ignore_bins RESERVED = {2'b11}; }
	LEN 	: coverpoint len 	   	{ 
										bins FIXED_LEN = {[0:15]} iff (burst == FIXED); 
										bins WRAP_LEN  = {1, 3, 7, 15} iff (burst == WRAP);
								   	}
	SIZE 	: coverpoint size;

	// TBD - coverpoints for cache, prot, lock, region, qos...
	AXI_CVR : cross RW, BURST, LEN, SIZE;

endgroup : cg_axi_control

covergroup cg_rresp_vals with function sample(logic [1:0]rresp);
	coverpoint rresp   	{
							bins OKAY 	= {2'b00};
							bins EXOKAY = {2'b01};
							bins SLVERR = {2'b10};
							bins DECERR = {2'b11};
						}
endgroup : cg_rresp_vals

covergroup cg_bresp_vals with function sample(axi_resp_e bresp);
	coverpoint bresp   	{
							bins OKAY 	= {2'b00};
							bins EXOKAY = {2'b01};
							bins SLVERR = {2'b10};
							bins DECERR = {2'b11};
	 					}
endgroup : cg_bresp_vals

covergroup cg_addr_vals(int addr_range_split) with function sample(logic [ADDR_WIDTH-1:0]addr, axi_burst_e burst, logic [ADDR_WIDTH-1:0]wrap_boundry);
	coverpoint addr 	{
							bins MIN 							 = {{ADDR_WIDTH{1'b0}}};
							bins MAX 							 = {{ADDR_WIDTH{1'b1}}};
							bins ADDR_GROUPS[ADDR_WIDTH/addr_range_split]  = {[0:ADDR_WIDTH]};
						}
endgroup : cg_addr_vals

//===========================================================================//
class axi_coverage_collector extends uvm_subscriber #(axi_seq_item);
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
	`uvm_component_utils(axi_coverage_collector)

// DATA MEMBERS =================================  //
// ============================================== //
	axi_seq_item item;
	cg_rresp_vals 	cg_rresp_inst;
	cg_bresp_vals 	cg_bresp_inst;
	cg_addr_vals 	cg_addr_inst;
	cg_axi_control	cg_ctrl_inst;
	bit is_master;

	int ADDR_RANGE_SPLIT = 3;	//	control number of range groups for address stimulus coverage
	bit [ID_WIDTH-1:0]m_id_onehots[ID_WIDTH];
	bit [ADDR_WIDTH-1:0]m_addr_onehots[ADDR_WIDTH];
	bit [DATA_WIDTH-1:0]m_data_onehots[DATA_WIDTH];
	bit [STRB_WIDTH-1:0]m_strb_onehots[STRB_WIDTH];


	// CONNECTIVITY COVERGROUPS:
	covergroup cg_id_onehot();
		coverpoint item.id { bins SELECTED_ID[ID_WIDTH] = m_id_onehots; }
	endgroup : cg_id_onehot
	
	covergroup cg_addr_onehot();
		coverpoint item.addr { bins SELECTED_ADDR[ADDR_WIDTH] = m_addr_onehots; }
	endgroup : cg_addr_onehot
	
	covergroup cg_data_onehot with function sample(logic [DATA_WIDTH-1:0]data);
		coverpoint data { bins SELECTED_DATA[DATA_WIDTH] = m_data_onehots; }
	endgroup : cg_data_onehot
	
	covergroup cg_strobe_onehot with function sample(logic [STRB_WIDTH-1:0]strb);
		coverpoint strb { bins SELECTED_STRB[STRB_WIDTH] = m_strb_onehots; }
	endgroup : cg_strobe_onehot

// CONSTRUCTOR ==================================  //
// ============================================== //
	function new(string name = "axi_coverage_collector", uvm_component parent);
		super.new(name, parent);
		if (!uvm_config_db#(bit)::get(this, "", "is_master", is_master))
			`uvm_fatal("CONFIG_DB", "get() is_master failed!")

		//	master covergroups
		if (is_master)begin
			cg_rresp_inst	 = new();
			cg_bresp_inst	 = new();
		end
		//	slave covergroups
		else begin
			cg_addr_inst = new(ADDR_RANGE_SPLIT);
			cg_ctrl_inst = new();
		end
		foreach(m_id_onehots[i]) m_id_onehots[i] = 1'b1 << i;
		cg_id_onehot 	 = new();
		foreach(m_addr_onehots[i]) m_addr_onehots[i] = 1'b1 << i;
		cg_addr_onehot	 = new();
		foreach(m_data_onehots[i]) m_data_onehots[i] = 1'b1 << i;
		cg_data_onehot	 = new();
		foreach(m_strb_onehots[i]) m_strb_onehots[i] = 1'b1 << i;
		cg_strobe_onehot = new();
	endfunction

// METHODS ======================================  //
// ============================================== //
	function void build_phase(uvm_phase phase);
		item = axi_seq_item::type_id::create("item");
	endfunction : build_phase

	virtual function void write(axi_seq_item t);
		item.copy(t);
		`uvm_info(get_type_name(), $sformatf("[%0s_COVERAGE] > %s", is_master ? "MASTER" : "SLAVE", item.convert2string()), UVM_HIGH)
	// onehot & data (WD/RD channels) coverage is sampled on both sides, control & address (WA/RA channels) on slave side, response (WR/RD) on master side
			if (item.channel == WRITE_ADDR || item.channel == READ_ADDR)begin
					cg_addr_onehot.sample();
					if (!is_master)begin
						cg_ctrl_inst.sample(item.wr_rd_op, item.burst, item.len, item.size);
						cg_addr_inst.sample(item.addr, item.burst, item.wrap_boundry);
					end
			end
			if (item.channel == WRITE_DATA || item.channel == READ_DATA)begin
					foreach(item.data[i]) cg_data_onehot.sample(item.data[i]);
					if (item.channel == WRITE_DATA) foreach(item.strb[i]) cg_strobe_onehot.sample(item.strb[i]);
					if (is_master && item.channel == READ_DATA) foreach(item.rresp[i]) cg_rresp_inst.sample(item.rresp[i]);
			end
			if (is_master && item.channel == WRITE_RESP)
				cg_bresp_inst.sample(item.bresp);
		cg_id_onehot.sample();
	endfunction : write

endclass : axi_coverage_collector