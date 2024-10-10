# AXI4_VIP

### 🔗Project Description
*This project was made for self practice and learning, hope you find it useful for any purpose.*

AXI4 VIP, suitable for all types of AXI DUTs.
Made with emphasis on UVM methodology, OOP concepts, flexability and reusability covering the protocol requirements using blackbox verification approach.
DUT parameters can be controlled from axi_utils_pkg.sv, However, it may require some changes to suit a specific DUT.

### 🔗Features
* Supports all bursts with all lengths and sizes with narrow or unaligned transfers.
* Reorder mechanism verification.
* Contains a memory model capable of prioritizing write/read, parametrized with address/data widths, can be modded to be FIFO with depth parameter ; acting as a reference model.
* Has a B2B active slave model operation mode.
* All channels are individual threads.
* Sampling from interface, enabling axi master to be PASSIVE for larger environments integration.
* Test that imports transactions from file for user flexability.
* Regression script with merged coverage and summary report.
  
*For more details refer to AXI4_VIP.pdf*

### 🔗Techniques
* SystemVerilog UVM
* Functional & Formal SVA verification
* Clocking Blocks
* Virtual Sequences
* Covergroups & Assertion Coverage
* File I/O
* TCL and shell scripts

### 🤝Contact
[My LinkedIn](www.linkedin.com/in/yosef-belyatsky-5163a5173)

Feel free to contact at yosefbel92@gmail.com
