//=============================================================================================
//    Main contributors                  
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module eco32_timer_box
(                                                                                                                               
input  wire         clk, 
input  wire         rst,        
                                      
// network interface                             
input  wire         ul_eve_stb,  
input  wire [ 7:0]  ul_eve_cmd,  
input  wire [35:0]  ul_eve_ptr,  
output wire         ul_eve_ack,       
                                   
output wire         dl_eve_stb,  
output wire [ 7:0]  dl_eve_cmd,  
output wire [ 7:0]  dl_eve_dev,  
output wire [35:0]  dl_eve_ptr,  
input  wire         dl_eve_ack  
);                                         
//=============================================================================================
// parameters
//============================================================================================= 
parameter  TIMER_NUMBER                     = 8'd0;

localparam START_CLK_DIV                    = 32'd10_000_000;       
localparam CMD_TIMER_SET_ENA                = 8'h30; 
localparam CMD_TIMER_SLOT_CFG               = 8'h31;    
localparam CMD_TIMER_VALID_SLOT_CNT         = 8'h32;    
localparam CMD_TIMER_CLK_DIV                = 8'h33;    
localparam CMD_TIMER_EVENT                  = 8'h34;
//=============================================================================================
// variables                                                                                                                                                                                                                                                            
//=============================================================================================
reg [27:0]  Trg_info_buff [0:255];
reg [31:0]  clk_div;                                                    
//--------------------------------------------------------------------------------------------- 
reg         timer_ena;
reg  [32:0] tic_cnt;    
reg  [19:0] timer_cnt; 
reg  [ 8:0] valid_slot_num; 
reg  [ 8:0] slot_ptr;
reg  [ 8:0] next_slot_ptr;         
reg  [27:0] next_slot_datax;
reg  [27:0] next_slot_data;  
reg  [ 7:0] curr_slot_id; 
reg         curr_slot_ena;                                                                      
//----------------------------------------------------------------------------------------------
wire        next_slot_ena;          
wire [18:0] next_slot_cv;            
wire [ 7:0] next_slot_id;                                           
//----------------------------------------------------------------------------------------------
reg         eve_o_ena;
reg  [ 7:0] eve_o_id;
//---------------------------------------------------------------------------------------------
integer     i;
//=============================================================================================      
wire ul_eve_clk_div_set_stb     =       ul_eve_stb && (ul_eve_cmd == CMD_TIMER_CLK_DIV       );     
wire ul_eve_set_ena_stb         =       ul_eve_stb && (ul_eve_cmd == CMD_TIMER_SET_ENA       ); 
wire ul_eve_slot_cfg_stb        =       ul_eve_stb && (ul_eve_cmd == CMD_TIMER_SLOT_CFG      ); 
wire ul_eve_valid_slot_num_stb  =       ul_eve_stb && (ul_eve_cmd == CMD_TIMER_VALID_SLOT_CNT);                                                                 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
     if(rst                     )   timer_ena <=                                          1'b0;
else if(ul_eve_set_ena_stb      )   timer_ena <=                                 ul_eve_ptr[0];
else                                timer_ena <=                                     timer_ena;                                         
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
     if(rst                     )   clk_div <=                                   START_CLK_DIV;  
else if(ul_eve_clk_div_set_stb  )   clk_div <=                                ul_eve_ptr[31:0];
else                                clk_div <=                                         clk_div;                                                                 
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
     if(rst                     )   valid_slot_num <=                                     9'd0;  
else if(ul_eve_valid_slot_num_stb)  valid_slot_num <=                          ul_eve_ptr[8:0];
else                                valid_slot_num <=                           valid_slot_num;                                                                                 
//---------------------------------------------------------------------------------------------
wire tic_f = tic_cnt[32];
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
     if(rst                     )   tic_cnt <=                                           33'd0; 
else if(!timer_ena              )   tic_cnt <=                                           33'd0; 
else if(tic_f                   )   tic_cnt <=                                 clk_div - 33'd2;
else                                tic_cnt <=                                 tic_cnt - 33'd1;                                                                      
//--------------------------------------------------------------------------------------------- 
wire curr_slot_end = timer_cnt[19];
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
     if(rst                     )   timer_cnt <=                                         20'd0; 
else if(!timer_ena              )   timer_cnt <=            {1'b0, next_slot_cv[18:0]} - 20'd1; 
else if(curr_slot_end           )   timer_cnt <=            {1'b0, next_slot_cv[18:0]} - 20'd1; 
else if(tic_f                   )   timer_cnt <=                             timer_cnt - 20'd1;
else                                timer_cnt <=                             timer_cnt - 20'd0;                                         
//--------------------------------------------------------------------------------------------- 
wire last_slot_f = (slot_ptr == (valid_slot_num - 1));
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
     if(rst                     )   next_slot_ptr <=                                      9'd0; 
else if(!timer_ena              )   next_slot_ptr <=                                      9'd0;
else if(last_slot_f             )   next_slot_ptr <=                                      9'd0;  
else                                next_slot_ptr <=                           slot_ptr + 9'd1;     
//============================================================================================= 
// memory                                                                                                                                                                                                                           
//=============================================================================================     
wire        ul_eve_slot_cfg_ena         =                                       ul_eve_ptr[35];         
wire [18:0] ul_eve_slot_cfg_cv          =                                     ul_eve_ptr[34:16]; 
wire [ 7:0] ul_eve_slot_cfg_slot_num    =                                     ul_eve_ptr[15: 8];
wire [ 7:0] ul_eve_slot_cfg_id          =                                     ul_eve_ptr[ 7: 0]; 
//---------------------------------------------------------------------------------------------- 
initial for(i = 0; i<256; i=i+1) Trg_info_buff [i] <= 36'd0;   
always@(posedge clk) 
  begin                                       
      if(ul_eve_slot_cfg_stb) Trg_info_buff [ul_eve_slot_cfg_slot_num] <= {ul_eve_slot_cfg_ena, ul_eve_slot_cfg_cv, ul_eve_slot_cfg_id};
  end                                         
//----------------------------------------------------------------------------------------------  
always@(posedge clk)       
  begin     
      next_slot_datax <= Trg_info_buff [next_slot_ptr];                                                                      
        next_slot_data  <= next_slot_datax; 
  end               
//----------------------------------------------------------------------------------------------
assign      next_slot_ena               =                                    next_slot_data[27];            
assign      next_slot_cv                =                                 next_slot_data[26: 8];             
assign      next_slot_id                =                                 next_slot_data[ 7: 0]; 
//---------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
     if(rst                     )   slot_ptr <=                                           -9'd1;  
else if(curr_slot_end           )   slot_ptr <=                                   next_slot_ptr;
else if(ul_eve_set_ena_stb      )   slot_ptr <=                                            9'd0; 
else                                slot_ptr <=                                        slot_ptr; 
//---------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
     if(rst                     )   curr_slot_id  <=                                       8'd0;  
else if(!timer_ena              )   curr_slot_id  <=                               next_slot_id;     
else if(curr_slot_end           )   curr_slot_id  <=                               next_slot_id;     
else                                curr_slot_id  <=                               curr_slot_id;     
//---------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
     if(rst                     )   curr_slot_ena  <=                                      8'd0;  
else if(!timer_ena              )   curr_slot_ena  <=                             next_slot_ena;     
else if(curr_slot_end           )   curr_slot_ena  <=                             next_slot_ena;     
else                                curr_slot_ena  <=                             curr_slot_ena;
//---------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
     if(rst                     )   eve_o_ena <=                                           1'd0; 
else if(!timer_ena              )   eve_o_ena <=                                           1'd0; 
else if(dl_eve_ack              )   eve_o_ena <=                                           1'd0;  
else if(curr_slot_end           )   eve_o_ena <=                                  curr_slot_ena;
else if(ul_eve_set_ena_stb      )   eve_o_ena <=                                           1'd0; 
else                                eve_o_ena <=                                      eve_o_ena;    
//---------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
     if(rst                     )   eve_o_id  <=                                           8'd0;     
else if(curr_slot_end           )   eve_o_id  <=                                   curr_slot_id;     
else                                eve_o_id  <=                                       eve_o_id;    
//============================================================================================= 
// output                                                                                           
//============================================================================================= 
// events interface
assign        dl_eve_stb =                                                           eve_o_ena;                         
assign        dl_eve_ptr =                                          {28'd0, TIMER_NUMBER[7:0]};
assign        dl_eve_cmd =                                                     CMD_TIMER_EVENT; 
assign        dl_eve_dev =                                                       eve_o_id[7:0];
//--------------------------------------------------------------------------------------------- 
assign        ul_eve_ack =                                                          ul_eve_stb;           
//============================================================================================= 
endmodule
