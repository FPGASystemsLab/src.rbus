//=============================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rbus_muxNto1
#(
parameter           N                                                                       = 2
) 
(
input  wire         clk,
input  wire         rst,   

input  wire         i_stb [0:N-1],                                                               
input  wire         i_sof [0:N-1],
input  wire [71:0]  i_data[0:N-1], 
output wire  [1:0]  i_rdy [0:N-1], 
output wire  [1:0]  i_rdyE[0:N-1],   

output wire         o_stb ,
output wire         o_sof ,
output wire [71:0]  o_data, 
input  wire  [1:0]  o_rdy ,
input  wire  [1:0]  o_rdyE,

output reg          ff_err
);   
//------------------------------------------------------------------------------------------------- 
// find_log2
//   Returns the 'log2' value for the input value for the supported ratios
//------------------------------------------------------------------------------------------------- 
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
      
//------------------------------------------------------------------------------------------------- 
function integer find_inputs_on_layer;
  input layer, N;
  integer layer, N;
  integer l, layer_inputs;
  begin     
    layer_inputs = N;
    for (l = 0; l < layer; l = l+1) begin
      layer_inputs = (layer_inputs+1) / 2;
    end                                                                                                                 
    find_inputs_on_layer = layer_inputs;
  end
endfunction 
//------------------------------------------------------------------------------------------------- 
function integer find_muxs_on_layer;
  input layer, N;
  integer layer, N;                 
  begin                                                                                                          
    find_muxs_on_layer = find_inputs_on_layer(layer+1,N);
  end
endfunction 
      
//=============================================================================================
// TODO
//=============================================================================================   
// pragma translate_off
initial
    begin
        if(N>1)        
            begin
            $display( "%m: signals \"..._rdyE\" not employed fully, so virtual channel for events can be blocked here." );       
            end 
    end
// pragma translate_on  
//=============================================================================================
// variables
//=============================================================================================
localparam LAYERS = find_log2(N);                                                             
//---------------------------------------------------------------------------------------------
wire [0:                    LAYERS-1] ff_mux_err_l;
//--------------------------------------------------------------------------------------------- 
// Comment for following signals declaration:
//  [0:N] not [0:N-1] - one additional space to obtain even number of inputs
//  [0:LAYER] not [0:LAYER-1] for layer that will be an output without mux
//  On each layer N connections are declared but decreasing number of them 
//  will be used on each consecutive layer but this way it is simpler to implement
wire [ 0:0] int_stb  [0:LAYERS][0:N]; 
wire [ 0:0] int_sof  [0:LAYERS][0:N]; 
wire [71:0] int_data [0:LAYERS][0:N]; 
wire [ 1:0] int_rdy  [0:LAYERS][0:N];

/*localparam [31:0] num_of_mux_on_layer    [0:LAYERS-1];
localparam [31:0] num_of_inputs_to_layer [0:LAYERS-1];

genvar layer_idx;
initial
begin
  for(layer_idx = 0; layer_idx < LAYERS ; layer_idx=layer_idx+1)
  begin
    num_of_inputs_to_layer = find_inputs_on_layer(layer_idx, N);
    num_of_mux_on_layer    = find_muxs_on_layer  (layer_idx, N);
  end
end*/

genvar in_idx;
generate
for(in_idx = 0; in_idx < N ; in_idx=in_idx+1)
begin: input_assigment
  assign i_rdy       [in_idx] = int_rdy [0][in_idx];
  assign i_rdyE      [in_idx] = int_rdy [0][in_idx]; // rdyE no supported by mux2x1   
  assign int_stb  [0][in_idx] = i_stb      [in_idx];
  assign int_sof  [0][in_idx] = i_sof      [in_idx];
  assign int_data [0][in_idx] = i_data     [in_idx];
end
endgenerate
//============================================================================================= 

generate
begin: mux_tree
  genvar layer;
  genvar mux_idx;
  genvar con_idx;              
  if(N == 1)
    begin : mux_bypass
      assign o_stb          =  i_stb [0];
      assign o_sof          =  i_sof [0];
      assign o_data         =  i_data[0]; 
      assign int_rdy[0][0]  =      o_rdy;
      assign ff_mux_err_l[0]=        'd0;
    end
  else begin: muxes2x1
    for(layer = 0; layer < LAYERS; layer = layer + 1)
    begin: one_layer
      wire [ 0:0] lay_i_stb  [0:find_inputs_on_layer(layer  , N)-1]; 
      wire [ 0:0] lay_i_sof  [0:find_inputs_on_layer(layer  , N)-1]; 
      wire [71:0] lay_i_data [0:find_inputs_on_layer(layer  , N)-1]; 
      wire [ 1:0] lay_i_rdy  [0:find_inputs_on_layer(layer  , N)-1];
      
      for(con_idx = 0; con_idx<find_inputs_on_layer(layer, N); con_idx=con_idx+1)
      begin: ass
        assign lay_i_stb         [con_idx] = int_stb  [layer  ][con_idx];
        assign lay_i_sof         [con_idx] = int_sof  [layer  ][con_idx];
        assign lay_i_data        [con_idx] = int_data [layer  ][con_idx];
        assign int_rdy  [layer  ][con_idx] = lay_i_rdy         [con_idx];
      end                                           
      
      wire [ 0:0] lay_o_stb  [0:find_inputs_on_layer(layer+1, N)-1]; 
      wire [ 0:0] lay_o_sof  [0:find_inputs_on_layer(layer+1, N)-1]; 
      wire [71:0] lay_o_data [0:find_inputs_on_layer(layer+1, N)-1]; 
      wire [ 1:0] lay_o_rdy  [0:find_inputs_on_layer(layer+1, N)-1];  
      
      for(con_idx = 0; con_idx<find_inputs_on_layer(layer+1, N); con_idx=con_idx+1)
      begin: ass2
        assign int_stb  [layer+1][con_idx] = lay_o_stb         [con_idx];
        assign int_sof  [layer+1][con_idx] = lay_o_sof         [con_idx];
        assign int_data [layer+1][con_idx] = lay_o_data        [con_idx];
        assign lay_o_rdy         [con_idx] = int_rdy  [layer+1][con_idx];
      end
      
      wire [ find_muxs_on_layer(layer, N)-1:0] lay_ff_mux_err_m;    
      //localparam odd_number_of_inputs = ((find_inputs_on_layer(layer, N) & 32'd1) != 0);
      for(mux_idx = 0; mux_idx < find_muxs_on_layer(layer,N); mux_idx=mux_idx+1)
        begin: mux2x1 
          // if we have odd number of inputs than one mux is a simple bypass
          // if it is a first or the last one than for bigger muxes, with number of layers higher than 2, 
          // one path can have a lot of bypasses. Structure can have more balanced number of muxes for all the inputs 
          // if bypass is inserted instead of other than last or first mux. I pisk a second mux on a layer:
          if((mux_idx == 1) && (find_inputs_on_layer(layer, N) & 32'd1))
            begin: mux_bypass
              assign lay_o_stb  [1 ] = lay_i_stb  [2];
              assign lay_o_sof  [1 ] = lay_i_sof  [2];
              assign lay_o_data [1 ] = lay_i_data [2];
              assign lay_i_rdy  [2 ] = lay_o_rdy  [1];
              assign lay_ff_mux_err_m[1] = 1'b0;
            end
          else
            begin: mux_instantion
              rbus_mux2to1ch mux2x1  
              (                                                                                                                               
              .clk      (clk),
              .rst      (rst), 
              
              .ia_stb   (lay_i_stb  [((find_inputs_on_layer(layer, N) & 32'd1) & (mux_idx>1))? mux_idx*2-1 : mux_idx*2  ]),
              .ia_sof   (lay_i_sof  [((find_inputs_on_layer(layer, N) & 32'd1) & (mux_idx>1))? mux_idx*2-1 : mux_idx*2  ]),
              .ia_data  (lay_i_data [((find_inputs_on_layer(layer, N) & 32'd1) & (mux_idx>1))? mux_idx*2-1 : mux_idx*2  ]),
              .ia_rdy   (lay_i_rdy  [((find_inputs_on_layer(layer, N) & 32'd1) & (mux_idx>1))? mux_idx*2-1 : mux_idx*2  ]),
                                  
              .ib_stb   (lay_i_stb  [((find_inputs_on_layer(layer, N) & 32'd1) & (mux_idx>1))? mux_idx*2   : mux_idx*2+1]),
              .ib_sof   (lay_i_sof  [((find_inputs_on_layer(layer, N) & 32'd1) & (mux_idx>1))? mux_idx*2   : mux_idx*2+1]),
              .ib_data  (lay_i_data [((find_inputs_on_layer(layer, N) & 32'd1) & (mux_idx>1))? mux_idx*2   : mux_idx*2+1]), 
              .ib_rdy   (lay_i_rdy  [((find_inputs_on_layer(layer, N) & 32'd1) & (mux_idx>1))? mux_idx*2   : mux_idx*2+1]), 
              
              .o_stb    (lay_o_stb  [mux_idx]),
              .o_sof    (lay_o_sof  [mux_idx]),
              .o_data   (lay_o_data [mux_idx]), 
              .o_rdy    (lay_o_rdy  [mux_idx]), 
              
              .ff_err   (lay_ff_mux_err_m[mux_idx])
              ); 
            end   
        end  
      if(layer == LAYERS - 1)
        begin 
          assign o_stb                = lay_o_stb  [0];
          assign o_sof                = lay_o_sof  [0];
          assign o_data               = lay_o_data [0];  
          assign int_rdy [layer+1][0] = o_rdy;
        end
      assign ff_mux_err_l[layer] = |lay_ff_mux_err_m;//[0:find_muxs_on_layer(layer,N)-1];
    end                                              
  end
end
endgenerate
//============================================================================================= 
always@(posedge clk or posedge rst)
if(rst)                    ff_err      <=                                                 1'b0;
else                       ff_err      <=                            ff_err || (|ff_mux_err_l);
//=============================================================================================
endmodule