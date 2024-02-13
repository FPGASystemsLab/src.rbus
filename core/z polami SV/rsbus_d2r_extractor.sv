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

module rsbus_d2r_extractor
#(                        
parameter           SPACE_CHECKING      =                                                "OFF",
parameter [38:0]    SPACE_START_ADDRESS =                                      39'h0_0000_0000,
parameter [38:0]    SPACE_LAST_ADDRESS  =                                      39'h0_0000_0000
)
(                                                                                                                  
input  wire         clk,
input  wire         rst,   

input  wire         i_sof,
input  rbus_ctrl_t  i_ctrl,
input  rbus_word_t  i_bus,   

output wire         o_sof,
output rbus_ctrl_t  o_ctrl,
output rbus_word_t  o_bus,

output wire         frm_o_stb,
output wire         frm_o_sof,
output rbus_word_t  frm_o_bus,
input  wire [ 1:0]  frm_o_af
);      
//=============================================================================================
// parameters
//=============================================================================================      
//parameter     ACK_ID          =                                                                     4'd0;                                                                                                                              
// pragma translate_off
initial
    begin
        if((SPACE_CHECKING != "ON") && (SPACE_CHECKING != "OFF"))             
            begin
           $display( "SPACE_CHECKING = %s, is out of range (\"ON\" / \"OFF\")", SPACE_CHECKING );  
            $finish;
            end  
           
        else if((SPACE_CHECKING == "ON")&&(SPACE_LAST_ADDRESS < SPACE_START_ADDRESS)) 
            begin
           $display( "!!!ERROR!!! SPACE_LAST_ADDRESS (%d) < SPACE_START_ADDRESS (%d)",SPACE_LAST_ADDRESS, SPACE_START_ADDRESS );
            $finish;
            end       
    end
// pragma translate_on
//=============================================================================================
// variables
//=============================================================================================   
reg         s0_sof;
rbus_ctrl_t s0_ctrl;
rbus_word_t s0_bus; 
reg         s0_reco;
reg         s0_hdr_ena;
reg         s0_ena;   
//---------------------------------------------------------------------------------------------  
reg         s1_sof;
rbus_ctrl_t s1_ctrl;         
rbus_word_t s1_bus;
//=============================================================================================                  
// flags
//=============================================================================================  
wire        i_frm_stb    =                                               i_bus.header.frm_used;
wire        i_frm_len    =                                               i_bus.header.frm_len ; 
wire        i_frm_pha    =                                  i_bus.header.mem_space == PHYSICAL;
wire [3:0]  i_frm_did    =                                          i_bus.header.net_addr.lid0;
wire [38:0] i_frm_addr   =                                        {i_bus.header.mem_addr,3'd0};
//--------------------------------------------------------------------------------------------- 
wire        f_frm_enaX1S =                                 (i_frm_len == 1'b0 && !frm_o_af[0]); 
wire        f_frm_enaX1L =                                 (i_frm_len == 1'b1 && !frm_o_af[1]);
wire        f_frm_enaX1  =                                        f_frm_enaX1S || f_frm_enaX1L;
wire        f_frm_enaX2  =                                                           i_frm_pha;
//---------------------------------------------------------------------------------------------        
wire        f_addr_beg   =                  {1'b0,i_frm_addr} >= {1'b0,(SPACE_START_ADDRESS )};
wire        f_addr_end   =                  {1'b0,i_frm_addr}  < {1'b0,(SPACE_LAST_ADDRESS+1)};
wire        f_addr_ok    =                                             f_addr_beg & f_addr_end;
wire        f_addr_ena   = (SPACE_CHECKING=="OFF")?                           1'b1 : f_addr_ok;
//--------------------------------------------------------------------------------------------- 
wire        f_frm_ena    =                  i_frm_stb & f_frm_enaX1 & f_frm_enaX2 & f_addr_ena;
wire        f_frm_reco   =                  i_frm_stb &!f_frm_enaX1 & f_frm_enaX2 & f_addr_ena;
//=============================================================================================                  
// stage 0
//=============================================================================================  
always@(posedge clk or posedge rst)
if(rst)                        
 begin                                                                                              
   s0_sof                      <=                                                          'b0;   
   s0_reco                     <=                                                          'b0;
   s0_ena                      <=                                                          'b0;
   s0_hdr_ena                  <=                                                          'b0;
   s0_ctrl.valid               <=                                                          'b0;       
   s0_bus.header.frm_used      <=                                                          'd0;
   s0_bus.header.frm_owned     <=                                                          'd0;
   s0_bus.header.frm_priority  <=                                                          'd0;
   s0_bus.header.frm_len       <=                                                          'd0;    
 end 
else  
 begin                                                                                                  
   s0_sof                      <=                                                        i_sof;   
   s0_ctrl.valid               <=                                                 i_ctrl.valid;
   s0_bus.header.frm_used      <=                                        i_bus.header.frm_used;
   s0_bus.header.frm_owned     <=                                       i_bus.header.frm_owned;
   s0_bus.header.frm_priority  <=                                    i_bus.header.frm_priority;
   s0_bus.header.frm_len       <=                                         i_bus.header.frm_len;    
   
   s0_reco                     <= (i_sof) ?                             f_frm_reco :      1'd0;   
   s0_ena                      <= (i_sof) ?                              f_frm_ena :    s0_ena;   
   s0_hdr_ena                  <= (i_sof) ?                              f_frm_ena :      1'b0;    
 end 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)
  begin
   s0_bus.header.net_addr      <=                                       i_bus.header.net_addr;
   s0_bus.header.frm_sid       <=                                       i_bus.header.frm_sid ;
   s0_bus.header.frm_rid       <=                                       i_bus.header.frm_rid ;
    
   s0_bus.header.mem_addr      <=                                       i_bus.header.mem_addr;      
   s0_bus.header.mem_space     <=                                      i_bus.header.mem_space;                    
   s0_bus.header.mem_op        <=                                         i_bus.header.mem_op;

   s0_ctrl.len                 <=                                                  i_ctrl.len; 
   s0_ctrl.pp                  <=                                                  i_ctrl.pp ; 
   s0_ctrl.did                 <=                                                  i_ctrl.did; 
   s0_ctrl.rid                 <=                                                  i_ctrl.rid; 
  end
//=============================================================================================
// TX fifos
//=============================================================================================
assign  frm_o_stb              =                                                        s0_ena;
assign  frm_o_sof              =                                                        s0_sof;
assign  frm_o_bus              =                                                        s0_bus;    
//=============================================================================================
// stage 1
//=============================================================================================
always@(posedge clk or posedge rst)
 if(rst)                        
  begin                                                                                   
   s1_sof                      <=                                                          'b0;      
   s1_ctrl                     <=                                                          'b0;       
   s1_bus.header.frm_used      <=                                                          'd0;
   s1_bus.header.frm_owned     <=                                                          'd0;
   s1_bus.header.frm_priority  <=                                                          'd0;
   s1_bus.header.frm_len       <=                                                          'd0;    
  end 
 else  
  begin                                                                                                
   s1_sof                      <=                                                       s0_sof;  
   s1_ctrl.valid               <= (s0_hdr_ena)?                           'd0 :  s0_ctrl.valid;
   
   s1_bus.header.frm_used      <= (s0_ena    )?       1'b0 :            s0_bus.header.frm_used;
   s1_bus.header.frm_owned     <= (s0_ena    )?       1'b0 : s0_reco | s0_bus.header.frm_owned;
   s1_bus.header.frm_priority  <=                                   s0_bus.header.frm_priority;
   s1_bus.header.frm_len       <=                                        s0_bus.header.frm_len;    
  end   
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)
  begin
   s1_bus.header.net_addr      <=                                       s0_bus.header.net_addr;
   s1_bus.header.frm_sid       <=                                       s0_bus.header.frm_sid ;
   s1_bus.header.frm_rid       <=                                       s0_bus.header.frm_rid ;
    
   s1_bus.header.mem_addr      <=                                       s0_bus.header.mem_addr;
   s1_bus.header.mem_space     <=                                      s0_bus.header.mem_space;
   s1_bus.header.mem_op        <=                                         s0_bus.header.mem_op;

   s1_ctrl.len                 <= (s0_hdr_ena)?                              'd0 : s0_ctrl.len; 
   s1_ctrl.pp                  <= (s0_hdr_ena)?                              'd0 : s0_ctrl.pp ; 
   s1_ctrl.did                 <= (s0_hdr_ena)?                              'd0 : s0_ctrl.did; 
   s1_ctrl.rid                 <= (s0_hdr_ena)?                              'd0 : s0_ctrl.rid; 
  end
//=============================================================================================
// output
//=============================================================================================   
assign  o_sof           =                                                               s1_sof;
assign  o_ctrl          =                                                              s1_ctrl;
assign  o_bus           =                                                               s1_bus;
//=============================================================================================
endmodule
