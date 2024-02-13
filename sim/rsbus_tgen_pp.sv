//=============================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//=============================================================================
`default_nettype none
//-----------------------------------------------------------------------------
`timescale 1ns / 1ns
//=============================================================================
module rsbus_tgen_pp_box
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
//-----------------------------------------------------------------------------
wire [1:0] i_pp = {2{i_sof & i_stb}} & i_data[69:68];
wire       i_wr = i_stb & i_sof & (i_data[2:0] == 3'b010);
wire       i_rd = i_stb & i_sof & (i_data[2:0] != 3'b010);
//=============================================================================================
// parameters
//=============================================================================================
parameter           READ_PP0_DELAY_M100     =                                          100_000;
parameter           WRITE_PP0_DELAY_M100    =                                          100_000;
parameter           READ_PP1_DELAY_M100     =                                          100_000;
parameter           WRITE_PP1_DELAY_M100    =                                          100_000;
parameter           READ_PP2_DELAY_M100     =                                          100_000;
parameter           WRITE_PP2_DELAY_M100    =                                          100_000;
parameter           READ_PP3_DELAY_M100     =                                          100_000;
parameter           WRITE_PP3_DELAY_M100    =                                          100_000;
//=============================================================================================
// variables
//=============================================================================================
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
wire [ 7:0] s_x_stb ; 
wire [ 1:0] s_x_pp  [7:0];

wire [ 1:0] s_sh_max_pp;
wire [ 1:0] s_lg_max_pp;
//=============================================================================================
wire       i_rid_stb [7:0]; 
wire [4:0] i_rid_data[7:0]; 

wire       o_rid_stb [7:0];
wire       o_rid_ack [7:0];
wire [4:0] o_rid_data[7:0];


//---------------------------------------------------------------------------------------------
reg  [5:0] start_cnt;
wire       init_bsy  =                                                           !start_cnt[5];
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
     if(rst     ) start_cnt <=                                                            6'd0;
else if(init_bsy) start_cnt <=                                                start_cnt + 6'd1;
//---------------------------------------------------------------------------------------------
//=============================================================================================
// input
//=============================================================================================
assign i_rdy= 2'b11;
//=============================================================================================
// generator
//=============================================================================================
integer START_DEL_M100;
integer START_DEL;
initial
begin
assign START_DEL_M100 = READ_PP0_DELAY_M100;
if(READ_PP1_DELAY_M100  > START_DEL_M100) assign START_DEL_M100 =  READ_PP1_DELAY_M100;
if(READ_PP2_DELAY_M100  > START_DEL_M100) assign START_DEL_M100 =  READ_PP2_DELAY_M100;
if(READ_PP3_DELAY_M100  > START_DEL_M100) assign START_DEL_M100 =  READ_PP3_DELAY_M100;
if(WRITE_PP0_DELAY_M100 > START_DEL_M100) assign START_DEL_M100 = WRITE_PP0_DELAY_M100;
if(WRITE_PP1_DELAY_M100 > START_DEL_M100) assign START_DEL_M100 = WRITE_PP1_DELAY_M100;
if(WRITE_PP2_DELAY_M100 > START_DEL_M100) assign START_DEL_M100 = WRITE_PP2_DELAY_M100;
if(WRITE_PP3_DELAY_M100 > START_DEL_M100) assign START_DEL_M100 = WRITE_PP3_DELAY_M100;
assign START_DEL = (START_DEL_M100 + 50) / 100;
end
//=============================================================================================
genvar i;
generate
for(i=0; i<=7; i=i+1) begin: read_write_generators
     
  //=============================================================================================
  reg signed [31:0] g_cnt;
  reg signed [31:0] g_random;
  //---------------------------------------------------------------------------------------------
  integer DEL_M100 = ((i[2] == 1'b0) && (i[1:0]==2'd0))?   READ_PP0_DELAY_M100 : 
                     ((i[2] == 1'b0) && (i[1:0]==2'd1))?   READ_PP1_DELAY_M100 : 
                     ((i[2] == 1'b0) && (i[1:0]==2'd2))?   READ_PP2_DELAY_M100 : 
                     ((i[2] == 1'b0) && (i[1:0]==2'd3))?   READ_PP3_DELAY_M100 : 
                     ((i[2] == 1'b1) && (i[1:0]==2'd0))?   WRITE_PP0_DELAY_M100 : 
                     ((i[2] == 1'b1) && (i[1:0]==2'd1))?   WRITE_PP1_DELAY_M100 : 
                     ((i[2] == 1'b1) && (i[1:0]==2'd2))?   WRITE_PP2_DELAY_M100 : 
                   /*((i[2] == 1'b1) && (i[1:0]==2'd3))?*/ WRITE_PP3_DELAY_M100 ;
  //=============================================================================================
  always@(posedge clk or posedge rst)
   if(rst)                               g_random <=                                           0;
   else if(g_cnt[31]                  )  g_random <=                             $signed($random); 
   else                                  g_random <=                                     g_random;
  //=============================================================================================
  wire signed [31:0] x_delay =                                 (DEL_M100 + 50) / 100 - 1;
  //---------------------------------------------------------------------------------------------
  always@(posedge clk or posedge rst)
   if(rst)                               g_cnt    <=                                          -1;
   else if(DEL_M100==0 )                 g_cnt    <=                                           0;
   else if(init_bsy    )                 g_cnt    <=  x_delay + ($unsigned($random) % START_DEL);
   else if(g_cnt[31]   )                 g_cnt    <= (req_ff_full)?                           -1:// keep request untill fifo can accept a new packet
                                                      x_delay + (g_random % ((x_delay+2)/4 + 1));
   else                                  g_cnt    <= g_cnt    - 1;                               
  //---------------------------------------------------------------------------------------------                    
  wire [1:0]                  rd_pp       =                                               i[1:0];
  //=============================================================================================
  wire                        req_ff_full;
  wire                        req_ff_stb =            (DEL_M100!=0) && !req_ff_full && g_cnt[31]; 
  wire                        s_x_ack = (( (i[2] == 1'b1) && (n_state == 21) && (s_lg_max_pp == i[1:0])) || 
                                         ( (i[2] == 1'b0) && (n_state == 11) && (s_sh_max_pp == i[1:0]))   ) && s_x_stb[i];
  //=============================================================================================
  ff_srl_af_ack_d32
  #(
  .WIDTH(1)
  )
  fifo_for_rd_req
  (
   .clk           (clk),
   .rst           (rst),

   .i_stb         (req_ff_stb),
   .i_data        (),
   .i_af          (),
   .i_full        (req_ff_full),
   .i_err         (),

   .o_stb         (s_x_stb[i]),
   .o_data        (),
   .o_ack         (s_x_ack),
   .o_ae          (),
   .o_err         ()
   );
  //---------------------------------------------------------------------------------------------
  assign i_rid_stb[i]  =  init_bsy                  |  (i_stb & i_sof & ((i[2] & i_wr) || (!i[2] & i_rd)) & (i_pp == i[1:0]));
  assign i_rid_data[i] = (init_bsy)? start_cnt[4:0] :/*(i_stb & i_sof)?*/ i_data[44:40];
  //---------------------------------------------------------------------------------------------
  ff_srl_af_ack_d32
  #(
  .WIDTH(5)
  )
  fifo_for_rrid
  (
   .clk           (clk),
   .rst           (rst),

   .i_stb         (i_rid_stb[i]),
   .i_data        (i_rid_data[i]),
   .i_af          (),
   .i_full        (),
   .i_err         (),

   .o_stb         (o_rid_stb[i]),
   .o_data        (o_rid_data[i]),
   .o_ack         (o_rid_ack[i]),
   .o_ae          (),
   .o_err         ()
   );
   assign o_rid_ack[i] =                                                               s_x_ack;
//=============================================================================================
end
endgenerate
//=============================================================================================
always@(posedge clk or posedge rst)
 if(rst)                                   s_sel <=   1'b0; 
 else if((n_state==11)                )    s_sel <=   1'b1; 
 else if(                (n_state==21))    s_sel <=   1'b0;
 else                                      s_sel <=  s_sel;
//=============================================================================================
assign     s_sh_max_pp = (s_x_stb [0+3])?  2'd3:
                         (s_x_stb [0+2])?  2'd2:
                         (s_x_stb [0+1])?  2'd1:
                       /*(s_x_stb [0+0])?*/2'd0;
assign     s_lg_max_pp = (s_x_stb [4+3])?  2'd3:
                         (s_x_stb [4+2])?  2'd2:
                         (s_x_stb [4+1])?  2'd1:
                       /*(s_x_stb [4+0])?*/2'd0;
//=============================================================================================
// output
//============================================================================================= 
always@(*)
  case(s_state)                                              
   0:       if(!s_sel & |s_x_stb[3:0] & (o_rdy[0] || (o_rdyE[0] & (s_sh_max_pp ==2'd3))) & o_rid_stb[  s_sh_max_pp])     n_state   <=  11; // send data
      else  if(!s_sel & |s_x_stb[7:4] & (o_rdy[1] || (o_rdyE[1] & (s_lg_max_pp ==2'd3))) & o_rid_stb[4+s_lg_max_pp])     n_state   <=  21; 
      else  if( s_sel & |s_x_stb[7:4] & (o_rdy[1] || (o_rdyE[1] & (s_lg_max_pp ==2'd3))) & o_rid_stb[4+s_lg_max_pp])     n_state   <=  21; 
      else  if( s_sel & |s_x_stb[3:0] & (o_rdy[0] || (o_rdyE[0] & (s_sh_max_pp ==2'd3))) & o_rid_stb[  s_sh_max_pp])     n_state   <=  11; 
      else                                                                                                               n_state   <=   0;                                                        
  11:                                                                                                                    n_state   <=  12; // send header  (read)
  12:       if(         |s_x_stb[7:4] & (o_rdy[1] || (o_rdyE[1] & (s_lg_max_pp ==2'd3))) & o_rid_stb[4+s_lg_max_pp])     n_state   <=  21; 
      else  if(         |s_x_stb[3:0] & (o_rdy[0] || (o_rdyE[0] & (s_sh_max_pp ==2'd3))) & o_rid_stb[  s_sh_max_pp])     n_state   <=  11; 
      else        														 																							         		                 n_state   <=   0; 
                  														 																							         			                 	    
  21:             														 																						                               n_state   <=  22;  // send header  (read)
  22:             														 																						                               n_state   <=  23;  // send data[0]
  23:             														 																						                               n_state   <=  24;  // send data[1]
  24:             														 																						                               n_state   <=  25;  // send data[2]
  25:             														 																						                               n_state   <=  26;  // send data[3]
  26:             														 																						                               n_state   <=  27;  // send data[4]
  27:             														 																						                               n_state   <=  28;  // send data[5]
  28:             														 																						                               n_state   <=  29;  // send data[6]   
  29:       if(        |s_x_stb[3:0] & (o_rdy[0] || (o_rdyE[0] & (s_sh_max_pp ==2'd3))) & o_rid_stb[  s_sh_max_pp])      n_state   <=  11;  // send data[8]
      else  if(        |s_x_stb[7:4] & (o_rdy[1] || (o_rdyE[1] & (s_lg_max_pp ==2'd3))) & o_rid_stb[4+s_lg_max_pp])      n_state   <=  21; 
      else                                                                                                               n_state   <=   0;   
           
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
  else                 s_addr   <=  s_addr;
  
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
      s_pp      <= s_sh_max_pp;
      s_rid     <= o_rid_data[0+s_sh_max_pp][3:0];
      s_sid     <= {3'd4, o_rid_data[0+s_sh_max_pp][4]}; 
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
      s_pp      <= s_lg_max_pp;
      s_rid     <= o_rid_data[4+s_lg_max_pp][3:0];
      s_sid     <= {3'd6, o_rid_data[4+s_lg_max_pp][4]};  
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