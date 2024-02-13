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
parameter [39:0]    SEND_WR_FB   = "TRUE"  // "TRUE", "FALSE" 
)
(
input  wire         clk,    
input  wire         rst,    
 
input  wire         d2r_i_sof,    
input  wire [11:0]  d2r_i_ctrl,   
input  wire [71:0]  d2r_i_bus,   

output wire         d2r_o_sof,    
output wire [11:0]  d2r_o_ctrl,   
output wire [71:0]  d2r_o_bus, 
 
input  wire         r2d_i_sof,    
input  wire [71:0]  r2d_i_bus,   

output wire         r2d_o_sof,    
output wire [71:0]  r2d_o_bus,   

output wire         pkt_intercepted
);               
//=============================================================================================
// parameters check
//=============================================================================================   
// pragma translate_off
initial
    begin
        if((SEND_WR_FB[31:0] != "TRUE") && (SEND_WR_FB[39:0] != "FALSE"))        
            begin
            $display( "%m !!!ERROR!!! SEND_WR_FB = %s, is out of range (\"TRUE\" \"FALSE\")", SEND_WR_FB );
            $finish;
            end 
    end
// pragma translate_on                                                                               
//=============================================================================================
// variables
//============================================================================================= 
reg         r2d_stb;
reg  [71:0] r2d_header;   
wire        r2d_bsy;  
wire        r2d_ack;
//---------------------------------------------------------------------------------------------                                                                         
reg         s0_r2d_sof; 
reg  [71:0] s0_r2d_bus; 
reg  [11:0] s0_ctrl;     
reg         s0_r2d_ena;                       
//---------------------------------------------------------------------------------------------
reg         s0_d2r_sof;
reg  [11:0] s0_d2r_ctrl;
reg  [71:0] s0_d2r_bus;       
reg         s0_d2r_clr;                                                                        
//=============================================================================================                  
// stage 0
//=============================================================================================  
// tx
wire        i_frm_stb     =                                                      d2r_i_bus[71];
wire        i_frm_len     =                                                      d2r_i_bus[39]; 
wire        i_frm_pha     =                                                      !d2r_i_bus[2]; 
//---------------------------------------------------------------------------------------------
wire        i_frm_rd1     =                                            d2r_i_bus[1:0] == 2'b00; 
wire        i_frm_rd8     =                                            d2r_i_bus[1:0] == 2'b01; 
wire        i_frm_wra     =                                            d2r_i_bus[1:0] == 2'b10; 
wire        i_frm_upda    =                                            d2r_i_bus[1:0] == 2'b11; 
//---------------------------------------------------------------------------------------------	
wire        i_frm_wr      =                                                          i_frm_wra;  
wire        i_frm_rd      =                                 i_frm_rd1 | i_frm_rd8 | i_frm_upda; 
wire        i_frm_rd_len  =                               i_frm_rd8 | (i_frm_upda & i_frm_len);
wire        i_frm_reco    =                                                      d2r_i_bus[70];
wire [1:0]  i_frm_pr      =                                                   d2r_i_bus[69:68]; 
wire        i_frm_clr_d2r =                             !r2d_bsy && !i_frm_reco && i_frm_stb  ; 
wire        i_frm_ins_r2d =                             !r2d_bsy && !i_frm_reco && i_frm_stb &&
                                              (((SEND_WR_FB == "TRUE") & i_frm_wr) | i_frm_rd);    
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
  r2d_header[71]    <=                                                                    1'b1;
  r2d_header[70]    <=                                                                    1'b0;
  r2d_header[69:68] <=                                                        d2r_i_bus[69:68];
  r2d_header[67:40] <=                                                        d2r_i_bus[67:40];
  r2d_header[39]    <=                                                            i_frm_rd_len;// packet lenght depends on memory operation code
  r2d_header[38:0]  <=                                                        d2r_i_bus[38: 0];
end else
  r2d_header        <=                                                              r2d_header;                                                                                      
//--------------------------------------------------------------------------------------------- 
assign r2d_bsy = r2d_stb;                                                                                 
//=============================================================================================
// mux response into r2d bus
//============================================================================================= 
wire        r_frm_stb   =                                                              r2d_stb;
wire        r_frm_len   =                                                       r2d_header[39];
wire        r_frm_enaX1 =                            r_frm_stb && (r_frm_len == r2d_i_bus[39]);
wire        r_frm_empty =                                                       !r2d_i_bus[71];
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
                           (s0_r2d_ena &&!r2d_i_sof)?                  2'h0: r2d_i_bus [71:70];
  end
  
//---------------------------------------------------------------------------------------------
always@(posedge clk)
   s0_r2d_bus[69:0]     <= (r_frm_ena  && r2d_i_sof)?                        r2d_header[69: 0]: 
                           (s0_r2d_ena &&!r2d_i_sof)?  {6'h00, "E", 56'h0} : r2d_i_bus [69: 0];
//=============================================================================================
// remove packet from d2r bus
//=============================================================================================              
always@(posedge clk or posedge rst)
 if(rst)
  begin
   s0_d2r_sof            <=                                                               1'b0;
   s0_d2r_clr            <=                                                               1'b0;
   s0_d2r_ctrl[11]       <=                                                               1'b0; 
   
   s0_d2r_bus[71:70]     <=                                                               2'd0;
  end 
 else  
  begin
   s0_d2r_sof            <=                                                          d2r_i_sof;  
   s0_d2r_clr            <=  (d2r_i_sof)?                           i_frm_clr_d2r : s0_d2r_clr; 
   s0_d2r_ctrl[11]       <=  (i_frm_clr_d2r && d2r_i_sof)?          1'd0:       d2r_i_ctrl[11];
   s0_d2r_bus[71:70]     <=  (i_frm_clr_d2r && d2r_i_sof)?                        {1'b0, 1'b0}: // clear header
                             (s0_d2r_clr    &&!d2r_i_sof)?          2'd0:    d2r_i_bus [71:70];
  end 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk) begin
   s0_d2r_bus[69:0]      <=  (i_frm_clr_d2r && d2r_i_sof)?                       {2'd0, 68'd0}: // clear header
                             (s0_d2r_clr    &&!d2r_i_sof)?         70'd0:    d2r_i_bus [69: 0];
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