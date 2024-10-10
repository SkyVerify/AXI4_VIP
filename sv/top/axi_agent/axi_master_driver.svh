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
// File          : axi_master_driver.svh
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// AXI4 master driver class, extended from axi_driver base class
//--------------------------------------------------------------------------------------
//===========================================================================//
class axi_master_driver extends axi_driver;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
	`uvm_component_utils(axi_master_driver)

// DATA MEMBERS =================================  //
// ============================================== //
	uvm_nonblocking_put_port #(axi_seq_item) m_driver_tlm_port; //	TLM port for slave
	//	WA and WD are sequential and therefore a queue:
	axi_seq_item wa_items_q[$];			
	axi_seq_item wd_items_q[$];			
	axi_seq_item ra_items_q[$];

// CONSTRUCTOR ==================================  //
// ============================================== //
	function new(string name = "axi_master_driver", uvm_component parent);
		super.new(name, parent);
	endfunction

// METHODS ======================================  //
// ============================================== //
	virtual function void build_phase(uvm_phase phase);
		if (DUT_EXIST == 0)
			m_driver_tlm_port = new("m_driver_tlm_port", this);
	endfunction : build_phase

	task drive_item(axi_seq_item item);
		axi_seq_item tmp = axi_seq_item::type_id::create("tmp");
		super.drive_item(item);
		`uvm_info(get_type_name(), $sformatf("%0s", item.convert2string()), UVM_DEBUG)
		tmp.copy(item);
		//	write transaction
		if (tmp.wr_rd_op)
			wa_items_q.push_back(tmp);
		//	read transaction
		else 
			ra_items_q.push_back(tmp);
		`uvm_info(get_type_name(), "end drive item", UVM_LOW)
	endtask : drive_item

	task write_address();
		axi_seq_item item;
		axi_seq_item tmp;
		super.write_address();
		forever begin
			// wait for new items before starting WA channel transaction;
			@(vif.mstr_cb iff wa_items_q.size() > 0);
			item = wa_items_q.pop_front();
			tmp = axi_seq_item::type_id::create("tmp");
			tmp.copy(item);

			//	drive data and assert valid:
			vif.mstr_cb.awid 		<= item.id;
			vif.mstr_cb.awaddr 		<= item.addr;
			vif.mstr_cb.awlen 		<= item.len;
			vif.mstr_cb.awsize 		<= item.size;
			vif.mstr_cb.awburst 	<= item.burst;
			vif.mstr_cb.awlock		<= item.lock;	
			vif.mstr_cb.awcache 	<= item.cache;
			vif.mstr_cb.awprot		<= item.prot;	
			vif.mstr_cb.awqos 	 	<= item.qos;
			vif.mstr_cb.awregion	<= item.region;
			vif.mstr_cb.awuser	 	<= item.user;	
			vif.mstr_cb.awvalid 	<= 1'b1;

			//	wait for ready signal from slave before deasserting valid:
			@(vif.mstr_cb iff vif.mstr_cb.awready);
			vif.mstr_cb.awvalid 	<= 1'b0;

			//	start write data transaction once done:
			wd_items_q.push_back(tmp);
		end
	endtask : write_address
				
	task write_data();
		axi_seq_item item;
		super.write_data();
		forever begin
			//	wait for previous WD channel transaction to finish before driving the next item:
			@(vif.mstr_cb iff wd_items_q.size() > 0);
			item = wd_items_q.pop_front();
			//	drive data and assert valid:
			vif.mstr_cb.wid   	<= item.id;		
			vif.mstr_cb.wlast	<= 1'b0;
			vif.mstr_cb.wuser 	<= item.user;
			vif.mstr_cb.wvalid 	<= 1'b1;
			for (int i = 0; i <= item.len; i++)begin
				vif.mstr_cb.wdata <= item.data[i];
				vif.mstr_cb.wstrb <= item.strb[i];
				vif.mstr_cb.wlast <= (i == item.len);
				//	transfer only when ready is high
				@(vif.mstr_cb iff vif.mstr_cb.wready);
			end
			vif.mstr_cb.wvalid 	<= 1'b0;
			vif.mstr_cb.wlast 	<= 1'b0;

			//	send item via TLM port to slave:
			if (DUT_EXIST == 0)
				m_driver_tlm_port.try_put(item);
		end
	endtask : write_data
	
	task write_response();
		super.write_response();
		forever begin
			//	assert ready:
			@(vif.mstr_cb); 
			vif.mstr_cb.bready <= 1'b1;
			//  deassert with valid:
			@(negedge vif.mstr_cb.bvalid);
			vif.mstr_cb.bready <= 1'b0;
		end
	endtask : write_response
	
	task read_address();
		axi_seq_item item;
		super.read_address();
		forever begin
			// wait for new items before starting RA channel transaction:
			@(vif.mstr_cb iff ra_items_q.size() > 0);
			item = ra_items_q.pop_front();

			//	drive data and assert valid:
			vif.mstr_cb.arid 		<= item.id;
			vif.mstr_cb.araddr 		<= item.addr;
			vif.mstr_cb.arlen 		<= item.len;
			vif.mstr_cb.arsize 		<= item.size;
			vif.mstr_cb.arburst 	<= item.burst;
			vif.mstr_cb.arlock		<= item.lock;	
			vif.mstr_cb.arcache 	<= item.cache;
			vif.mstr_cb.arprot		<= item.prot;	
			vif.mstr_cb.arqos 	 	<= item.qos;
			vif.mstr_cb.arregion	<= item.region;
			vif.mstr_cb.aruser	 	<= item.user;	
			@(vif.mstr_cb); 
			vif.mstr_cb.arvalid 	<= 1'b1;
			//	wait for ready signal from slave before deasserting valid:
			@(vif.mstr_cb iff vif.mstr_cb.arready);
			vif.mstr_cb.arvalid 	<= 1'b0;

			//	send item via TLM port to slave:
			if (DUT_EXIST == 0)
				m_driver_tlm_port.try_put(item);
		end
	endtask : read_address
	
	task read_data();
		super.read_data();
		forever begin
			//	assert ready:
			@(vif.mstr_cb); 
			vif.mstr_cb.rready <= 1'b1;
			//  deassert when read is over:
			@(posedge vif.mstr_cb.rlast);
			vif.mstr_cb.rready <= 1'b0;
		end
	endtask : read_data
	
endclass : axi_master_driver