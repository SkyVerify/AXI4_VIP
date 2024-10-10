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
// File          : axi_driver.svh
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// AXI4 driver class, base class for master/slave_driver
//--------------------------------------------------------------------------------------
//===========================================================================//
class axi_driver extends uvm_driver #(axi_seq_item);
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
	`uvm_component_utils(axi_driver)

// DATA MEMBERS =================================  //
// ============================================== //
	virtual interface axi_if vif;

// CONSTRUCTOR ==================================  //
// ============================================== //
	function new(string name = "axi_driver", uvm_component parent);
		super.new(name, parent);
	endfunction

// METHODS ======================================  //
// ============================================== //
	virtual task write_address();
		`uvm_info(get_type_name(), "WRITE ADDRESS CHANNEL", UVM_DEBUG)
	endtask : write_address

	virtual task write_data();
		`uvm_info(get_type_name(), "WRITE DATA CHANNEL", UVM_DEBUG)
	endtask : write_data

	virtual task write_response();
		`uvm_info(get_type_name(), "WRITE RESPONSE CHANNEL", UVM_DEBUG)
	endtask : write_response

	virtual task read_address();
		`uvm_info(get_type_name(), "READ ADDRESS CHANNEL", UVM_DEBUG)
	endtask : read_address

	virtual task read_data();
		`uvm_info(get_type_name(), "READ DATA CHANNEL", UVM_DEBUG)
	endtask : read_data

	//	Run 5 threads representing each individual channel ;
	//	Each arriving sequence item is being processed according to the driver type at drive_item task:
	virtual task run_phase(uvm_phase phase);
		vif.delay(1);
		fork
			// Write address channel:
			write_address();
			// Write data channel:
			write_data();
			// Write response channel:
			write_response();
			// Read address channel:
			read_address();
			// Read data channel:
			read_data();
		join_none
		forever begin
			//*** Chose one, comment the other: ***
			///////////////////////////////////////
			// Blocking - waits for req to be available:
			seq_item_port.get_next_item(req);
			vif.rst_n <= req.rst_n;
			// Reset logic
			if (!req.rst_n)
				vif.delay(1);
			else begin
				fork
					vif.delay(req.delay);
					drive_item(req);
				join
			end
			// Non-blocking - pulls 'null' if req unavailable:
			//seq_item_port.try_next_item(req) 
			//if (req != null)begin
			seq_item_port.item_done();
			//end	
		end
    endtask : run_phase

    virtual task drive_item(axi_seq_item item);
		`uvm_info(get_type_name(), "start drive item", UVM_LOW)
	endtask : drive_item

endclass : axi_driver