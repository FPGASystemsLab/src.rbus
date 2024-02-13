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
input  wire [71:0]  frm_i_bus,
output wire  [1:0]  frm_i_rdy,   

input  wire         i_sof,
input  wire [71:0]  i_bus,
                                                          
output wire         o_sof,
output wire [71:0]  o_bus,

output reg          ff_err
);                                                                                                
//=============================================================================================
// variables
//=============================================================================================
wire            frm_i_len;   

wire            i_empty;
wire            i_len;  
wire            i_free;      
//---------------------------------------------------------------------------------------------
reg             s0_sof; 
reg     [71:0]  s0_i_data;            

reg             s0_sh_try_insert;
reg             s0_sh_trg;  
reg             s0_lng_try_insert;
reg             s0_lng_trg; 
//---------------------------------------------------------------------------------------------               
reg             s1_sof;       
reg             s1_try_insert; 
reg     [71:0]  s1_i_data;       
//---------------------------------------------------------------------------------------------               
reg             s2_sof;       
reg             s2_try_insert; 
reg     [71:0]  s2_i_data; 
  
wire            s2_int_en;
wire            s2_int_sof;
wire    [71:0]  s2_int_data;
//---------------------------------------------------------------------------------------------               
reg             s3_sof;       
reg     [71:0]  s3_data;       
//---------------------------------------------------------------------------------------------
wire            ff_errs;
//=============================================================================================
// input fifo
//=============================================================================================       
assign i_empty        =                                                             !i_bus[71];
assign i_len          =                                                              i_bus[39];
assign i_free         =                                                                i_empty; 
//--------------------------------------------------------------------------------------------- 
assign frm_i_len      =                                                          frm_i_bus[39];
//--------------------------------------------------------------------------------------------- 
rbus_2ch_ff
#(
.TRIGGER_WITH_EMPTY_FF_IS_OK ("YES")
)
fifo_int
(
.clk        (clk),
.rst        (rst),

.frm_i_stb  (frm_i_stb),
.frm_i_sof  (frm_i_sof),
.frm_i_bus  (frm_i_bus),
.frm_i_rdy  (frm_i_rdy), 
            
.frm_o_en   (s2_int_en),
.frm_o_sof  (s2_int_sof),
.frm_o_bus  (s2_int_data),

.has_long   (),
.has_short  (),
.trg_long   (s0_lng_trg),
.trg_short  (s0_sh_trg),

.ff_err     (ff_errs)
);                            
//=============================================================================================
// in/out for inst/data cache
//============================================================================================= 
wire      f_sh_can_insert  =                                           i_sof & i_free & !i_len;
wire      f_lng_can_insert =                                           i_sof & i_free &  i_len;
//=============================================================================================
// stage s0 - trigger decision
//=============================================================================================
always@(posedge clk or posedge rst)
if(rst)                        
 begin                                                                                   
  s0_sof                <=                                                                1'b0;    
  s0_i_data[71:68]      <=                                                                4'b0;   
  
  s0_sh_try_insert      <=                                                                1'b0;
  s0_sh_trg             <=                                                                1'b0;
  s0_lng_try_insert     <=                                                                1'b0; 
  s0_lng_trg            <=                                                                1'b0;
 end                              
else  
 begin                                                                                      
  s0_sof                <=                                                               i_sof;  
  s0_i_data[71:68]      <=                                                        i_bus[71:68];
  
  s0_sh_try_insert      <= (i_sof) ?                      f_sh_can_insert  :  s0_sh_try_insert; 
  s0_sh_trg             <= (i_sof) ?                      f_sh_can_insert  :              1'b0;
  s0_lng_try_insert     <= (i_sof) ?                      f_lng_can_insert : s0_lng_try_insert; 
  s0_lng_trg            <= (i_sof) ?                      f_lng_can_insert :              1'b0;
 end     
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)   
  s0_i_data[67: 0]      <=                                                        i_bus[67: 0];
//=============================================================================================
// stage s1 - bypass
//=============================================================================================
always@(posedge clk or posedge rst)
if(rst)                        
 begin                                                                                          
  s1_sof                <=                                                                1'b0; 
  s1_try_insert         <=                                                                1'b0;
  s1_i_data[71:68]      <=                                                                4'b0;    
 end 
else  
 begin                                                                                      
  s1_sof                <=                                                              s0_sof; 
  s1_try_insert         <=                                s0_sh_try_insert | s0_lng_try_insert; 
  s1_i_data[71:68]      <=                                                    s0_i_data[71:68];   
 end     
//---------------------------------------------------------------------------------------------
always@(posedge clk)       
  s1_i_data[67: 0]      <=                                                    s0_i_data[67: 0]; 
//=============================================================================================
// stage s2 - bypass
//=============================================================================================
always@(posedge clk or posedge rst)
if(rst)                        
 begin                                                                                          
  s2_sof                <=                                                                1'b0;  
  s2_try_insert         <=                                                                1'b0;
  s2_i_data[71:68]      <=                                                                4'b0;   
 end 
else  
 begin                                                                                      
  s2_sof                <=                                                              s1_sof;
  s2_try_insert         <=                                                       s1_try_insert; 
  s2_i_data[71:68]      <=                                                    s1_i_data[71:68];    
 end     
//---------------------------------------------------------------------------------------------
always@(posedge clk)       
  s2_i_data[67: 0]      <=                                                    s1_i_data[67: 0]; 
//=============================================================================================
// stage s3 - mux
//=============================================================================================
always@(posedge clk or posedge rst)
 if(rst)
  begin
   s3_sof               <=                                                                1'b0;   
   s3_data[71:68]       <=                                                                4'd0;
  end                                                                                        
 else
  begin
   s3_sof               <=                                                              s2_sof;   
   s3_data[   71]       <= (s2_int_en) ?                 s2_int_data[   71] : s2_i_data[   71];   
   s3_data[   70]       <= (s2_int_en) ?  (s2_sof? 1'b0 :s2_int_data[   70]): s2_i_data[   70];   
   s3_data[69:68]       <= (s2_int_en) ?                 s2_int_data[69:68] : s2_i_data[69:68];
  end
//--------------------------------------------------------------------------------------------- 
always@(posedge clk) 
  begin                                                                                         
   s3_data[67: 0]       <= (s2_int_en) ?                 s2_int_data[67: 0] : s2_i_data[67: 0]; 
  end
//=============================================================================================
// output
//=============================================================================================  
always@(posedge clk or posedge rst)
 if(rst)              ff_err           <=                                                 1'b0;                                                                                    
 else if( ff_errs   ) ff_err           <=                                                 1'b1;                                                                                    
 else                 ff_err           <=                                               ff_err;
//=============================================================================================   
assign  o_sof           =                                                               s3_sof;
assign  o_bus           =                                                              s3_data;
//=============================================================================================                      
endmodule