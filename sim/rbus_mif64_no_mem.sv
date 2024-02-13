//============================================================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//============================================================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//============================================================================================================================
module rbus_mif64_no_mem  
#(                                                         
parameter        SEND_WR_FB          = "TRUE", // "TRUE", "FALSE"
parameter [31:0] REDUCED_BANDWITH_TO = 100 // 0-100
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
 input  wire     [1:0]  o_rdy
);    
//=============================================================================================
wire      fi_head_stb  =                                                      i_sof && i_stb; 
wire [1:0]fi_mode      =                                                         i_data[1:0];

wire      fi_len       =                                                          i_data[39];
wire      fi_rd1       =                                                i_data[1:0] == 2'b00; 
wire      fi_rd8       =                                                i_data[1:0] == 2'b01;
wire      fi_wra       =                                                i_data[1:0] == 2'b10; 
wire      fi_upda      =                                                i_data[1:0] == 2'b11;
wire      fi_rd_len    =                                         fi_rd8 | (fi_upda & fi_len);

wire      fi_f_hwr     =                                                fi_wra & fi_head_stb;  
wire      fi_f_hrd     =                           (fi_rd1 | fi_rd8 | fi_upda) & fi_head_stb;
wire      fi_rd_wr     =                                              fi_upda  & fi_head_stb; 
 
//=============================================================================================
reg       i1_wr_ack_pen;
reg       i1_wr_frst;
reg [71:0]i1_wr_ack_head;
reg [ 4:0]i1_wr_pen_cnt;
wire      i1_wr_pen_lst = (i1_wr_ack_pen            ) & i1_wr_pen_cnt[4];
wire      i1_wr_wait;

reg       i1_rd_1_pen;
reg       i1_rd_8_pen;
wire      i1_rd_pen = i1_rd_1_pen || i1_rd_8_pen;
reg       i1_rd_frst;
reg [71:0]i1_rd_head;
reg [ 4:0]i1_rd_pen_cnt;
wire      i1_rd_pen_lst = (i1_rd_1_pen | i1_rd_8_pen) & i1_rd_pen_cnt[4];

//=============================================================================================
always@(posedge clk or posedge rst)
     if(rst             ) i1_wr_ack_pen <= 1'b0;
else if(fi_f_hwr        ) i1_wr_ack_pen <= 1'b1;
else if(i1_wr_pen_lst   ) i1_wr_ack_pen <= 1'b0;

always@(posedge clk or posedge rst)
     if(rst             ) i1_wr_frst <= 1'b0;
else if(fi_f_hwr        ) i1_wr_frst <= 1'b1;
else                      i1_wr_frst <= i1_wr_frst & i1_wr_wait;

always@(posedge clk or posedge rst)
     if(rst             ) i1_wr_ack_head <= 72'd0;
else if(fi_f_hwr        ) i1_wr_ack_head <= {i_data[71:40], 1'b0, i_data[38:0]};
else                      i1_wr_ack_head <= i1_wr_ack_head;

always@(posedge clk or posedge rst)
     if(rst             ) i1_wr_pen_cnt  <= 5'd0;
else if(fi_f_hwr        ) i1_wr_pen_cnt  <= 5'd0;
else if(i1_wr_ack_pen   ) i1_wr_pen_cnt  <= i1_wr_pen_cnt - {4'd0, !i1_wr_wait};

assign i1_wr_wait = i1_rd_pen;
//=============================================================================================
always@(posedge clk or posedge rst)
     if(rst             ) i1_rd_1_pen <= 1'b0;
else if(fi_f_hrd        ) i1_rd_1_pen <= !fi_rd_len;
else if(i1_rd_pen_lst   ) i1_rd_1_pen <= 1'b0;

always@(posedge clk or posedge rst)
     if(rst             ) i1_rd_8_pen <= 1'b0;
else if(fi_f_hrd        ) i1_rd_8_pen <=  fi_rd_len;
else if(i1_rd_pen_lst   ) i1_rd_8_pen <= 1'b0;

always@(posedge clk or posedge rst)
     if(rst             ) i1_rd_frst <= 1'b0;
else if(fi_f_hrd        ) i1_rd_frst <= 1'b1;
else                      i1_rd_frst <= 1'b0;
        
always@(posedge clk or posedge rst)
     if(rst             ) i1_rd_head  <= 72'd0;
else if(fi_f_hrd        ) i1_rd_head  <= {i_data[71:40], fi_rd_len, i_data[38:0]};
else                      i1_rd_head  <= i1_rd_head;

always@(posedge clk or posedge rst)
     if(rst             ) i1_rd_pen_cnt  <= 5'd0;
else if(fi_f_hrd        ) i1_rd_pen_cnt  <= 5'd0;
else if(i1_rd_pen       ) i1_rd_pen_cnt  <= i1_rd_pen_cnt - 5'd1;
//=============================================================================================
// variables
//=============================================================================================
wire        ff_i_l_wen=   (i1_rd_frst || i1_wr_frst) &  ff_i_data[39];
wire        ff_i_s_wen=   (i1_rd_frst || i1_wr_frst) & !ff_i_data[39];
wire [72:0] ff_i_data =  (i1_rd_frst)?   {1'b1, i1_rd_head    } : 
                         (i1_wr_frst)?   {1'b1, i1_wr_ack_head} : {1'b0, 72'd0};      
wire [ 1:0] ff_i_s_af; 
wire [ 1:0] ff_i_l_af; 
wire [ 1:0] ff_i_af;   
wire        ff_i_s_err; 
wire        ff_i_l_err;  

wire        ff_o_s_ack;
wire        ff_o_s_stb;
wire [72:0] ff_o_s_data; 
wire        ff_o_s_err;  

wire        ff_o_l_ack;
wire        ff_o_l_stb;
wire [72:0] ff_o_l_data; 
wire        ff_o_l_err; 

wire        ff_sof     ;
wire        ff_len     ;   
                         
wire        o_hdr_l_en ;
wire        o_hdr_s_en ;
wire        o_stb_hdr  ;                                                                        

reg  [4:0]  o_pnd_cnt; 
wire        o_pnd;    
wire        o_pnd_lst; 

reg         o_pref_len;  

reg  [31:0] o_pause_cnt;
wire        o_pause_flag;
//---------------------------------------------------------------------------------------------                           
ff_dram_af_ack_d16
#(
.WIDTH(73),      
.AF0LIMIT(7'd2), 
.AF1LIMIT(7'd2)
)   
ff_hdr_l
(             
.clk    (clk), .rst   (rst),
                 
.i_stb  (ff_i_l_wen),  
.i_data (ff_i_data),
.i_af   (ff_i_l_af),
.i_full ( ),   
.i_err  (ff_i_l_err),

.o_stb  (ff_o_l_stb), 
.o_ack  (ff_o_l_ack), 
.o_data (ff_o_l_data),
.o_ae   (),  
.o_err  (ff_o_l_err)
);          
//---------------------------------------------------------------------------------------------                           
ff_dram_af_ack_d16
#(
.WIDTH(73),      
.AF0LIMIT(7'd2), 
.AF1LIMIT(7'd2)
)   
ff_hdr_s
(             
.clk    (clk), .rst   (rst),
                 
.i_stb  (ff_i_s_wen),  
.i_data (ff_i_data),
.i_af   (ff_i_s_af),
.i_full ( ),   
.i_err  (ff_i_s_err),

.o_stb  (ff_o_s_stb), 
.o_ack  (ff_o_s_ack), 
.o_data (ff_o_s_data),
.o_ae   (),  
.o_err  (ff_o_s_err)
);    

//============================================================================================= 
assign ff_i_af = {ff_i_s_af[0], ff_i_l_af[0]};                                 
assign i_rdy = ~ff_i_af;                                 
//---------------------------------------------------------------------------------------------
assign ff_sof     = ff_o_l_data[72];
assign ff_len     = ff_o_l_data[39];                                                            
assign o_hdr_l_en = !o_pnd & (ff_o_l_stb & ( o_pref_len || (!ff_o_s_stb || !o_rdy[0]))) & o_rdy[1] & !o_pause_flag;
assign o_hdr_s_en = !o_pnd & (ff_o_s_stb & (!o_pref_len || (!ff_o_l_stb || !o_rdy[1]))) & o_rdy[0] & !o_pause_flag;
assign o_stb_hdr  = o_hdr_l_en | o_hdr_s_en; 
assign ff_o_l_ack   = o_hdr_l_en;     
assign ff_o_s_ack   = o_hdr_s_en;                                                            
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
if(rst)                o_pref_len =                       1'b0; 
else if(o_hdr_l_en   ) o_pref_len =                       1'b0;
else if(o_hdr_s_en   ) o_pref_len =                       1'b1; 
else                   o_pref_len =                 o_pref_len;                        
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
if(rst)                o_pnd_cnt =                      5'h1F; 
else if(o_hdr_l_en   ) o_pnd_cnt =                       5'd7;
else if(o_hdr_s_en   ) o_pnd_cnt =                       5'd0;
else if(o_pnd        ) o_pnd_cnt =           o_pnd_cnt - 5'd1; 
else                   o_pnd_cnt =           o_pnd_cnt       ;                                  
//---------------------------------------------------------------------------------------------
assign o_pnd     = !o_pnd_cnt[4];  
assign o_pnd_lst = o_pnd_cnt == 5'd0;
//---------------------------------------------------------------------------------------------  
assign o_stb  = o_hdr_l_en | o_hdr_s_en | o_pnd;
assign o_sof  = o_stb_hdr;
assign o_data = (o_hdr_l_en)? ff_o_l_data[71:0] : (o_hdr_s_en)? ff_o_s_data[71:0] : 72'd0;   
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)        
if(rst)                   o_pause_cnt <=                                                   400; 
else if(o_pause_cnt == 0) o_pause_cnt <=                                                   400;
else                      o_pause_cnt <=                                       o_pause_cnt - 1;
//---------------------------------------------------------------------------------------------
assign o_pause_flag =                            (o_pause_cnt > (REDUCED_BANDWITH_TO*400/100));                                            
//=============================================================================================
// ff_err
//============================================================================================= 
always @(clk)
if(ff_i_s_err | ff_o_s_err | ff_i_l_err | ff_o_l_err )    
  begin
    $display( "!!!ERROR!!! %m: FIFO OVERFLOW DETECTED" );
    $finish;
  end                                                                                           
//=============================================================================================   
endmodule
