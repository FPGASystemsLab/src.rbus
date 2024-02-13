//=============================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
`include "rbus_defs.sv"
//=============================================================================================
import rbus_pkg::*;

module rmbus_slice_sw_box         
#
(
parameter               BUS_NUM    = 2,
parameter               BRANCH_NUM = 4
)  
(                                                                                                       
 input  wire            clk,                                            /*synthesis syn_keep=1*/
 input  wire            rst,                                            /*synthesis syn_keep=1*/

 input  wire            i_stb [BUS_NUM-1:0],                            /*synthesis syn_keep=1*/
 input  wire            i_sof [BUS_NUM-1:0],                            /*synthesis syn_keep=1*/
 input  rbus_word_t     i_bus [BUS_NUM-1:0],                            /*synthesis syn_keep=1*/
 output wire     [1:0]  i_rdy [BUS_NUM-1:0],                            /*synthesis syn_keep=1*/  
                                
 output wire            o_stb [BUS_NUM-1:0],                            /*synthesis syn_keep=1*/
 output wire            o_sof [BUS_NUM-1:0],                            /*synthesis syn_keep=1*/
 output rbus_word_t     o_bus [BUS_NUM-1:0],                            /*synthesis syn_keep=1*/
 input  wire     [1:0]  o_rdy [BUS_NUM-1:0],                            /*synthesis syn_keep=1*/
 input  wire     [1:0]  o_rdyE[BUS_NUM-1:0],                            /*synthesis syn_keep=1*/
 
 input  wire            branch_d2r_stb  [BRANCH_NUM-1:0][BUS_NUM-1:0],  /*synthesis syn_keep=1*/
 input  wire            branch_d2r_sof  [BRANCH_NUM-1:0][BUS_NUM-1:0],  /*synthesis syn_keep=1*/
 input  rbus_word_t     branch_d2r_bus  [BRANCH_NUM-1:0][BUS_NUM-1:0],  /*synthesis syn_keep=1*/
 output wire    [ 1:0]  branch_d2r_rdy  [BRANCH_NUM-1:0][BUS_NUM-1:0],  /*synthesis syn_keep=1*/
 output wire    [ 1:0]  branch_d2r_rdyE [BRANCH_NUM-1:0][BUS_NUM-1:0],  /*synthesis syn_keep=1*/
 
 output wire            branch_r2d_stb  [BRANCH_NUM-1:0][BUS_NUM-1:0],  /*synthesis syn_keep=1*/
 output wire            branch_r2d_sof  [BRANCH_NUM-1:0][BUS_NUM-1:0],  /*synthesis syn_keep=1*/
 output rbus_word_t     branch_r2d_bus  [BRANCH_NUM-1:0][BUS_NUM-1:0],  /*synthesis syn_keep=1*/
 input  wire    [ 1:0]  branch_r2d_rdy  [BRANCH_NUM-1:0][BUS_NUM-1:0],  /*synthesis syn_keep=1*/ 
 
 output wire            ff_err                                          /*synthesis syn_keep=1*/ 
);                                                                                                                                                                  
//==============================================================================================
// local param
//==============================================================================================
//==============================================================================================
// variables
//==============================================================================================    
wire                 d2r_sof     [BRANCH_NUM+3:0][BUS_NUM-1:0];
rbus_ctrl_t          d2r_ctrl    [BRANCH_NUM+3:0][BUS_NUM-1:0];
rbus_word_t          d2r_bus     [BRANCH_NUM+3:0][BUS_NUM-1:0];
//---------------------------------------------------------------------------------------------- 
wire                 r2d_sof     [BRANCH_NUM+3:0][BUS_NUM-1:0];
rbus_word_t          r2d_bus     [BRANCH_NUM+3:0][BUS_NUM-1:0];
//---------------------------------------------------------------------------------------------- 
wire   [BUS_NUM-1:0] ff_tmp_err;
reg             	 ff_ovr_err;
//==============================================================================================
// SWITCH 
//==============================================================================================
generate
genvar i;
  for(i=0;i<BUS_NUM;i=i+1)
  begin : BUS
    rsbus_slice_sw_box         
    #
    (
    .BRANCH_NUM (BRANCH_NUM)
    )               
    sw_box
    (                                                                                                       
    .clk            (clk), 
    .rst            (rst), 
    
    .i_stb          (i_stb [i]),                
    .i_sof          (i_sof [i]),                
    .i_bus          (i_bus [i]),                
    .i_rdy          (i_rdy [i]),                 
            
    .o_stb          (o_stb [i]),                
    .o_sof          (o_sof [i]),                
    .o_bus          (o_bus [i]),                
    .o_rdy          (o_rdy [i]),                
    .o_rdyE         (o_rdyE[i]),                 
    
    .branch_d2r_stb (branch_d2r_stb [i]), 
    .branch_d2r_sof (branch_d2r_sof [i]), 
    .branch_d2r_bus (branch_d2r_bus [i]), 
    .branch_d2r_rdy (branch_d2r_rdy [i]),
    .branch_d2r_rdyE(branch_d2r_rdyE[i]),
    
    .branch_r2d_stb (branch_r2d_stb [i]),
    .branch_r2d_sof (branch_r2d_sof [i]),
    .branch_r2d_bus (branch_r2d_bus [i]),
    .branch_r2d_rdy (branch_r2d_rdy [i]),
    
    .ff_err         (ff_tmp_err     [i])                   
    );                                                                                                                                                                  
  end                 
endgenerate
//==============================================================================================
always @(posedge clk or posedge rst)                                                                           
if( rst                  ) ff_ovr_err    <=                                                1'b0;               
else if( |ff_tmp_err     ) ff_ovr_err    <=                                                1'b1;  
else                       ff_ovr_err    <=                                          ff_ovr_err;    
//---------------------------------------------------------------------------------------------- 
assign ff_err =                                                                      ff_ovr_err;
//============================================================================================== 
endmodule            