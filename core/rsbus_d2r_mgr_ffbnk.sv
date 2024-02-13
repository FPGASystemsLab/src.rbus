//=============================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>        
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rsbus_d2r_mgr_ffbnk
(                                                                                                                               
input  wire         clk,
input  wire         rst,   

input  wire [ 3:0]  i_stb,
input  wire [ 1:0]  i_prior,
input  wire [ 3:0]  i_req,
input  wire [ 3:0]  i_rid, 
output reg  [ 3:0]  i_af,
                                                          
output reg          o_stb,
output reg  [ 1:0]  o_prior,
output wire [ 3:0]  o_req,
output wire [ 3:0]  o_rid,
input  wire         o_ack,                                
output reg          o_ff_err
);      
//=============================================================================================
// parameters
//=============================================================================================  
localparam PRIORITIES_NUM =                                                                  4;
parameter  FF_DEPTH       =                                                                 64; //64 / 32 / 16
//=============================================================================================
// variables
//=============================================================================================
wire [ 3:0] ff_i_stb;
wire [ 7:0] ff_i_dat;
wire [ 3:0] ff_i_err;
wire [ 3:0] ff_i_af;


wire [ 3:0] ff_o_stb;
reg  [ 3:0] ff_o_ack;
wire [ 7:0] ff_o_dat[3:0];
wire [ 3:0] ff_o_err; 
wire [ 3:0] ff_o_ae;   
                   
reg         o0_stb; 
reg  [ 7:0] o0_dat_x[3:0];
reg  [ 3:0] o0_prior_1hot;   
reg         o0_ack1;
reg         o0_ack2; 
reg  [ 1:0] o0_prior;

reg  [ 7:0] o_dat_x;
reg  [ 3:0] o_prior_1hot;
//=============================================================================================
// requests fifo
//============================================================================================= 
assign ff_i_dat =                                                               {i_req, i_rid}; 
//---------------------------------------------------------------------------------------------
generate 
genvar i;
    for(i = 0; i < PRIORITIES_NUM; i = i+1)
    begin : pkt_req_ff  
      wire unused;
      assign ff_i_stb[i] = /*(i_prior == i) && */ i_stb[i];    
      wire [1:0] ffx_o_ae;             
      always@(posedge clk or posedge rst)
      if(rst) ff_o_ack[i] <=                     1'b0;
      else    ff_o_ack[i] <= o0_prior_1hot[i] && o_ack;
                         
      if(FF_DEPTH == 64) begin
        ff_dram_af_ack_d64
        #(
        .WIDTH(8), 
        .AF0LIMIT(7'd3), 
        .AE0LIMIT(7'd5)
        )   
        ff_req_64
        (             
        .clk    (clk), .rst   (rst),
                         
        .i_stb  (ff_i_stb[i]),  
        .i_data (ff_i_dat),
        .i_af   ({unused, ff_i_af[i]}),
        .i_full ( ),   
        .i_err  (ff_i_err[i]),

        .o_stb  (ff_o_stb[i]), 
        .o_ack  (ff_o_ack[i]), 
        .o_data (ff_o_dat[i]),
        .o_ae   (ffx_o_ae),
        .o_err  (ff_o_err[i])
        ); end
      else if (FF_DEPTH == 32) begin
        `ifdef NO_SHIFT_REGS
        ff_dram_af_ack_d32
        `else	  
        ff_srl_af_ack_d32
        `endif
        #(
        .WIDTH(8), 
        .AF0LIMIT(6'd3), 
        .AE0LIMIT(6'd3)
        )   
        ff_req_32
        (             
        .clk    (clk), .rst   (rst),
                         
        .i_stb  (ff_i_stb[i]),  
        .i_data (ff_i_dat),
        .i_af   ({unused, ff_i_af[i]}),
        .i_full ( ),   
        .i_err  (ff_i_err[i]),

        .o_stb  (ff_o_stb[i]), 
        .o_ack  (ff_o_ack[i]), 
        .o_data (ff_o_dat[i]),   
        .o_ae   (ffx_o_ae),
        .o_err  (ff_o_err[i])
        ); end
      else /*if (FF_DEPTH == 16)*/ begin
        `ifdef NO_SHIFT_REGS
        ff_dram_af_ack_d16
        `else	  
        ff_srl_af_ack_d16
        `endif
        #(
        .WIDTH(8), 
        .AF0LIMIT(5'd3), 
        .AE0LIMIT(5'd3)
        )   
        ff_req_16
        (             
        .clk    (clk), .rst   (rst),
                         
        .i_stb  (ff_i_stb[i]),  
        .i_data (ff_i_dat),
        .i_af   ({unused, ff_i_af[i]}),
        .i_full ( ),   
        .i_err  (ff_i_err[i]),

        .o_stb  (ff_o_stb[i]), 
        .o_ack  (ff_o_ack[i]), 
        .o_data (ff_o_dat[i]), 
        .o_ae   (ffx_o_ae),
        .o_err  (ff_o_err[i])
        ); end
                  
      assign ff_o_ae[i] = ffx_o_ae[0];
      
      // almost full with histerezis 
      always@(posedge clk or posedge rst)
           if(rst        )         i_af[i]  <=                                            1'b0;
      else if(i_af[i]    )         i_af[i]  <=                                     ~ff_o_ae[i];
      else                         i_af[i]  <=                                      ff_i_af[i];
    end
endgenerate
//=============================================================================================
always@(posedge clk or posedge rst)
if(rst)                      o_ff_err <=                                                  1'b0;
else                         o_ff_err <=                o_ff_err || (|ff_i_err) || (|ff_o_err);        
//=============================================================================================
// output
//============================================================================================= 
always@(posedge clk or posedge rst)
if(rst)                                          o0_ack1  <=                              1'b0;
else                                             o0_ack1  <=                             o_ack; 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
if(rst)                                          o0_ack2  <=                              1'b0;
else                                             o0_ack2  <=                           o0_ack1; 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
if(rst)                                          o0_stb   <=                              1'b0;
else                                             o0_stb   <=                         |ff_o_stb; 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk) begin
                                                 o0_dat_x[3] <=                    ff_o_dat[3];
                                                 o0_dat_x[2] <=                    ff_o_dat[2];
                                                 o0_dat_x[1] <=                    ff_o_dat[1];
                                                 o0_dat_x[0] <=                    ff_o_dat[0];
end                                                                                             
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)
     if((!o0_stb | o0_ack2) & ff_o_stb[3])       o0_prior <=                               'd3;
else if((!o0_stb | o0_ack2) & ff_o_stb[2])       o0_prior <=                               'd2;
else if((!o0_stb | o0_ack2) & ff_o_stb[1])       o0_prior <=                               'd1;
else if((!o0_stb | o0_ack2)              )       o0_prior <=                               'd0;
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)                      
     if((!o0_stb | o0_ack2) & ff_o_stb[3])       o0_prior_1hot <=                       'b1000;
else if((!o0_stb | o0_ack2) & ff_o_stb[2])       o0_prior_1hot <=                       'b0100;
else if((!o0_stb | o0_ack2) & ff_o_stb[1])       o0_prior_1hot <=                       'b0010;
else if((!o0_stb | o0_ack2)              )       o0_prior_1hot <=                       'b0001;
//=============================================================================================  
// output
//=============================================================================================
always@(posedge clk or posedge rst)
if(rst)                                          o_stb    <=                              1'b0;
else                                             o_stb    <=                            o0_stb; 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)
     if(o0_prior == 2'd3)                        o_dat_x  <=                       o0_dat_x[3];
else if(o0_prior == 2'd2)                        o_dat_x  <=                       o0_dat_x[2];
else if(o0_prior == 2'd1)                        o_dat_x  <=                       o0_dat_x[1];
else                                             o_dat_x  <=                       o0_dat_x[0];
//--------------------------------------------------------------------------------------------- 
assign o_req =                                                                    o_dat_x[7:4]; 
assign o_rid =                                                                    o_dat_x[3:0];
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)                             o_prior  <=                          o0_prior;
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)                             o_prior_1hot <=                 o0_prior_1hot;
//=============================================================================================
endmodule