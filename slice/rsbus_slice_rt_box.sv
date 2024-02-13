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
`include "mem_spaces.vh"
//==============================================================================================

module rsbus_slice_rt_box
#
(
parameter             BRANCH_NUM = 4
)  
(
 input  wire          rst,                              /*synthesis syn_keep=1*/
 input  wire          clk,                              /*synthesis syn_keep=1*/
                                                    
 output wire  [15:0]  dbg,                              /*synthesis syn_keep=1*/       
                                                    
 // bootrom/flash port                              
                                                    
 output wire          mem0_r2m_stb,                       /*synthesis syn_keep=1*/
 output wire          mem0_r2m_sof,                       /*synthesis syn_keep=1*/
 output wire [71:0]   mem0_r2m_data,                      /*synthesis syn_keep=1*/                           
 input  wire  [ 1:0]  mem0_r2m_rdy,                        /*synthesis syn_keep=1*/
                                                    
 input  wire          mem0_m2r_stb,                       /*synthesis syn_keep=1*/
 input  wire          mem0_m2r_sof,                       /*synthesis syn_keep=1*/
 input  wire [71:0]   mem0_m2r_data,                      /*synthesis syn_keep=1*/  
 output wire  [ 1:0]  mem0_m2r_rdy,                        /*synthesis syn_keep=1*/  
                                                    
 // external RAM port (DDR)                         
                                                    
 output wire          mem1_r2m_stb,                       /*synthesis syn_keep=1*/
 output wire          mem1_r2m_sof,                       /*synthesis syn_keep=1*/
 output wire [71:0]   mem1_r2m_data,                      /*synthesis syn_keep=1*/
 input  wire  [ 1:0]  mem1_r2m_rdy,                        /*synthesis syn_keep=1*/
                                                    
 input  wire          mem1_m2r_stb,                       /*synthesis syn_keep=1*/
 input  wire          mem1_m2r_sof,                       /*synthesis syn_keep=1*/
 input  wire [71:0]   mem1_m2r_data,                      /*synthesis syn_keep=1*/
 output wire  [ 1:0]  mem1_m2r_rdy,                        /*synthesis syn_keep=1*/
                                                    
 // mutex                                           
                                                    
 output wire          mutex_r2m_stb,                       /*synthesis syn_keep=1*/
 output wire          mutex_r2m_sof,                       /*synthesis syn_keep=1*/
 output wire [71:0]   mutex_r2m_data,                      /*synthesis syn_keep=1*/
 input  wire  [ 1:0]  mutex_r2m_rdy,                        /*synthesis syn_keep=1*/
                                                    
 input  wire          mutex_m2r_stb,                       /*synthesis syn_keep=1*/
 input  wire          mutex_m2r_sof,                       /*synthesis syn_keep=1*/
 input  wire [71:0]   mutex_m2r_data,                      /*synthesis syn_keep=1*/
 output wire  [ 1:0]  mutex_m2r_rdy,                        /*synthesis syn_keep=1*/
                                                    
 // reflector                                       
                                                    
 output wire          ref_r2m_stb,                         /*synthesis syn_keep=1*/
 output wire          ref_r2m_sof,                         /*synthesis syn_keep=1*/
 output wire [71:0]   ref_r2m_data,                        /*synthesis syn_keep=1*/
 input  wire  [ 1:0]  ref_r2m_rdy,                          /*synthesis syn_keep=1*/
                                                    
 input  wire          ref_m2r_stb,                         /*synthesis syn_keep=1*/
 input  wire          ref_m2r_sof,                         /*synthesis syn_keep=1*/
 input  wire [71:0]   ref_m2r_data,                        /*synthesis syn_keep=1*/
 output wire  [ 1:0]  ref_m2r_rdy,                          /*synthesis syn_keep=1*/

 // branches
 
 input  wire          branch_d2r_stb  [BRANCH_NUM-1:0],  /*synthesis syn_keep=1*/
 input  wire          branch_d2r_sof  [BRANCH_NUM-1:0],  /*synthesis syn_keep=1*/
 input  wire [71:0]   branch_d2r_data [BRANCH_NUM-1:0],  /*synthesis syn_keep=1*/
 output wire  [ 1:0]  branch_d2r_rdy   [BRANCH_NUM-1:0],  /*synthesis syn_keep=1*/
 output wire  [ 1:0]  branch_d2r_rdyE  [BRANCH_NUM-1:0],  /*synthesis syn_keep=1*/
 
 output wire          branch_r2d_stb  [BRANCH_NUM-1:0],  /*synthesis syn_keep=1*/
 output wire          branch_r2d_sof  [BRANCH_NUM-1:0],  /*synthesis syn_keep=1*/
 output wire [71:0]   branch_r2d_data [BRANCH_NUM-1:0],  /*synthesis syn_keep=1*/
 input  wire  [ 1:0]  branch_r2d_rdy   [BRANCH_NUM-1:0],  /*synthesis syn_keep=1*/ 

 output wire          ff_err              /*synthesis syn_keep=1*/
);    
//==============================================================================================
// variables                                                  
//==============================================================================================   
wire         d2r_sof  [0:9+BRANCH_NUM];
wire  [11:0] d2r_ctrl [0:9+BRANCH_NUM]; 
wire  [71:0] d2r_data [0:9+BRANCH_NUM]; 
                                               
wire         d2r_active      [0:9+BRANCH_NUM];
wire         d2r_active_l    [0:9+BRANCH_NUM];
wire         d2r_active_s    [0:9+BRANCH_NUM];    
wire         d2r_owned       [0:9+BRANCH_NUM];    
wire         d2r_ctrl_req    [0:9+BRANCH_NUM];    
wire         d2r_ctrl_req_l  [0:9+BRANCH_NUM];    
wire         d2r_ctrl_req_s  [0:9+BRANCH_NUM]; 
wire         d2r_ctrl_res    [0:9+BRANCH_NUM]; 
wire         d2r_ctrl_res_l  [0:9+BRANCH_NUM]; 
wire         d2r_ctrl_res_s  [0:9+BRANCH_NUM]; 
//---------------------------------------------------------------------------------------------- 
generate 
genvar d2r_id;
for (d2r_id = 0; d2r_id <= 9+BRANCH_NUM; d2r_id = d2r_id+1)
  begin: simulation_signals                                                 
    assign d2r_active   [d2r_id] =  d2r_sof[d2r_id] & d2r_data[d2r_id][71];                        
    assign d2r_active_l [d2r_id] =  d2r_sof[d2r_id] & d2r_data[d2r_id][71] &  d2r_data[d2r_id][39];
    assign d2r_active_s [d2r_id] =  d2r_sof[d2r_id] & d2r_data[d2r_id][71] & !d2r_data[d2r_id][39];                          
    assign d2r_owned    [d2r_id] =  d2r_sof[d2r_id] & d2r_data[d2r_id][71] &  d2r_data[d2r_id][70];   
    assign d2r_ctrl_req   [d2r_id] = !d2r_sof[d2r_id] & d2r_ctrl[d2r_id][11];
    assign d2r_ctrl_req_l [d2r_id] = !d2r_sof[d2r_id] & d2r_ctrl[d2r_id][11] &  d2r_ctrl[d2r_id][10];
    assign d2r_ctrl_req_s [d2r_id] = !d2r_sof[d2r_id] & d2r_ctrl[d2r_id][11] & !d2r_ctrl[d2r_id][10]; 
    assign d2r_ctrl_res   [d2r_id] =  d2r_sof[d2r_id] & d2r_ctrl[d2r_id][11];
    assign d2r_ctrl_res_l [d2r_id] =  d2r_sof[d2r_id] & d2r_ctrl[d2r_id][11] &  d2r_ctrl[d2r_id][10];
    assign d2r_ctrl_res_s [d2r_id] =  d2r_sof[d2r_id] & d2r_ctrl[d2r_id][11] & !d2r_ctrl[d2r_id][10];
  end
endgenerate
//---------------------------------------------------------------------------------------------- 
wire         r2d_sof  [0:9+BRANCH_NUM];
wire  [71:0] r2d_data [0:9+BRANCH_NUM];
  
//---------------------------------------------------------------------------------------------- 
wire [11:0]  d2r_ctrl_x [0:9+BRANCH_NUM]; 
wire [71:0]  d2r_bus_x  [0:9+BRANCH_NUM]; 
wire [71:0]  r2d_bus_x  [0:9+BRANCH_NUM]; 
genvar jj;
for(jj = 0; jj<9+BRANCH_NUM+1; jj=jj+1)
begin
assign  d2r_ctrl_x [jj] = d2r_ctrl[jj];
assign  d2r_bus_x  [jj] = d2r_data [jj];
assign  r2d_bus_x  [jj] = r2d_data [jj];
end

//----------------------------------------------------------------------------------------------        
wire [BRANCH_NUM-1:0] branch_inj_ff_err ;  
//----------------------------------------------------------------------------------------------  
 reg         ff_ovr_err;
//==============================================================================================
// Frame  generator for D2R ring
//==============================================================================================
rsbus_frame_generator d2r_frame_generator
(
.clk            (clk),
.rst            (rst),                                          
                                                            
.i_sof          (d2r_sof  [0]),
.i_ctrl         (d2r_ctrl [0]),
.i_bus          (d2r_data [0]),   

.o_sof          (d2r_sof  [1]),
.o_ctrl         (d2r_ctrl [1]),
.o_bus          (d2r_data [1])
); 
//..............................................................................................
assign           r2d_sof  [1]   =                                                  r2d_sof  [0];
assign           r2d_data [1]   =                                                  r2d_data [0];
//==============================================================================================
// RBUS access manager
//==============================================================================================
wire d2r_mgr_ff_err;
rsbus_d2r_mgr 
#(
.FF_DEPTH          ((BRANCH_NUM > 8)? 64 : ((BRANCH_NUM > 4)? 32 : 16)),     
// if ff depth is set as above than internal ffs can not overflow because d2r_injectors can 
// insert only 4 requests so it gives #(BRANCH_NUM*4) requests of each packets type 
// (various combinations of length and priority)
// Situation changed because of additional slots for packets with packet priority 3 that
// are now available in d2r_injectors. If an unlikely situation occures and all devices in a ring 
// sends packets with PP3 than a total number of those types of request can be #(BRANCH_NUM*5) for 
// a long packets and #(BRANCH_NUM*6) for a short packets. This situation is indeed very unlikely 
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
.i_bus          (d2r_data [1]),
            
.o_sof          (d2r_sof  [2]),
.o_ctrl         (d2r_ctrl [2]),
.o_bus          (d2r_data [2]),

.ff_err         (d2r_mgr_ff_err)
); 
//..............................................................................................
assign           r2d_sof [2] = r2d_sof [1];
assign           r2d_data[2] = r2d_data[1];
//==============================================================================================
// memory address map PHY->LOGICAL
//==============================================================================================
shell_mem_map
#(     
 .DIRECTION("PHY2LOG")
)
mem_map_phy2log
(
.clk            (clk),
.rst            (rst),    
 
.i_sof          (r2d_sof  [2]),
.i_ctrl         (12'd0),
.i_data         (r2d_data [2]),   
            
.o_sof          (r2d_sof  [3]),
.o_ctrl         (),
.o_data         (r2d_data [3])
);                
//..............................................................................................
assign           d2r_sof  [3]   =                                                  d2r_sof  [2];
assign           d2r_ctrl [3]   =                                                  d2r_ctrl [2];
assign           d2r_data [3]   =                                                  d2r_data [2];
//==============================================================================================
// branch 0
//==============================================================================================
genvar i;
generate
  for(i=0; i<BRANCH_NUM; i=i+1)
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
                                                                 
        .i_sof          (r2d_sof [3+i]),                         
        .i_bus          (r2d_data[3+i]),                         
                                                                 
        .o_sof          (r2d_sof [4+i]),                         
        .o_bus          (r2d_data[4+i]),                         
        
        .frm_o_stb      (branch_r2d_stb[i]),  
        .frm_o_sof      (branch_r2d_sof[i]),  
        .frm_o_iid      (),
        .frm_o_bus      (branch_r2d_data[i]),
        .frm_o_rdy      (branch_r2d_rdy[i])
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
        
        .frm_i_stb      (branch_d2r_stb[i]),                                                               
        .frm_i_sof      (branch_d2r_sof[i]),
        .frm_i_iid      (4'd0),
        .frm_i_bus      (branch_d2r_data[i]),
        .frm_i_rdy      (branch_d2r_rdy[i]), 
        .frm_i_rdyE     (branch_d2r_rdyE[i]),   
                        
        .i_sof          (d2r_sof  [3+i]),
        .i_ctrl         (d2r_ctrl [3+i]),
        .i_bus          (d2r_data [3+i]),
                                      
        .o_sof          (d2r_sof  [4+i]),
        .o_ctrl         (d2r_ctrl [4+i]),
        .o_bus          (d2r_data [4+i]),
        
        .ff_err         (branch_inj_ff_err[i])
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
                                                            
.i_sof          (r2d_sof  [3+BRANCH_NUM]),
.i_ctrl         (12'd0),
.i_bus          (r2d_data [3+BRANCH_NUM]),   

.o_sof          (r2d_sof  [4+BRANCH_NUM]),
.o_ctrl         (),
.o_bus          (r2d_data [4+BRANCH_NUM])
); 
//..............................................................................................
assign           d2r_sof  [4+BRANCH_NUM]   =                            d2r_sof  [3+BRANCH_NUM];                                                                    
assign           d2r_ctrl [4+BRANCH_NUM]   =                            d2r_ctrl [3+BRANCH_NUM];
assign           d2r_data [4+BRANCH_NUM]   =                            d2r_data [3+BRANCH_NUM];
//==============================================================================================
// memory address map LOGICAL->PHY
//==============================================================================================
shell_mem_map
#(
  .DIRECTION("LOG2PHY")
)
mem_map_log2phy
(
.clk            (clk),
.rst            (rst),   

.i_sof          (d2r_sof  [4+BRANCH_NUM]),
.i_ctrl         (d2r_ctrl [4+BRANCH_NUM]),
.i_data         (d2r_data [4+BRANCH_NUM]),   
              
.o_sof          (d2r_sof  [5+BRANCH_NUM]),
.o_ctrl         (d2r_ctrl [5+BRANCH_NUM]),
.o_data         (d2r_data [5+BRANCH_NUM])
);                
//..............................................................................................
assign           r2d_sof  [5+BRANCH_NUM]   =                            r2d_sof  [4+BRANCH_NUM];
assign           r2d_data [5+BRANCH_NUM]   =                            r2d_data [4+BRANCH_NUM];
//==============================================================================================
// mutex manager                                                                            
//==============================================================================================
generate
wire           mux_inj_ff_err; 
begin : MUTEX

    rsbus_d2r_extractor                                                                          
    #(                                                                                           
    .SPACE_CHECKING      ("ON"),                                                                 
    .SPACE_START_ADDRESS (`MEM_SP_MUTEX_START_PHY),                                              
    .SPACE_LAST_ADDRESS  (`MEM_SP_MUTEX_START_PHY + `MEM_SP_MUTEX_LEN - 39'd1)                     
    )                                                                                           
    d2r_extractor                                                                               	
    (                                                                                            
    .clk            (clk),                                                                       
    .rst            (rst),                                                                       
                                          
    .i_sof          (d2r_sof  [5+BRANCH_NUM]),
    .i_ctrl         (d2r_ctrl [5+BRANCH_NUM]),
    .i_bus          (d2r_data [5+BRANCH_NUM]),
                                          
    .o_sof          (d2r_sof  [6+BRANCH_NUM]),
    .o_ctrl         (d2r_ctrl [6+BRANCH_NUM]),
    .o_bus          (d2r_data [6+BRANCH_NUM]),
    
    .frm_o_stb      (mutex_r2m_stb),
    .frm_o_sof      (mutex_r2m_sof),
    .frm_o_bus      (mutex_r2m_data),
    .frm_o_rdy      (mutex_r2m_rdy),
    .frm_o_rdyE     (mutex_r2m_rdy) // connected to device that do not support rdyE signals so rdy is connected
    );

    rsbus_r2d_injector r2d_injector
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   

    .frm_i_stb      (mutex_m2r_stb), 
    .frm_i_sof      (mutex_m2r_sof), 
    .frm_i_bus      (mutex_m2r_data),
    .frm_i_rdy      (mutex_m2r_rdy),  
    
    .i_sof          (r2d_sof [5+BRANCH_NUM]),
    .i_bus          (r2d_data[5+BRANCH_NUM]),
                                                     
    .o_sof          (r2d_sof [6+BRANCH_NUM]),
    .o_bus          (r2d_data[6+BRANCH_NUM]), 
    
    .ff_err         (mux_inj_ff_err)
    );                                
end                                                                                 
//==============================================================================================
// system reflector
//============================================================================================== 
wire           ref_inj_ff_err;
begin : REFLECTOR
  
    rsbus_d2r_extractor       
    #(                                     
    .SPACE_CHECKING      ("ON"),      
    .SPACE_START_ADDRESS (`MEM_SP_REFLECTOR_START_PHY),
    .SPACE_LAST_ADDRESS  (`MEM_SP_REFLECTOR_START_PHY + `MEM_SP_REFLECTOR_LEN - 39'd1)
    )
    d2r_extractor
    (
    .clk            (clk),
    .rst            (rst), 
                                          
    .i_sof          (d2r_sof  [6+BRANCH_NUM]),
    .i_ctrl         (d2r_ctrl [6+BRANCH_NUM]),
    .i_bus          (d2r_data [6+BRANCH_NUM]),
                                          
    .o_sof          (d2r_sof  [7+BRANCH_NUM]),
    .o_ctrl         (d2r_ctrl [7+BRANCH_NUM]),
    .o_bus          (d2r_data [7+BRANCH_NUM]),
                    
    .frm_o_stb      (ref_r2m_stb),
    .frm_o_sof      (ref_r2m_sof),
    .frm_o_bus      (ref_r2m_data),
    .frm_o_rdy      (ref_r2m_rdy),
    .frm_o_rdyE     (ref_r2m_rdy) // connected to device that do not support rdyE signals so rdy is connected
    );                                                     

    rsbus_r2d_injector r2d_injector
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   

    .frm_i_stb      (ref_m2r_stb),
    .frm_i_sof      (ref_m2r_sof),  
    .frm_i_bus      (ref_m2r_data),
    .frm_i_rdy      (ref_m2r_rdy), 
                    
    .i_sof          (r2d_sof  [6+BRANCH_NUM]),
    .i_bus          (r2d_data [6+BRANCH_NUM]),
                                                     
    .o_sof          (r2d_sof  [7+BRANCH_NUM]),
    .o_bus          (r2d_data [7+BRANCH_NUM]), 
    
    .ff_err         (ref_inj_ff_err)
    );                                
end 
//==============================================================================================
// bootrom 
//==============================================================================================   
wire           mem0_inj_ff_err;
begin : BOOTROM                    

    rsbus_d2r_extractor       
    #(                                           
    .SPACE_CHECKING       ("ON"),                         
    .SPACE_START_ADDRESS (`MEM_SP_BOOTROM_START_PHY),
    .SPACE_LAST_ADDRESS  (`MEM_SP_BOOTROM_START_PHY + `MEM_SP_BOOTROM_LEN - 39'd1)
    )
    d2r_extractor
    (
    .clk            (clk),
    .rst            (rst), 
                                          
    .i_sof          (d2r_sof  [7+BRANCH_NUM]),
    .i_ctrl         (d2r_ctrl [7+BRANCH_NUM]),
    .i_bus          (d2r_data [7+BRANCH_NUM]),
                                                        
    .o_sof          (d2r_sof  [8+BRANCH_NUM]),
    .o_ctrl         (d2r_ctrl [8+BRANCH_NUM]),
    .o_bus          (d2r_data [8+BRANCH_NUM]),                  
                    
    .frm_o_stb      (mem0_r2m_stb),   
    .frm_o_sof      (mem0_r2m_sof),   
    .frm_o_bus      (mem0_r2m_data),  
    .frm_o_rdy      (mem0_r2m_rdy),
    .frm_o_rdyE     (mem0_r2m_rdy) // connected to device that do not support rdyE signals so rdy is connected     
    );              
    
    rsbus_r2d_injector r2d_injector
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   

    .frm_i_stb      (mem0_m2r_stb),
    .frm_i_sof      (mem0_m2r_sof),
    .frm_i_bus      (mem0_m2r_data),
    .frm_i_rdy      (mem0_m2r_rdy),  
                    
    .i_sof          (r2d_sof  [7+BRANCH_NUM]),
    .i_bus          (r2d_data [7+BRANCH_NUM]),
                                                     
    .o_sof          (r2d_sof  [8+BRANCH_NUM]),
    .o_bus          (r2d_data [8+BRANCH_NUM]), 
    
    .ff_err         (mem0_inj_ff_err)
    );                                
end                                                                                 
//==============================================================================================
// mem interface
//==============================================================================================    
wire           mem1_inj_ff_err;
begin : MEMORY                      

    rsbus_d2r_extractor       
    #(                                           
    .SPACE_CHECKING      ("ON"),                     
    .SPACE_START_ADDRESS (`MEM_SP_KERNEL_START_PHY),
    .SPACE_LAST_ADDRESS  (`MEM_SP_USER_START_PHY + `MEM_SP_USER_LEN - 39'd1)
    )
    d2r_extractor
    (
    .clk            (clk),
    .rst            (rst), 
                                          
    .i_sof          (d2r_sof  [8+BRANCH_NUM]),
    .i_ctrl         (d2r_ctrl [8+BRANCH_NUM]),
    .i_bus          (d2r_data [8+BRANCH_NUM]),
                                                        
    .o_sof          (d2r_sof  [9+BRANCH_NUM]),
    .o_ctrl         (d2r_ctrl [9+BRANCH_NUM]),
    .o_bus          (d2r_data [9+BRANCH_NUM]),                  
                    
    .frm_o_stb      (mem1_r2m_stb),   
    .frm_o_sof      (mem1_r2m_sof),   
    .frm_o_bus      (mem1_r2m_data),  
    .frm_o_rdy      (mem1_r2m_rdy) ,
    .frm_o_rdyE     (mem1_r2m_rdy) // connected to device that do not support rdyE signals so rdy is connected      
    );              
    
    rsbus_r2d_injector r2d_injector
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   

    .frm_i_stb      (mem1_m2r_stb),
    .frm_i_sof      (mem1_m2r_sof),
    .frm_i_bus      (mem1_m2r_data),
    .frm_i_rdy      (mem1_m2r_rdy),  
                    
    .i_sof          (r2d_sof  [8+BRANCH_NUM]),
    .i_bus          (r2d_data [8+BRANCH_NUM]),
                                                     
    .o_sof          (r2d_sof  [9+BRANCH_NUM]),
    .o_bus          (r2d_data [9+BRANCH_NUM]), 
    
    .ff_err         (mem1_inj_ff_err)
    );                                
end                                                                                 
endgenerate
//==============================================================================================
// mem interface
//==============================================================================================
wire devnull_active;                                                                           
//----------------------------------------------------------------------------------------------
rsbus_devnull
#(                                     
  .SEND_WR_FB  ("TRUE") 
)
DEVNULL
(
  .clk              (clk),       
  .rst              (rst),   

  // internal ring  
  .d2r_i_sof       (d2r_sof  [9+BRANCH_NUM]),
  .d2r_i_ctrl      (d2r_ctrl [9+BRANCH_NUM]),
  .d2r_i_bus       (d2r_data  [9+BRANCH_NUM]), 
  
  .d2r_o_sof       (d2r_sof  [0]),
  .d2r_o_ctrl      (d2r_ctrl [0]),
  .d2r_o_bus       (d2r_data [0]),
   
  .r2d_i_sof       (r2d_sof  [9+BRANCH_NUM]),
  .r2d_i_bus       (r2d_data [9+BRANCH_NUM]), 
    
  .r2d_o_sof       (r2d_sof  [0]),
  .r2d_o_bus       (r2d_data [0]),

  .pkt_intercepted (devnull_active)
);                                                                                          
//============================================================================================== 
always @(posedge clk or posedge rst)                                                            
if(rst                     ) ff_ovr_err <=                                                 1'b0;           
else if( |branch_inj_ff_err) ff_ovr_err <=                                                 1'b1; // ff for data from branches                    
else if( d2r_mgr_ff_err    ) ff_ovr_err <=                                                 1'b1; 
else if( mem0_inj_ff_err   ) ff_ovr_err <=                                                 1'b1; // ff for data from memory0  
else if( mem1_inj_ff_err   ) ff_ovr_err <=                                                 1'b1; // ff for data from memory1   
else if( ref_inj_ff_err    ) ff_ovr_err <=                                                 1'b1; // ff for data from reflector  
else if( mux_inj_ff_err    ) ff_ovr_err <=                                                 1'b1; // ff for data from mutex   
else                         ff_ovr_err <=                                           ff_ovr_err;
//---------------------------------------------------------------------------------------------- 
assign ff_err =                                                                      ff_ovr_err;
//---------------------------------------------------------------------------------------------- 
reg [BRANCH_NUM-1+5:0] ff_err_rsn;
always @(posedge clk or posedge rst)                                                            
if(rst                     ) ff_err_rsn <=                                                  'd0;
else                         ff_err_rsn <= ff_err_rsn | {branch_inj_ff_err, d2r_mgr_ff_err, mem0_inj_ff_err, mem1_inj_ff_err, ref_inj_ff_err, mux_inj_ff_err};
//==============================================================================================
assign dbg = {
       ff_err_rsn,
       devnull_active, branch_d2r_rdy[0][1:0], 
       mem1_r2m_rdy[1:0],        mem1_r2m_rdy[1:0]
       //to_ref_rdy[1:0],    from_ref_rdy[1:0]
       };                                                                            
//==============================================================================================

endmodule            