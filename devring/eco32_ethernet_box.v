//=============================================================================================
//    Main contributors             
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module eco32_ethernet_box   
(                                                                                                                               
input  wire         clk, 
input  wire         rst,    
                            
// PHY interface
input  wire         RX,   
output wire         TX,     
                      
// network interface
input  wire         soft_rst,

input  wire         ul_stb,                              
input  wire         ul_sof, 
input  wire [71:0]  ul_data,
output wire  [1:0]  ul_af,  
                
input  wire         ul_eve_stb,  
input  wire [ 7:0]  ul_eve_cmd,  
input  wire [35:0]  ul_eve_ptr,  
output wire         ul_eve_ack,  
                              
output wire         dl_stb,      
output wire         dl_sof,       
output wire [71:0]  dl_data,     
input  wire  [1:0]  dl_af,       
                       
output wire         dl_eve_stb,  
output wire [ 7:0]  dl_eve_cmd,  
output wire [ 7:0]  dl_eve_dev,  
output wire [35:0]  dl_eve_ptr,  
input  wire         dl_eve_ack
);                           
//=============================================================================================
// parameters
//============================================================================================= 
localparam CMD_NULL       = 8'h00;    
localparam CMD_ADD_RX_BUFF_PTR  = 8'h01;    
localparam CMD_ADD_TX_BUFF_PTR  = 8'h02;    
localparam CMD_GET_STATUS       = 8'h03;  
//=============================================================================================
// variables                               
//============================================================================================= 
wire rsx = rst || soft_rst;   
//--------------------------------------------------------------------------------------------- 
//wire ul_eve_set_eve_dest_stb= ul_eve_stb && (ul_eve_cmd == CMD_SET_EVE_DEST);  
//wire ul_eve_clk_div_set_stb = ul_eve_stb && (ul_eve_cmd == CMD_UART_CLK_DIV);  
//wire ul_eve_uart_data_stb   = ul_eve_stb && (ul_eve_cmd == CMD_UART_WDATA);       
//wire ul_eve_txbuff_ptr_stb  = ul_eve_stb && (ul_eve_cmd == CMD_UART_TXBUFF_PTR);  
//wire ul_eve_txbuff_send     = ul_eve_stb && (ul_eve_cmd == CMD_UART_TXBUFF_SEND); 
//wire ul_eve_rxbuff_ptr_stb  = ul_eve_stb && (ul_eve_cmd == CMD_UART_RXBUFF_PTR);                
//--------------------------------------------------------------------------------------------- 
//reg  [ 7:0] clk_div;        
////--------------------------------------------------------------------------------------------- 
//reg  [ 7:0] eve_dest;       
//                   
//wire        rx_stb;
//wire [ 7:0] rx_data;         
//wire        rx_ack;       
//                   
//wire        tx_stb;
//wire [ 7:0] tx_data;         
//wire        tx_ack;
//wire        tx_full;                                                                      
////--------------------------------------------------------------------------------------------- 
//reg  [35:0] txbuff_ptr_base;  
//reg  [31:0] txbuff_dat_cnt;
////--------------------------------------------------------------------------------------------- 
//reg  [35:0] rxbuff_ptr_base;   
//reg         rxbuff_ptr_reset;
////=============================================================================================  
//always@(posedge clk or posedge rsx)
//   if(rsx                      )eve_dest <=              -1;  
//else if(ul_eve_set_eve_dest_stb)eve_dest <= ul_eve_ptr[7:0];
//else                            eve_dest <=        eve_dest;              
////--------------------------------------------------------------------------------------------- 
//always@(posedge clk or posedge rsx)
//   if(rsx                     ) clk_div <= START_CLK_DIV;  
//else if(ul_eve_clk_div_set_stb) clk_div <= ul_eve_ptr[7:0];
//else                            clk_div <=     clk_div;                             
////--------------------------------------------------------------------------------------------- 
//always@(posedge clk or posedge rsx)                                       
//   if(rsx                     ) rxbuff_ptr_base <=   START_RX_BUFF_PTR;                    
//else if(ul_eve_rxbuff_ptr_stb ) rxbuff_ptr_base <=    ul_eve_ptr[35:0];
//else                            rxbuff_ptr_base <=     rxbuff_ptr_base;                     
////--------------------------------------------------------------------------------------------- 
//always@(posedge clk or posedge rsx)
//   if(rsx                     ) rxbuff_ptr_reset <=               1'b1;  
//else if(ul_eve_rxbuff_ptr_stb ) rxbuff_ptr_reset <=               1'b1;
//else                            rxbuff_ptr_reset <=               1'b0;                     
////--------------------------------------------------------------------------------------------- 
//always@(posedge clk or posedge rsx)
//   if(rsx                     ) txbuff_ptr_base <=   START_TX_BUFF_PTR;  
//else if(ul_eve_txbuff_ptr_stb ) txbuff_ptr_base <=    ul_eve_ptr[35:0];
//else                            txbuff_ptr_base <= ---    txbuff_ptr_base;                      
////------------------------------------------------------------------------------------------  
//always@(posedge clk or posedge rsx)
//   if(rsx                     ) txbuff_dat_cnt  <=               32'd0;  
//else if(ul_eve_txbuff_send    ) txbuff_dat_cnt  <=    ul_eve_ptr[35:0];
//else                            txbuff_dat_cnt  <=      txbuff_dat_cnt;      
////============================================================================================= 
//eco32_uart_rx_pktform rx_data_packet_formater
//(
//.clk            (clk),
//.rst            (rsx),  
//                           
//.i_stb          (rx_stb),       
//.i_data         (rx_data),  
//.i_ack          (rx_ack), 
//
//.buff_ptr_base  (rxbuff_ptr_base),
//.buff_ptr_reset (rxbuff_ptr_reset),
//
//.dl_stb         (dl_stb),
//.dl_sof         (dl_sof),
//.dl_data        (dl_data),
//.dl_af          (dl_af)
//);               
////============================================================================================= 
//// serial input                                                                   
////============================================================================================= 
//aser_rx_box aser_rx
//(                             
//.CLK            (clk),    
//.RST            (rsx),    
//            
//.I_RxD          (RX),   
//            
//.O_STB          (rx_stb),       
//.O_DATA         (rx_data),  
//.O_ACK          (rx_ack),
//
//.CFG_CLK_DIV (clk_div)
//// 200MHz -> 115200 b/s : 217
//// 100MHz -> 115200 b/s : 108 
//// 100MHz -> 921600 b/s : 14
//);                                                                            
////============================================================================================= 
//// serial output                                                                  
////============================================================================================= 
//aser_tx_box aser_tx
//(                             
//.CLK            (clk),    
//.RST            (rsx),    
//            
//.I_STB          (tx_stb),
//.I_DATA           (tx_data),
//.I_ACK          (tx_ack),                                
//.I_FULL         (tx_full),
//
//.O_TxD          (TX),   
//
//.CFG_CLK_DIV (clk_div)
//// 200MHz -> 115200 b/s : 217
//// 100MHz -> 115200 b/s : 108  
//// 100MHz -> 921600 b/s : 14
//);               
////--------------------------------------------------------------------------------------------- 
//assign        tx_stb  = ul_eve_uart_data_stb;         
//assign        tx_data = ul_eve_ptr[7:0];
//
////assign        tx_stb = ul_eve_uart_data_stb || bypass_tx_stb;         
////assign        tx_data = (bypass_tx_stb)? bypass_tx_data : ul_eve_ptr[7:0];
////assign        bypass_tx_ack = tx_ack && bypass_tx_stb;                                  
////============================================================================================= 
//// events interface
//assign        dl_eve_stb = 1'b0;  
//assign        dl_eve_dev = eve_dest;
//assign        dl_eve_ptr = {28'd0, rx_data};
//assign        dl_eve_cmd = CMD_UART_WDATA;                   
//
//assign        ul_eve_ack = ul_eve_stb && !(!tx_ack && ul_eve_uart_data_stb);
////--------------------------------------------------------------------------------------------- 
//assign        ul_af      = 2'd0;      
////============================================================================================= 
endmodule
