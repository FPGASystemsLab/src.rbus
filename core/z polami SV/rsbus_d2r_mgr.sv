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
`include "rbus_defs.sv"
import rbus_pkg::*;
//=============================================================================================

module rsbus_d2r_mgr
(                                                                                                                               
input  wire         clk,                      
input  wire         rst,   

input  wire         i_sof,
input  rbus_ctrl_t  i_ctrl,
input  rbus_word_t  i_bus,
 
output wire         o_sof,
output rbus_ctrl_t  o_ctrl,
output rbus_word_t  o_bus,

output reg          ff_err
);      
//=============================================================================================
// parameters
//=============================================================================================
parameter  BUG_FIX_GRANT_FOLDING  =                                                      "YES";//"YES","NO"
localparam PRIORITIES_NUM =                                                                  4;
//=============================================================================================
// variables
//=============================================================================================
localparam      _cs   =   $bits(rbus_ctrl_t);       // control word size
localparam      _ws   =   $bits(rbus_word_t);       // bus word size
localparam      _ts   =   _cs + _ws;                 // 
//---------------------------------------------------------------------------------------------
wire        i0_ff_req_stb;   
wire        i0_ff_req_stb_l;
wire        i0_ff_req_bps_l;
wire        i0_ff_req_stb_s;
wire        i0_ff_req_bps_s;
wire        i0_ff_req_len;
wire [ 1:0] i0_ff_req_pri;
wire [ 3:0] i0_ff_req_dev;
wire [ 3:0] i0_ff_req_rid;

wire        i0_pkt_sof;
wire        i0_pkt_len;
wire        i0_pkt_used;
//---------------------------------------------------------------------------------------------
reg         i1_ff_req_stb;   
reg         i1_ff_req_stb_l;  
wire [ 3:0] i1_ff_req_ff_af_l; 
reg         i1_ff_req_bps_l; 
reg         i1_ff_req_stb_s; 
wire [ 3:0] i1_ff_req_ff_af_s;
reg         i1_ff_req_bps_s;
reg         i1_ff_req_len;
reg  [ 1:0] i1_ff_req_pri;
reg  [ 3:0] i1_ff_req_dev; 
reg  [ 3:0] i1_ff_req_rid;
reg         i1_pkt_used;                                                      
//---------------------------------------------------------------------------------------------
wire        o0_empty_pkt_s;
wire        o0_empty_pkt_l;                                                                            
//--------------------------------------------------------------------------------------------- 
reg         o1_sof;
rbus_ctrl_t o1_ctrl;
rbus_word_t o1_dat;
reg         o1_empty_pkt_l;
reg         o1_empty_pkt_s;

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
//---------------------------------------------------------------------------------------------
reg         o2_sof;
rbus_ctrl_t o2_ctrl;
rbus_word_t o2_dat;       

reg         o2_req_ena;
reg         o2_req_len;
reg  [ 1:0] o2_req_pri;
reg  [ 3:0] o2_req_dev;
reg  [ 3:0] o2_req_rid;
                                               
//---------------------------------------------------------------------------------------------     
wire        ff_err_l;
wire        ff_err_s;
//=============================================================================================
assign i0_ff_req_stb   =                                                 !i_sof & i_ctrl.valid;
assign i0_ff_req_len   =                                                            i_ctrl.len;
assign i0_ff_req_stb_l =    i0_ff_req_stb &  i0_ff_req_len & !i1_ff_req_ff_af_l[i0_ff_req_pri];
assign i0_ff_req_stb_s =    i0_ff_req_stb & !i0_ff_req_len & !i1_ff_req_ff_af_s[i0_ff_req_pri];
assign i0_ff_req_bps_l =    i0_ff_req_stb &  i0_ff_req_len &  i1_ff_req_ff_af_l[i0_ff_req_pri];
assign i0_ff_req_bps_s =    i0_ff_req_stb & !i0_ff_req_len &  i1_ff_req_ff_af_s[i0_ff_req_pri];
assign i0_ff_req_pri   =                                                            i_ctrl.pp ;
assign i0_ff_req_dev   =                                                            i_ctrl.did;
assign i0_ff_req_rid   =                                                            i_ctrl.rid;
                    
assign i0_pkt_sof      =                                                            i_sof     ;
assign i0_pkt_len      =                                                  i_bus.header.frm_len; 
assign i0_pkt_used     = (BUG_FIX_GRANT_FOLDING == "YES")? i_ctrl.valid :i_bus.header.frm_used;
//---------------------------------------------------------------------------------------------
always @(posedge clk or posedge rst)
if(rst) begin
                               i1_ff_req_stb   <=                                         1'b0; 
                               i1_ff_req_stb_l <=                                         1'b0;
                               i1_ff_req_stb_s <=                                         1'b0;
                               i1_ff_req_bps_l <=                                         1'b0;
                               i1_ff_req_bps_s <=                                         1'b0;
  end
else begin
                               i1_ff_req_stb   <=                              i0_ff_req_stb  ; 
                               i1_ff_req_stb_l <=                              i0_ff_req_stb_l;
                               i1_ff_req_stb_s <=                              i0_ff_req_stb_s;
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
//=============================================================================================
// requests fifo
//============================================================================================= 
rsbus_d2r_mgr_ffbnk req_ff_long
(                                                                                                                               
.clk        (clk),
.rst        (rst),   

.i_stb      (i1_ff_req_stb_l),
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
rsbus_d2r_mgr_ffbnk req_ff_short
(                                                                                                                               
.clk        (clk),
.rst        (rst),   

.i_stb      (i1_ff_req_stb_s),
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
assign o0_empty_pkt_s =                                i0_pkt_sof & !i0_pkt_len & !i0_pkt_used;
assign o0_empty_pkt_l =                                i0_pkt_sof &  i0_pkt_len & !i0_pkt_used; 
//============================================================================================= 
always @(posedge clk or posedge rst)
if(rst)                        o1_sof          <=                                         1'b0;
else                           o1_sof          <=                                        i_sof;
//--------------------------------------------------------------------------------------------- 
always @(posedge clk or posedge rst)
if(rst)                        o1_ctrl.valid   <=                                         1'b0;
else                           o1_ctrl.valid   <=                                 i_ctrl.valid;
//--------------------------------------------------------------------------------------------- 
always @(posedge clk)          o1_ctrl.len     <=                                   i_ctrl.len;
always @(posedge clk)          o1_ctrl.pp      <=                                   i_ctrl.pp ;
always @(posedge clk)          o1_ctrl.did     <=                                   i_ctrl.did;
always @(posedge clk)          o1_ctrl.rid     <=                                   i_ctrl.rid;
//--------------------------------------------------------------------------------------------- 
always @(posedge clk or posedge rst)
if(rst)                        o1_req_ena_s    <=                                         1'b0;
else                           o1_req_ena_s    <=             o0_ff_req_stb_s & o0_empty_pkt_s;
always @(posedge clk or posedge rst)
if(rst)                        o1_req_ena_l    <=                                         1'b0;
else                           o1_req_ena_l    <=             o0_ff_req_stb_l & o0_empty_pkt_l;
//---------------------------------------------------------------------------------------------  
always @(posedge clk)          o1_dat          <=                                       i_bus; 
always @(posedge clk)          o1_empty_pkt_l  <=                               o0_empty_pkt_l; 
always @(posedge clk)          o1_empty_pkt_s  <=                               o0_empty_pkt_s;
                                                                                               
always @(posedge clk)          o1_req_len  <= (!i0_pkt_len)?            1'b0 :            1'b1;
always @(posedge clk)          o1_req_pri  <= (!i0_pkt_len)? o0_ff_req_pri_s : o0_ff_req_pri_l;
always @(posedge clk)          o1_req_dev  <= (!i0_pkt_len)? o0_ff_req_dev_s : o0_ff_req_dev_l; 
always @(posedge clk)          o1_req_rid  <= (!i0_pkt_len)? o0_ff_req_rid_s : o0_ff_req_rid_l;   
//============================================================================================= 
assign o1_req_ena   =                                             o1_req_ena_s || o1_req_ena_l;
assign o1_pkt_len   =                                                    o1_dat.header.frm_len;
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
if(rst)                        o2_req_ena <=                                              1'b0;
else                           o2_req_ena <=                      o1_req_ena_s || o1_req_ena_l; 
//---------------------------------------------------------------------------------------------
always@(posedge clk)           o2_req_len <=                                        o1_req_len;
always@(posedge clk)           o2_req_pri <=                                        o1_req_pri;
always@(posedge clk)           o2_req_dev <=                                        o1_req_dev;
always@(posedge clk)           o2_req_rid <=                                        o1_req_rid;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
if(rst)                        o2_ctrl.valid <=                                           1'b0; 
else if(i1_ff_req_bps_l     )  o2_ctrl.valid <=                                  o1_ctrl.valid;
else if(i1_ff_req_bps_s     )  o2_ctrl.valid <=                                  o1_ctrl.valid;  
else if(o1_sof & i1_pkt_used)  o2_ctrl.valid <=                                  o1_ctrl.valid; 
else if(o1_sof              )  o2_ctrl.valid <=                                     o1_req_ena;
else                           o2_ctrl.valid <=                                           1'b0;
//---------------------------------------------------------------------------------------------
always@(posedge clk) 
     if(i1_ff_req_bps_l     )  o2_ctrl.len  <=                                     o1_ctrl.len;
else if(i1_ff_req_bps_s     )  o2_ctrl.len  <=                                     o1_ctrl.len;  
else if(o1_sof & i1_pkt_used)  o2_ctrl.len  <=                                     o1_ctrl.len; 
else if(o1_sof              )  o2_ctrl.len  <=                                      o1_req_len;
else                           o2_ctrl.len  <=                                            1'b0;
//---------------------------------------------------------------------------------------------
always@(posedge clk) 
     if(i1_ff_req_bps_l     )  o2_ctrl.pp   <=                                     o1_ctrl.pp ;
else if(i1_ff_req_bps_s     )  o2_ctrl.pp   <=                                     o1_ctrl.pp ;  
else if(o1_sof & i1_pkt_used)  o2_ctrl.pp   <=                                     o1_ctrl.pp ; 
else if(o1_sof              )  o2_ctrl.pp   <=                                      o1_req_pri;
else                           o2_ctrl.pp   <=                                            2'd0;
//---------------------------------------------------------------------------------------------
always@(posedge clk) 
     if(i1_ff_req_bps_l     )  o2_ctrl.did  <=                                     o1_ctrl.did;
else if(i1_ff_req_bps_s     )  o2_ctrl.did  <=                                     o1_ctrl.did;  
else if(o1_sof & i1_pkt_used)  o2_ctrl.did  <=                                     o1_ctrl.did; 
else if(o1_sof              )  o2_ctrl.did  <=                                      o1_req_dev;
else                           o2_ctrl.did  <=                                            4'd0;
//---------------------------------------------------------------------------------------------
always@(posedge clk) 
     if(i1_ff_req_bps_l     )  o2_ctrl.rid  <=                                     o1_ctrl.rid;
else if(i1_ff_req_bps_s     )  o2_ctrl.rid  <=                                     o1_ctrl.rid;  
else if(o1_sof & i1_pkt_used)  o2_ctrl.rid  <=                                     o1_ctrl.rid; 
else if(o1_sof              )  o2_ctrl.rid  <=                                      o1_req_rid;
else                           o2_ctrl.rid  <=                                            4'd0;
//=============================================================================================
// output control bus
//=============================================================================================
assign      o_ctrl     =                                                               o2_ctrl;
assign      o_sof      =                                                                o2_sof;
assign      o_bus      =                                                                o2_dat;
//=============================================================================================
endmodule