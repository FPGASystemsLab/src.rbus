//============================================================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//============================================================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//============================================================================================================================
module rbus_mif64_axi  
#(
parameter [38:0] BURST_BORDER = 1024*4, // read/write burst should not cross border of 4KB 
parameter        SEND_WR_FB   = "TRUE"  // "TRUE", "FALSE"
) 
(
 input  wire            net_clk,
 input  wire            net_rst,
 input  wire            mem_clk,
 input  wire            rst,   

 input  wire            i_stb,
 input  wire            i_sof,
 input  wire    [71:0]  i_data,
 output wire     [1:0]  i_rdy,
 output reg             i_ff_err,

 output wire            o_stb,
 output wire            o_sof,
 output wire    [71:0]  o_data,
 input  wire     [1:0]  o_rdy,
 output reg             o_ff_err,
 output reg     [ 2:0]  o_dbg_err,
 
 output wire            co_rd_stb,
 output wire            co_wr_stb,
 output wire    [38:0]  co_addr,
 input  wire            co_wr_rdy,
 input  wire            co_rd_rdy,

 output wire            do_stb,
 output wire     [7:0]  do_mask,
 output wire    [63:0]  do_data,
 input  wire            do_rdy,//   (c1_p0_wr_data_rdy), 
 output wire            do_end,//   (c1_p0_wr_data_end),
 
 input wire             ci_wr_end,
 
 input  wire            di_en,
 input  wire    [63:0]  di_data,
 input  wire            di_end,
         
 output wire    [9:0]   dbg
);      
//=============================================================================================
// parameters
//=============================================================================================
// if adress bits in BURST_BORDER_HI_MASK positions are all high and any bit in BURST_BORDER_LO_MASK is hi 
//  then this operation will cross BURST_BORDER 
localparam [38:0] BURST_BORDER_LO_MASK = 39'b0111000; 
localparam [39:0] BURST_BORDER_HI_MASKx= (~(BURST_BORDER ^ (~BURST_BORDER + 1)) );
localparam [38:0] BURST_BORDER_HI_MASK = {1'b1, BURST_BORDER_HI_MASKx[39:1]} ^ 39'b0111111;
//=============================================================================================
// variables
//=============================================================================================
wire         i_dff_err;

wire         x_stb;
wire         x_sof;
wire [71:0]  x_data;
wire         x_ack;
wire         x_ff_err;    
            
reg  [10:0]  di_cnt;
wire         di_cnt_dec;   
//---------------------------------------------------------------------------------------------
wire         r1_h_stb;
wire         r1_pkt_en;
wire         r1_pkt_rd_en; 
wire         r1_pkt_wr_en; 
wire [75:0]  r1_h_data;
wire [71:0]  r1_h_header;
wire         r1_h_not_alig;
wire [ 2:0]  r1_h_pre;
wire         r1_h_ack;
wire         r1_h_err; 
    
//---------------------------------------------------------------------------------------------
rbus_dff dff
(
.clk      (net_clk),     
.rst      (net_rst),

.i_stb    (i_stb),
.i_sof    (i_sof),
.i_data   (i_data),//(i_sof)?(i_data|72'hFC8):i_data),
//.i_data   ((i_sof)?(i_data|72'hFC8):i_data),
.i_rdy    (i_rdy),
.i_err    (i_dff_err),

.o_stb    (x_stb), 
.o_sof    (x_sof),
.o_data   (x_data),
.o_ack    (x_ack),
.o_err    (x_ff_err)
);  
//=============================================================================================
// input parsing and fifos space check, delete read packet payload
//============================================================================================= 
reg         ffh_i_ena;
reg  [75:0] ffh_i_data;
wire        ffh_i_full;
wire        ffh_i_err;

wire        ftm_i_wen;
wire [71:0] ftm_i_data;
wire        ftm_i_full;
wire        ftm_i_af;
wire [ 8:0] ftm_i_wcnt;    
wire        ftm_i_werr;
reg         x_f_wr_pkt;    
//=============================================================================================

wire        fx_head_stb; 
wire [ 1:0] fx_mode;
   
wire        fx_len;
wire        fx_rd1; 
wire        fx_rd8;
wire        fx_wra; 
wire        fx_upda;
wire        fx_rd_len;

wire        fx_f_hrd; 
wire        fx_f_hwr; 
wire        fx_rd_wr;
wire        fx_f_dat; 
wire        fx_hd_ff_rdy; 
wire        fx_ftm_ff_rdy;  
wire        fx_rd_ff_rdy; 
reg         fx_rd_ff_rdy_r;    
                          
wire        fx_hi_bits_border_f;
wire        fx_lo_bits_border_f;          
wire        fx_not_alig_f; 
wire [2:0]  fx_pre_num;
reg         fx_not_alig_f_r; 
                                    
wire        fx_f_hrd_ena;
reg         fx_f_hrd_ena_r;
wire        fx_f_hwr_ena;
wire        fx_f_dwr_ena;
wire        fx_f_drd_ena;                                                                        
//---------------------------------------------------------------------------------------------
     
  assign  fx_hi_bits_border_f =  (BURST_BORDER_HI_MASK & x_data[38:0]) == BURST_BORDER_HI_MASK;
  assign  fx_lo_bits_border_f =  (BURST_BORDER_LO_MASK & x_data[38:0]) !=                39'd0;
  assign  fx_not_alig_f       =                      fx_hi_bits_border_f & fx_lo_bits_border_f; 
//---------------------------------------------------------------------------------------------
assign fx_pre_num =        (x_data[5:3]==3'd0)?                                           3'd0: 
                           (x_data[5:3]==3'd1)?                                           3'd1:
                           (x_data[5:3]==3'd2)?                                           3'd2:
                           (x_data[5:3]==3'd3)?                                           3'd3:
                           (x_data[5:3]==3'd4)?                                           3'd4:
                           (x_data[5:3]==3'd5)?                                           3'd5:
                           (x_data[5:3]==3'd6)?                                           3'd6:
                         /*(i_data[5:3]==3'd7)?*/                                         3'd7;
  
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst) 
 if(net_rst)                           fx_f_hrd_ena_r <=                                  1'b0;  
 else                                  fx_f_hrd_ena_r <=                          fx_f_hrd_ena; 
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst) 
 if(net_rst)                           fx_not_alig_f_r<=                                  1'b0;  
 else                                  fx_not_alig_f_r<=                         fx_not_alig_f; 
//---------------------------------------------------------------------------------------------
// data counter
always@(posedge net_clk or posedge net_rst) 
 if(net_rst)                           di_cnt <=                                         11'd0; 
 else if( fx_f_hrd_ena_r && di_cnt_dec)di_cnt <=((fx_not_alig_f_r)? 11'd16 : 11'd8) + di_cnt -11'd1;
 else if( fx_f_hrd_ena_r &&!di_cnt_dec)di_cnt <=((fx_not_alig_f_r)? 11'd16 : 11'd8) + di_cnt -11'd0;
 else if(!fx_f_hrd_ena_r && di_cnt_dec)di_cnt <=                                 di_cnt -11'd1;
 else                                  di_cnt <=                                 di_cnt       ; 
//---------------------------------------------------------------------------------------------
assign      fx_rd_ff_rdy =                                {1'b0, di_cnt} <= (11'd512 - 11'd16); 
//---------------------------------------------------------------------------------------------
// data counter
always@(posedge net_clk or posedge net_rst) 
 if(net_rst)                           fx_rd_ff_rdy_r <=                                 1'b0;  
 else                                  fx_rd_ff_rdy_r <=                         fx_rd_ff_rdy; 
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst)
 if(net_rst)        x_f_wr_pkt       <=                                                  1'd0;
 else if(fx_f_hwr)  x_f_wr_pkt       <=                                                  1'd1;
 else if(fx_f_hrd)  x_f_wr_pkt       <=                                                  1'd0;
 else               x_f_wr_pkt       <=                                            x_f_wr_pkt;
//---------------------------------------------------------------------------------------------
assign      fx_head_stb  =                                                      x_sof && x_stb; 
assign      fx_mode      =                                                         x_data[1:0];
                        
assign      fx_len       =                                                          x_data[39];
assign      fx_rd1       =                                                x_data[1:0] == 2'b00; 
assign      fx_rd8       =                                                x_data[1:0] == 2'b01;
assign      fx_wra       =                                                x_data[1:0] == 2'b10; 
assign      fx_upda      =                                                x_data[1:0] == 2'b11;
assign      fx_rd_len    =                                         fx_rd8 | (fx_upda & fx_len);
              
assign      fx_f_hwr     =                                  (fx_wra/*| fx_upda*/)&&fx_head_stb;  
assign      fx_f_hrd     =                          (fx_rd1 | fx_rd8 | fx_upda) && fx_head_stb;
assign      fx_rd_wr     =                                             fx_upda  && fx_head_stb; 
 
assign      fx_f_dat     =                                                     !x_sof && x_stb; 
assign      fx_hd_ff_rdy =                                                         !ffh_i_full; 
assign      fx_ftm_ff_rdy=                                                           !ftm_i_af;  

assign      fx_f_hrd_ena = (fx_f_hrd &                          fx_hd_ff_rdy  & fx_rd_ff_rdy_r & fx_ftm_ff_rdy);
assign      fx_f_hwr_ena = (fx_f_hwr &((SEND_WR_FB != "TRUE") | fx_hd_ff_rdy)                  & fx_ftm_ff_rdy);
assign      fx_f_dwr_ena =                                          (  x_f_wr_pkt  & fx_f_dat);
assign      fx_f_drd_ena =                                          ( !x_f_wr_pkt  & fx_f_dat);

assign      x_ack        =        fx_f_hwr_ena || fx_f_hrd_ena || fx_f_dwr_ena || fx_f_drd_ena;
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst) 
if(net_rst)              ffh_i_ena  <=                                                    1'b0;
else                     ffh_i_ena  <= fx_f_hrd_ena || ((SEND_WR_FB == "TRUE") & fx_f_hwr_ena);
//---------------------------------------------------------------------------------------------
always@(posedge net_clk) ffh_i_data <=                {fx_not_alig_f, fx_pre_num[2:0], x_data};
//---------------------------------------------------------------------------------------------
assign      ftm_i_wen    =        fx_f_hwr_ena || fx_f_hrd_ena || fx_f_dwr_ena                ; 
assign      ftm_i_data   =                                                        x_data[71:0];
//=============================================================================================
// buffer for 32 headers for read operations
//============================================================================================= 
ff_dram_af_ack_d32
#(
.WIDTH(1+3+72)
)   
ffh
(             
.clk    (net_clk),
.rst    (net_rst),
                 
.i_stb  (ffh_i_ena),  
.i_data (ffh_i_data),
.i_af   (),
.i_full (ffh_i_full),
.i_err  (ffh_i_err),

.o_stb  (r1_h_stb),
.o_ack  (r1_h_ack),
.o_data (r1_h_data),
.o_err  (r1_h_err),
.o_ae   ()
);                                                                                              
//---------------------------------------------------------------------------------------------   
reg  [31:0] xx_r1_heade_ff_ack;                                                                      
reg  [31:0] xx_r1_data_done;   
reg  [31:0] xx_r3_headers_done;                                                                      
reg  [31:0] xx_r3_data_done;                                                                           
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst) 
 if(net_rst)                           xx_r1_heade_ff_ack <=                               'd0;  
 else if(r1_h_ack                    ) xx_r1_heade_ff_ack <=          xx_r1_heade_ff_ack + 'd1;  
 else                                  xx_r1_heade_ff_ack <=          xx_r1_heade_ff_ack      ; 
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst) 
 if(net_rst)                           xx_r1_data_done    <=                               'd0;  
 else if(r1_ack                      ) xx_r1_data_done    <=             xx_r1_data_done + 'd1;  
 else                                  xx_r1_data_done    <=             xx_r1_data_done      ;
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst) 
 if(net_rst)                           xx_r3_headers_done <=                               'd0;  
 else if(r3_en &  r3_sof             ) xx_r3_headers_done <=          xx_r3_headers_done + 'd1;  
 else                                  xx_r3_headers_done <=          xx_r3_headers_done      ; 
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst) 
 if(net_rst)                           xx_r3_data_done    <=                               'd0;  
 else if(r3_en & !r3_sof             ) xx_r3_data_done    <=             xx_r3_data_done + 'd1;  
 else                                  xx_r3_data_done    <=             xx_r3_data_done      ; 
//---------------------------------------------------------------------------------------------   
wire   xx_headers_mismatch =                          xx_r1_heade_ff_ack != xx_r3_headers_done;
wire   xx_data_h_mismatch  =                       xx_r3_data_done[31:3] != xx_r3_headers_done;
//---------------------------------------------------------------------------------------------
wire        ftm_o_stb;
wire        ftm_o_ack;
wire        ftm_o_empty;
wire        ftm_o_aempty;
wire [71:0] ftm_o_data;
wire [12:0] ftm_o_rcnt; 
wire        ftm_o_rerr;
//--------------------------------------------------------------------------------------------- 
FIFO_DUALCLOCK_MACRO    
#(       
                            
.FIFO_SIZE               ("36Kb"),
   
.DATA_WIDTH              (72),
    
.ALMOST_EMPTY_OFFSET     (13'd008),    
.ALMOST_FULL_OFFSET      (13'd016), //It must be set to a value smaller than (FIFO_DEPTH - ((roundup(4 * (WRCLK frequency / RDCLK frequency))) + 6)) when FIFO36E1 has different frequencies for RDCLK and WRCLK
.DEVICE                  ("7SERIES"),
   
.FIRST_WORD_FALL_THROUGH ("TRUE")                              
)
ff_interd_to_mem
( 
.RST        (net_rst), 
.WRCLK      (net_clk), 
.RDCLK      (mem_clk),    

.WREN       (ftm_i_wen),
.DI         (ftm_i_data),
.FULL       (ftm_i_full),
.WRCOUNT    (ftm_i_wcnt),   
.WRERR      (ftm_i_werr),
.ALMOSTFULL (ftm_i_af),
                        
.RDEN       (ftm_o_ack),
.EMPTY      (ftm_o_empty),
.ALMOSTEMPTY(ftm_o_aempty), 
.RDCOUNT    (ftm_o_rcnt), 
.RDERR      (ftm_o_rerr),
.DO         (ftm_o_data)
);
assign ftm_o_stb = !ftm_o_empty;
//=============================================================================================
// memory interface state machine
//=============================================================================================    
wire [ 1:0] t1_ff_af;   
wire        t1_ff_full; 
wire        t1_ff_werr;

reg         t1_en;  

reg         t1_cr_en;
reg         t1_cw_en;     
    
reg         t1_d_en;
reg         t1_d_last; 
reg  [63:0] t1_d_data;
reg  [ 7:0] t1_d_mask;  
//--------------------------------------------------------------------------------------------- 
//reg[31:0] cnt;
//always@(posedge mem_clk or posedge rst)
//if(rst)            cnt <= 400;
//else if (cnt == 0) cnt <= 400;
//else               cnt <= cnt - 'd1;
//
//wire t2_stbx;
//wire  fake_stop = cnt < 220;
rbus_mif64_binj  
#(
.BURST_BORDER (BURST_BORDER) // read/write burst should not cross border of 4KB
) 
corss_boundary_inspector
(
.clk      (mem_clk),
.rst      (rst),   

.i_stb    (ftm_o_stb),
.i_data   (ftm_o_data),
.i_ack    (ftm_o_ack),

.o_en     (t1_en),
.o_cr_en  (t1_cr_en),
.o_cw_en  (t1_cw_en),
.o_d_en   (t1_d_en),
.o_d_lst  (t1_d_last),
.o_data   (t1_d_data),
.o_mask   (t1_d_mask),
.o_rdy    (~t1_ff_af)
);                                                      
//============================================================================================= 
// parsed command and data output fifo
//=============================================================================================
wire        t2_stb; 
wire        t2_ack;  

wire        t2_cw_en;
wire        t2_cr_en;   
wire [38:0] t2_c_addr;  

wire        t2_d_en;
wire [63:0] t2_d_data;   
wire [ 7:0] t2_d_mask;  
wire        t2_d_end;   
wire        t2_ff_rerr;        
//---------------------------------------------------------------------------------------------                                                                   
ff_dram_af_ack_d32
#(
.WIDTH(1+1+1+1+8+64),     
.AF0LIMIT (7'd2+7'd2),
.AF1LIMIT (7'd9+7'd2)
)   
ff_uif
(             
.clk    (mem_clk),
.rst    (rst),
                 
.i_stb  (t1_en),  
.i_data ({t1_cr_en, t1_cw_en, t1_d_en, t1_d_last, t1_d_mask, t1_d_data}),
.i_af   (t1_ff_af),
.i_full (t1_ff_full),
.i_err  (t1_ff_werr),

.o_stb  (t2_stb),
.o_ack  (t2_ack),
.o_data ({t2_cr_en, t2_cw_en, t2_d_en, t2_d_end, t2_d_mask, t2_d_data}),
.o_err  (t2_ff_rerr),
.o_ae   ()
);  
//assign  t2_stb = !fake_stop & t2_stbx;                                                                                                               
//=============================================================================================
// output to memory controller
//============================================================================================= 
assign      t2_c_addr     =                                             {t2_d_data[38:3],3'd0};
assign      co_wr_stb     =                                                  t2_stb & t2_cw_en;
assign      co_rd_stb     =                                                  t2_stb & t2_cr_en; 
assign      co_addr       =                                                    t2_c_addr[38:0];
//---------------------------------------------------------------------------------------------
assign      do_stb        =                                                   t2_stb & t2_d_en;
assign      do_mask       =                                                          t2_d_mask;  
assign      do_data       =                                                          t2_d_data;
assign      do_end        =                                                           t2_d_end;
//--------------------------------------------------------------------------------------------- 
assign      t2_ack        =                                  t2_stb & (!co_wr_stb | co_wr_rdy)&
                                                                      (!co_rd_stb | co_rd_rdy)&
                                                                      (!   do_stb |    do_rdy); 
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst)
 if(net_rst)                        i_ff_err       <=                                     1'd0;
 else if(i_dff_err  || x_ff_err  )  i_ff_err       <=                                     1'd1;
 else if(ffh_i_err               )  i_ff_err       <=                                     1'd1;
 else if(ftm_i_werr || ftm_o_rerr)  i_ff_err       <=                                     1'd1;/*ftm_o_rerr in mem_clk domain but constant*/
 else if(t1_ff_werr || t2_ff_rerr)  i_ff_err       <=                                     1'd1;
 else                               i_ff_err       <=                                 i_ff_err;
//=============================================================================================
// interdomain fifo for data from memory
//=============================================================================================  
wire        r0_en;
wire        r0_data_end;
wire [63:0] r0_data;
wire        r0_wr_err; 
wire        r0_full; 
wire [12:0] r0_wr_cnt;  
wire        r0_wr_af;
  
wire        r0_wr_res_end;   
wire        r0_wr_res_full;   
//---------------------------------------------------------------------------------------------
integer      pf_state;
//---------------------------------------------------------------------------------------------
wire        r1_stb;
wire        r1_ack;
wire        r1_empty; 
wire        r1_7OrLess;
wire [63:0] r1_data; 
wire        r1_data_end;   
wire [ 6:0] r1_data_zero_unused;  
wire        r1_rd_err; 
wire [12:0] r1_rd_cnt; 

wire        r1_wr_res_stb;  
wire        r1_wr_res_ack;   
//---------------------------------------------------------------------------------------------
reg         r2_pkt_wr_en; 

reg  [16:0] r2_data_sof_sr;
wire        r2_data_sof_f;
reg  [16:0] r2_data_lst_sr;
wire        r2_data_lst_f;
reg  [16:0] r2_data_ack_sr;
wire        r2_data_ack_f;
reg  [16:0] r2_data_out_sr;
wire        r2_data_out_f;

reg  [ 2:0] r2_wr_res_sof_sr;
wire        r2_wr_res_sof_f;
reg  [ 2:0] r2_wr_res_fill_sr;
wire        r2_wr_res_fill_f;
wire        r2_wr_res_lst_f;
//---------------------------------------------------------------------------------------------
wire        r3_wr_err; 

reg         r3_en; 
reg  [71:0] r3_data; 
reg         r3_sof;        
wire [ 1:0] r3_rdy;  
wire        r3_full;
wire        r4_rd_err;                                                                          
//============================================================================================= 
assign      r0_en       =                                                                di_en;
assign      r0_data_end =                                                               di_end;
assign      r0_data     =                                                              di_data;  
//--------------------------------------------------------------------------------------------- 
assign      di_cnt_dec  =                                                               r1_ack;
//---------------------------------------------------------------------------------------------
// interdomain synchronization of "writer operation finished" messages
assign      r0_wr_res_end =                                                          ci_wr_end;
//--------------------------------------------------------------------------------------------- 
intdom_trg_synch_ack #(.MAX_LOG2_IFREQ_DIV_OFREQ ('d1), .MAX_LOG2_OFREQ_DIV_IFREQ ('d1), .BUFF_LEN(64)) // buffer for as many triggers as writes that can be accepted in this memhub (fifo for 32 headers) mul by 2 because writes crossing 4kB boundary are actually done using two writes 
wr_end_synch(.i_clk (mem_clk), .i_rst (    rst), .i_trg (r0_wr_res_end), .i_full(r0_wr_res_full), .i_err(),
             .o_clk (net_clk), .o_rst (net_rst), .o_trg (r1_wr_res_stb), .o_ack (r1_wr_res_ack) , .o_err());                         
//--------------------------------------------------------------------------------------------- 
FIFO_DUALCLOCK_MACRO    
#(       
                            
.FIFO_SIZE               ("36Kb"),
   
.DATA_WIDTH              (72),
       
.ALMOST_FULL_OFFSET      (13'd016), //It must be set to a value smaller than (FIFO_DEPTH - ((roundup(4 * (WRCLK frequency / RDCLK frequency))) + 6)) when FIFO36E1 has different frequencies for RDCLK and WRCLK
.DEVICE                  ("7SERIES"),
   
.FIRST_WORD_FALL_THROUGH ("TRUE")                             
)
ff_interd_from_mem
( 
.RST        (net_rst), 
.WRCLK      (mem_clk), 
.RDCLK      (net_clk),    

.WREN       (r0_en),
.DI         ({7'd0, r0_data_end, r0_data}),
.FULL       (r0_full),
.WRCOUNT    (r0_wr_cnt),   
.WRERR      (r0_wr_err),
.ALMOSTFULL (r0_wr_af),
                        
.RDEN       (r1_ack),
.EMPTY      (r1_empty),
.ALMOSTEMPTY(), 
.RDCOUNT    (r1_rd_cnt), 
.RDERR      (r1_rd_err),
.DO         ({r1_data_zero_unused, r1_data_end, r1_data})
);
/*
FIFO_X7_512x72_SlowToFast ff_interd_from_mem
(   
.rst      (rst), 
.wr_clk   (mem_clk), 
.rd_clk   (net_clk),    

.wr_en    (r0_en),
.din      ({r0_data_end, r0_data}),
.full     (),  

//.valid    (r1_stb),
.rd_en    (r1_ack),  
.empty    (r1_empty),
.prog_empty(r1_7OrLess),
.dout     ({r1_data_end, r1_data})
);  */               
//---------------------------------------------------------------------------------------------
assign  r1_stb = !r1_empty;                                      
// burst size deppends on alignment and interface width. If interface is 16 bit and Xilinx IP
// Core requires data in 128-bits bursts and the same 128-bit alignment. 
// If input address is not proper aligned than we need to add one  64-bites filler word as 
// a first word and one 64-bites filler word at the end to obtain 128-bit aligned operations.
// For a wider interface of 256 bits tis allignement should be 256-bit also and (1-3)x64-bit 
// words should be added
                                                                                                
//---------------------------------------------------------------------------------------------
assign  r1_pkt_en     =                         (pf_state == PF_WAIT) && r1_h_stb && r3_rdy[1]; 
assign  r1_h_header   =                                                       r1_h_data[71: 0];
assign  r1_pkt_rd_en  =                                r1_pkt_en & (r1_h_header[1:0] != 2'b10); 
assign  r1_pkt_wr_en  =       (SEND_WR_FB == "TRUE") & r1_pkt_en & (r1_h_header[1:0] == 2'b10); 
assign  r1_h_pre      =                                                       r1_h_data[74:72];
assign  r1_h_not_alig =                                                       r1_h_data   [75]; 

//=============================================================================================
// packet formater - network clock domain
//=============================================================================================
localparam  PF_WAIT   = 1;   
localparam  PF_HEADER = 2; 
localparam  PF_BURST  = 4;
localparam  PF_PL     = 8;
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst)
 if(net_rst)                            pf_state   <=                                  PF_WAIT;
 else case(pf_state)                                  
 PF_WAIT:   if(r1_pkt_en              ) pf_state   <=                                PF_HEADER; 
       else                             pf_state   <=                                  PF_WAIT;     
 PF_HEADER: if(r2_pkt_wr_en           ) pf_state   <=                                    PF_PL; 
       else                             pf_state   <=                                 PF_BURST; 
 PF_BURST:  if(r2_data_lst_f          ) pf_state   <=                                  PF_WAIT; 
       else                             pf_state   <=                                 PF_BURST; 
 PF_PL:     if(r2_wr_res_lst_f        ) pf_state   <=                                  PF_WAIT; 
       else                             pf_state   <=                                    PF_PL;       
 endcase                                                                                     
//--------------------------------------------------------------------------------------------- 
always@(posedge net_clk or posedge net_rst)
if(net_rst)                       r2_pkt_wr_en        <=                                  1'b0;
else                              r2_pkt_wr_en        <=                          r1_pkt_wr_en;  
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst)
  if(net_rst)                     r2_data_sof_sr      <=                                   'b0;
  else if(r1_pkt_rd_en         )  r2_data_sof_sr      <=                       'b00000000000000001;
  else if(r1_pkt_wr_en         )  r2_data_sof_sr      <=                       'b00000000000000000;
  else if(!r1_empty            )  r2_data_sof_sr      <=                     r2_data_sof_sr>>1;
  else                            r2_data_sof_sr      <=                     r2_data_sof_sr   ;
//---------------------------------------------------------------------------------------------
assign r2_data_sof_f =                                           r2_data_sof_sr[0] & !r1_empty;
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst)
  if(net_rst)                     r2_data_lst_sr      <=                                   'b0;
  else if(r1_pkt_wr_en         )  r2_data_lst_sr      <=                       'b00000000000000000;
  else if(r1_pkt_rd_en         )  r2_data_lst_sr      <= (!r1_h_not_alig   )?  'b00000000100000000:
                                                         ( r1_h_pre == 3'd1)?  'b10000000000000000:
                                                         ( r1_h_pre == 3'd2)?  'b10000000000000000:
                                                         ( r1_h_pre == 3'd3)?  'b10000000000000000:
                                                         ( r1_h_pre == 3'd4)?  'b10000000000000000:
                                                         ( r1_h_pre == 3'd5)?  'b10000000000000000:
                                                         ( r1_h_pre == 3'd6)?  'b10000000000000000:
                                                       /*( r1_h_pre == 3'd7)?*/'b10000000000000000;
  else if(!r1_empty            )  r2_data_lst_sr      <=                     r2_data_lst_sr>>1;
  else                            r2_data_lst_sr      <=                     r2_data_lst_sr   ;
//---------------------------------------------------------------------------------------------
assign r2_data_lst_f =                                           r2_data_lst_sr[0] & !r1_empty;
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst)
  if(net_rst)                     r2_data_ack_sr      <=                                   'b0;
  else if(r1_pkt_wr_en         )  r2_data_ack_sr      <=                       'b00000000000000000;
  else if(r1_pkt_rd_en         )  r2_data_ack_sr      <= (!r1_h_not_alig   )?  'b00000000111111110:
                                                         ( r1_h_pre == 3'd1)?  'b11111111111111110:
                                                         ( r1_h_pre == 3'd2)?  'b11111111111111110:
                                                         ( r1_h_pre == 3'd3)?  'b11111111111111110:
                                                         ( r1_h_pre == 3'd4)?  'b11111111111111110:
                                                         ( r1_h_pre == 3'd5)?  'b11111111111111110:
                                                         ( r1_h_pre == 3'd6)?  'b11111111111111110:
                                                       /*( r1_h_pre == 3'd7)?*/'b11111111111111110;  
  else if(!r1_empty            )  r2_data_ack_sr      <=                     r2_data_ack_sr>>1;
  else                            r2_data_ack_sr      <=                     r2_data_ack_sr   ; 
//---------------------------------------------------------------------------------------------
assign r2_data_ack_f =                                           r2_data_ack_sr[0] & !r1_empty;
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst)
  if(net_rst)                     r2_data_out_sr      <=                                   'b0;
  else if(r1_pkt_wr_en         )  r2_data_out_sr      <=                       'b00000000000000000;
  else if(r1_pkt_rd_en         )  r2_data_out_sr      <= (!r1_h_not_alig   )?  'b00000000111111110:
                                                         ( r1_h_pre == 3'd1)?  'b00000001111111100:
                                                         ( r1_h_pre == 3'd2)?  'b00000011111111000:
                                                         ( r1_h_pre == 3'd3)?  'b00000111111110000:
                                                         ( r1_h_pre == 3'd4)?  'b00001111111100000:
                                                         ( r1_h_pre == 3'd5)?  'b00011111111000000:
                                                         ( r1_h_pre == 3'd6)?  'b00111111110000000:
                                                       /*( r1_h_pre == 3'd7)?*/'b01111111100000000; 
  else if(!r1_empty            )  r2_data_out_sr      <=                     r2_data_out_sr>>1;
  else                            r2_data_out_sr      <=                     r2_data_out_sr   ;
//---------------------------------------------------------------------------------------------
assign r2_data_out_f =                                           r2_data_out_sr[0] & !r1_empty;   
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst)
  if(net_rst)                     r2_wr_res_sof_sr    <=                                   'b0;
  else if(r1_pkt_rd_en         )  r2_wr_res_sof_sr    <=                                 'b000;
  else if(r1_pkt_wr_en         )  r2_wr_res_sof_sr    <=                                 'b001;
  else if(r1_wr_res_stb        )  r2_wr_res_sof_sr    <=                   r2_wr_res_sof_sr>>1;
  else                            r2_wr_res_sof_sr    <=                   r2_wr_res_sof_sr   ;
//---------------------------------------------------------------------------------------------
assign r2_wr_res_sof_f =                                   r2_wr_res_sof_sr[0] & r1_wr_res_stb;
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst)
  if(net_rst)                     r2_wr_res_fill_sr   <=                                 'b000;
  else if(r1_pkt_wr_en         )  r2_wr_res_fill_sr   <= ( r1_h_not_alig   )?            'b110:
                                                                                         'b010;  
  else if(r1_wr_res_stb        )  r2_wr_res_fill_sr   <=                  r2_wr_res_fill_sr>>1;
  else                            r2_wr_res_fill_sr   <=                  r2_wr_res_fill_sr   ;
//---------------------------------------------------------------------------------------------
assign r2_wr_res_fill_f  =                                r2_wr_res_fill_sr[0] & r1_wr_res_stb; 
assign r1_wr_res_ack =                                                        r2_wr_res_fill_f;
assign r2_wr_res_lst_f =                        (r2_wr_res_fill_sr[1] == 1'b0) & r1_wr_res_stb;
//=============================================================================================
// mux
//=============================================================================================                                                                     
always@(posedge net_clk or posedge net_rst)
 if(net_rst) r3_en           <=                                                           1'd0;
 else        r3_en           <= r2_data_sof_f || r2_data_out_f || r2_wr_res_sof_f || r2_wr_res_fill_f;  
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst)
 if(net_rst) r3_sof          <=                                                           1'd0;
 else        r3_sof          <=                               r2_wr_res_sof_f || r2_data_sof_f;  
//---------------------------------------------------------------------------------------------
always@(posedge net_clk)                                                                        
     if(r2_wr_res_sof_f) r3_data  <= {2'b10, r1_h_header[69:40], 1'b0/*L*/, r1_h_header[38:0]};
else if(r2_data_sof_f  ) r3_data  <= {2'b10, r1_h_header[69:40], 1'b1/*L*/, r1_h_header[38:0]}; 
else if(r2_data_out_f  ) r3_data  <=                                    {8'hFF, r1_data[63:0]}; 
else /*r2_wr_res_fill_f*/r3_data  <=                                    {8'h00,         72'd0};   
//---------------------------------------------------------------------------------------------
assign    r1_ack  =                                                              r2_data_ack_f;
assign    r1_h_ack=                                                                     r3_sof; 
//=============================================================================================
ff_dram_rdy_d32 
#(
.PKT_LEN0   ('d2),
.PKT_LEN1   ('d9),
.WIDTH      ('d72) // width of i_data
)
o_solid_pkt_ff 
(
.clk        (net_clk),
.rst        (net_rst),

.i_stb      (r3_en),
.i_sof      (r3_sof),
.i_data     (r3_data),
.i_rdy      (r3_rdy),
.i_full     (r3_full),

.o_stb      (o_stb),
.o_sof      (o_sof),
.o_data     (o_data),
.o_rdy      (o_rdy), 

.i_err      (r3_wr_err),
.o_err      (r4_rd_err)
);  
//============================================================================================= 
always@(posedge net_clk or posedge net_rst)
 if(net_rst)                        o_ff_err       <=                                     1'd0;
 else if(r1_h_err                )  o_ff_err       <=                                     1'd1;
 else if(r0_wr_err  || r1_rd_err )  o_ff_err       <=                                     1'd1;/*r0_wr_err in mem_clk domain but constant*/  
 else if(r3_wr_err  || r4_rd_err )  o_ff_err       <=                                     1'd1;
 else                               o_ff_err       <=                                 o_ff_err;
//---------------------------------------------------------------------------------------------
assign dbg = {i_dff_err, x_ff_err, ffh_i_err, ftm_i_werr, ftm_o_rerr, t1_ff_werr, t2_ff_rerr, r1_h_err, r0_wr_err, r1_rd_err};
//---------------------------------------------------------------------------------------------
always@(posedge net_clk or posedge net_rst)
 if(net_rst)                        o_dbg_err       <=                                    3'd0;
 else if(r1_h_err                )  o_dbg_err       <=                      o_dbg_err | 3'b001;
 else if(r0_wr_err               )  o_dbg_err       <=                      o_dbg_err | 3'b010;/*r0_wr_err in mem_clk domain but constant*/
 else if(            r1_rd_err   )  o_dbg_err       <=                      o_dbg_err | 3'b100;
 else                               o_dbg_err       <=                               o_dbg_err;
//=============================================================================================      
endmodule
