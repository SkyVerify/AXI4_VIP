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
// File          : axi_scoreboard.svh
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// AXI4 scoreboard ; consists phantom reference model (axi_memory) connected via TLM ports
//--------------------------------------------------------------------------------------
//===========================================================================//
class axi_scoreboard extends uvm_scoreboard;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
	`uvm_component_utils(axi_scoreboard)

// CONSTRUCTOR ==================================  //
// ============================================== //
	function new(string name = "axi_scoreboard", uvm_component parent = null);
			super.new(name, parent);
	endfunction

// ANALYSIS PORTS ===============================  //
// ============================================== //
	`uvm_analysis_imp_decl(_axi_mstr)
	`uvm_analysis_imp_decl(_axi_slv)
	uvm_analysis_imp_axi_mstr #(axi_seq_item, axi_scoreboard) axi_master_imp;
	uvm_analysis_imp_axi_slv #(axi_seq_item, axi_scoreboard) axi_slave_imp;

// DATA MEMBERS =================================  //
// ============================================== //
	axi_env_config env_cfg;

	axi_memory#(MEM_WIDTH, ADDR_WIDTH, FIFO_DEPTH) mem_model;
	//	memory model interface (put to send requests ; get to recieve respones):
	uvm_nonblocking_put_port #(axi_seq_item) memory_put_port;
	uvm_blocking_get_port #(axi_seq_item) memory_get_port;

	axi_seq_item wr_bresp_pkt_q[$];			//	sent write resp queue, triggers write_axi_memory task
	axi_seq_item slv_rresp_pkt_q[$];		//	sent read resp queue, triggers prepare_expected task
	axi_seq_item mstr_rresp_pkt_q[$];		//	arriving read resp queue, triggers collect_rdata task
	axi_seq_item comp_ready_q[$];			//	
	//	response item (from memory) queues:
	axi_seq_item wr_resp_items_q[$];	
	axi_seq_item rd_resp_items_q[$];
	//	key = item.id ; queue of axi_seq_item to keep in order transactions:
	axi_seq_item wr_req_pkt_q[int][$];		//	write addr queue, used in write_axi_memory to update memory model
	axi_seq_item wr_data_pkt_q[int][$];		//	write data queue, used in write_axi_memory to update memory model
	axi_seq_item rd_req_pkt_q[int][$];		//	read addr queue, used in prepare_expected and collect_rdata methods for control
	axi_seq_item exp_rd_pkt_q[int][$];		//	expected resp data queue, assigned in prepare_expected method by RA data
	axi_seq_item act_rd_pkt_q[int][$];		//	actual read data, assigned in collect_rdata

	int 		 comprasions = 0;
	int 		 exp_comprasions = 0;
// CHECKERS =====================================  //
// ============================================== //
	extern virtual task collect_responses();
	extern virtual task write_axi_memory(axi_seq_item t);
	extern virtual task prepare_expected(axi_seq_item t);
	extern virtual task collect_rdata(axi_seq_item t);
	extern virtual task check_axi(axi_seq_item t);

// METHODS ======================================  //
// ============================================== //
	function void build_phase(uvm_phase phase);
		axi_master_imp	= new("axi_master_imp", this);
		axi_slave_imp 	= new("axi_slave_imp", this);

		mem_model = axi_memory#(MEM_WIDTH, ADDR_WIDTH, FIFO_DEPTH)::type_id::create("scoreboard_mem_model", this);
		memory_put_port = new("memory_put_port", this);
		memory_get_port = new("memory_get_port", this);
	endfunction : build_phase

	function void connect_phase(uvm_phase phase);
		memory_put_port.connect(mem_model.memory_put_imp);
		memory_get_port.connect(mem_model.memory_get_imp);
	endfunction : connect_phase

	//	prepare expected data when sending data to slave;
	//	reorder and compare read data sent from slave when recieving:
	function void write_axi_mstr(axi_seq_item t);
		axi_seq_item tmp_axi_mstr = axi_seq_item::type_id::create("tmp_axi_mstr");
		tmp_axi_mstr.copy(t);
		`uvm_info(get_type_name(), $sformatf("[MASTER_SB] > %s", tmp_axi_mstr.convert2string()), UVM_LOW)
		case (tmp_axi_mstr.channel)
			WRITE_ADDR : wr_req_pkt_q[tmp_axi_mstr.id].push_back(tmp_axi_mstr);
			WRITE_DATA :
				begin
					wr_data_pkt_q[tmp_axi_mstr.id].push_back(tmp_axi_mstr);
					//	check for sequential WA->WD order, issue an error if false:
					if (tmp_axi_mstr.id != wr_req_pkt_q[tmp_axi_mstr.id][wr_data_pkt_q[tmp_axi_mstr.id].size()-1].id)
						`uvm_error("CHECKER", $sformatf("OUT OF ORDER WRITE_ADDR -> WRITE_DATA transactions! WA_ID = 0x%h ; WD_ID = 0x%h",
														wr_req_pkt_q[tmp_axi_mstr.id][wr_data_pkt_q[tmp_axi_mstr.id].size()-1].id, tmp_axi_mstr.id))
				end	
			READ_ADDR  :
				begin
					rd_req_pkt_q[tmp_axi_mstr.id].push_back(tmp_axi_mstr);
					exp_comprasions++;
				end
			READ_DATA : mstr_rresp_pkt_q.push_back(tmp_axi_mstr);
		endcase
	endfunction : write_axi_mstr

	//	write to memory when sending write response to master according to write request queue ;
	//	issue warning if 4Kb boundry was crossed ;
	//	prepare expected read data when sending read response to master:
	function void write_axi_slv(axi_seq_item t);
		axi_seq_item tmp_axi_slv = axi_seq_item::type_id::create("tmp_axi_slv");
		tmp_axi_slv.copy(t);
		`uvm_info(get_type_name(), $sformatf("[SLAVE_SB] > %s", tmp_axi_slv.convert2string()), UVM_LOW)
		case (tmp_axi_slv.channel)
			WRITE_ADDR : 
				begin
					if (8*(2**tmp_axi_slv.size)*(tmp_axi_slv.len+1) > 4096)
						`uvm_warning(get_type_name(), "Burst 4Kb was exceeded! behaviour may be unexpected")
				end
			WRITE_RESP : wr_bresp_pkt_q.push_back(tmp_axi_slv);	
			READ_ADDR  : 
				begin
					if (8*(2**tmp_axi_slv.size)*(tmp_axi_slv.len+1) > 4096)
						`uvm_warning(get_type_name(), "Burst 4Kb was exceeded! behaviour may be unexpected")
				end
			READ_DATA  : slv_rresp_pkt_q.push_back(tmp_axi_slv);
		endcase
	endfunction : write_axi_slv

	virtual task run_phase(uvm_phase phase);
	//	Background 'listner' to memory interface, collects responses when appear:
		fork
			collect_responses();
		join_none
	//	4 Threads, each initiating a task:
		forever begin
			fork
				begin
					wait(wr_bresp_pkt_q.size() > 0);
					write_axi_memory(wr_bresp_pkt_q.pop_front());
				end
				begin
					wait(slv_rresp_pkt_q.size() > 0);
					prepare_expected(slv_rresp_pkt_q.pop_front());
				end
				begin
					wait(mstr_rresp_pkt_q.size() > 0);
					collect_rdata(mstr_rresp_pkt_q.pop_front());
				end
				begin
					wait(comp_ready_q.size() > 0);
					check_axi(comp_ready_q.pop_front());
				end
			join_any
		end
	endtask : run_phase

	function void check_phase(uvm_phase phase);
		foreach (wr_req_pkt_q[i]) 
			if (wr_req_pkt_q[i].size() > 0) `uvm_error(get_type_name(), $sformatf("%0d AXI WRITE_ADDRESS ITEMS LEFT FOR ID = 0x%0h!", wr_req_pkt_q[i].size(), i))
		foreach (wr_data_pkt_q[i]) 
			if (wr_data_pkt_q[i].size() > 0) `uvm_error(get_type_name(), $sformatf("%0d AXI WRITE_DATA ITEMS LEFT FOR ID = 0x%0h!", wr_data_pkt_q[i].size(), i))
		foreach (rd_req_pkt_q[i]) 
			if (rd_req_pkt_q[i].size() > 0) `uvm_error(get_type_name(), $sformatf("%0d AXI READ_ADDRESS ITEMS LEFT FOR ID = 0x%0h!", rd_req_pkt_q[i].size(), i))
		if (act_rd_pkt_q.size() > 0) `uvm_error(get_type_name(), $sformatf("%0d AXI READ_DATA ITEMS LEFT!", act_rd_pkt_q.size()))
		if (comp_ready_q.size() > 0) `uvm_error(get_type_name(), $sformatf("%0d COMPRASIONS LEFT!", comp_ready_q.size()))
		if (comprasions != exp_comprasions)
			`uvm_error(get_type_name(), $sformatf("UNMATCHING COMPRASIONS! EXPECTED = %0d ; ACTUAL = %0d", exp_comprasions, comprasions))			
	endfunction : check_phase

	function void report_phase(uvm_phase phase);
		uvm_report_server srvr = uvm_report_server::get_server();
		int err_cnt = srvr.get_severity_count(UVM_ERROR);
		if (err_cnt == 0)
			`uvm_info(get_type_name(), "\nTEST STATUS: PASSED\n", UVM_LOW)
		else
			`uvm_info(get_type_name(), "\nTEST STATUS: FAILED\n", UVM_LOW)
	endfunction : report_phase

endclass : axi_scoreboard

//	Collect responses from memory ; sort to write/read queues accordingly:
task axi_scoreboard::collect_responses();
	axi_seq_item resp;
	forever begin
		memory_get_port.get(resp);
		if (resp.wr_rd_op)
			wr_resp_items_q.push_back(resp);
		else
 			rd_resp_items_q.push_back(resp);
	end
endtask

//	This function writes to memory according to sent WA, WD from master, upon slave response transfer:
task axi_scoreboard::write_axi_memory(axi_seq_item t);
	axi_seq_item wr_req = wr_req_pkt_q[t.id].pop_front();
	axi_seq_item wr_data = wr_data_pkt_q[t.id].pop_front();
	wr_req.data = new[wr_data.data.size()];
	wr_req.strb = new[wr_data.strb.size()];
	foreach(wr_req.data[i])begin
		wr_req.data[i] = wr_data.data[i];
		wr_req.strb[i] = wr_data.strb[i];
	end

	//	Send write request to memory:
	memory_put_port.try_put(wr_req);
	//	Wait for response:
	wait(wr_resp_items_q.size() > 0);
	wr_req.bresp = wr_resp_items_q.pop_front().bresp;
	//	Compare expected response with actual:
	if (t.bresp != wr_req.bresp)
		`uvm_error("CHECKER", $sformatf("UNMATCHING WRITE_RESPONSE! ACTUAL = 0x%0s ; EXPECTED = 0x%0s", t.bresp, wr_req.bresp))
endtask : write_axi_memory

//	This task collects read data upon arrival to master and verifies reorder mechanism on master side:
task axi_scoreboard::collect_rdata(axi_seq_item t);
	axi_seq_item rd_req; 
	axi_seq_item act_rd;

	//	Check whether a RA request with that ID was made ; TRUE - prepare data, FALSE - issue an error:
	if (!rd_req_pkt_q.exists(t.id))
		`uvm_error("CHECKER", $sformatf("Invalid BURST ID = 0x%h ; No READ_ADDR request found!", t.id))
	else begin
		rd_req = act_rd_pkt_q.exists(t.id) ? rd_req_pkt_q[t.id][act_rd_pkt_q[t.id].size()-1] : rd_req_pkt_q[t.id][0];
		`uvm_info(get_type_name(), $sformatf("> REORDER AXI FOR: \n===============\n%0s\n===============",
	 										rd_req.convert2string()), UVM_DEBUG)
	
		//	If entry exsists and there are items in queue, check if the received transaction id is equal to existing item ;
		//	TRUE - add the burst beat transfer to existing item:			
		if (act_rd_pkt_q.exists(t.id) && act_rd_pkt_q[t.id].size() > 0)begin
			act_rd = act_rd_pkt_q[t.id][0];

			if (t.item_idx == act_rd.item_idx)begin				
				act_rd.data = new[act_rd.data.size() + 1](act_rd.data);
				act_rd.data[act_rd.data.size() - 1] = t.data[0];
				act_rd.rresp = new[act_rd.rresp.size() + 1](act_rd.rresp);
				act_rd.rresp[act_rd.rresp.size() - 1] = t.rresp[0];
			end
			//	unexpected higher/lower transaction - issue OOO error:
			else
				`uvm_error("CHECKER", $sformatf("OUT OF ORDER transaction for ID = 0x%0h! EXPECTED = %0d ; ACTUAL = %0d",
				 			t.id, act_rd.item_idx, t.item_idx))
		end
		//	New ID has arrived / new transaction for same ID, issue new entry:
		else 
			act_rd_pkt_q[t.id].push_back(t);

		// if transaction is over, compare items in check function:
		if (act_rd_pkt_q[t.id][0].data.size() == rd_req.len+1)
			comp_ready_q.push_back(act_rd_pkt_q[t.id].pop_front());
	end
endtask : collect_rdata

//	This task prepares expected read data upon transfer from slave (edit read request until done) and verifies reorder mechanism on slave side:
task axi_scoreboard::prepare_expected(axi_seq_item t);
	axi_seq_item axi_exp;
	axi_seq_item axi_resp;

	//	Check whether a RA request with that ID was made ; TRUE - prepare data, FALSE - issue an error:
	if (!rd_req_pkt_q.exists(t.id))
		`uvm_error("CHECKER", $sformatf("Invalid ID = 0x%h ; No READ_ADDR request found!", t.id))
	else begin
		axi_exp = exp_rd_pkt_q.exists(t.id) ? rd_req_pkt_q[t.id][exp_rd_pkt_q[t.id].size()-1] : rd_req_pkt_q[t.id][0];
		`uvm_info(get_type_name(), $sformatf("> PREPARE EXPECTED FOR: \n===============\n%0s\n===============",
	 										axi_exp.convert2string()), UVM_DEBUG)

		//	if the received transaction id is equal to existing item ;
		//	TRUE - add the burst beat transfer to existing item:
		if (t.item_idx == axi_exp.item_idx)begin								
			//	Send read request to memory:
			memory_put_port.try_put(axi_exp);
			//	Wait for response:
			wait(rd_resp_items_q.size() > 0);
			axi_resp = rd_resp_items_q.pop_front();
			//	Update expected:
			axi_exp.rresp = new[axi_exp.rresp.size() + 1](axi_exp.rresp);
			axi_exp.rresp[axi_exp.rresp.size() - 1] = axi_resp.rresp[0];
			//	Compare expected response with actual:
			if (t.rresp[0] != axi_resp.rresp[0])
				`uvm_error("CHECKER", $sformatf("UNMATCHING WRITE_RESPONSE! ACTUAL = 0x%0s ; EXPECTED = 0x%0s", t.rresp[0], axi_resp.rresp[0]))
			axi_exp.data = new[axi_exp.data.size() + 1](axi_exp.data);
			axi_exp.data[axi_exp.data.size() - 1] = axi_resp.data[0];
		end
		//	unexpected higher/lower transaction - issue OOO error:
		else
			`uvm_error("CHECKER", $sformatf("OUT OF ORDER transaction for ID = 0x%0h! EXPECTED = %0d ; ACTUAL = %0d",
			 								t.id, axi_exp.item_idx, t.item_idx))
		
		// if transaction is over, push to expected queue:
		if (axi_exp.data.size() == axi_exp.len+1)begin
			axi_exp.channel = READ_DATA;
			exp_rd_pkt_q[t.id].push_back(axi_exp);
		end
	end
endtask : prepare_expected

task axi_scoreboard::check_axi(axi_seq_item t);
	axi_seq_item axi_exp;
	wait(exp_rd_pkt_q.exists(t.id));
	rd_req_pkt_q[t.id].pop_front();
	axi_exp = exp_rd_pkt_q[t.id].pop_front();
	if (exp_rd_pkt_q[t.id].size() == 0) exp_rd_pkt_q.delete(t.id);
	if (act_rd_pkt_q[t.id].size() == 0) act_rd_pkt_q.delete(t.id);
	// compare:
	if (!t.compare(axi_exp))
		`uvm_error("CHECKER", $sformatf("> COMPARE FAIL!\nEXPECTED%s\n===============\nACTUAL%s\n===============",
		 								axi_exp.convert2string(), t.convert2string()))
	else
		`uvm_info("CHECKER", $sformatf("> COMPARE PASS!\nTRANSACTION%s\n===============\n",
		 								t.convert2string()), UVM_LOW)
	comprasions++;
endtask : check_axi