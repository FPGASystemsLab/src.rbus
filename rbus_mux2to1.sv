//=============================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rbus_mux2to1
(
    input  wire             clk,
    input  wire             rst,   
                    
    input  wire             ia_stb,
    input  wire             ia_sof,
    input  wire    [71:0]   ia_data,
    output wire     [1:0]   ia_rdy,
          
    input  wire             ib_stb,
    input  wire             ib_sof,
    input  wire    [71:0]   ib_data,
    output wire     [1:0]   ib_rdy,

    output wire             o_stb,
    output wire             o_sof,
    output wire    [71:0]   o_data,
    input  wire     [1:0]   o_rdy,
    
    output wire             ff_err 
);
//=============================================================================================
// variables
//=============================================================================================
// mux                                                                        
//---------------------------------------------------------------------------------------------
wire        ia_iff_err;
wire        ia_off_err;
wire        ib_iff_err;
wire        ib_off_err;
reg         i_ff_err;
//---------------------------------------------------------------------------------------------
wire        si_a_stb;
wire        si_a_sof;
wire [71:0] si_a_data;
wire        si_a_ack;
//---------------------------------------------------------------------------------------------
wire        si_b_stb;
wire        si_b_sof;
wire [71:0] si_b_data;
wire        si_b_ack;                                        
//---------------------------------------------------------------------------------------------  
reg         mx0_stb;     
reg  [ 8:0] mx0_ack_a;
reg  [ 8:0] mx0_ack_b;   
reg  [ 1:0] mx0_sof;   
reg         mx0_last;   
reg  [71:0] mx0_data; 
//=============================================================================================
// input fifo
//=============================================================================================
// in_a
//---------------------------------------------------------------------------------------------
rbus_dff fifo_in0
(
.clk        (clk),
.rst        (rst),

.i_stb      (ia_stb),
.i_sof      (ia_sof),
.i_data     (ia_data),
.i_rdy      (ia_rdy), 
.i_err      (ia_iff_err),

.o_stb      (si_a_stb),
.o_sof      (si_a_sof),
.o_data     (si_a_data),
.o_ack      (si_a_ack),
.o_err      (ia_off_err)
);                         
//---------------------------------------------------------------------------------------------
// in_b
//---------------------------------------------------------------------------------------------
rbus_dff fifo_in1
(
.clk        (clk),
.rst        (rst),

.i_stb      (ib_stb),
.i_sof      (ib_sof),
.i_data     (ib_data),
.i_rdy      (ib_rdy), 
.i_err      (ib_iff_err),

.o_stb      (si_b_stb),
.o_sof      (si_b_sof),
.o_data     (si_b_data),
.o_ack      (si_b_ack),
.o_err      (ib_off_err)
);                       
//=============================================================================================
// fifos error indicator
//=============================================================================================
always@(posedge clk or posedge rst)
      if( rst          ) i_ff_err  <=                                                     1'b0;
 else if( ia_iff_err   ) i_ff_err  <=                                                     1'b1; 
 else if( ia_off_err   ) i_ff_err  <=                                                     1'b1; 
 else if( ib_iff_err   ) i_ff_err  <=                                                     1'b1; 
 else if( ib_off_err   ) i_ff_err  <=                                                     1'b1; 
 else                    i_ff_err  <=                                                 i_ff_err;  
 //---------------------------------------------------------------------------------------------
 assign ff_err =                                                                      i_ff_err;      
//=============================================================================================
// MUX
//=============================================================================================  
wire si_a_len  =                                                                 si_a_data[39]; 
wire si_b_len  =                                                                 si_b_data[39];   
wire si_a_hstb =                                                         si_a_stb &&  si_a_sof;
wire si_b_hstb =                                                         si_b_stb &&  si_b_sof; 
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)
    begin                                                                                       
        mx0_stb         <=                                                                1'b0;
        mx0_last        <=                                                                1'b0;
        mx0_sof         <=                                                                2'd0; 
        mx0_ack_a       <=                                                                9'b0;
        mx0_ack_b       <=                                                                9'b0;
        mx0_data        <=                                                               72'd0;
    end                            
 else if( (si_a_hstb && si_b_hstb) && (!mx0_ack_a[1] && !mx0_ack_b[1]))     
    begin                                                                                         
        mx0_stb         <=                                        mx0_ack_a[0] || mx0_ack_b[0];
        casex({mx0_last, si_a_len, si_b_len, o_rdy[1:0]})                                    
          5'b0_x_0_x1:  mx0_last  <=                                                      1'b1;
          5'b0_x_1_1x:  mx0_last  <=                                                      1'b1; 
          5'b1_0_x_x1:  mx0_last  <=                                                      1'b0;
          5'b1_1_x_1x:  mx0_last  <=                                                      1'b0;
          default:      mx0_last  <=                                                  mx0_last;
        endcase
        mx0_sof         <=                                                               2'b10;
        casex({mx0_last, si_a_hstb, si_a_len, o_rdy[1:0]})
          5'b1_1_1_1x:  mx0_ack_a <=                                                    9'h1FF;
          5'b1_1_0_x1:  mx0_ack_a <=                                                    9'h003;
          default:      mx0_ack_a <=                                                    9'h000;
        endcase
        casex({mx0_last, si_b_hstb, si_b_len, o_rdy[1:0]})
          5'b0_1_1_1x:  mx0_ack_b <=                                                    9'h1FF;
          5'b0_1_0_x1:  mx0_ack_b <=                                                    9'h003;
          default:      mx0_ack_b <=                                                    9'h000;
        endcase
        mx0_data        <= (mx0_last == 1'b0)?                          si_a_data :  si_b_data;
    end  
 else if( (si_a_hstb || si_b_hstb) && (!mx0_ack_a[1] && !mx0_ack_b[1])) 
    begin                                                                                         
        mx0_stb         <=                                        mx0_ack_a[0] || mx0_ack_b[0]; 
        casex({si_a_hstb, si_a_len, si_b_len, o_rdy[1:0]})                                    
          5'b0_x_0_x1:  mx0_last  <=                                                      1'b1;
          5'b0_x_1_1x:  mx0_last  <=                                                      1'b1; 
          5'b1_0_x_x1:  mx0_last  <=                                                      1'b0;
          5'b1_1_x_1x:  mx0_last  <=                                                      1'b0;
          default:      mx0_last  <=                                                  mx0_last;
        endcase
        mx0_sof         <=                                                               2'b10;
        casex({si_a_hstb, si_a_len, o_rdy[1:0]})
          4'b1_1_1x:    mx0_ack_a <=                                                    9'h1FF;
          4'b1_0_x1:    mx0_ack_a <=                                                    9'h003;
          default:      mx0_ack_a <=                                                    9'h000;
        endcase
        casex({si_b_hstb, si_b_len, o_rdy[1:0]})
          4'b1_1_1x:    mx0_ack_b <=                                                    9'h1FF;
          4'b1_0_x1:    mx0_ack_b <=                                                    9'h003;
          default:      mx0_ack_b <=                                                    9'h000;
        endcase
        mx0_data        <= (mx0_last == 1'b0)?                          si_a_data :  si_b_data;
    end 
 else if( mx0_ack_a[0] || mx0_ack_b[0] )    
    begin                                                                                         
        mx0_stb         <=                                                                1'b1;
        mx0_last        <=                                                            mx0_last;
        mx0_sof         <=                                                  {1'b0, mx0_sof[1]}; 
        mx0_ack_a       <=                                              {1'b0, mx0_ack_a[8:1]};
        mx0_ack_b       <=                                              {1'b0, mx0_ack_b[8:1]};
        mx0_data        <= (mx0_last == 1'b0)?                          si_a_data :  si_b_data;
    end                        
 else  
    begin                                                                                          
        mx0_stb         <=                                                                1'b0;
        mx0_last        <=                                                            mx0_last;
        mx0_sof         <=                                                                2'd0; 
        mx0_ack_a       <=                                              {1'b0, mx0_ack_a[8:1]};
        mx0_ack_b       <=                                              {1'b0, mx0_ack_b[8:1]};
        mx0_data        <= (mx0_last == 1'b0)?                          si_a_data :  si_b_data;
    end                                                                                        
//--------------------------------------------------------------------------------------------- 
assign si_a_ack        =                                                          mx0_ack_a[0];
assign si_b_ack        =                                                          mx0_ack_b[0];                                           
//=============================================================================================
// output
//=============================================================================================
assign o_stb           =                                                               mx0_stb;
assign o_sof           =                                                               mx0_sof;
assign o_data          =                                                              mx0_data;
//=============================================================================================
endmodule
