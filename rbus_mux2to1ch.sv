//=============================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//
// Output of this module can be connected ONLY to a receiver with separate FIFOs for long and 
// short packets, because this module uses the property of independent control for O_RDY for
// both packets types.
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rbus_mux2to1ch
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
wire        ia_ff_err;
wire        ib_ff_err;
reg         i_ff_err;
//---------------------------------------------------------------------------------------------
wire        si_a_en;
wire        si_a_sof;
wire [71:0] si_a_data;
wire        si_a_has_l;
wire        si_a_has_s;
//---------------------------------------------------------------------------------------------
wire        si_b_en;
wire        si_b_sof;
wire [71:0] si_b_data;
wire        si_b_has_l;
wire        si_b_has_s;                                       
//---------------------------------------------------------------------------------------------  
wire [ 3:0] mx0_pkt_trgn;
wire        mx0_trg_asn;
wire        mx0_trg_aln;
wire        mx0_trg_bsn;
wire        mx0_trg_bln;
reg         mx0_nt_as; 
reg         mx0_nt_al; 
reg         mx0_nt_bs;
reg         mx0_nt_bl; 
wire        mx0_nt_s;
wire        mx0_nt_l;
wire [ 3:0] mx0_next_trg; 
reg         mx0_lst_pkt_len;
reg  [ 1:0] mx0_pri_ptr;
reg         mx0_pkt_trgx;
reg  [ 3:0] mx0_pkt_trg;
reg  [ 3:0] mx0_pkt_dcnt;
wire        mx0_block_norm_trg;
reg  [ 4:0] mx0_gap_slen_dcnt;
wire        mx0_block_same_len_trg; 
wire        mx0_gap_rdy;

wire        mx0_trg_as;
wire        mx0_trg_al;
wire        mx0_trg_bs;
wire        mx0_trg_bl;
  
reg         mx0_stb;     
reg         mx0_sof;     
reg  [71:0] mx0_data; 
//=============================================================================================
// input fifo
//=============================================================================================
// in_a
//---------------------------------------------------------------------------------------------
rbus_2ch_ff fifo_in0
(
.clk        (clk),
.rst        (rst),

.frm_i_stb  (ia_stb),
.frm_i_sof  (ia_sof),
.frm_i_bus  (ia_data),
.frm_i_rdy  (ia_rdy), 
            
.frm_o_en   (si_a_en),
.frm_o_sof  (si_a_sof),
.frm_o_bus  (si_a_data),

.has_long   (si_a_has_l),
.has_short  (si_a_has_s),
.trg_long   (mx0_trg_al),
.trg_short  (mx0_trg_as),

.ff_err     (ia_ff_err)
);                         
//---------------------------------------------------------------------------------------------
// in_b
//---------------------------------------------------------------------------------------------
rbus_2ch_ff fifo_in1
(
.clk        (clk),
.rst        (rst),

.frm_i_stb  (ib_stb),
.frm_i_sof  (ib_sof),
.frm_i_bus  (ib_data),
.frm_i_rdy  (ib_rdy), 
            
.frm_o_en   (si_b_en),
.frm_o_sof  (si_b_sof),
.frm_o_bus  (si_b_data),

.has_long   (si_b_has_l),
.has_short  (si_b_has_s),
.trg_long   (mx0_trg_bl),
.trg_short  (mx0_trg_bs),

.ff_err     (ib_ff_err)
);                       
//=============================================================================================
// fifos error indicator
//=============================================================================================
always@(posedge clk or posedge rst)
      if( rst          ) i_ff_err  <=                                                     1'b0;
 else if( ia_ff_err    ) i_ff_err  <=                                                     1'b1; 
 else if( ib_ff_err    ) i_ff_err  <=                                                     1'b1; 
 else                    i_ff_err  <=                                                 i_ff_err;  
 //---------------------------------------------------------------------------------------------
 assign ff_err =                                                                      i_ff_err;      
//=============================================================================================
// MUX
//=============================================================================================   
wire si_a_hstb =                                                           si_a_en && si_a_sof;
wire si_b_hstb =                                                           si_b_en && si_b_sof; 
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                           mx0_pkt_trgx      <=                                   1'b0;
else if (mx0_pkt_trgx)             mx0_pkt_trgx      <=                                   1'b0;
else                               mx0_pkt_trgx      <=      (|mx0_next_trg) &   mx0_gap_rdy  ;
//---------------------------------------------------------------------------------------------
assign mx0_pkt_trgn =                          mx0_next_trg & {4{mx0_gap_rdy & !mx0_pkt_trgx}};
assign mx0_trg_asn  =                                                          mx0_pkt_trgn[3];
assign mx0_trg_aln  =                                                          mx0_pkt_trgn[2];
assign mx0_trg_bsn  =                                                          mx0_pkt_trgn[1];
assign mx0_trg_bln  =                                                          mx0_pkt_trgn[0];
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                           mx0_pkt_trg       <=                                   4'd0;
else if (mx0_pkt_trgx)             mx0_pkt_trg       <=                                   4'd0;
else                               mx0_pkt_trg       <=        mx0_next_trg & {4{mx0_gap_rdy}};
//---------------------------------------------------------------------------------------------
assign mx0_trg_as  =                                                            mx0_pkt_trg[3];
assign mx0_trg_al  =                                                            mx0_pkt_trg[2];
assign mx0_trg_bs  =                                                            mx0_pkt_trg[1];
assign mx0_trg_bl  =                                                            mx0_pkt_trg[0];
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                           mx0_lst_pkt_len   <=                                   1'b1;
else if(mx0_trg_al | mx0_trg_bl)   mx0_lst_pkt_len   <=                                   1'b1;
else if(mx0_trg_as | mx0_trg_bs)   mx0_lst_pkt_len   <=                                   1'b0;
else                               mx0_lst_pkt_len   <=                        mx0_lst_pkt_len;
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                           mx0_pkt_dcnt      <=                                   4'hF;
else if(mx0_trg_al | mx0_trg_bl)   mx0_pkt_dcnt      <=                                   4'd6;
else if(mx0_trg_as | mx0_trg_bs)   mx0_pkt_dcnt      <=                                   4'hF;
else if(mx0_block_norm_trg     )   mx0_pkt_dcnt      <=                    mx0_pkt_dcnt - 4'd1;
//---------------------------------------------------------------------------------------------
assign mx0_block_norm_trg     =                                               !mx0_pkt_dcnt[3];
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                           mx0_gap_slen_dcnt <=                                  5'h1F;
else if(mx0_trg_al | mx0_trg_bl)   mx0_gap_slen_dcnt <=                                   5'd6; 
else if(mx0_trg_as | mx0_trg_bs)   mx0_gap_slen_dcnt <=                                   5'd3; // short packet after short packet needs to be separated by few clock cycles to update o_rdy
else if(mx0_block_same_len_trg )   mx0_gap_slen_dcnt <=               mx0_gap_slen_dcnt - 5'd1;
//---------------------------------------------------------------------------------------------
assign mx0_block_same_len_trg =                                          !mx0_gap_slen_dcnt[4];
assign mx0_nt_s    =                                                     mx0_nt_as | mx0_nt_bs;
assign mx0_nt_l    =                                                     mx0_nt_al | mx0_nt_bl;
assign mx0_gap_rdy =                 ((mx0_lst_pkt_len == mx0_nt_l) & !mx0_block_same_len_trg)| 
                                     ((mx0_lst_pkt_len != mx0_nt_l) & !mx0_block_norm_trg    );
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                 mx0_pri_ptr    <=                                               2'b00;
 else if(mx0_trg_asn)    mx0_pri_ptr    <=                                               2'b00;
 else if(mx0_trg_aln)    mx0_pri_ptr    <=                                               2'b01;
 else if(mx0_trg_bsn)    mx0_pri_ptr    <=                                               2'b10;
 else if(mx0_trg_bln)    mx0_pri_ptr    <=                                               2'b11;
 else                    mx0_pri_ptr    <=                                         mx0_pri_ptr; 
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)                {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b0000;
 else   casex({mx0_pri_ptr, (si_a_has_s & o_rdy[0]), (si_a_has_l & o_rdy[1]), (si_b_has_s & o_rdy[0]), (si_b_has_l & o_rdy[1])})                                
          6'b00_x1_xx:  {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b0100; // highest priority for a_long
          6'b00_x0_x1:  {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b0001; // high    priority for b_long
          6'b00_10_x0:  {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b1000; // low     priority for a_short
          6'b00_00_10:  {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b0010; // lowest  priority for b_short
                                                                                
          6'b01_xx_1x:  {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b0010; // highest priority for b_short 
          6'b01_1x_0x:  {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b1000; // high    priority for a_short 
          6'b01_0x_01:  {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b0001; // low     priority for b_long
          6'b01_01_00:  {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b0100; // lowest  priority for a_long
                                                                                
          6'b10_xx_x1:  {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b0001; // highest priority for b_long 
          6'b10_x1_x0:  {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b0100; // high    priority for a_long 
          6'b10_x0_10:  {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b0010; // low     priority for b_short
          6'b10_10_00:  {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b1000; // lowest  priority for a_short
                                                                                
          6'b11_1x_xx:  {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b1000; // highest priority for a_short  
          6'b11_0x_1x:  {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b0010; // high    priority for b_short  
          6'b11_01_0x:  {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b0100; // low     priority for a_long   
          6'b11_00_01:  {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b0001; // lowest  priority for b_long   
                                                                                
          default:      {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl}  <=               4'b0000;
        endcase
//---------------------------------------------------------------------------------------------
assign mx0_next_trg =                             {mx0_nt_as, mx0_nt_al, mx0_nt_bs, mx0_nt_bl};
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)mx0_stb         <=                                                                1'b0;
 else   mx0_stb         <=                                                   si_a_en | si_b_en;
//---------------------------------------------------------------------------------------------
always@(posedge clk)  
      if( si_a_en )     
    begin                                                                                       
        mx0_sof         <=                                                           si_a_sof ;
        mx0_data        <=                                                           si_a_data;
    end                          
 else if( si_b_en )     
    begin                                                                                      
        mx0_sof         <=                                                           si_b_sof ;
        mx0_data        <=                                                           si_b_data;
    end  
 else  
    begin                                                                                      
        mx0_sof         <=                                                                1'b0;
        mx0_data        <=                                                           si_b_data;
    end                                                                                                                                  
//=============================================================================================
// output
//=============================================================================================
assign o_stb           =                                                               mx0_stb;
assign o_sof           =                                                               mx0_sof;
assign o_data          =                                                              mx0_data;
//=============================================================================================
endmodule
