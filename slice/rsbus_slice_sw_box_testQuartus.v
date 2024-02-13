//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns     
//=============================================================================================
`include "rbus_defs.sv"
//=============================================================================================
import rbus_pkg::*;

module rsbus_slice_sw_box_testQuartus         
#
(
parameter               BRANCH_NUM = 4
)  
(                                                                                                       
 input  wire            clk                               /*synthesis syn_keep=1*/ ,
 input  wire            rst                               /*synthesis syn_keep=1*/ ,
 
 input  wire            i_stb                             /*synthesis syn_keep=1*/ ,
 input  wire            i_sof                             /*synthesis syn_keep=1*/ ,
 input  rbus_word_t     i_bus                             /*synthesis syn_keep=1*/ ,
 output wire     [1:0]  i_rdy                             /*synthesis syn_keep=1*/ ,
 
 output wire            o_stb                             /*synthesis syn_keep=1*/ ,
 output wire            o_sof                             /*synthesis syn_keep=1*/ ,
 output rbus_word_t     o_bus                             /*synthesis syn_keep=1*/ ,
 input  wire     [1:0]  o_rdy                             /*synthesis syn_keep=1*/ ,
 input  wire     [1:0]  o_rdyE                            /*synthesis syn_keep=1*/ ,
 
 input  wire            branch_d2r_stb  [BRANCH_NUM-1:0]  /*synthesis syn_keep=1*/ , 
 input  wire            branch_d2r_sof  [BRANCH_NUM-1:0]  /*synthesis syn_keep=1*/ , 
 input  rbus_word_t     branch_d2r_bus  [BRANCH_NUM-1:0]  /*synthesis syn_keep=1*/ , 
 output wire    [ 1:0]  branch_d2r_rdy  [BRANCH_NUM-1:0]  /*synthesis syn_keep=1*/ , 
 output wire    [ 1:0]  branch_d2r_rdyE [BRANCH_NUM-1:0]  /*synthesis syn_keep=1*/ ,
 
 output wire            branch_r2d_stb  [BRANCH_NUM-1:0]  /*synthesis syn_keep=1*/ , 
 output wire            branch_r2d_sof  [BRANCH_NUM-1:0]  /*synthesis syn_keep=1*/ , 
 output rbus_word_t     branch_r2d_bus                    /*synthesis syn_keep=1*/ , 
 input  wire    [ 1:0]  branch_r2d_rdy  [BRANCH_NUM-1:0]  /*synthesis syn_keep=1*/ ,
 
 output wire            ff_err                            /*synthesis syn_keep=1*/ 
);                                   
//==============================================================================================
rbus_word_t     branch_r2d_bus_all[BRANCH_NUM-1:0];
rsbus_slice_sw_box TTT
(                                                                                                       
 .clk            (clk             ),
 .rst            (rst             ),
 .i_stb          (i_stb           ),
 .i_sof          (i_sof           ),
 .i_bus          (i_bus           ),
 .i_rdy          (i_rdy           ),
 .o_stb          (o_stb           ),
 .o_sof          (o_sof           ),
 .o_bus          (o_bus           ),
 .o_rdy          (o_rdy           ),
 .o_rdyE         (o_rdyE          ),
 .branch_d2r_stb (branch_d2r_stb  ),
 .branch_d2r_sof (branch_d2r_sof  ),
 .branch_d2r_bus (branch_d2r_bus  ),
 .branch_d2r_rdy (branch_d2r_rdy  ),
 .branch_d2r_rdyE(branch_d2r_rdyE ),
 .branch_r2d_stb (branch_r2d_stb  ),
 .branch_r2d_sof (branch_r2d_sof  ),
 .branch_r2d_bus (branch_r2d_bus_all  ),
 .branch_r2d_rdy (branch_r2d_rdy  ),
 .ff_err         (ff_err          )
);                           
genvar i;
generate
  for(i=0;i<71;i=i+1)
  begin: assignement
    assign branch_r2d_bus[i] = branch_r2d_bus_all[0][i] | branch_r2d_bus_all[1][i] | branch_r2d_bus_all[2][i] | branch_r2d_bus_all[3][i];
  end
endgenerate
//============================================================================================== 
endmodule            