//=============================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                     
//=============================================================================================
module rsbus_d2r_extractor
#(                        
parameter           SPACE_CHECKING      =                                                "OFF",
parameter [38:0]    SPACE_START_ADDRESS =                                      39'h0_0000_0000,
parameter [38:0]    SPACE_LAST_ADDRESS  =                                      39'h0_0000_0000
)
(                                                                                                                  
input  wire         clk,
input  wire         rst,   

input  wire         i_sof,
input  wire [11:0]  i_ctrl,
input  wire [71:0]  i_bus,   

output wire         o_sof,
output wire [11:0]  o_ctrl,
output wire [71:0]  o_bus,

output wire         frm_o_stb,
output wire         frm_o_sof,
output wire [71:0]  frm_o_bus,
input  wire [ 1:0]  frm_o_rdy,
input  wire [ 1:0]  frm_o_rdyE
);      
//=============================================================================================
// parameters
//=============================================================================================      
//parameter     ACK_ID          =                                                                     4'd0;                                                                                                                              
// pragma translate_off
initial
    begin
        if((SPACE_CHECKING != "ON") && (SPACE_CHECKING != "OFF"))             
            begin
           $display( "SPACE_CHECKING = %s, is out of range (\"ON\" / \"OFF\")", SPACE_CHECKING );  
            $finish;
            end  
           
        else if((SPACE_CHECKING == "ON")&&(SPACE_LAST_ADDRESS < SPACE_START_ADDRESS)) 
            begin
           $display( "!!!ERROR!!! SPACE_LAST_ADDRESS (%d) < SPACE_START_ADDRESS (%d)",SPACE_LAST_ADDRESS, SPACE_START_ADDRESS );
            $finish;
            end       
    end
// pragma translate_on
//=============================================================================================
// variables
//=============================================================================================   
reg         sx_sof;
reg [11:0]  sx_ctrl;
reg [71:0]  sx_bus;       
reg         sx_addr_beg;
reg         sx_addr_end;
//--------------------------------------------------------------------------------------------- 
reg         s0_sof;
reg [11:0]  s0_ctrl;
reg [71:0]  s0_bus; 
reg         s0_reco;
reg         s0_hdr_ena;
reg         s0_ena;   
//---------------------------------------------------------------------------------------------  
reg         s1_sof;
reg [11:0]  s1_ctrl;         
reg [71:0]  s1_bus;
//=============================================================================================                  
// flags
//============================================================================================= 
wire        i_frm_stb    =                                                           i_bus[71];
wire        i_frm_len    =                                                           i_bus[39]; 
wire        i_frm_pha    =                                                          !i_bus[ 2];             
wire [3:0]  i_frm_did    =                                                        i_bus[51:48];
wire [1:0]  i_frm_pp     =                                                        i_bus[69:68];
wire [38:0] i_frm_addr   =                                                  {i_bus[38:3],3'd0};
//--------------------------------------------------------------------------------------------- 
wire        f_frm_enaX1S =                                (i_frm_len == 1'b0 && frm_o_rdy[0] ); 
wire        f_frm_enaX1L =                                (i_frm_len == 1'b1 && frm_o_rdy[1] );
wire        f_frm_enaX1  =                                        f_frm_enaX1S || f_frm_enaX1L; 
wire        f_frm_enaX1ES=                                (i_frm_len == 1'b0 && frm_o_rdyE[0]); 
wire        f_frm_enaX1EL=                                (i_frm_len == 1'b1 && frm_o_rdyE[1]);
wire        f_frm_enaX1E =                                      f_frm_enaX1ES || f_frm_enaX1EL;
wire        f_frm_enaX2  =                                                           i_frm_pha;
//---------------------------------------------------------------------------------------------        
wire        f_addr_beg   =                  {1'b0,i_frm_addr} >= {1'b0,(SPACE_START_ADDRESS )};
wire        f_addr_end   =                  {1'b0,i_frm_addr}  < {1'b0,(SPACE_LAST_ADDRESS+1)};
wire        f_addr_ok    =                                             f_addr_beg & f_addr_end;
//---------------------------------------------------------------------------------------------  
wire        f_frm_ena    =i_frm_stb                   & f_frm_enaX1 & f_frm_enaX2             ;
wire        f_frm_enaE   =i_frm_stb & (i_frm_pp==2'd3)& f_frm_enaX1E& f_frm_enaX2             ;
wire        f_frm_reco   =i_frm_stb                   &!f_frm_enaX1 & f_frm_enaX2             ; 
//=============================================================================================                  
// stage sx - additional stage when address space checking is enabled
//=============================================================================================  
always@(posedge clk or posedge rst)
if(rst)                        
 begin                                                                                              
   sx_sof                      <=                                                          'b0;
   sx_ctrl[11]                 <=                                                          'b0;    
   sx_bus[71:68]               <=                                                          'd0;   
 end 
else  
 begin                                                                                           
   sx_sof                      <=                                                        i_sof;
   sx_ctrl[11]                 <=                                                   i_ctrl[11];  
   sx_bus[71:68]               <=                                                 i_bus[71:68];
 end 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)
  begin                                                                                           
   sx_addr_beg                 <=                                                   f_addr_beg;
   sx_addr_end                 <=                                                   f_addr_end; 
   sx_bus[67: 0]               <=                                                 i_bus[67: 0];
   sx_ctrl[10:0]               <=                                                 i_ctrl[10:0];  
  end                                                                                            
//=============================================================================================  
wire       sx_frm_stb    =                                                          sx_bus[71];
wire       sx_frm_len    =                                                          sx_bus[39]; 
wire       sx_frm_pha    =                                                         !sx_bus[ 2];             
wire [3:0] sx_frm_did    =                                                       sx_bus[51:48];
wire [1:0] sx_frm_pp     =                                                       sx_bus[69:68]; 
//--------------------------------------------------------------------------------------------- 
wire       sx_frm_enaX1S =                                (sx_frm_len == 1'b0 && frm_o_rdy[0]); 
wire       sx_frm_enaX1L =                                (sx_frm_len == 1'b1 && frm_o_rdy[1]);
wire       sx_frm_enaX1  =                                      sx_frm_enaX1S || sx_frm_enaX1L;
wire       sx_frm_enaX1ES=                               (sx_frm_len == 1'b0 && frm_o_rdyE[0]); 
wire       sx_frm_enaX1EL=                               (sx_frm_len == 1'b1 && frm_o_rdyE[1]);
wire       sx_frm_enaX1E =                                    sx_frm_enaX1ES || sx_frm_enaX1EL;
wire       sx_frm_enaX2  =                                                          sx_frm_pha;
//--------------------------------------------------------------------------------------------- 
wire       sx_addr_ok    =                                           sx_addr_beg & sx_addr_end;
wire       sx_addr_ena   =                                                          sx_addr_ok;
//---------------------------------------------------------------------------------------------  
wire       sx_frm_ena =sx_frm_stb                  & sx_frm_enaX1 & sx_frm_enaX2 & sx_addr_ena;
wire       sx_frm_enaE=sx_frm_stb&(sx_frm_pp==2'd3)& sx_frm_enaX1E& sx_frm_enaX2 & sx_addr_ena;
wire       sx_frm_reco=sx_frm_stb                  &!sx_frm_enaX1 & sx_frm_enaX2 & sx_addr_ena; 
//=============================================================================================                  
// stage 0
//=============================================================================================   
wire use_sx =                                                         (SPACE_CHECKING == "ON");
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
if(rst)                        
 begin                                                                                              
   s0_sof                      <=                                                          'b0;   
   s0_reco                     <=                                                          'b0;
   s0_ena                      <=                                                          'b0;
   s0_hdr_ena                  <=                                                          'b0;
   s0_ctrl[11]                 <=                                                          'b0;    
  s0_bus[71:68]                <=                                                          'd0;   
 end 
else if(use_sx) 
 begin                                                                                                  
   s0_sof                      <=                                                       sx_sof;
   s0_ctrl[11]                 <=                                                  sx_ctrl[11]; 
   s0_reco                     <= (sx_sof) ?                           sx_frm_reco :      1'd0;   
   s0_ena                      <= (sx_sof) ?            (sx_frm_ena | sx_frm_enaE) :   s0_ena ;  
   s0_hdr_ena                  <= (sx_sof) ?                            sx_frm_ena :      1'b0;   
   s0_bus[71:68]               <=                                                sx_bus[71:68];
 end 
else  
 begin                                                                                                  
   s0_sof                      <=                                                        i_sof;
   s0_ctrl[11]                 <=                                                   i_ctrl[11]; 
   s0_reco                     <= (i_sof) ?                             f_frm_reco :      1'd0;   
   s0_ena                      <= (i_sof) ?               (f_frm_ena | f_frm_enaE) :   s0_ena ;  
   s0_hdr_ena                  <= (i_sof) ?                              f_frm_ena :      1'b0;   
   s0_bus[71:68]               <=                                                 i_bus[71:68];
 end 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)
if(use_sx)  
  begin
   s0_bus[67:0]                <=                                                 sx_bus[67:0];  
   s0_ctrl[10:0]               <=                                                sx_ctrl[10:0]; 
  end  
else
  begin
   s0_bus[67:0]                <=                                                  i_bus[67:0];
   s0_ctrl[10:0]               <=                                                 i_ctrl[10:0]; 
  end
//=============================================================================================
// TX fifos
//=============================================================================================  
assign  frm_o_stb              =                                                       s0_ena ;
assign  frm_o_sof              =                                                        s0_sof;
assign  frm_o_bus              =                                                        s0_bus;   
//=============================================================================================
// stage 1
//=============================================================================================
always@(posedge clk or posedge rst)
 if(rst)                        
  begin                                                                                   
   s1_sof                      <=                                                          'b0;      
   s1_ctrl[11]                 <=                                                          'b0;       
   s1_bus[71:68]               <=                                                          'd0;         
  end 
 else  
  begin                                                                                                
   s1_sof                      <=                                                       s0_sof;  
   s1_ctrl[11]                 <= (s0_hdr_ena)?                             'd0 :  s0_ctrl[11];
   
   s1_bus[71]                  <= (s0_ena )?                       1'b0 :           s0_bus[71];
   s1_bus[70]                  <= (s0_ena )?                       1'b0 : s0_reco | s0_bus[70];
   s1_bus[69:68]               <=                                                s0_bus[69:68]; 
  end   
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)
  begin
   s1_bus[67:0]                <=                                                 s0_bus[67:0];
                                                 
   s1_ctrl[10:0]               <= (s0_hdr_ena)?                            'd0 : s0_ctrl[10:0]; 
  end
//=============================================================================================
// output
//=============================================================================================   
assign  o_sof           =                                                               s1_sof;
assign  o_ctrl          =                                                              s1_ctrl;
assign  o_bus           =                                                               s1_bus;
//=============================================================================================
endmodule
