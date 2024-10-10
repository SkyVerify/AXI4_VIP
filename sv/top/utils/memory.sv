//---------------------------------------------------------------------------------------
// This VIP was created by Yosef Belyatsky @https://github.com/SkyVerify
// see axi4_vip_spec.pdf for additional information and usage. 
//
// Hope this will be useful as a reference, learning/exercise material or part of a bigger project.
// Use with own responsibility and caution! 
// If you integrate this VIP or part of it in your project please note there is no guarantee 
// or warranty of any kind, express or implied, including but not limited to the warranties
// of merchantability, fitness for particular purpose and noninfringement.
//
// For any comments, bugs, issues or questions feel free to contact via yosefbel92@gmail.com
//--------------------------------------------------------------------------------------
// File          : memory.sv
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// Generic memory class, parameterized with data and address width ; 
// supports RAM/SAM or FIFO types.
//--------------------------------------------------------------------------------------
//===========================================================================//
class memory#(int DW=8, int AW=8, int DEPTH=32) extends uvm_component;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
	`uvm_component_param_utils(memory#(DW, AW, DEPTH))
	
// DATA MEMBERS =================================  //
// ============================================== //
//	1'b1 = for sequential/random access memory (each address has data bus of DW width); 1'b0 for fifo (each address has fifo of data buses of DW width):
bit mem_type;

logic [DW-1:0]data;
logic [DW-1:0]entries[longint];
logic [DW-1:0]fifo[longint][$];

// CONSTRUCTOR ==================================  //
// ============================================== //
	function new (string name = "memory", uvm_component parent);
		super.new(name, parent);
	endfunction

// METHODS ======================================  //
// ============================================== //
	virtual function void build_phase(uvm_phase phase);
		// Get config from test:
		if (!uvm_config_db#(bit)::get(this, "", "mem_type", mem_type))
			`uvm_fatal("CONFIG_DB", "get() mem_type failed!")
	endfunction

	function string print_mem();
		string s;
		string tmp;
		s = "\n| ADDR |\t| DATA |\n------------------------\n";
		if (mem_type)begin
			foreach(entries[addr])
				s = {s, $sformatf("[0x%0h]\t\t[ 0x%h ]\n", addr, entries[addr])};
		end
		else begin
			foreach (fifo[addr]) begin	
				$swriteh(tmp, "[0x%0h]\t\t[ 0x%p ]\n", addr, fifo[addr]);
				s = {s, $sformatf("%0s",tmp)};
			end
		end
		return {s, "------------------------\n"};
	endfunction : print_mem 

	function bit is_full(logic [AW-1:0]addr);
	//	This function returns 1'b1 if the FIFO is full for a given address:		
		if (!mem_type)
			return (fifo[addr].size() == DEPTH);
		else
			return 0;	
	endfunction : is_full

	function bit is_empty(logic [AW-1:0]addr);
	//	This function returns 1'b1 if the FIFO is empty for a given address:		
		if (!mem_type)
			return (fifo[addr].size() == 0);
		else
			return 0;	
	endfunction : is_empty

	function void write(logic [AW-1:0]addr, logic [DW-1:0]data);
	//	This function writes the requested data to the requested address:
		`uvm_info("MEMORY", $sformatf("> Write memory[0x%0h] = 0x%h", addr, data), UVM_DEBUG)
		if (mem_type)
			entries[addr] = data;
		else
			if (!this.is_full(addr))
				fifo[addr].push_back(data);
	endfunction : write

	function logic [DW-1:0] read(logic [AW-1:0]addr);
	//	This function check whether the requested read address was written ;
	//	return : data for the requested read address if exists ; 0 otherwise (as if the memory was initiated to 'b0)
		string tmp;
		logic [DW-1:0]read_data;

		if (mem_type)begin
			if (entries.exists(addr))begin
				`uvm_info("MEMORY", $sformatf("> Read memory[0x%0h] = 0x%h", addr, entries[addr]), UVM_DEBUG)
				return entries[addr];
			end
		end
		else begin
			if (fifo.exists(addr) && !this.is_empty(addr))begin
				read_data = fifo[addr].pop_front();
				if (fifo[addr].size() == 0) fifo.delete(addr);
				$swriteh(tmp, "> Read memory[0x%0h] = 0x%p", addr, read_data);
				`uvm_info("MEMORY", $sformatf("%0s", tmp), UVM_DEBUG)
				return read_data;
			end
		end

		`uvm_info("MEMORY", $sformatf("> Entry does not exists for address = 0x%0h", addr), UVM_DEBUG)
		return 0;
	endfunction : read

endclass : memory