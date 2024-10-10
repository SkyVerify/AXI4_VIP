// 	FILE INFORMATION:
//
//	FORMATTING: (bit) <tab> (int) <tab> (int) <tab> (hex) <tab> (hex) <tab> (hex)
//		    data beats with underscores _ between, it may overflow lines.

//	PARAMETERS: BURST_TYPE	LEN	SIZE	ID	ADDRESS	DATA
//
//	Do not mix fixed with wrap/incr burst types in the same file!
//
//	Example : 2 beat, 16 bit each fixed burst with id = a, address = 0x4, data: [0xaced, 0xface]
//	0	1	1	a	4	aced_face
/////////////////////////////////////////////////////////////////////////////////////////////////////