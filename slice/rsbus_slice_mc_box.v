//==============================================================================================
//    Main contributors
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//==============================================================================================
`default_nettype none
//----------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//==============================================================================================
module rsbus__slice_mc_box
(
 input  wire            clk,                /*synthesis syn_keep=1*/
 input  wire            rst,                /*synthesis syn_keep=1*/

 input  wire            i_stb,              /*synthesis syn_keep=1*/
 input  wire            i_sof,              /*synthesis syn_keep=1*/
 input  wire    [71:0]  i_data,             /*synthesis syn_keep=1*/
 output wire     [1:0]  i_af,               /*synthesis syn_keep=1*/  

 output wire            o_stb,              /*synthesis syn_keep=1*/
 output wire            o_sof,              /*synthesis syn_keep=1*/
 output wire    [71:0]  o_data,             /*synthesis syn_keep=1*/
 input  wire     [1:0]  o_af,               /*synthesis syn_keep=1*/
 
 output wire            ff_err              /*synthesis syn_keep=1*/ 
);                                                                                                                                                                  
//==============================================================================================
// local param
//==============================================================================================              
parameter               SLICE_NUM      =                                                   'd01;
//==============================================================================================
// variables                                                                                                       
//==============================================================================================                     
wire [SLICE_NUM-1+1:0]  ff_tmp_err;
reg                     ff_ovr_err;                             
//---------------------------------------------------------------------------------------------- 
wire                    br0_r2d_stb   [SLICE_NUM-1:0];    
wire                    br0_r2d_sof   [SLICE_NUM-1:0];    
wire            [71:0]  br0_r2d_data  [SLICE_NUM-1:0];   
wire            [ 1:0]  br0_r2d_af    [SLICE_NUM-1:0];     

wire                    br0_d2r_stb   [SLICE_NUM-1:0];    
wire                    br0_d2r_sof   [SLICE_NUM-1:0];    
wire            [71:0]  br0_d2r_data  [SLICE_NUM-1:0];   
wire            [ 1:0]  br0_d2r_af    [SLICE_NUM-1:0];     
//==============================================================================================
// switch
//==============================================================================================
rsbus__slice_sx_box switch
(
.clk                  (clk),                
.rst                  (rst),                

.i_stb                (i_stb),              
.i_sof                (i_sof),              
.i_data               (i_data),                              
.i_af                 (i_af),                                
                                      
.o_stb                (o_stb),                               
.o_sof                (o_sof),                               
.o_data               (o_data),                              
.o_af                 (o_af),                                
                                      
.branch_d2r_stb       (br0_d2r_stb),  
.branch_d2r_sof       (br0_d2r_sof),  
.branch_d2r_data      (br0_d2r_data), 
.branch_d2r_af        (br0_d2r_af),           
                                            
.branch_r2d_stb       (br0_r2d_stb),                     
.branch_r2d_sof       (br0_r2d_sof),          
.branch_r2d_data      (br0_r2d_data),  
.branch_r2d_af        (br0_r2d_af),     

.ff_err               (ff_tmp_err[0])  
);
//==============================================================================================
// slice with uP
//==============================================================================================
// slice 0
//==============================================================================================
generate
genvar i;
  for(i=0;i<SLICE_NUM;i=i+1) 
    begin : SLICE
      rbus__slice_cx_box eco32_slice_cx_box
      (                                         
      .clk               (clk),                        
      .rst               (rst), 
                                      
      .i_stb             (br0_r2d_stb   [i]),
      .i_sof             (br0_r2d_sof   [i]),    
      .i_data            (br0_r2d_data  [i]),   
      .i_af              (br0_r2d_af    [i]), 
                            
      .o_stb             (br0_d2r_stb   [i]),    
      .o_sof             (br0_d2r_sof   [i]),    
      .o_data            (br0_d2r_data  [i]),   
      .o_af              (br0_d2r_af    [i]),    
                                
      .dbg_i_stb         ('d0),    
      .dbg_i_data        ('d0),    
      .dbg_i_ack         (),
                                
      .dbg_o_stb         (),    
      .dbg_o_data        (),    
      .dbg_o_ack         (eco32_slice_cx_box.dbg_o_stb),
                                
      .ff_err            (ff_tmp_err [i+1])   
      ); 
  end
endgenerate
//============================================================================================== 
always@(posedge clk or posedge rst)
if(rst)                 ff_ovr_err <=                                                      1'b0; 
else if(|ff_tmp_err[4]) ff_ovr_err <=                                                      1'b1;
else                    ff_ovr_err <=                                                ff_ovr_err;
//---------------------------------------------------------------------------------------------- 
assign ff_err =                                                                      ff_ovr_err;
//============================================================================================== 
endmodule

