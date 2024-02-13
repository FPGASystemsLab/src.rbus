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
input  wire [11:0]  i_ctrl,
input  wire [71:0]  i_bus,   

output wire         o_sof,
output wire [11:0]  o_ctrl,
output wire [71:0]  o_bus
);  
`ifdef NO_SHIFT_REGS
	rsbus_frame_generator_dram fg
	(	  
       .clk    (clk   ),
       .rst    (rst   ),
       .i_sof  (i_sof ),
       .i_ctrl (i_ctrl),
       .i_bus  (i_bus ),
       .o_sof  (o_sof ),
       .o_ctrl (o_ctrl),
       .o_bus  (o_bus )
	 );
`else   
	rsbus_frame_generator_shreg fg
	(	  
       .clk    (clk   ),
       .rst    (rst   ),
       .i_sof  (i_sof ),
       .i_ctrl (i_ctrl),
       .i_bus  (i_bus ),
       .o_sof  (o_sof ),
       .o_ctrl (o_ctrl),
       .o_bus  (o_bus )
	 );
`endif	
endmodule
//=============================================================================================
module rsbus_frame_generator_shreg
(
input  wire         clk,
input  wire         rst,   

input  wire         i_sof,
input  wire [11:0]  i_ctrl,
input  wire [71:0]  i_bus,   

output wire         o_sof,
output wire [11:0]  o_ctrl,
output wire [71:0]  o_bus
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
reg     [ 3:0]  s0_offset_m1;
reg             s0_beg;
reg             s0_end;
reg             s0_rst_offset;
reg             s0_dec_offset;
reg     [10:0]  s0_frm;
reg     [10:0]  s0_eof;
wire    [11:0]  s0_ctrl;
wire    [71:0]  s0_bus;
//---------------------------------------------------------------------------------------------
reg             s1_sof;
`ifdef XILINX_NO_SHREG_AT_GEN_OUT
reg     [11:0]  s1_ctrl/* synthesis shreg_extract="no" */;
reg     [71:0]  s1_bus/* synthesis shreg_extract="no" */;  
`else 
reg     [11:0]  s1_ctrl;
reg     [71:0]  s1_bus;         
`endif                         
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
     s0_rst_offset  <=                                                                    1'b0; 
     s0_dec_offset  <=                                                                    1'b0; 
     s0_offset      <=                                                                    4'd0;  
     s0_offset_m1   <=                                                                    4'd0;  
    end
  else
    begin
     s0_beg         <=  (s0_frm[0]         ) ?                                   1'b1 : s0_beg;  
     s0_end         <=  (i_sof             ) ?                                   1'b1 : s0_end;  
     s0_frm         <=                                                {s0_frm[9:0],s0_frm[10]};
     s0_eof         <=                                                {s0_eof[9:0],s0_eof[10]};
     s0_rst_offset  <=                                        s0_eof[10] && !(i_sof || s0_end); 
     s0_dec_offset  <=                             (s0_frm[0] || s0_beg) && !(i_sof || s0_end);
     
     if(s0_rst_offset)//s0_eof[0] && !s0_end)
      s0_offset     <=                                                                   4'd10;
     else if(s0_dec_offset)//s0_beg && !s0_end) 
      s0_offset     <=                                                            s0_offset_m1;
     else 
      s0_offset     <=                                                               s0_offset;
     if(s0_rst_offset)//s0_eof[0] && !s0_end)
      s0_offset_m1  <=                                                                    4'd9; 
     else
      s0_offset_m1  <=                                                     s0_offset_m1 - 4'd1;  
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
   s1_ctrl[11]                 <=                                                         1'b0;       
   s1_bus[71:68]               <=                                                          'd0;
   s1_bus[39]                  <=                                                         1'd0;    
  end  
 else 
  begin      
   s1_sof                      <=                                                    s0_frm[0];    
   s1_ctrl[11]                 <=                                                  s0_ctrl[11];
   s1_bus[71:68]               <=                                                s0_bus[71:68];
   s1_bus[39]                  <=            s0_frm[0] ?               !s0_frm[9] : s0_bus[39];    
  end   
//---------------------------------------------------------------------------------------------       
always@(posedge clk) 
  begin          
   s1_ctrl[10:0]               <=                                                s0_ctrl[10:0];
   
   s1_bus[67:40]               <=                                                s0_bus[67:40];
    
   s1_bus[38:0]                <=                                                 s0_bus[38:0];
  end
//=============================================================================================
// output
//=============================================================================================
assign  o_sof        =                                                                  s1_sof;   
assign  o_ctrl       =                                                                 s1_ctrl;
assign  o_bus        =                                                                  s1_bus;
//=============================================================================================
endmodule

module rsbus_frame_generator_dram
(
input  wire         clk,
input  wire         rst,   

input  wire         i_sof,
input  wire [11:0]  i_ctrl,
input  wire [71:0]  i_bus,   

output wire         o_sof,
output wire [11:0]  o_ctrl,
output wire [71:0]  o_bus
);                                                                                                                                                        
//=============================================================================================
// variables
//=============================================================================================  
localparam      _cs   =   $bits(rbus_ctrl_t);       // control word size
localparam      _ws   =   $bits(rbus_word_t);       // bus word size
localparam      _ts   =   _cs + _ws;                 // 
//---------------------------------------------------------------------------------------------
`ifdef ALTERA
reg  [_ts-1:0]  s0_buffer [0:10]/* synthesis syn_ramstyle="no_rw_check,MLAB" */;        
`else
reg  [_ts-1:0]  s0_buffer [0:10]/* synthesis syn_ramstyle="select_ram,no_rw_check" */;          
`endif                                       
reg     [ 3:0]  s0_rd_ptr;
wire    [ 3:0]  s0_rd_ptrX;                  
reg     [ 3:0]  s0_rd_ptr_p1;
reg             s0_rd_ptr_rst;
reg     [ 3:0]  i_wr_ptr;
reg     [ 3:0]  i_wr_ptr_p1;
reg             i_wr_ptr_rst;
reg             s0_beg;        
reg             s0_end;
reg     [10:0]  s0_frm;
reg     [10:0]  s0_eof;
wire    [11:0]  s0_ctrl;
wire    [71:0]  s0_bus;
reg     [11:0]  s0_ctrlX;
reg     [71:0]  s0_busX;
//---------------------------------------------------------------------------------------------
reg             s1_sof;
`ifdef XILINX_NO_SHREG_AT_GEN_OUT
reg     [11:0]  s1_ctrl/* synthesis shreg_extract="no" */;
reg     [71:0]  s1_bus/* synthesis shreg_extract="no" */;  
`else 
reg     [11:0]  s1_ctrl;
reg     [71:0]  s1_bus;         
`endif                          
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
     s0_rd_ptr      <=                                                                    4'd0; 
     s0_rd_ptr_p1   <=                                                                    4'd0; 
     i_wr_ptr       <=                                                                    4'd0; 
     i_wr_ptr_p1    <=                                                                    4'd0;  
     s0_rd_ptr_rst  <=                                                                    1'b0;  
     i_wr_ptr_rst   <=                                                                    1'b0; 
    end
  else
    begin
     s0_beg         <=  (s0_frm[10]        ) ?                                   1'b1 : s0_beg;  
     s0_end         <=  (i_sof             ) ?                                   1'b1 : s0_end;  
     s0_frm         <=                                                {s0_frm[9:0],s0_frm[10]};
     s0_eof         <=                                                {s0_eof[9:0],s0_eof[10]};
     s0_rd_ptr_rst  <=                            ~(s0_frm[10] || s0_beg) || s0_rd_ptr == 4'd9;  
     i_wr_ptr_rst   <=                                                        i_wr_ptr == 4'd9; 
     
    //i_wr_ptr      <=  (~s0_end && i_sof)? 4'd1 : (i_wr_ptr == 4'd10)?4'd0 :  i_wr_ptr + 4'd1;
     i_wr_ptr_p1    <=  (~s0_end && i_sof)? 4'd2 : (i_wr_ptr_rst     )?4'd1 : i_wr_ptr_p1+4'd1; 
     i_wr_ptr       <=  (~s0_end && i_sof)? 4'd1 : (i_wr_ptr_rst     )?4'd0 :      i_wr_ptr_p1;
    //s0_rd_ptr     <=  (~s0_beg            || s0_rd_ptr == 4'd10)?    4'd0 : s0_rd_ptr + 4'd1;
     s0_rd_ptr_p1   <=  (                           s0_rd_ptr_rst)?    4'd1 :s0_rd_ptr_p1+4'd1; 
     s0_rd_ptr      <=  (                           s0_rd_ptr_rst)?    4'd0 :     s0_rd_ptr_p1;
    end                 
//assign s0_rd_ptrX  =  (~s0_beg            || s0_rd_ptr == 4'd10)?    4'd0 : s0_rd_ptr + 4'd1; 
assign s0_rd_ptrX    =  (                           s0_rd_ptr_rst)?    4'd0 :     s0_rd_ptr_p1;    
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)
begin
                      s0_buffer[i_wr_ptr]               <=                      {i_ctrl,i_bus};
`ifdef ALTERA 
       {s0_ctrlX,s0_busX}      <=                                        s0_buffer[s0_rd_ptrX];
`endif
end                      

`ifndef ALTERA
assign {s0_ctrl,s0_bus}         =                                         s0_buffer[s0_rd_ptr];
`endif
//=============================================================================================
// stage 1
//=============================================================================================
always@(posedge clk or posedge rst)
 if(rst)                        
  begin         
   s1_sof                      <=                                                         1'b0;
`ifdef ALTERA 
   s1_ctrl[11]                 <=                                                         1'b0; 
   s1_bus[71:68]               <=                                                          'd0;
   s1_bus[39]                  <=                                                         1'd0; 
`else       
   s1_ctrl[11]                 <=                                                         1'b0; 
   s1_bus[71:68]               <=                                                          'd0;
   s1_bus[39]                  <=                                                         1'd0; 
`endif         
  end  
 else 
  begin      
   s1_sof                      <=                                                    s0_frm[0];
`ifdef ALTERA 
   s1_ctrl[11]                 <=                                                 s0_ctrlX[11];
   s1_bus[71:68]               <=                                               s0_busX[71:68];
   s1_bus[39]                  <=            s0_frm[0] ?              !s0_frm[9] : s0_busX[39]; 
`else       
   s1_ctrl[11]                 <=                                                  s0_ctrl[11];
   s1_bus[71:68]               <=                                                s0_bus[71:68];
   s1_bus[39]                  <=            s0_frm[0] ?               !s0_frm[9] : s0_bus[39]; 
`endif   
  end   
//---------------------------------------------------------------------------------------------    
always@(posedge clk) 
  begin     
`ifdef ALTERA 
   s1_ctrl[10:0]               <=                                               s0_ctrlX[10:0];
   
   s1_bus[67:40]               <=                                               s0_busX[67:40];
    
   s1_bus[38:0]                <=                                                s0_busX[38:0];  
`else         
   s1_ctrl[10:0]               <=                                                s0_ctrl[10:0];
   
   s1_bus[67:40]               <=                                                s0_bus[67:40];
    
   s1_bus[38:0]                <=                                                 s0_bus[38:0];
`endif
  end
//=============================================================================================
// output
//=============================================================================================
assign  o_sof        =                                                                  s1_sof;   
assign  o_ctrl       =                                                                 s1_ctrl;
assign  o_bus        =                                                                  s1_bus;
//=============================================================================================
endmodule