//=============================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                                                                            
//============================================================================================= 
// N=3                            i_[0]    i_[1]     i_[2]
//                                 |         |         |    
//                                 v         v         v    
//                               _____     _____     _____   
// N* DEMUX_1xM                 /_____\   /_____\   /_____\  
//                               |   |     |   |     |   |  
//  N*M                   x_[0]  |   |     |   |     |   |  x_[N*M-1]
//                               v   v     v   v     v   v    
//                               ___________    ___________  
// M* MUX_Nx1                   \__________/   \__________/
//                                   |              |      
//                                   v              v      
// M=2                             o_[0]           o_[1]
//=============================================================================================
module rbus_muxNtoM_2x3
#(
parameter           N                                                                       = 2,
parameter           M                                                                       = 3
)
(
input  wire         clk,
input  wire         rst,   

input  wire         i_stb [0:N-1],                                                               
input  wire         i_sof [0:N-1],
input  wire [71:0]  i_data[0:N-1],
output wire [ 1:0]  i_rdy [0:N-1],
output wire [ 1:0]  i_rdyE[0:N-1],   

output wire         o_stb [0:M-1],
output wire         o_sof [0:M-1],
output wire [71:0]  o_data[0:M-1],
input  wire [ 1:0]  o_rdy [0:M-1],
input  wire [ 1:0]  o_rdyE[0:M-1],

output reg          ff_err
);      
//==============================================================================================
// channels number change with demux & mux section
//==============================================================================================
wire         x_stb  [0: (N * M) - 1 ] ;
wire         x_sof  [0: (N * M) - 1 ] ;
wire  [71:0] x_data [0: (N * M) - 1 ] ; 
wire  [ 1:0] x_rdy  [0: (N * M) - 1 ] ;
wire  [ 1:0] x_rdyE [0: (N * M) - 1 ] ;


wire [N-1:0]  dmx_ff_err;
wire [M-1:0]  mx_ff_err;
//==============================================================================================
genvar in_ch_id;
genvar out_ch_id;
//----------------------------------------------------------------------------------------------
generate
  if( N == M )
    //------------------------------------------------------------------------------------------
    for(out_ch_id = 0; out_ch_id < M; out_ch_id = out_ch_id+1) 
      begin: simple_assign
        assign o_stb     [out_ch_id]=                                         i_stb [out_ch_id];
        assign o_sof     [out_ch_id]=                                         i_sof [out_ch_id];
        assign o_data    [out_ch_id]=                                         i_data[out_ch_id];
        assign i_rdy     [out_ch_id]=                                         o_rdy [out_ch_id];
        assign i_rdyE    [out_ch_id]=                                         o_rdyE[out_ch_id];
        assign dmx_ff_err           =                                            'b0           ;
        assign mx_ff_err            =                                            'b0           ;
      end
    //------------------------------------------------------------------------------------------ 
  else
    //------------------------------------------------------------------------------------------ 
    begin: demux_mux_instantions
      for(in_ch_id = 0; in_ch_id < N; in_ch_id = in_ch_id+1)
        begin: in_demux    
          
          wire         dmo_stb  [0: M - 1 ] ;
          wire         dmo_sof  [0: M - 1 ] ;
          wire  [71:0] dmo_data [0: M - 1 ] ;
          wire  [ 1:0] dmo_rdy  [0: M - 1 ] ;
          wire  [ 1:0] dmo_rdyE [0: M - 1 ] ;
          
          rbus_demux1toN
          #(.N (M)) 
          demux_expansion
          (                                                                                                                           
          .clk       (clk),
          .rst       (rst), 								 					   

          .i_stb     (i_stb [in_ch_id]),                                                               
          .i_sof     (i_sof [in_ch_id]),
          .i_data    (i_data[in_ch_id]), 
          .i_rdy     (i_rdy [in_ch_id]), 
          .i_rdyE    (i_rdyE[in_ch_id]), 

          .o_stb     (dmo_stb ),
          .o_sof     (dmo_sof ),
          .o_data    (dmo_data),
          .o_rdy     (dmo_rdy ),
          .o_rdyE    (dmo_rdyE),

          .ff_err    (dmx_ff_err[in_ch_id])
          );    
          
          for(out_ch_id = 0; out_ch_id < M; out_ch_id = out_ch_id+1)
            begin: arrays_assign
              assign x_stb [in_ch_id*M + out_ch_id] = dmo_stb [out_ch_id];
              assign x_sof [in_ch_id*M + out_ch_id] = dmo_sof [out_ch_id];
              assign x_data[in_ch_id*M + out_ch_id] = dmo_data[out_ch_id]; 
              assign dmo_rdy [out_ch_id] = x_rdy [in_ch_id*M + out_ch_id];
              assign dmo_rdyE[out_ch_id] = x_rdyE[in_ch_id*M + out_ch_id];
            end
        end  
      //----------------------------------------------------------------------------------------  
      for(out_ch_id = 0; out_ch_id < M; out_ch_id = out_ch_id+1)
        begin: out_muxs
          
          wire         dmi_stb  [0: N - 1 ] ;
          wire         dmi_sof  [0: N - 1 ] ;
          wire  [71:0] dmi_data [0: N - 1 ] ;  
          wire  [ 1:0] dmi_rdy  [0: N - 1 ] ;
          wire  [ 1:0] dmi_rdyE [0: N - 1 ] ;
          
          for(in_ch_id = 0; in_ch_id < N; in_ch_id = in_ch_id+1) 
            begin: arrays_assign
              assign dmi_stb [in_ch_id] = x_stb [out_ch_id*N + in_ch_id];
              assign dmi_sof [in_ch_id] = x_sof [out_ch_id*N + in_ch_id];
              assign dmi_data[in_ch_id] = x_data[out_ch_id*N + in_ch_id]; 
              assign x_rdy [out_ch_id*N + in_ch_id] = dmi_rdy [in_ch_id];
              assign x_rdyE[out_ch_id*N + in_ch_id] = dmi_rdyE[in_ch_id];
            end
            
          rbus_muxNto1
          #(.N (N)) 
          mux_reduction
          (                                                                                                                           
          .clk       (clk),
          .rst       (rst), 

          .i_stb     (dmi_stb ),                                                               
          .i_sof     (dmi_sof ),
          .i_data    (dmi_data), 
          .i_rdy     (dmi_rdy ), 
          .i_rdyE    (dmi_rdyE), 

          .o_stb     (o_stb [out_ch_id]),
          .o_sof     (o_sof [out_ch_id]),
          .o_data    (o_data[out_ch_id]),  
          .o_rdy     (o_rdy [out_ch_id]),
          .o_rdyE    (o_rdyE[out_ch_id]),

          .ff_err    (mx_ff_err[out_ch_id])
          ); 
        end
    //------------------------------------------------------------------------------------------
    end
endgenerate
//==============================================================================================
always@(posedge clk or posedge rst)
if(rst)                    ff_err      <=                                                  1'b0;
else                       ff_err      <=               ff_err || (|mx_ff_err) || (|dmx_ff_err);
//==============================================================================================
endmodule