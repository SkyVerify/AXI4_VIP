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
// File          : axi_slave_driver.svh
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// AXI4 slave driver class, extended from axi_driver base class. 
// used only in back-to-back case.
//--------------------------------------------------------------------------------------
//===========================================================================//
class axi_slave_driver extends axi_driver;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
	`uvm_component_utils(axi_slave_driver)

// DATA MEMBERS =================================  //
// ============================================== //
	uvm_nonblocking_put_imp #(axi_seq_item, axi_slave_driver) s_driver_tlm_imp;  //	TLM port from master
	//	write/read requests sent via TLM port from master, initiating response:
	axi_seq_item 		 wr_req_items_q[$];			
	axi_seq_item 		 rd_req_items_q[$];	
	//	write/read responses sent via TLM port from memory, finishing response:
	axi_seq_item 		 wr_resp_items_q[$];			
	axi_seq_item 		 rd_resp_items_q[$];				
	axi_memory#(MEM_WIDTH, ADDR_WIDTH, FIFO_DEPTH) mem_model;
	//	memory model interface (put to send requests ; get to recieve respones):
	uvm_nonblocking_put_port #(axi_seq_item) memory_put_port;
	uvm_blocking_get_port #(axi_seq_item) memory_get_port;

// CONSTRUCTOR ==================================  //
// ============================================== //
	function new(string name = "axi_slave_driver", uvm_component parent);
		super.new(name, parent);
	endfunction

// METHODS ======================================  //
// ============================================== //
	virtual function void build_phase(uvm_phase phase);
		s_driver_tlm_imp = new("s_driver_tlm_imp", this); 
		mem_model = axi_memory#(MEM_WIDTH, ADDR_WIDTH, FIFO_DEPTH)::type_id::create("slave_mem_model", this);
		memory_put_port = new("memory_put_port", this);
		memory_get_port = new("memory_get_port", this);
	endfunction : build_phase

	virtual function void connect_phase(uvm_phase phase);
		memory_put_port.connect(mem_model.memory_put_imp);
		memory_get_port.connect(mem_model.memory_get_imp);
	endfunction : connect_phase

	task run_phase(uvm_phase phase);
		fork
			collect_responses();
		join_none
		super.run_phase(phase);
	endtask : run_phase

	//	Get transaction items from master ;
	//  write transcations 	-> update write request queue to indicate write_response task ;
	//	read transactions 	-> update read request queue for read_data task usage:
	virtual function bit try_put(axi_seq_item item);
		axi_seq_item tmp = axi_seq_item::type_id::create("tmp");
		`uvm_info(get_type_name(), $sformatf("TLM port %0s transaction received", item.wr_rd_op ? "write" : "read"), UVM_DEBUG)
		tmp.copy(item);
		if (tmp.wr_rd_op)
			wr_req_items_q.push_back(tmp);
		else 
			rd_req_items_q.push_back(tmp);
		return 1;
	endfunction : try_put

	virtual function bit can_put();
	endfunction : can_put

	//	Collect responses from memory ; sort to write/read queues accordingly:
	task collect_responses();
		axi_seq_item resp;
		forever begin
			memory_get_port.get(resp);
			if (resp.wr_rd_op)
				wr_resp_items_q.push_back(resp);
			else
	 			rd_resp_items_q.push_back(resp);
		end
	endtask : collect_responses

	task write_address();
		super.write_address();
		forever begin
			//	assert ready:
			@(vif.slv_cb);
			vif.slv_cb.awready <= 1'b1;
			//  deassert with valid:
			@(negedge vif.slv_cb.awvalid);
			vif.slv_cb.awready <= 1'b0;
		end
	endtask : write_address
				
	task write_data();
		super.write_data();
		forever begin
			//	assert ready:
			@(vif.slv_cb); 
			vif.slv_cb.wready <= 1'b1;
			//  deassert when write is over:
			@(posedge vif.slv_cb.wlast);
			vif.slv_cb.wready <= 1'b0;
		end
	endtask : write_data
	
	task write_response();
		axi_seq_item item;
		axi_seq_item resp_item;
		super.write_response();
		forever begin
			int pop_idx;
			// 	Response order is not sequential and depends on memory regions speed ; simulate random response:
			// 	randomly select different ID transactions (pop_index) and send response from queue (same ID are in order)
			@(vif.slv_cb iff wr_req_items_q.size() > 0); 
			pop_idx = $urandom_range(0, wr_req_items_q.size()-1);
			item = wr_req_items_q[pop_idx];
			wr_req_items_q.delete(pop_idx);

			@(vif.slv_cb);
			vif.slv_cb.bid 		<= item.id;
			vif.slv_cb.buser 	<= item.user;

			//	write item to memory, wait and collect response:
			mem_model.try_put(item);
			wait(wr_resp_items_q.size() > 0);
			resp_item = wr_resp_items_q.pop_front();
			vif.slv_cb.bresp 	<= resp_item.bresp;

			vif.slv_cb.bvalid 	<= 1'b1;
			//	wait for ready signal from master before deasserting valid:
			@(vif.slv_cb iff vif.slv_cb.bready);
			vif.slv_cb.bvalid 	<= 1'b0;
		end
	endtask : write_response
	
	task read_address();
		super.read_address();
		forever begin
			//	assert ready:
			@(vif.slv_cb); 
			vif.slv_cb.arready	<= 1'b1;
			//  deassert with valid:
			@(negedge vif.slv_cb.arvalid);
			vif.slv_cb.arready 	<= 1'b0;
		end
	endtask : read_address
	
	task read_data();
		int 	pop_idx;	//	random read_data ID to simulate out of order transactions 
		int 	rd_len;		//	random read length to simulate unorder burst beats
		int 	cur_beat;	//	each read item #beats are randomized from cur_beat to item.len
		axi_seq_item id_q[$];
		axi_seq_item item;
		axi_seq_item resp_item;
		super.read_data();

		forever begin
			//	Read response items depend on memory region speed ; 
			//	items are being pushed to rd_req_items_q after arvalid and arready (enabling rvalid to be raised);
			// 	pop_idx used to randomly select one of the RA requests items ; 
			//	each item will be sent for random length of beats, according to rd_len randomization ;
			//	once burst transaction is done (cur_beat == item.len), raise last bit and delete items from queues

			@(vif.slv_cb iff rd_req_items_q.size() > 0);
			pop_idx = $urandom_range(0, rd_req_items_q.size()-1);
			// in case of identical ids, choose the first occurence:
			pop_idx = int'(rd_req_items_q.find_first_index(x) with (x.id == rd_req_items_q[pop_idx].id));
			item = rd_req_items_q[pop_idx];
			//	drive data and assert valid:
			cur_beat = item.data.size();
			//	if there are read requests for numerous IDs, randomize reads beats to simulate out of order read, otherwise send the whole burst:
			id_q 	= rd_req_items_q.unique(x) with (x.id == rd_req_items_q[pop_idx].id);
			rd_len 	= id_q.size() == rd_req_items_q.size() ? item.len : $urandom_range(cur_beat, item.len); 

			@(vif.slv_cb);
			vif.slv_cb.rid   	<= item.id;
			vif.slv_cb.rlast	<= 1'b0;
			vif.slv_cb.ruser 	<= item.user;

			for (int i = cur_beat; i <= rd_len; i++)begin								   	
				// 	prepare data vector ; read from memory, wait and collect response and read data:
				mem_model.try_put(item);
				wait(rd_resp_items_q.size() > 0);
				resp_item 	 = rd_resp_items_q.pop_front();
				item.data 	 = new[item.data.size() + 1](item.data);
				item.data[i] = resp_item.data[0];

				vif.slv_cb.rresp <= resp_item.rresp[0];
				vif.slv_cb.rvalid<= 1'b1;
				vif.slv_cb.rdata <= item.data[i]; 

				//	raise last and remove items from queues when burst is done:
				if (i == item.len)begin
					vif.slv_cb.rlast <= 1'b1;
					rd_req_items_q.delete(pop_idx);
				end
				//	update item:
				else 
					rd_req_items_q[pop_idx] = item;
				//	transfer only when ready is high
				@(vif.slv_cb iff vif.slv_cb.rready);
			end
			vif.slv_cb.rvalid 	<= 1'b0;
			vif.slv_cb.rlast 	<= 1'b0;
		end
	endtask : read_data

endclass : axi_slave_driver