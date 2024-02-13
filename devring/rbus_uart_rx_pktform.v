//=============================================================================================
//    Main contributors                
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rbus_uart_rx_pktform   
(                                                                                                                               
input  wire         clk, 
input  wire         rst,    
              
// input data interface 
input  wire         i_stb,  
input  wire [ 7:0]  i_data, 
output wire         i_ack,  
                        
// network interface 
input  wire [38:0]  buff_ptr_base,
input  wire         buff_ptr_reset,

output wire         d2r_stb,      
output wire         d2r_sof,       
output wire [71:0]  d2r_data,     
input  wire  [1:0]  d2r_rdy
);                                     
//============================================================================================= 
localparam RXDMA_WAIT           = 1;
localparam RXDMA_HEAD           = 2; 
localparam RXDMA_WRITE          = 5;
localparam RXDMA_END            = 6;                        
//---------------------------------------------------------------------------------------------  
wire [38:0] rxbuff_ptr_base = buff_ptr_base;                                                                        
reg  [ 3:0] rxbuff_curr_page_dword;                                                                  
reg  [ 2:0] rxbuff_curr_dword_byte;                                                                        
reg  [38:0] rxbuff_ptr_curr_page;    
reg  [71:0] d2r0_data;      
reg  [71:0] d2r1_data;     
reg         d2r1_stb;      
reg         d2r1_sof;
reg  [ 3:0] rxdma_dword_cnt;
wire        rx_end_pkt;
integer     rxdma_state;                                     
//---------------------------------------------------------------------------------------------   
wire rxdma_start_pkt  = (rxdma_state == RXDMA_WAIT) && i_stb && d2r_rdy[1];                              
wire rxdma_put_head   = (rxdma_state == RXDMA_HEAD);        
wire rxdma_send_end   = (rxdma_state == RXDMA_END );
wire rxdma_next_byte  = rxdma_send_end;                    
wire rxdma_next_dword = rxdma_next_byte  && (rxbuff_curr_dword_byte == 3'd7);  
wire rxdma_next_pkt   = rxdma_next_dword && (rxbuff_curr_page_dword == 4'd7);

wire rxdma_put_byte   = (rxdma_dword_cnt == rxbuff_curr_page_dword);                        
//============================================================================================= 
always@(posedge clk or posedge rst)
 if(rst)                                               rxdma_state  <=             RXDMA_WAIT ;
 else case(rxdma_state)                                                           
 RXDMA_WAIT:              if(rxdma_start_pkt)          rxdma_state  <=             RXDMA_HEAD ;
                     else                              rxdma_state  <=             RXDMA_WAIT ;
 RXDMA_HEAD:                                           rxdma_state  <=             RXDMA_WRITE;     
 RXDMA_WRITE:             if(rx_end_pkt  )             rxdma_state  <=             RXDMA_END  ;
                     else                              rxdma_state  <=             RXDMA_WRITE;
 RXDMA_END:                                            rxdma_state  <=             RXDMA_WAIT ;
 endcase                                                                                                    
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
   if(rst                     ) rxbuff_ptr_curr_page   <=                                39'd0;  
else if(buff_ptr_reset        ) rxbuff_ptr_curr_page   <=                rxbuff_ptr_base[38:0];                
else if(rxdma_next_pkt        ) rxbuff_ptr_curr_page   <=         rxbuff_ptr_curr_page +39'd64;
else                            rxbuff_ptr_curr_page   <=         rxbuff_ptr_curr_page + 39'd0;               
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
   if(rst                     ) rxbuff_curr_page_dword <=                                 4'd0;  
else if(buff_ptr_reset        ) rxbuff_curr_page_dword <=                                 4'd0;              
else if(rxdma_next_pkt        ) rxbuff_curr_page_dword <=                                 4'd0;                
else if(rxdma_next_dword      ) rxbuff_curr_page_dword <=       rxbuff_curr_page_dword +  4'd1;
else                            rxbuff_curr_page_dword <=       rxbuff_curr_page_dword +  4'd0;               
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
   if(rst                     ) rxbuff_curr_dword_byte <=                                 3'd0;  
else if(buff_ptr_reset        ) rxbuff_curr_dword_byte <=                                 3'd0;                
else if(rxdma_next_byte       ) rxbuff_curr_dword_byte <=       rxbuff_curr_dword_byte +  3'd1;
else                            rxbuff_curr_dword_byte <=       rxbuff_curr_dword_byte +  3'd0;             
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
    if(rst                    ) d2r0_data <=                                             72'd0;
else                                                      
    case(rxbuff_curr_dword_byte)                                                    
 3'd0:                          d2r0_data <=                {8'h80,        i_data[7:0], 56'h0};                  
 3'd1:                          d2r0_data <=                {8'h40,  8'h0, i_data[7:0], 48'h0};                  
 3'd2:                          d2r0_data <=                {8'h20, 16'h0, i_data[7:0], 40'h0};                  
 3'd3:                          d2r0_data <=                {8'h10, 24'h0, i_data[7:0], 32'h0};                  
 3'd4:                          d2r0_data <=                {8'h08, 32'h0, i_data[7:0], 24'h0};                  
 3'd5:                          d2r0_data <=                {8'h04, 40'h0, i_data[7:0], 16'h0};                  
 3'd6:                          d2r0_data <=                {8'h02, 48'h0, i_data[7:0],  8'h0};                  
 3'd7:                          d2r0_data <=                {8'h01, 56'h0, i_data[7:0]       };                  
 default:                       d2r0_data <=                {8'h01, 56'h0, i_data[7:0]       }; 
 endcase                                                  
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
   if(rst                     ) d2r1_data <=                                             72'd0;  
else if(rxdma_put_head        ) d2r1_data <=  {2'b10, 2'd0, 28'h0, 1'b1, rxbuff_ptr_curr_page[38:3],3'd2};                
else if(rxdma_put_byte        ) d2r1_data <=                                         d2r0_data;
else                            d2r1_data <=                                             72'd0;            
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)                            
   if(rst                     ) d2r1_stb  <=                                              1'b0; 
else if(rxdma_put_head        ) d2r1_stb  <=                                              1'b1; 
else                            d2r1_stb  <=                               !rxdma_dword_cnt[3];          
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
   if(rst                     ) d2r1_sof  <=                                              1'b0; 
else if(rxdma_put_head        ) d2r1_sof  <=                                              1'b1; 
else                            d2r1_sof  <=                                              1'b0;          
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
   if(rst                     ) rxdma_dword_cnt <=                                        4'h8;  
else if(rxdma_put_head        ) rxdma_dword_cnt <=                                        4'd0; 
else if(!rxdma_dword_cnt[3]   ) rxdma_dword_cnt <=                        rxdma_dword_cnt+4'h1;
else                            rxdma_dword_cnt <=                        rxdma_dword_cnt+4'h0;                   
//--------------------------------------------------------------------------------------------- 
assign rx_end_pkt   =                                                  rxdma_dword_cnt == 4'h7;
assign i_ack        =                                                  i_stb && rxdma_send_end;                                                      
//=============================================================================================   
// memory interface
assign d2r_stb      =                                                                 d2r1_stb;   
assign d2r_sof      =                                                                 d2r1_sof;    
assign d2r_data     =                                                                d2r1_data;     
//=============================================================================================     
endmodule
