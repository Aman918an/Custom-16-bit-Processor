// instruction field macros (operate on IR)
`define oper_type IR[31:27]
`define rdst      IR[26:22]
`define rsrc1     IR[21:17]
`define imm_mode  IR[16]
`define rsrc2     IR[15:11]
`define isrc      IR[15:0]

// arithmetic operations
`define movsgpr 5'b00000
`define mov     5'b00001
`define add     5'b00010
`define sub     5'b00011
`define mul     5'b00100
// logical operations
`define ror     5'b00101
`define rand    5'b00110
`define rxor    5'b00111
`define rxnor   5'b01000
`define rnand   5'b01001
`define rnor    5'b01010
`define rnot    5'b01011

//instructions
`define storereg 5'b01101 // reg to data mem
`define storedin 5'b01110 // din into data mem
`define senddout 5'b01111 // data mem to dout
`define sendreg  5'b10001 // data mem to reg

/*
`define readin 5'b10010
`define writein 5'b10011
*/


// jump and branch 
`define jump        5'b10010 // jump to address
`define jcarry      5'b10011 // jump if carry is set
`define jnocarry    5'b10100
`define jsign       5'b10101 // jump if sign is set
`define jnosign     5'b10110
`define jzero       5'b10111 // jump if zero is set
`define jnozero     5'b11000
`define joverflow   5'b11001 // jump if overflow is set
`define jnooverflow 5'b11010

// halt
`define halt 5'b11011
