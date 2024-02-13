//=============================================================================================
//    Main contributors
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//      - Jakub Siast        
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
// Each N-th packet goes to the oa_... channel and rest of packets goes to the ob_... channel.
// oa_channel is assumed to be connected to a module with its own fifo so there is no fifo 
//  for this channel output inside this module.
// ob_... channel has fifo on its output so it can be connected to the input of another 
//  rbus_r2d_demux1to2. 
// TODO: i_rdy is "s0_rdy & oa_rdy". Change it to "s0_rdy | oa_rdy" with proper channel switching handling.
//=============================================================================================
module rbus_demux1to2
#(
parameter           DEMUX_RATIO                                                            = 1 // N:1
)
(                                                                                                                               
input  wire         clk,
input  wire         rst,   

input  wire         i_stb,                                                               
input  wire         i_sof,
input  wire [71:0]  i_data,
output wire  [1:0]  i_rdy,   

output wire         oa_stb,
output wire         oa_sof,
output wire [71:0]  oa_data,
input  wire  [1:0]  oa_rdy,

output wire         ob_stb,
output wire         ob_sof,
output wire [71:0]  ob_data,
input  wire  [1:0]  ob_rdy,

output reg          ff_err
);        
//=============================================================================================
// variables
//=============================================================================================
reg         s0_stb_A;
reg         s0_stb_B;
reg         s0_sof;
reg  [71:0] s0_data;
wire  [1:0] s0_af;  
reg   [3:0] s0_cnt_l;
reg   [3:0] s0_cnt_s;
//---------------------------------------------------------------------------------------------
wire        s1_pkt_len;
wire        s1_lng_pkt_en;
wire        s1_srt_pkt_en;
wire        s1_pkt_dat_en;

wire        s1_stb;
wire        s1_sof;
wire [71:0] s1_data;
wire        s1_ack;
//---------------------------------------------------------------------------------------------
reg         s2_stb;
reg         s2_sof;
reg  [71:0] s2_data;
//---------------------------------------------------------------------------------------------
wire        ff_for_B_ch_i_err;
wire        ff_for_B_ch_o_err;
//=============================================================================================
// input demux
//=============================================================================================
always@(posedge clk or posedge rst)
 if(rst) 
	begin                                                                
		s0_stb_A    <=                                                                         'd0; 
		s0_stb_B    <=                                                                         'd0;  
		s0_cnt_l    <=                                                                         'd0;	
		s0_cnt_s    <=                                                                         'd0;		
	end                                                                  
 else if(i_stb &&  i_data[39] && i_sof == 1'b1) // header                             
	begin                                                                
		s0_stb_A    <=                                                             (s0_cnt_l=='d0); 
		s0_stb_B    <=                                                             (s0_cnt_l!='d0); 
		s0_cnt_s    <=                                                              s0_cnt_s      ;	
		s0_cnt_l    <= (s0_cnt_l == DEMUX_RATIO - 1) ?                        'd0 : s0_cnt_l + 'd1;		
	end                                                               
 else if(i_stb && !i_data[39] && i_sof == 1'b1) // header                             
	begin                                                                
		s0_stb_A    <=                                                             (s0_cnt_s=='d0); 
		s0_stb_B    <=                                                             (s0_cnt_s!='d0); 
		s0_cnt_s    <= (s0_cnt_s == DEMUX_RATIO - 1) ?                        'd0 : s0_cnt_s + 'd1;	
		s0_cnt_l    <=                                                              s0_cnt_l      ;		
	end                                                                  
 else if(i_stb && i_sof == 1'b0) // data                               
	begin                                                                
		s0_stb_A    <=                                                                    s0_stb_A; 
		s0_stb_B    <=                                                                    s0_stb_B; 
		s0_cnt_s    <=                                                                    s0_cnt_s; 
		s0_cnt_l    <=                                                                    s0_cnt_l;		
	end                                                                  
 else                                                                  
	begin                                                                
		s0_stb_A    <=                                                                         'd0; 
		s0_stb_B    <=                                                                         'd0; 
		s0_cnt_s    <=                                                                    s0_cnt_s; 
		s0_cnt_l    <=                                                                    s0_cnt_l;	
	end
//---------------------------------------------------------------------------------------------
always@(posedge clk)
if(i_stb && i_sof == 1'b1) // header                     
	begin                                                  
		s0_sof      <=                                                                        1'b1; 
		s0_data     <=                                                                      i_data;		
	end                                                    
else if(i_stb && i_sof == 1'b0) // data                  
	begin                                                  
		s0_sof      <=                                                                        1'b0; 
		s0_data     <=                                                                      i_data;	
	end                                                    
else                                                     
	begin                                                  
		s0_sof      <=                                                                         'd0; 
		s0_data     <=                                                                      i_data;
	end
//---------------------------------------------------------------------------------------------
assign  i_rdy        =                                                       (~s0_af) & oa_rdy;
//=============================================================================================
// input buffer
//=============================================================================================
ff_dram_af_ack_d32 
#(             
.AF0LIMIT(6'd2+ 6'd2), // 1 for additional one clock cycle for af check in extractor
.AF1LIMIT(6'd9+ 6'd2), // 1 for additional one clock cycle for af check in extractor
.WIDTH(73)                                                                           
) 
fifo_for_B_channel
(                     
 .clk           (clk),                         
 .rst           (rst),   
 
 .i_stb         (s0_stb_B),
 .i_data        ({s0_sof,s0_data}),
 .i_af          (s0_af),    
 .i_full        (),
 .i_err         (ff_for_B_ch_i_err), 
 
 .o_stb         (s1_stb),
 .o_data        ({s1_sof,s1_data}),
 .o_ack         (s1_ack), 						 
 .o_ae          (),            							 
 .o_err         (ff_for_B_ch_o_err)
 ); 
//=============================================================================================
assign s1_pkt_len    =                                                             s1_data[39];
assign s1_lng_pkt_en =                              s1_stb &  s1_sof &  s1_pkt_len & ob_rdy[1];
assign s1_srt_pkt_en =                              s1_stb &  s1_sof & !s1_pkt_len & ob_rdy[0];
assign s1_pkt_dat_en =                              s1_stb & !s1_sof                          ;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                   s2_stb      <=                                                 1'b0; 
 else if( s1_pkt_dat_en )  s2_stb      <=                                                 1'b1;
 else if( s1_lng_pkt_en )  s2_stb      <=                                                 1'b1;
 else if( s1_srt_pkt_en )  s2_stb      <=                                                 1'b1;
 else                      s2_stb      <=                                                 1'b0;
//---------------------------------------------------------------------------------------------
assign s1_ack =                              (s1_lng_pkt_en || s1_srt_pkt_en || s1_pkt_dat_en);
//---------------------------------------------------------------------------------------------
always@(posedge clk)                                                        
	begin                                                                       
		                       s2_sof      <=                                               s1_sof; 
		                       s2_data     <=                                              s1_data;	
	end
//=============================================================================================
// output A
//=============================================================================================  
assign  oa_stb          =                                                             s0_stb_A;
assign  oa_sof          =                                                               s0_sof;
assign  oa_data         =                                                              s0_data;
//=============================================================================================
// output B
//=============================================================================================  
assign  ob_stb          =                                                               s2_stb;
assign  ob_sof          =                                                               s2_sof;
assign  ob_data         =                                                              s2_data;
//============================================================================================= 
always@(posedge clk or posedge rst)
if(rst)                    ff_err      <=                                                 1'b0;
else                       ff_err      <=     ff_err || ff_for_B_ch_i_err || ff_for_B_ch_o_err;
//=============================================================================================
endmodule