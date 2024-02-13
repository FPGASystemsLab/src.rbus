//=============================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rbus_mux21
(
    input  wire             clk,
    input  wire             rst,   
                    
    input  wire             p0_dl_stb,
    input  wire             p0_dl_sof,
    input  wire    [71:0]   p0_dl_data,
    output wire     [1:0]   p0_dl_rdy,
                    
    output wire             p0_ul_stb,
    output wire             p0_ul_sof,
    output wire    [71:0]   p0_ul_data,
    input  wire     [1:0]   p0_ul_rdy,
          
    input  wire             p1_dl_stb,
    input  wire             p1_dl_sof,
    input  wire    [71:0]   p1_dl_data,
    output wire     [1:0]   p1_dl_rdy,

    output wire                 p1_ul_stb,
    output wire               p1_ul_sof,
    output wire       [71:0]    p1_ul_data,
    input  wire        [1:0]    p1_ul_rdy,
          
    input  wire             m_ul_stb,
    input  wire             m_ul_sof,
    input  wire     [71:0]  m_ul_data,
    output wire        [1:0]    m_ul_rdy,

    output wire             m_dl_stb,
    output wire                 m_dl_sof,
    output wire       [71:0]  m_dl_data,
    input  wire        [1:0]  m_dl_rdy,
    
    output wire             ff_err 
);
//=============================================================================================
// parameters
//=============================================================================================
//=============================================================================================
// variables
//=============================================================================================
// mux                                                                        
//---------------------------------------------------------------------------------------------
wire        mx_0_iff_err;
wire        mx_0_off_err;
wire        mx_1_iff_err;
wire        mx_1_off_err;
reg         mx_ff_err;
//---------------------------------------------------------------------------------------------
wire            si_0_stb;
wire            si_0_sof;
wire [71:0] si_0_data;
wire            si_0_ack;
//---------------------------------------------------------------------------------------------
wire            si_1_stb;
wire            si_1_sof;
wire [71:0] si_1_data;
wire            si_1_ack;                                        
//---------------------------------------------------------------------------------------------  
reg           mx0_stb;     
reg  [ 8:0] mx0_ack_0;
reg  [ 8:0] mx0_ack_1;   
reg     [1:0] mx0_sof;   
reg           mx0_last;   
reg  [71:0] mx0_data;  
//---------------------------------------------------------------------------------------------
reg             mx1_stb;
reg             mx1_sof;    
reg  [71:0] mx1_data; 
//---------------------------------------------------------------------------------------------
// demux
//---------------------------------------------------------------------------------------------
reg             dm0_stb;
reg             dm0_stb_0;
reg             dm0_stb_1;   
reg             dm0_sof;
reg  [71:0] dm0_data;
//---------------------------------------------------------------------------------------------
reg             dm1_stb_0;
reg             dm1_stb_1;
reg             dm1_sof;
reg  [71:0] dm1_data;
//=============================================================================================
// input fifo
//=============================================================================================
// in_0
//---------------------------------------------------------------------------------------------
rbus_dff fifo_in0
(
.clk        (clk),
.rst        (rst),

.i_stb      (p0_dl_stb),
.i_sof      (p0_dl_sof),
.i_data     (p0_dl_data),
.i_rdy      (p0_dl_rdy), 
.i_err      (mx_0_iff_err),

.o_stb      (si_0_stb),
.o_sof      (si_0_sof),
.o_data     (si_0_data),
.o_ack      (si_0_ack),
.o_err      (mx_0_off_err)
);                         
//---------------------------------------------------------------------------------------------
// in_1
//---------------------------------------------------------------------------------------------
rbus_dff fifo_in1
(
.clk        (clk),
.rst        (rst),

.i_stb      (p1_dl_stb),
.i_sof      (p1_dl_sof),
.i_data     (p1_dl_data),
.i_rdy      (p1_dl_rdy), 
.i_err      (mx_1_iff_err),

.o_stb      (si_1_stb),
.o_sof      (si_1_sof),
.o_data     (si_1_data),
.o_ack      (si_1_ack),
.o_err      (mx_1_off_err)
);                       
//=============================================================================================
// fifos error indicator
//=============================================================================================
always@(posedge clk or posedge rst)
      if( rst          ) mx_ff_err <=                                                     1'b0;
 else if( mx_0_iff_err ) mx_ff_err <=                                                     1'b1; 
 else if( mx_0_off_err ) mx_ff_err <=                                                     1'b1; 
 else if( mx_1_iff_err ) mx_ff_err <=                                                     1'b1; 
 else if( mx_1_off_err ) mx_ff_err <=                                                     1'b1; 
 else                    mx_ff_err <=                                                mx_ff_err;  
 //---------------------------------------------------------------------------------------------
 assign ff_err =                                                                     mx_ff_err;      
//=============================================================================================
// MUX
//=============================================================================================  
wire si_0_len  =  si_0_data[64]; 
wire si_1_len  =  si_1_data[64];   
wire si_0_hstb =  si_0_stb &&  si_0_sof;
wire si_1_hstb =  si_1_stb &&  si_1_sof; 
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)
    begin                                                                                       
        mx0_stb             <=                                                                1'b0;
        mx0_last              <=                                                                1'b0;
        mx0_sof         <=                                                                2'd0; 
        mx0_ack_0       <=                                                                9'b0;
        mx0_ack_1       <=                                                                9'b0;
        mx0_data        <=                                                               72'd0;
    end                            
 else if( (si_0_hstb && si_1_hstb) && (!mx0_ack_0[1] && !mx0_ack_1[1]))     
    begin                                                                                         
        mx0_stb             <=                                        mx0_ack_0[0] || mx0_ack_1[0];
        casex({mx0_last, si_0_len, si_1_len, m_dl_rdy[1:0]})                                    
          5'b0_x_0_x1:  mx0_last  <=                                                      1'b1;
          5'b0_x_1_1x:  mx0_last  <=                                                      1'b1; 
          5'b1_0_x_x1:  mx0_last  <=                                                      1'b0;
          5'b1_1_x_1x:  mx0_last  <=                                                      1'b0;
          default:      mx0_last  <=                                                  mx0_last;
        endcase
        mx0_sof         <=                                                               2'b10;
        casex({mx0_last, si_0_hstb, si_0_len, m_dl_rdy[1:0]})
          5'b1_1_1_1x:  mx0_ack_0 <=                                                    9'h1FF;
          5'b1_1_0_x1:  mx0_ack_0 <=                                                    9'h003;
          default:      mx0_ack_0 <=                                                    9'h000;
        endcase
        casex({mx0_last, si_1_hstb, si_1_len, m_dl_rdy[1:0]})
          5'b0_1_1_1x:  mx0_ack_1 <=                                                    9'h1FF;
          5'b0_1_0_x1:  mx0_ack_1 <=                                                    9'h003;
          default:      mx0_ack_1 <=                                                    9'h000;
        endcase
        mx0_data        <= (mx0_last == 1'b0)?                          si_0_data :  si_1_data;
    end  
 else if( (si_0_hstb || si_1_hstb) && (!mx0_ack_0[1] && !mx0_ack_1[1])) 
    begin                                                                                         
        mx0_stb             <=                                        mx0_ack_0[0] || mx0_ack_1[0]; 
        casex({si_0_hstb, si_0_len, si_1_len, m_dl_rdy[1:0]})                                    
          5'b0_x_0_x1:  mx0_last  <=                                                      1'b1;
          5'b0_x_1_1x:  mx0_last  <=                                                      1'b1; 
          5'b1_0_x_x1:  mx0_last  <=                                                      1'b0;
          5'b1_1_x_1x:  mx0_last  <=                                                      1'b0;
          default:      mx0_last  <=                                                  mx0_last;
        endcase
        mx0_sof         <=                                                               2'b10;
        casex({si_0_hstb, si_0_len, m_dl_rdy[1:0]})
          4'b1_1_1x:  mx0_ack_0 <=                                                      9'h1FF;
          4'b1_0_x1:  mx0_ack_0 <=                                                      9'h003;
          default:    mx0_ack_0 <=                                                      9'h000;
        endcase
        casex({si_1_hstb, si_1_len, m_dl_rdy[1:0]})
          4'b1_1_1x:  mx0_ack_1 <=                                                      9'h1FF;
          4'b1_0_x1:  mx0_ack_1 <=                                                      9'h003;
          default:    mx0_ack_1 <=                                                      9'h000;
        endcase
        mx0_data        <= (mx0_last == 1'b0)?                          si_0_data :  si_1_data;
    end 
 else if( mx0_ack_0[0] || mx0_ack_1[0] )    
    begin                                                                                         
        mx0_stb             <=                                                                1'b1;
        mx0_last              <=                                                            mx0_last;
        mx0_sof         <=                                                  {1'b0, mx0_sof[1]}; 
        mx0_ack_0       <=                                              {1'b0, mx0_ack_0[8:1]};
        mx0_ack_1       <=                                              {1'b0, mx0_ack_1[8:1]};
        mx0_data        <= (mx0_last == 1'b0)?                          si_0_data :  si_1_data;
    end                        
 else  
    begin                                                                                          
        mx0_stb             <=                                                                1'b0;
        mx0_last              <=                                                            mx0_last;
        mx0_sof         <=                                                                2'd0; 
        mx0_ack_0       <=                                              {1'b0, mx0_ack_0[8:1]};
        mx0_ack_1       <=                                              {1'b0, mx0_ack_1[8:1]};
        mx0_data        <= (mx0_last == 1'b0)?                          si_0_data :  si_1_data;
    end                                                                                        
//--------------------------------------------------------------------------------------------- 
assign si_0_ack   = mx0_ack_0[0];
assign si_1_ack   = mx0_ack_1[0];                                           
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)
    begin
        mx1_stb          <=                                                               1'b0;
        mx1_sof          <=                                                               1'b0;
        mx1_data         <=                                                              72'b0;
    end
 else if(mx0_sof[0])      
    begin       
        mx1_stb              <=                                                            mx0_stb;
        mx1_sof          <=                                                               1'b1;
        mx1_data         <= {mx0_data[71:64], mx0_data[59:52], 3'd0, si_1_ack, mx0_data[51:0]};
    end
 else
    begin       
        mx1_stb              <=                                                            mx0_stb;
        mx1_sof          <=                                                               1'b0;
        mx1_data         <=                                                           mx0_data;
    end
//=============================================================================================
// output
//=============================================================================================
assign                      m_dl_stb        =                                                    mx1_stb;
assign                      m_dl_sof        =                                                    mx1_sof;
assign                      m_dl_data       =                                                     mx1_data;
//=============================================================================================
// DEMUX
//=============================================================================================
always@(posedge clk or posedge rst)
 if(rst)
    begin
        dm0_stb          <=                                                                1'b0;
        dm0_stb_0        <=                                                                1'b0;
        dm0_stb_1        <=                                                                1'b0;
        dm0_sof          <=                                                                1'b0;
        dm0_data         <=                                                               72'b0;
    end
 else if(m_ul_stb & m_ul_sof)
    begin
        dm0_stb          <=                                                            m_ul_stb;
        dm0_stb_0        <=                                                      !m_ul_data[52];
        dm0_stb_1        <=                                                       m_ul_data[52];
        dm0_sof          <=                                                            m_ul_sof;
        dm0_data         <=         {m_ul_data[71:64], 4'd0, m_ul_data[63:56], m_ul_data[51:0]};
    end
 else if(m_ul_stb & !m_ul_sof)
    begin
        dm0_stb          <=                                                            m_ul_stb;
        dm0_sof          <=                                                            m_ul_sof;
        dm0_data         <=                                                           m_ul_data;
    end
 else 
    begin
        dm0_stb          <=                                                                1'b0;
        dm0_stb_0        <=                                                                1'b0;
        dm0_stb_1        <=                                                                1'b0;
        dm0_sof          <=                                                                1'b0;
        dm0_data         <=                                                           m_ul_data;
    end
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)
    begin
        dm1_stb_0        <=                                                                1'b0;
        dm1_stb_1        <=                                                                1'b0;
        dm1_sof          <=                                                                1'b0;
        dm1_data         <=                                                               72'b0;
    end
 else   
    begin
        dm1_stb_0        <=                                                dm0_stb_0 & dm0_stb;
        dm1_stb_1            <=                                                dm0_stb_1 & dm0_stb;
        dm1_sof          <=                                                            dm0_sof;
        dm1_data         <=                                                           dm0_data;
    end
//=============================================================================================
assign                      p0_ul_stb       =                                                dm1_stb_0;
assign                      p0_ul_sof       =                                                  dm1_sof;
assign                  p0_ul_data    =                                                 dm1_data;
//---------------------------------------------------------------------------------------------
assign                      p1_ul_stb       =                                                dm1_stb_1;
assign                      p1_ul_sof       =                                                  dm1_sof;
assign                p1_ul_data    =                                                 dm1_data;
//---------------------------------------------------------------------------------------------
assign                m_ul_rdy      =                                                     2'd3;
//=============================================================================================
endmodule
