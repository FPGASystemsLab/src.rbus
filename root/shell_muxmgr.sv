//=============================================================================================
//    Main contributors
//      - Jakub Siast         
// 17.11.2015 - dodane wysylanie pakietu z potwierdzeniem zapisu
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module shell_muxmgr
(
input  wire                 clk,
input  wire                 rst,   

input  wire                 i_stb,
input  wire                 i_sof,
input  wire     [71:0]      i_data,
output wire      [1:0]      i_rdy,

output wire                 o_stb,
output wire                 o_sof,
output wire     [71:0]      o_data,
input  wire      [1:0]      o_rdy        
);                                
//=============================================================================================
// parameters
//=============================================================================================                             
parameter        SEND_WR_FB          =                                                  "TRUE"; // "TRUE", "FALSE"     
//=============================================================================================
// parameters check
//=============================================================================================   
// pragma translate_off
initial
    begin
        if((SEND_WR_FB != "TRUE") && (SEND_WR_FB != "FALSE"))        
            begin
            $display( "%m !!!ERROR!!! SEND_WR_FB = %s, is out of range (\"TRUE\" \"FALSE\")", SEND_WR_FB );
            $finish;
            end 
    end
// pragma translate_on                       
/**************************************************************************
* find_log2
*   Returns the 'log2' value for the input value for the supported ratios
***************************************************************************/
function integer find_log2;
  input integer int_val;
  integer i,j;
  begin
    i = 1;
    j = 0;
    for (i = 1; i < int_val; i = i*2) begin
      j = j + 1;
    end
    find_log2 = j;
  end
endfunction                                                                                             
//=============================================================================================  
localparam [15:0] DEV_VER = 16'h02_01;
localparam [15:0] DEV_CAP = 16'h00_01;
//---------------------------------------------------------------------------------------------                                      
localparam [31:0] MUX_NUM = 16384;                                                               
localparam [15:0] LOG2_MUX_NUM = 14; 
//---------------------------------------------------------------------------------------------                                      
initial begin                  
      if (LOG2_MUX_NUM != find_log2(MUX_NUM)) begin
         $display("FAILURE : LOG2_MUX_NUM is not log2 of MUX_NUM.");
         $finish;
      end   
end          
//---------------------------------------------------------------------------------------------                                      
localparam [47:0] MTX_INFO  =                                 {DEV_VER, DEV_CAP, LOG2_MUX_NUM};
//=============================================================================================
// mutex buffer                                                                 
//=============================================================================================
reg   [ 0:0]    mutexTab [0:(MUX_NUM-32'd1)] /* synthesis syn_ramstyle="no_rw_check" */;  
//---------------------------------------------------------------------------------------------
wire  [13:0]    mutexTabA_addrx;   
wire            mutexTabA_wr;            
reg             mutexTabA_dataOutx/* synthesis syn_replicate =  0 */; 
reg             mutexTabA_dataOut/* synthesis syn_replicate =  0 */; 
wire            mutexTabA_dataIn;  
//---------------------------------------------------------------------------------------------
wire  [13:0]    mutexTabB_addrx;   
wire            mutexTabB_wr;      
reg             mutexTabB_dataOutx/* synthesis syn_replicate =  0 */; 
reg             mutexTabB_dataOut/* synthesis syn_replicate =  0 */; 
wire            mutexTabB_dataIn;          
//============================================================================================= 
// input parsing                  
//============================================================================================= 
wire            i_head_stb;  
wire  [ 1:0]    i_mode;

wire            i_len;
wire            i_rd1; 
wire            i_rd8;
wire            i_wra; 
wire            i_upda; 
wire            i_res_len;

wire            i_rd;  
wire            i_wr;
wire            i_rd_wr;                                                                  
//----------------------------------------------------------------------------------------------                                      
wire  [13:0]    i_addr;                                         
wire            i_wr_dat;                                                                 
wire   [3:0]    i_m0_sel;
//----------------------------------------------------------------------------------------------                                      
reg   [14:0]    init_cnt;  
wire            init_bsy;
//=============================================================================================
// s1                                                                
//=============================================================================================  
reg             s1_stb_hdr;   
reg             s1_stb_dat;  
reg             s1_wr;   
reg             s1_rd;                                               
reg   [71:0]    s1_header;  
reg             s1_bsy;
reg             s1_inf_f; 
wire            s1_dat_f; 
reg             s1_res_len; 
wire            s1_dat_pen;
reg   [ 3:0]    s1_dat_cnt;
//----------------------------------------------------------------------------------------------                                      
reg   [13:0]    s1_addr;                                         
reg             s1_wr_dat;                                                                                                                              
//=============================================================================================
// s2                                                                
//=============================================================================================   
reg             s2_stb_hdr;   
reg             s2_stb_dat; 
reg             s2_stb;  
reg             s2_wr;   
reg             s2_rd;                                           
reg   [71:0]    s2_header;                                        
reg   [13:0]    s2_addr;                                         
reg             s2_wr_dat;   
reg             s2_bsy; 
reg             s2_inf_f;   
wire            s2_dat_f;  
reg             s2_res_len;                                                              
//---------------------------------------------------------------------------------------------- 
wire            s2_result;                                                                                                                        
//=============================================================================================
// s3                                                                
//=============================================================================================   
reg             s3_stb_hdr;   
reg             s3_stb_dat; 
reg             s3_stb_inf; 
reg             s3_stb;   
reg             s3_rd;     
reg             s3_wr;                                           
reg   [71:0]    s3_header;                                        
reg   [13:0]    s3_addr;                                         
reg             s3_wr_dat;                                                                       
reg             s3_result;  
reg             s3_bsy; 
reg             s3_res_len; 
reg             s3_wr_ack;
//----------------------------------------------------------------------------------------------
reg             s4_stb;   
reg             s4_sof;   
reg   [71:0]    s4_data;
reg             s4_res_len; 
//----------------------------------------------------------------------------------------------
reg             s4_inc;
reg             s4_clr;
//----------------------------------------------------------------------------------------------
reg    [7:0]    s5_cnt;                                        
//============================================================================================= 
// input parsing                  
//============================================================================================= 
assign          i_head_stb  =                                                    i_stb & i_sof; 
assign          i_mode      =                                                      i_data[1:0];

assign          i_len       =                                                       i_data[39];
assign          i_rd1       =                                             i_data[1:0] == 2'b00; 
assign          i_rd8       =                                             i_data[1:0] == 2'b01;
assign          i_wra       =                                             i_data[1:0] == 2'b10; 
assign          i_upda      =                                             i_data[1:0] == 2'b11;
assign          i_res_len   =                                         i_rd8 | (i_upda & i_len);

assign          i_wr        =              !init_bsy &&         (i_wra | i_upda) && i_head_stb;  
assign          i_rd        =                           (i_rd1 | i_rd8 | i_upda) && i_head_stb;
assign          i_rd_wr     =                                            i_upda  && i_head_stb; 
assign          i_addr      =                                                     i_data[16:3];
//---------------------------------------------------------------------------------------------
assign          i_wr_dat    =                                                     i_data[   0];  
//---------------------------------------------------------------------------------------------
assign          i_m0_sel    =                                                     i_data[ 3:0];  
//=============================================================================================       
// Mutex table - 1 BRAMs in true dual port mode 1024x1b
//  READ FIRST Mode!!! Previous value is read first prior to writing!
//============================================================================================= 
always@(posedge clk)
 begin                                              
     if(mutexTabA_wr) 
         mutexTab [mutexTabA_addrx] <= mutexTabA_dataIn;  
 end 
always@(posedge clk)
  begin                                              
      if(mutexTabB_wr) 
          mutexTab [mutexTabB_addrx] <= mutexTabB_dataIn;   
  end                                   
//---------------------------------------------------------------------------------------------- 
always@(posedge clk)           
  begin                                                                                                   
      mutexTabA_dataOutx <= mutexTab [mutexTabA_addrx];      
      if(rst) mutexTabA_dataOut  <= 1'd0;
      else    mutexTabA_dataOut  <= mutexTabA_dataOutx;                                      
  end
always@(posedge clk)                                                                                                                                                                 
  begin                                                                                                   
      mutexTabB_dataOutx <= mutexTab [mutexTabB_addrx];      
      if(rst) mutexTabB_dataOut  <= 1'd0;
      else    mutexTabB_dataOut  <= mutexTabB_dataOutx;
  end                                                                                                     
//=============================================================================================  
assign mutexTabA_addrx  =                                                              s1_addr;  
assign mutexTabA_dataIn =                                                             i_wr_dat;      
assign mutexTabA_wr     =                                                                s1_wr;         
//============================================================================================= 
always@(posedge clk or posedge rst)                                                                     
 if(rst)                                init_cnt    <=              'd0;                           
 else if(init_bsy               )       init_cnt    <=   init_cnt + 'd1;             
 else                                   init_cnt    <=   init_cnt + 'd0;                       
//----------------------------------------------------------------------------------------------   
assign init_bsy = !init_cnt[14];                                                                                       
//---------------------------------------------------------------------------------------------- 
assign mutexTabB_addrx  =                                                        init_cnt[13:0];
assign mutexTabB_dataIn =                                                                  1'b0; 
assign mutexTabB_wr     =                                                              init_bsy; 
//=============================================================================================
// s1                                                                
//============================================================================================= 
always@(posedge clk or posedge rst)        
 if(  rst )
     begin                                                                                        
                                        s1_stb_hdr <=                                     1'b0;  
                                        s1_stb_dat <=                                     1'b0; 
                                        s1_wr      <=                                     1'b0; 
                                        s1_rd      <=                                     1'b0; 
                                        s1_wr_dat  <=                                     1'b0;                               
                                        s1_bsy     <=                                     1'd1;
                                        s1_dat_cnt <=                                     4'hF;
     end
 else 
     begin                                                                                       
                                        s1_stb_hdr <= i_head_stb && (i_rd | (i_wr & (SEND_WR_FB == "TRUE")));  
                                        s1_wr      <=                                     i_wr; 
                                        s1_rd      <=                                     i_rd; 
                                        s1_stb_dat <=                 s1_stb_hdr || s1_dat_pen;  
                                        s1_wr_dat  <=                                 i_wr_dat;
                                        s1_bsy     <=                                 init_bsy; 
                                        s1_dat_cnt <= (s1_stb_hdr)?  (s1_res_len? 4'h7 : 4'hF):
                                                      (s1_dat_pen)?   s1_dat_cnt - 4'd1 : 4'hF; 
     end                                                                                       

always@(posedge clk)                    s1_header  <= (i_head_stb)?         i_data : s1_header; 
always@(posedge clk)                    s1_res_len <= (i_head_stb)?     i_res_len : s1_res_len;
always@(posedge clk)                    s1_addr    <= (i_head_stb)?         i_addr :   s1_addr;
always@(posedge clk)                    s1_inf_f   <= (i_head_stb)?       ~|i_addr :  s1_inf_f; 
//--------------------------------------------------------------------------------------------- 
assign          s1_dat_f   =                                                         !s1_inf_f; 
assign          s1_dat_pen =                                                    !s1_dat_cnt[3];       
//=============================================================================================
// s2                                                                
//============================================================================================= 
always@(posedge clk or posedge rst)        
 if(  rst )
     begin                                                                                       
                                        s2_stb_hdr <=                                     1'b0;  
                                        s2_stb_dat <=                                     1'b0;  
                                        s2_stb     <=                                     1'b0;   
                                        s2_wr      <=                                     1'b0; 
                                        s2_rd      <=                                     1'b0; 
                                        s2_wr_dat  <=                                     1'd0;  
                                        s2_bsy     <=                                     1'd1;
     end
 else  
     begin                                                                                 
                                        s2_stb_hdr <=                 s1_stb_hdr              ;   
                                        s2_stb_dat <=                               s1_stb_dat;    
                                        s2_stb     <=                 s1_stb_hdr || s1_stb_dat;  
                                        s2_wr      <=                                    s1_wr; 
                                        s2_rd      <=                                    s1_rd; 
                                        s2_wr_dat  <=                                s1_wr_dat;  
                                        s2_bsy     <=                                   s1_bsy;
     end                                                                                          

always@(posedge clk)                    s2_header  <= {2'b10, s1_header[69:40], s1_res_len, s1_header[38:0]}; 
always@(posedge clk)                    s2_addr    <=                                  s1_addr;  
always@(posedge clk)                    s2_inf_f   <=                                 s1_inf_f;  
always@(posedge clk)                    s2_res_len <=                               s1_res_len;
//--------------------------------------------------------------------------------------------- 
assign          s2_dat_f   =                                                         !s2_inf_f;
assign          s2_result  =//({s3_wr, s3_rd} == 2'b00)?                     mutexTabA_dataOut: 
                              ({s3_wr, s3_rd} == 2'b01)?                     mutexTabA_dataOut: 
                            //({s3_wr, s3_rd} == 2'b10)?         s2_wr_dat ^ mutexTabA_dataOut: 
                            /*({s3_wr, s3_rd} == 2'b11)?*/       s2_wr_dat ^ mutexTabA_dataOut; // if 0 and 0 is to be writen than result is "false"! Free mutex was tryed to be released                                                                                                                                          
//=============================================================================================
// s3                                                               
//============================================================================================= 
always@(posedge clk or posedge rst)        
 if(  rst )
     begin                                                                                       
                                        s3_stb_hdr <=                                      'b0;  
                                        s3_stb_dat <=                                      'b0;  
                                        s3_stb_inf <=                                      'b0;  
                                        
                                        s3_stb     <=                                     1'b0; 
                                        s3_rd      <=                                     1'b0; 
                                        s3_wr      <=                                     1'b0; 
                                        s3_wr_dat  <=                                     1'd0; 
                                        s3_result  <=                                     1'd0;
                                        s3_bsy     <=                                     1'd1;
     end
 else  
     begin                                                                                 
                                        s3_stb_hdr <=                               s2_stb_hdr;
                                        s3_stb_dat <=                    s2_dat_f & s2_stb_dat;    
                                        s3_stb_inf <=                    s2_inf_f & s2_stb_dat;    
                                        
                                        s3_rd      <=                                    s2_rd;
                                        s3_wr      <=                                    s2_wr;
                                        s3_stb     <=                               s2_stb    ; 
                                        s3_wr_dat  <=                                s2_wr_dat; 
                                        s3_result  <=                                s2_result; 
                                        s3_bsy     <=                                   s2_bsy;
     end                                                                                      

always@(posedge clk)                    s3_header  <= {2'b10, s2_header[69:40], s2_res_len, s2_header[38:0]}; 
always@(posedge clk)                    s3_addr    <=                                  s2_addr; 
always@(posedge clk)                    s3_res_len <=                               s2_res_len; 
always@(posedge clk)                    s3_wr_ack  <= (s3_header[1:0] == 2'b10) & (SEND_WR_FB == "TRUE");   
//============================================================================================= 
// init/release counter
//============================================================================================= 
always@(posedge clk or posedge rst)        
 if(  rst )                        s4_inc     <=                                           'd0;
 else                              s4_inc     <= !s2_stb_dat & s3_stb && s3_stb_inf && s3_header[2:0]=='d3; // update
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)        
 if(  rst )                        s4_clr     <=                                           'd0;
 else                              s4_clr     <= 1'b0;//!s2_stb_dat & s3_stb && s3_stb_inf && s3_header[2:0]=='d2; // write 
//============================================================================================= 
always@(posedge clk or posedge rst)        
 if(  rst )                        s5_cnt     <=                                           'd0;  
 else if(s4_inc)                   s5_cnt     <=                                  s5_cnt + 'd1;  
 else if(s4_clr)                   s5_cnt     <=                                           'd0; 
 else                              s5_cnt     <=                                  s5_cnt      ; 
//============================================================================================= 
assign      i_rdy         =                                                        {2{&o_rdy}};  
//============================================================================================= 
// output buffer
//============================================================================================= 
always@(posedge clk or posedge rst)        
 if(  rst )
     begin                                                                                       
        s4_stb                 <=                                                          'b0;   
        s4_sof                 <=                                                          'b0;  
     end
 else  
     begin                                                                                 
        s4_stb                  <=                                                      s3_stb;  
        s4_sof                  <=                                                  s3_stb_hdr; 
     end                                                                                      
//---------------------------------------------------------------------------------------------

always@(posedge clk)
  begin                                                                                
        casex({s3_stb_hdr, s3_wr_ack, s3_stb_dat,s3_stb_inf})
        4'b1xxx:      s4_data   <=                                                   s3_header;  
        4'b01xx:      s4_data   <=          {8'h00,     8'd0,                           56'd0}; // write ACK 
        4'b001x:      s4_data   <=          {8'hFF,    48'd0,   8'd0, 6'd0, s3_bsy, s3_result};  
        4'b0001:      s4_data   <=          {8'hFF, MTX_INFO, s5_cnt, 6'd0, s3_bsy,      1'b0}; 
        default:      s4_data   <=          {8'hFF,    48'd0,   8'd0, 6'd0,   1'b0,      1'b0};
        endcase     
  end                                                                                      
//---------------------------------------------------------------------------------------------
assign  o_stb            =                                                              s4_stb;  
assign  o_sof            =                                                              s4_sof;  
assign  o_data           =                                                             s4_data; 
//============================================================================================= 
endmodule