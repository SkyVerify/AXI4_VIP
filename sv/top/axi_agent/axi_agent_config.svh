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
// File          : axi_agent_config.svh
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// AXI4 agent config class
//--------------------------------------------------------------------------------------
//===========================================================================//
class axi_agent_config extends uvm_object;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
	`uvm_object_utils(axi_agent_config)
	
// DATA MEMBERS =================================  //
// ============================================== //
	virtual interface axi_if vif;
	uvm_active_passive_enum is_active;
	bit has_functional_coverage;
	bit is_master;
	
// CONSTRUCTOR ==================================  //
// ============================================== //
	function new (string name = "axi_agent_config");
		super.new(name);
	endfunction
	
endclass : axi_agent_config