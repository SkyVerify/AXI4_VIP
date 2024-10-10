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
// File          : axi_seq_item.svh
// Project       : axi4_vip
//--------------------------------------------------------------------------------------
// Description :
// AXI4 transaction class
//--------------------------------------------------------------------------------------
//===========================================================================//
class axi_seq_item extends uvm_sequence_item;
//===========================================================================//
// FACTORY REGISTRATION =========================  //
// ============================================== //
	`uvm_object_utils(axi_seq_item)

// DATA MEMBERS =================================  //
// ============================================== //
	// Global signals:
	rand logic 	rst_n;						

	// Address channel
	rand logic			[ID_WIDTH-1:0]id;		
	rand logic 			[ADDR_WIDTH-1:0]addr;	
	rand logic 			[7:0]len;
	rand logic			[2:0]size;		
	rand axi_burst_e	burst;						//	enum defined in axi_utils
	rand logic 			lock;	
	rand logic 			cache;						//	TBD 	
	rand logic 			[2:0]prot;					//	TBD 
	rand logic 			[3:0]qos;					//	TBD
	rand logic 			[3:0]region;				//	TBD
	rand logic 			user;	
	
	// Data channel	
	rand logic 			[DATA_WIDTH-1:0]data[];						
	rand axi_resp_e 	rresp[];					//	enum defined in axi_utils				
	rand axi_resp_e   	bresp;						//	enum defined in axi_utils
	logic 				[STRB_WIDTH-1:0]strb[];

	// General
	rand int  item_idx;
	rand int  delay;
	rand axi_channel_e channel;						//	enum defined in axi_utils
	rand bit wr_rd_op; 								//	indication whether it is a write or read transaction ; HIGH = write, LOW = read
	rand bit align_addr_en; 						// 	force address align after randomization; HIGH = force 
	// calculated post_randomization:
	logic [ADDR_WIDTH-1:0]wrap_boundry;				//	address which is being wrapped to in case of wrap burst
	logic [ADDR_WIDTH-1:0]wrap_condition;			//	address that will trigger wrap condition in case of wrap burst

// CONSTRAINTS ==================================  //
// ============================================== //
	// 	delay constraint:
	constraint delay_c		{ delay inside {[1:10]}; }
	//	dynamic array of data vectors sized by number of burst beats:
	constraint data_c		{ solve len before data;
							  solve wr_rd_op before data;
						  	  if (wr_rd_op) data.size() == len + 1;
						  	  else data.size() == 0; }
	//	dynamic array of resp vectors sized by number of burst beats:
	constraint rresp_c		{ solve len before rresp;
						  	rresp.size() == len + 1; }					  
	//	len constraint according to burst type:
	constraint len_c 		{ solve burst before len;
						  	if (burst == FIXED) len inside {[0:15]}; // AXI4 supports 1 to 256 len for INCR only, others are 1 to 16
						  	if (burst == WRAP) len inside {1, 3, 7, 15}; } // WRAP burst len must be 2, 4, 8 or 16
	//	constraint max burst size to be under 4KB:
	constraint max_size_c 	{ 8*(2**size)*(len+1) <= 4096; }

// CONSTRUCTOR ==================================  //
// ============================================== //
	function new (string name = "axi_seq_item");
		super.new(name);
	endfunction

// METHODS ======================================  //
// ============================================== //
	function void post_randomize();
		int d_size = DATA_WIDTH/8;
		int t_size = 2**size;
		int byte_lane;

		if (rst_n)begin	
			//	WRAP burst starts with aligned addresses:
			if (burst == WRAP)
				align_addr_en = 1'b1; 

			//	Align address ; can be toggled in test, default for WRAP bursts:
			if (align_addr_en)
				addr = align_addr(addr, t_size);

			//	Strobe logic:
			byte_lane = addr - align_addr(addr, d_size);
			strb = new[len+1];

			foreach(strb[i])begin
				//	set all bits of strobe to HIGH by default change for either condition:
				strb[i] = {STRB_WIDTH{1'b1}}; 

				//	Unaligned / narrow transfer ; initial transfer is determined by address offset (==byte_lane):
				//	For unaligned case, the rest of transfers will be aligned (for burst != FIXED) ;
				//	For narrow transfers, the logic below will determine the strobe vector:
				if (i == 0)begin
					if ((byte_lane != 0) || (d_size > t_size))begin
						repeat(t_size)begin
							if (byte_lane == d_size) break;
							strb[0][byte_lane] = 1'b0;
							byte_lane++;
						end
						strb[i] = ~strb[i];
					end
				end
				//	Rest of transfers ; FIXED - unchanged strb / INCR - narrow (=bits shift):
				else begin
					if (burst == FIXED)
						strb[i] = strb[i-1];
					//	narrow transfer ; strobe bits are wrap-around shifted according to transfer size:
					else if (d_size > t_size)
						strb[i] = ((strb[i-1] << t_size) == {STRB_WIDTH{1'b0}}) ? 
									strb[i] >> (d_size - t_size) : 
							  		strb[i-1] << t_size;	
				end
			end	
		end
	endfunction : post_randomize

	virtual function string convert2string();
		string contents = $sformatf("\n=====================\n\t%0s [%0d]\n=====================\n\t", channel.name(), item_idx);
		contents = {contents, $sformatf("ID \t= 0x%0h\n\t", id)};
		if (channel == WRITE_ADDR || channel == READ_ADDR)begin
			contents = {contents, $sformatf("ADDR \t= 0x%0h\n\t", addr)};
			contents = {contents, $sformatf("LEN \t= %0d\n\t", len)}; 
			contents = {contents, $sformatf("SIZE \t= %0d\n\t", size)};
			contents = {contents, $sformatf("BURST \t= %0s\n\t", burst.name())};
			contents = {contents, $sformatf("LOCK \t= %0b\n\t", lock)};
			contents = {contents, $sformatf("CACHE \t= %0b\n\t", cache)}; 
			contents = {contents, $sformatf("PROT \t= %0b\n\t", prot)};
			contents = {contents, $sformatf("QOS \t= %0b\n\t", qos)};
			contents = {contents, $sformatf("REGION \t= %0b\n\t", region)};
		end
		if (channel == WRITE_DATA || channel == READ_DATA)begin
			string data_s;
			string strb_s;
			string resp_s;
			$swriteh(data_s, "%p", data);
			if (channel == WRITE_DATA)
				$swriteb(strb_s, "%p", strb);
			else
				$swriteb(resp_s, "%p", rresp);
			contents = {contents, $sformatf("DATA \t= 0x%s\n\t", data_s)};
			contents = {contents, channel == WRITE_DATA ? $sformatf("STRB \t= %s\n\t", strb_s) : $sformatf("RESP \t= %0s\n\t", resp_s)};
		end
		if (channel == WRITE_RESP)
		 	contents = {contents, $sformatf("RESP \t= %0s\n\t", bresp.name())};
		contents = {contents, $sformatf("USER \t= %0b\n\t", user)}; 
		return contents;
	endfunction : convert2string

	function void do_print(uvm_printer printer);
		printer.m_string = convert2string();
	endfunction : do_print

	virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
		axi_seq_item _item;
		if (!$cast(_item, rhs))begin
			`uvm_fatal("do_compare", "cast failed!")
		end
		do_compare = super.do_compare(_item, comparer);
		do_compare &= (_item.id 			== id);
		if (channel == WRITE_ADDR || channel == READ_ADDR)begin
			do_compare &= (
				(_item.addr 		== addr) 	 &&
				(_item.len 			== len) 	 &&
				(_item.size 		== size) 	 &&
				(_item.burst 		== burst)  	 &&
				(_item.lock 		== lock) 	 &&
				(_item.cache 		== cache)  	 &&
				(_item.prot 		== prot) 	 &&
				(_item.qos 			== qos) 	 &&
				(_item.region 		== region));
		end
		if (channel == WRITE_DATA || channel  == READ_DATA)
			foreach (data[i])
				do_compare &= (_item.data[i]  == data[i]);
		if (channel == WRITE_RESP)
			do_compare &= (_item.bresp == bresp);
		if (channel == READ_DATA)
			foreach (rresp[i])
				do_compare &= (_item.rresp[i]  == rresp[i]);
		return do_compare;  
	endfunction : do_compare

	virtual function void do_copy(uvm_object rhs);
		axi_seq_item _item;
		if (!$cast(_item, rhs))
			`uvm_fatal("do_copy", "cast failed!")
		super.do_copy(rhs);
		item_idx		= _item.item_idx;
		delay 			= _item.delay;
		channel 		= _item.channel;
		wr_rd_op  		= _item.wr_rd_op;
		wrap_boundry	= _item.wrap_boundry;
		wrap_condition	= _item.wrap_condition;
		id				= _item.id;
		user 			= _item.user;
		addr  			= _item.addr;
		len				= _item.len; 	
		size  			= _item.size; 
		burst 			= _item.burst; 	
		lock 			= _item.lock; 
		cache 			= _item.cache; 
		prot  			= _item.prot;
		qos				= _item.qos;
		region 			= _item.region;
		data 			= new[_item.data.size()];
		foreach(_item.data[i]) data[i] = _item.data[i];
		strb 			= new[_item.strb.size()];
		foreach(_item.strb[i]) strb[i] = _item.strb[i];
		rresp 			= new[_item.rresp.size()];
		foreach(_item.rresp[i]) rresp[i] = _item.rresp[i];
		bresp			= _item.bresp;			
	endfunction : do_copy
	
endclass : axi_seq_item