//=============================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns 
//=============================================================================================
`include "rbus_defs.sv"
import rbus_pkg::*;
`include "mem_spaces.vh"
//=============================================================================================
module shell_mem_map 
#(                                                                    
parameter           DIRECTION  =                  "PHY2LOG"  // "PHY2LOG", "LOG2PHY"         /*synthesis syn_keep=1*/   
)
(
input  wire         clk          /*synthesis syn_keep=1*/,
input  wire         rst          /*synthesis syn_keep=1*/,
                           
input  wire         i_sof        /*synthesis syn_keep=1*/,
input  wire [11:0]  i_ctrl       /*synthesis syn_keep=1*/,
input  wire [71:0]  i_data       /*synthesis syn_keep=1*/,

output wire         o_sof        /*synthesis syn_keep=1*/,
output wire [11:0]  o_ctrl       /*synthesis syn_keep=1*/,
output wire [71:0]  o_data       /*synthesis syn_keep=1*/

);  
//=============================================================================================
// parameters check
//=============================================================================================   
// pragma translate_off
initial
    begin
        if((DIRECTION != "PHY2LOG") && (DIRECTION != "LOG2PHY"))    
            begin
            $display( "!!!ERROR!!! DIRECTION = %s, is out of range (\"PHY2LOG\" \"LOG2PHY\")", DIRECTION );
            $finish;
            end
    end
// pragma translate_on                                                                          
//=============================================================================================
// translation parameters
//============================================================================================= 
wire [38:0]    START_0_PHY =                  `MEM_SP_BOOTROM_START_PHY;    
wire [38:0]    START_0_LOG =                  `MEM_SP_BOOTROM_START_LOG;    
wire [38:0]    LEN_0       =                  `MEM_SP_BOOTROM_LEN;          
wire [38:0]    START_1_PHY =                  `MEM_SP_REFLECTOR_START_PHY; 
wire [38:0]    START_1_LOG =                  `MEM_SP_REFLECTOR_START_LOG; 
wire [38:0]    LEN_1       =                  `MEM_SP_REFLECTOR_LEN;       
wire [38:0]    START_2_PHY =                  `MEM_SP_MUTEX_START_PHY;      
wire [38:0]    START_2_LOG =                  `MEM_SP_MUTEX_START_LOG;  
wire [38:0]    LEN_2       =                  `MEM_SP_MUTEX_LEN;        
wire [38:0]    START_3_PHY =                  `MEM_SP_KERNEL_START_PHY; 
wire [38:0]    START_3_LOG =                  `MEM_SP_KERNEL_START_LOG; 
wire [38:0]    LEN_3       =                  `MEM_SP_KERNEL_LEN;       
wire [38:0]    START_4_PHY =                  `MEM_SP_DEVICES_START_PHY;  
wire [38:0]    START_4_LOG =                  `MEM_SP_DEVICES_START_LOG;  
wire [38:0]    LEN_4       =                  `MEM_SP_DEVICES_LEN;        
wire [38:0]    START_5_PHY =                  `MEM_SP_GLOBAL_START_PHY; 
wire [38:0]    START_5_LOG =                  `MEM_SP_GLOBAL_START_LOG; 
wire [38:0]    LEN_5       =                  `MEM_SP_GLOBAL_LEN;       
wire [38:0]    START_6_PHY =                  `MEM_SP_USER_START_PHY;  
wire [38:0]    START_6_LOG =                  `MEM_SP_USER_START_LOG;  
wire [38:0]    LEN_6       =                  `MEM_SP_USER_LEN;      
wire [38:0]    START_7_PHY =                  `MEM_SP_DEBUG_START_PHY;  
wire [38:0]    START_7_LOG =                  `MEM_SP_DEBUG_START_LOG;  
wire [38:0]    LEN_7       =                  `MEM_SP_DEBUG_LEN;      
wire [38:0]    START_8_PHY =                  `MEM_SP_DEVNULL_START_PHY;  
wire [38:0]    START_8_LOG =                  `MEM_SP_DEVNULL_START_LOG;  
wire [38:0]    LEN_8       =                  `MEM_SP_DEVNULL_LEN;  
wire [38:0]    DEVNULL_PHY =                  `MEM_SP_DEVNULL_START_PHY;  

wire [38:0]   END_0_PHY   =                  START_0_PHY + LEN_0;
wire [38:0]   END_0_LOG   =                  START_0_LOG + LEN_0; 
wire [38:0]   END_1_PHY   =                  START_1_PHY + LEN_1;
wire [38:0]   END_1_LOG   =                  START_1_LOG + LEN_1; 
wire [38:0]   END_2_PHY   =                  START_2_PHY + LEN_2;
wire [38:0]   END_2_LOG   =                  START_2_LOG + LEN_2; 
wire [38:0]   END_3_PHY   =                  START_3_PHY + LEN_3;
wire [38:0]   END_3_LOG   =                  START_3_LOG + LEN_3; 
wire [38:0]   END_4_PHY   =                  START_4_PHY + LEN_4;
wire [38:0]   END_4_LOG   =                  START_4_LOG + LEN_4; 
wire [38:0]   END_5_PHY   =                  START_5_PHY + LEN_5;
wire [38:0]   END_5_LOG   =                  START_5_LOG + LEN_5; 
wire [38:0]   END_6_PHY   =                  START_6_PHY + LEN_6;
wire [38:0]   END_6_LOG   =                  START_6_LOG + LEN_6;
wire [38:0]   END_7_PHY   =                  START_7_PHY + LEN_7;
wire [38:0]   END_7_LOG   =                  START_7_LOG + LEN_7;
wire [38:0]   END_8_PHY   =                  START_8_PHY + LEN_8;
wire [38:0]   END_8_LOG   =                  START_8_LOG + LEN_8;                                                                                                                                
//=============================================================================================
// variables
//=============================================================================================  
wire            i_hdr; 
wire            i_stb;
wire            i_owned;
wire            i_len; 
wire     [38:0] i_mem_addr;
wire     [19:0] i_net_addr; 
wire     [ 3:0] i_sid;
wire     [ 3:0] i_rid;
//---------------------------------------------------------------------------------------------
wire            i_ena;
//--------------------------------------------------------------------------------------------- 
wire     [ 9:0] i_mem_p2l_space_det;
wire     [38:0] i_mem_p2l_offset;	
wire     [ 9:0] i_mem_l2p_space_det;
wire     [38:0] i_mem_l2p_offset;
wire     [38:0] i_mem_offset;
//---------------------------------------------------------------------------------------------   
reg             s0_sof;
reg             s0_mem_tr_en;
reg  [11:0]     s0_ctrl;
reg  [71:0]     s0_data;
reg      [38:0] s0_mem_off;

wire     [38:0] s0_mem_addr_org;
wire     [38:0] s0_mem_addr_tr;
//--------------------------------------------------------------------------------------------- 
reg             s1_sof;
reg  [11:0]     s1_ctrl;
reg  [71:0]     s1_data;
//--------------------------------------------------------------------------------------------- 
reg             s1_bp_c;
reg      [71:0] s1_bp_x;
//=============================================================================================
// address translation - computing offsets
//=============================================================================================  
assign          i_hdr       =                                                            i_sof; 
assign          i_stb       =                                                    i_data[   71];
assign          i_owned     =                                                    i_data[   70];
assign          i_len       =                                                    i_data[   39]; 
assign          i_mem_addr  =                                            {i_data[38: 3], 3'd0};
assign          i_net_addr  =                                                    i_data[67:48]; 
assign          i_sid       =                                                    i_data[47:44]; 
assign          i_rid       =                                                    i_data[43:40];                         
//---------------------------------------------------------------------------------------------
assign          i_ena       =                                       i_hdr && i_stb && !i_owned;	
//--------------------------------------------------------------------------------------------- 
// physical to logical offset
/* verilator lint_off UNSIGNED */ assign          i_mem_p2l_offset = 
(                                                                                 !i_ena)?                     39'd0: 
(({1'b0, i_mem_addr} >= {1'b0, START_0_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_0_PHY}))? START_0_LOG - START_0_PHY: 
(({1'b0, i_mem_addr} >= {1'b0, START_1_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_1_PHY}))? START_1_LOG - START_1_PHY:
(({1'b0, i_mem_addr} >= {1'b0, START_2_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_2_PHY}))? START_2_LOG - START_2_PHY:
(({1'b0, i_mem_addr} >= {1'b0, START_3_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_3_PHY}))? START_3_LOG - START_3_PHY:
(({1'b0, i_mem_addr} >= {1'b0, START_4_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_4_PHY}))? START_4_LOG - START_4_PHY:
(({1'b0, i_mem_addr} >= {1'b0, START_5_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_5_PHY}))? START_5_LOG - START_5_PHY: 
(({1'b0, i_mem_addr} >= {1'b0, START_6_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_6_PHY}))? START_6_LOG - START_6_PHY: 
(({1'b0, i_mem_addr} >= {1'b0, START_7_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_7_PHY}))? START_7_LOG - START_7_PHY: 
(({1'b0, i_mem_addr} >= {1'b0, START_8_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_8_PHY}))? START_8_LOG - START_8_PHY: 
                                                                   40'd0 - {1'b0, DEVNULL_PHY};  
//--------------------------------------------------------------------------------------------- 
// physical to logical offset
/* verilator lint_off UNSIGNED */ assign i_mem_p2l_space_det = 
(                                                           !i_ena)?                    -'d1: 
(({1'b0, i_mem_addr} >= {1'b0, START_0_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_0_PHY}))? 'h000:
(({1'b0, i_mem_addr} >= {1'b0, START_1_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_1_PHY}))? 'h001:
(({1'b0, i_mem_addr} >= {1'b0, START_2_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_2_PHY}))? 'h002:
(({1'b0, i_mem_addr} >= {1'b0, START_3_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_3_PHY}))? 'h004:
(({1'b0, i_mem_addr} >= {1'b0, START_4_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_4_PHY}))? 'h008:
(({1'b0, i_mem_addr} >= {1'b0, START_5_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_5_PHY}))? 'h010:
(({1'b0, i_mem_addr} >= {1'b0, START_6_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_6_PHY}))? 'h020:
(({1'b0, i_mem_addr} >= {1'b0, START_7_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_7_PHY}))? 'h040:
(({1'b0, i_mem_addr} >= {1'b0, START_8_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_8_PHY}))? 'h080:
                                                                                           'h100;                       
//--------------------------------------------------------------------------------------------- 
// logical to physical offset                                        
assign          i_mem_l2p_offset =  
(                                                           !i_ena)?                     39'd0: 
(({1'b0, i_mem_addr} >= {1'b0, START_0_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_0_LOG}))? START_0_PHY - START_0_LOG:
(({1'b0, i_mem_addr} >= {1'b0, START_1_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_1_LOG}))? START_1_PHY - START_1_LOG:
(({1'b0, i_mem_addr} >= {1'b0, START_2_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_2_LOG}))? START_2_PHY - START_2_LOG:
(({1'b0, i_mem_addr} >= {1'b0, START_3_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_3_LOG}))? START_3_PHY - START_3_LOG:
(({1'b0, i_mem_addr} >= {1'b0, START_4_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_4_LOG}))? START_4_PHY - START_4_LOG:
(({1'b0, i_mem_addr} >= {1'b0, START_5_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_5_LOG}))? START_5_PHY - START_5_LOG:
(({1'b0, i_mem_addr} >= {1'b0, START_6_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_6_LOG}))? START_6_PHY - START_6_LOG: 
(({1'b0, i_mem_addr} >= {1'b0, START_7_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_7_LOG}))? START_7_PHY - START_7_LOG: 
(({1'b0, i_mem_addr} >= {1'b0, START_8_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_8_LOG}))? START_8_PHY - START_8_LOG:  
                                                                                   DEVNULL_PHY; 
//--------------------------------------------------------------------------------------------- 
// physical to logical offset
assign i_mem_l2p_space_det = 
(                                                           !i_ena)?                    -'d1: 
(({1'b0, i_mem_addr} >= {1'b0, START_0_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_0_LOG}))? 'h000:
(({1'b0, i_mem_addr} >= {1'b0, START_1_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_1_LOG}))? 'h001:
(({1'b0, i_mem_addr} >= {1'b0, START_2_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_2_LOG}))? 'h002:
(({1'b0, i_mem_addr} >= {1'b0, START_3_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_3_LOG}))? 'h004:
(({1'b0, i_mem_addr} >= {1'b0, START_4_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_4_LOG}))? 'h008:
(({1'b0, i_mem_addr} >= {1'b0, START_5_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_5_LOG}))? 'h010:
(({1'b0, i_mem_addr} >= {1'b0, START_6_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_6_LOG}))? 'h020:
(({1'b0, i_mem_addr} >= {1'b0, START_7_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_7_LOG}))? 'h040:
(({1'b0, i_mem_addr} >= {1'b0, START_8_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_8_LOG}))? 'h080:
                                                                                           'h100;                       
//--------------------------------------------------------------------------------------------- 
// offset choose
assign          i_mem_offset = (DIRECTION == "LOG2PHY")?   i_mem_l2p_offset : i_mem_p2l_offset;  
//=============================================================================================
// stage 0
//=============================================================================================
always_ff@(posedge clk or posedge rst)
 if(rst)                        
  begin
   s0_sof        <=                                                                       1'b0;
   s0_data[71:70]<=                                                                       2'b0;
   s0_ctrl[11]   <=                                                                       1'd0;
  end 
 else 
  begin 
   s0_sof        <=                                                                      i_sof;
   s0_data[71:70]<=                                                              i_data[71:70];
   s0_ctrl[11]   <=                                                                 i_ctrl[11];
  end 
//--------------------------------------------------------------------------------------------- 
always_ff@(posedge clk)
  begin                                                                                        
   s0_mem_tr_en <=                                                                       i_ena;
   s0_mem_off   <=                                                                i_mem_offset;
   s0_data[69:0]<=                                                                i_data[69:0];
   s0_ctrl[10:0]<=                                                                i_ctrl[10:0];
  end 
//=============================================================================================
// stage 1
//============================================================================================= 
assign          s0_mem_addr_org =                                       {s0_data[38: 3], 3'd0}; 
assign          s0_mem_addr_tr  =                                 s0_mem_addr_org + s0_mem_off; 
//--------------------------------------------------------------------------------------------- 
always_ff@(posedge clk or posedge rst)
 if(rst)                        
  begin
   s1_sof        <=                                                                       1'b0;
   s1_data[71:70]<=                                                                       2'b0;
   s1_ctrl[11]   <=                                                                       1'd0;
  end            
 else            
  begin                                                                                             
   s1_sof        <=                                                                     s0_sof;    
   s1_data[71:70]<=                                                             s0_data[71:70]; 
   s1_ctrl[11]   <=                                                                s0_ctrl[11];
  end
//--------------------------------------------------------------------------------------------- 
always_ff@(posedge clk)
  begin                                                                                         
   s1_data[69:39]<=                                                             s0_data[69:39];
   // address bits changed, but just for header word. For data words memory offset is set to 
   //  zero so data words are unchanged. This way no multiplexer is needed here   
   s1_data[38: 3]<=                                                      s0_mem_addr_tr[38: 3];
   s1_data[ 2: 0]<=                                                             s0_data[ 2: 0];
   s1_ctrl[10: 0]<=                                                              s0_ctrl[10:0];
  end 
//=============================================================================================
// output
//=============================================================================================
assign          o_sof          =                                                        s1_sof;
assign          o_ctrl         =                                                       s1_ctrl;
assign          o_data         =                                                       s1_data;
//=============================================================================================
endmodule  

////=============================================================================================
////    Main contributors
////      - Jakub Siast         <mailto:jakubsiast@gmail.com>
////=============================================================================================
//`default_nettype none
////---------------------------------------------------------------------------------------------
//`timescale 1ns / 1ns 
////=============================================================================================
//`include "rbus_defs.sv"
//import rbus_pkg::*;
//`include "mem_spaces.vh"
////=============================================================================================
//module shell_mem_map 
//#(                                                                    
//parameter           DIRECTION  =                  "PHY2LOG"  // "PHY2LOG", "LOG2PHY"         /*synthesis syn_keep=1*/   
//)
//(
//input  wire         clk,         /*synthesis syn_keep=1*/
//input  wire         rst,         /*synthesis syn_keep=1*/
//                           
//input  wire         i_sof,       /*synthesis syn_keep=1*/
//input  rbus_ctrl_t  i_ctrl,      /*synthesis syn_keep=1*/
//input  rbus_word_t  i_data,      /*synthesis syn_keep=1*/
//
//output wire         o_sof,       /*synthesis syn_keep=1*/
//output rbus_ctrl_t  o_ctrl,      /*synthesis syn_keep=1*/
//output wire [71:0]  o_data       /*synthesis syn_keep=1*/
//
//);  
////=============================================================================================
//// parameters check
////=============================================================================================   
//// pragma translate_off
//initial
//    begin
//        if((DIRECTION != "PHY2LOG") && (DIRECTION != "LOG2PHY"))    
//            begin
//            $display( "!!!ERROR!!! DIRECTION = %s, is out of range (\"PHY2LOG\" \"LOG2PHY\")", DIRECTION );
//            $finish;
//            end
//    end
//// pragma translate_on                                                                          
////=============================================================================================
//// translation parameters
////============================================================================================= 
//wire [38:0]    START_0_PHY =                  `MEM_SP_BOOTROM_START_PHY;    
//wire [38:0]    START_0_LOG =                  `MEM_SP_BOOTROM_START_LOG;    
//wire [38:0]    LEN_0       =                  `MEM_SP_BOOTROM_LEN;          
//wire [38:0]    START_1_PHY =                  `MEM_SP_REFLECTOR_START_PHY; 
//wire [38:0]    START_1_LOG =                  `MEM_SP_REFLECTOR_START_LOG; 
//wire [38:0]    LEN_1       =                  `MEM_SP_REFLECTOR_LEN;       
//wire [38:0]    START_2_PHY =                  `MEM_SP_MUTEX_START_PHY;      
//wire [38:0]    START_2_LOG =                  `MEM_SP_MUTEX_START_LOG;  
//wire [38:0]    LEN_2       =                  `MEM_SP_MUTEX_LEN;        
//wire [38:0]    START_3_PHY =                  `MEM_SP_KERNEL_START_PHY; 
//wire [38:0]    START_3_LOG =                  `MEM_SP_KERNEL_START_LOG; 
//wire [38:0]    LEN_3       =                  `MEM_SP_KERNEL_LEN;       
//wire [38:0]    START_4_PHY =                  `MEM_SP_DEVICES_START_PHY;  
//wire [38:0]    START_4_LOG =                  `MEM_SP_DEVICES_START_LOG;  
//wire [38:0]    LEN_4       =                  `MEM_SP_DEVICES_LEN;        
//wire [38:0]    START_5_PHY =                  `MEM_SP_GLOBAL_START_PHY; 
//wire [38:0]    START_5_LOG =                  `MEM_SP_GLOBAL_START_LOG; 
//wire [38:0]    LEN_5       =                  `MEM_SP_GLOBAL_LEN;       
//wire [38:0]    START_6_PHY =                  `MEM_SP_USER_START_PHY;  
//wire [38:0]    START_6_LOG =                  `MEM_SP_USER_START_LOG;  
//wire [38:0]    LEN_6       =                  `MEM_SP_USER_LEN;      
//wire [38:0]    START_7_PHY =                  `MEM_SP_DEBUG_START_PHY;  
//wire [38:0]    START_7_LOG =                  `MEM_SP_DEBUG_START_LOG;  
//wire [38:0]    LEN_7       =                  `MEM_SP_DEBUG_LEN;      
//wire [38:0]    START_8_PHY =                  `MEM_SP_DEVNULL_START_PHY;  
//wire [38:0]    START_8_LOG =                  `MEM_SP_DEVNULL_START_LOG;  
//wire [38:0]    LEN_8       =                  `MEM_SP_DEVNULL_LEN;  
//wire [38:0]    DEVNULL_PHY =                  `MEM_SP_DEVNULL_START_PHY;  
//
//wire [38:0]   END_0_PHY   =                  START_0_PHY + LEN_0;
//wire [38:0]   END_0_LOG   =                  START_0_LOG + LEN_0; 
//wire [38:0]   END_1_PHY   =                  START_1_PHY + LEN_1;
//wire [38:0]   END_1_LOG   =                  START_1_LOG + LEN_1; 
//wire [38:0]   END_2_PHY   =                  START_2_PHY + LEN_2;
//wire [38:0]   END_2_LOG   =                  START_2_LOG + LEN_2; 
//wire [38:0]   END_3_PHY   =                  START_3_PHY + LEN_3;
//wire [38:0]   END_3_LOG   =                  START_3_LOG + LEN_3; 
//wire [38:0]   END_4_PHY   =                  START_4_PHY + LEN_4;
//wire [38:0]   END_4_LOG   =                  START_4_LOG + LEN_4; 
//wire [38:0]   END_5_PHY   =                  START_5_PHY + LEN_5;
//wire [38:0]   END_5_LOG   =                  START_5_LOG + LEN_5; 
//wire [38:0]   END_6_PHY   =                  START_6_PHY + LEN_6;
//wire [38:0]   END_6_LOG   =                  START_6_LOG + LEN_6;
//wire [38:0]   END_7_PHY   =                  START_7_PHY + LEN_7;
//wire [38:0]   END_7_LOG   =                  START_7_LOG + LEN_7;
//wire [38:0]   END_8_PHY   =                  START_8_PHY + LEN_8;
//wire [38:0]   END_8_LOG   =                  START_8_LOG + LEN_8;                                                                                                                                
////=============================================================================================
//// variables
////=============================================================================================  
//wire            i_hdr; 
//wire            i_stb;
//wire            i_owned;
//wire            i_len; 
//wire     [38:0] i_mem_addr;
//wire     [19:0] i_net_addr; 
//wire     [ 3:0] i_sid;
//wire     [ 3:0] i_rid;
////---------------------------------------------------------------------------------------------
//wire            i_ena;
////--------------------------------------------------------------------------------------------- 
//wire     [ 9:0] i_mem_p2l_space_det;
//wire     [38:0] i_mem_p2l_offset;	
//wire     [ 9:0] i_mem_l2p_space_det;
//wire     [38:0] i_mem_l2p_offset;
//wire     [38:0] i_mem_offset;
////---------------------------------------------------------------------------------------------   
//reg             s0_sof;
//reg             s0_mem_tr_en;
//rbus_ctrl_t     s0_ctrl;
//reg      [71:0] s0_data;
//reg      [38:0] s0_mem_off;
//
//wire     [38:0] s0_mem_addr_org;
//wire     [38:0] s0_mem_addr_tr;
////--------------------------------------------------------------------------------------------- 
//reg             s1_sof;
//rbus_ctrl_t     s1_ctrl;
//reg      [71:0] s1_data;
////--------------------------------------------------------------------------------------------- 
//reg             s1_bp_c;
//reg      [71:0] s1_bp_x;
////=============================================================================================
//// address translation - computing offsets
////=============================================================================================  
//assign          i_hdr       =                                                            i_sof; 
//assign          i_stb       =                                          i_data.header.frm_used ;
//assign          i_owned     =                                          i_data.header.frm_owned;
//assign          i_len       =                                          i_data.header.frm_len  ; 
//assign          i_mem_addr  =                                   {i_data.header.mem_addr, 3'd0};
//assign          i_net_addr  =                                          i_data.header.net_addr ; 
//assign          i_sid       =                                          i_data.header.frm_sid  ;
//assign          i_rid       =                                          i_data.header.frm_rid  ;                         
////---------------------------------------------------------------------------------------------
//assign          i_ena       =                                       i_hdr && i_stb && !i_owned;	
////--------------------------------------------------------------------------------------------- 
//// physical to logical offset
//assign          i_mem_p2l_offset = 
//(                                                           !i_ena)?                     39'd0: 
//(({1'b0, i_mem_addr} >= {1'b0, START_0_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_0_PHY}))? START_0_LOG - START_0_PHY:
//(({1'b0, i_mem_addr} >= {1'b0, START_1_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_1_PHY}))? START_1_LOG - START_1_PHY:
//(({1'b0, i_mem_addr} >= {1'b0, START_2_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_2_PHY}))? START_2_LOG - START_2_PHY:
//(({1'b0, i_mem_addr} >= {1'b0, START_3_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_3_PHY}))? START_3_LOG - START_3_PHY:
//(({1'b0, i_mem_addr} >= {1'b0, START_4_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_4_PHY}))? START_4_LOG - START_4_PHY:
//(({1'b0, i_mem_addr} >= {1'b0, START_5_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_5_PHY}))? START_5_LOG - START_5_PHY: 
//(({1'b0, i_mem_addr} >= {1'b0, START_6_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_6_PHY}))? START_6_LOG - START_6_PHY: 
//(({1'b0, i_mem_addr} >= {1'b0, START_7_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_7_PHY}))? START_7_LOG - START_7_PHY: 
//(({1'b0, i_mem_addr} >= {1'b0, START_8_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_8_PHY}))? START_8_LOG - START_8_PHY: 
//                                                                   40'd0 - {1'b0, DEVNULL_PHY};  
////--------------------------------------------------------------------------------------------- 
//// physical to logical offset
//assign i_mem_p2l_space_det = 
//(                                                           !i_ena)?                    -'d1: 
//(({1'b0, i_mem_addr} >= {1'b0, START_0_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_0_PHY}))? 'h000:
//(({1'b0, i_mem_addr} >= {1'b0, START_1_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_1_PHY}))? 'h001:
//(({1'b0, i_mem_addr} >= {1'b0, START_2_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_2_PHY}))? 'h002:
//(({1'b0, i_mem_addr} >= {1'b0, START_3_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_3_PHY}))? 'h004:
//(({1'b0, i_mem_addr} >= {1'b0, START_4_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_4_PHY}))? 'h008:
//(({1'b0, i_mem_addr} >= {1'b0, START_5_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_5_PHY}))? 'h010:
//(({1'b0, i_mem_addr} >= {1'b0, START_6_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_6_PHY}))? 'h020:
//(({1'b0, i_mem_addr} >= {1'b0, START_7_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_7_PHY}))? 'h040:
//(({1'b0, i_mem_addr} >= {1'b0, START_8_PHY}) && ({1'b0, i_mem_addr} < {1'b0, END_8_PHY}))? 'h080:
//                                                                                           'h100;                       
////--------------------------------------------------------------------------------------------- 
//// logical to physical offset                                        
//assign          i_mem_l2p_offset =  
//(                                                           !i_ena)?                     39'd0: 
//(({1'b0, i_mem_addr} >= {1'b0, START_0_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_0_LOG}))? START_0_PHY - START_0_LOG:
//(({1'b0, i_mem_addr} >= {1'b0, START_1_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_1_LOG}))? START_1_PHY - START_1_LOG:
//(({1'b0, i_mem_addr} >= {1'b0, START_2_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_2_LOG}))? START_2_PHY - START_2_LOG:
//(({1'b0, i_mem_addr} >= {1'b0, START_3_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_3_LOG}))? START_3_PHY - START_3_LOG:
//(({1'b0, i_mem_addr} >= {1'b0, START_4_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_4_LOG}))? START_4_PHY - START_4_LOG:
//(({1'b0, i_mem_addr} >= {1'b0, START_5_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_5_LOG}))? START_5_PHY - START_5_LOG:
//(({1'b0, i_mem_addr} >= {1'b0, START_6_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_6_LOG}))? START_6_PHY - START_6_LOG: 
//(({1'b0, i_mem_addr} >= {1'b0, START_7_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_7_LOG}))? START_7_PHY - START_7_LOG: 
//(({1'b0, i_mem_addr} >= {1'b0, START_8_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_8_LOG}))? START_8_PHY - START_8_LOG:  
//                                                                                   DEVNULL_PHY; 
////--------------------------------------------------------------------------------------------- 
//// physical to logical offset
//assign i_mem_l2p_space_det = 
//(                                                           !i_ena)?                    -'d1: 
//(({1'b0, i_mem_addr} >= {1'b0, START_0_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_0_LOG}))? 'h000:
//(({1'b0, i_mem_addr} >= {1'b0, START_1_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_1_LOG}))? 'h001:
//(({1'b0, i_mem_addr} >= {1'b0, START_2_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_2_LOG}))? 'h002:
//(({1'b0, i_mem_addr} >= {1'b0, START_3_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_3_LOG}))? 'h004:
//(({1'b0, i_mem_addr} >= {1'b0, START_4_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_4_LOG}))? 'h008:
//(({1'b0, i_mem_addr} >= {1'b0, START_5_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_5_LOG}))? 'h010:
//(({1'b0, i_mem_addr} >= {1'b0, START_6_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_6_LOG}))? 'h020:
//(({1'b0, i_mem_addr} >= {1'b0, START_7_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_7_LOG}))? 'h040:
//(({1'b0, i_mem_addr} >= {1'b0, START_8_LOG}) && ({1'b0, i_mem_addr} < {1'b0, END_8_LOG}))? 'h080:
//                                                                                           'h100;                       
////--------------------------------------------------------------------------------------------- 
//// offset choose
//assign          i_mem_offset = (DIRECTION == "LOG2PHY")?   i_mem_l2p_offset : i_mem_p2l_offset;  
////=============================================================================================
//// stage 0
////=============================================================================================
//always_ff@(posedge clk or posedge rst)
// if(rst)                        
//  begin
//   s0_sof        <=                                                                       1'b0;
//   s0_data[71:70]<=                                                                       2'b0;
//   s0_ctrl.valid <=                                                                       1'd0;
//  end 
// else 
//  begin 
//   s0_sof        <=                                                                      i_sof;
//   s0_data[71:70]<=                                                              i_data[71:70];
//   s0_ctrl.valid <=                                                               i_ctrl.valid;
//  end 
////--------------------------------------------------------------------------------------------- 
//always_ff@(posedge clk)
//  begin                                                                                        
//   s0_mem_tr_en <=                                                                       i_ena;
//   s0_mem_off   <=                                                                i_mem_offset;
//   s0_data[69:0]<=                                                                i_data[69:0];
//   s0_ctrl.len  <=                                                                  i_ctrl.len;
//   s0_ctrl.pp   <=                                                                  i_ctrl.pp ;
//   s0_ctrl.did  <=                                                                  i_ctrl.did;
//   s0_ctrl.rid  <=                                                                  i_ctrl.rid;
//  end 
////=============================================================================================
//// stage 1
////============================================================================================= 
//assign          s0_mem_addr_org =                                       {s0_data[38: 3], 3'd0}; 
//assign          s0_mem_addr_tr  =                                 s0_mem_addr_org + s0_mem_off; 
////--------------------------------------------------------------------------------------------- 
//always_ff@(posedge clk or posedge rst)
// if(rst)                        
//  begin
//   s1_sof        <=                                                                       1'b0;
//   s1_data[71:70]<=                                                                       2'b0;
//   s1_ctrl.valid <=                                                                       1'd0;
//  end            
// else            
//  begin                                                                                             
//   s1_sof        <=                                                                     s0_sof;    
//   s1_data[71:70]<=                                                             s0_data[71:70]; 
//   s1_ctrl.valid <=                                                              s0_ctrl.valid;
//  end
////--------------------------------------------------------------------------------------------- 
//always_ff@(posedge clk)
//  begin                                                                                         
//   s1_data[69:39]<=                                                             s0_data[69:39];
//   // address bits changed, but just for header word. For data words memory offset is set to 
//   //  zero so data words are unchanged. This way no multiplexer is needed here   
//   s1_data[38: 3]<=                                                      s0_mem_addr_tr[38: 3];
//   s1_data[ 2: 0]<=                                                             s0_data[ 2: 0];
//   s1_ctrl.len  <=                                                                 s0_ctrl.len;
//   s1_ctrl.pp   <=                                                                 s0_ctrl.pp ;
//   s1_ctrl.did  <=                                                                 s0_ctrl.did;
//   s1_ctrl.rid  <=                                                                 s0_ctrl.rid;
//  end 
////=============================================================================================
//// output
////=============================================================================================
//assign          o_sof          =                                                        s1_sof;
//assign          o_ctrl         =                                                       s1_ctrl;
//assign          o_data         =                                                       s1_data;
////=============================================================================================
//endmodule  
//                                                        