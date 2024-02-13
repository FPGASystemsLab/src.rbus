//=============================================================================================
//    Main contributors
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rbus_mb_frame_generator
#
(
parameter           BUS_NUM = 1
)
(
input  wire         clk,
input  wire         rst,   

input  wire         i_sof   [BUS_NUM-1:0],
input  wire [11:0]  i_ctrl  [BUS_NUM-1:0],
input  wire [71:0]  i_data  [BUS_NUM-1:0],   

output wire         o_sof   [BUS_NUM-1:0],
output wire [11:0]  o_ctrl  [BUS_NUM-1:0],
output wire [71:0]  o_data  [BUS_NUM-1:0]
);                                                                                                                                                        
//=============================================================================================
// variables
//=============================================================================================  
generate 
genvar i;
  for(i=0;i<BUS_NUM;i=i+1)
    begin : FRAME_GENERATOR
      rbus_frame_generator fg
      (
      .clk    (clk),
      .rst    (rst),   
      
      .i_sof  (i_sof  [i]),
      .i_ctrl (i_ctrl [i]),
      .i_data (i_data [i]),   
      
      .o_sof  (o_sof  [i]),
      .o_ctrl (o_ctrl [i]),
      .o_data (o_data [i])
      );       
      
    end
endgenerate
//=============================================================================================
endmodule