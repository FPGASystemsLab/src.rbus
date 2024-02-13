//=============================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
// 
// Two FIFOs, one for 3 long packets and one for 2 short packets with triggered output. After
// triggering FIFO (long or short) packet is transmitted after 2 clock cycles.
// If TRIGGER_WITH_EMPTY_FF_IS_OK == "NO" than has_long / has_short must be set when 
// trigger signal trg_long / trg_short is set. 
// TRIGGER_WITH_EMPTY_FF_IS_OK == "YES" fifo chcecks if it has a packet and if not than simply 
// no frm_o_en signal will be set for a packet and no packet will be poped from this fifo and 
// no error signal will be set. In this mode a packet can be transmitted with one clock cycle
// delay less.
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rbus_2ch_ff
#(
parameter [31:0] TRIGGER_WITH_EMPTY_FF_IS_OK = "NO" // "YES" or "NO"
)
(                                                                                                                               
input  wire         clk,
input  wire         rst,   

input  wire         frm_i_stb,
input  wire         frm_i_sof,
input  wire [71:0]  frm_i_bus,
output wire  [1:0]  frm_i_rdy, 

output wire         frm_o_en,
output wire         frm_o_sof,
output wire [71:0]  frm_o_bus,

output wire         has_long,
output wire         has_short,
input  wire         trg_long,
input  wire         trg_short,

output reg          ff_err
);         
//=============================================================================================
// TODO
//=============================================================================================   
// pragma translate_off
initial                
  begin
  $display( "%m: Module can be changed to support priorities and virtual channel for events." );       
  end  
// pragma translate_on  
//=============================================================================================
// PARMETERS CHECK
//=============================================================================================   
// pragma translate_off
initial
  begin
    if(TRIGGER_WITH_EMPTY_FF_IS_OK[15:0] != "NO" && TRIGGER_WITH_EMPTY_FF_IS_OK[23:0] != "YES")        
      begin
        $display( "%m: Paremeter TRIGGER_WITH_EMPTY_FF_IS_OK can only be set to \"YES\" or \"NO\"" );
        $finish;
      end 
  end
// pragma translate_on  
//=============================================================================================
// variables
//=============================================================================================       
reg             w0_stb;
reg             w0_sof;
reg     [71:0]  w0_bus;      
reg      [1:0]  w0_nptr_long;
reg      [0:0]  w0_nptr_short;
reg      [2:0]  w0_cnt_longX;
reg      [2:0]  w0_cnt_shortX;

reg      [4:0]  w0_mm_addr;
wire            w0_mm_wr_hdr_long;
wire            w0_mm_wr_hdr_short;
//---------------------------------------------------------------------------------------------
reg      [2:0]  w1_cnt_long;
reg      [1:0]  w1_cnt_short;    
//---------------------------------------------------------------------------------------------
`ifdef ALTERA
reg     [71:0]  mm_buff [0:31] /* synthesis syn_ramstyle="no_rw_check,MLAB" */;
reg     [71:0]  mm_buff_outX;
`else
reg     [71:0]  mm_buff [0:31] /* synthesis syn_ramstyle="no_rw_check,select_ram" */;
wire    [71:0]  mm_buff_out;
`endif
wire            mm_ne_long;
wire            mm_ne_short;
//---------------------------------------------------------------------------------------------
wire            r0_en_long;
wire            r0_en_short;
wire            r0_free_long;
wire            r0_free_short;
reg             r1_stb;
reg             r1_sof;        
reg      [0:0]  r1_nptr_short;
reg      [1:0]  r1_nptr_long;
reg      [4:0]  r1_mm_addr;
`ifdef ALTERA
reg      [4:0]  r1_mm_addrX;
`endif
reg      [3:0]  r1_pkt_dcnt;
wire            r1_lst;
//---------------------------------------------------------------------------------------------       
reg     [71:0]  r2_mm_bus;
reg             r2_sof;
reg             r2_en;                                                                                       
//---------------------------------------------------------------------------------------------
wire     [3:0]  ff_errs;                                                                         
//=============================================================================================
// input 
//=============================================================================================
// stage w0
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
wire     f_insert_long  =                                frm_i_bus[39] & frm_i_stb & frm_i_sof;
wire     f_insert_short =                               !frm_i_bus[39] & frm_i_stb & frm_i_sof;
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
 if(rst)
  begin
   w0_stb               <=                                                                 'd0; 
   
   w0_nptr_long         <=                                                                2'd0;   
   w0_nptr_short        <=                                                                1'd0; 
   
   w0_cnt_longX         <=                                                                -'d3; 
   w0_cnt_shortX        <=                                                                -'d2; 
   
  end                                                                                        
 else
  begin
   w0_stb               <=                                                           frm_i_stb;  
   
   w0_nptr_long         <= ( f_insert_long )? ((w0_nptr_long == 'd2)? 2'd0: w0_nptr_long +'d1):
                                                                            w0_nptr_long      ; 
   w0_nptr_short        <= ( f_insert_short)? ((w0_nptr_short== 'd1)? 1'd0: w0_nptr_short+'d1):
                                                                            w0_nptr_short     ; 
                                                                            
   w0_cnt_longX         <= ( f_insert_long  & !r0_free_long ) ?             w0_cnt_longX + 'd1:
                           (!f_insert_long  &  r0_free_long ) ?             w0_cnt_longX - 'd1:
                                                                            w0_cnt_longX      ;
   w0_cnt_shortX        <= ( f_insert_short & !r0_free_short) ?            w0_cnt_shortX + 'd1:
                           (!f_insert_short &  r0_free_short) ?            w0_cnt_shortX - 'd1:
                                                                           w0_cnt_shortX      ;
  end
//--------------------------------------------------------------------------------------------- 
always@(posedge clk) 
  begin     
   w0_sof               <=                                                           frm_i_sof;                                                                                    
   w0_bus[71: 0]        <=                                                    frm_i_bus[71: 0]; 
   if(frm_i_sof)
       casex({frm_i_bus[39], w0_nptr_long, w0_nptr_short})
       4'b0_xx_0:       w0_mm_addr    <=                                                  'd27;  // slot 0 short
       4'b0_xx_1:       w0_mm_addr    <=                                                  'd29;  // slot 1 short
                                                                                         
       4'b1_00_x:       w0_mm_addr    <=                                                  'd00;  // slot 0 long 
       4'b1_01_x:       w0_mm_addr    <=                                                  'd09;  // slot 1 long 
       4'b1_1x_x:       w0_mm_addr    <=                                                  'd18;  // slot 2 long 
                                                                                          
       default:         w0_mm_addr    <=                                                  'd31;   
       endcase
   else if(frm_i_stb)   w0_mm_addr    <=                                      w0_mm_addr + 'd1;     

  end
//--------------------------------------------------------------------------------------------- 
assign w0_mm_wr_hdr_long     =                                   w0_stb & w0_sof &  w0_bus[39];
assign w0_mm_wr_hdr_short    =                                   w0_stb & w0_sof & !w0_bus[39];
//--------------------------------------------------------------------------------------------- 
assign    frm_i_rdy[1]       =                                                 w0_cnt_longX[2];
assign    frm_i_rdy[0]       =                                                w0_cnt_shortX[2];
//--------------------------------------------------------------------------------------------- 
assign    ff_errs[0]         =                                 !frm_i_rdy[0] && f_insert_short;
assign    ff_errs[1]         =                                 !frm_i_rdy[1] && f_insert_long ;
//=============================================================================================
always@(posedge clk or posedge rst)
 if(rst)
  begin
   w1_cnt_long          <=                                                                 'd0; 
   w1_cnt_short         <=                                                                 'd0; 
  end                                                                                        
 else
  begin
   w1_cnt_long          <= ( w0_mm_wr_hdr_long  & !r0_free_long ) ?          w1_cnt_long - 'd1:
                           (!w0_mm_wr_hdr_long  &  r0_free_long ) ?          w1_cnt_long + 'd1:
                                                                             w1_cnt_long      ;
                                                                                                
   w1_cnt_short         <= ( w0_mm_wr_hdr_short & !r0_free_short) ?         w1_cnt_short - 'd1:
                           (!w0_mm_wr_hdr_short &  r0_free_short) ?         w1_cnt_short + 'd1:
                                                                            w1_cnt_short      ;
  end    
//=============================================================================================
// buffer for packets                                                                                            
//=============================================================================================           
always@(posedge clk) 
 begin
  if(w0_stb)   mm_buff[w0_mm_addr]  <=                                                  w0_bus;
    //if(w1_sof & w1_mm_we) $display("%d %m WR : %H",$time,w1_bus);
`ifdef ALTERA
   mm_buff_outX[71: 0]  <=                                                mm_buff[r1_mm_addrX];
`endif
 end                                                                                           
//---------------------------------------------------------------------------------------------  
`ifndef ALTERA       
assign mm_buff_out      =                                                  mm_buff[r1_mm_addr];
`endif
assign mm_ne_long       =                                                      w1_cnt_long [2];
assign mm_ne_short      =                                                      w1_cnt_short[1];
//=============================================================================================
// output
//=============================================================================================
assign has_long         =                                                          mm_ne_long ;
assign has_short        =                                                          mm_ne_short;
//=============================================================================================
// read
//=============================================================================================      
assign r0_en_long   = (TRIGGER_WITH_EMPTY_FF_IS_OK == "YES")?(trg_long  & has_long ):trg_long ;
assign r0_en_short  = (TRIGGER_WITH_EMPTY_FF_IS_OK == "YES")?(trg_short & has_short):trg_short;
assign r0_free_long =                                                              r0_en_long ;
assign r0_free_short=                                                              r0_en_short;
assign ff_errs[2]   =                                               r0_free_short & !has_short;
assign ff_errs[3]   =                                               r0_free_long  & !has_long ;         
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)
  begin
   r1_stb               <=                                                                1'b0;
   r1_nptr_long         <=                                                                2'd0;   
   r1_nptr_short        <=                                                                1'd0;   
   r1_pkt_dcnt          <=                                                                4'd0; 
  end                                                                                        
 else
  begin
   r1_stb               <=                     (r0_en_long | r0_en_short | (r1_stb & !r1_lst));
   r1_nptr_long         <= (r0_en_long  )?    ((r1_nptr_long == 'd2)? 2'd0: r1_nptr_long +'d1):
                                                                            r1_nptr_long      ; 
   r1_nptr_short        <= (r0_en_short )?    ((r1_nptr_short== 'd1)? 1'd0: r1_nptr_short+'d1):
                                                                            r1_nptr_short     ; 
   r1_pkt_dcnt          <= (trg_long )?                                                   4'd7: 
                           (trg_short)?                                                   4'd0: 
                           (r1_stb   )?                                     r1_pkt_dcnt - 4'd1:
                                                                            r1_pkt_dcnt       ;
  end  
//---------------------------------------------------------------------------------------------
assign r1_lst        =                                                          r1_pkt_dcnt[3];         
//---------------------------------------------------------------------------------------------
always@(posedge clk) 
  begin      
   r1_sof               <=                                                   !r1_stb || r1_lst;
   
   if(!r1_stb || r1_lst)
       casex({trg_long, r1_nptr_long, r1_nptr_short})
       4'b0_xx_0:       r1_mm_addr    <=                                                  'd27;  // slot 0 short
       4'b0_xx_1:       r1_mm_addr    <=                                                  'd29;  // slot 1 short
                                                                                         
       4'b1_00_x:       r1_mm_addr    <=                                                  'd00;  // slot 0 long 
       4'b1_01_x:       r1_mm_addr    <=                                                  'd09;  // slot 1 long 
       4'b1_1x_x:       r1_mm_addr    <=                                                  'd18;  // slot 2 long 
                                                                                          
       default:         r1_mm_addr    <=                                                  'd31;   
       endcase          
   else if(r1_stb   )   r1_mm_addr    <=                                      r1_mm_addr + 'd1;     
  end
`ifdef ALTERA
always@(*) 
   if(!r1_stb || r1_lst)
       casex({trg_long, r1_nptr_long, r1_nptr_short})
       4'b0_xx_0:       r1_mm_addrX   <=                                                  'd27;  // slot 0 short
       4'b0_xx_1:       r1_mm_addrX   <=                                                  'd29;  // slot 1 short
                                                                                        
       4'b1_00_x:       r1_mm_addrX   <=                                                  'd00;  // slot 0 long 
       4'b1_01_x:       r1_mm_addrX   <=                                                  'd09;  // slot 1 long 
       4'b1_1x_x:       r1_mm_addrX   <=                                                  'd18;  // slot 2 long 
                                                                                         
       default:         r1_mm_addrX   <=                                                  'd31;   
       endcase                      
   else if(r1_stb   )   r1_mm_addrX   <=                                      r1_mm_addr + 'd1;  
`endif
//=============================================================================================
// stage r1
//=============================================================================================
always@(posedge clk or posedge rst)                                                                                                             
 if(rst)
  begin  
   r2_en                <=                                                                 'd0;
  end                                                                                        
 else
  begin 
   r2_en                <=                                                              r1_stb;
  end
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)                                                                                                        
  begin                                                                                       
   r2_sof               <=                                                              r1_sof; 
`ifdef ALTERA
   r2_mm_bus [71: 0]    <=                                                 mm_buff_outX[71: 0];
`else
   r2_mm_bus [71: 0]    <=                                                  mm_buff_out[71: 0];
`endif
  end
//============================================================================================= 
// output
//=============================================================================================  
always@(posedge clk or posedge rst)
 if(rst)              ff_err           <=                                                 1'b0;                                                                                    
 else if(|ff_errs   ) ff_err           <=                                                 1'b1;                                                                                    
 else                 ff_err           <=                                               ff_err;
//=============================================================================================   
assign  frm_o_en        =                                                               r2_en ;  
assign  frm_o_sof       =                                                               r2_sof;
assign  frm_o_bus       =                                                            r2_mm_bus;
//=============================================================================================                      
endmodule