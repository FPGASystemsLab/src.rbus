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

module rsbus_slice_tg_box
(
 input  wire            clk,                    /*synthesis syn_keep=1*/
 input  wire            rst,                    /*synthesis syn_keep=1*/

 input  wire            i_stb,                  /*synthesis syn_keep=1*/
 input  wire            i_sof,                  /*synthesis syn_keep=1*/
 input  wire    [71:0]  i_bus,                  /*synthesis syn_keep=1*/
 output wire     [1:0]  i_rdy,                   /*synthesis syn_keep=1*/  
                                
 output wire            o_stb,                  /*synthesis syn_keep=1*/
 output wire            o_sof,                  /*synthesis syn_keep=1*/
 output wire    [71:0]  o_bus,                  /*synthesis syn_keep=1*/
 input  wire     [1:0]  o_rdy,                   /*synthesis syn_keep=1*/
 input  wire     [1:0]  o_rdyE,                  /*synthesis syn_keep=1*/
 
 output wire            ff_err                  /*synthesis syn_keep=1*/ 
);                                                                                                                                                                  
//==============================================================================================
// local param
//==============================================================================================
parameter           READ_PP0_DELAY_M100     =                                           100_000;  
parameter           READ_PP1_DELAY_M100     =                                           100_000;  
parameter           READ_PP2_DELAY_M100     =                                           100_000;  
parameter           READ_PP3_DELAY_M100     =                                           100_000;    
parameter           WRITE_PP0_DELAY_M100    =                                           100_000;   
parameter           WRITE_PP1_DELAY_M100    =                                           100_000;   
parameter           WRITE_PP2_DELAY_M100    =                                           100_000;   
parameter           WRITE_PP3_DELAY_M100    =                                           100_000;  
parameter           TGEN_NUM                =                                               'd1; 
//==============================================================================================
// variables
//==============================================================================================    
wire            d2r_sof  [TGEN_NUM+3:0];
wire    [11:0]  d2r_ctrl [TGEN_NUM+3:0];
wire    [71:0]  d2r_bus  [TGEN_NUM+3:0];
//---------------------------------------------------------------------------------------------- 
wire            r2d_sof  [TGEN_NUM+3:0];
wire    [71:0]  r2d_bus  [TGEN_NUM+3:0];
//----------------------------------------------------------------------------------------------  
wire[TGEN_NUM-1:0]d2r_inf_ff_err; 
wire            d2r_mgr_ff_err; 
wire            r2d_inj_ff_err;
reg             ff_ovr_err;
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
.FF_DEPTH          ((TGEN_NUM > 8)? 64 : ((TGEN_NUM > 4)? 32 : 16)),      
// if ff depth is set as above than internal ffs can not overflow because d2r_injectors can 
// insert only 4 requests so it gives #(TGEN_NUM*4) requests of each packets type 
// (various combinations of length and priority)
// Situation changed because of additional slots for packets with packet priority 3 that
// are now available in d2r_injectors. If an unlikely situation occures and all devices in a ring 
// sends packets with PP3 than a total number of those types of request can be #(TGEN_NUM*5) for 
// a long packets and #(TGEN_NUM*6) for a short packets. This situation is indeed very unlikely 
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

.ff_err         (d2r_mgr_ff_err)
); 
//..............................................................................................
assign           r2d_sof [2] = r2d_sof [1];
assign           r2d_bus [2] = r2d_bus [1];
//==============================================================================================
// risc core
//==============================================================================================
generate        
genvar i;
    for(i=0;i<TGEN_NUM;i=i+1)                                                     
        begin : TRAFFIC_GENERATOR                  
            integer                 to_root_rd_cnt;
            integer                 to_root_wr_cnt;  
            wire                    to_root_stb;
            wire                    to_root_sof;
            wire             [3:0]  to_root_iid;
            wire            [71:0]  to_root_data;
            wire             [1:0]  to_root_rdy; 
            wire             [1:0]  to_root_rdyE;                                                                                                                                                                                                   
                                                   
            integer                 from_root_rd_cnt;
            integer                 from_root_wr_cnt;
            wire                    from_root_stb;
            wire                    from_root_sof;
            wire             [3:0]  from_root_iid;
            wire            [71:0]  from_root_data;
            wire             [1:0]  from_root_rdy;
      
            rsbus_r2d_extractor
            #
            (                    
            .BASE_ID         (i[3:0]),                                                
            .LAST_ID         (i[3:0])
            )
            r2d_extractor
            (                                                                                                                               
            .clk            (clk),
            .rst            (rst),   
                                           
            .i_sof          (r2d_sof [i+2]),
            .i_bus          (r2d_bus [i+2]),
                                              
            .o_sof          (r2d_sof [i+3]),
            .o_bus          (r2d_bus [i+3]),
            
            .frm_o_stb      (from_root_stb),  
            .frm_o_sof      (from_root_sof),  
            .frm_o_iid      (from_root_iid),
            .frm_o_bus      (from_root_data),
            .frm_o_rdy      (from_root_rdy)
            );         
                
            //rsbus_tgen_box 
            //#(                            
            //.READ_DELAY_M100            ((ONE_IN_SLICE_IS_REALTIME && ((i==0) /*|| (i==1)*/) )? REALTIME_DELAY_M100 : READ_DELAY_M100  * TGEN_NUM),
            //.WRITE_DELAY_M100           ((ONE_IN_SLICE_IS_REALTIME && ((i==0) /*|| (i==1)*/) )? REALTIME_DELAY_M100 : WRITE_DELAY_M100 * TGEN_NUM),
            //.HIGH_PRIORITY_PERC         (HIGH_PRIORITY_PERC),                 /*         */       
            //.HIGH_PRIORITY_VAL          (2'd3),                               /*         */
            //.LOW_PRIORITY_VAL           ((ONE_IN_SLICE_IS_REALTIME && ((i==0) /*|| (i==1)*/) )? i+2'd1 : 2'd0)
            //)
            rsbus_tgen_pp_box 
            #(                            
            .READ_PP0_DELAY_M100        (READ_PP0_DELAY_M100  * TGEN_NUM),
            .READ_PP1_DELAY_M100        (READ_PP1_DELAY_M100  * TGEN_NUM),
            .READ_PP2_DELAY_M100        (READ_PP2_DELAY_M100  * TGEN_NUM),
            .READ_PP3_DELAY_M100        (READ_PP3_DELAY_M100  * TGEN_NUM),
            .WRITE_PP0_DELAY_M100       (WRITE_PP0_DELAY_M100 * TGEN_NUM),
            .WRITE_PP1_DELAY_M100       (WRITE_PP1_DELAY_M100 * TGEN_NUM),
            .WRITE_PP2_DELAY_M100       (WRITE_PP2_DELAY_M100 * TGEN_NUM),
            .WRITE_PP3_DELAY_M100       (WRITE_PP3_DELAY_M100 * TGEN_NUM)
            )
            tgen
            (                                       
            .clk            (clk),                                                 
            .rst            (rst),   

            .i_stb          (from_root_stb),
            .i_sof          (from_root_sof),
            .i_iid          (from_root_iid),
            .i_data         (from_root_data),  
            .i_rdy          (from_root_rdy), 

            .o_stb          (to_root_stb),
            .o_sof          (to_root_sof),
            .o_iid          (to_root_iid),                                     
            .o_data         (to_root_data),
            .o_rdy          (to_root_rdy),
            .o_rdyE         (to_root_rdyE)                               
            );   

            rsbus_d2r_injector
            #(                
            .BASE_ID         (i[3:0]),                                                
            .LAST_ID         (i[3:0]) 
            )  
            d2r_injector
            (                                                                                                                               
            .clk            (clk),
            .rst            (rst),   
            
            .frm_i_stb      (to_root_stb),                                                               
            .frm_i_sof      (to_root_sof),
            .frm_i_iid      (to_root_iid),
            .frm_i_bus      (to_root_data), 
            .frm_i_rdy      (to_root_rdy), 
            .frm_i_rdyE     (to_root_rdyE), 
            
            .i_sof          (d2r_sof  [i+2]),
            .i_ctrl         (d2r_ctrl [i+2]),
            .i_bus          (d2r_bus  [i+2]),
                                          
            .o_sof          (d2r_sof  [i+3]),
            .o_ctrl         (d2r_ctrl [i+3]),
            .o_bus          (d2r_bus  [i+3]),
            
            .ff_err         (d2r_inf_ff_err[i])
            );                                                                          
                                                                                        
            integer time_cnt;
            integer fout_0;
            string  m_0;
              
              initial $sformat(m_0,"log__%m.stat");
              initial fout_0 = $fopen(m_0,"w");

              always@(posedge clk or posedge rst)  
                if(rst) time_cnt <= 0;
                else    time_cnt <= time_cnt + 'd1;
                                                          
              wire  [1:0] req_PP    = to_root_data[69:68]; 
              wire  [3:0] req_SID   = to_root_data[47:44];  
              wire  [3:0] req_RID   = to_root_data[43:40];  
              wire  [2:0] req_MOD   = to_root_data[2:0];  
              wire        req_LEN   = to_root_data[39];  
              wire [31:0] req_TIME  = time_cnt;  
              wire [31:0] req_ADDR  = {to_root_data[31:3],3'd0};  
                                                          
              wire  [1:0] ans_PP    = from_root_data[69:68]; 
              wire  [3:0] ans_SID   = from_root_data[47:44];  
              wire  [3:0] ans_RID   = from_root_data[43:40];  
              wire  [2:0] ans_MOD   = from_root_data[2:0];  
              wire        ans_LEN   = from_root_data[39];  
              wire [31:0] ans_TIME  = time_cnt;  
              wire [31:0] ans_ADDR  = {from_root_data[31:3],3'd0};  
              
                       
              always@(posedge clk)  
              begin    
                
                if(!rst && to_root_stb && to_root_sof)
                  begin
                    $fdisplay(fout_0,"OP:0,TIME:%H,SID:%H,RID:%H,MODE:%H,LEN:%H,ADDR:%H,PP:%H",req_TIME,req_SID,req_RID,req_MOD,req_LEN,req_ADDR,req_PP); 
                    $fflush(fout_0); 
                  end
                if(!rst && from_root_stb && from_root_sof) 
                  begin
                    $fdisplay(fout_0,"OP:1,TIME:%H,SID:%H,RID:%H,MODE:%H,LEN:%H,ADDR:%H,PP:%H",ans_TIME,ans_SID,ans_RID,ans_MOD,ans_LEN,ans_ADDR,ans_PP); 
                    $fflush(fout_0);
                  end
                                    
              end  
                                                                                                         
              always@(posedge clk)  
              if(rst)                                                 to_root_rd_cnt   <=                    0;  
              else if(to_root_stb   && to_root_sof   &&  req_MOD[1] ) to_root_rd_cnt   <=   to_root_rd_cnt + 1;  
              always@(posedge clk)  
              if(rst)                                                 to_root_wr_cnt   <=                    0;  
              else if(to_root_stb   && to_root_sof   && !req_MOD[1] ) to_root_wr_cnt   <=   to_root_wr_cnt + 1;  
                
              always@(posedge clk)  
              if(rst)                                                 from_root_rd_cnt <=                    0;  
              else if(from_root_stb && from_root_sof &&  ans_MOD[1] ) from_root_rd_cnt <= from_root_rd_cnt + 1;  
              always@(posedge clk)  
              if(rst)                                                 from_root_wr_cnt <=                    0;  
              else if(from_root_stb && from_root_sof && !ans_MOD[1] ) from_root_wr_cnt <= from_root_wr_cnt + 1;  
                    
        end 
endgenerate
//==============================================================================================
// Frame  generator for R2D ring
//==============================================================================================
rsbus_frame_generator r2d_frame_generator
(
.clk            (clk),
.rst            (rst),                                          
                                                            
.i_sof          (r2d_sof  [TGEN_NUM+2]),
.i_ctrl         (12'd0),
.i_bus          (r2d_bus  [TGEN_NUM+2]),   

.o_sof          (r2d_sof  [TGEN_NUM+3]),
.o_ctrl         (),
.o_bus          (r2d_bus  [TGEN_NUM+3])
); 
//..............................................................................................
assign           d2r_sof  [TGEN_NUM+3] = d2r_sof  [TGEN_NUM+2];                                                                    
assign           d2r_ctrl [TGEN_NUM+3] = d2r_ctrl [TGEN_NUM+2];
assign           d2r_bus  [TGEN_NUM+3] = d2r_bus  [TGEN_NUM+2];
//==============================================================================================
// ring bus switch (internal ring to external ring)
//==============================================================================================
rsbus_d2r_extractor #
(                        
.SPACE_CHECKING         ("OFF"),
.SPACE_START_ADDRESS    (39'h0_0000_0000),
.SPACE_LAST_ADDRESS     (39'h0_0000_0000)
)
d2r_extractor
(
.clk                    (clk),
.rst                    (rst),   
                                      
.i_sof                  (d2r_sof  [TGEN_NUM+3]),
.i_ctrl                 (d2r_ctrl [TGEN_NUM+3]),
.i_bus                  (d2r_bus  [TGEN_NUM+3]),
                                      
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
rsbus_r2d_injector      r2d_injector
(                                                                                                                               
.clk                    (clk),
.rst                    (rst),

.frm_i_stb              (i_stb), 
.frm_i_sof              (i_sof), 
.frm_i_bus              (i_bus),
.frm_i_rdy              (i_rdy),

.i_sof                  (r2d_sof [TGEN_NUM+3]),
.i_bus                  (r2d_bus [TGEN_NUM+3]),
                                  
.o_sof                  (r2d_sof [0]),
.o_bus                  (r2d_bus [0]),  

.ff_err                 (r2d_inj_ff_err)
);                    
//==============================================================================================
always @(posedge clk or posedge rst)                                                                           
if( rst                  ) ff_ovr_err    <=                                                1'b0;               
else if( |d2r_inf_ff_err ) ff_ovr_err    <=                                                1'b1;  
else if(  d2r_mgr_ff_err ) ff_ovr_err    <=                                                1'b1;  
else if(  r2d_inj_ff_err ) ff_ovr_err    <=                                                1'b1;   
else                       ff_ovr_err    <=                                          ff_ovr_err;    
//---------------------------------------------------------------------------------------------- 
assign ff_err =                                                                      ff_ovr_err;
//============================================================================================== 
endmodule            