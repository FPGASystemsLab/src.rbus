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
// - In case of overflow risk it skips request and leave it on the ring (if FF_NEVER_OVERFLOW and
//   FF_CAN_OVERFLOW_JUST_FOR_PP3 are both 0, or if FF_NEVER_OVERFLOW is 0 and
//   FF_CAN_OVERFLOW_JUST_FOR_PP3 is 1 but then overflow is checked only for PP3).
// - Grants are placed at rbus_o_ctrl bus along with headers (rbus_o_sof == 1).
// - A grant assigns current packet for a use by a designated device.      
//
// If module detects "owned" packet (packet that was supposed to be extracted by d2r_extractor 
// but it was not because of fifo fullness in an injector connected to the extractor output) it
// stops giving grants till all "owned" packet are extracted from this ring. The number of 
// consecutive packets that should be checked, to be certain that there are no more "owned"
// packets in a ring is determined during initialization of the module. Ring can have various 
// number of packets depending on a number of connected devices. 
// Initialization process:
// - Just after the first header insert a fake request (set a ctrl[11] bit of the output word),
// - Count the number of long headers that will be seen before the first request occurs
//   and set this number as a number of packets in a ring
// - delete the first request because it is our own fake request and mark the module as 
//   initialized

//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
`include "rbus_defs.sv"
import rbus_pkg::*;
//=============================================================================================

module rsbus_d2r_mgr
(                                                                                                                               
input  wire         clk,                      
input  wire         rst,   

input  wire         i_sof,
input  wire [11:0]  i_ctrl,
input  wire [71:0]  i_bus,
 
output wire         o_sof,
output wire [11:0]  o_ctrl,
output wire [71:0]  o_bus,

output reg          ff_err
);      
//=============================================================================================
// parameters
//=============================================================================================                
parameter  FF_NEVER_OVERFLOW  =                                                           1'b0;
parameter  FF_CAN_OVERFLOW_JUST_FOR_PP3 =                                                 1'b1;
parameter  FF_DEPTH           =                                                             64; //64 / 32 / 16                
localparam PRIORITIES_NUM     =                                                              4;                                                                                                                            
// pragma translate_off
initial
    begin
        if((FF_DEPTH != 64) && (FF_DEPTH != 32) && (FF_DEPTH != 16))             
            begin
           $display( "FF_DEPTH = %s, is out of range (64, 32, 16)", FF_DEPTH );  
            $finish;
            end  
           
        else if((PRIORITIES_NUM < 1) || (PRIORITIES_NUM > 4)) 
            begin
           $display( "!!!ERROR!!! PRIORITIES_NUM (%d) out of (1, 4) range", PRIORITIES_NUM );
            $finish;
            end       
    end
// pragma translate_on
//=============================================================================================
// variables
//=============================================================================================
localparam      _cs   =   $bits(rbus_ctrl_t);       // control word size
localparam      _ws   =   $bits(rbus_word_t);       // bus word size
localparam      _ts   =   _cs + _ws;                //      
//--------------------------------------------------------------------------------------------- 
reg         initialized_f;  
reg         init_started_f;
wire        init_insert_req; 
//--------------------------------------------------------------------------------------------- 
reg  [ 2:0] block_pkt_period;
reg  [ 2:0] block_pkt_s_dcnt;                         
wire        block_pkt_s;
reg  [ 2:0] block_pkt_l_dcnt;                         
wire        block_pkt_l;
//---------------------------------------------------------------------------------------------
wire        i0_ff_req_stb;   
wire        i0_ff_req_stb_l;
wire [ 3:0] i0_ff_req_stb_l1h;
wire        i0_ff_req_bps_l;
wire        i0_ff_req_stb_s;
wire [ 3:0] i0_ff_req_stb_s1h;
wire        i0_ff_req_bps_s;
wire        i0_ff_req_len;
wire [ 1:0] i0_ff_req_pri;
wire [ 3:0] i0_ff_req_dev;
wire [ 3:0] i0_ff_req_rid;

wire        i0_pkt_sof;
wire        i0_pkt_len;
wire        i0_pkt_used;
wire        i0_pkt_owned;
//---------------------------------------------------------------------------------------------
reg         i1_ff_req_stb;   
reg         i1_ff_req_stb_l;  
reg  [ 3:0] i1_ff_req_stb_l1h; 
wire [ 3:0] i1_ff_req_ff_af_l; 
reg         i1_ff_req_bps_l; 
reg         i1_ff_req_stb_s; 
reg  [ 3:0] i1_ff_req_stb_s1h;
wire [ 3:0] i1_ff_req_ff_af_s;
reg         i1_ff_req_bps_s;
reg         i1_ff_req_len;
reg  [ 1:0] i1_ff_req_pri;
reg  [ 3:0] i1_ff_req_dev; 
reg  [ 3:0] i1_ff_req_rid;
reg         i1_pkt_used;                                                      
//---------------------------------------------------------------------------------------------
wire        o0_slot_rdy_s;
wire        o0_slot_rdy_l;                                                                            
//--------------------------------------------------------------------------------------------- 
reg         o1_sof;
reg  [11:0] o1_ctrl;
reg  [71:0] o1_dat;
reg         o1_slot_rdy_l;
reg         o1_slot_rdy_s;

wire        o0_ff_req_stb_l;
wire [ 1:0] o0_ff_req_pri_l; 
wire [ 3:0] o0_ff_req_dev_l;
wire [ 3:0] o0_ff_req_rid_l;

wire        o0_ff_req_stb_s;
wire [ 1:0] o0_ff_req_pri_s;
wire [ 3:0] o0_ff_req_dev_s;
wire [ 3:0] o0_ff_req_rid_s;                                                                    

reg         o1_req_ena_s;
reg         o1_req_ena_l; 
wire        o1_ff_ack_l;
wire        o1_ff_ack_s;
wire        o1_req_ena;
wire        o1_pkt_len;   
reg         o1_req_len;
reg  [ 1:0] o1_req_pri;
reg  [ 3:0] o1_req_dev;  
reg  [ 3:0] o1_req_rid;   

reg         o1_bps_o1_ctrl;                                                                                                 
//---------------------------------------------------------------------------------------------
reg         o2_sof;
reg  [11:0] o2_ctrl;
reg  [71:0] o2_dat;       

reg         o2_req_ena;
reg         o2_req_len;
reg  [ 1:0] o2_req_pri;
reg  [ 3:0] o2_req_dev;
reg  [ 3:0] o2_req_rid;
                                               
//---------------------------------------------------------------------------------------------     
wire        ff_err_l;
wire        ff_err_s;
//=============================================================================================
assign i0_ff_req_stb   =                                                  !i_sof & i_ctrl[ 11];
assign i0_ff_req_len   =                                                           i_ctrl[ 10];
assign i0_ff_req_stb_l = (FF_NEVER_OVERFLOW           )? i0_ff_req_stb &  i0_ff_req_len &                                                     initialized_f:
                         (FF_CAN_OVERFLOW_JUST_FOR_PP3)? i0_ff_req_stb &  i0_ff_req_len & ((i0_ff_req_pri != 2'd3) | !i1_ff_req_ff_af_l[3]) & initialized_f:
                                                         i0_ff_req_stb &  i0_ff_req_len &                 !i1_ff_req_ff_af_l[i0_ff_req_pri] & initialized_f;
assign i0_ff_req_stb_s = (FF_NEVER_OVERFLOW           )? i0_ff_req_stb & !i0_ff_req_len &                                                     initialized_f:
                         (FF_CAN_OVERFLOW_JUST_FOR_PP3)? i0_ff_req_stb & !i0_ff_req_len & ((i0_ff_req_pri != 2'd3) | !i1_ff_req_ff_af_s[3]) & initialized_f:
                                                         i0_ff_req_stb & !i0_ff_req_len &                 !i1_ff_req_ff_af_s[i0_ff_req_pri] & initialized_f;
genvar p;
generate
for(p = 0; p < PRIORITIES_NUM; p=p+1) 
	begin:oneHotStbAssignement
	assign i0_ff_req_stb_l1h[p] = (FF_NEVER_OVERFLOW           )? i0_ff_req_stb &  i0_ff_req_len & (i0_ff_req_pri == p) &                                                     initialized_f:
	                              (FF_CAN_OVERFLOW_JUST_FOR_PP3)? i0_ff_req_stb &  i0_ff_req_len & (i0_ff_req_pri == p) & ((i0_ff_req_pri != 2'd3) | !i1_ff_req_ff_af_l[3]) & initialized_f:
	                                                              i0_ff_req_stb &  i0_ff_req_len & (i0_ff_req_pri == p) &                            !i1_ff_req_ff_af_l[p]  & initialized_f;
	assign i0_ff_req_stb_s1h[p] = (FF_NEVER_OVERFLOW           )? i0_ff_req_stb & !i0_ff_req_len & (i0_ff_req_pri == p) &                                                     initialized_f:
	                              (FF_CAN_OVERFLOW_JUST_FOR_PP3)? i0_ff_req_stb & !i0_ff_req_len & (i0_ff_req_pri == p) & ((i0_ff_req_pri != 2'd3) | !i1_ff_req_ff_af_s[3]) & initialized_f:
	                                                              i0_ff_req_stb & !i0_ff_req_len & (i0_ff_req_pri == p) &                            !i1_ff_req_ff_af_s[p]  & initialized_f;
	end
endgenerate                                                         
assign i0_ff_req_bps_l = (FF_NEVER_OVERFLOW           )?                                                                                               1'b0:
                         (FF_CAN_OVERFLOW_JUST_FOR_PP3)? i0_ff_req_stb &  i0_ff_req_len & ((i0_ff_req_pri == 2'd3) &  i1_ff_req_ff_af_l[3]) & initialized_f:
                                                         i0_ff_req_stb &  i0_ff_req_len &                  i1_ff_req_ff_af_l[i0_ff_req_pri] & initialized_f; 
assign i0_ff_req_bps_s = (FF_NEVER_OVERFLOW           )?                                                                                               1'b0:
                         (FF_CAN_OVERFLOW_JUST_FOR_PP3)? i0_ff_req_stb & !i0_ff_req_len & ((i0_ff_req_pri == 2'd3) &  i1_ff_req_ff_af_s[3]) & initialized_f:
                                                         i0_ff_req_stb & !i0_ff_req_len &                  i1_ff_req_ff_af_s[i0_ff_req_pri] & initialized_f; 
assign i0_ff_req_pri   =                                                           i_ctrl[9:8];
assign i0_ff_req_dev   =                                                           i_ctrl[7:4];
assign i0_ff_req_rid   =                                                           i_ctrl[3:0];  
                    
assign i0_pkt_sof      =                                                             i_sof    ;
assign i0_pkt_len      =                                                             i_bus[39]; 
assign i0_pkt_used     =                                                             i_bus[71];
assign i0_pkt_owned    =                                                             i_bus[70];  
//---------------------------------------------------------------------------------------------  
always @(posedge clk or posedge rst)                                                            
if(rst)                        initialized_f   <=                                         1'b0; 
else if(i0_ff_req_stb)         initialized_f   <=                                         1'b1; 
else                           initialized_f   <=                                initialized_f;       
//---------------------------------------------------------------------------------------------  
always @(posedge clk or posedge rst)
if(rst) begin
                               i1_ff_req_stb   <=                                         1'b0; 
                               i1_ff_req_stb_l <=                                         1'b0;
                               i1_ff_req_stb_l1h<=                                        4'b0;
                               i1_ff_req_stb_s <=                                         1'b0;
                               i1_ff_req_stb_s1h<=                                        4'b0;
                               i1_ff_req_bps_l <=                                         1'b0;
                               i1_ff_req_bps_s <=                                         1'b0;
  end
else begin
                               i1_ff_req_stb   <=                              i0_ff_req_stb  ; 
                               i1_ff_req_stb_l <=                              i0_ff_req_stb_l;
                               i1_ff_req_stb_l1h<=                           i0_ff_req_stb_l1h;
                               i1_ff_req_stb_s <=                              i0_ff_req_stb_s;
                               i1_ff_req_stb_s1h<=                           i0_ff_req_stb_s1h;
                               i1_ff_req_bps_l <=                              i0_ff_req_bps_l;
                               i1_ff_req_bps_s <=                              i0_ff_req_bps_s;
  end
//---------------------------------------------------------------------------------------------
always @(posedge clk) begin
                               i1_ff_req_len   <=                              i0_ff_req_len  ;
                               i1_ff_req_pri   <=                              i0_ff_req_pri  ;
                               i1_ff_req_dev   <=                              i0_ff_req_dev  ; 
                               i1_ff_req_rid   <=                              i0_ff_req_rid  ;
                               i1_pkt_used     <=                              i0_pkt_used    ;
  end                                                                                            
//---------------------------------------------------------------------------------------------  
always @(posedge clk or posedge rst)
if(rst)                                                           block_pkt_period<= 3'h7;       
else if(initialized_f                                           ) block_pkt_period<= block_pkt_period; 
else if(i0_pkt_sof &  i0_pkt_len                                ) block_pkt_period<= block_pkt_period + 3'd1; 
else                                                              block_pkt_period<= block_pkt_period; 
//---------------------------------------------------------------------------------------------
always @(posedge clk or posedge rst)
if(rst)                                                           block_pkt_s_dcnt<= 3'h7; 
else if(i0_pkt_sof & !i0_pkt_len &  i0_pkt_used &  i0_pkt_owned ) block_pkt_s_dcnt<= block_pkt_period;                                   
else if(i0_pkt_sof & !i0_pkt_len &(!i0_pkt_used | !i0_pkt_owned)) block_pkt_s_dcnt<= block_pkt_s_dcnt - {2'd0, block_pkt_s};
else                                                              block_pkt_s_dcnt<= block_pkt_s_dcnt; 
//--------------------------------------------------------------------------------------------- 
assign block_pkt_s =                                                      !block_pkt_s_dcnt[2];
//---------------------------------------------------------------------------------------------
always @(posedge clk or posedge rst)
if(rst)                                                           block_pkt_l_dcnt<= 3'h7; 
else if(i0_pkt_sof &  i0_pkt_len &  i0_pkt_used &  i0_pkt_owned ) block_pkt_l_dcnt<= block_pkt_period;                                   
else if(i0_pkt_sof &  i0_pkt_len &(!i0_pkt_used | !i0_pkt_owned)) block_pkt_l_dcnt<= block_pkt_l_dcnt - {2'd0, block_pkt_l};
else                                                              block_pkt_l_dcnt<= block_pkt_l_dcnt; 
//--------------------------------------------------------------------------------------------- 
assign block_pkt_l =                                                      !block_pkt_l_dcnt[2];
//=============================================================================================
// requests fifo
//============================================================================================= 
rsbus_d2r_mgr_ffbnk 
#(
.FF_DEPTH   (FF_DEPTH)
)
req_ff_long
(                                                                                                                               
.clk        (clk),
.rst        (rst),   

.i_stb      (i1_ff_req_stb_l1h),
.i_prior    (i1_ff_req_pri), 
.i_req      (i1_ff_req_dev),
.i_rid      (i1_ff_req_rid),
.i_af       (i1_ff_req_ff_af_l),
                                     
.o_stb      (o0_ff_req_stb_l),
.o_prior    (o0_ff_req_pri_l),
.o_req      (o0_ff_req_dev_l),
.o_rid      (o0_ff_req_rid_l),
.o_ack      (o1_ff_ack_l),                                
.o_ff_err   (ff_err_l)
); 
//---------------------------------------------------------------------------------------------
rsbus_d2r_mgr_ffbnk  
#(
.FF_DEPTH   (FF_DEPTH)
)
req_ff_short
(                                                                                                                               
.clk        (clk),
.rst        (rst),   

.i_stb      (i1_ff_req_stb_s1h),
.i_prior    (i1_ff_req_pri),
.i_req      (i1_ff_req_dev),
.i_rid      (i1_ff_req_rid),
.i_af       (i1_ff_req_ff_af_s),
                                     
.o_stb      (o0_ff_req_stb_s),
.o_prior    (o0_ff_req_pri_s),
.o_req      (o0_ff_req_dev_s),
.o_rid      (o0_ff_req_rid_s),
.o_ack      (o1_ff_ack_s),                                
.o_ff_err   (ff_err_s)
); 
//=============================================================================================
always@(posedge clk or posedge rst)
if(rst)                        ff_err    <=                                               1'b0;
else                           ff_err    <=                       ff_err | ff_err_l | ff_err_s; 
//=============================================================================================
// output path                                                                                  
//============================================================================================= 
assign o0_slot_rdy_s =                  i0_pkt_sof & !i0_pkt_len & !i0_pkt_used & !block_pkt_s;
assign o0_slot_rdy_l =                  i0_pkt_sof &  i0_pkt_len & !i0_pkt_used & !block_pkt_l; 
//============================================================================================= 
always @(posedge clk or posedge rst)
if(rst)                        o1_sof          <=                                         1'b0;
else                           o1_sof          <=                                        i_sof;
//--------------------------------------------------------------------------------------------- 
always @(posedge clk or posedge rst)
if(rst)                        o1_ctrl[11]     <=                                         1'b0;
else                           o1_ctrl[11]     <=                                   i_ctrl[11];
//--------------------------------------------------------------------------------------------- 
always @(posedge clk)
                               o1_ctrl[10:0]   <=                                 i_ctrl[10:0];
//--------------------------------------------------------------------------------------------- 
always @(posedge clk or posedge rst)
if(rst)                        o1_req_ena_s    <=                                         1'b0;
else                           o1_req_ena_s    <=              o0_ff_req_stb_s & o0_slot_rdy_s;
always @(posedge clk or posedge rst)
if(rst)                        o1_req_ena_l    <=                                         1'b0;
else                           o1_req_ena_l    <=              o0_ff_req_stb_l & o0_slot_rdy_l;
//---------------------------------------------------------------------------------------------  
always @(posedge clk)          o1_dat          <=                                        i_bus; 
always @(posedge clk)          o1_slot_rdy_l   <=                                o0_slot_rdy_l; 
always @(posedge clk)          o1_slot_rdy_s   <=                                o0_slot_rdy_s;
                                                                                               
always @(posedge clk)          o1_req_len  <= (!i0_pkt_len)?            1'b0 :            1'b1;
always @(posedge clk)          o1_req_pri  <= (!i0_pkt_len)? o0_ff_req_pri_s : o0_ff_req_pri_l;
always @(posedge clk)          o1_req_dev  <= (!i0_pkt_len)? o0_ff_req_dev_s : o0_ff_req_dev_l; 
always @(posedge clk)          o1_req_rid  <= (!i0_pkt_len)? o0_ff_req_rid_s : o0_ff_req_rid_l;   
//============================================================================================= 
assign o1_req_ena   =                                             o1_req_ena_s || o1_req_ena_l;
assign o1_pkt_len   =                                                               o1_dat[39];
assign o1_ff_ack_l  =                                                             o1_req_ena_l; 
assign o1_ff_ack_s  =                                                             o1_req_ena_s;  
//=============================================================================================
always @(posedge clk or posedge rst)
if(rst)                        o2_sof          <=                                         1'b0;
else                           o2_sof          <=                                       o1_sof;
//---------------------------------------------------------------------------------------------
always @(posedge clk)          o2_dat          <=                                       o1_dat;  
//============================================================================================= 
always@(posedge clk or posedge rst)
if(rst)                        init_started_f<=                                           1'b0; 
else if(init_insert_req     )  init_started_f<=                                           1'b1;
else                           init_started_f<=                                 init_started_f;
//---------------------------------------------------------------------------------------------  
assign init_insert_req =                                              !init_started_f & o2_sof;  
//============================================================================================= 
always@(posedge clk or posedge rst)
if(rst)                        o2_req_ena <=                                              1'b0;
else                           o2_req_ena <=                      o1_req_ena_s || o1_req_ena_l; 
//---------------------------------------------------------------------------------------------
always@(posedge clk)           o2_req_len <=                                        o1_req_len;
always@(posedge clk)           o2_req_pri <=                                        o1_req_pri;
always@(posedge clk)           o2_req_dev <=                                        o1_req_dev;
always@(posedge clk)           o2_req_rid <=                                        o1_req_rid;
                                                                                               
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
if(rst)                        o1_bps_o1_ctrl <=                                          1'b0;
else if(i0_ff_req_bps_l     )  o1_bps_o1_ctrl <=                                          1'b1;
else if(i0_ff_req_bps_s     )  o1_bps_o1_ctrl <=                                          1'b1;
else if(i_sof & i0_pkt_used )  o1_bps_o1_ctrl <=                                          1'b1;
else                           o1_bps_o1_ctrl <=                                          1'b0;
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
if(rst)                        o2_ctrl[11]  <=                                            1'b0; 
else if(init_insert_req     )  o2_ctrl[11]  <=                                            1'b1;
else if(o1_bps_o1_ctrl      )  o2_ctrl[11]  <=                                     o1_ctrl[11];
//else if(i1_ff_req_bps_l     )  o2_ctrl[11]  <=                                     o1_ctrl[11];
//else if(i1_ff_req_bps_s     )  o2_ctrl[11]  <=                                     o1_ctrl[11];  
//else if(o1_sof & i1_pkt_used)  o2_ctrl[11]  <=                                     o1_ctrl[11]; 
else if(o1_sof              )  o2_ctrl[11]  <=                                      o1_req_ena;
else                           o2_ctrl[11]  <=                                            1'b0;
//---------------------------------------------------------------------------------------------
always@(posedge clk) 
     if(o1_bps_o1_ctrl      )  o2_ctrl[10]  <=                                     o1_ctrl[10];
//     if(i1_ff_req_bps_l     )  o2_ctrl[10]  <=                                     o1_ctrl[10];
//else if(i1_ff_req_bps_s     )  o2_ctrl[10]  <=                                     o1_ctrl[10];  
//else if(o1_sof & i1_pkt_used)  o2_ctrl[10]  <=                                     o1_ctrl[10]; 
else if(o1_sof              )  o2_ctrl[10]  <=                                      o1_req_len;
else                           o2_ctrl[10]  <=                                            1'bx;
//---------------------------------------------------------------------------------------------
always@(posedge clk) 
     if(o1_bps_o1_ctrl      )  o2_ctrl[9:8] <=                                    o1_ctrl[9:8];
//     if(i1_ff_req_bps_l     )  o2_ctrl[9:8] <=                                    o1_ctrl[9:8];
//else if(i1_ff_req_bps_s     )  o2_ctrl[9:8] <=                                    o1_ctrl[9:8];  
//else if(o1_sof & i1_pkt_used)  o2_ctrl[9:8] <=                                    o1_ctrl[9:8]; 
else if(o1_sof              )  o2_ctrl[9:8] <=                                      o1_req_pri;
else                           o2_ctrl[9:8] <=                                            2'dx;
//---------------------------------------------------------------------------------------------
always@(posedge clk) 
     if(o1_bps_o1_ctrl      )  o2_ctrl[7:4] <=                                    o1_ctrl[7:4];
//     if(i1_ff_req_bps_l     )  o2_ctrl[7:4] <=                                    o1_ctrl[7:4];
//else if(i1_ff_req_bps_s     )  o2_ctrl[7:4] <=                                    o1_ctrl[7:4];  
//else if(o1_sof & i1_pkt_used)  o2_ctrl[7:4] <=                                    o1_ctrl[7:4]; 
else if(o1_sof              )  o2_ctrl[7:4] <=                                      o1_req_dev;
else                           o2_ctrl[7:4] <=                                            4'dx;
//---------------------------------------------------------------------------------------------
always@(posedge clk) 
     if(o1_bps_o1_ctrl      )  o2_ctrl[3:0] <=                                    o1_ctrl[3:0];
//     if(i1_ff_req_bps_l     )  o2_ctrl[3:0] <=                                    o1_ctrl[3:0];
//else if(i1_ff_req_bps_s     )  o2_ctrl[3:0] <=                                    o1_ctrl[3:0];  
//else if(o1_sof & i1_pkt_used)  o2_ctrl[3:0] <=                                    o1_ctrl[3:0]; 
else if(o1_sof              )  o2_ctrl[3:0] <=                                      o1_req_rid;
else                           o2_ctrl[3:0] <=                                            4'dx;
//=============================================================================================
// output control bus
//=============================================================================================
assign      o_ctrl     =                                                               o2_ctrl;
assign      o_sof      =                                                                o2_sof;
assign      o_bus      =                                                                o2_dat;
//=============================================================================================
endmodule