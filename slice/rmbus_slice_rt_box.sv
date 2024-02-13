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
import rbus_pkg::*;                                                                                    
//==============================================================================================

module rmbus_slice_rt_box
#
(
parameter             RINGS_MULT                   = 4,
parameter             MEM1_EXTERNAL_PORT_MULT      = 1,
parameter             BRANCH_NUM                   = 4
)  
(
 input  wire          rst,                                         /*synthesis syn_keep=1*/
 input  wire          clk,                                         /*synthesis syn_keep=1*/
 
 output wire  [15:0]  dbg         [0: RINGS_MULT-1],      /*synthesis syn_keep=1*/ 
 
 // bootrom/flash port                                             
 
 output wire          mem0_r2m_stb ,                               /*synthesis syn_keep=1*/
 output wire          mem0_r2m_sof ,                               /*synthesis syn_keep=1*/
 output wire [71:0]   mem0_r2m_data,                               /*synthesis syn_keep=1*/                           
 input  wire [ 1:0]   mem0_r2m_rdy ,                               /*synthesis syn_keep=1*/ 
 
 input  wire          mem0_m2r_stb ,                               /*synthesis syn_keep=1*/
 input  wire          mem0_m2r_sof ,                               /*synthesis syn_keep=1*/
 input  wire [71:0]   mem0_m2r_data,                               /*synthesis syn_keep=1*/  
 output wire [ 1:0]   mem0_m2r_rdy ,                               /*synthesis syn_keep=1*/  
 
 // external RAM port (DDR)                         
 
 output wire          mem1_r2m_stb [0:MEM1_EXTERNAL_PORT_MULT-1], /*synthesis syn_keep=1*/
 output wire          mem1_r2m_sof [0:MEM1_EXTERNAL_PORT_MULT-1], /*synthesis syn_keep=1*/
 output wire [71:0]   mem1_r2m_data[0:MEM1_EXTERNAL_PORT_MULT-1], /*synthesis syn_keep=1*/  
 input  wire [ 1:0]   mem1_r2m_rdy [0:MEM1_EXTERNAL_PORT_MULT-1], /*synthesis syn_keep=1*/
 
 input  wire          mem1_m2r_stb [0:MEM1_EXTERNAL_PORT_MULT-1], /*synthesis syn_keep=1*/
 input  wire          mem1_m2r_sof [0:MEM1_EXTERNAL_PORT_MULT-1], /*synthesis syn_keep=1*/
 input  wire [71:0]   mem1_m2r_data[0:MEM1_EXTERNAL_PORT_MULT-1], /*synthesis syn_keep=1*/  
 output wire [ 1:0]   mem1_m2r_rdy [0:MEM1_EXTERNAL_PORT_MULT-1], /*synthesis syn_keep=1*/
 
 // mutex                                           
 
 output wire          mutex_r2m_stb ,                              /*synthesis syn_keep=1*/
 output wire          mutex_r2m_sof ,                              /*synthesis syn_keep=1*/
 output wire [71:0]   mutex_r2m_data,                              /*synthesis syn_keep=1*/
 input  wire [ 1:0]   mutex_r2m_rdy ,                              /*synthesis syn_keep=1*/
 
 input  wire          mutex_m2r_stb ,                              /*synthesis syn_keep=1*/
 input  wire          mutex_m2r_sof ,                              /*synthesis syn_keep=1*/
 input  wire [71:0]   mutex_m2r_data,                              /*synthesis syn_keep=1*/
 output wire [ 1:0]   mutex_m2r_rdy ,                              /*synthesis syn_keep=1*/
 
 // reflector                                                      
 
 output wire          ref_r2m_stb ,                                /*synthesis syn_keep=1*/
 output wire          ref_r2m_sof ,                                /*synthesis syn_keep=1*/
 output wire [71:0]   ref_r2m_data,                                /*synthesis syn_keep=1*/
 input  wire [ 1:0]   ref_r2m_rdy ,                                /*synthesis syn_keep=1*/
 
 input  wire          ref_m2r_stb , 	                           /*synthesis syn_keep=1*/
 input  wire          ref_m2r_sof ,                                /*synthesis syn_keep=1*/
 input  wire [71:0]   ref_m2r_data,                                /*synthesis syn_keep=1*/
 output wire [ 1:0]   ref_m2r_rdy ,                                /*synthesis syn_keep=1*/

 // branches
 
 input  wire          branch_d2r_stb  [0:BRANCH_NUM-1][0:RINGS_MULT-1],  /*synthesis syn_keep=1*/
 input  wire          branch_d2r_sof  [0:BRANCH_NUM-1][0:RINGS_MULT-1],  /*synthesis syn_keep=1*/
 input  wire [71:0]   branch_d2r_data [0:BRANCH_NUM-1][0:RINGS_MULT-1],  /*synthesis syn_keep=1*/
 output wire [ 1:0]   branch_d2r_rdy  [0:BRANCH_NUM-1][0:RINGS_MULT-1],  /*synthesis syn_keep=1*/
 output wire [ 1:0]   branch_d2r_rdyE [0:BRANCH_NUM-1][0:RINGS_MULT-1],  /*synthesis syn_keep=1*/
 									                                                    
 output wire          branch_r2d_stb  [0:BRANCH_NUM-1][0:RINGS_MULT-1],  /*synthesis syn_keep=1*/
 output wire          branch_r2d_sof  [0:BRANCH_NUM-1][0:RINGS_MULT-1],  /*synthesis syn_keep=1*/
 output wire [71:0]   branch_r2d_data [0:BRANCH_NUM-1][0:RINGS_MULT-1],  /*synthesis syn_keep=1*/
 input  wire [ 1:0]   branch_r2d_rdy  [0:BRANCH_NUM-1][0:RINGS_MULT-1],  /*synthesis syn_keep=1*/ 

 output wire          ff_err              /*synthesis syn_keep=1*/
);    
//==============================================================================================
// variables                                                  
//==============================================================================================
reg           ff_err_reg;

wire          x0_mem0_r2m_stb    [0: RINGS_MULT-1];                     
wire          x0_mem0_r2m_sof    [0: RINGS_MULT-1];                     
wire [71:0]   x0_mem0_r2m_data   [0: RINGS_MULT-1];                                           
wire [ 1:0]   x0_mem0_r2m_rdy    [0: RINGS_MULT-1];    
wire          x0_mem0_m2r_stb    [0: RINGS_MULT-1];                     
wire          x0_mem0_m2r_sof    [0: RINGS_MULT-1];                     
wire [71:0]   x0_mem0_m2r_data   [0: RINGS_MULT-1];                     
wire [ 1:0]   x0_mem0_m2r_rdy    [0: RINGS_MULT-1]; 
                                 
wire          x0_mem1_r2m_stb    [0: RINGS_MULT-1];
wire          x0_mem1_r2m_sof    [0: RINGS_MULT-1];
wire [71:0]   x0_mem1_r2m_data   [0: RINGS_MULT-1];
wire [ 1:0]   x0_mem1_r2m_rdy    [0: RINGS_MULT-1];
wire          x0_mem1_m2r_stb    [0: RINGS_MULT-1];
wire          x0_mem1_m2r_sof    [0: RINGS_MULT-1];
wire [71:0]   x0_mem1_m2r_data   [0: RINGS_MULT-1];
wire [ 1:0]   x0_mem1_m2r_rdy    [0: RINGS_MULT-1];
                                 
wire          x0_mutex_r2m_stb   [0: RINGS_MULT-1];           
wire          x0_mutex_r2m_sof   [0: RINGS_MULT-1];           
wire [71:0]   x0_mutex_r2m_data  [0: RINGS_MULT-1];           
wire [ 1:0]   x0_mutex_r2m_rdy   [0: RINGS_MULT-1];    
wire          x0_mutex_m2r_stb   [0: RINGS_MULT-1];           
wire          x0_mutex_m2r_sof   [0: RINGS_MULT-1];           
wire [71:0]   x0_mutex_m2r_data  [0: RINGS_MULT-1];           
wire [ 1:0]   x0_mutex_m2r_rdy   [0: RINGS_MULT-1]; 
                                 
wire          x0_ref_r2m_stb     [0: RINGS_MULT-1];               
wire          x0_ref_r2m_sof     [0: RINGS_MULT-1];
wire [71:0]   x0_ref_r2m_data    [0: RINGS_MULT-1];
wire [ 1:0]   x0_ref_r2m_rdy     [0: RINGS_MULT-1];
wire          x0_ref_m2r_stb     [0: RINGS_MULT-1];
wire          x0_ref_m2r_sof     [0: RINGS_MULT-1];
wire [71:0]   x0_ref_m2r_data    [0: RINGS_MULT-1]; 
wire [ 1:0]   x0_ref_m2r_rdy     [0: RINGS_MULT-1];   

wire          x0_branch_d2r_stb  [0:BRANCH_NUM-1][0: RINGS_MULT-1] ;
wire          x0_branch_d2r_sof  [0:BRANCH_NUM-1][0: RINGS_MULT-1] ;
wire [71:0]   x0_branch_d2r_data [0:BRANCH_NUM-1][0: RINGS_MULT-1] ;
wire [ 1:0]   x0_branch_d2r_rdy  [0:BRANCH_NUM-1][0: RINGS_MULT-1] ;
wire [ 1:0]   x0_branch_d2r_rdyE [0:BRANCH_NUM-1][0: RINGS_MULT-1] ;
wire          x0_branch_r2d_stb  [0:BRANCH_NUM-1][0: RINGS_MULT-1] ;
wire          x0_branch_r2d_sof  [0:BRANCH_NUM-1][0: RINGS_MULT-1] ;
wire [71:0]   x0_branch_r2d_data [0:BRANCH_NUM-1][0: RINGS_MULT-1] ;
wire [ 1:0]   x0_branch_r2d_rdy  [0:BRANCH_NUM-1][0: RINGS_MULT-1] ;

wire [RINGS_MULT-1:0] x0_shell_ff_err; 
wire [ 1:0]   mutex_ff_err;
wire [ 1:0]   ref_ff_err;  	
wire [ 1:0]   mem0_ff_err;
wire [ 1:0]   mem1_ff_err;
//==============================================================================================
// internal rings generation
//==============================================================================================
genvar ir_id, er_id, br_id;
generate
  for(ir_id = 0; ir_id < RINGS_MULT; ir_id = ir_id+1)
    begin: internal_ring   
    
      wire          xx_branch_d2r_stb  [0:BRANCH_NUM-1];
      wire          xx_branch_d2r_sof  [0:BRANCH_NUM-1];
      wire [71:0]   xx_branch_d2r_data [0:BRANCH_NUM-1];
      wire [ 1:0]   xx_branch_d2r_rdy  [0:BRANCH_NUM-1];
      wire [ 1:0]   xx_branch_d2r_rdyE [0:BRANCH_NUM-1];
      wire          xx_branch_r2d_stb  [0:BRANCH_NUM-1];
      wire          xx_branch_r2d_sof  [0:BRANCH_NUM-1];
      wire [71:0]   xx_branch_r2d_data [0:BRANCH_NUM-1];
      wire [ 1:0]   xx_branch_r2d_rdy  [0:BRANCH_NUM-1];
      
      for(br_id = 0; br_id < BRANCH_NUM; br_id = br_id+1)
      begin
        assign xx_branch_d2r_stb  [br_id] = x0_branch_d2r_stb [br_id][ir_id];
        assign xx_branch_d2r_sof  [br_id] = x0_branch_d2r_sof [br_id][ir_id];
    `assignB72(xx_branch_d2r_data [br_id] , x0_branch_d2r_data[br_id][ir_id])
    `assignB2 (x0_branch_d2r_rdy [br_id][ir_id] , xx_branch_d2r_rdy  [br_id])
    `assignB2 (x0_branch_d2r_rdyE[br_id][ir_id] , xx_branch_d2r_rdyE [br_id])
        
        assign x0_branch_r2d_stb  [br_id][ir_id] = xx_branch_r2d_stb [br_id];
        assign x0_branch_r2d_sof  [br_id][ir_id] = xx_branch_r2d_sof [br_id];
    `assignB72(x0_branch_r2d_data [br_id][ir_id] , xx_branch_r2d_data[br_id])
    `assignB2 (xx_branch_r2d_rdy [br_id] , x0_branch_r2d_rdy  [br_id][ir_id]) 
      end                                          
      
      rsbus_slice_rt_box 
      #(
      .BRANCH_NUM (BRANCH_NUM)
      )  
      root_slice_box
      (
      .rst               (rst),   
      .clk               (clk),
      .dbg               (dbg[ir_id]),
      
      // bootrom port                          
      .mem0_r2m_stb      (x0_mem0_r2m_stb [ir_id]),                 
      .mem0_r2m_sof      (x0_mem0_r2m_sof [ir_id]),               
      .mem0_r2m_data     (x0_mem0_r2m_data[ir_id]),
      .mem0_r2m_rdy      (x0_mem0_r2m_rdy [ir_id]), 
      
      .mem0_m2r_stb      (x0_mem0_m2r_stb [ir_id]),
      .mem0_m2r_sof      (x0_mem0_m2r_sof [ir_id]),
      .mem0_m2r_data     (x0_mem0_m2r_data[ir_id]),
      .mem0_m2r_rdy      (x0_mem0_m2r_rdy [ir_id]), 
      
      // ddr port        
      .mem1_r2m_stb      (x0_mem1_r2m_stb [ir_id]),
      .mem1_r2m_sof      (x0_mem1_r2m_sof [ir_id]),
      .mem1_r2m_data     (x0_mem1_r2m_data[ir_id]),                        
      .mem1_r2m_rdy      (x0_mem1_r2m_rdy [ir_id]),   
                                     
      .mem1_m2r_stb      (x0_mem1_m2r_stb [ir_id]),                                
      .mem1_m2r_sof      (x0_mem1_m2r_sof [ir_id]),
      .mem1_m2r_data     (x0_mem1_m2r_data[ir_id]),
      .mem1_m2r_rdy      (x0_mem1_m2r_rdy [ir_id]),

       // mutex                                         
      .mutex_r2m_stb     (x0_mutex_r2m_stb [ir_id]),  
      .mutex_r2m_sof     (x0_mutex_r2m_sof [ir_id]),  
      .mutex_r2m_data    (x0_mutex_r2m_data[ir_id]),  
      .mutex_r2m_rdy     (x0_mutex_r2m_rdy [ir_id]), 
      
      .mutex_m2r_stb     (x0_mutex_m2r_stb [ir_id]),  
      .mutex_m2r_sof     (x0_mutex_m2r_sof [ir_id]),  
      .mutex_m2r_data    (x0_mutex_m2r_data[ir_id]),  
      .mutex_m2r_rdy     (x0_mutex_m2r_rdy [ir_id]), 

       // reflector                              
      .ref_r2m_stb       (x0_ref_r2m_stb [ir_id]), 
      .ref_r2m_sof       (x0_ref_r2m_sof [ir_id]), 
      .ref_r2m_data      (x0_ref_r2m_data[ir_id]), 
      .ref_r2m_rdy       (x0_ref_r2m_rdy [ir_id]),
      
      .ref_m2r_stb       (x0_ref_m2r_stb [ir_id]), 
      .ref_m2r_sof       (x0_ref_m2r_sof [ir_id]), 
      .ref_m2r_data      (x0_ref_m2r_data[ir_id]), 
      .ref_m2r_rdy       (x0_ref_m2r_rdy [ir_id]), 

      //branches tables
      .branch_r2d_stb    (xx_branch_r2d_stb ),    
      .branch_r2d_sof    (xx_branch_r2d_sof ),    
      .branch_r2d_data   (xx_branch_r2d_data),    
      .branch_r2d_rdy    (xx_branch_r2d_rdy ),
      
      .branch_d2r_stb    (xx_branch_d2r_stb ),    
      .branch_d2r_sof    (xx_branch_d2r_sof ),    
      .branch_d2r_data   (xx_branch_d2r_data),    
      .branch_d2r_rdy    (xx_branch_d2r_rdy ),    
      .branch_d2r_rdyE   (xx_branch_d2r_rdyE), 

      .ff_err            (x0_shell_ff_err[ir_id]) 
      );                                       
    end  
endgenerate 
//==============================================================================================
// mutex mux/demux
//==============================================================================================
rbus_muxNto1
#(.N (RINGS_MULT)) 
mux_for_mutex
(                                                                                                                           
.clk       (clk),
.rst       (rst), 

.i_stb     (x0_mutex_r2m_stb ),                                                               
.i_sof     (x0_mutex_r2m_sof ),
.i_data    (x0_mutex_r2m_data), 
.i_rdy     (x0_mutex_r2m_rdy ), 
.i_rdyE    (                 ), 

.o_stb     (   mutex_r2m_stb ),
.o_sof     (   mutex_r2m_sof ),
.o_data    (   mutex_r2m_data),
.o_rdy     (   mutex_r2m_rdy ),
.o_rdyE    (   mutex_r2m_rdy ), // mutex do not support rdyE signals so rdy is connected

.ff_err    (mutex_ff_err[0])
); 
//---------------------------------------------------------------------------------------------- 
rbus_demux1toN
#(.N (RINGS_MULT)) 
demux_for_mutex
(                                                                                                                           
.clk       (clk),
.rst       (rst), 

.i_stb     (   mutex_m2r_stb ),                                                               
.i_sof     (   mutex_m2r_sof ),
.i_data    (   mutex_m2r_data),
.i_rdy     (   mutex_m2r_rdy ), 
.i_rdyE    (                 ), 

.o_stb     (x0_mutex_m2r_stb ),
.o_sof     (x0_mutex_m2r_sof ),
.o_data    (x0_mutex_m2r_data),
.o_rdy     (x0_mutex_m2r_rdy ), 
.o_rdyE    (x0_mutex_m2r_rdy ), // r2d do not support rdyE signals so rdy is connected

.ff_err    (mutex_ff_err[1])
); 
//==============================================================================================
// reflector mux/demux
//==============================================================================================
rbus_muxNto1
#(.N (RINGS_MULT)) 
mux_for_ref
(                                                                                                                           
.clk       (clk),
.rst       (rst), 

.i_stb     (x0_ref_r2m_stb ),                                                               
.i_sof     (x0_ref_r2m_sof ),
.i_data    (x0_ref_r2m_data),
.i_rdy     (x0_ref_r2m_rdy ), 
.i_rdyE    (               ), 

.o_stb     (   ref_r2m_stb ),
.o_sof     (   ref_r2m_sof ),
.o_data    (   ref_r2m_data),
.o_rdy     (   ref_r2m_rdy ),
.o_rdyE    (   ref_r2m_rdy ), // reflector do not support rdyE signals so rdy is connected

.ff_err    (ref_ff_err[0])
); 
//---------------------------------------------------------------------------------------------- 
rbus_demux1toN
#(.N (RINGS_MULT)) 
demux_for_ref
(                                                                                                                           
.clk       (clk),
.rst       (rst), 

.i_stb     (   ref_m2r_stb ),                                                               
.i_sof     (   ref_m2r_sof ),
.i_data    (   ref_m2r_data),
.i_rdy     (   ref_m2r_rdy ), 
.i_rdyE    (               ), 

.o_stb     (x0_ref_m2r_stb ),
.o_sof     (x0_ref_m2r_sof ),
.o_data    (x0_ref_m2r_data),
.o_rdy     (x0_ref_m2r_rdy ),  
.o_rdyE    (x0_ref_m2r_rdy ), // r2d do not support rdyE signals so rdy is connected

.ff_err    (ref_ff_err[1])
); 
//==============================================================================================
// mem0 mux/demux
//==============================================================================================
rbus_muxNto1
#(.N (RINGS_MULT)) 
mux_for_mem0
(                                                                                                                           
.clk       (clk),
.rst       (rst), 

.i_stb     (x0_mem0_r2m_stb ),                                                               
.i_sof     (x0_mem0_r2m_sof ),
.i_data    (x0_mem0_r2m_data),
.i_rdy     (x0_mem0_r2m_rdy ), 
.i_rdyE    (                ), 

.o_stb     (   mem0_r2m_stb ),
.o_sof     (   mem0_r2m_sof ),
.o_data    (   mem0_r2m_data),
.o_rdy     (   mem0_r2m_rdy ),
.o_rdyE    (   mem0_r2m_rdy ), // memory interface do not support rdyE signals so rdy is connected

.ff_err    (mem0_ff_err[0])
); 
//---------------------------------------------------------------------------------------------- 
rbus_demux1toN
#(.N (RINGS_MULT)) 
demux_for_mem0
(                                                                                                                           
.clk       (clk),
.rst       (rst), 

.i_stb     (   mem0_m2r_stb ),                                                               
.i_sof     (   mem0_m2r_sof ),
.i_data    (   mem0_m2r_data),
.i_rdy     (   mem0_m2r_rdy ), 
.i_rdyE    (                ), 

.o_stb     (x0_mem0_m2r_stb ),
.o_sof     (x0_mem0_m2r_sof ),
.o_data    (x0_mem0_m2r_data),
.o_rdy     (x0_mem0_m2r_rdy ),
.o_rdyE    (x0_mem0_m2r_rdy ), // r2d do not support rdyE signals so rdy is connected

.ff_err    (mem0_ff_err[1])
); 
//==============================================================================================
// MEM1 m2r channels number reduction
//==============================================================================================
rbus_muxNtoM
#(
.N (MEM1_EXTERNAL_PORT_MULT),
.M (RINGS_MULT)
) 
mem1_m2r_channels_change
(                                                                                                                           
.clk       (clk),
.rst       (rst), 

.i_stb     (   mem1_m2r_stb ),                                                               
.i_sof     (   mem1_m2r_sof ),
.i_data    (   mem1_m2r_data),
.i_rdy     (   mem1_m2r_rdy ), 
.i_rdyE    (                ),

.o_stb     (x0_mem1_m2r_stb ),
.o_sof     (x0_mem1_m2r_sof ),
.o_data    (x0_mem1_m2r_data),
.o_rdy     (x0_mem1_m2r_rdy ),
.o_rdyE    (x0_mem1_m2r_rdy ),  // r2d do not support rdyE signals so rdy is connected

.ff_err    (mem1_ff_err[0])
);   
//==============================================================================================
// MEM1 r2m channels expansion
//==============================================================================================
rbus_muxNtoM
#(
.N (RINGS_MULT),
.M (MEM1_EXTERNAL_PORT_MULT)
) 
mem1_r2m_channels_change
(                                                                                                                           
.clk       (clk),
.rst       (rst), 

.i_stb     (x0_mem1_r2m_stb ),                                                               
.i_sof     (x0_mem1_r2m_sof ),
.i_data    (x0_mem1_r2m_data),   
.i_rdy     (x0_mem1_r2m_rdy ), 
.i_rdyE    (                ), 

.o_stb     (   mem1_r2m_stb ),
.o_sof     (   mem1_r2m_sof ),
.o_data    (   mem1_r2m_data), 
.o_rdy     (   mem1_r2m_rdy ),
.o_rdyE    (   mem1_r2m_rdy ), // memory interface do not support rdyE signals so rdy is connected
                    
.ff_err    (mem1_ff_err[1])
); 
//==============================================================================================
// branches channels assign
//==============================================================================================
generate 
for (br_id = 0; br_id < BRANCH_NUM; br_id = br_id + 1)
  begin : branch_mux                                               
    // d2r mux                                                   
    for(ir_id = 0; ir_id < RINGS_MULT; ir_id = ir_id+1)
    begin
      assign x0_branch_d2r_stb [br_id][ir_id] = branch_d2r_stb    [br_id][ir_id];
      assign x0_branch_d2r_sof [br_id][ir_id] = branch_d2r_sof    [br_id][ir_id];
  //`assignB72(x0_branch_d2r_data[br_id][ir_id] , branch_d2r_data   [br_id][ir_id])
  //`assignB2 (   branch_d2r_rdy [br_id][ir_id] , x0_branch_d2r_rdy [br_id][ir_id]);
      assign x0_branch_d2r_data[br_id][ir_id] = branch_d2r_data   [br_id][ir_id];
      assign    branch_d2r_rdy [br_id][ir_id] = x0_branch_d2r_rdy [br_id][ir_id];
      assign    branch_d2r_rdyE[br_id][ir_id] = x0_branch_d2r_rdyE[br_id][ir_id];
    end   
    //======================================================================================
    // r2d mux     
    for(ir_id = 0; ir_id < RINGS_MULT; ir_id = ir_id+1)
    begin                                                                       
      assign    branch_r2d_stb [br_id][ir_id] = x0_branch_r2d_stb [br_id][ir_id];
      assign    branch_r2d_sof [br_id][ir_id] = x0_branch_r2d_sof [br_id][ir_id];
  //`assignB72(   branch_r2d_data[br_id][ir_id] , x0_branch_r2d_data[br_id][ir_id])
  //`assignB2 (x0_branch_r2d_rdy [br_id][ir_id] ,    branch_r2d_rdy [br_id][ir_id])
      assign    branch_r2d_data[br_id][ir_id] = x0_branch_r2d_data[br_id][ir_id];
      assign x0_branch_r2d_rdy [br_id][ir_id] =    branch_r2d_rdy [br_id][ir_id];
    end
    
  end
endgenerate 
//============================================================================================== 
always @(posedge clk or posedge rst)                                                            
if(rst                     ) ff_err_reg <=                                                 1'b0;           
else if( |x0_shell_ff_err  ) ff_err_reg <=                                                 1'b1; // ff error from internal rings
else if( |mutex_ff_err     ) ff_err_reg <=                                                 1'b1; // ff error from mutex mux/demux
else if( |ref_ff_err       ) ff_err_reg <=                                                 1'b1; // ff error from reflector mux/demux
else if( |mem0_ff_err      ) ff_err_reg <=                                                 1'b1; // ff error from mem0 mux/demux
else if( |mem1_ff_err      ) ff_err_reg <=                                                 1'b1; // ff error from mem1 mux/demux
else                         ff_err_reg <=                                           ff_err_reg;
//---------------------------------------------------------------------------------------------- 
assign ff_err =                                                                      ff_err_reg;
//==============================================================================================

endmodule            