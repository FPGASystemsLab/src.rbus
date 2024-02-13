//=============================================================================================
//    Main contributors
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//      - Jakub Siast
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rbus_introm
(
  input  wire                         clk,
  input  wire                         rst,   
            
  input  wire                         i_stb,
  input  wire                         i_sof,
  input  wire               [71:0]    i_data,
  output wire                [1:0]    i_rdy,
            
  output wire                         o_stb,
  output wire                         o_sof,
  output wire               [71:0]    o_data,
  input  wire                [1:0]    o_rdy
);
//=============================================================================================
// variables
//============================================================================================= 
wire          f_head_stb;  
wire  [ 1:0]  f_mode;   

wire          f_len;
wire          f_rd1; 
wire          f_rd8;
wire          f_wra; 
wire          f_upda; 
wire          f_rd_len; 
                          
wire          f_req_rd;  
wire          f_start_rd;  
wire          f_skip_wr;
wire          f_rd_wr;                                                                       
//----------------------------------------------------------------------------------------------                                                                

wire          m_stb;
wire          m_sof;
wire          m_ack;
wire  [71:0]  m_data;

reg   [31:0]  m_stage; 
wire          m_rdy;
reg   [ 4:0]  m_rdy_cnt;
reg           m0_rd_len;
reg   [38:0]  m0_addr;
reg   [69:0]  m0_hdr;
wire  [63:0]  m1_dat;

reg   [69:0]  m2_hdr;
reg   [63:0]  m2_dat;
reg           m2_thdr;
reg           m2_tstb;

reg   [71:0]  m3_mux;
reg           m3_thdr;
reg           m3_tstb;
//=============================================================================================
// input fifo
//=============================================================================================
rbus_dffs input_fifo
(
.clk        (clk),                   
.rst        (rst),   
                                   
.i_stb      (i_stb),
.i_sof      (i_sof),
.i_data     (i_data), 
.i_rdy      (i_rdy),
.i_err      ( ),

.o_stb      (m_stb),
.o_sof      (m_sof),
.o_data     (m_data),
.o_ack      (m_ack),
.o_err      ( )
); 
//---------------------------------------------------------------------------------------------
assign  f_head_stb  =                                                            m_stb & m_sof; 
assign  f_mode      =                                                              m_data[1:0];
                             
assign  f_len       =                                                               m_data[39];
assign  f_rd1       =                                                     m_data[1:0] == 2'b00; 
assign  f_rd8       =                                                     m_data[1:0] == 2'b01;
assign  f_wra       =                                                     m_data[1:0] == 2'b10; 
assign  f_upda      =                                                     m_data[1:0] == 2'b11;
assign  f_rd_len    =                                                 f_rd8 | (f_upda & f_len);
                             
assign  f_skip_wr   =                                           (f_wra | f_upda) && f_head_stb;  
assign  f_req_rd    =                                   (f_rd1 | f_rd8 | f_upda) && f_head_stb;
assign  f_start_rd  =    f_req_rd & ((f_rd_len & o_rdy[1]) || (!f_rd_len & o_rdy[0])) && m_rdy; 
assign  f_rd_wr     =                                                    f_upda  && f_head_stb;   
//--------------------------------------------------------------------------------------------- 
assign  m_ack       =                          m_stb && (f_start_rd || !f_req_rd || f_skip_wr);
//=============================================================================================
// rom reader
//=============================================================================================  
always@(posedge clk or posedge rst)
 if(rst)                m_rdy_cnt <=                                                     5'h10;
 else if(f_start_rd)    m_rdy_cnt <=                                                     5'h05;
 else if(    !m_rdy)    m_rdy_cnt <=                                         m_rdy_cnt + 5'h01;
 else                   m_rdy_cnt <=                                         m_rdy_cnt        ;
 
 //---------------------------------------------------------------------------------------------
 assign m_rdy =                                                                   m_rdy_cnt[4];
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                m_stage <=                                                           0;
 else case(m_stage)     
  0: if(f_start_rd)     m_stage <=                                                           1; 
     else               m_stage <=                                                           0; 
  1:                    m_stage <=                                                           2; // header
  2:                    m_stage <= (m0_rd_len)?                                          3 : 0; // dw0
  3:                    m_stage <=                                                           4; // dw1
  4:                    m_stage <=                                                           5; // dw2
  5:                    m_stage <=                                                           6; // dw3
  6:                    m_stage <=                                                           7; // dw4
  7:                    m_stage <=                                                           8; // dw5
  8:                    m_stage <=                                                           9; // dw6
  9:                    m_stage <=                                                           0; // dw7
  default:              m_stage <=                                                     m_stage;  
 endcase  
//---------------------------------------------------------------------------------------------
always@(posedge clk)
      if(m_stage==0)    m0_addr <=                                         {m_data[38:3],3'd0}; 
 else if(m_stage==1)    m0_addr <=                                                   m0_addr+8; 
 else if(m_stage==2)    m0_addr <=                                                   m0_addr+8; 
 else if(m_stage==3)    m0_addr <=                                                   m0_addr+8; 
 else if(m_stage==4)    m0_addr <=                                                   m0_addr+8; 
 else if(m_stage==5)    m0_addr <=                                                   m0_addr+8; 
 else if(m_stage==6)    m0_addr <=                                                   m0_addr+8; 
 else if(m_stage==7)    m0_addr <=                                                   m0_addr+8; 
 else if(m_stage==8)    m0_addr <=                                                   m0_addr+8; 
 else if(m_stage==9)    m0_addr <=                                                   m0_addr+8; 
 else                   m0_addr <=                                                   m0_addr+8;
//---------------------------------------------------------------------------------------------
always@(posedge clk)
      if(f_start_rd)    m0_hdr  <=                                                m_data[69:0]; 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)
      if(f_start_rd)    m0_rd_len  <=                                                 f_rd_len;
 else                   m0_rd_len  <=                                                m0_rd_len;
                                                                                                
//---------------------------------------------------------------------------------------------
rom bootrom
(
.clk        (clk),
.rst        (rst),

.i_addr     (m0_addr[15:0]),

.o_data     (m1_dat)
);
//---------------------------------------------------------------------------------------------
always@(posedge clk)
      if(m_stage==1)    m2_hdr  <=                                                m0_hdr[69:0]; // hdr
 else                   m2_hdr  <=                                                m2_hdr[69:0]; // 7
//---------------------------------------------------------------------------------------------
always@(posedge clk )   m2_dat  <=                                                m1_dat[63:0]; 
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                m2_tstb <=                                                           0;
 else if(m_stage==1)    m2_tstb <=                                                           1; // hdr
 else if(m_stage==2)    m2_tstb <=                                                           1; // 0
 else if(m_stage==3)    m2_tstb <=                                                           1; // 1
 else if(m_stage==4)    m2_tstb <=                                                           1; // 2
 else if(m_stage==5)    m2_tstb <=                                                           1; // 3
 else if(m_stage==6)    m2_tstb <=                                                           1; // 4
 else if(m_stage==7)    m2_tstb <=                                                           1; // 5
 else if(m_stage==8)    m2_tstb <=                                                           1; // 6
 else if(m_stage==9)    m2_tstb <=                                                           1; // 7
 else                   m2_tstb <=                                                           0;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst) 
 if(rst)                m2_thdr <=                                                           0;
 else if(m_stage==1)    m2_thdr <=                                                           1; // hdr
 else if(m_stage==2)    m2_thdr <=                                                           0; // 0
 else if(m_stage==3)    m2_thdr <=                                                           0; // 1
 else if(m_stage==4)    m2_thdr <=                                                           0; // 2
 else if(m_stage==5)    m2_thdr <=                                                           0; // 3
 else if(m_stage==6)    m2_thdr <=                                                           0; // 4
 else if(m_stage==7)    m2_thdr <=                                                           0; // 5
 else if(m_stage==8)    m2_thdr <=                                                           0; // 6
 else if(m_stage==9)    m2_thdr <=                                                           0; // 7
 else                   m2_thdr <=                                                           0;
//---------------------------------------------------------------------------------------------
always@(posedge clk)
      if(m2_thdr   )    m3_mux  <=             {2'b10, m2_hdr[69:40], m0_rd_len, m2_hdr[38:0]}; // hdr
 else                   m3_mux  <=                                       {8'hFF, m2_dat[63:0]}; // dat
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                m3_tstb <=                                                           0;
 else                   m3_tstb <=                                                     m2_tstb; 
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                m3_thdr <=                                                           0;
 else                   m3_thdr <=                                                     m2_thdr;
//=============================================================================================
// output
//=============================================================================================
assign    o_stb   =                                                                    m3_tstb;
assign    o_sof   =                                                                    m3_thdr;
assign    o_data  =                                                                     m3_mux;
//=============================================================================================
endmodule
