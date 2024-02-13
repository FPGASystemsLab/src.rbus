//=============================================================================================
//    Main contributors             
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rbus_vo_box   
(                                                                                                                               
input  wire         clk, 
input  wire         rst,    
                            
// PHY interface         
input wire          vid_clk,
input wire          vid_rst,

output wire         vid_pclk,
output wire         vid_hsync,
output wire         vid_vsync,
output wire         vid_active,
output wire         vid_disp,
output wire  [7:0]  vid_red,
output wire  [7:0]  vid_green,
output wire  [7:0]  vid_blue,     
                      
// network interface
input  wire         soft_rst,

input  wire         r2d_stb,                              
input  wire         r2d_sof, 
input  wire [71:0]  r2d_data,
output wire  [1:0]  r2d_af,  
                
input  wire         r2d_eve_stb,  
input  wire [ 7:0]  r2d_eve_cmd,  
input  wire [39:0]  r2d_eve_ptr,  
output wire         r2d_eve_ack,  
                          
output wire         d2r_stb,   
output wire         d2r_sof,      
output wire [71:0]  d2r_data,     
input  wire  [1:0]  d2r_af,       
                     
output wire         d2r_eve_stb,  
output wire [ 7:0]  d2r_eve_cmd,  
output wire [ 7:0]  d2r_eve_dev,  
output wire [39:0]  d2r_eve_ptr,  
input  wire         d2r_eve_ack 
);                         
//=============================================================================================
// parameters
//============================================================================================= 
parameter DBG               = "FALSE";  

parameter V_SYNC            = 2;
parameter V_BACK_PORCH      = 2;       
parameter V_FRONT_PORCH     = 10; 
parameter V_SYNC_POL        = 0;   
                
parameter H_READ_BURST      = 8; // (H_ACTIVE >> 1) must be divisible by H_READ_BURST 
parameter H_SYNC            = 2;    
parameter H_BACK_PORCH      = 2;  
parameter H_FRONT_PORCH     = 41;
parameter H_SYNC_POL        = 0;

parameter MAX_DISP_L_WIDTH  = 480;// for gfx bufer & txt bufer size calculation  
parameter MAX_DISP_HEIGHT   = 272;// for             txt bufer size calculation 

parameter MEM_BUFF_START    = 39'h000000000;
//=============================================================================================
localparam CMD_VGA_SET_BASE_ADDR    = 8'h20;  
localparam CMD_VGA_SET_PH_WIDTH     = 8'h21;  
localparam CMD_VGA_SET_LO_WIDTH     = 8'h22;  
localparam CMD_VGA_SET_LO_HEIGHT    = 8'h23;  
localparam CMD_VGA_SET_MODE         = 8'h24;  
localparam CMD_VGA_SET_TEXT_ENA     = 8'h25;  
localparam CMD_VGA_PUT_CHAR         = 8'h26;  
localparam CMD_VGA_SET_H_POL        = 8'h27;  
localparam CMD_VGA_SET_V_POL        = 8'h28;  
//=============================================================================================
// variables
//=============================================================================================
//wire rsx = rst || soft_rst; 
(* keep = "true", max_fanout = 200 *) reg  rsx;                   
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)
     if(rst                     ) rsx <=                 1'd1;
else if(soft_rst                ) rsx <=                 1'd1;
else                              rsx <=                 1'b0;   
//---------------------------------------------------------------------------------------------   
reg  [38:0] cfg_base_addr;        
reg  [15:0] cfg_ph_width;       
reg  [15:0] cfg_lo_width;       
reg  [15:0] cfg_lo_height;        
reg   [1:0] cfg_mode;       
reg         cfg_text_ena;
reg         cfg_h_pol;
reg         cfg_v_pol;

reg  [ 7:0] vga_char_dat;   
reg         vga_char_stb;
wire        vga_char_ack; 
//===============================================================================  
wire r2d_eve_cfg_base_addr_stb   = r2d_eve_stb && (r2d_eve_cmd == CMD_VGA_SET_BASE_ADDR);  
wire r2d_eve_cfg_ph_width_stb    = r2d_eve_stb && (r2d_eve_cmd == CMD_VGA_SET_PH_WIDTH);  
wire r2d_eve_cfg_lo_width_stb    = r2d_eve_stb && (r2d_eve_cmd == CMD_VGA_SET_LO_WIDTH);  
wire r2d_eve_cfg_lo_height_stb   = r2d_eve_stb && (r2d_eve_cmd == CMD_VGA_SET_LO_HEIGHT); 
wire r2d_eve_cfg_mode_stb        = r2d_eve_stb && (r2d_eve_cmd == CMD_VGA_SET_MODE);     
wire r2d_eve_cfg_text_ena_stb    = r2d_eve_stb && (r2d_eve_cmd == CMD_VGA_SET_TEXT_ENA);
wire r2d_eve_vga_char_stb        = r2d_eve_stb && (r2d_eve_cmd == CMD_VGA_PUT_CHAR) && !vga_char_stb;  
wire r2d_eve_cfg_h_pol           = r2d_eve_stb && (r2d_eve_cmd == CMD_VGA_SET_H_POL);  
wire r2d_eve_cfg_v_pol           = r2d_eve_stb && (r2d_eve_cmd == CMD_VGA_SET_V_POL);                
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rsx)
   if(rsx                        ) cfg_base_addr <=       MEM_BUFF_START;// 1024*1024*128 - 512; 
else if(r2d_eve_cfg_base_addr_stb) cfg_base_addr <=    r2d_eve_ptr[38:0];
else                               cfg_base_addr <=        cfg_base_addr;                    
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rsx)
   if(rsx                        ) cfg_ph_width  <=             16'd2048;  
else if(r2d_eve_cfg_ph_width_stb ) cfg_ph_width  <=    r2d_eve_ptr[11:0];
else                               cfg_ph_width  <=         cfg_ph_width;                    
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rsx)
   if(rsx                        ) cfg_lo_width  <=     MAX_DISP_L_WIDTH;  
else if(r2d_eve_cfg_lo_width_stb ) cfg_lo_width  <=    r2d_eve_ptr[11:0];
else                               cfg_lo_width  <=         cfg_lo_width;                    
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rsx)
   if(rsx                        ) cfg_lo_height <=      MAX_DISP_HEIGHT;   
else if(r2d_eve_cfg_lo_height_stb) cfg_lo_height <=    r2d_eve_ptr[11:0];
else                               cfg_lo_height <=        cfg_lo_height;                    
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rsx)
   if(rsx                        ) cfg_mode      <=                2'b00; // default RGBA  
else if(r2d_eve_cfg_mode_stb     ) cfg_mode      <=     r2d_eve_ptr[1:0];
else                               cfg_mode      <=             cfg_mode;                    
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rsx)
   if(rsx                        ) cfg_text_ena  <=                 1'd0;  
else if(r2d_eve_cfg_text_ena_stb ) cfg_text_ena  <=       r2d_eve_ptr[0];
else                               cfg_text_ena  <=         cfg_text_ena;                  
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rsx)
   if(rsx                        ) cfg_v_pol     <=           V_SYNC_POL;  
else if(r2d_eve_cfg_v_pol        ) cfg_v_pol     <=       r2d_eve_ptr[0];
else                               cfg_v_pol     <=            cfg_v_pol;                      
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rsx)
   if(rsx                        ) cfg_h_pol     <=           H_SYNC_POL;  
else if(r2d_eve_cfg_h_pol        ) cfg_h_pol     <=       r2d_eve_ptr[0];
else                               cfg_h_pol     <=            cfg_h_pol;
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rsx)
   if(rsx                        ) vga_char_dat  <=                 1'd0;  
else if(r2d_eve_vga_char_stb     ) vga_char_dat  <=    r2d_eve_ptr[ 7:0];
else                               vga_char_dat  <=         vga_char_dat;                    
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rsx)
   if(rsx                        ) vga_char_stb  <=                 1'd0;  
else if(vga_char_ack             ) vga_char_stb  <=                 1'b0; 
else if(r2d_eve_vga_char_stb     ) vga_char_stb  <=                 1'b1;
else                               vga_char_stb  <=         vga_char_stb;  
//==============================================================================================
// video out
//============================================================================================== 
vo_box video_out
(
.mem_rst                    (rsx),   
.mem_clk                    (clk),
                            
.mem_o_stb                  (d2r_stb),
.mem_o_sof                  (d2r_sof),
.mem_o_data                 (d2r_data),
.mem_o_af                   (d2r_af),   
                            
.mem_i_stb                  (r2d_stb),
.mem_i_sof                  (r2d_sof),
.mem_i_data                 (r2d_data),
.mem_i_af                   (r2d_af),
                            
.vout_rst                   (vid_rst),
.vout_clk                   (vid_clk),
                            
.vout_pclk_pin              (vid_pclk),// nieuzywane, przepiety wprost sygna z wejscia CLK_VGA   
.vout_hsync_pin             (vid_hsync),                                                          
.vout_vsync_pin             (vid_vsync),                                                          
.vout_de_pin                (vid_active),                                                         
.vout_red_pin               (vid_red),                                                            
.vout_green_pin             (vid_green),                                                          
.vout_blue_pin              (vid_blue),                     
              
// Parametry H              
.cfg_disp_h_front_porch     (H_FRONT_PORCH),
.cfg_disp_h_back_porch      (H_BACK_PORCH),
.cfg_disp_h_sync_pol        (cfg_h_pol),  // 0(-), 1(+)
.cfg_disp_h_sync            (H_SYNC),
// Parametry V              
.cfg_disp_v_front_porch     (V_FRONT_PORCH),
.cfg_disp_v_back_porch      (V_BACK_PORCH),
.cfg_disp_v_sync_pol        (cfg_v_pol),  // 0(-), 1(+)
.cfg_disp_v_sync            (V_SYNC),
// Parametry IMG             
.cfg_img_mode               (cfg_mode),             
.cfg_img_base_addr          (cfg_base_addr),
.cfg_img_lo_width           (cfg_lo_width),
.cfg_img_lo_hight           (cfg_lo_height),
.cfg_img_ph_width           (cfg_ph_width)
);                                                          
//============================================================================================= 
// events interface               
assign        d2r_eve_stb =                                                               1'b0;
assign        d2r_eve_dev =                                                               8'd0;                
assign        d2r_eve_ptr =                                                              40'd0;
assign        d2r_eve_cmd =                                                               8'd0; 

assign        r2d_eve_ack =             r2d_eve_stb && !(r2d_eve_vga_char_stb && vga_char_stb);        
//============================================================================================= 
endmodule
