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

module rsbus_r2d_extractor
#(                                  
parameter      [3:0]  BASE_ID  =                  4'd0, // 
parameter      [3:0]  LAST_ID  =                  4'd0  //
)
(                                                                                                                               
input  wire           clk,
input  wire           rst,   
                                                       
input  wire           i_sof,
input  rbus_word_t    i_bus,
                                                          
output wire           o_sof,
output rbus_word_t    o_bus,

output wire           frm_o_stb,  
output wire           frm_o_sof,  
output wire    [3:0]  frm_o_iid,
output rbus_word_t    frm_o_bus,
input  wire    [1:0]  frm_o_af
);      
//=============================================================================================
// parameters
//=============================================================================================   
// pragma translate_off
initial
    begin
        if({1'b0, BASE_ID} > {1'b0, LAST_ID}) 
            begin
              $display( "!!!ERROR!!! rbus_d2r_injector. BASE_ID (%d) lower than LAST_ID (%d)", BASE_ID, LAST_ID ); 
              $finish;
            end
    end
// pragma translate_on
//=============================================================================================
// variables
//=============================================================================================  
reg             s0_sof;             
rbus_word_t     s0_bus; 
wire    [ 3:0]  s0_iidn;
reg             s0_extract_ena;
reg             s0_bypass_ena;
reg             s0_bypass_own;
//---------------------------------------------------------------------------------------------       
reg             s1_sof; 
rbus_word_t     s1_bus;
//---------------------------------------------------------------------------------------------       
reg             s1_ext_stb; 
reg             s1_ext_sof; 
rbus_word_t     s1_ext_bus;      
reg     [ 3:0]  s1_ext_iid;
//=============================================================================================
// in/out for inst/data cache
//=============================================================================================
wire            i_frm_stb     =                                         i_bus.header.frm_used ;
wire            i_frm_len     =                                         i_bus.header.frm_len  ;
wire     [3:0]  i_frm_lid_0   =                                     i_bus.header.net_addr.lid0; 
//---------------------------------------------------------------------------------------------        
wire            f_frm_enaAD_B =                                (~i_frm_lid_0[ 3:0] >= BASE_ID);
wire            f_frm_enaAD_L =                                (~i_frm_lid_0[ 3:0] <= LAST_ID);   
wire            f_frm_enaADDR =                                 f_frm_enaAD_B && f_frm_enaAD_L; 
//---------------------------------------------------------------------------------------------        
wire            f_frm_enaSAF  =                            (i_frm_len == 1'b0) && !frm_o_af[0];
wire            f_frm_enaLAF  =                            (i_frm_len == 1'b1) && !frm_o_af[1];
wire            f_frm_enaAF   =                                   f_frm_enaSAF || f_frm_enaLAF;
//---------------------------------------------------------------------------------------------        
wire            f_frm_own     =                     i_frm_stb && f_frm_enaADDR && !f_frm_enaAF;
wire            f_frm_ena     =                     i_frm_stb && f_frm_enaADDR &&  f_frm_enaAF;
//---------------------------------------------------------------------------------------------        
wire            f_frm_bypass  =                                                     !f_frm_ena;
//=============================================================================================
// input stage (0)
//=============================================================================================
always@(posedge clk or posedge rst)
if(rst)                        
 begin                                                                                   
   s0_sof                      <=                                                          'b0;
  
   s0_bus.header.frm_used      <=                                                          'd0;
   s0_bus.header.frm_owned     <=                                                          'd0;
   s0_bus.header.frm_priority  <=                                                          'd0;
   s0_bus.header.frm_len       <=                                                          'd0;    
  
   s0_extract_ena              <=                                                          'b0;
 end 
else  
 begin                                                                                      
   s0_sof            <=                                                                  i_sof;
  
   s0_bus.header.frm_used      <=                                        i_bus.header.frm_used;
   s0_bus.header.frm_owned     <=                                       i_bus.header.frm_owned;
   s0_bus.header.frm_priority  <=                                    i_bus.header.frm_priority;
   s0_bus.header.frm_len       <=                                         i_bus.header.frm_len;    
  
   s0_extract_ena              <= (i_sof)?                          f_frm_ena : s0_extract_ena;  
   s0_bypass_ena               <= (i_sof)?                         !f_frm_ena :  s0_bypass_ena;
   s0_bypass_own               <= (i_sof)?                          f_frm_own :  s0_bypass_own;
 end     
//---------------------------------------------------------------------------------------------
always@(posedge clk)
  begin
   s0_bus.header.net_addr      <=                                        i_bus.header.net_addr;
   s0_bus.header.frm_sid       <=                                        i_bus.header.frm_sid ;
   s0_bus.header.frm_rid       <=                                        i_bus.header.frm_rid ;
      
   s0_bus.header.mem_addr      <=                                        i_bus.header.mem_addr;      
   s0_bus.header.mem_space     <=                                       i_bus.header.mem_space;                    
   s0_bus.header.mem_op        <=                                          i_bus.header.mem_op;
  end                                                                                        
//---------------------------------------------------------------------------------------------
assign s0_iidn =                                                   s0_bus.header.net_addr.lid0;
//=============================================================================================
// 
//=============================================================================================
always@(posedge clk or posedge rst)
 if(rst)                        
  begin                             
   s1_sof           <=                                                                    1'b0; 
   
   s1_bus.header.frm_used      <=                                                          'd0;
   s1_bus.header.frm_owned     <=                                                          'd0;
   s1_bus.header.frm_priority  <=                                                          'd0;
   s1_bus.header.frm_len       <=                                                          'd0;    
   
   s1_ext_stb       <=                                                                    1'b0;
  end 
 else  
  begin                                                                                      
   s1_sof           <=                                                                  s0_sof;    
   
   if(s0_sof & s0_extract_ena)
	 begin
       s1_bus.header.frm_used      <=                                                     1'b0;
       s1_bus.header.frm_owned     <=                                                     1'b0;
   	 end
   else if(s0_sof & s0_bypass_own)
	 begin
       s1_bus.header.frm_used      <=                                   s0_bus.header.frm_used;
       s1_bus.header.frm_owned     <=                                                     1'b1;
   	 end
   else
	 begin  
       s1_bus.header.frm_used      <=                                   s0_bus.header.frm_used;
       s1_bus.header.frm_owned     <=                                  s0_bus.header.frm_owned;
   	 end

   s1_bus.header.frm_priority      <=                               s0_bus.header.frm_priority;
   s1_bus.header.frm_len           <=                                    s0_bus.header.frm_len;    
   
   s1_ext_stb       <=                                                          s0_extract_ena; 
  end                                                         
//---------------------------------------------------------------------------------------------
wire  [3:0] s0_iid    =                                          ((~s0_iidn[ 3: 0]) - BASE_ID);  
//---------------------------------------------------------------------------------------------
always@(posedge clk)
  begin                                                                                        	   
   s1_bus.header.net_addr      <=                                       s0_bus.header.net_addr;
   s1_bus.header.frm_sid       <=                                       s0_bus.header.frm_sid ;
   s1_bus.header.frm_rid       <=                                       s0_bus.header.frm_rid ;
    
   s1_bus.header.mem_addr      <=                                       s0_bus.header.mem_addr;
   s1_bus.header.mem_space     <=                                      s0_bus.header.mem_space;
   s1_bus.header.mem_op        <=                                         s0_bus.header.mem_op;
   
   s1_ext_sof        <=                                                                 s0_sof; 
   
   if(s0_sof)
	 begin  														 
       s1_ext_bus.header.frm_used      <=                               s0_bus.header.frm_used;
       s1_ext_bus.header.frm_owned     <=                              s0_bus.header.frm_owned;
       s1_ext_bus.header.frm_priority  <=                           s0_bus.header.frm_priority;
       s1_ext_bus.header.frm_len       <=                                s0_bus.header.frm_len;    

       s1_ext_bus.header.net_addr.lid4 <=                                                 4'd0;
       s1_ext_bus.header.net_addr.lid3 <=                          s0_bus.header.net_addr.lid4;
       s1_ext_bus.header.net_addr.lid2 <=                          s0_bus.header.net_addr.lid3;
       s1_ext_bus.header.net_addr.lid1 <=                          s0_bus.header.net_addr.lid2;
       s1_ext_bus.header.net_addr.lid0 <=                          s0_bus.header.net_addr.lid1;
       s1_ext_bus.header.frm_sid       <=                                s0_bus.header.frm_sid;
       s1_ext_bus.header.frm_rid       <=                                s0_bus.header.frm_rid;
	   
       s1_ext_bus.header.mem_addr      <=                               s0_bus.header.mem_addr;
       s1_ext_bus.header.mem_space     <=                              s0_bus.header.mem_space;
       s1_ext_bus.header.mem_op        <=                                 s0_bus.header.mem_op;
     end															 
   else	 															 
	 begin  
`ifdef WORK_AROUND_XILINX_UNIONS														 
	   s1_ext_bus/*.payload*/          <=       	                        s0_bus/*.payload*/;
`else
       s1_ext_bus.payload              <=                                       s0_bus.payload;
`endif
     end															 
	 
   s1_ext_iid                          <= (s0_sof)?                    s0_iid :     s1_ext_iid;
  end 
//=============================================================================================			  
// output																								  
//=============================================================================================
assign  frm_o_stb         =                                                         s1_ext_stb;
assign  frm_o_sof         =                                                         s1_ext_sof;
assign  frm_o_bus         =                                                         s1_ext_bus;
assign  frm_o_iid         =                                                         s1_ext_iid;
//=============================================================================================      
assign  o_sof             =                                                             s1_sof;      
assign  o_bus             =                                                             s1_bus;      
//=============================================================================================
endmodule