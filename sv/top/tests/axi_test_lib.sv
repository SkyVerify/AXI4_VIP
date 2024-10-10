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
// File          : axi_test_lib.sv
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// AXI4 test library ;
// axi_base_test 			- base test class for all other tests ; parameterized for number of packets from cmd line
//							  user may config sequence with: addr, size, len, id and data as well as forced addr alignment and narrow transfers.
// axi_connectivity_test	- connectivity test for integration verification purpose
// axi_corner_cases_test	- corner cases test ; generated from corner_cases.txt file
// axi_gen_from_file_test	- generate transactions from file test ; genereated from gen_file.txt by default
// axi_fixed_test			- random fixed burst test ; user can constraint randomization with the parameters stated above
// axi_incr_test			- random incr burst test ; user can constraint randomization with the parameters stated above
// axi_wrap_test			- random wrap burst test ; user can constraint randomization with the parameters stated above
//--------------------------------------------------------------------------------------
package axi_test_lib;
	
	import uvm_pkg::*;
	`include "uvm_macros.svh"

	import axi_utils_pkg::*;
	import axi_agent_pkg::*;
	import axi_seq_lib::*;	
	import env_pkg::*;

//===========================================================================//
	class axi_base_test#(NUM_OF_CMD = 10) extends uvm_test;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
		`uvm_component_param_utils(axi_base_test#(NUM_OF_CMD))

// DATA MEMBERS =================================  //
// ============================================== //
		axi_env env;
		axi_env_config env_cfg;
		axi_agent_config axi_master_agent_cfg;
		axi_agent_config axi_slave_agent_cfg;
		axi_write_read_vseq axi_vseq;
		mem_type_e mem_type;

// CONSTRAINTS ==================================  //
// ============================================== //
		function new (string name = "axi_base_test", uvm_component parent);
			super.new(name, parent);
		endfunction

// MAIN =========================================  //
// ============================================== //
		virtual function void pre_build();
			// Create sequences:
			axi_vseq = axi_write_read_vseq::type_id::create("axi_vseq");
			
			// Create configs:
			env_cfg = axi_env_config::type_id::create("env_cfg");
			axi_master_agent_cfg = axi_agent_config::type_id::create("axi_master_agent_cfg");
			axi_slave_agent_cfg = axi_agent_config::type_id::create("axi_slave_agent_cfg");

			// Create env:
			env = axi_env::type_id::create("env", this);

			// Set config parameters:
			axi_master_agent_cfg.is_active = UVM_ACTIVE;
			axi_slave_agent_cfg.is_active = DUT_EXIST ? UVM_PASSIVE : UVM_ACTIVE;
			axi_master_agent_cfg.is_master = 1'b1;
			axi_slave_agent_cfg.is_master  = 1'b0;
			axi_master_agent_cfg.has_functional_coverage = 1'b1;
			axi_slave_agent_cfg.has_functional_coverage = 1'b1;

			// Set test parameters:
			mem_type = SAM_RAM;	// SAM/RAM by default, only fixed test changes to FIFO
		endfunction : pre_build

		function void build_phase(uvm_phase phase);
			pre_build();
			// Get VIFs from config_db (set in TB) & Update env_cfg:
			if (!uvm_config_db#(virtual axi_if)::get(this, "", "axi_master_if", axi_master_agent_cfg.vif))
				`uvm_fatal("CONFIG_DB", "get() axi_master_if failed!")
			if (!uvm_config_db#(virtual axi_if)::get(this, "", "axi_slave_if", axi_slave_agent_cfg.vif))
				`uvm_fatal("CONFIG_DB", "get() axi_slave_if failed!")

			env_cfg.m_axi_master_agent_config = axi_master_agent_cfg;
			env_cfg.m_axi_slave_agent_config = axi_slave_agent_cfg;

			// Register env_config with config_db:
			uvm_config_db#(axi_env_config)::set(this, "env", "env_cfg", env_cfg);

			// Set mem_type with config_db:
			uvm_config_db#(bit)::set(this, "env.m_scoreboard.scoreboard_mem_model", "mem_type", mem_type);
			if (axi_slave_agent_cfg.is_active == UVM_ACTIVE)
				uvm_config_db#(bit)::set(this, "env.m_axi_slave_agent.m_driver.slave_mem_model", "mem_type", mem_type);
		endfunction : build_phase

		virtual function void connect_phase(uvm_phase phase);
			//	Pass data to sequences:
			axi_vseq.cmd_cnt    = NUM_OF_CMD;
			//	HIGH for custom input, LOW for random:
			axi_vseq.delay_sel  = 1'b0;
			axi_vseq.id_sel 	= 1'b0;
			axi_vseq.data_sel  	= 1'b0;
			axi_vseq.addr_sel 	= 1'b0; 
			axi_vseq.len_sel  	= 1'b0; 
			axi_vseq.size_sel	= 1'b0; 
			//	HIGH to force narrow transfer / aligned address correspondingly:
			axi_vseq.narrow_tr  = 1'b0; 
			axi_vseq.align_en 	= 1'b0; 
		endfunction : connect_phase

		virtual function void end_of_elaboration_phase(uvm_phase phase);
			//	print TB heirarchy
			uvm_top.print_topology();
		endfunction : end_of_elaboration_phase

		task run_phase(uvm_phase phase);
  			phase.raise_objection(this, "Test Started");
  			axi_vseq.mstr_seqr = env.m_axi_master_agent.m_sequencer;
  			if (axi_slave_agent_cfg.is_active == UVM_ACTIVE)
  				axi_vseq.slv_seqr = env.m_axi_slave_agent.m_sequencer;
  			axi_vseq.start(null);
  			phase.drop_objection(this, "Test Finished");
  			phase.phase_done.set_drain_time(this, 200us);
		endtask : run_phase

	endclass : axi_base_test

//===========================================================================//
	class axi_connectivity_test extends axi_base_test;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
		`uvm_component_utils(axi_connectivity_test)

// CONSTRUCTOR ==================================  //
// ============================================== //
		function new (string name = "axi_connectivity_test", uvm_component parent);
			super.new(name, parent);
		endfunction
		
// MAIN =========================================  //
// ============================================== //
		function void connect_phase(uvm_phase phase);
			super.connect_phase(phase);
			// Pass data to sequences:
			axi_vseq.burst_mode 		= 2'b00;
			axi_vseq.delay_sel  		= 1'b1;
			axi_vseq.id_sel 			= 1'b1;
			axi_vseq.data_sel  			= 1'b1;
			axi_vseq.len_sel			= 1'b1;
			axi_vseq.size_sel 			= 1'b1;
			axi_vseq.addr_sel 			= 1'b1;
			axi_vseq.delay 				= MAX_WRITE_DELAY;
			axi_vseq.burst_id 			= 'h1;
			axi_vseq.wr_addr 			= 'h1;
			axi_vseq.burst_len			= 0;
			axi_vseq.beat_size 	 		= $clog2(DATA_WIDTH/8);
		endfunction : connect_phase

		function void build_phase(uvm_phase phase);
			// Override sequencers to relevant type:
			set_type_override_by_type(axi_write_read_vseq::get_type(), axi_onehot_vseq::get_type());
			super.build_phase(phase);
		endfunction : build_phase

	endclass : axi_connectivity_test

//===========================================================================//
	class axi_corner_cases_test extends axi_base_test;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
		`uvm_component_utils(axi_corner_cases_test)

// CONSTRUCTOR ==================================  //
// ============================================== //
		function new (string name = "axi_corner_cases_test", uvm_component parent);
			super.new(name, parent);
		endfunction
		
// MAIN =========================================  //
// ============================================== //
		function void connect_phase(uvm_phase phase);
			super.connect_phase(phase);
			// Pass data to sequences:
			axi_vseq.file_name 			= "corner_cases.txt";
			axi_vseq.id_sel 			= 1'b1;
			axi_vseq.data_sel  			= 1'b1;
			axi_vseq.len_sel			= 1'b1;
			axi_vseq.size_sel 			= 1'b1;
			axi_vseq.addr_sel 			= 1'b1;
		endfunction : connect_phase

		function void build_phase(uvm_phase phase);
			// Override sequencers to relevant type:
			set_type_override_by_type(axi_write_read_vseq::get_type(), axi_gen_from_file_vseq::get_type());
			super.build_phase(phase);
		endfunction : build_phase

	endclass : axi_corner_cases_test

//===========================================================================//
	class axi_gen_from_file_test extends axi_base_test;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
		`uvm_component_utils(axi_gen_from_file_test)

// CONSTRUCTOR ==================================  //
// ============================================== //
		function new (string name = "axi_gen_from_file_test", uvm_component parent);
			super.new(name, parent);
		endfunction
		
// MAIN =========================================  //
// ============================================== //
		function void connect_phase(uvm_phase phase);
			super.connect_phase(phase);
			// Pass data to sequences:
			axi_vseq.file_name 			= "gen_file.txt";
			axi_vseq.id_sel 			= 1'b1;
			axi_vseq.data_sel  			= 1'b1;
			axi_vseq.len_sel			= 1'b1;
			axi_vseq.size_sel 			= 1'b1;
			axi_vseq.addr_sel 			= 1'b1;
		endfunction : connect_phase

		function void build_phase(uvm_phase phase);
			// Override sequencers to relevant type:
			set_type_override_by_type(axi_write_read_vseq::get_type(), axi_gen_from_file_vseq::get_type());
			super.build_phase(phase);
		endfunction : build_phase

	endclass : axi_gen_from_file_test

//===========================================================================//
	class axi_fixed_test extends axi_base_test;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
		`uvm_component_utils(axi_fixed_test)

// CONSTRUCTOR ==================================  //
// ============================================== //
		function new (string name = "axi_fixed_test", uvm_component parent);
			super.new(name, parent);
		endfunction
		
// MAIN =========================================  //
// ============================================== //
		function void pre_build();
			super.pre_build();
			mem_type = FIFO; // model memory as fifo for FIXED burst test
		endfunction
		
		function void connect_phase(uvm_phase phase);
			super.connect_phase(phase);
			// Pass data to sequences:
			axi_vseq.burst_mode 		= 2'b00;
			//axi_vseq.len_sel  			= 1'b1;
			//axi_vseq.size_sel			= 1'b1;
			//axi_vseq.addr_sel 			= 1'b1;
			//axi_vseq.burst_len 			= 1;
			//axi_vseq.beat_size 			= 2;
			//axi_vseq.wr_addr 			= 'h2d;
			//axi_vseq.narrow_tr			= 1'b1;
		endfunction : connect_phase

	endclass : axi_fixed_test

//===========================================================================//
	class axi_incr_test extends axi_base_test;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
		`uvm_component_utils(axi_incr_test)

// CONSTRUCTOR ==================================  //
// ============================================== //
		function new (string name = "axi_incr_test", uvm_component parent);
			super.new(name, parent);
		endfunction
		
// MAIN =========================================  //
// ============================================== //
		function void connect_phase(uvm_phase phase);
			super.connect_phase(phase);
			// Pass data to sequences:
			axi_vseq.burst_mode 		= 2'b01;
			//axi_vseq.len_sel 			= 1'b1;
			//axi_vseq.size_sel 			= 1'b1;
			//axi_vseq.addr_sel 			= 1'b1;
			//axi_vseq.burst_len 			= 1;
			//axi_vseq.beat_size 			= 2;
			//axi_vseq.align_en		    = 1'b1;
			//axi_vseq.wr_addr 			= 'h12;
			//axi_vseq.narrow_tr			= 1'b1;
		endfunction : connect_phase

	endclass : axi_incr_test

//===========================================================================//
	class axi_wrap_test extends axi_base_test;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
		`uvm_component_utils(axi_wrap_test)

// CONSTRUCTOR ==================================  //
// ============================================== //
		function new (string name = "axi_wrap_test", uvm_component parent);
			super.new(name, parent);
		endfunction
		
// MAIN =========================================  //
// ============================================== //
		function void connect_phase(uvm_phase phase);
			super.connect_phase(phase);
			// Pass data to sequences:
			axi_vseq.burst_mode 		= 2'b10;
			//axi_vseq.len_sel			= 1'b1;
			//axi_vseq.size_sel 			= 1'b1;
			//axi_vseq.addr_sel 			= 1'b1;
			//axi_vseq.burst_len 			= 1;
			//axi_vseq.beat_size 			= 0;
			//axi_vseq.wr_addr 			= 'h41;
			//axi_vseq.narrow_tr			= 1'b1;
		endfunction : connect_phase

	endclass : axi_wrap_test

endpackage : axi_test_lib