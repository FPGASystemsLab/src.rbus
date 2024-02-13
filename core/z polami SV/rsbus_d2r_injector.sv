//=============================================================================================
//    Main contributors
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//      - Jakub Siast        
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rsbus_d2r_injector
#(                                                        
parameter   [3:0]   BASE_ID  =                  4'd0, // 
parameter   [3:0]   LAST_ID  =                  4'd0, //
parameter           DBG_MSG  =                  1'b0
)
(                                                                                                                               
input  wire         clk,
input  wire         rst,   

input  wire         i_stb,                                 
input  wire  [3:0]  i_iid,
input  wire         i_sof,
input  wire [71:0]  i_data,
output wire  [1:0]  i_af, 

input  wire         d2r_i_sof,
input  wire [11:0]  d2r_i_ctrl,
input  wire [71:0]  d2r_i_data,
                                                          
output wire         d2r_o_sof,                                                                
output wire [11:0]  d2r_o_ctrl,                                                               
output wire [71:0]  d2r_o_data, 

output reg          ff_err
);      
//=============================================================================================
// parameters
//=============================================================================================   
// pragma translate_off
initial
    begin
        if({1'b0, BASE_ID} > {1'b0, LAST_ID}) 
            begin
              $display( "!!!ERROR!!! rbus_d2r_injector. BASE_ID (%d) lower than LAST_ID (%d)", BASE_ID, LAST_ID ); 
              $finish;
            end
    end
// pragma translate_on 
//=============================================================================================
// variables
//============================================================================================= 
reg             init; 
//---------------------------------------------------------------------------------------------
wire            xi_stb;
wire    [71:0]  xi_data;
//---------------------------------------------------------------------------------------------       
wire            x0_stb;
wire            x0_sof;
wire     [3:0]  x0_lid;
wire    [71:0]  x0_data;
//---------------------------------------------------------------------------------------------      
reg             s0_sof;
reg     [11:0]  s0_ctrl;
reg     [71:0]  s0_data;
reg             s0_insert_ena;
reg             s0_header_ack;

reg             s0_o_ena;
reg             s0_o_sof;
reg             s0_i_ena;
reg     [71:0]  s0_i_data;         
//---------------------------------------------------------------------------------------------               
reg             s1_sof;           
reg     [11:0]  s1_ctrl;  
reg             s1_insert_ena;  
reg             s1_insert_req;
reg      [3:0]  s1_x_lid; 
reg     [71:0]  s1_i_data;
reg     [71:0]  s1_x_data;
//---------------------------------------------------------------------------------------------               
reg             s2_sof;           
reg     [11:0]  s2_ctrl;
reg     [71:0]  s2_data;  
//---------------------------------------------------------------------------------------------               
wire            req_stb; 
wire            req_len; 
wire     [1:0]  req_pp;  
wire     [3:0]  req_lad;            
//---------------------------------------------------------------------------------------------
wire     [ 5:0] ff_errs;
//=============================================================================================
// rbus initialization wait
//============================================================================================= 
always@(posedge clk or posedge rst)
if(rst)         init    <=                                                                1'b1;
else            init    <=                                                  init && !d2r_i_sof;
//=============================================================================================
// input fifo
//=============================================================================================       
wire        d2r_i_frm_empty=                                                   !d2r_i_data[71];
wire        d2r_i_frm_len  =                                                    d2r_i_data[39];
wire        d2r_i_frm_free =                                                   d2r_i_frm_empty;
wire  [1:0] d2r_i_frm_pp   =                                                 d2r_i_data[69:68];  
//--------------------------------------------------------------------------------------------- 
wire  [3:0] i_lid          =                                                ~(BASE_ID + i_iid);
// pragma translate_off
always @(clk)
if(i_stb & i_sof & (((BASE_ID + i_iid) < BASE_ID) || ((BASE_ID + i_iid) > LAST_ID)))    
  begin
    $display( "!!!ERROR!!! dev id (%d) out of range 0-15", i_lid );
    $finish;
  end   
// pragma translate_on
//---------------------------------------------------------------------------------------------                           
wire        i_frm_len      =                                                        i_data[39];
wire  [1:0] i_frm_pp       =                                                     i_data[69:68];
wire  [3:0] i_frm_lad      =                                                             i_lid;
//---------------------------------------------------------------------------------------------    
`ifdef NO_SHIFT_REGS
ff_dram_af_ack_d16
`else	  
ff_srl_af_ack_d16
`endif    
#(             
.AF0LIMIT(6'd2+ 6'd1), // 1 for additional one clock cycle for af check in extractor
.AF1LIMIT(6'd9+ 6'd1), // 1 for additional one clock cycle for af check in extractor
.WIDTH(77)                                                                           
) fifo_for_packets
(                     
 .clk           (clk),                         
 .rst           (rst),   
 
 .i_stb         (i_stb),
 .i_data        ({i_sof,i_lid,i_data}),
 .i_af          (i_af),    
 .i_full        (),
 .i_err         (ff_errs[0]), 
 
 .o_stb         (x0_stb),
 .o_data        ({x0_sof,x0_lid,x0_data}),
 .o_ack         (s0_insert_ena), 
 .o_ae          (),            
 .o_err         (ff_errs[1])
 ); 
 
`ifdef NO_SHIFT_REGS
ff_dram_af_ack_d16
`else	  
ff_srl_af_ack_d16
`endif 
#(.WIDTH(72)) fifo_for_headers
(                     
 .clk           (clk),                         
 .rst           (rst),   
 
 .i_stb         (i_stb && i_sof),
 .i_data        (i_data),
 .i_af          (),
 .i_full        (),
 .i_err         (ff_errs[2]), 
 
 .o_stb         (xi_stb),
 .o_data        (xi_data),                                            
 .o_ack         (s0_header_ack), 
 .o_ae          (),                                                       
 .o_err         (ff_errs[3])
 ); 

`ifdef NO_SHIFT_REGS
ff_dram_af_ack_d16
`else	  
ff_srl_af_ack_d16
`endif 
#(.WIDTH(7)) fifo_for_requests
(                     
 .clk           (clk),                                             
 .rst           (rst),                                   
 
 .i_stb         (i_stb && i_sof),
 .i_data        ({i_frm_pp,i_frm_len,i_frm_lad}),
 .i_af          (),
 .i_full        (),
 .i_err         (ff_errs[4]), 
 
 .o_stb         (req_stb),
 .o_data        ({req_pp,req_len,req_lad}),
 .o_ack         (s1_insert_req),  
 .o_ae          (),            
 .o_err         (ff_errs[5])
 ); 
//=============================================================================================
// in/out for inst/data cache
//=============================================================================================
wire      f_frm_len_ok   =                            xi_stb && (xi_data[39] == d2r_i_frm_len);
wire      f_frm_dev_ok   =                                   (d2r_i_ctrl[7:4] ==  x0_lid[3:0]);
wire      f_frm_grant    = (d2r_i_frm_free && d2r_i_ctrl[11]) ? f_frm_len_ok && f_frm_dev_ok : 1'b0;
//=============================================================================================
// pragma translate_off  
integer req_send_cnt;
integer grant_recv_cnt;
                       
always@(posedge clk or posedge rst) 
if(rst)   req_send_cnt <= 0;
else if(s1_insert_req & DBG_MSG) 
  begin                             
      $display( "BASE_ID (%d) req (%d)", BASE_ID, req_send_cnt );  
      req_send_cnt <= req_send_cnt+1;       
    end

always@(posedge clk or posedge rst) 
if(rst)   grant_recv_cnt <= 0;
else if(d2r_i_sof & f_frm_grant & DBG_MSG) 
  begin                             
      $display( "BASE_ID (%d) grant (%d)", BASE_ID, grant_recv_cnt ); 
      grant_recv_cnt <= grant_recv_cnt+1;       
    end

// pragma translate_on
//=============================================================================================
// stage s0
//=============================================================================================
always@(posedge clk or posedge rst)
if(rst)                        
 begin                                                                                   
  s0_sof                <=                                                                1'b0;    
  s0_ctrl               <=                                                                8'b0;    
  s0_data[71:68]        <=                                                                4'b0;   
  
  s0_insert_ena         <=                                                                1'b0;
  s0_header_ack         <=                                                                1'b0;
 end                              
else  
 begin                                                                                      
  s0_sof                <=                                                           d2r_i_sof;  
  s0_ctrl               <=                                                          d2r_i_ctrl;  
  s0_data[71:68]        <=                                                   d2r_i_data[71:68];
  
  s0_insert_ena         <= (d2r_i_sof) ?                           f_frm_grant : s0_insert_ena;
  s0_header_ack         <= (d2r_i_sof) ?                           f_frm_grant :          1'b0;
 end     
//--------------------------------------------------------------------------------------------- 
always@(posedge clk) 
 begin                                                                                         
  s0_data[67: 0]         <=                                                  d2r_i_data[67: 0];
 end
//=============================================================================================
// stage s1
//=============================================================================================
always@(posedge clk or posedge rst)
if(rst)                        
 begin                                                                                          
  s1_sof                <=                                                                1'b0;       
  s1_ctrl               <=                                                                8'b0;    

  s1_insert_ena         <=                                                                1'b0;    
  s1_insert_req         <=                                                                1'b0;   
  
  s1_i_data[71:68]      <=                                                                4'b0;    
  
  s1_x_data[71:68]      <=                                                                4'b0;    
  s1_x_lid              <=                                                                4'b0;    
 end 
else  
 begin                                                                                      
  s1_sof                <=                                                              s0_sof;        
  s1_ctrl               <=                                                             s0_ctrl;       
  
  s1_insert_ena         <=                                                       s0_insert_ena;    
  s1_insert_req         <= (!s0_sof & !s0_ctrl[7] & !s1_insert_req & !init)?    req_stb : 1'b0;   

  s1_i_data[71:68]      <=                                                      s0_data[71:68];
  
  s1_x_data[71:68]      <= (s0_sof)? {x0_data[71], 1'b0/*O*/, x0_data[69:68]} : x0_data[71:68];    
 end     
//---------------------------------------------------------------------------------------------
always@(posedge clk)
 begin                                                                                             
  s1_i_data[67: 0]      <=                                                      s0_data[67: 0];    
  
  s1_x_data[38: 0]      <=                                                      x0_data[38: 0];
  s1_x_data[   39]      <=                                                      x0_data[   39];
  s1_x_data[47:40]      <=                                                      x0_data[47:40];
  s1_x_data[67:48]      <= (s0_sof)?                 {x0_data[63:48], x0_lid} : x0_data[67:48];    
 end     
//=============================================================================================
// stage s2
//=============================================================================================
always@(posedge clk or posedge rst)
 if(rst)
  begin
   s2_sof               <=                                                                1'b0;   
   s2_ctrl              <=                                                                8'd0;   
   s2_data[71:68]       <=                                                                4'd0;
  end                                                                                        
 else
  begin
   s2_sof               <=                                                              s1_sof; 
   s2_ctrl              <= (s1_insert_req) ?      {1'b1,req_len,req_pp,req_lad,4'd0} : s1_ctrl;   
   s2_data[71:68]       <= (s1_insert_ena) ?               s1_x_data[71:68] : s1_i_data[71:68];
  end
//--------------------------------------------------------------------------------------------- 
always@(posedge clk) 
  begin                                                                                         
   s2_data[67: 0]       <= (s1_insert_ena) ?               s1_x_data[67: 0] : s1_i_data[67: 0]; 
  end
//=============================================================================================
// output
//=============================================================================================  
always@(posedge clk or posedge rst)
 if(rst)              ff_err           <=                                                 1'b0;                                                                                    
 else if(|ff_errs   ) ff_err           <=                                                 1'b1;                                                                                    
 else                 ff_err           <=                                               ff_err;
//=============================================================================================   
assign  d2r_o_sof       =                                                               s2_sof;
assign  d2r_o_ctrl      =                                                              s2_ctrl;
assign  d2r_o_data      =                                                              s2_data;
//=============================================================================================                      
endmodule