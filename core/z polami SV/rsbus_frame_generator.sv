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

module rsbus_frame_generator
(
input  wire         clk,
input  wire         rst,   

input  wire         i_sof,
input  rbus_ctrl_t  i_ctrl,
input  rbus_word_t  i_bus,   

output wire         o_sof,
output rbus_ctrl_t  o_ctrl,
output rbus_word_t  o_bus
);                                                                                                                                                        
//=============================================================================================
// variables
//=============================================================================================  
localparam      _cs   =   $bits(rbus_ctrl_t);       // control word size
localparam      _ws   =   $bits(rbus_word_t);       // bus word size
localparam      _ts   =   _cs + _ws;                 // 
//---------------------------------------------------------------------------------------------
reg  [_ts-1:0]  s0_buffer [0:15];
reg     [ 3:0]  s0_offset;
reg             s0_beg;
reg             s0_end;
reg     [10:0]  s0_frm;
reg     [10:0]  s0_eof;
rbus_ctrl_t     s0_ctrl;
rbus_word_t     s0_bus;
//---------------------------------------------------------------------------------------------
reg             s1_sof;
rbus_ctrl_t     s1_ctrl;
rbus_word_t     s1_bus;
//=============================================================================================
// stage 0
//=============================================================================================  
always@(posedge clk or posedge rst)
  if(rst)
    begin   
     s0_beg         <=                                                                    1'd0;  
     s0_end         <=                                                                    1'b0;  
     s0_frm         <=                                                        11'b000000010_10;//gdy 11'b10_100000000; to rejestr przeswny nie zdazy sie zaladowac zerami przed startem
     s0_eof         <=                                                        11'b000000010_00;//gdy 11'b10_000000000; to rejestr przeswny nie zdazy sie zaladowac zerami przed startem
     s0_offset      <=                                                                    4'd0;  
    end
  else
    begin
     s0_beg         <=  (s0_frm[0]         ) ?                                   1'b1 : s0_beg;  
     s0_end         <=  (i_sof             ) ?                                   1'b1 : s0_end;  
     s0_frm         <=                                                {s0_frm[9:0],s0_frm[10]};
     s0_eof         <=                                                {s0_eof[9:0],s0_eof[10]};
     
     if(s0_eof[0] && !s0_end)
      s0_offset     <=                                                                   4'd10;
     else if(s0_beg && !s0_end) 
      s0_offset     <=                                                        s0_offset - 4'd1;
    end     
//--------------------------------------------------------------------------------------------- 
generate
genvar k;
    for(k=0;k<16;k=k+1) 
     begin : shift_register
        if(k==0)
            begin : stage0
                always@(posedge clk) s0_buffer[k]       <=                      {i_ctrl,i_bus};
            end     
        else    
            begin : stageN
                always@(posedge clk) s0_buffer[k]       <=                      s0_buffer[k-1];
            end     
       end
endgenerate
//---------------------------------------------------------------------------------------------       
assign {s0_ctrl,s0_bus}         =                                         s0_buffer[s0_offset];
//=============================================================================================
// stage 1
//=============================================================================================
always@(posedge clk or posedge rst)
 if(rst)                        
  begin         
   s1_sof                      <=                                                         1'b0;       
   s1_ctrl.valid               <=                                                         1'b0;       
   s1_bus.header.frm_used      <=                                                         1'd0;
   s1_bus.header.frm_owned     <=                                                         1'd0;
   s1_bus.header.frm_priority  <=                                                         2'd0;
   s1_bus.header.frm_len       <=                                                         1'd0;    
  end  
 else 
  begin      
   s1_sof                      <=                                                    s0_frm[0];    
   s1_ctrl.valid               <=                                                s0_ctrl.valid;
   s1_bus.header.frm_used      <=                                       s0_bus.header.frm_used;
   s1_bus.header.frm_owned     <=                                      s0_bus.header.frm_owned;
   s1_bus.header.frm_priority  <=                                   s0_bus.header.frm_priority;
   s1_bus.header.frm_len       <= s0_frm[0] ?               !s0_frm[9] : s0_bus.header.frm_len;    
  end   
//---------------------------------------------------------------------------------------------       
always@(posedge clk) 
  begin          
   s1_ctrl.len                 <=                                                  s0_ctrl.len;
   s1_ctrl.pp                  <=                                                  s0_ctrl.pp ; 
   s1_ctrl.did                 <=                                                  s0_ctrl.did;
   s1_ctrl.rid                 <=                                                  s0_ctrl.rid;
   
   s1_bus.header.net_addr      <=                                       s0_bus.header.net_addr;
   s1_bus.header.frm_sid       <=                                       s0_bus.header.frm_sid ;
   s1_bus.header.frm_rid       <=                                       s0_bus.header.frm_rid ;
    
   s1_bus.header.mem_addr      <=                                       s0_bus.header.mem_addr;
   s1_bus.header.mem_space     <=                                      s0_bus.header.mem_space;
   s1_bus.header.mem_op        <=                                         s0_bus.header.mem_op;
  end
//=============================================================================================
// output
//=============================================================================================
assign  o_sof        =                                                                  s1_sof;   
assign  o_ctrl       =                                                                 s1_ctrl;
assign  o_bus        =                                                                  s1_bus;
//=============================================================================================
endmodule