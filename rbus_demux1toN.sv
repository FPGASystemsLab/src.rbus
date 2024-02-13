//=============================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rbus_demux1toN
#(
parameter           N                                                                       = 2
)  
(
input  wire         clk,
input  wire         rst,   

input  wire         i_stb,                                                               
input  wire         i_sof,
input  wire [71:0]  i_data,  
output wire  [1:0]  i_rdy,  
output wire  [1:0]  i_rdyE,   

output wire         o_stb [0:N-1],
output wire         o_sof [0:N-1],
output wire [71:0]  o_data[0:N-1],
input  wire  [1:0]  o_rdy [0:N-1],
input  wire  [1:0]  o_rdyE[0:N-1],

output reg          ff_err
);   
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

wire        ff_o_en;   
wire        ff_o_sof;   
wire [71:0] ff_o_data; 
wire        ff_has_l;  
wire        ff_has_s; 

wire [N-1: 0]     oN_stb  [0 : N];                                                              
wire [  0: 0]     oN_sof  [0 : N];
wire [ 71: 0]     oN_data [0 : N];
wire [N-1: 0]     oN_s_req[0 : N];
wire [N-1: 0]     oN_l_req[0 : N];
wire [N-1: 0]     oN_err; 
                            
reg               l_l_ava;
reg               l_s_ava;
reg               i0_last_len;
reg               i0_l_trg;
reg               i0_s_trg;
wire              i0_block_trg;
reg  [  4: 0]     i1_pnd_cnt;
wire              i1_pnd;
reg  [N-1: 0]     i1_pnd_token;
reg               i1_block_trg;
reg               i2_pnd;
reg  [N-1: 0]     i2_stb;
                                  
reg  [N-1: 0]     lN_s_req;
reg  [N-1: 0]     lN_l_req;
                              
reg  [N-1: 0]     lN_s_token; 
wire [N-1: 0]     lN_s_token_next; 
reg  [N-1: 0]     lN_l_token; 
wire [N-1: 0]     lN_l_token_next;   
   
wire              ff_in_err;  
//=============================================================================================	 
generate 
genvar nn;
  if(N == 1)
    begin : demux_bypass
      assign o_stb [0]    =  i_stb ;
      assign o_sof [0]    =  i_sof ;
      assign o_data[0]    =  i_data;  
      assign i_rdy        = o_rdy [0];
      assign i_rdyE       = o_rdyE[0];  
      assign oN_err       =     'd0;
      assign ff_in_err    =     'd0;
    end
  else
  	begin : demux_body 
    //=============================================================================================
    // input fifo
    //=============================================================================================
    rbus_2ch_ff fifo_in0
    (
    .clk        (clk),
    .rst        (rst),

    .frm_i_stb  (i_stb),
    .frm_i_sof  (i_sof),
    .frm_i_bus  (i_data), 
    .frm_i_rdy  (i_rdy),   
                
    .frm_o_en   (ff_o_en),
    .frm_o_sof  (ff_o_sof),
    .frm_o_bus  (ff_o_data),

    .has_long   (ff_has_l),
    .has_short  (ff_has_s),
    .trg_long   (i0_l_trg),
    .trg_short  (i0_s_trg),

    .ff_err     (ff_in_err)
    ); 
    assign i_rdyE = i_rdy; // rdyE not supported now so rdy is connected  
    //=============================================================================================  
    always@(posedge clk or posedge rst)
         if( rst             ) lN_s_req    <=                                                  'd0;
    else if( i0_s_trg        ) lN_s_req    <=             (lN_s_req | oN_s_req[N]) & (~lN_s_token);
    else                       lN_s_req    <=             (lN_s_req | oN_s_req[N])                ;
    //---------------------------------------------------------------------------------------------
    assign lN_s_token_next =                                  {lN_s_token[N-2:0], lN_s_token[N-1]};
    //---------------------------------------------------------------------------------------------
    always@(posedge clk or posedge rst)     
         if( rst             ) lN_s_token  <=                                                  'd1;
    else if( i0_s_trg        ) lN_s_token  <=                                      lN_s_token_next;
    else                       lN_s_token  <=                                      lN_s_token     ;
    //---------------------------------------------------------------------------------------------
    always@(posedge clk or posedge rst)
         if( rst             ) l_s_ava     <=                                                  'b0; 
    else if( i0_s_trg        ) l_s_ava     <=                  (lN_s_token_next & lN_s_req) != 'd0;
    else                       l_s_ava     <=                  (lN_s_token      & lN_s_req) != 'd0;
    //---------------------------------------------------------------------------------------------
    assign i0_block_trg =                                       i1_block_trg | i0_s_trg | i0_l_trg;
    //---------------------------------------------------------------------------------------------
    always@(posedge clk or posedge rst)
    if(rst)                    i0_s_trg    <=                                                  'b0;
    else casex({i0_block_trg, i0_last_len, l_l_ava, ff_has_l, l_s_ava, ff_has_s})
    6'b1_x_xx_xx:              i0_s_trg    <=                                                  'b0;
    6'b0_1_xx_11:              i0_s_trg    <=                                                  'b1;
    6'b0_0_x0_11:              i0_s_trg    <=                                                  'b1;
    6'b0_0_0x_11:              i0_s_trg    <=                                                  'b1;
    default:                   i0_s_trg    <=                                                  'b0;
    endcase
    //=============================================================================================
    always@(posedge clk or posedge rst)
         if( rst             ) lN_l_req    <=                                                  'd0;
    else if(i0_l_trg         ) lN_l_req    <=             (lN_l_req | oN_l_req[N]) & (~lN_l_token);
    else                       lN_l_req    <=             (lN_l_req | oN_l_req[N])                ;
    //---------------------------------------------------------------------------------------------
    assign lN_l_token_next =                                  {lN_l_token[N-2:0], lN_l_token[N-1]};
    //---------------------------------------------------------------------------------------------
    always@(posedge clk or posedge rst)
         if( rst             ) lN_l_token  <=                                                  'd1;
    else if( i0_l_trg        ) lN_l_token  <=                                      lN_l_token_next;
    else                       lN_l_token  <=                                      lN_l_token     ;
    //---------------------------------------------------------------------------------------------
    always@(posedge clk or posedge rst)
         if( rst             ) l_l_ava     <=                                                  'b0;
    else                       l_l_ava     <=                       (lN_l_token & lN_l_req) != 'd0;
    //---------------------------------------------------------------------------------------------
    always@(posedge clk or posedge rst)
    if(rst)                    i0_l_trg    <=                                                  'b0;
    else casex({i0_block_trg, i0_last_len, l_l_ava, ff_has_l, l_s_ava, ff_has_s})
    6'b1_x_xx_xx:              i0_l_trg    <=                                                  'b0;
    6'b0_0_11_xx:              i0_l_trg    <=                                                  'b1;
    6'b0_1_11_0x:              i0_l_trg    <=                                                  'b1;
    6'b0_1_11_x0:              i0_l_trg    <=                                                  'b1;
    default:                   i0_l_trg    <=                                                  'b0;
    endcase
    //=============================================================================================
    always@(posedge clk or posedge rst)
         if( rst             ) i0_last_len <=                                                  'b0;
    else if(i0_l_trg         ) i0_last_len <=                                                  'b1;
    else if(i0_s_trg         ) i0_last_len <=                                                  'b0;
    else                       i0_last_len <=                                          i0_last_len;
    //=============================================================================================
    always@(posedge clk or posedge rst)
         if( rst             ) i1_pnd_cnt  <=                                                  'b0;
    else if(i0_s_trg         ) i1_pnd_cnt  <=                                                  'd1;
    else if(i0_l_trg         ) i1_pnd_cnt  <=                                                  'd8;
    else if(!i1_pnd_cnt[4]   ) i1_pnd_cnt  <=                                     i1_pnd_cnt - 'd1;
    else                       i1_pnd_cnt  <=                                           i1_pnd_cnt;
    //---------------------------------------------------------------------------------------------
    always@(posedge clk)
    /*   if(i0_s_trg         ) i1_block_trg<=                                                 1'b1;
   else*/if(i0_l_trg         ) i1_block_trg<=                                                 1'b1;
    else if(i1_pnd_cnt[4]    ) i1_block_trg<=                                                 1'b0;
    else if(i1_pnd_cnt[3:0]==4'd2)i1_block_trg<=                                              1'b0;
    else                       i1_block_trg<=                                         i1_block_trg;
    //---------------------------------------------------------------------------------------------
    always@(posedge clk or posedge rst)
         if( rst             ) i1_pnd_token<=                                                  'b0;
    else if(i0_s_trg         ) i1_pnd_token<=                                           lN_s_token;
    else if(i0_l_trg         ) i1_pnd_token<=                                           lN_l_token;
    else                       i1_pnd_token<=                                         i1_pnd_token;
    //---------------------------------------------------------------------------------------------
    assign i1_pnd =                                                                 !i1_pnd_cnt[4];
    //=============================================================================================
    always@(posedge clk or posedge rst)
         if( rst             ) i2_stb      <=                                                  'b0;
    else if(i1_pnd           ) i2_stb      <=                                         i1_pnd_token;
    else                       i2_stb      <=                                                  'b0;
    //---------------------------------------------------------------------------------------------
    always@(posedge clk or posedge rst)
         if( rst             ) i2_pnd      <=                                                  'b0;
    else                       i2_pnd      <=                                               i1_pnd;
    //=============================================================================================
    assign oN_data [0] =                                                                 ff_o_data; 
    assign oN_sof  [0] =                                                                 ff_o_sof ; 
    assign oN_s_req[0] =                                                                       'd0; 
    assign oN_l_req[0] =                                                                       'd0; 
    assign oN_stb  [0] =                                                                    i2_stb;
    //=============================================================================================
	  for(nn = 0; nn < N; nn = nn + 1)
	    begin: demuxs
	      rbus_demux_out_stage
	      #(
        .N         (N),
        .ID        (nn)
        )
	      demux_out_stage
	      (                                                                                                                               
	      .clk       (clk),
	      .rst       (rst), 
	                 
	      .i_stb_bus (oN_stb    [nn]),                                                               
	      .i_sof     (oN_sof    [nn]),
	      .i_data    (oN_data   [nn]),
	      .i_req_s   (oN_s_req  [nn]),
	      .i_req_l   (oN_l_req  [nn]), 
	      
	      .o_stb_bus (oN_stb    [nn+1]),
	      .o_sof     (oN_sof    [nn+1]),
	      .o_data    (oN_data   [nn+1]),
	      .o_req_s   (oN_s_req  [nn+1]),
	      .o_req_l   (oN_l_req  [nn+1]),
	      
	      .frm_stb   (o_stb    [nn]),
	      .frm_sof   (o_sof    [nn]),
	      .frm_data  (o_data   [nn]),
	      .frm_rdy   (o_rdy    [nn]),
	      
	      .err       (oN_err   [nn])
	      );
	    end 
	end
endgenerate	
//============================================================================================= 
always@(posedge clk or posedge rst)
if(rst)                    ff_err      <=                                                 1'b0;
else                       ff_err      <=                     ff_err || ff_in_err || (|oN_err);
//=============================================================================================
endmodule
                       
//=============================================================================================
module rbus_demux_out_stage
#(
parameter           N                                                                       = 2,
parameter           ID                                                                      = 1
)  
(
input  wire         clk,
input  wire         rst,   

input  wire [N-1:0] i_stb_bus,                                                              
input  wire         i_sof    ,
input  wire [71: 0] i_data   ,  
input  wire [N-1:0] i_req_s  , 
input  wire [N-1:0] i_req_l  ,   
                    
output reg  [N-1:0] o_stb_bus,                                                              
output reg          o_sof    ,
output reg  [71: 0] o_data   ,  
output reg  [N-1:0] o_req_s  , 
output reg  [N-1:0] o_req_l  ,  
                    
output reg          frm_stb  ,                                                              
output wire         frm_sof  ,
output wire [71: 0] frm_data ,  
input  wire [ 1: 0] frm_rdy  , 
                    
output reg          err
);     
localparam MINIMAL_RDY_UPDATE_TIME = 2; // valid values in a range <2,6>, 0 and 1 will result in 2
//=============================================================================================
wire      frm_ins_hl;
wire      frm_ins_hs;

wire      int_trg_sample_rdy_l;
reg [2:0] int_del_cnt_l;
reg       int_sample_rdy_l;
reg       int_done_l;
wire      int_ins_req_l;

wire      int_trg_sample_rdy_s;
reg [2:0] int_del_cnt_s;
reg       int_sample_rdy_s;
reg       int_done_s;
wire      int_ins_req_s;
//=============================================================================================
always@(posedge clk or posedge rst)
     if(rst          ) frm_stb  <=                                                        1'b0;
else if(i_stb_bus[ID]) frm_stb  <=                                                        1'b1;
else                   frm_stb  <=                                                        1'b0;
//---------------------------------------------------------------------------------------------
assign frm_sof    =                                                                      o_sof;
assign frm_data   =                                                                     o_data;
assign frm_ins_hl =                                         frm_stb &  frm_sof &  frm_data[39];
assign frm_ins_hs =                                         frm_stb &  frm_sof & !frm_data[39];
//=============================================================================================
always@(posedge clk or posedge rst)
     if(rst          ) o_stb_bus <=                                                        'd0;
else                   o_stb_bus <=                                     i_stb_bus & ~(1 << ID);
//---------------------------------------------------------------------------------------------
always@(posedge clk ) begin
                       o_data    <=                                                     i_data;
                       o_sof     <=                                                      i_sof;
end
//=============================================================================================
assign int_trg_sample_rdy_l =                                                       frm_ins_hl;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
     if(rst                               ) int_del_cnt_l <=                               'b0;
else if(int_trg_sample_rdy_l              ) int_del_cnt_l <=       MINIMAL_RDY_UPDATE_TIME - 3; // ze sprawdzeniem sygnału rdy poczekaj kilka taktów tak zeby odbiorca uwzglednil wlasnie wyslany pakiet
else if(!int_del_cnt_l[2]                 ) int_del_cnt_l <=                 int_del_cnt_l - 1;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
     if(rst                               ) int_done_l    <=                              1'b0;
else if(int_trg_sample_rdy_l              ) int_done_l    <=                              1'b0;
else                                        int_done_l    <=       int_done_l || int_ins_req_l;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
     if(rst                               ) int_sample_rdy_l <=                           1'b0;
else if(int_ins_req_l                     ) int_sample_rdy_l <=                           1'b0;
else if( int_del_cnt_l[2] & !int_done_l   ) int_sample_rdy_l <=                           1'b1;
else                                        int_sample_rdy_l <=               int_sample_rdy_l;
//---------------------------------------------------------------------------------------------
assign int_ins_req_l =                                           int_sample_rdy_l & frm_rdy[1];
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
     if(rst          ) o_req_l <=                                                          'b0;
else                   o_req_l <=                             i_req_l  | (int_ins_req_l << ID);
//=============================================================================================
assign int_trg_sample_rdy_s =                                                       frm_ins_hs;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
     if(rst                               ) int_del_cnt_s <=                               'b0;
else if(int_trg_sample_rdy_s              ) int_del_cnt_s <=       MINIMAL_RDY_UPDATE_TIME - 3; // ze sprawdzeniem sygnału rdy poczekaj kilka taktów tak zeby odbiorca uwzglednil wlasnie wyslany pakiet
else if(!int_del_cnt_s[2]                 ) int_del_cnt_s <=                 int_del_cnt_s - 1;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
     if(rst                               ) int_done_s    <=                              1'b0;
else if(int_trg_sample_rdy_s              ) int_done_s    <=                              1'b0;
else                                        int_done_s    <=       int_done_s || int_ins_req_s;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
     if(rst                               ) int_sample_rdy_s <=                           1'b0;
else if(int_ins_req_s                     ) int_sample_rdy_s <=                           1'b0;
else if( int_del_cnt_s[2] & !int_done_s   ) int_sample_rdy_s <=                           1'b1;
else                                        int_sample_rdy_s <=               int_sample_rdy_s;
//---------------------------------------------------------------------------------------------
assign int_ins_req_s =                                           int_sample_rdy_s & frm_rdy[0];
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
     if(rst          ) o_req_s <=                                                          'b0;
else                   o_req_s <=                             i_req_s  | (int_ins_req_s << ID);
//=============================================================================================
always@(posedge clk or posedge rst)
     if(rst                     ) err     <=                                               'b0;
else if(frm_ins_hl & !frm_rdy[1]) err     <=                                               'b1;
else if(frm_ins_hs & !frm_rdy[0]) err     <=                                               'b1;
else                              err     <=                                               err;
//=============================================================================================
endmodule