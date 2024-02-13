//=============================================================================================
//    Main contributors             
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rbus_uart_box   
(                                                                                                                               
input  wire         clk, 
input  wire         rst,    
                            
// PHY interface
input  wire         RX,   
output wire         TX,     
                      
// network interface
input  wire         soft_rst,

input  wire         r2d_stb,                              
input  wire         r2d_sof, 
input  wire [71:0]  r2d_data,
output wire  [1:0]  r2d_rdy,  
                
input  wire         r2d_eve_stb,  
input  wire [ 7:0]  r2d_eve_cmd,  
input  wire [39:0]  r2d_eve_ptr,  
output wire         r2d_eve_ack,  
                              
output wire         d2r_stb,      
output wire         d2r_sof,       
output wire [71:0]  d2r_data,     
input  wire  [1:0]  d2r_rdy,       
                       
output wire         d2r_eve_stb,  
output wire [ 7:0]  d2r_eve_cmd,  
output wire [ 7:0]  d2r_eve_dev,  
output wire [39:0]  d2r_eve_ptr,  
input  wire         d2r_eve_ack
                                   
//input  wire [7:0]   bypass_tx_data,
//output wire         bypass_tx_ack,
//input  wire         bypass_tx_stb
);                           
//=============================================================================================
// parameters
//============================================================================================= 
parameter START_CLK_DIV         = 8'd14;//zegar 100MHz - 921600 b/s     //8'd108; //zegar 100MHz - 115200 b/s    
parameter START_RX_BUFF_PTR     = 39'h000000000;   
parameter START_TX_BUFF_PTR     = 39'd0;

localparam CMD_SET_EVE_DEST     = 8'h01;  
localparam CMD_UART_WDATA       = 8'h10;    
localparam CMD_UART_CLK_DIV     = 8'h11; 
localparam CMD_UART_TXBUFF_PTR  = 8'h12;
localparam CMD_UART_RXBUFF_PTR  = 8'h13;
localparam CMD_UART_TXBUFF_SEND = 8'h14;
//=============================================================================================
// variables                               
//============================================================================================= 
wire rsx = rst || soft_rst;   
//--------------------------------------------------------------------------------------------- 
wire r2d_eve_set_eve_dest_stb= r2d_eve_stb && (r2d_eve_cmd == CMD_SET_EVE_DEST);  
wire r2d_eve_clk_div_set_stb = r2d_eve_stb && (r2d_eve_cmd == CMD_UART_CLK_DIV);  
wire r2d_eve_uart_data_stb   = r2d_eve_stb && (r2d_eve_cmd == CMD_UART_WDATA);       
wire r2d_eve_txbuff_ptr_stb  = r2d_eve_stb && (r2d_eve_cmd == CMD_UART_TXBUFF_PTR);  
wire r2d_eve_txbuff_send     = r2d_eve_stb && (r2d_eve_cmd == CMD_UART_TXBUFF_SEND); 
wire r2d_eve_rxbuff_ptr_stb  = r2d_eve_stb && (r2d_eve_cmd == CMD_UART_RXBUFF_PTR);                
//--------------------------------------------------------------------------------------------- 
reg  [ 7:0] clk_div;        
//--------------------------------------------------------------------------------------------- 
reg  [ 7:0] eve_dest;       
                   
wire        rx_stb;
wire [ 7:0] rx_data;         
wire        rx_ack;       
                   
wire        tx_stb;
wire [ 7:0] tx_data;         
wire        tx_ack;
wire        tx_full;                                                                      
//--------------------------------------------------------------------------------------------- 
reg  [38:0] txbuff_ptr_base;  
reg  [31:0] txbuff_dat_cnt;
//--------------------------------------------------------------------------------------------- 
reg  [38:0] rxbuff_ptr_base;   
reg         rxbuff_ptr_reset;
//=============================================================================================  
always@(posedge clk or posedge rsx)
   if(rsx                       )eve_dest        <=                                         -1;  
else if(r2d_eve_set_eve_dest_stb)eve_dest        <=                           r2d_eve_ptr[7:0];
else                             eve_dest        <=                                   eve_dest;              
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rsx)
   if(rsx                      ) clk_div         <=                              START_CLK_DIV;  
else if(r2d_eve_clk_div_set_stb) clk_div         <=                           r2d_eve_ptr[7:0];
else                             clk_div         <=                                    clk_div;                             
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rsx)                                       
   if(rsx                      ) rxbuff_ptr_base <=                          START_RX_BUFF_PTR;                    
else if(r2d_eve_rxbuff_ptr_stb ) rxbuff_ptr_base <=                          r2d_eve_ptr[38:0];
else                             rxbuff_ptr_base <=                            rxbuff_ptr_base;                     
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rsx)
   if(rsx                      ) rxbuff_ptr_reset <=                                      1'b1;  
else if(r2d_eve_rxbuff_ptr_stb ) rxbuff_ptr_reset <=                                      1'b1;
else                             rxbuff_ptr_reset <=                                      1'b0;                     
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rsx)
   if(rsx                      ) txbuff_ptr_base <=                          START_TX_BUFF_PTR;  
else if(r2d_eve_txbuff_ptr_stb ) txbuff_ptr_base <=                          r2d_eve_ptr[38:0];
else                             txbuff_ptr_base <=                            txbuff_ptr_base;                     
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rsx)
   if(rsx                      ) txbuff_dat_cnt  <=                                      32'd0;  
else if(r2d_eve_txbuff_send    ) txbuff_dat_cnt  <=                          r2d_eve_ptr[31:0];
else                             txbuff_dat_cnt  <=                             txbuff_dat_cnt;      
//============================================================================================= 
rbus_uart_rx_pktform rx_data_packet_formater
(
.clk             (clk),
.rst             (rsx),  
                            
.i_stb           (rx_stb),       
.i_data          (rx_data),  
.i_ack           (rx_ack), 

.buff_ptr_base   (rxbuff_ptr_base),
.buff_ptr_reset  (rxbuff_ptr_reset),

.d2r_stb         (d2r_stb),
.d2r_sof         (d2r_sof),
.d2r_data        (d2r_data),
.d2r_rdy         (d2r_rdy)
);               
//============================================================================================= 
// serial input                                                                   
//============================================================================================= 
aser_rx_box aser_rx
(                             
.CLK             (clk),    
.RST             (rsx),    
                
.I_RxD           (RX),   
                
.O_STB           (rx_stb),       
.O_DATA          (rx_data),  
.O_ACK           (rx_ack),

.CFG_CLK_DIV     (clk_div)
// 200MHz -> 115200 b/s : 217
// 100MHz -> 115200 b/s : 108 
// 100MHz -> 921600 b/s : 14
);                                                                            
//============================================================================================= 
// serial output                                                                  
//============================================================================================= 
aser_tx_box aser_tx
(                             
.CLK             (clk),    
.RST             (rsx),    
                
.I_STB           (tx_stb),
.I_DATA          (tx_data),
.I_ACK           (tx_ack),                                
.I_FULL          (tx_full),
                 
.O_TxD           (TX),   
                 
.CFG_CLK_DIV     (clk_div)
// 200MHz -> 115200 b/s : 217
// 100MHz -> 115200 b/s : 108  
// 100MHz -> 921600 b/s : 14
);               
//--------------------------------------------------------------------------------------------- 
assign        tx_stb      =                                              r2d_eve_uart_data_stb;         
assign        tx_data     =                                                   r2d_eve_ptr[7:0];

//assign        tx_stb = r2d_eve_uart_data_stb || bypass_tx_stb;         
//assign        tx_data = (bypass_tx_stb)? bypass_tx_data : r2d_eve_ptr[7:0];
//assign        bypass_tx_ack = tx_ack && bypass_tx_stb;                                  
//============================================================================================= 
// events interface
assign        d2r_eve_stb =                                                               1'b0;  
assign        d2r_eve_dev =                                                           eve_dest;
assign        d2r_eve_ptr =                                                   {32'd0, rx_data};
assign        d2r_eve_cmd =                                                     CMD_UART_WDATA;                   

assign        r2d_eve_ack =                 r2d_eve_stb && !(!tx_ack && r2d_eve_uart_data_stb);
//--------------------------------------------------------------------------------------------- 
assign        r2d_rdy     =                                                               2'd3;      
//============================================================================================= 
endmodule
