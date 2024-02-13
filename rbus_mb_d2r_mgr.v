//=============================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>  
//---------------------------------------------------------------------------------------------
// Module rbus_d2r_mgr
// - Buffers requests from devices and grants access to a ring bus with respect to 
//  the signalised priority.
// - Priority 0x3 is the highest, 0x0 is the lowest.
// - Requests come at rbus_i_ctrl bus along with data (rbus_i_sof == 0).
// - Requests are stored in 8 separate fifos, 4 for long packets and 4 for short packets 
//    requests. 
// - Each fifo is 16 requests deep and in case of overflow risk it skips request and leave it 
//    on the ring.
// - Grants are placed at rbus_o_ctrl bus along with headers (rbus_o_sof == 1).
// - A grant assigns current packet for a use by a designated device.
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rbus_mb_d2r_mgr
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
output wire [71:0]  o_data  [BUS_NUM-1:0],

output reg          ff_err
);      
//=============================================================================================
generate 
genvar i;
  for(i=0;i<BUS_NUM;i=i+1)
    begin : D2R_MGR
      rbus_d2r_mgr d2r_mgr
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