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

input  wire         i_stb,
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

reg  [ 7:0] o_dat_x;
reg  [ 3:0] o_prior_1hot;   
reg         o_ack1;
reg         o_ack2;
//=============================================================================================
// requests fifo
//============================================================================================= 
assign ff_i_dat =                                                               {i_req, i_rid}; 
//---------------------------------------------------------------------------------------------
generate 
genvar i;
    for(i = 0; i < PRIORITIES_NUM; i = i+1)
    begin : pkt_req_ff  
    
      assign ff_i_stb[i] = (i_prior == i) && i_stb;    
      wire unused;                      
      
      always@(posedge clk or posedge rst)
      if(rst) ff_o_ack[i] <=                     1'b0;
      else    ff_o_ack[i] <= o_prior_1hot[i] && o_ack;
                         
      ff_srl_af_ack_d32
      #(
      .WIDTH(8), 
      .AF0LIMIT(6'd3), 
      .AE0LIMIT(6'd3)
      )   
      ff_req
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
      .o_ae   (ff_o_ae [i]),
      .o_err  (ff_o_err[i])
      ); 
      
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
if(rst)                                          o_ack1   <=                              1'b0;
else                                             o_ack1   <=                             o_ack; 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
if(rst)                                          o_ack2   <=                              1'b0;
else                                             o_ack2   <=                            o_ack1; 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
if(rst)                                          o_stb    <=                              1'b0;
else                                             o_stb    <=                         |ff_o_stb; 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)
     if((!o_stb | o_ack2) & ff_o_stb[3])         o_dat_x  <=                       ff_o_dat[3];
else if((!o_stb | o_ack2) & ff_o_stb[2])         o_dat_x  <=                       ff_o_dat[2];
else if((!o_stb | o_ack2) & ff_o_stb[1])         o_dat_x  <=                       ff_o_dat[1];
else if((!o_stb | o_ack2)              )         o_dat_x  <=                       ff_o_dat[0];
//--------------------------------------------------------------------------------------------- 
assign o_req =                                                                    o_dat_x[7:4]; 
assign o_rid =                                                                    o_dat_x[3:0];
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)
     if((!o_stb | o_ack2) & ff_o_stb[3])         o_prior  <=                               'd3;
else if((!o_stb | o_ack2) & ff_o_stb[2])         o_prior  <=                               'd2;
else if((!o_stb | o_ack2) & ff_o_stb[1])         o_prior  <=                               'd1;
else if((!o_stb | o_ack2)              )         o_prior  <=                               'd0;
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)                      
     if((!o_stb | o_ack2) & ff_o_stb[3])         o_prior_1hot <=                        'b1000;
else if((!o_stb | o_ack2) & ff_o_stb[2])         o_prior_1hot <=                        'b0100;
else if((!o_stb | o_ack2) & ff_o_stb[1])         o_prior_1hot <=                        'b0010;
else if((!o_stb | o_ack2)              )         o_prior_1hot <=                        'b0001;
//=============================================================================================
endmodule