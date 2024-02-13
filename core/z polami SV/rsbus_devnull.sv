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

module rsbus_devnull  
#(                        
parameter [63:0]    INSERT_DWORD  =                                     64'hABBA_FACE_CAFE_BACA    
)
(
input  wire         clk,    
input  wire         rst,    
 
input  wire         d2r_i_sof,    
input  rbus_ctrl_t  d2r_i_ctrl,   
input  rbus_word_t  d2r_i_bus,   

output wire         d2r_o_sof,    
output rbus_ctrl_t  d2r_o_ctrl,   
output rbus_word_t  d2r_o_bus, 
 
input  wire         r2d_i_sof,    
input  rbus_word_t  r2d_i_bus,   

output wire         r2d_o_sof,    
output rbus_word_t  r2d_o_bus,   

output wire         pkt_intercepted
);                                                                                             
//=============================================================================================
// variables
//============================================================================================= 
reg         r2d_stb;
rbus_word_t r2d_header;   
wire        r2d_bsy;  
wire        r2d_ack;
//---------------------------------------------------------------------------------------------                                                                         
reg         s0_r2d_sof; 
rbus_word_t s0_r2d_bus; 
rbus_ctrl_t s0_ctrl;     
reg         s0_r2d_ena;                       
//---------------------------------------------------------------------------------------------
reg         s0_d2r_sof;
rbus_ctrl_t s0_d2r_ctrl;
rbus_word_t s0_d2r_bus;       
reg         s0_d2r_clr;                                                                        
//=============================================================================================                  
// stage 0
//=============================================================================================  
// tx
wire        i_frm_stb     =                                          d2r_i_bus.header.frm_used;
wire        i_frm_len     =                                           d2r_i_bus.header.frm_len; 
wire        i_frm_pha     =                             d2r_i_bus.header.mem_space == PHYSICAL; 
//---------------------------------------------------------------------------------------------
wire        i_frm_rd1     =                              d2r_i_bus.header.mem_op == MEM_READ_1; 
wire        i_frm_rd8     =                              d2r_i_bus.header.mem_op == MEM_READ_8; 
wire        i_frm_wra     =                              d2r_i_bus.header.mem_op == MEM_WRITE ; 
wire        i_frm_upda    =                              d2r_i_bus.header.mem_op == MEM_UPDATE; 
//---------------------------------------------------------------------------------------------			  
wire        i_frm_wr      =                                                          i_frm_wra; 			  
wire        i_frm_rd      =                                 i_frm_rd1 | i_frm_rd8 | i_frm_upda; 			 
wire        i_frm_rd_len  =                               i_frm_rd8 | (i_frm_upda & i_frm_len);
wire        i_frm_reco    =                                         d2r_i_bus.header.frm_owned;
wire [1:0]  i_frm_pr      =                                      d2r_i_bus.header.frm_priority; 
wire        i_frm_clr_d2r =                               !r2d_bsy && !i_frm_reco && i_frm_stb; 
wire        i_frm_ins_r2d =                   i_frm_rd && !r2d_bsy && !i_frm_reco && i_frm_stb;    
//=============================================================================================
// response data prepare
//=============================================================================================             
always@(posedge clk or posedge rst)
if(rst)
  r2d_stb        <=                                                                       1'b0;
else
  r2d_stb        <= (d2r_i_sof && !r2d_bsy)?             i_frm_ins_r2d : (r2d_stb && !r2d_ack); 
//---------------------------------------------------------------------------------------------
always@(posedge clk)
if(d2r_i_sof && i_frm_ins_r2d) begin
  r2d_header.header.frm_used     <=                                                       1'b1;
  r2d_header.header.frm_owned    <=                                                       1'b0;
  r2d_header.header.frm_priority <=                              d2r_i_bus.header.frm_priority;
  r2d_header.header.net_addr     <=                                 d2r_i_bus.header.net_addr ;
  r2d_header.header.frm_sid      <=                                 d2r_i_bus.header.frm_sid  ;
  r2d_header.header.frm_rid      <=                                 d2r_i_bus.header.frm_rid  ;
  r2d_header.header.frm_len      <=                                               i_frm_rd_len;// packet lenght depends on memory operation code
  r2d_header.header.mem_addr     <=                                 d2r_i_bus.header.mem_addr ;
  r2d_header.header.mem_space    <=                                 d2r_i_bus.header.mem_space;
  r2d_header.header.mem_op       <=                                 d2r_i_bus.header.mem_op   ;
end else
  r2d_header                     <=                                                 r2d_header;                                                                                      
//--------------------------------------------------------------------------------------------- 
assign r2d_bsy = r2d_stb;                                                                                 
//=============================================================================================
// mux response into r2d bus
//============================================================================================= 
wire        r_frm_stb   =                                                              r2d_stb;
wire        r_frm_len   =                                            r2d_header.header.frm_len;
wire        r_frm_enaX1 =                 r_frm_stb && (r_frm_len == r2d_i_bus.header.frm_len);
wire        r_frm_empty =                                          !r2d_i_bus .header.frm_used;
wire        r_frm_ena   =                                           r_frm_enaX1 && r_frm_empty;
//---------------------------------------------------------------------------------------------
assign r2d_ack = (r_frm_ena && r2d_i_sof);   
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                        
  begin                                                                                        
   s0_r2d_sof           <=                                                                1'b0;
   s0_r2d_ena           <=                                                                1'b0;
   s0_r2d_bus[71:70]    <=                                                                2'd0;
  end 
 else  
  begin 
   s0_r2d_sof           <=                                                           r2d_i_sof;
   s0_r2d_ena           <= (r2d_i_sof)?                                 r_frm_ena : s0_r2d_ena;
   s0_r2d_bus[71:70]    <= (r_frm_ena  && r2d_i_sof)?                        r2d_header[71:70]: 
                           (s0_r2d_ena &&!r2d_i_sof)?                  2'h3: r2d_i_bus [71:70];
  end
  
//---------------------------------------------------------------------------------------------
always@(posedge clk)
   s0_r2d_bus[69:0]     <= (r_frm_ena  && r2d_i_sof)?                        r2d_header[69: 0]: 
                           (s0_r2d_ena &&!r2d_i_sof)?{6'h3F, INSERT_DWORD} : r2d_i_bus [69: 0];
//=============================================================================================
// remove packet from d2r bus
//=============================================================================================              
always@(posedge clk or posedge rst)
 if(rst)
  begin
   s0_d2r_sof            <=                                                               1'b0;
   s0_d2r_clr            <=                                                               1'b0;
   s0_d2r_ctrl.valid     <=                                                               1'b0; 
   
   s0_d2r_bus[71:70]     <=                                                               2'd0;
  end 
 else  
  begin
   s0_d2r_sof            <=                                                          d2r_i_sof;  
   s0_d2r_clr            <= (d2r_i_sof)?                            i_frm_clr_d2r : s0_d2r_clr; 
   s0_d2r_ctrl.valid     <=  (i_frm_clr_d2r && d2r_i_sof)?          1'd0:     d2r_i_ctrl.valid;
   s0_d2r_bus[71:70]     <=  (i_frm_clr_d2r && d2r_i_sof)?                        {1'b0, 1'b0}: // clear header
                             (s0_d2r_clr    &&!d2r_i_sof)?          2'd0:    d2r_i_bus [71:70];
  end 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk) begin
   s0_d2r_bus[69:0]      <= (i_frm_clr_d2r && d2r_i_sof)?                        {2'd0, 68'd0}: // clear header
                            (s0_d2r_clr    &&!d2r_i_sof)?          70'd0:    d2r_i_bus [69: 0];
   s0_d2r_ctrl[10:0]     <=  (i_frm_clr_d2r && d2r_i_sof)?         11'd0:     d2r_i_ctrl[10:0];
end
//=============================================================================================
assign  d2r_o_sof       =                                                           s0_d2r_sof;
assign  d2r_o_ctrl      =                                                          s0_d2r_ctrl; 
assign  d2r_o_bus       =                                                           s0_d2r_bus;

assign  r2d_o_sof       =                                                           s0_r2d_sof;
assign  r2d_o_bus       =                                                           s0_r2d_bus;
//---------------------------------------------------------------------------------------------
assign  pkt_intercepted =                                                           s0_d2r_clr;
//=============================================================================================
endmodule