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
// File          : axi_env.svh
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// AXI4 environment class
//--------------------------------------------------------------------------------------
//===========================================================================//
class axi_env extends uvm_env;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
	`uvm_component_utils(axi_env)

// DATA MEMBERS =================================  //
// ============================================== //
	axi_env_config m_cfg;
	axi_agent m_axi_master_agent;
	axi_agent m_axi_slave_agent;
	axi_scoreboard m_scoreboard;
	UVM_FILE file_h;

// CONSTRUCTOR ==================================  //
// ============================================== //
	function new (string name = "axi_env", uvm_component parent);
		super.new(name, parent);
	endfunction
	
// METHODS ======================================  //
// ============================================== //
	function void start_of_simulation_phase(uvm_phase phase);
      	file_h = $fopen("sim_log.log", "w");
      	uvm_top.set_report_default_file_hier(file_h);
      	uvm_top.set_report_severity_action_hier(UVM_INFO, UVM_DISPLAY + UVM_LOG);
      	uvm_top.set_report_severity_action_hier(UVM_ERROR, UVM_DISPLAY + UVM_LOG);
      	uvm_top.set_report_severity_action_hier(UVM_FATAL, UVM_DISPLAY + UVM_LOG);
	endfunction : start_of_simulation_phase

	function void build_phase(uvm_phase phase);
		// Get config from test:
		if (!uvm_config_db#(axi_env_config)::get(this, "", "env_cfg", m_cfg))
			`uvm_fatal("CONFIG_DB", "get() axi_env_config failed!")

		// Set and create agents:
		uvm_config_db#(axi_agent_config)::set(this, "m_axi_master_agent", "axi_agent_config", m_cfg.m_axi_master_agent_config);
		m_axi_master_agent = axi_agent::type_id::create("m_axi_master_agent", this);
		uvm_config_db#(axi_agent_config)::set(this, "m_axi_slave_agent", "axi_agent_config", m_cfg.m_axi_slave_agent_config);
		m_axi_slave_agent = axi_agent::type_id::create("m_axi_slave_agent", this);

		//  Create Scoreboard:
		m_scoreboard = axi_scoreboard::type_id::create("m_scoreboard", this);
	endfunction : build_phase

	function void connect_phase(uvm_phase phase);
		m_axi_master_agent.m_monitor.ap.connect(m_scoreboard.axi_master_imp);
		m_axi_slave_agent.m_monitor.ap.connect(m_scoreboard.axi_slave_imp);
		// Connect TLM ports between master and slave drivers if slave is active in simulation:
		if (m_axi_slave_agent.m_cfg.is_active == UVM_ACTIVE)begin
			m_axi_master_agent.m_master_driver.m_driver_tlm_port.connect(m_axi_slave_agent.m_slave_driver.s_driver_tlm_imp);
		end
		m_scoreboard.env_cfg = m_cfg;
	endfunction : connect_phase

endclass : axi_env