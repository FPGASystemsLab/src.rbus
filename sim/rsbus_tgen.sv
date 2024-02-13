//=============================================================================
//    Main contributors
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//=============================================================================
`default_nettype none
//-----------------------------------------------------------------------------
`timescale 1ns / 1ns
//=============================================================================
module rsbus_tgen_box
(
 input  wire            clk,
 input  wire            rst,

 input  wire            i_stb,
 input  wire            i_sof,
 input  wire     [3:0]  i_iid,
 input  wire    [71:0]  i_data,
 output wire     [1:0]  i_rdy,

 output wire            o_stb,
 output wire            o_sof,
 output wire     [3:0]  o_iid,
 output wire    [71:0]  o_data,
 input  wire     [1:0]  o_rdy,
 input  wire     [1:0]  o_rdyE
);
//=============================================================================================
// parameters
//=============================================================================================
parameter           READ_DELAY_M100     =                                              100_000;
parameter           WRITE_DELAY_M100    =                                              100_000;
parameter           HIGH_PRIORITY_PERC  =                                                    0;  
parameter [ 1:0]    HIGH_PRIORITY_VAL   =                                                 2'd3; 
parameter [ 1:0]    LOW_PRIORITY_VAL    =                                                 2'd0;
//=============================================================================================
// variables
//=============================================================================================
reg signed [31:0] g_rd_cnt;
reg signed [31:0] g_wr_cnt;
reg signed [31:0] g_random;     
reg signed [31:0] g_rd_pri_cnt;
reg signed [31:0] g_wr_pri_cnt;

wire        g_rdy;
//--------------------------------------------------------------------------------------------- 
integer     s_state; 
integer     n_state; 
reg         s_hdr_en;
reg         s_dat_en;
reg   [2:0] s_mode;
reg   [1:0] s_pp;
reg   [3:0] s_rid;
reg   [3:0] s_sid;
reg         s_len;
reg  [38:0] s_addr;
reg  [63:0] s_rdata;
reg  [63:0] s_wdata; 
reg  [63:0] s_data;
reg         s_sel;
wire        s_short_stb; 
wire [ 1:0] s_short_pp;
wire        s_long_stb;  
wire [ 1:0] s_long_pp;
//=============================================================================================
// input
//=============================================================================================
assign i_rdy= 2'b11;
//=============================================================================================
// generator
//=============================================================================================
always@(posedge clk or posedge rst)
 if(rst)                               g_random <=                                           0;
 else if(g_rd_cnt[31] | g_wr_cnt[31])  g_random <=                             $signed($random); 
 else                                  g_random <=                                     g_random;
//=============================================================================================
wire signed [31:0] rd_delay =                                 (READ_DELAY_M100 + 50) / 100 - 1;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                               g_rd_cnt <=                                          -1;
 else if(READ_DELAY_M100==0)           g_rd_cnt <=                                           0;
 else if(init_bsy    )                 g_rd_cnt <=                   rd_delay                 ;
 else if(g_rd_cnt[31])                 g_rd_cnt <= (rd_full)?                               -1:// keep request untill fifo can accept a new packet
                                                 rd_delay + (g_random % ((rd_delay+2)/4 + 1));
 else                                  g_rd_cnt <= g_rd_cnt - 1;                               
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                               g_rd_pri_cnt <= (HIGH_PRIORITY_PERC==0)? -1 :                      ((($random) % ((1000*2/HIGH_PRIORITY_PERC)-1))+5)/10                    ;
 else if(rd_stb      )                 g_rd_pri_cnt <= (HIGH_PRIORITY_PERC==0)? -1 :(g_rd_pri_cnt == 0)? (((($random) % ((1000*2/HIGH_PRIORITY_PERC)-1))+5)/10) : (g_rd_pri_cnt[31]? g_rd_pri_cnt + 1: g_rd_pri_cnt - 1);
 else                                  g_rd_pri_cnt <=                                                               g_rd_pri_cnt    ;  
//---------------------------------------------------------------------------------------------                      
wire [1:0]                  rd_pp       = (g_rd_pri_cnt == 0)? HIGH_PRIORITY_VAL : LOW_PRIORITY_VAL;
//=============================================================================================
wire                        rd_full;
wire                        rd_stb      =     (READ_DELAY_M100!=0) && !rd_full && g_rd_cnt[31]; 
wire                        s_short_ack =                                      (n_state == 11);
//=============================================================================================
ff_srl_af_ack_d32
#(
.WIDTH(2)
)
fifo_for_rd_req
(
 .clk           (clk),
 .rst           (rst),

 .i_stb         (rd_stb),
 .i_data        (rd_pp),
 .i_af          (),
 .i_full        (rd_full),
 .i_err         (),

 .o_stb         (s_short_stb),
 .o_data        (s_short_pp),
 .o_ack         (s_short_ack),
 .o_ae          (),
 .o_err         ()
 );
//=============================================================================================
wire       i_rrid_stb;
wire [4:0] i_rrid_data;

wire       o_rrid_stb;
wire       o_rrid_ack;
wire [4:0] o_rrid_data;

wire       i_wrid_stb;
wire [4:0] i_wrid_data;

wire       o_wrid_stb;
wire       o_wrid_ack;
wire [4:0] o_wrid_data;

reg  [5:0] start_cnt;
wire       init_bsy  =                                                           !start_cnt[5];
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
     if(rst     ) start_cnt <=                                                            6'd0;
else if(init_bsy) start_cnt <=                                                start_cnt + 6'd1;
//---------------------------------------------------------------------------------------------
assign i_rrid_stb  =  init_bsy                  |  (i_stb & i_sof & (i_data[2:0] != 3'b010));
assign i_rrid_data = (init_bsy)? start_cnt[4:0] :/*(i_stb & i_sof)?*/ i_data[44:40];
//---------------------------------------------------------------------------------------------
ff_srl_af_ack_d32
#(
.WIDTH(5)
)
fifo_for_rrid
(
 .clk           (clk),
 .rst           (rst),

 .i_stb         (i_rrid_stb),
 .i_data        (i_rrid_data),
 .i_af          (),
 .i_full        (),
 .i_err         (),

 .o_stb         (o_rrid_stb),
 .o_data        (o_rrid_data),
 .o_ack         (o_rrid_ack),
 .o_ae          (),
 .o_err         ()
 );
 assign o_rrid_ack =                                                             (n_state==11);
 //---------------------------------------------------------------------------------------------
assign i_wrid_stb  =  init_bsy                  |  (i_stb & i_sof & (i_data[2:0] == 3'b010));
assign i_wrid_data = (init_bsy)? start_cnt[4:0] :/*(i_stb & i_sof)?*/ i_data[44:40];// : o_data[43:40];
//---------------------------------------------------------------------------------------------
ff_srl_af_ack_d32
#(
.WIDTH(5)
)
fifo_for_wrid
(
 .clk           (clk),
 .rst           (rst),

 .i_stb         (i_wrid_stb),
 .i_data        (i_wrid_data),
 .i_af          (),
 .i_full        (),
 .i_err         (),

 .o_stb         (o_wrid_stb),
 .o_data        (o_wrid_data),
 .o_ack         (o_wrid_ack),
 .o_ae          (),
 .o_err         ()
 );
 assign o_wrid_ack =                                                             (n_state==21);
//=============================================================================================
wire signed [31:0] wr_delay =                                (WRITE_DELAY_M100 + 50) / 100 - 1;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                    g_wr_cnt <=                                                     -1;
 else if(WRITE_DELAY_M100==0)g_wr_cnt<=                                                      0;
 else if(g_wr_cnt[31])      g_wr_cnt <=            (wr_full)?                               -1:// keep request untill fifo can accept a new packet
                                                   wr_delay + (g_random % ((wr_delay+2)/4 + 1));
 else                       g_wr_cnt <=                                           g_wr_cnt - 1;   
//---------------------------------------------------------------------------------------------                                         
always@(posedge clk or posedge rst)                                                                                                        
 if(rst)                               g_wr_pri_cnt <= (HIGH_PRIORITY_PERC==0)? -1 :                      ((($random) % ((1000*2/HIGH_PRIORITY_PERC)-1))+5)/10                    ;
 else if(wr_stb      )                 g_wr_pri_cnt <= (HIGH_PRIORITY_PERC==0)? -1 :(g_wr_pri_cnt == 0)? (((($random) % ((1000*2/HIGH_PRIORITY_PERC)-1))+5)/10) : (g_wr_pri_cnt[31]? g_wr_pri_cnt + 1: g_wr_pri_cnt - 1);
 else                                  g_wr_pri_cnt <=                                                               g_wr_pri_cnt    ; 
//---------------------------------------------------------------------------------------------                      
wire [1:0]                  wr_pp       = (g_wr_pri_cnt == 0)? HIGH_PRIORITY_VAL : LOW_PRIORITY_VAL;
//=============================================================================================
wire                        wr_full;
wire                        wr_stb      =    (WRITE_DELAY_M100!=0) && !wr_full && g_wr_cnt[31];
wire                        s_long_ack  =                                      (n_state == 21);
//=============================================================================================
ff_srl_af_ack_d16
#(
.WIDTH(2)
)
fifo_for_wr_req
(
 .clk           (clk),
 .rst           (rst),

 .i_stb         (wr_stb),
 .i_data        (wr_pp),
 .i_af          (),
 .i_full        (wr_full),
 .i_err         (),

 .o_stb         (s_long_stb),
 .o_data        (s_long_pp),
 .o_ack         (s_long_ack),
 .o_ae          (),
 .o_err         ()
 );
//=============================================================================================
always@(posedge clk or posedge rst)
 if(rst)                                   s_sel <=   1'b0; 
 else if((n_state==11)                )    s_sel <=   1'b1; 
 else if(                (n_state==21))    s_sel <=   1'b0;
 else                                      s_sel <=  s_sel;
//=============================================================================================
// output
//============================================================================================= 
always@(*)
  case(s_state)                                              
   0:       if(!s_sel & s_short_stb & (o_rdy[0] || (o_rdyE[0] & (s_short_pp==2'd3))) & o_rrid_stb)      n_state   <=  11; // send data
      else  if(!s_sel & s_long_stb  & (o_rdy[1] || (o_rdyE[1] & (s_long_pp ==2'd3))) & o_wrid_stb)      n_state   <=  21; 
      else  if( s_sel & s_long_stb  & (o_rdy[1] || (o_rdyE[1] & (s_long_pp ==2'd3))) & o_wrid_stb)      n_state   <=  21; 
      else  if( s_sel & s_short_stb & (o_rdy[0] || (o_rdyE[0] & (s_short_pp==2'd3))) & o_rrid_stb)      n_state   <=  11; 
      else                                                                                              n_state   <=   0;                                                        
  11:                                                                                                   n_state   <=  12; // send header  (read)
  12:       if(         s_long_stb  & (o_rdy[1] || (o_rdyE[1] & (s_long_pp ==2'd3))) & o_wrid_stb)      n_state   <=  21; 
      else  if(         s_short_stb & (o_rdy[0] || (o_rdyE[0] & (s_short_pp==2'd3))) & o_rrid_stb)      n_state   <=  11; 
      else        														 																										  	  n_state   <=   0; 
                  														 																										  	    
  21:             														 																										  	  n_state   <=  22;  // send header  (read)
  22:             														 																										  	  n_state   <=  23;  // send data[0]
  23:             														 																										  	  n_state   <=  24;  // send data[1]
  24:             														 																										  	  n_state   <=  25;  // send data[2]
  25:             														 																										  	  n_state   <=  26;  // send data[3]
  26:             														 																										  	  n_state   <=  27;  // send data[4]
  27:             														 																										  	  n_state   <=  28;  // send data[5]
  28:             														 																										  	  n_state   <=  29;  // send data[6]   
  29:       if(         s_short_stb & (o_rdy[0] || (o_rdyE[0] & (s_short_pp==2'd3))) & o_rrid_stb)      n_state   <=  11;  // send data[8]
      else  if(         s_long_stb  & (o_rdy[1] || (o_rdyE[1] & (s_long_pp ==2'd3))) & o_wrid_stb)      n_state   <=  21; 
      else                                                                                              n_state   <=   0;   
           
  endcase                 
//-----------------------------------------------------------------------------
always@(posedge clk or posedge rst)
  if(rst)                                                         s_state   <=   0;
  else                                                            s_state   <=   n_state;
//-----------------------------------------------------------------------------
wire [38:0] s_addr_top = 39'h00_80_00_00_00 + 128*1024*1024 - 1024;
always@(posedge clk or posedge rst)
       if(rst        ) s_addr   <=                         39'h00_80_00_00_00;
  else if(n_state==11) s_addr   <= (s_addr >= s_addr_top)? 39'h00_80_00_00_00 : s_addr + 39'h00_00_00_00_08;
  else if(n_state==21) s_addr   <= (s_addr >= s_addr_top)? 39'h00_80_00_00_00 : s_addr + 39'h00_00_00_00_08;
  else                 s_addr   <= s_addr;
  
always@(posedge clk or posedge rst)
  if(rst)
    begin                
      s_hdr_en  <= 1'b0;
      s_dat_en  <= 1'b0;
      s_mode    <= 0;
      s_pp      <= 0;
      s_rid     <= 0;
      s_sid     <= 0; 
      s_len     <= 0;
      s_rdata   <= 0;
      s_wdata   <= 0;
      s_data    <= 'd0;
    end    
  else if(n_state==0)
    begin           
      s_hdr_en  <= 1'b0;
      s_dat_en  <= 1'b0;
      s_mode    <= 3'h1;
      s_pp      <= 0;
      s_rid     <= 0;
      s_sid     <= 0; 
      s_len     <= 0;
      s_rdata   <= s_rdata;
      s_wdata   <= s_wdata; 
      s_data    <= 'd0;
    end 
  else if(n_state==11) // short  - read
    begin           
      s_hdr_en  <= 1'b1;
      s_dat_en  <= 1'b0;
      s_mode    <= 3'h1;
      s_pp      <= s_short_pp;
      s_rid     <= o_rrid_data[3:0];
      s_sid     <= {3'd4, o_rrid_data[4]}; 
      s_len     <= 0;
      s_rdata   <= s_rdata + 1;
      s_wdata   <= s_wdata;
      s_data    <= 'd0;
    end    
  else if(n_state==21) // long - write
    begin             
      s_hdr_en  <= 1'b1;
      s_dat_en  <= 1'b0;
      s_mode    <= 3'h2;
      s_pp      <= s_long_pp;
      s_rid     <= o_wrid_data[3:0];
      s_sid     <= {3'd6, o_wrid_data[4]};  
      s_len     <= 1;
      s_rdata   <= s_rdata;
      s_wdata   <= s_wdata + 1; 
      s_data    <= 'd0;
    end 
  else if(n_state==12) // short - data
    begin             
      s_hdr_en  <= 1'b0;
      s_dat_en  <= 1'b1;
      s_mode    <= 3'h2;
      s_pp      <= 0;
      s_rid     <= 0;
      s_sid     <= 0;    
      s_len     <= 0;
      s_rdata   <= s_rdata; 
      s_wdata   <= s_wdata;
      s_data    <= s_rdata;
    end
  else if((n_state>=22) & (n_state<=29)) // long - data
    begin             
      s_hdr_en  <= 1'b0;
      s_dat_en  <= 1'b1;
      s_mode    <= 3'h2;
      s_pp      <= 0;
      s_rid     <= 0;  
      s_sid     <= 0;
      s_len     <= 0;
      s_rdata   <= s_rdata;
      s_wdata   <= s_wdata;
      s_data    <= s_wdata;
    end
//==============================================================================================
assign  o_stb  =      s_dat_en || s_hdr_en;

assign  o_sof  =      s_hdr_en;

assign  o_iid  =      'd0;

assign  o_data =      (s_hdr_en   ) ? {2'b10,s_pp,4'd0,16'd0,s_sid,s_rid,s_len,s_addr[38:3],s_mode}: 
                      (s_dat_en   ) ? {8'hFF,                                               s_data}: 72'd0;
                                      
//==============================================================================================
endmodule