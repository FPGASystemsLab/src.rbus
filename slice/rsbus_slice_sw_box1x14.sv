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

module rsbus_slice_sw_box1x14         
#
(
parameter               BRANCH_NUM = 14
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
 output rbus_word_t     branch_r2d_bus  [BRANCH_NUM-1:0]  /*synthesis syn_keep=1*/ , 
 input  wire    [ 1:0]  branch_r2d_rdy  [BRANCH_NUM-1:0]  /*synthesis syn_keep=1*/ ,
 
 output wire            ff_err                            /*synthesis syn_keep=1*/ 
);                                                                                                                                                                  
//==============================================================================================
// local param
//==============================================================================================
//==============================================================================================
// variables
//==============================================================================================    
wire                   d2r_sof     [BRANCH_NUM+3:0];
rbus_ctrl_t            d2r_ctrl    [BRANCH_NUM+3:0];
rbus_word_t            d2r_bus     [BRANCH_NUM+3:0];
//---------------------------------------------------------------------------------------------- 
wire                   r2d_sof     [BRANCH_NUM+3:0];
rbus_word_t            r2d_bus     [BRANCH_NUM+3:0];
//---------------------------------------------------------------------------------------------- 
wire  [BRANCH_NUM+3:0] ff_tmp_err;
reg                    ff_ovr_err;
//==============================================================================================
// Frame  generator for D2R ring
//==============================================================================================
rsbus_frame_generator d2r_frame_generator
(
.clk            (clk),
.rst            (rst),                                          
                                                            
.i_sof          (d2r_sof  [0]),
.i_ctrl         (d2r_ctrl [0]),
.i_bus          (d2r_bus  [0]),   

.o_sof          (d2r_sof  [1]),
.o_ctrl         (d2r_ctrl [1]),
.o_bus          (d2r_bus  [1])
); 
//..............................................................................................
assign           r2d_sof  [1]   =                                                  r2d_sof  [0];
assign           r2d_bus  [1]   =                                                  r2d_bus  [0];
//==============================================================================================
// RBUS access manager
//==============================================================================================
rsbus_d2r_mgr   
#(                                   
.FF_DEPTH          ((BRANCH_NUM > 8)? 64 : ((BRANCH_NUM > 4)? 32 : 16)),       
// if ff depth is set as above than internal ffs can not overflow because d2r_injectors can 
// insert only 4 requests so it gives #(CORE_NUM*4) requests of each packets type 
// (various combinations of length and priority)
// Situation changed because of additional slots for packets with packet priority 3 that
// are now available in d2r_injectors. If an unlikely situation occures and all devices in a ring 
// sends packets with PP3 than a total number of those types of request can be #(CORE_NUM*5) for 
// a long packets and #(CORE_NUM*6) for a short packets. This situation is indeed very unlikely 
// but to preserve a valid network operation under all conditions a new parameter is introduced. 
// That is the FF_CAN_OVERFLOW_JUST_FOR_PP3 parameter that can be set instead of FF_NEVER_OVERFLOW 
.FF_NEVER_OVERFLOW (1'b0),
.FF_CAN_OVERFLOW_JUST_FOR_PP3 (1'b1)              
// Long fifos for request, that can be never filled, guarantee that all requests with a given 
// priority will be served in an order of arrival, and no request will circulate in a ring. Now
// such a circulation can occure just for packets with PP3 but it is a very unlikely situation
// that enough such packets can be generated by devices in a ring. 
)
d2r_mgr 
(
.clk            (clk),
.rst            (rst), 

.i_sof          (d2r_sof  [1]),
.i_ctrl         (d2r_ctrl [1]),
.i_bus          (d2r_bus  [1]),
            
.o_sof          (d2r_sof  [2]),
.o_ctrl         (d2r_ctrl [2]),
.o_bus          (d2r_bus  [2]),

.ff_err         (ff_tmp_err[1])
); 
//..............................................................................................
assign           r2d_sof [2] = r2d_sof [1];
assign           r2d_bus [2] = r2d_bus [1];
//==============================================================================================
// branch
//==============================================================================================
generate
genvar i;
  for(i=0;i<BRANCH_NUM;i=i+1)
  begin : BRANCH
    rsbus_r2d_extractor
    #
    (                     
    .BASE_ID         (i),                                                
    .LAST_ID         (i)
    )
    r2d_extractor
    (                                                                                                                      
    .clk            (clk),                                   
    .rst            (rst),                                   
                                                             
    .i_sof          (r2d_sof [i+2]),                         
    .i_bus          (r2d_bus [i+2]),                         
                                                             
    .o_sof          (r2d_sof [i+3]),                         
    .o_bus          (r2d_bus [i+3]),                         
    
    .frm_o_stb      (branch_r2d_stb   [i]),  
    .frm_o_sof      (branch_r2d_sof   [i]),  
    .frm_o_iid      (),
    .frm_o_bus      (branch_r2d_bus   [i]),
    .frm_o_rdy      (branch_r2d_rdy   [i])
    );         
    
    rsbus_d2r_injector
    #(                                                       
    .BASE_ID         (i),                                                
    .LAST_ID         (i)
    )  
    d2r_injector
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   
    
    .frm_i_stb      (branch_d2r_stb   [i]),                                                               
    .frm_i_sof      (branch_d2r_sof   [i]),
    .frm_i_iid      (4'd0),
    .frm_i_bus      (branch_d2r_bus   [i]),
    .frm_i_rdy      (branch_d2r_rdy   [i]), 
    .frm_i_rdyE     (branch_d2r_rdyE  [i]), 
                
    .i_sof          (d2r_sof  [i+2]),
    .i_ctrl         (d2r_ctrl [i+2]),
    .i_bus          (d2r_bus  [i+2]),
                                  
    .o_sof          (d2r_sof  [i+3]),
    .o_ctrl         (d2r_ctrl [i+3]),
    .o_bus          (d2r_bus  [i+3]),
    
    .ff_err         (ff_tmp_err[i+2])
    );                                
  end                 
endgenerate
//==============================================================================================
// Frame  generator for R2D ring
//==============================================================================================
rsbus_frame_generator r2d_frame_generator
(
.clk            (clk),
.rst            (rst),                                          
                                                            
.i_sof          (r2d_sof  [BRANCH_NUM + 2]),
.i_ctrl         (12'd0),
.i_bus          (r2d_bus  [BRANCH_NUM + 2]),   

.o_sof          (r2d_sof  [BRANCH_NUM + 3]),
.o_ctrl         (),
.o_bus          (r2d_bus  [BRANCH_NUM + 3])
); 
//..............................................................................................
assign           d2r_sof  [BRANCH_NUM + 3] = d2r_sof  [BRANCH_NUM + 2];                                                                    
assign           d2r_ctrl [BRANCH_NUM + 3] = d2r_ctrl [BRANCH_NUM + 2];
assign           d2r_bus  [BRANCH_NUM + 3] = d2r_bus  [BRANCH_NUM + 2];
//==============================================================================================
// ring bus switch (internal ring to external ring)
//==============================================================================================
rsbus_d2r_extractor #
(                        
.SPACE_CHECKING         ("OFF"),
.SPACE_START_ADDRESS    (36'h0_0000_0000),
.SPACE_LAST_ADDRESS     (36'h0_0000_0000)
)
d2r_extractor
(
.clk                    (clk),
.rst                    (rst),   
                                      
.i_sof                  (d2r_sof  [BRANCH_NUM + 3]),
.i_ctrl                 (d2r_ctrl [BRANCH_NUM + 3]),
.i_bus                  (d2r_bus  [BRANCH_NUM + 3]),
                                      
.o_sof                  (d2r_sof  [0]),
.o_ctrl                 (d2r_ctrl [0]),
.o_bus                  (d2r_bus  [0]),
                       
.frm_o_stb              (o_stb), 
.frm_o_sof              (o_sof), 
.frm_o_bus              (o_bus),
.frm_o_rdy              (o_rdy),
.frm_o_rdyE             (o_rdyE)   
);  
//..............................................................................................   
rsbus_r2d_injector       r2d_injector
(                                                                                                                               
.clk                    (clk),
.rst                    (rst),

.frm_i_stb              (i_stb), 
.frm_i_sof              (i_sof), 
.frm_i_bus              (i_bus),
.frm_i_rdy              (i_rdy),
																					  
.i_sof                  (r2d_sof [BRANCH_NUM + 3]),								  
.i_bus                  (r2d_bus [BRANCH_NUM + 3]),
                                      
.o_sof                  (r2d_sof [0]),
.o_bus                  (r2d_bus [0]),  

.ff_err                 (ff_tmp_err[BRANCH_NUM + 3])
);  
//==============================================================================================
always @(posedge clk or posedge rst)                                                                           
if( rst                  ) ff_ovr_err    <=                                                1'b0;               
else if( |ff_tmp_err     ) ff_ovr_err    <=                                                1'b1;  
else                       ff_ovr_err    <=                                          ff_ovr_err;    
//---------------------------------------------------------------------------------------------- 
assign ff_err =                                                                      ff_ovr_err;
//============================================================================================== 
endmodule            