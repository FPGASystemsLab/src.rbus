//============================================================================================================================
//    Main contributors
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//============================================================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//============================================================================================================================
module rbus_mif64
#(
 parameter RBUS_WR_ACK = 1'b0
)
(
 input  wire            clk,
 input  wire            rst,   

 input  wire            i_stb,
 input  wire            i_sof,
 input  wire    [71:0]  i_data,
 output wire     [1:0]  i_rdy,

 output wire            o_stb,
 output wire            o_sof,
 output wire    [71:0]  o_data,
 input  wire     [1:0]  o_rdy,
 
 output wire            co_stb,
 output wire     [2:0]  co_cmd,
 output wire     [2:0]  co_bl,
 output wire    [38:0]  co_addr,
 input  wire            co_full,

 output wire            do_stb,
 output wire     [7:0]  do_mask,
 output wire    [63:0]  do_data,
 input  wire     [6:0]  do_cnt, // long latency write fifo words counter
 
 input  wire            di_stb,
 input  wire    [63:0]  di_data,
 output wire            di_ack
);                              
//=============================================================================================
// variables
//=============================================================================================
localparam  IF_WAIT     = 0;
localparam  IF_BURST_WR = 1;
localparam  IF_BURST_RD = 2;
localparam  IF_SKIP     = 3;
localparam  IF_ERROR    = 4;
//---------------------------------------------------------------------------------------------
integer     if_state;
//---------------------------------------------------------------------------------------------
wire         x_stb;
wire         x_sof;
wire [71:0]  x_data;
wire         x_ack;
                    
reg   [3:0]  if_psize;
reg   [3:0]  if_burst;
reg  [71:0]  if_header;
reg          if_header_f;     

reg          if_c_stb;
reg   [2:0]  if_c_cmd;
reg   [2:0]  if_c_bl;
reg  [38:0]  if_c_addr;
reg          if_c_hpass;
wire         if_c_hf;

reg          if_d_stb;
reg   [7:0]  if_d_mask;
reg  [63:0]  if_d_data;

reg          if_wr_end; 
wire         if_wr_done_stb; 
            
reg   [7:0]  di_cnt;
//---------------------------------------------------------------------------------------------
wire         h_stb;
wire [71:0]  h_header;
wire         h_ack;
//---------------------------------------------------------------------------------------------
integer      pf_state;
//---------------------------------------------------------------------------------------------
wire         s0_bf_ack;
wire         s0_hd_ack;   
reg          s0_sof;
reg          s0_stb;
reg          s0_inc;
reg          s0_lst;
reg   [3:0]  s0_burst;
reg   [7:0]  s0_ben;
reg  [71:0]  s0_data;
//---------------------------------------------------------------------------------------------
wire         s1_sof;
wire         s1_len;
wire         s1_lst;
wire [71:0]  s1_data;
reg   [5:0]  s1_pcnt;  
reg          s1_pending;
wire         s1_rdy;
wire         s1_f2;
wire         s1_f9;  
wire         s1_dec;  
//---------------------------------------------------------------------------------------------         
reg          o_ff_rdy;
//---------------------------------------------------------------------------------------------   
wire         wr_done_stb; 
wire         wr_done_ack;
//---------------------------------------------------------------------------------------------
rbus_dff dff
(
.clk      (clk),     
.rst      (rst),   

.i_stb    (i_stb),
.i_sof    (i_sof),
.i_data   (i_data),
.i_rdy    (i_rdy), 
.i_err    (),    

.o_stb    (x_stb), 
.o_sof    (x_sof),
.o_data   (x_data),
.o_ack    (x_ack), 
.o_err    ()
);  
//=============================================================================================
// memory interface state machine
//=============================================================================================
wire [1:0]  f_mode      =                                                          x_data[1:0];

wire        f_len       =                                                           x_data[39];
wire        f_rd1       =                                                 x_data[1:0] == 2'b00; 
wire        f_rd8       =                                                 x_data[1:0] == 2'b01;
wire        f_wra       =                                                 x_data[1:0] == 2'b10; 
wire        f_upda      =                                                 x_data[1:0] == 2'b11;
wire        f_rd_len    =                                             f_rd8 | (f_upda & f_len);

//wire        f_wr        =                                                     (f_wra | f_upda);
wire        f_wr        =                                                      f_wra          ;  
wire        f_rd        =                                             (f_rd1 | f_rd8 | f_upda);
wire        f_rd_wr     =                                                              f_upda ;  
wire        f_op_len    =                           f_rd8 | (f_upda & f_len) | (f_wra & f_len);
  
wire [3:0]  f_burst     = (f_op_len  )?                                            4'd8 : 4'd1; 
wire [3:0]  f_psize     = (x_data[39]) ?                                           4'h8 : 4'h1; 
wire        f_rd_ff_rdy =                                  (8'd64 - di_cnt) >= {4'd0, f_burst};
wire        f_hd_ff_rdy =                                                             !if_c_hf; 
wire        f_wr_ff_rdy =                           (8'd64 - {1'b0,do_cnt}) >= {4'd0, f_burst};
wire        f_cm_ff_rdy =                                                             !co_full;
wire        f_rd_ena    =                 f_hd_ff_rdy  && f_rd_ff_rdy && f_cm_ff_rdy && x_stb && x_sof && f_rd; 
wire        f_wr_ena    = (!RBUS_WR_ACK | f_hd_ff_rdy) && f_wr_ff_rdy && f_cm_ff_rdy && x_stb && x_sof && f_wr; 
wire        f_burst_end =                                                      if_burst == 'd1; 
wire        f_skip_end  =                                                      if_psize == 'd1; 
wire        f_plaod_end =                                                      if_psize == 'd1; 
wire        f_total_end =                                            f_burst_end && f_skip_end;
wire        f_hd_stb    =                                x_stb && x_sof && (if_state==IF_WAIT);
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                        if_state   <=                                          IF_WAIT;
 else case(if_state)                                   
 IF_WAIT:     if(f_rd_ena)      if_state   <=                                      IF_BURST_RD; 
         else if(f_wr_ena)      if_state   <=                                      IF_BURST_WR; 
         else                   if_state   <=                                          IF_WAIT; 
 IF_BURST_WR: if(f_total_end)   if_state   <=                                          IF_WAIT;
         else if(f_burst_end)   if_state   <=                                          IF_SKIP;  
         else                   if_state   <=                                      IF_BURST_WR;  
 IF_BURST_RD:                   if_state   <=                                          IF_WAIT;  
 IF_SKIP:     if(f_skip_end)    if_state   <=                                          IF_WAIT;
         else                   if_state   <=                                          IF_SKIP; 
 IF_ERROR:                      if_state   <=                                          IF_WAIT; 
 endcase          
//---------------------------------------------------------------------------------------------
wire f_ack_wr_data  =                                                  (if_state==IF_BURST_WR);
wire f_ack_rd_data  =                                                  (if_state==IF_BURST_RD);
//---------------------------------------------------------------------------------------------

//=============================================================================================
assign x_ack = (if_state==IF_WAIT && (f_rd_ena || f_wr_ena)) || f_ack_rd_data || f_ack_wr_data;
//=============================================================================================
always@(posedge clk or posedge rst)
 if(rst)
 begin
  if_header       <=                                                                     72'd0;
  if_header_f     <=                                                                      1'b0;
  if_burst        <=                                                                      1'd0;
  if_psize        <=                                                                       'd0;
               
  if_c_stb        <=                                                                      1'd0;
  if_c_cmd        <=                                                                      3'd0;
  if_c_bl         <=                                                                      3'd0;
  if_c_addr       <=                                                                     32'd0;
  if_c_hpass      <=                                                                      1'b0;
               
  if_d_stb        <=                                                                      1'd0;
  if_d_mask       <=                                                                      8'd0;
  if_d_data       <=                                                                     64'd0;
  
  if_wr_end       <=                                                                      1'b0;
 end 
 else if(if_state == IF_WAIT)
 begin
  if_header       <=                                                                    x_data;
  if_header_f     <=                                                      f_rd_ena || f_wr_ena;
          
  if_burst        <=                                                                   f_burst;
  if_psize        <=                                                                   f_psize;
        
  if_c_stb        <=                                                                      1'd0;
  if_c_cmd        <=                                                             {2'b00,!f_wr};
  if_c_bl         <=                                                            f_burst - 4'd1;
  if_c_addr       <=                                                       {x_data[38:3],3'd0};
  if_c_hpass      <=                                                                      1'b0;
          
  if_d_stb        <=                                                                      1'd0;
  if_d_mask       <=                                                            ~x_data[71:64];
  if_d_data       <=                                                              x_data[63:0];
  
  if_wr_end       <=                                                                      1'b0;
 end         
 else if(if_state == IF_BURST_WR)        
 begin                                                                                                
  if_header       <=                                                                 if_header;
  if_header_f     <=                                                                      1'b0;
  
  if_burst        <=                                                            if_burst - 'd1;
  if_psize        <=                                                            if_psize - 'd1;

  if_c_stb        <=                                                           if_burst == 'd1;
  if_c_cmd        <=                                                                  if_c_cmd;
  if_c_addr       <=                                                                 if_c_addr;
  if_c_hpass      <=                                                 RBUS_WR_ACK & if_header_f;
            
  if_d_stb        <=                                                                      1'd1;
  if_d_mask       <=                                                            ~x_data[71:64];
  if_d_data       <=                                                              x_data[63:0];
  
  if_wr_end       <=                                                               f_burst_end;
 end          
 else if(if_state == IF_SKIP)          
 begin                                                                                                                    
  if_header       <=                                                                 if_header;
  if_header_f     <=                                                                      1'b0;
            
  if_burst        <=                                                            if_burst - 'd1;
  if_psize        <=                                                            if_psize - 'd1;
          
  if_c_stb        <=                                                                      1'd0;
  if_c_cmd        <=                                                                  if_c_cmd;
  if_c_addr       <=                                                                 if_c_addr;
  if_c_hpass      <=                                                                      1'b0;
            
  if_d_stb        <=                                                                      1'd0;
  if_d_mask       <=                                                            ~x_data[71:64];
  if_d_data       <=                                                              x_data[63:0];
  
  if_wr_end       <=                                                                      1'b0;
 end
 else if(if_state == IF_BURST_RD)
 begin                                                                                                      
  if_header       <=                                                                 if_header;
  if_header_f     <=                                                                      1'b0;
  
  if_burst        <=                                                            if_burst - 'd1;
  if_psize        <=                                                            if_psize - 'd1;

  if_c_stb        <=                                                                      1'b1;
  if_c_cmd        <=                                                                  if_c_cmd;
  if_c_addr       <=                                                                 if_c_addr;
  if_c_hpass      <=                                                                      1'b1;
               
  if_d_stb        <=                                                                      1'd0;
  if_d_mask       <=                                                            ~x_data[71:64];
  if_d_data       <=                                                              x_data[63:0];
  
  if_wr_end       <=                                                                      1'b0;
 end
 else
 begin                                                                                                      
  if_header       <=                                                                 if_header;
  if_header_f     <=                                                                      1'b0;
  
  if_burst        <=                                                                  if_burst;
  if_psize        <=                                                                  if_psize;
        
  if_c_stb        <=                                                                  if_c_stb;
  if_c_cmd        <=                                                                  if_c_cmd;
  if_c_addr       <=                                                                 if_c_addr;
  if_c_hpass      <=                                                                if_c_hpass;
          
  if_d_stb        <=                                                                  if_d_stb;
  if_d_mask       <=                                                                 if_d_mask;
  if_d_data       <=                                                                 if_d_data;
  
  if_wr_end       <=                                                                      1'b0;
 end
//=============================================================================================
// write operation ack
//=============================================================================================
assign if_wr_done_stb =                                                RBUS_WR_ACK & if_wr_end;
//---------------------------------------------------------------------------------------------
`ifdef NO_SHIFT_REGS
ff_dram_af_ack_d16
`else	  
ff_srl_af_ack_d16
`endif 
#(
.WIDTH(1)
)   
wr_done_cnt
(             
.clk  (clk),
.rst  (rst),
                 
.i_stb  (if_wr_done_stb),  
.i_data (1'b1),
.i_af   (),
.i_full (),
.i_err  (),      

.o_stb  (wr_done_stb),
.o_ack  (wr_done_ack),
.o_data (), 
.o_ae   (), 
.o_err  ()
); 
//=============================================================================================
// output to memory controller
//=============================================================================================
assign                      co_stb        =                                           if_c_stb;
assign                      co_cmd        =                                           if_c_cmd;
assign                      co_bl         =                                            if_c_bl;
assign                      co_addr       =                                          if_c_addr;
//---------------------------------------------------------------------------------------------
assign                      do_stb        =                                           if_d_stb;
assign                      do_mask       =                                          if_d_mask;
assign                      do_data       =                                          if_d_data;
//=============================================================================================
// buffer for 32 headers
//============================================================================================= 
ff_dram_af_ack_d32
#(
.WIDTH(72)
)   
header_buffer
(             
.clk  (clk),
.rst  (rst),
                 
.i_stb  (if_c_hpass),  
.i_data (if_header),
.i_af   (),
.i_full (if_c_hf),
.i_err  (),      

.o_stb  (h_stb),
.o_ack  (h_ack),
.o_data (h_header), 
.o_ae   (), 
.o_err  ()
);     
//==========================================================================================
// data counter
//=============================================================================================  
 
always@(posedge clk or posedge rst) 
 if(rst)                                          di_cnt <=                               8'd0; 
 else if( (if_state == IF_BURST_RD) &&  di_ack)   di_cnt <=   di_cnt + {4'd0, if_burst} - 8'd1;
 else if( (if_state == IF_BURST_RD) && !di_ack)   di_cnt <=   di_cnt + {4'd0, if_burst} - 8'd0;
 else if( (if_state != IF_BURST_RD) &&  di_ack)   di_cnt <=   di_cnt                    - 8'd1;
 else/*if(~(if_state == IF_BURST_RD)&& ~di_ack)*/ di_cnt <=   di_cnt                          ;
  
//=============================================================================================
// packet formater
//=============================================================================================
localparam  PF_WAIT   = 0;
localparam  PF_HEADER = 1;
localparam  PF_BURST  = 2;
localparam  PF_WR_FILL= 3;
localparam  PF_EOP    = 4;
localparam  PF_ERROR  = 5;
//---------------------------------------------------------------------------------------------
wire        f_bl_end    =                                          (s0_burst == 'd1) && di_stb; 

wire        fo_len      =                                                         h_header[39];
wire        fo_rd1      =                                               h_header[1:0] == 2'b00; 
wire        fo_rd8      =                                               h_header[1:0] == 2'b01;
wire        fo_wra      =                                               h_header[1:0] == 2'b10; 
wire        fo_upda     =                                               h_header[1:0] == 2'b11;
wire        fo_rd_len   =                                          fo_rd8 | (fo_upda & fo_len);
                           
//wire        f_wr       =                                                      (f_wra | f_upda);
wire        fo_wr       =                                                     fo_wra          ;  
wire        fo_rd       =                                          (fo_rd1 | fo_rd8 | fo_upda);
wire        fo_rd_wr    =                                                             fo_upda ;  
wire        fo_op_len   =                      fo_rd8 | (fo_upda & fo_len)                    ; // response len
  
wire [3:0]  f_bl        =  (fo_op_len)?                                            4'd8 : 4'd1; 
wire        f_long      =                                                            fo_op_len;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                                               pf_state   <=                   PF_WAIT;
 else case(pf_state)                                  
 PF_WAIT:   if(h_stb && !s1_f9)                        pf_state   <=                 PF_HEADER; 
       else                                            pf_state   <=                   PF_WAIT; 
 PF_HEADER: if(fo_wra & RBUS_WR_ACK)                   pf_state   <=                PF_WR_FILL; 
       else                                            pf_state   <=                  PF_BURST;
 PF_BURST:  if(f_bl_end)                               pf_state   <=                   PF_WAIT;
       else                                            pf_state   <=                  PF_BURST;
 PF_WR_FILL:if(wr_done_stb)                            pf_state   <=                   PF_WAIT;
       else                                            pf_state   <=                PF_WR_FILL;
 PF_ERROR:                                             pf_state   <=                   PF_WAIT; 
 endcase 
//---------------------------------------------------------------------------------------------
assign   h_ack   =                                                       pf_state == PF_HEADER;
//=============================================================================================
// mux
//============================================================================================= 
always@(posedge clk or posedge rst)
 if(rst)
 begin
  s0_sof          <=                                                                      1'd0;
  s0_inc          <=                                                                      1'd0;
  s0_lst          <=                                                                      1'd0;
  s0_data         <=                                                                     72'd0;
  s0_burst        <=                                                                      6'd0; 
  s0_stb          <=                                                                      1'd0;          
 end 
 else if(pf_state == PF_WAIT)
 begin
  s0_sof          <=                                                                      1'd0;
  s0_inc          <=                                                                      1'd0;
  s0_lst          <=                                                                      1'd0;   
  s0_data         <=                                                                     72'd0;
  s0_burst        <=                                                                      6'd0; 
  s0_stb          <=                                                                      1'd0;        
 end 
 else if(pf_state == PF_HEADER)
 begin                                         
  s0_sof          <=                                                                      1'd1;
  s0_inc          <=                                                                      1'd0;
  s0_lst          <=                                                                      1'd0;
  s0_data         <=                          {2'b10, h_header[69:40], f_long, h_header[38:0]};
  s0_burst        <=                                                                      f_bl;
  s0_stb          <=                                                                      1'd1;            
 end 
 else if(pf_state == PF_BURST)
 begin
  s0_sof          <=                                                                      1'd0;
  s0_inc          <=                                                   s0_burst=='d1 && di_stb;
  s0_lst          <=                                                             s0_burst=='d1;
  s0_burst        <= (di_stb)?                                 s0_burst - 'd1 : s0_burst - 'd0;
  s0_data         <=                                                           {8'hFF,di_data};
  s0_stb          <=                                                                    di_stb;                
 end 
 else if(pf_state == PF_WR_FILL)
 begin
  s0_sof          <=                                                                      1'd0;
  s0_inc          <=                                                               wr_done_stb;
  s0_lst          <=                                                                      1'd1;
  s0_burst        <=                                                                      6'd0;
  s0_data         <=                                                            {8'h00, 64'd0}; // don't care
  s0_stb          <=                                                               wr_done_stb;                
 end 
 else 
 begin
  s0_sof          <=                                                                    s0_sof;
  s0_inc          <=                                                                    s0_inc;
  s0_lst          <=                                                                    s0_lst;
  s0_burst        <=                                                                  s0_burst;
  s0_data         <=                                                                   s0_data;
  s0_stb          <=                                                                    s0_stb;                        
 end 
//---------------------------------------------------------------------------------------------
assign   di_ack      =                                      di_stb && (pf_state ==   PF_BURST);
assign   wr_done_ack =                                 wr_done_stb && (pf_state == PF_WR_FILL);
//=============================================================================================
// output fifo
//============================================================================================= 
ff_dram_af_ack_d32
#(
.WIDTH    (74), 
.AF0LIMIT (2), 
.AF1LIMIT (9)
)   
o_ff
(
.clk    (clk),
.rst    (rst),
                 
.i_stb  (s0_stb), 
.i_af   ({s1_f9, s1_f2}),
.i_data ({s0_sof, s0_lst, s0_data}),
.i_full (),  
.i_err  (), 

.o_stb  (s1_rdy),
.o_ack  (o_stb),
.o_data ({s1_sof, s1_lst, s1_data}), 
.o_ae   (),                
.o_err  ()
);
//---------------------------------------------------------------------------------------------
assign s1_len =                                                                    s1_data[39];
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst) 
 if(rst)                            s1_pcnt    <=                                          - 1;
 else if(~s0_inc &&  s1_dec)        s1_pcnt    <=                                  s1_pcnt - 1;          
 else if( s0_inc && ~s1_dec)        s1_pcnt    <=                                  s1_pcnt + 1;
 else                               s1_pcnt    <=                                  s1_pcnt; 
//---------------------------------------------------------------------------------------------
always@(posedge clk)                                                                                               
      if(!o_ff_rdy || !s1_rdy      )o_ff_rdy   <=                                     o_rdy[1]; // sprawdzanie przed rozpoczeciem nadawania pakietu                   
// else if(            o_stb & s1_lst)o_ff_rdy   <=                                         1'b0; // stop po nadaniu caego pakietu - takt przerwy na aktualizacj flag af   
 else                               o_ff_rdy   <=                                     o_ff_rdy; 
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)                                                                                                
      if(rst                                     )s1_pending  <=                          1'b0;                    
 else if(        !s1_rdy                         )s1_pending  <=                          1'b0;                    
 else if(s1_lst & s1_rdy                         )s1_pending  <=    s1_pcnt != 'd0 && o_rdy[1]; // sprawdzanie przed rozpoczeciem nadawania pakietu     
 else if(!s1_pending & s1_sof & s1_rdy &  s1_len )s1_pending  <=       !s1_pcnt[4] && o_rdy[1]; // sprawdzanie przed rozpoczeciem nadawania pakietu 
 else if(!s1_pending & s1_sof & s1_rdy & !s1_len )s1_pending  <=       !s1_pcnt[4] && o_rdy[0]; // sprawdzanie przed rozpoczeciem nadawania pakietu                     
 else                                             s1_pending  <=                    s1_pending; 
//---------------------------------------------------------------------------------------------
assign  s1_dec      =                                                          o_stb && s1_lst;
//=============================================================================================
assign o_stb        =                                                               s1_pending;
assign o_sof        =                                                                   s1_sof;
assign o_data       =                                                                  s1_data;
//=============================================================================================      
endmodule