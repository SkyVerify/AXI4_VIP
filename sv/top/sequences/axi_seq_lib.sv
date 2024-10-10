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
// File          : axi_seq_lib.sv
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// AXI4 sequence library ;
// axi_reset_seq			-	reset sequence ; nested sequence in axi_base_seq, activated if is_rst is HIGH.
// axi_base_seq				- 	base sequence ; base for write/read sequences, consist all randomization parameters.
// axi_write_seq 			- 	write sequence ; used to initiate write transaction in master driver. keeps track of generated items.
// axi_read_seq 			- 	read sequence ; used to initiate read transaction in master driver.
// axi_write_read_vseq  	-	write & read virtual sequence; base for gen_from_file and onehot sequences.
//								used to initiate write and read transactions simultaneously.
// axi_onehot_vseq	 		- 	onehot sequence ; generated onehot pattern for connectivity test
// axi_gen_from_file_vseq	-	generate from file sequence ; custom made user sequences for special cases (see README.txt)
//--------------------------------------------------------------------------------------
package axi_seq_lib;

	import uvm_pkg::*;
	`include "uvm_macros.svh"

	import axi_utils_pkg::*;
	import axi_agent_pkg::*;	
	import env_pkg::*;

//===========================================================================//
	class axi_reset_seq extends uvm_sequence #(axi_seq_item);
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
		`uvm_object_utils(axi_reset_seq)

// DATA MEMBERS =================================  //
// ============================================== //
		axi_seq_item req;

// CONSTRUCTOR ==================================  //
// ============================================== //
		function new(string name = "axi_reset_seq");
			super.new(name);
		endfunction

// MAIN =========================================  //
// ============================================== //
		virtual task body();
			req = axi_seq_item::type_id::create("mstr_req");
			start_item(req);
			if (!req.randomize() with {
										rst_n 	== 1'b0;
						})
						`uvm_fatal(get_type_name(), "RST FAIL")
					else
						`uvm_info(get_type_name(), "RST PASS", UVM_LOW)
			finish_item(req);
		endtask : body

	endclass : axi_reset_seq

//===========================================================================//
	class axi_base_seq extends uvm_sequence #(axi_seq_item);
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
		`uvm_object_utils(axi_base_seq)

// DATA MEMBERS =================================  //
// ============================================== //
		axi_seq_item req;
		axi_reset_seq rst_seq;
		bit is_rst 	= 1'b1;

		//	transaction id:
		int 					m_idx 		= 0;
		//	control transaction fields selectors:
		bit 					m_delay_sel = 1'b0;
		bit 					m_id_sel	= 1'b0;
		bit 					m_addr_sel 	= 1'b0;
		bit 					m_data_sel	= 1'b0;
		bit						m_len_sel 	= 1'b0;
		bit 					m_size_sel 	= 1'b0;
		bit 					m_narrow_tr = 1'b0; // force narrow transfer
		bit 					m_align_en 	= 1'b0;	// force aligned address
		//	transaction fields:
		logic [1:0] 			m_burst_mode;
		//	requires HIGH corresponding select:
		int 					m_delay;
		logic [ID_WIDTH-1:0]	m_burst_id;
		logic [ADDR_WIDTH-1:0] 	m_burst_addr;
		logic [DATA_WIDTH-1:0]	m_burst_data[];
		logic [7:0] 			m_burst_len;
		logic [2:0] 			m_beat_size;
		//
		logic 					m_lock;
		logic [3:0]				m_cache;
		logic 					m_prot;
		logic [3:0]				m_qos;
		logic 					m_region;
		logic 					m_user;
// CONSTRUCTOR ==================================  //
// ============================================== //
		function new(string name = "axi_base_seq");
			super.new(name);
		endfunction : new

// MAIN =========================================  //
// ============================================== //
		virtual task pre_body();
			rst_seq = axi_reset_seq::type_id::create("rst_seq");
			req = axi_seq_item::type_id::create("req");
		endtask : pre_body

		virtual task body();
			if (is_rst)
				rst_seq.start(m_sequencer);			
		endtask : body

	endclass : axi_base_seq

//===========================================================================//
	class axi_write_seq extends axi_base_seq;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
		`uvm_object_utils(axi_write_seq)

// DATA MEMBERS =================================  //
// ============================================== //
		axi_seq_item gen_items_q[int][$];

// CONSTRUCTOR ==================================  //
// ============================================== //
		function new(string name = "axi_write_seq");
			super.new(name);
		endfunction

// MAIN =========================================  //
// ============================================== //
		virtual task pre_body();
			super.pre_body();
		endtask : pre_body

		virtual task body();
			super.body();
			start_item(req);
			if (!req.randomize() with {	
										item_idx    	== m_idx;
										rst_n 			== 1'b1;
										wr_rd_op		== 1'b1;
										align_addr_en 	== m_align_en;
										channel 		== WRITE_ADDR;
										burst 			== m_burst_mode;
										m_narrow_tr -> 2**size < DATA_WIDTH / 8;
										m_delay_sel -> delay == m_delay;
										m_id_sel	-> id 	 == m_burst_id;
										m_addr_sel 	-> addr  == m_burst_addr;
										m_data_sel  -> foreach (m_burst_data[i]) data[i]  == m_burst_data[i];
										m_len_sel  	-> len   == m_burst_len;
										m_size_sel 	-> size  == m_beat_size;
									})
				`uvm_fatal(get_type_name(), "Randomization failure!")
			else begin	
				string tmp = $sformatf("\n[GEN %0d] > %0s", m_idx, req.convert2string().substr(60,));
				string data_s;
				string strb_s;
				$swriteh(data_s, "WDATA = 0x%p", req.data);
				$swriteb(strb_s, "WSTRB = %p", req.strb);
				tmp = {tmp, $sformatf("\n\t%s\n\t%s\n\t", data_s, strb_s)};
				`uvm_info(get_type_name(), $sformatf("%0s",tmp), UVM_LOW)
				gen_items_q[req.id].push_back(req);
			end
			finish_item(req);
		endtask : body

	endclass : axi_write_seq

//===========================================================================//
	class axi_read_seq extends axi_base_seq;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
		`uvm_object_utils(axi_read_seq)
		
// CONSTRUCTOR ==================================  //
// ============================================== //
		function new(string name = "axi_read_seq");
			super.new(name);
		endfunction

// MAIN =========================================  //
// ============================================== //
		virtual task body();
			super.body();
			start_item(req);
			if (!req.randomize() with {	
										item_idx    	== m_idx;
										rst_n 			== 1'b1;
										wr_rd_op		== 1'b0;
										align_addr_en 	== m_align_en;
										channel 		== READ_ADDR;
										id 				== m_burst_id;
										user 			== m_user;
										len 			== m_burst_len;
										burst  			== m_burst_mode;
										addr 			== m_burst_addr;
										size 			== m_beat_size;
										lock 			== m_lock;
										prot 			== m_prot;
										qos 			== m_qos;
										region 			== m_region;
									})
				`uvm_fatal(get_type_name(), "Randomization failure!")
			else
				`uvm_info(get_type_name(),$sformatf("\n[GEN %0d] > %0s", m_idx, req.convert2string()), UVM_LOW)
			finish_item(req);
		endtask : body

	endclass : axi_read_seq

//===========================================================================//
	class axi_write_read_vseq extends uvm_sequence;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
		`uvm_object_utils(axi_write_read_vseq)

// DATA MEMBERS =================================  //
// ============================================== //
		uvm_event_pool ev_pool = uvm_event_pool::get_global_pool(); // Used to trace done write response transaction from monitor
		string file_name;	//	Used for read from file generation tests

		axi_seq_item mstr_req;
		axi_seq_item slv_req;
		axi_seq_item read_items_q[$];
		axi_seq_item write_items_q[$];
		uvm_sequencer#(axi_seq_item) mstr_seqr;
		uvm_sequencer#(axi_seq_item) slv_seqr;
		axi_write_seq mstr_wr_seq;
		axi_read_seq  mstr_rd_seq;

		int 					cmd_cnt;
		int 					delay;

		bit 					delay_sel;
		bit 					id_sel;
		bit 					addr_sel;
		bit 					data_sel;
		bit 					len_sel;
		bit 					size_sel;

		logic [1:0]				burst_mode;
		bit 	  				narrow_tr;
		bit 	   				align_en;

		logic [ID_WIDTH-1:0]	burst_id;
		logic [ADDR_WIDTH-1:0]	wr_addr;
		logic [DATA_WIDTH-1:0]	burst_data[];
		logic [7:0]				burst_len;
		logic [2:0]				beat_size;

// CONSTRUCTOR ==================================  //
// ============================================== //
		function new(string name = "axi_write_read_vseq");
			super.new(name);
		endfunction

// MAIN =========================================  //
// ============================================== //
		virtual task pre_body();
			mstr_req = axi_seq_item::type_id::create("mstr_req");
			slv_req = axi_seq_item::type_id::create("slv_req");
			mstr_wr_seq = axi_write_seq::type_id::create("mstr_wr_seq");
			mstr_rd_seq = axi_read_seq::type_id::create("mstr_rd_seq");

			mstr_wr_seq.m_delay_sel 	= delay_sel;
			mstr_wr_seq.m_id_sel 		= id_sel;
			mstr_wr_seq.m_addr_sel 		= addr_sel;
			mstr_wr_seq.m_data_sel 		= data_sel;
			mstr_wr_seq.m_len_sel 		= len_sel;
			mstr_wr_seq.m_size_sel 		= size_sel;
			mstr_wr_seq.m_narrow_tr 	= narrow_tr;
			mstr_wr_seq.m_align_en     	= align_en;

			set_write_fields();
			mstr_wr_seq.m_burst_mode 	= burst_mode;
		endtask : pre_body

		//	set write sequence fields for sequence item randomization according to test:
		virtual function void set_write_fields();
			repeat(cmd_cnt)begin
				axi_seq_item gen_req = axi_seq_item::type_id::create("gen_req");
				if (delay_sel)  gen_req.delay   = delay;
				if (id_sel)		gen_req.id 		= burst_id;
				if (addr_sel)	gen_req.addr 	= wr_addr;
				if (data_sel)	foreach (burst_data[i]) gen_req.data[i] = burst_data[i];
				if (len_sel)	gen_req.len 	= burst_len;
				if (size_sel)	gen_req.size 	= beat_size;
				write_items_q.push_back(gen_req);
			end
		endfunction : set_write_fields
		
		//	get write sequence fields for sequence item randomization according to what was set in set_write_fields method:
		virtual function void get_write_fields();
			axi_seq_item gen_req = axi_seq_item::type_id::create("gen_req");
			gen_req = write_items_q.pop_front();
			mstr_wr_seq.m_delay 		= gen_req.delay;
			mstr_wr_seq.m_burst_id 		= gen_req.id;
			mstr_wr_seq.m_burst_addr 	= gen_req.addr;
			mstr_wr_seq.m_burst_data	= new[gen_req.data.size()];
			foreach (gen_req.data[i]) mstr_wr_seq.m_burst_data[i] = gen_req.data[i];
			mstr_wr_seq.m_burst_len 	= gen_req.len;
			mstr_wr_seq.m_beat_size 	= gen_req.size;
		endfunction : get_write_fields

		//	get read sequence fields for sequence item randomization according to generated write items:
		virtual function void get_read_fields(axi_seq_item wr_item);
			mstr_rd_seq.m_burst_id		= wr_item.id; 
			mstr_rd_seq.m_burst_addr	= wr_item.addr;
			mstr_rd_seq.m_burst_len		= wr_item.len;
			mstr_rd_seq.m_beat_size		= wr_item.size;
			mstr_rd_seq.m_burst_mode 	= wr_item.burst;
			mstr_rd_seq.m_lock			= wr_item.lock;
			mstr_rd_seq.m_cache			= wr_item.cache;	
			mstr_rd_seq.m_prot			= wr_item.prot;
			mstr_rd_seq.m_qos			= wr_item.qos;
			mstr_rd_seq.m_region		= wr_item.region;
			mstr_rd_seq.m_user			= wr_item.user;
		endfunction : get_read_fields

// MAIN =========================================  //
// ============================================== //
		virtual task body();
			uvm_event wresp_done_ev = ev_pool.get("wresp_done_ev"); 

			fork
				//	Thread #1 : Write transaction:
				begin
					for (int wr_cmd = 0; wr_cmd < cmd_cnt; wr_cmd++)begin
						mstr_wr_seq.is_rst = (wr_cmd == 0);
					//	Get write fields (if any) for master write sequence:
						if (write_items_q.size() > 0)
							this.get_write_fields();
					//	Start write transaction:
						mstr_wr_seq.m_idx = wr_cmd;
						mstr_wr_seq.start(mstr_seqr);
					end
				end
				//	Thread #2: B channel transaction is over (a write response event was triggered) ;
				//			   Collect items to prepare read transaction queue:
				begin
					for (int i = 0; i < cmd_cnt; i++)begin
						wresp_done_ev.wait_trigger();
    					$cast(slv_req, wresp_done_ev.get_trigger_data()); 
    					read_items_q.push_back(mstr_wr_seq.gen_items_q[slv_req.id].pop_front());
						wresp_done_ev.reset();
					end
				end
				//	Thread #3: Read transaction:
				begin
					for (int rd_cmd = 0; rd_cmd < cmd_cnt; rd_cmd++)begin
						//	wait for write response before initiating read transaction:
						wait(read_items_q.size() > 0);
						//	get read fields for master read sequence:
						this.get_read_fields(read_items_q.pop_front());
						mstr_rd_seq.m_idx			= rd_cmd;
						mstr_rd_seq.m_align_en 		= 1'b0;
						mstr_rd_seq.is_rst 			= 1'b0;
						//	Start read transaction:
						mstr_rd_seq.start(mstr_seqr);
					end
				end
			join
		endtask : body

	endclass : axi_write_read_vseq

//===========================================================================//
	class axi_onehot_vseq extends axi_write_read_vseq;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
		`uvm_object_utils(axi_onehot_vseq)

// CONSTRUCTOR ==================================  //
// ============================================== //
		function new(string name = "axi_onehot_vseq");
			super.new(name);
		endfunction

// MAIN =========================================  //
// ============================================== //

		//	override axi_write_read_vseq method to generate onehot pattern for relevant fields:
		function void set_write_fields();
			axi_seq_item gen_req;
			let max(a, b, c) = (a >= b && a >= c) ? a :
							   (a >= b && a < c) ? c :
							   (a < b && b >= c) ? b : 
							   c;

			cmd_cnt = max(DATA_WIDTH, ADDR_WIDTH, ID_WIDTH);
			for (int i = 0; i < cmd_cnt; i++)begin
				gen_req = axi_seq_item::type_id::create("gen_req");
				gen_req.delay 	= delay;
				gen_req.len 	= burst_len;
				gen_req.size 	= beat_size;
				gen_req.id 		= 1'b1 << i;
				gen_req.addr 	= 1'b1 << i;
				gen_req.data 	= new[1];
				gen_req.data[0] = 1'b1 << i;
				write_items_q.push_back(gen_req);
			end
		endfunction : set_write_fields

	endclass : axi_onehot_vseq

//===========================================================================//
	class axi_gen_from_file_vseq extends axi_write_read_vseq;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
		`uvm_object_utils(axi_gen_from_file_vseq)

// CONSTRUCTOR ==================================  //
// ============================================== //
		function new(string name = "axi_gen_from_file_vseq");
			super.new(name);
		endfunction

// MAIN =========================================  //
// ============================================== //

		//	override axi_write_read_vseq method to generate fields from user defined file (passed from test):
		function void set_write_fields();
			axi_seq_item gen_req;
			string line;
			int fields;
			string tmp;
			string title = "\n===============\nExtracted fields\n===============\n";

			int fd = $fopen($sformatf("../top/sequences/%0s", file_name), "r");
			if (fd)
				`uvm_info(get_type_name(), $sformatf("File %0s was opened successfully",file_name), UVM_DEBUG)
			else begin
				`uvm_fatal(get_type_name(), $sformatf("File %0s was not opened successfully", file_name))
				return;
			end

			while (!$feof(fd)) begin
				$fgets(line, fd);
				`uvm_info(get_type_name(), $sformatf("line = %0s", line), UVM_DEBUG)
				if (line == "") continue;
	 			fields =$sscanf(line, "%b\t%d\t%d\t%h\t%h\t%s", 
	 							burst_mode, burst_len, beat_size, burst_id, wr_addr, tmp);
	 			if (fields == 6)begin
	 				gen_req = axi_seq_item::type_id::create("gen_req");
	 				gen_req.len 	= burst_len;
					gen_req.size 	= beat_size;
					gen_req.id 		= burst_id; 
					gen_req.addr 	= wr_addr;
	 				gen_req.data 	= new[gen_req.len+1];
	 				parse_data(tmp, gen_req);
	 				$swriteh(tmp, "%p", gen_req.data);
	 				`uvm_info(get_type_name(), $sformatf("%0s\tBURST = %s\n\tLEN = %0d\n\tSIZE = %0d\n\tID = 0x%0h\n\tADDR = 0x%0h\n\tDATA = %s",
	 													 title, axi_burst_e'(burst_mode), gen_req.len, gen_req.size, gen_req.id, gen_req.addr, tmp), UVM_DEBUG);
	 			end
	 			else
	 				`uvm_error(get_type_name(), "Extract fields from file failure!")
				write_items_q.push_back(gen_req);
			end
			$fclose(fd);
			cmd_cnt = write_items_q.size();
		endfunction : set_write_fields

		//	data parser method ; create dynamic array of data vectors from string:
		function void parse_data(ref string raw_data, axi_seq_item item);
			string beat;
			int beat_size = (2**(item.size) * 2);
			`uvm_info("parse_data", $sformatf("parsing %0s", raw_data), UVM_DEBUG)
			//	iterate over data segments and store in gen_req.data ; break when done:
			for (int i = 0; i <= item.len; i++)begin
				beat = raw_data.substr(0, beat_size - 1);
				if (beat == "") break;
				`uvm_info("parse_data", $sformatf("[0x%0s]", beat), UVM_DEBUG)
				item.data[i] = beat.atohex();
				raw_data = raw_data.substr(beat.len() + 1, raw_data.len() - 1);
			end
		endfunction : parse_data

	endclass : axi_gen_from_file_vseq

 endpackage : axi_seq_lib