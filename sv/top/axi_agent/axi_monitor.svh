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
// File          : axi_monitor.svh 
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// AXI4 mutual monitor class for master and slave
//--------------------------------------------------------------------------------------
//===========================================================================//
class axi_monitor extends uvm_monitor;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
	`uvm_component_utils(axi_monitor)

// DATA MEMBERS =================================  //
// ============================================== //
	uvm_analysis_port #(axi_seq_item) ap; 
	virtual interface axi_if vif;
	uvm_event_pool ev_pool = uvm_event_pool::get_global_pool(); // Used to trigger event in sequence for read transactions
	bit is_master;

	logic [DATA_WIDTH-1:0]wr_data_beat_q[$];
	logic [STRB_WIDTH-1:0]strb_beat_q[$];
	//	transactions counter:
	int wa_item_idx[int][$];
	int wd_item_idx[int][$];
	int wr_item_idx[int][$];
	int ra_item_idx[int][$];
	int rd_item_idx[int][$];

// CONSTRAINTS ==================================  //
// ============================================== //
	function new (string name = "axi_monitor", uvm_component parent);
		super.new(name, parent);
	endfunction

// METHODS ======================================  //
// ============================================== //
	extern task sample_write_address();
	extern task sample_write_data();
	extern task sample_write_response();
	extern task sample_read_address();
	extern task sample_read_data();

	virtual function void build_phase(uvm_phase phase);
		ap = new("monitor_analysis_port", this);
	endfunction : build_phase

	virtual task run_phase(uvm_phase phase);
		int item_cnt = 0;

		forever begin
			fork 
				//	Thread #1 - Write address channel:
				@(vif.mon_cb iff vif.rst_n);
				if (vif.mon_cb.awvalid && vif.mon_cb.awready)begin
					wa_item_idx[vif.mon_cb.awid].push_back(item_cnt);
					wd_item_idx[vif.mon_cb.awid].push_back(item_cnt);
					wr_item_idx[vif.mon_cb.awid].push_back(item_cnt);
					ra_item_idx[vif.mon_cb.awid].push_back(item_cnt);
					rd_item_idx[vif.mon_cb.awid].push_back(item_cnt);
					sample_write_address();
					item_cnt++;
				end
				//	Thread #2 - Write data channel:
				if (vif.mon_cb.wvalid && vif.mon_cb.wready)
					sample_write_data();
				//	Thread #3 - Read address channel:
				if (vif.mon_cb.arvalid && vif.mon_cb.arready)
					sample_read_address();
				//	Thread #4 - Write response channel:
				if (vif.mon_cb.bvalid && vif.mon_cb.bready)
					sample_write_response();
				//	Thread #5 - Read data channel:
				if (vif.mon_cb.rvalid && vif.mon_cb.rready)
					sample_read_data();
			join
		end // forever
	endtask : run_phase

endclass : axi_monitor

task axi_monitor::sample_write_address();
	axi_seq_item item = axi_seq_item::type_id::create("item", this);
	item.channel 	 = WRITE_ADDR;
	item.wr_rd_op  	 = 1'b1;
	item.id 		 = vif.mon_cb.awid;
	item.addr 	 	 = vif.mon_cb.awaddr;
	item.len 		 = vif.mon_cb.awlen;
	item.size 	 	 = vif.mon_cb.awsize;
	item.burst 	 	 = axi_burst_e'(vif.mon_cb.awburst);
	item.lock		 = vif.mon_cb.awlock;	
	item.cache 	 	 = vif.mon_cb.awcache;
	item.prot		 = vif.mon_cb.awprot;	
	item.qos 	 	 = vif.mon_cb.awqos;
	item.region	 	 = vif.mon_cb.awregion;
	item.user	 	 = vif.mon_cb.awuser;
	item.item_idx = wa_item_idx[item.id].pop_front();
	`uvm_info(get_type_name(), $sformatf("[%0s_MON] > %s", is_master ? "MASTER" : "SLAVE", item.convert2string()), UVM_HIGH)
	ap.write(item);
endtask : sample_write_address

task axi_monitor::sample_write_data();
	axi_seq_item item = axi_seq_item::type_id::create("item", this);
	wr_data_beat_q.push_back(vif.mon_cb.wdata); 
	strb_beat_q.push_back(vif.mon_cb.wstrb);
	if(vif.mon_cb.wlast)begin
		item.channel 	 = WRITE_DATA;
		item.wr_rd_op  	 = 1'b1;
		item.id 		 = vif.mon_cb.wid;		
		item.user 		 = vif.mon_cb.wuser;
		item.data 		 = wr_data_beat_q;
		item.strb 		 = strb_beat_q;
		item.item_idx = wd_item_idx[item.id].pop_front();
		`uvm_info(get_type_name(), $sformatf("[%0s_MON] > %s", is_master ? "MASTER" : "SLAVE", item.convert2string()), UVM_HIGH)
		ap.write(item);
		wr_data_beat_q.delete();
		strb_beat_q.delete();
	end
endtask : sample_write_data

task axi_monitor::sample_write_response();
	uvm_event wresp_done_ev = ev_pool.get("wresp_done_ev"); //	B channel done event 
	axi_seq_item item = axi_seq_item::type_id::create("item", this);
	axi_seq_item ev_item = axi_seq_item::type_id::create("ev_item", this);
	item.channel 	= WRITE_RESP;
	item.wr_rd_op  	 = 1'b1;
	item.id 		= vif.mon_cb.bid;		
	item.bresp 		= axi_resp_e'(vif.mon_cb.bresp);
	item.user 		= vif.mon_cb.buser;
	item.item_idx 	= wr_item_idx[item.id].pop_front();
	`uvm_info(get_type_name(), $sformatf("[%0s_MON] > %s", is_master ? "MASTER" : "SLAVE", item.convert2string()), UVM_HIGH)
	//	once B channel is done, trigger an event with the relevant transaction to initiate read sequence:
	if (is_master)begin
		ev_item.copy(item);
		wresp_done_ev.trigger(ev_item);
	end
	ap.write(item);
endtask : sample_write_response

task axi_monitor::sample_read_address();
	axi_seq_item item = axi_seq_item::type_id::create("item", this);
	item.channel 	 = READ_ADDR;
	item.wr_rd_op  	 = 1'b0;
	item.id 		 = vif.mon_cb.arid;
	item.addr 	 	 = vif.mon_cb.araddr;
	item.len 		 = vif.mon_cb.arlen;
	item.size 	 	 = vif.mon_cb.arsize;
	item.burst 	 	 = axi_burst_e'(vif.mon_cb.arburst);
	item.lock		 = vif.mon_cb.arlock;	
	item.cache 	 	 = vif.mon_cb.arcache;
	item.prot		 = vif.mon_cb.arprot;	
	item.qos 	 	 = vif.mon_cb.arqos;
	item.region	 	 = vif.mon_cb.arregion;
	item.user	 	 = vif.mon_cb.aruser;
	item.item_idx = ra_item_idx[item.id].pop_front();
	`uvm_info(get_type_name(), $sformatf("[%0s_MON] > %s", is_master ? "MASTER" : "SLAVE", item.convert2string()), UVM_HIGH)
	ap.write(item);
endtask : sample_read_address

task axi_monitor::sample_read_data();
	axi_seq_item item = axi_seq_item::type_id::create("item", this);
	item.channel 	= READ_DATA;
	item.wr_rd_op  	 = 1'b0;
	item.id 		= vif.mon_cb.rid;		
	item.user 		= vif.mon_cb.ruser;
	item.data 		= new[1];
	item.rresp 		= new[1];
	item.rresp[0] 	= axi_resp_e'(vif.mon_cb.rresp);
	item.data[0] 	= vif.mon_cb.rdata;
	item.item_idx 	= rd_item_idx[item.id][0];
	if (vif.mon_cb.rlast) rd_item_idx[item.id].pop_front();
	`uvm_info(get_type_name(), $sformatf("[%0s_MON] > %s", is_master ? "MASTER" : "SLAVE", item.convert2string()), UVM_HIGH)
	ap.write(item);
endtask : sample_read_data