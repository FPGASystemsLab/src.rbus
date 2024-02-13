//============================================================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
// Description:
//  Module detect wr/rd requests that cross allowed border and change them to prevent this situation. Requests crossing the 
// address border are transformed into two requests: one for data below the border address, and one above the border address.
// For write operations also additional data are generated to fill initial words of a first packets and closing words of 
// a second packet.
//============================================================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//============================================================================================================================
module rbus_mif64_binj  
#(
parameter [38:0] BURST_BORDER = 1024*1024*4 // read/write burst should not cross border of 4KB
) 
(
 input  wire            clk,
 input  wire            rst,   

 input  wire            i_stb,
 input  wire    [71:0]  i_data,
 output wire            i_ack,

 output wire            o_en,
 output wire            o_cr_en,
 output wire            o_cw_en,
 output wire            o_d_en,
 output wire    [63:0]  o_data,
 output wire    [ 7:0]  o_mask,
 output wire            o_d_lst,
 input  wire     [1:0]  o_rdy
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
integer     next_state; 
integer     state;
//---------------------------------------------------------------------------------------------
localparam  ST_WAIT       = 'b0000000000001;
localparam  ST_HDR_RD_X1  = 'b0000000000010;
localparam  ST_HDR_RD_X2  = 'b0000000000100;
localparam  ST_HDR_RD     = 'b0000000001000;
localparam  ST_HDR_WR_X1  = 'b0000000010000;
localparam  ST_DAT_WR_X1F = 'b0000000100000;
localparam  ST_DAT_WR_X1D = 'b0000001000000;
localparam  ST_HDR_X_WAIT = 'b0000010000000;
localparam  ST_HDR_WR_X2  = 'b0000100000000;
localparam  ST_DAT_WR_X2D = 'b0001000000000;
localparam  ST_DAT_WR_X2F = 'b0010000000000;
localparam  ST_HDR_WR     = 'b0100000000000;
localparam  ST_DAT_WR_D   = 'b1000000000000;
//---------------------------------------------------------------------------------------------
wire        ns_wait       = next_state == ST_WAIT      ;
wire        ns_hdr_rd_x1  = next_state == ST_HDR_RD_X1 ;
wire        ns_hdr_rd_x2  = next_state == ST_HDR_RD_X2 ;
wire        ns_hdr_rd     = next_state == ST_HDR_RD    ;
wire        ns_hdr_wr_x1  = next_state == ST_HDR_WR_X1 ;
wire        ns_dat_wr_x1f = next_state == ST_DAT_WR_X1F;
wire        ns_dat_wr_x1d = next_state == ST_DAT_WR_X1D;
wire        ns_hdr_x_wait = next_state == ST_HDR_X_WAIT;
wire        ns_hdr_wr_x2  = next_state == ST_HDR_WR_X2 ;
wire        ns_dat_wr_x2d = next_state == ST_DAT_WR_X2D;
wire        ns_dat_wr_x2f = next_state == ST_DAT_WR_X2F;
wire        ns_hdr_wr     = next_state == ST_HDR_WR    ;
wire        ns_dat_wr_d   = next_state == ST_DAT_WR_D  ;
//---------------------------------------------------------------------------------------------
wire        s_wait       =       state == ST_WAIT      ;
wire        s_hdr_rd_x1  =       state == ST_HDR_RD_X1 ;
wire        s_hdr_rd_x2  =       state == ST_HDR_RD_X2 ;
wire        s_hdr_rd     =       state == ST_HDR_RD    ;
wire        s_hdr_wr_x1  =       state == ST_HDR_WR_X1 ;
wire        s_dat_wr_x1f =       state == ST_DAT_WR_X1F;
wire        s_dat_wr_x1d =       state == ST_DAT_WR_X1D;
wire        s_hdr_x_wait =       state == ST_HDR_X_WAIT;
wire        s_hdr_wr_x2  =       state == ST_HDR_WR_X2 ;
wire        s_dat_wr_x2d =       state == ST_DAT_WR_X2D;
wire        s_dat_wr_x2f =       state == ST_DAT_WR_X2F;
wire        s_hdr_wr     =       state == ST_HDR_WR    ;
wire        s_dat_wr_d   =       state == ST_DAT_WR_D  ;
//---------------------------------------------------------------------------------------------
wire [ 1:0] s0_mode;
   
wire        s0_len;
wire        s0_rd1; 
wire        s0_rd8;
wire        s0_wra; 
wire        s0_upda;
wire        s0_rd_len;

wire        s0_f_hrd; 
wire        s0_f_hwr; 
wire        s0_rd_wr;

wire        s0_hi_bits_border_f;
wire        s0_lo_bits_border_f;          
wire        s0_crossing_f; 
wire  [3:0] s0_pre_num; // number of words to insert at a beginning of a first packet
wire  [3:0] s0_pst_num; // number of words to insert at an end of a second packet
//---------------------------------------------------------------------------------------------
reg   [3:0] s0_pkt_dcnt; 
wire        s0_sof;
reg         s1_new_dat_f;
reg  [71:0] s1_data;
reg         s1_dat_valid; 
wire        s1_dat_rdy;
reg         s1_crossing_f; 
reg   [3:0] s1_pre_num; // number of words to insert at a beginning of a first packet
reg   [3:0] s1_pst_num; // number of words to insert at an end of a second packet

reg         s1_f_hrd; 
reg         s1_f_hwr; 

reg         s1_rdx_f;
reg         s1_rd_f ;
reg         s1_wrx_f;
reg         s1_wr_f ; 
wire        s1_rdx_ena;
wire        s1_rd_ena ;
wire        s1_wrx_ena;
wire        s1_wr_ena ; 
//---------------------------------------------------------------------------------------------
reg         s2_rdy;
reg         s2_cr_en;
reg         s2_cw_en;
reg         s2_d_en;
reg  [71:0] s2_data;
reg  [38:0] s2_addr;
reg         s2_crossing_f; 
reg  [ 3:0] s2_dat_dcnt;
wire        s2_dat_lst;
reg   [3:0] s2_pre_dcnt; // number of words to insert at a beginning of a first packet
wire        s2_pre_lst;
reg   [3:0] s2_pst_dcnt; // number of words to insert at an end of a second packet
wire        s2_pst_lst;
//---------------------------------------------------------------------------------------------
reg         s3_en;        
reg         s3_cr_en;
reg         s3_cw_en;
reg         s3_d_en; 
reg  [71:0] s3_data;
reg         s3_dat_lst;  
//=============================================================================================
assign      s0_mode      =                                                         i_data[1:0];
                        
assign      s0_len       =                                                          i_data[39];
assign      s0_rd1       =                                                i_data[1:0] == 2'b00; 
assign      s0_rd8       =                                                i_data[1:0] == 2'b01;
assign      s0_wra       =                                                i_data[1:0] == 2'b10; 
assign      s0_upda      =                                                i_data[1:0] == 2'b11;
assign      s0_rd_len    =                                         s0_rd8 | (s0_upda & s0_len);
              
assign      s0_f_hwr     =                                               (s0_wra/*| s0_upda*/);  
assign      s0_f_hrd     =                                         (s0_rd1 | s0_rd8 | s0_upda);
assign      s0_rd_wr     =                                                             s0_upda; 
 
assign s0_hi_bits_border_f =     (BURST_BORDER_HI_MASK & i_data[38:0]) == BURST_BORDER_HI_MASK;
assign s0_lo_bits_border_f =     (BURST_BORDER_LO_MASK & i_data[38:0]) !=                39'd0;
assign s0_crossing_f       =                         s0_hi_bits_border_f & s0_lo_bits_border_f; 

//---------------------------------------------------------------------------------------------
assign s0_pre_num =        (i_data[5:3]==3'd0)?                                    4'd0 - 4'd1: 
                           (i_data[5:3]==3'd1)?                                    4'd1 - 4'd1:
                           (i_data[5:3]==3'd2)?                                    4'd2 - 4'd1:
                           (i_data[5:3]==3'd3)?                                    4'd3 - 4'd1:
                           (i_data[5:3]==3'd4)?                                    4'd4 - 4'd1:
                           (i_data[5:3]==3'd5)?                                    4'd5 - 4'd1:
                           (i_data[5:3]==3'd6)?                                    4'd6 - 4'd1:
                         /*(i_data[5:3]==3'd7)?*/                                  4'd7 - 4'd1;
assign s0_pst_num =        (i_data[5:3]==3'd0)?                                    4'd0 - 4'd1: 
                           (i_data[5:3]==3'd1)?                                    4'd7 - 4'd1:
                           (i_data[5:3]==3'd2)?                                    4'd6 - 4'd1:
                           (i_data[5:3]==3'd3)?                                    4'd5 - 4'd1:
                           (i_data[5:3]==3'd4)?                                    4'd4 - 4'd1:
                           (i_data[5:3]==3'd5)?                                    4'd3 - 4'd1:
                           (i_data[5:3]==3'd6)?                                    4'd2 - 4'd1:
                         /*(i_data[5:3]==3'd7)?*/                                  4'd1 - 4'd1;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
if(rst)                                s0_pkt_dcnt     <=                                 4'hF;
else if( s0_sof     & i_ack          ) s0_pkt_dcnt     <= (s0_f_hwr)?              4'd7 : 4'hF;  
else if(!s0_sof     & i_ack          ) s0_pkt_dcnt     <=                   s0_pkt_dcnt - 4'd1; 
else                                   s0_pkt_dcnt     <=                   s0_pkt_dcnt       ; 
//---------------------------------------------------------------------------------------------
assign s0_sof =                                                                 s0_pkt_dcnt[3];
//=============================================================================================
always@(posedge clk) if(i_ack)         s1_crossing_f   <=                        s0_crossing_f;
always@(posedge clk) if(i_ack)         s1_pre_num      <=                        s0_pre_num   ;
always@(posedge clk) if(i_ack)         s1_pst_num      <=                        s0_pst_num   ;
always@(posedge clk) if(i_ack)         s1_f_hwr        <=                        s0_f_hwr     ;
always@(posedge clk) if(i_ack)         s1_f_hrd        <=                        s0_f_hrd     ;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst) 
     if(rst             )              s1_rdx_f        <=                                 1'b0;
else if(i_ack           )              s1_rdx_f        <=   s0_sof & s0_f_hrd &  s0_crossing_f;
else if(s_wait &o_rdy[0])              s1_rdx_f        <=                                 1'b0;
else                                   s1_rdx_f        <=                         s1_rdx_f    ;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst) 
     if(rst             )              s1_rd_f         <=                                 1'b0;
else if(i_ack           )              s1_rd_f         <=   s0_sof & s0_f_hrd & !s0_crossing_f;
else if(s_wait &o_rdy[0])              s1_rd_f         <=                                 1'b0;
else                                   s1_rd_f         <=                         s1_rd_f     ;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst) 
     if(rst             )              s1_wrx_f        <=                                 1'b0;
else if(i_ack           )              s1_wrx_f        <=   s0_sof & s0_f_hwr &  s0_crossing_f;
else if(s_wait &o_rdy[1])              s1_wrx_f        <=                                 1'b0;
else                                   s1_wrx_f        <=                         s1_wrx_f    ;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst) 
     if(rst             )              s1_wr_f         <=                                 1'b0;
else if(i_ack           )              s1_wr_f         <=   s0_sof & s0_f_hwr & !s0_crossing_f;
else if(s_wait &o_rdy[1])              s1_wr_f         <=                                 1'b0;
else                                   s1_wr_f         <=                         s1_wr_f     ;
//---------------------------------------------------------------------------------------------
assign s1_rdx_ena =                                                        s1_rdx_f & o_rdy[0];
assign s1_rd_ena  =                                                        s1_rd_f  & o_rdy[0];
assign s1_wrx_ena =                                                        s1_wrx_f & o_rdy[1];
assign s1_wr_ena  =                                                        s1_wr_f  & o_rdy[1];
//---------------------------------------------------------------------------------------------
always@(posedge clk) 
     if(i_ack           )              s1_data         <=                               i_data;
else                                   s1_data         <=                              s1_data;
//---------------------------------------------------------------------------------------------
always@(posedge clk) 
     if(i_ack           )              s1_new_dat_f    <=                                 1'b1;
else                                   s1_new_dat_f    <=                                 1'b0;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst) 
     if(rst             )              s1_dat_valid    <=                                 1'b0;
else if(i_ack           )              s1_dat_valid    <=                                 1'b1;
else if(s1_dat_rdy      )              s1_dat_valid    <=                                 1'b0;
else                                   s1_dat_valid    <=                         s1_dat_valid;
//---------------------------------------------------------------------------------------------
//assign s1_dat_rdy =                               s_dat_wr_x1d |  s_dat_wr_x2d |  s_dat_wr_d |  // zapis danych
//                                            s_hdr_rd |  s_hdr_wr |  s_hdr_rd_x1 |  s_hdr_wr_x1; // zapis naglowkow
assign s1_dat_rdy =                             ns_dat_wr_x1d |  ns_dat_wr_x2d |  ns_dat_wr_d |  // zapis danych
                                        ns_hdr_rd |  ns_hdr_wr |  ns_hdr_rd_x1 |  ns_hdr_wr_x1; // zapis naglowkow
//---------------------------------------------------------------------------------------------
assign i_ack =                                          i_stb && (!s1_dat_valid || s1_dat_rdy); 
//=============================================================================================
always@(*)                                        
 if(rst)                        next_state   <=                                  ST_WAIT      ;
 else case(state)                                 
 ST_WAIT:     if(s1_rdx_ena)    next_state   <=                                  ST_HDR_RD_X1 ; 
         else if(s1_rd_ena )    next_state   <=                                  ST_HDR_RD    ; 
         else if(s1_wrx_ena)    next_state   <=                                  ST_HDR_WR_X1 ; 
         else if(s1_wr_ena )    next_state   <=                                  ST_HDR_WR    ;   
         else                   next_state   <=                                  ST_WAIT      ;  
         
 ST_HDR_RD_X1:                  next_state   <=                                  ST_HDR_RD_X2 ; 
 ST_HDR_RD_X2:                  next_state   <=                                  ST_WAIT      ;
 ST_HDR_RD:                     next_state   <=                                  ST_WAIT      ;
                                                  
 ST_HDR_WR_X1:                  next_state   <=                                  ST_DAT_WR_X1F;
 ST_DAT_WR_X1F:if(s2_pre_lst   )next_state   <=                                  ST_DAT_WR_X1D;  
         else                   next_state   <=                                  ST_DAT_WR_X1F; 
 ST_DAT_WR_X1D:if(s2_dat_lst   )next_state   <= (!s2_d_en)? state :              ST_HDR_X_WAIT;
         else                   next_state   <=                                  ST_DAT_WR_X1D;
                                                  
 ST_HDR_X_WAIT:if(o_rdy[1]     )next_state   <=                                  ST_HDR_WR_X2 ;
         else                   next_state   <=                                  ST_HDR_X_WAIT;
                                                  
 ST_HDR_WR_X2:                  next_state   <=                                  ST_DAT_WR_X2D; 
 ST_DAT_WR_X2D:if(s2_dat_lst   )next_state   <= (!s2_d_en)? state :              ST_DAT_WR_X2F;
         else                   next_state   <=                                  ST_DAT_WR_X2D;
 ST_DAT_WR_X2F:if(s2_pst_lst   )next_state   <=                                  ST_WAIT      ;  
         else                   next_state   <=                                  ST_DAT_WR_X2F;
                                                  
 ST_HDR_WR:                     next_state   <=                                  ST_DAT_WR_D  ;
 ST_DAT_WR_D:  if(s2_dat_lst   )next_state   <= (!s2_d_en)? state :              ST_WAIT      ;
         else                   next_state   <=                                  ST_DAT_WR_D  ;    
 endcase                                                                                         
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
if(rst)                              state   <=                                        ST_WAIT;
else                                 state   <=                                     next_state;
//=============================================================================================
always@(posedge clk or posedge rst)
     if(rst          ) s2_rdy        <=                                                   1'b0; 
else                   s2_rdy        <=                                                   1'b1;
//---------------------------------------------------------------------------------------------
always@(posedge clk)
     if(ns_hdr_rd    ) s2_cr_en      <=                                                   1'b1; 
else if(ns_hdr_rd_x1 ) s2_cr_en      <=                                                   1'b1; 
else if(ns_hdr_rd_x2 ) s2_cr_en      <=                                                   1'b1; 
else                   s2_cr_en      <=                                                   1'b0; 
//---------------------------------------------------------------------------------------------
always@(posedge clk)
     if(ns_hdr_wr    ) s2_cw_en      <=                                                   1'b1; 
else if(ns_hdr_wr_x1 ) s2_cw_en      <=                                                   1'b1;  
else if(ns_hdr_wr_x2 ) s2_cw_en      <=                                                   1'b1; 
else                   s2_cw_en      <=                                                   1'b0; 
//---------------------------------------------------------------------------------------------
always@(posedge clk)
     if(ns_dat_wr_x1f) s2_d_en       <=                                                   1'b1;
else if(ns_dat_wr_x2f) s2_d_en       <=                                                   1'b1;  
else if(ns_dat_wr_x1d) s2_d_en       <=                                           s1_dat_valid;  
else if(ns_dat_wr_x2d) s2_d_en       <=                                           s1_dat_valid;  
else if(ns_dat_wr_d  ) s2_d_en       <=                                           s1_dat_valid; 
else                   s2_d_en       <=                                                   1'b0; 
//---------------------------------------------------------------------------------------------
always@(posedge clk)
     if(ns_hdr_rd    ) s2_addr <= s1_data[38:0]                                               ; 
else if(ns_hdr_wr    ) s2_addr <= s1_data[38:0]                                               ; 
else if(ns_hdr_rd_x1 ) s2_addr <= s1_data[38:0] &                      (~BURST_BORDER_LO_MASK); 
else if(ns_hdr_wr_x1 ) s2_addr <= s1_data[38:0] &                      (~BURST_BORDER_LO_MASK); 
else if(ns_hdr_rd_x2 ) s2_addr <= s2_addr[38:0] +                                         'd64; 
else if(ns_hdr_wr_x2 ) s2_addr <= s2_addr[38:0] +                                         'd64; 
else                   s2_addr <= s2_addr[38:0]                                               ; 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)                                                                            
     if(ns_dat_wr_x1f) s2_data       <=                         {8'h00, 64'hxxxxxxxx_xxxxxxxx}; 
else if(ns_dat_wr_x2f) s2_data       <=                         {8'h00, 64'hxxxxxxxx_xxxxxxxx};
else if(ns_dat_wr_x1d) s2_data       <=                                          s1_data[71:0]; 
else if(ns_dat_wr_x2d) s2_data       <=                                          s1_data[71:0];  
else if(ns_dat_wr_d  ) s2_data       <=                                          s1_data[71:0];  
else                   s2_data       <=                                          s2_data[71:0]; 
//---------------------------------------------------------------------------------------------
always@(posedge clk)
     if( s_wait      ) s2_crossing_f <=                                          s1_crossing_f; 
else                   s2_crossing_f <=                                          s2_crossing_f;
//---------------------------------------------------------------------------------------------
always@(posedge clk)
     if(ns_hdr_wr_x1 ) s2_dat_dcnt   <=                                                    'd6;  
else if(ns_hdr_wr_x2 ) s2_dat_dcnt   <=                                'd8 - s2_pst_dcnt - 'd3;   
else if(ns_hdr_wr    ) s2_dat_dcnt   <=                                                    'd6;  
//else if(ns_dat_wr_x1f) s2_dat_dcnt   <=                             s2_dat_dcnt -         1'b1;   
//else if(ns_dat_wr_x1d) s2_dat_dcnt   <=                             s2_dat_dcnt - s1_dat_valid;   
//else if(ns_dat_wr_x2d) s2_dat_dcnt   <=                             s2_dat_dcnt - s1_dat_valid;   
//else if(ns_dat_wr_x2f) s2_dat_dcnt   <=                             s2_dat_dcnt -         1'b1;   
//else if(ns_dat_wr_d  ) s2_dat_dcnt   <=                             s2_dat_dcnt - s1_dat_valid;   
else                   s2_dat_dcnt   <=                             s2_dat_dcnt - s2_d_en     ;
//---------------------------------------------------------------------------------------------
assign s2_dat_lst =                                                             s2_dat_dcnt[3];
//---------------------------------------------------------------------------------------------
always@(posedge clk)
     if(ns_hdr_wr_x1 ) s2_pre_dcnt   <=                                             s1_pre_num;  
else if(ns_dat_wr_x1f) s2_pre_dcnt   <=                             s2_pre_dcnt -          'd1;   
else                   s2_pre_dcnt   <=                             s2_pre_dcnt               ;
//---------------------------------------------------------------------------------------------
assign s2_pre_lst =                                                             s2_pre_dcnt[3]; 
//---------------------------------------------------------------------------------------------
always@(posedge clk)                 
     if(ns_hdr_wr_x1 ) s2_pst_dcnt   <=                                             s1_pst_num;  
else if(ns_dat_wr_x2f) s2_pst_dcnt   <=                             s2_pst_dcnt -          'd1;  
else                   s2_pst_dcnt   <=                             s2_pst_dcnt               ;
//---------------------------------------------------------------------------------------------
assign s2_pst_lst =                                                             s2_pst_dcnt[3]; 
//=============================================================================================
always@(posedge clk)
     if( s2_cr_en    ) s3_data       <=                                 {33'd0, s2_addr[38:0]};
else if( s2_cw_en    ) s3_data       <=                                 {33'd0, s2_addr[38:0]};
else if( s2_d_en     ) s3_data       <=                                                s2_data; 
else                   s3_data       <=                                                s3_data; 
//---------------------------------------------------------------------------------------------
always@(posedge clk)   s3_dat_lst    <= (s_dat_wr_x2f              )?        s2_pst_lst       : 
                                        (s_dat_wr_d || s_dat_wr_x1d)?        s2_dat_lst : 1'b0; 
always@(posedge clk)   s3_cr_en      <=                                               s2_cr_en; 
always@(posedge clk)   s3_cw_en      <=                                               s2_cw_en; 
always@(posedge clk)   s3_d_en       <=                                                s2_d_en; 
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
     if(rst          ) s3_en         <=                                                   1'b0; 
else                   s3_en         <=            s2_rdy && (s2_cw_en || s2_cr_en || s2_d_en);  
//=============================================================================================
assign o_en    =                                                                      s3_en   ;
assign o_cr_en =                                                                      s3_cr_en;
assign o_cw_en =                                                                      s3_cw_en;
assign o_d_en  =                                                                      s3_d_en ;
assign o_data  =                                                                s3_data[63: 0];
assign o_mask  =                                                               ~s3_data[71:64]; 
assign o_d_lst =                                                                    s3_dat_lst;
//=============================================================================================
endmodule












