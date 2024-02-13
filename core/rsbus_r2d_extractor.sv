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
parameter      [3:0]  BASE_ID     =                  4'd0, // 
parameter      [3:0]  LAST_ID     =                  4'd0, //           
parameter             PASS_WR_ACK =                "TRUE"  // "TRUE", "FALSE"  
)
(                                                                                                                               
input  wire           clk,
input  wire           rst,   
                                                       
input  wire           i_sof,
input  wire [71:0]    i_bus,
                                                          
output wire           o_sof,
output wire [71:0]    o_bus,

output wire           frm_o_stb,  
output wire           frm_o_sof,  
output wire    [3:0]  frm_o_iid,
output wire [71:0]    frm_o_bus,
input  wire    [1:0]  frm_o_rdy
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
        if((PASS_WR_ACK != "TRUE") && (PASS_WR_ACK != "FALSE"))        
            begin
            $display( "%m !!!ERROR!!! PASS_WR_ACK = %s, is out of range (\"TRUE\" \"FALSE\")", PASS_WR_ACK );
            $finish;
            end 
    end
// pragma translate_on
//=============================================================================================
// variables
//=============================================================================================  
reg             s0_sof;             
reg     [71:0]  s0_bus; 
wire    [ 3:0]  s0_iidn;
reg             s0_extract_ena;
reg             s0_bypass_ena;
reg             s0_bypass_own; 
reg             s0_delete_ena;
//---------------------------------------------------------------------------------------------       
reg             s1_sof; 
reg     [71:0]  s1_bus;
//---------------------------------------------------------------------------------------------       
reg             s1_ext_stb; 
reg             s1_ext_sof; 
reg     [71:0]  s1_ext_bus;      
reg     [ 3:0]  s1_ext_iid;
//=============================================================================================
// in/out for inst/data cache
//=============================================================================================
wire            i_frm_stb     =                                                      i_bus[71];
wire            i_frm_len     =                                                      i_bus[39];
wire     [3:0]  i_frm_lid_0   =                                                   i_bus[51:48];
wire            i_frm_wr_ack  =                                            i_bus[1:0] == 2'b10; 
//---------------------------------------------------------------------------------------------        
wire            f_frm_enaAD_B =                                (~i_frm_lid_0[ 3:0] >= BASE_ID);
wire            f_frm_enaAD_L =                                (~i_frm_lid_0[ 3:0] <= LAST_ID);   
wire            f_frm_enaADDR =                                 f_frm_enaAD_B && f_frm_enaAD_L; 
//---------------------------------------------------------------------------------------------        
wire            f_frm_enaSrdy =                            (i_frm_len == 1'b0) && frm_o_rdy[0];
wire            f_frm_enaLrdy =                            (i_frm_len == 1'b1) && frm_o_rdy[1];
wire            f_frm_enaRDY  =                                 f_frm_enaSrdy || f_frm_enaLrdy;
//---------------------------------------------------------------------------------------------        
wire            f_frm_own     =                    i_frm_stb && f_frm_enaADDR && !f_frm_enaRDY; 
wire            f_frm_ena     =                    i_frm_stb && f_frm_enaADDR &&  f_frm_enaRDY;
wire            f_frm_wr_f    =    i_frm_wr_ack && i_frm_stb && f_frm_enaADDR &&  f_frm_enaRDY;
//---------------------------------------------------------------------------------------------        
wire            f_frm_bypass  =                                                     !f_frm_ena;
//=============================================================================================
// input stage (0)
//=============================================================================================
always@(posedge clk or posedge rst)
if(rst)                        
 begin                                                                                   
   s0_sof                      <=                                                          'b0;
  
   s0_bus[71:68]               <=                                                          'd0;    
  
   s0_extract_ena              <=                                                          'b0;
   s0_bypass_own               <=                                                          'b0;
   s0_delete_ena               <=                                                          'b0; 
 end 
else  
 begin                                                                                      
   s0_sof                      <=                                                        i_sof;
  
   s0_bus[71:68]               <=                                                 i_bus[71:68];    
  
   s0_extract_ena              <= (i_sof)?                          f_frm_ena : s0_extract_ena;  
   s0_bypass_ena               <= (i_sof)?                         !f_frm_ena :  s0_bypass_ena;
   s0_bypass_own               <= (i_sof)?                          f_frm_own :  s0_bypass_own; 
   s0_delete_ena               <= (i_sof)?f_frm_wr_f &(PASS_WR_ACK == "FALSE") : s0_delete_ena; 
 end     
//---------------------------------------------------------------------------------------------
always@(posedge clk)
  begin
   s0_bus[67:0]                <=                                                  i_bus[67:0];
  end                                                                                        
//---------------------------------------------------------------------------------------------
assign s0_iidn =                                                                 s0_bus[51:48];
//=============================================================================================
// 
//=============================================================================================
always@(posedge clk or posedge rst)
 if(rst)                        
  begin                             
   s1_sof                      <=                                                         1'b0; 
   
   s1_bus[71:68]               <=                                                          'd0;    
   
   s1_ext_stb                  <=                                                         1'b0;
  end 
 else  
  begin                                                                                      
   s1_sof                      <=                                                       s0_sof;    
   
   if(s0_sof & s0_extract_ena)
	 begin
       s1_bus[71]              <=                                                         1'b0;
       s1_bus[70]              <=                                                         1'b0;
   	 end
   else if(s0_sof & s0_bypass_own)
	 begin
       s1_bus[71]              <=                                                   s0_bus[71];
       s1_bus[70]              <=                                                         1'b1;
   	 end                                        
   else                                         
	 begin                                        
       s1_bus[71]              <=                                                   s0_bus[71];
       s1_bus[70]              <=                                                   s0_bus[70];
   	 end

   s1_bus[69:68]               <=                                                s0_bus[69:68];    
   
   s1_ext_stb                  <=                              s0_extract_ena & !s0_delete_ena; 
  end                                                         
//---------------------------------------------------------------------------------------------
wire  [3:0] s0_iid    =                                          ((~s0_iidn[ 3: 0]) - BASE_ID);  
//---------------------------------------------------------------------------------------------
always@(posedge clk)
  begin                                                                                        	   
   s1_bus[67:0]                <=                                                 s0_bus[67:0];
   
   s1_ext_sof                  <=                                                       s0_sof; 
   
   if(s0_sof)
	 begin  														 
       s1_ext_bus[71:68]       <=                                                s0_bus[71:68];
                                                                                
       s1_ext_bus[67:64]       <=                                                         4'd0;
       s1_ext_bus[63:60]       <=                                                s0_bus[67:64];
       s1_ext_bus[59:56]       <=                                                s0_bus[63:60];
       s1_ext_bus[55:52]       <=                                                s0_bus[59:56];
       s1_ext_bus[51:48]       <=                                                s0_bus[55:52];
       s1_ext_bus[47:0]        <=                                                 s0_bus[47:0];
     end															 
   else	 															 
	 begin  
`ifdef WORK_AROUND_XILINX_UNIONS														 
	   s1_ext_bus[71:0]          <=       	                                        s0_bus[71:0];
`else								                                                         
	   s1_ext_bus[71:0]          <=       	                                        s0_bus[71:0];
`endif
     end															 
	 
   s1_ext_iid                  <= (s0_sof)?                            s0_iid :     s1_ext_iid;
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