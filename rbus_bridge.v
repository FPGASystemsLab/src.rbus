//=============================================================================================
//    Main contributors
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rbus_bridge
(
input  wire         i_clk,
input  wire         i_rst,   
input  wire         i_stb,          
input  wire         i_sof,          
input  wire [71:0]  i_data,   
output wire  [1:0]  i_rdy,

input  wire         o_clk,
input  wire         o_rst,   
output wire         o_stb,          
output wire         o_sof,          
output wire [71:0]  o_data,
input  wire  [1:0]  o_rdy
);                                                                                                                                                        
//=============================================================================================
// variables
//=============================================================================================  
parameter TARGET_FPGA_DEVICE                                                        = "ARTIX7";
//=============================================================================================
// variables
//=============================================================================================  
reg         fi_stb; 
reg         fi_sof; 
reg  [71:0] fi_data;
reg   [4:0] fi_cnt; 
reg         fi_frl; 
reg         fi_tag_stb; 
reg   [8:0] fi_tag_data; 
reg         fi_af; 
//---------------------------------------------------------------------------------------------
wire        fix_afull_hi;
wire        fix_afull_lo;
//---------------------------------------------------------------------------------------------
wire        fox_nstb_lo; 
wire        fox_nstb_hi;   
wire [71:0] fox_data;       
wire        fox_ack;
wire        fox_tag_ack;
wire  [8:0] fox_tag_data;              
wire        fox_tag_nstb;
//---------------------------------------------------------------------------------------------
reg   [4:0] fo0_cnt; 
reg         fo0_sof; 
reg         fo0_tag_ack; 
//---------------------------------------------------------------------------------------------
reg         fo1_stb; 
reg         fo1_sof;
reg  [71:0] fo1_data;
//=============================================================================================
/////////////////////////////////////////////////////////////////
// DATA_WIDTH | FIFO_SIZE | FIFO Depth | RDCOUNT/WRCOUNT Width //
// ===========|===========|============|=======================//
//   37-72    |  "36Kb"   |     512    |         9-bit         //
//   19-36    |  "36Kb"   |    1024    |        10-bit         //
//   19-36    |  "18Kb"   |     512    |         9-bit         //
//   10-18    |  "36Kb"   |    2048    |        11-bit         //
//   10-18    |  "18Kb"   |    1024    |        10-bit         //
//    5-9     |  "36Kb"   |    4096    |        12-bit         //
//    5-9     |  "18Kb"   |    2048    |        11-bit         //
//    1-4     |  "36Kb"   |    8192    |        13-bit         //
//    1-4     |  "18Kb"   |    4096    |        12-bit         //
/////////////////////////////////////////////////////////////////
//=============================================================================================
// buffered input
//=============================================================================================  
wire    f_frm_len    =                                                              i_data[39];
//---------------------------------------------------------------------------------------------
always@(posedge i_clk or posedge i_rst)
 if(i_rst)
    begin     
        fi_stb      <=                                                                     'd0;
        fi_sof      <=                                                                     'd0;
        fi_cnt      <=                                                                     'd0;
        fi_frl      <=                                                                     'd0;
    end
 else if(i_sof & i_stb)
    begin
        fi_stb      <=                                                                   i_stb;
        fi_sof      <=                                                                   i_sof;
        fi_cnt      <=  (f_frm_len) ?                                                'd7 : 'd0;
        fi_frl      <=                                                               f_frm_len;
    end
 else if(i_stb)
    begin
        fi_stb      <=                                                                   i_stb;
        fi_sof      <=                                                                   i_sof;
        fi_cnt      <=                                                            fi_cnt - 'd1;
        fi_frl      <=                                                                  fi_frl;
    end
 else
    begin
        fi_stb      <=                                                                     'd0;
        fi_sof      <=                                                                     'd0;
        fi_cnt      <=                                                                     'd0;
        fi_frl      <=                                                                  fi_frl;
    end
//---------------------------------------------------------------------------------------------
always@(posedge i_clk)
if(i_sof & i_stb)
  begin
      fi_data       <=                                                                  i_data;
  end                                           
 else if(i_stb)                                 
  begin                                         
      fi_data       <=                                                                  i_data;
  end                                           
 else                                           
  begin                                         
      fi_data       <=                                                                  i_data;
  end
//---------------------------------------------------------------------------------------------
always@(posedge i_clk or posedge i_rst)
 if(i_rst)
    begin     
        fi_tag_stb  <=                                                                     'd0;
        fi_tag_data <=                                                                     'd0;
    end
 else if(fi_cnt[4])
    begin
        fi_tag_stb  <=                                                                     'd1;
        fi_tag_data <=                                                           {fi_frl,8'd0};
    end
 else
    begin
        fi_tag_stb  <=                                                                     'd0;
        fi_tag_data <=                                                                     'd0;
    end
//---------------------------------------------------------------------------------------------
always@(posedge i_clk or posedge i_rst)
 if(i_rst)
    begin     
        fi_af       <=                                             fix_afull_hi | fix_afull_lo;
    end
 else 
    begin     
        fi_af       <=                                                                     'd0;
    end
//---------------------------------------------------------------------------------------------
assign  i_rdy        =                                                             ~{2{fi_af}}; 
//=============================================================================================
// device dependent fifo buffer
//=============================================================================================  
generate
case(TARGET_FPGA_DEVICE)
"ARTIX7", 
"KINTEX7", 
"VIRTEX7": 
    
    begin                                        
        // Lower 36 bits of rbus 72-bits word                  

        FIFO_DUALCLOCK_MACRO
        #(      
        .ALMOST_EMPTY_OFFSET        (9'h040),    
        .ALMOST_FULL_OFFSET         (9'h040),  
        .DATA_WIDTH                 (36), 
 
        .DEVICE                     ("7SERIES"),
        .FIFO_SIZE                  ("18Kb"),
        .FIRST_WORD_FALL_THROUGH    ("TRUE"),

        .INIT                       (72'h0), // This parameter is valid only for Virtex6
        .SRVAL                      (72'b0), // This parameter is valid only for Virtex6
        .SIM_MODE                   ("SAFE") // This parameter is valid only for Virtex5
        )
        fifo_36_A
        (
        .RST                        (i_rst), 
        
        .WRCLK                      (i_clk), 
        .WREN                       (fi_stb),
        .DI                         (fi_data[35:0]),
        .ALMOSTFULL                 (fix_afull_lo),
        .FULL                       (),
        .WRCOUNT                    (),
        .WRERR                      (),
        
        .RDCLK                      (o_clk), 
        .RDEN                       (fox_ack), 
        .DO                         (fox_data[35:0]), 
        .ALMOSTEMPTY                (), 
        .EMPTY                      (fox_nstb_lo), 
        .RDCOUNT                    (), 
        .RDERR                      () 
        );

        // Higher 36 bits of rbus 72-bits word                 
        
        FIFO_DUALCLOCK_MACRO
        #(      
        .ALMOST_EMPTY_OFFSET        (9'h080),
        .ALMOST_FULL_OFFSET         (9'h080),  
        .DATA_WIDTH                 (36), 
 
        .DEVICE                     ("7SERIES"),
        .FIFO_SIZE                  ("18Kb"),
        .FIRST_WORD_FALL_THROUGH    ("TRUE"),
 
        .INIT                       (72'h0), // This parameter is valid only for Virtex6
        .SRVAL                      (72'b0), // This parameter is valid only for Virtex6
        .SIM_MODE                   ("SAFE") // This parameter is valid only for Virtex5
        )
        fifo_36_B
        (
        .RST                        (i_rst), 
        
        .WRCLK                      (i_clk),
        .WREN                       (fi_stb),
        .DI                         (fi_data[71:36]),
        .ALMOSTFULL                 (fix_afull_hi),
        .FULL                       (),
        .WRCOUNT                    (),
        .WRERR                      (),
        
        .RDCLK                      (o_clk),
        .RDEN                       (fox_ack),
        .DO                         (fox_data[71:36]),
        .ALMOSTEMPTY                (),
        .EMPTY                      (fox_nstb_hi),
        .RDCOUNT                    (),
        .RDERR                      ()
        );

        // control bits of rbus 72-bits word                   
        
        FIFO_DUALCLOCK_MACRO
        #(      
        .ALMOST_EMPTY_OFFSET        (9'h080),    
        .ALMOST_FULL_OFFSET         (9'h080),  
        .DATA_WIDTH                 (9), 
 
        .DEVICE                     ("7SERIES"),
        .FIFO_SIZE                  ("18Kb"),
        .FIRST_WORD_FALL_THROUGH    ("TRUE"),
 
        .INIT                       (72'h0), // This parameter is valid only for Virtex6
        .SRVAL                      (72'b0), // This parameter is valid only for Virtex6
        .SIM_MODE                   ("SAFE") // This parameter is valid only for Virtex5
        )
        fifo_36_C
        (
        .RST                        (i_rst),
        
        .WRCLK                      (i_clk), 
        .WREN                       (fi_tag_stb), 
        .DI                         (fi_tag_data),
        .ALMOSTFULL                 (),
        .FULL                       (),
        .WRCOUNT                    (),
        .WRERR                      (),
        
        .RDCLK                      (o_clk), 
        .RDEN                       (fox_tag_ack), 
        .DO                         (fox_tag_data),
        .ALMOSTEMPTY                (),
        .RDCOUNT                    (),
        .EMPTY                      (fox_tag_nstb),
        .RDERR                      () 
        );
    end
"VIRTEX5", 
"VIRTEX6":
    begin
    
    end
//"SPARTAN6":
//  begin : ARTIX7_FIFO
//      $display("RBUS INTERDOMAIN FIFO for SPATAN-6 not implmented !!!");
//      $finish;
//  end        
endcase 
endgenerate
//=============================================================================================
// buffered output
//=============================================================================================
wire    f_stb_tag     =                                                          !fox_tag_nstb;
wire    f_flush       =                                                            !fo0_cnt[4];
wire    f_ready       =                                                               (&o_rdy);
//---------------------------------------------------------------------------------------------
always@(posedge o_clk or posedge o_rst)
 if(o_rst)
    begin     
        fo0_cnt      <=                                                                   -'d1;
        fo0_sof      <=                                                                    'd0;
        fo0_tag_ack  <=                                                                    'd0;
    end
 else if(f_stb_tag && !f_flush && f_ready)
    begin
        fo0_cnt      <= fox_tag_data[8] ?                                            'd8 : 'd1;
        fo0_sof      <=                                                                    'd1;
        fo0_tag_ack  <=                                                                    'd1;
    end
 else if(f_flush)
    begin
        fo0_cnt      <=                                                          fo0_cnt - 'd1;
        fo0_sof      <=                                                                    'd0;
        fo0_tag_ack  <=                                                                    'd0;
    end
 else  
    begin
        fo0_cnt      <=                                                                   -'d1;
        fo0_sof      <=                                                                    'd0;
        fo0_tag_ack  <=                                                                    'd0;
    end
//---------------------------------------------------------------------------------------------
assign  fox_tag_ack   =                                                            fo0_tag_ack;
assign  fox_ack       =                                                      (fo0_cnt[4]=='d0);
//---------------------------------------------------------------------------------------------
always@(posedge o_clk or posedge o_rst)
 if(o_rst)
    begin     
        fo1_stb      <=                                                                    'd0;
        fo1_sof      <=                                                                    'd0;
    end
 else if(fox_ack)
    begin
        fo1_stb      <=                                                                    'd1;
        fo1_sof      <=                                                                fo0_sof;
    end
 else
    begin
        fo1_stb      <=                                                                    'd0;
        fo1_sof      <=                                                                    'd0;
    end
//---------------------------------------------------------------------------------------------
always@(posedge o_clk)
if(fox_ack)
  begin
      fo1_data       <=                                                               fox_data;
  end                              
 else                              
  begin                            
      fo1_data       <=                                                               fox_data;
  end
//=============================================================================================
// output
//=============================================================================================
assign o_stb   =                                                                       fo1_stb;          
assign o_sof   =                                                                       fo1_sof;         
assign o_data  =                                                                      fo1_data;
//=============================================================================================
endmodule