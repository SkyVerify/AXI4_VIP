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
// File          : axi_env_config.svh
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// AXI4 environment config class
//--------------------------------------------------------------------------------------
//===========================================================================//
class axi_env_config extends uvm_object;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
	`uvm_object_utils(axi_env_config)

// DATA MEMBERS =================================  //
// ============================================== //
	axi_agent_config m_axi_master_agent_config;
	axi_agent_config m_axi_slave_agent_config;

// CONSTRUCTOR ==================================  //
// ============================================== //
	function new (string name = "axi_env_config");
		super.new(name);
	endfunction

endclass : axi_env_config