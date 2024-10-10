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
// File          : axi_memory.svh
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// AXI4 memory class, extended from memory.sv base class. 
// connected via TLM to host (SB or slave driver if exists) and preforms axi write/read
// operations.
// Sends write/read response items back to host.
//--------------------------------------------------------------------------------------
//===========================================================================//
class axi_memory#(int DW=8, int AW=8, int DEPTH=32) extends memory#(DW, AW, DEPTH);
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
	`uvm_component_param_utils(axi_memory#(DW, AW, DEPTH))
	
// DATA MEMBERS =================================  //
// ============================================== //
	//	Host interface
	uvm_nonblocking_put_imp #(axi_seq_item, axi_memory#(DW, AW, DEPTH)) memory_put_imp;	//	TLM import for incoming requests 
	uvm_blocking_get_imp #(axi_seq_item, axi_memory#(DW, AW, DEPTH)) memory_get_imp;	//	TLM import for outgoing responses 

	axi_seq_item wr_q[$];			//	write requests queue
	axi_seq_item rd_q[$];			//	read requests queue
	axi_seq_item resp_items_q[$];	//	response items queue
	//	indication of write/read events for SM trigger:
	bit wr_ev;
	bit rd_ev;
	//	SM signals:
	typedef enum int {STATE_IDLE, STATE_WRITE, STATE_READ} state_t;
	state_t state;
	state_t next_state;
// CONSTRUCTOR ==================================  //
// ============================================== //
	function new (string name = "axi_memory", uvm_component parent);
		super.new(name, parent);
	endfunction

// METHODS ======================================  //
// ============================================== //
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		memory_put_imp = new("memory_tlm_imp", this);
		memory_get_imp = new("memory_get_imp", this);
	endfunction : build_phase

	task run_phase(uvm_phase phase);
		state = STATE_IDLE;
		fork
			//	Thread #1 - write/read state machine:
			forever@(state) begin
				case(state)
					STATE_WRITE : 
					begin
						this.write_axi();
						wr_ev 		= 1'b0;
						next_state 	= rd_ev ? STATE_READ : STATE_IDLE;
					end
					STATE_READ :
					begin
						read_axi();
						rd_ev 		= 1'b0;
						next_state 	= wr_ev ? STATE_READ : STATE_IDLE;
					end
					//	IDLE:
					default : next_state = STATE_IDLE;				
				endcase
				state <= next_state;
			end
		join_none
		//	Thread #2 - requets handler:
		forever@(wr_ev or rd_ev)
			//	prioritize write/read when both arrive at same cycle:
			if (wr_ev && rd_ev)begin
				if (WR_RD_PRI)
					state <= STATE_WRITE;
				else 
					state <= STATE_READ;
			end
			else begin
				if (wr_ev)
				 	state <= STATE_WRITE;
				if (rd_ev)
					state <= STATE_READ;
			end
	endtask : run_phase

	//	Get write/read requests from host ;
	//  write requests 	-> raise wr_ev bit and push to wr_q
	//	read requests 	-> raise rd_ev bit and push to rd_q
	function bit try_put(axi_seq_item item);
		axi_seq_item tmp = axi_seq_item::type_id::create("tmp");
		`uvm_info("AXI_MEMORY", $sformatf("TLM port %0s request received", item.wr_rd_op ? "write" : "read"), UVM_DEBUG)
		tmp.copy(item);
		if (tmp.wr_rd_op)begin
			wr_ev <= 1'b1;
			wr_q.push_back(tmp);
		end
		else begin
			rd_ev <= 1'b1;
			rd_q.push_back(tmp);
		end
		return 1;
	endfunction : try_put

	//	Send write/read responses to host ; block until valid :
	task get(output axi_seq_item item);
		item = axi_seq_item::type_id::create("item");
		wait(resp_items_q.size() > 0);
		item = resp_items_q.pop_front();
		`uvm_info("AXI_MEMORY", $sformatf("memory %0s response sent", item.wr_rd_op ? "write" : "read"), UVM_DEBUG)
	endtask : get

	virtual function bit can_put();
	endfunction : can_put

	//	perform write action to memory model according to request ; sends write response item when done via TLM:
	function void write_axi();
		axi_seq_item wr_item;
		int t_bytes;						//	transfer size
		int incr;							//	addr incr size
		logic [ADDR_WIDTH-1:0]next_addr;	//	next burst beat addr
		logic [ADDR_WIDTH-1:0]inner_addr;	//	inner addr of memory (per memory word)
		int lower_byte_lane;				//	lower bound of bytes out of data bus
		int upper_byte_lane;				//	upper bound of bytes out of data bus
		logic [MEM_WIDTH-1:0] write_data;	//	data to be written to the memory (calculated by byte lanes and memory word)
		int write_bytes;					//	bytes per memory word counter
		longint wrap_boundry;
		longint wrap_condition;

		// calculate parameters in advance:
		axi_seq_item tmp = axi_seq_item::type_id::create("tmp");
		wr_item 		 = wr_q.pop_front();							
		t_bytes 		 = 2**wr_item.size;
		incr 			 = 1<<wr_item.size;
		next_addr 		 = wr_item.addr;
		wrap_boundry 	 = int'(wr_item.addr / ((wr_item.len+1)*(t_bytes)) * ((wr_item.len+1)*t_bytes));
		wrap_condition 	 = wrap_boundry + ((wr_item.len+1)*t_bytes);

		// cycle through burst beats, write to memory: 
		for (int i = 0; i <= wr_item.len; i++)begin
			write_bytes = 'b0;
			write_data  = 0;
			//	lower and upper byte lanes are determined by strobe vector:	
			lower_byte_lane = $clog2(wr_item.strb[i] & -wr_item.strb[i]);
			upper_byte_lane = ($clog2(wr_item.strb[i]) == lower_byte_lane) ? $clog2(wr_item.strb[i]) : $clog2(wr_item.strb[i]) - 1; //	don't sub in case of 1 HIGH bit
			
			//	inner memory address increments per memory word width:
			inner_addr = next_addr;
			for (int byte_lane = lower_byte_lane; byte_lane <= upper_byte_lane; byte_lane++)begin
				write_data[write_bytes*8+:8] = wr_item.data[i][byte_lane*8+:8];
				write_bytes++;
				//	write to memory once memory word size is reached:
				if (write_bytes == MEM_WORD || byte_lane == upper_byte_lane)begin
					write_bytes = 0;

					//	Response logic ; TBD: issue rest of response types
					//	SLVERR when unsupported transfer size attempted OR FIFO overrun:
					tmp.bresp 	= (t_bytes > DATA_WIDTH/8 || this.is_full(inner_addr)) ? SLVERR : 
										   											 	 OKAY;
					if (tmp.bresp == OKAY) this.write(inner_addr, write_data);
					if (wr_item.burst != FIXED) inner_addr++;
				end
			end

			//	address increment logic:
			if (wr_item.burst != FIXED)begin
				next_addr += incr;
				// align after first transfer:
				if (i == 0) next_addr = align_addr(next_addr, t_bytes);
				// address wraps around when reached a certain limit:
				if (wr_item.burst == WRAP && next_addr == wrap_condition)
					next_addr = wrap_boundry;
			end
		end

		`uvm_info("write_axi", print_mem(), UVM_DEBUG)
		//	send response item to host:
		tmp.wr_rd_op = 1'b1;
		resp_items_q.push_back(tmp);
	endfunction : write_axi

	//	perform read action from memory model according request ; sends read response item when done via TLM:
	function void read_axi();
		axi_seq_item rd_item;
		int d_size;
		int t_bytes;							//	transfer size
		int incr;								//	addr incr size
		int wrap_beat;							//	burst beat where wrap of addr is expected (if burst == WRAP)
		int read_beat;							//	the beat of data to be read
		int read_bytes;							//	bytes per memory word coutner
		int byte_lane;							//	the byte lane (out of data bus) where memory read data is inserted
		logic [DATA_WIDTH-1:0]read_data;		//	the data to be returned to host via TLM (calculated by byte lane and memory word)
		logic [MEM_WIDTH-1:0]mem_read_data;		//	returned memory read data
		logic [ADDR_WIDTH-1:0]next_addr;		//	next burst beat addr ; calculated at the beggining according to read_beat
		logic [ADDR_WIDTH-1:0]aligned_addr;		//	aligned addr, according to data bus or transfer size (different in narrow bursts case)
		longint wrap_boundry ;
		longint wrap_condition;
		
		// calculate parameters in advance:
		axi_seq_item tmp = axi_seq_item::type_id::create("tmp");
		rd_item 		 = rd_q.pop_front();
		d_size        	 = DATA_WIDTH/8;
		t_bytes			 = 2**rd_item.size;
		incr 			 = 1<<rd_item.size;
		wrap_boundry 	 = int'(rd_item.addr / ((rd_item.len+1)*(t_bytes)) * ((rd_item.len+1)*t_bytes));
		wrap_condition 	 = wrap_boundry + ((rd_item.len+1)*t_bytes);
		wrap_beat 		 = (wrap_condition - rd_item.addr) / t_bytes;
		read_beat		 = rd_item.data.size();
		read_data 		 = 'b0;
		read_bytes 		 = 0;
	
		//	Initiate next addr according to current beat/transfer:
		//	assign addr for FIXED / incremented addr according to current beat/transfer ; 
		//	INCR - align for non-first beat/transfer ; WRAP - wrap if condition is met:
		next_addr = (rd_item.burst == FIXED) ? rd_item.addr : rd_item.addr + read_beat*incr;
		if (rd_item.burst == INCR && (read_beat != 0)) 
			next_addr = align_addr(next_addr, t_bytes);
		//	If the address reaches wrap_condition, wrap around to boundry ;
		//	If the address is higher (after initiation), set to offset from condition:
		if (rd_item.burst == WRAP)begin
			if (next_addr == wrap_condition)
				next_addr = wrap_boundry;
			if (next_addr > wrap_condition)
				next_addr = wrap_boundry+incr*(read_beat - wrap_beat);
		end
		aligned_addr = align_addr(next_addr, d_size);
		byte_lane 	 = (next_addr - aligned_addr);
	
		for (int j = 0; j < t_bytes; j++)begin
			if (j == d_size - byte_lane) break; // end loop condition for address overflow

			//	Response logic ; TBD: issue rest of response types
			//	SLVERR when unsupported transfer size attempted OR FIFO underrun:
			tmp.rresp = new[1];
			tmp.rresp[0] = (t_bytes > d_size || this.is_empty(next_addr)) ? SLVERR : 
								   				   							OKAY;
			//	AXI spec indicates a burst must be finised even when an error is being indicated ;
			//	each beat will send no data (zeroes), with rresp flag raised indicating where's the problem:
			mem_read_data = (tmp.rresp[0] == OKAY) ? this.read(next_addr) : 0;
			read_data[(byte_lane+j)*8+:8] = mem_read_data[read_bytes*8+:8];
			read_bytes++;

			//	increment read address once memory word size is reached:
			if (read_bytes == MEM_WORD)begin
				read_bytes = 0;
				if (rd_item.burst != FIXED) next_addr++;
			end	
		end

		`uvm_info("read_axi", $sformatf("transfer = %0d > read data = 0x%h", read_beat, read_data), UVM_DEBUG)

		//	send response item to host:
		tmp.wr_rd_op = 1'b0;
		tmp.data = new[1];
		tmp.data[0] = read_data;
		resp_items_q.push_back(tmp);
	endfunction : read_axi

endclass : axi_memory