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
// File          : axi_agent.svh
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// AXI4 agent class, holds base driver handle as well as two driver handles, master and slave.
// driver type is determined according to is_master config property.
//--------------------------------------------------------------------------------------
//===========================================================================//
class axi_agent extends uvm_agent;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
	`uvm_component_utils(axi_agent)

// DATA MEMBERS =================================  //
// ============================================== //
	axi_agent_config m_cfg;
	axi_driver m_driver;
	uvm_sequencer#(axi_seq_item) m_sequencer;
	axi_monitor m_monitor;
	axi_coverage_collector m_cov_col;
	// handles for master/slave drivers to access TLM ports from axi_env:
	axi_master_driver m_master_driver;
	axi_slave_driver m_slave_driver;

// CONSTRUCTOR ==================================  //
// ============================================== //
	function new(string name = "axi_agent", uvm_component parent);
		super.new(name, parent);
	endfunction

// METHODS ======================================  //
// ============================================== //
	extern virtual function void build_phase(uvm_phase phase);
	extern virtual function void connect_phase(uvm_phase phase);

endclass : axi_agent

function void axi_agent::build_phase(uvm_phase phase);
	if (!uvm_config_db#(axi_agent_config)::get(this, "", "axi_agent_config", m_cfg))
		`uvm_fatal("CONFIG_DB", "get() axi_agent_config failed!")
	m_monitor = axi_monitor::type_id::create("m_monitor", this);
	if (m_cfg.is_active == UVM_ACTIVE)begin
		// driver type depends on is_master config property:
		if (m_cfg.is_master)begin
			m_driver = axi_master_driver::type_id::create("m_driver", this);
			// cast axi_driver to access members of master_driver from axi_env:
			if (!$cast(m_master_driver, m_driver))
				`uvm_fatal(get_type_name(), "cast failed!")
		end
		else begin
			m_driver = axi_slave_driver::type_id::create("m_driver", this);
			// cast axi_driver to access members of slave_driver from axi_env:
			if (!$cast(m_slave_driver, m_driver))
				`uvm_fatal(get_type_name(), "cast failed!")
		end
		m_sequencer = uvm_sequencer#(axi_seq_item)::type_id::create("m_sequencer", this);
	end
	if (m_cfg.has_functional_coverage)begin
		uvm_config_db#(bit)::set(this, "m_cov_col", "is_master", m_cfg.is_master);
		m_cov_col = axi_coverage_collector::type_id::create("m_cov_col", this);
	end
endfunction : build_phase

function void axi_agent::connect_phase(uvm_phase phase);
	m_monitor.vif = m_cfg.vif;
	// monitor behavior depends on is_master config property:
	m_monitor.is_master = m_cfg.is_master;
	if (m_cfg.is_active == UVM_ACTIVE)begin
		m_driver.vif = m_cfg.vif;
		m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
	end
	if (m_cfg.has_functional_coverage)
		m_monitor.ap.connect(m_cov_col.analysis_export);

endfunction : connect_phase
