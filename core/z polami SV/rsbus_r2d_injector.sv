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

module rsbus_r2d_injector
(                                                                                                                               
input  wire         clk,
input  wire         rst,   

input  wire         frm_i_stb,                                                               
input  wire         frm_i_sof,
input  rbus_word_t  frm_i_bus,
output wire  [1:0]  frm_i_af,   

input  wire         i_sof,
input  rbus_word_t  i_bus,
                                                          
output wire         o_sof,
output rbus_word_t  o_bus,

output reg          ff_err
);      
//=============================================================================================
// parameters
//=============================================================================================   
//=============================================================================================
// variables
//=============================================================================================
wire            frm_i_len;      
wire     [1:0]  frm_i_pp; 
reg     [ 3:0]  frm_i_pkt_dcnt; 
wire            frm_i_pkt_lst; 
reg             frm_i_lng_pending;
reg             frm_i_sh_pending; 
wire            xi_sh_stb;
wire    [71:0]  xi_sh_data;  
wire            xi_lng_stb;
wire    [71:0]  xi_lng_data;  
//---------------------------------------------------------------------------------------------       
wire            x0_sh_stb;
wire            x0_sh_sof;
wire    [71:0]  x0_sh_data;                                                                     

wire            x0_lng_stb;
wire            x0_lng_sof;
wire    [71:0]  x0_lng_data; 
//--------------------------------------------------------------------------------------------- 
reg             s0_sh_insert_ena;
reg             s0_sh_header_ack;                                                                  
                           
reg             s0_lng_insert_ena;
reg             s0_lng_header_ack; 
//---------------------------------------------------------------------------------------------
reg             s0_sof; 
reg     [71:0]  s0_data;           
//---------------------------------------------------------------------------------------------               
reg             s1_sof;       
reg             s1_sh_insert_ena;
reg             s1_lng_insert_ena;
reg             s1_insert_ena; 
reg      [3:0]  s1_x_lid; 
reg     [71:0]  s1_i_data;
reg     [71:0]  s1_x_data;
//---------------------------------------------------------------------------------------------               
reg             s2_sof;  
reg     [71:0]  s2_data;        
//---------------------------------------------------------------------------------------------
wire     [ 7:0] ff_errs;
//=============================================================================================
// input fifo
//=============================================================================================       
wire        i_empty   =                                                 !i_bus.header.frm_used;
wire        i_len     =                                                   i_bus.header.frm_len;
wire        i_free    =                                                                i_empty;
wire  [1:0] i_pp      =                                              i_bus.header.frm_priority;  
//--------------------------------------------------------------------------------------------- 
assign frm_i_len      =                                               frm_i_bus.header.frm_len;
assign frm_i_pp       =                                          frm_i_bus.header.frm_priority;
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)
     if( frm_i_lng_pending    )frm_i_pkt_dcnt    <=                      frm_i_pkt_dcnt - 4'd1;
else if( frm_i_sh_pending     )frm_i_pkt_dcnt    <=                      frm_i_pkt_dcnt - 4'd1;
else if( frm_i_stb &!frm_i_len)frm_i_pkt_dcnt    <=                                       4'hF;
else if( frm_i_stb & frm_i_len)frm_i_pkt_dcnt    <=                                       4'd6;
else                           frm_i_pkt_dcnt    <=                      frm_i_pkt_dcnt       ;  
//--------------------------------------------------------------------------------------------- 
assign frm_i_pkt_lst     =                                                   frm_i_pkt_dcnt[3]; 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
if(rst)                        frm_i_lng_pending <=                                       1'b0;
else if( frm_i_stb & frm_i_sof)frm_i_lng_pending <=                                  frm_i_len;
else if( frm_i_pkt_lst        )frm_i_lng_pending <=                                       1'b0;
else                           frm_i_lng_pending <=                          frm_i_lng_pending; 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
if(rst)                        frm_i_sh_pending  <=                                       1'b0;
else if( frm_i_stb & frm_i_sof)frm_i_sh_pending  <=                                 !frm_i_len;
else if( frm_i_pkt_lst        )frm_i_sh_pending  <=                                       1'b0;
else                           frm_i_sh_pending  <=                           frm_i_sh_pending;
//--------------------------------------------------------------------------------------------- 
wire unused0;       
ff_srl_af_ack_d16 
#(                                                                                    
.AF1LIMIT(6'd9+ 6'd1), // 1 for additional one clock cycle for af check in extractor
.WIDTH(73)
) fifo_for_lng_packets
(                     
 .clk           (clk),                         
 .rst           (rst),   
 
 .i_stb         (frm_i_lng_pending || (frm_i_stb & frm_i_len & frm_i_sof)),
 .i_data        ({frm_i_sof,frm_i_bus}),
 .i_af          ({frm_i_af[1], unused0}),    
 .i_full        (),
 .i_err         (ff_errs[0]), 
 
 .o_stb         (x0_lng_stb),
 .o_data        ({x0_lng_sof,x0_lng_data}),
 .o_ack         (s0_lng_insert_ena),  
 .o_ae          (),            
 .o_err         (ff_errs[1])
 ); 
 
ff_srl_af_ack_d16 #(.WIDTH(72)) fifo_for_lng_headers
(                     
 .clk           (clk),                         
 .rst           (rst),   
 
 .i_stb         (frm_i_stb & frm_i_len & frm_i_sof),
 .i_data        (frm_i_bus),
 .i_af          (),
 .i_full        (),
 .i_err         (ff_errs[2]), 
 
 .o_stb         (xi_lng_stb),
 .o_data        (xi_lng_data),                                            
 .o_ack         (s0_lng_header_ack),
 .o_ae          (),                                                        
 .o_err         (ff_errs[3])
 ); 
 
 
//--------------------------------------------------------------------------------------------- 
wire unused1;
ff_srl_af_ack_d16 #(
.AF0LIMIT(6'd2+ 6'd1), // 1 for additional one clock cycle for af check in extractor
.WIDTH(73)
) fifo_for_sh_packets
(                     
 .clk           (clk),                         
 .rst           (rst),   
 
 .i_stb         (frm_i_sh_pending || (frm_i_stb & !frm_i_len & frm_i_sof)),
 .i_data        ({frm_i_sof,frm_i_bus}),
 .i_af          ({unused1, frm_i_af[0]}),    
 .i_full        (),
 .i_err         (ff_errs[4]), 
 
 .o_stb         (x0_sh_stb),
 .o_data        ({x0_sh_sof,x0_sh_data}),
 .o_ack         (s0_sh_insert_ena), 
 .o_ae          (),            
 .o_err         (ff_errs[5])
 ); 
 
ff_srl_af_ack_d16 #(.WIDTH(72)) fifo_for_sh_headers
(                     
 .clk           (clk),                         
 .rst           (rst),   
 
 .i_stb         (frm_i_stb & !frm_i_len & frm_i_sof),
 .i_data        (frm_i_bus),
 .i_af          (),
 .i_full        (),
 .i_err         (ff_errs[6]), 
 
 .o_stb         (xi_sh_stb),
 .o_data        (xi_sh_data),                                            
 .o_ack         (s0_sh_header_ack),
 .o_ae          (),                                            
 .o_err         (ff_errs[7])
 ); 

//=============================================================================================
// in/out for inst/data cache
//============================================================================================= 
wire      f_sh_rdy       =                                                 xi_sh_stb  & !i_len; 
wire      f_sh_grant     =                                                  i_free &  f_sh_rdy;
wire      f_lng_rdy      =                                                 xi_lng_stb &  i_len; 
wire      f_lng_grant    =                                                  i_free & f_lng_rdy;
//=============================================================================================
// stage s0
//=============================================================================================
always@(posedge clk or posedge rst)
if(rst)                        
 begin                                                                                   
  s0_sof                <=                                                                1'b0;    
  s0_data[71:68]        <=                                                                4'b0;   
  
  s0_sh_insert_ena      <=                                                                1'b0;
  s0_sh_header_ack      <=                                                                1'b0;
  s0_lng_insert_ena     <=                                                                1'b0; 
  s0_lng_header_ack     <=                                                                1'b0;
 end                              
else  
 begin                                                                                      
  s0_sof                <=                                                               i_sof;  
  s0_data[71:68]        <=                                                        i_bus[71:68];
  
  s0_sh_insert_ena      <= (i_sof) ?                           f_sh_grant  :  s0_sh_insert_ena; 
  s0_sh_header_ack      <= (i_sof) ?                           f_sh_grant  :              1'b0;
  s0_lng_insert_ena     <= (i_sof) ?                           f_lng_grant : s0_lng_insert_ena; 
  s0_lng_header_ack     <= (i_sof) ?                           f_lng_grant :              1'b0;
 end     
//--------------------------------------------------------------------------------------------- 
always@(posedge clk) 
 begin                                                                                         
  s0_data[67: 0]         <=                                                   i_bus[67: 0];
 end
//=============================================================================================
// stage s1
//=============================================================================================
always@(posedge clk or posedge rst)
if(rst)                        
 begin                                                                                          
  s1_sof                <=                                                                1'b0;    
                                                                                                 
  s1_sh_insert_ena      <=                                                                1'b0; 
  s1_lng_insert_ena     <=                                                                1'b0; 
  s1_insert_ena         <=                                                                1'b0;
  
  s1_i_data[71:68]      <=                                                                4'b0;    
  
  s1_x_data[71:68]      <=                                                                4'b0;    
  s1_x_lid              <=                                                                4'b0;    
 end 
else  
 begin                                                                                      
  s1_sof                <=                                                              s0_sof;       
                                                                                               
  s1_sh_insert_ena      <=                                                    s0_sh_insert_ena;
  s1_lng_insert_ena     <=                                                   s0_lng_insert_ena;
  s1_insert_ena         <=                                s0_sh_insert_ena | s0_lng_insert_ena;   

  s1_i_data[71:68]      <=                                                      s0_data[71:68];
  
  s1_x_data[71:68]      <= (s0_sh_insert_ena)?         x0_sh_data[71:68] :  x0_lng_data[71:68];    
 end     
//---------------------------------------------------------------------------------------------
always@(posedge clk)
 begin                                                                                             
  s1_i_data[67: 0]      <=                                                      s0_data[67: 0];    
  
  s1_x_data[38: 0]      <= (s0_sh_insert_ena)?         x0_sh_data[38: 0] :  x0_lng_data[38: 0];
  s1_x_data[   39]      <= (s0_sh_insert_ena)?         x0_sh_data[   39] :  x0_lng_data[   39];
  s1_x_data[47:40]      <= (s0_sh_insert_ena)?         x0_sh_data[47:40] :  x0_lng_data[47:40];
  s1_x_data[67:48]      <= (s0_sh_insert_ena)?         x0_sh_data[67:48] :  x0_lng_data[67:48];   
 end     
//=============================================================================================
// stage s2
//=============================================================================================
always@(posedge clk or posedge rst)
 if(rst)
  begin
   s2_sof               <=                                                                1'b0;   
   s2_data[71:68]       <=                                                                4'd0;
  end                                                                                        
 else
  begin
   s2_sof               <=                                                              s1_sof;   
   s2_data[   71]       <= (s1_insert_ena) ?               s1_x_data[   71] : s1_i_data[   71];   
   s2_data[   70]       <= (s1_insert_ena) ?(s1_sof? 1'b0 :s1_x_data[   70]): s1_i_data[   70];   
   s2_data[69:68]       <= (s1_insert_ena) ?               s1_x_data[69:68] : s1_i_data[69:68];
  end
//--------------------------------------------------------------------------------------------- 
always@(posedge clk) 
  begin                                                                                         
   s2_data[67: 0]       <= (s1_insert_ena) ?               s1_x_data[67: 0] : s1_i_data[67: 0]; 
  end
//=============================================================================================
// output
//=============================================================================================  
always@(posedge clk or posedge rst)
 if(rst)              ff_err           <=                                                 1'b0;                                                                                    
 else if(|ff_errs   ) ff_err           <=                                                 1'b1;                                                                                    
 else                 ff_err           <=                                               ff_err;
//=============================================================================================   
assign  o_sof           =                                                               s2_sof;
assign  o_bus           =                                                              s2_data;
//=============================================================================================                      
endmodule