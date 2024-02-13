//=============================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rbus_dff
(      
input  wire  clk,   
input  wire           rst,   

input  wire           i_stb,
input  wire           i_sof,
input  wire   [71:0]  i_data,
output wire    [1:0]  i_rdy,
output wire           i_err,

output wire           o_stb,
output wire           o_sof,
output wire   [71:0]  o_data,
input  wire           o_ack,
output wire           o_err
);                                                                                             
//=============================================================================================   
wire [1:0] i_af;
ff_dram_af_ack_d32
#(
.WIDTH(73), 
.AF0LIMIT(6'd4),//4  zamiast 2 ze wzgledu na czasowki
.AF1LIMIT(6'd11) //11 zamiast 9 ze wzgledu na czasowki          
)   
ff_dram
(             
.clk    (clk),
.rst    (rst),
                 
.i_stb  (i_stb),  
.i_data ({i_sof, i_data}),
.i_af   (i_af),
.i_full (),
.i_err  (i_err),

.o_stb  (o_stb),
.o_ack  (o_ack),
.o_data ({o_sof, o_data}),
.o_ae   (),
.o_err  (o_err)
);     
assign i_rdy = ~i_af;
//=============================================================================================
endmodule



//=============================================================================================
module rbus_dffs
(      
input  wire  clk,   
input  wire           rst,   

input  wire           i_stb,
input  wire           i_sof,
input  wire   [71:0]  i_data,
output wire    [1:0]  i_rdy,
output wire           i_err,

output wire           o_stb,
output wire           o_sof,
output wire   [71:0]  o_data,
input  wire           o_ack,
output wire           o_err
);                                            
//=============================================================================================  
wire [1:0] i_af;  
`ifdef NO_SHIFT_REGS
ff_dram_af_ack_d16
`else	  
ff_srl_af_ack_d16
`endif            
#(
.WIDTH(73), 
.AF0LIMIT(6'd4),//4  zamiast 2 ze wzgledu na czasowki
.AF1LIMIT(6'd11) //11 zamiast 9 ze wzgledu na czasowki 
)   
ff_dram
(             
.clk    (clk),
.rst    (rst),
                 
.i_stb  (i_stb),  
.i_data ({i_sof, i_data}),
.i_af   (i_af),
.i_full (),   
.i_err  (i_err),

.o_stb  (o_stb),
.o_ack  (o_ack),
.o_data ({o_sof, o_data}), 
.o_ae   (),
.o_err  (o_err)
);             
assign i_rdy = ~i_af;
//=============================================================================================
endmodule