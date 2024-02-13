//=============================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rbus_memhub_axi
#(
parameter CTRLS_NUM = 1,
parameter BURST_BITS = 256
)
(
    input  wire             clk,
    input  wire             rst,   

    input  wire             mcb_if_rst,// reset signal correlated with the memory controler initialization process
    input  wire             mcb_if_clk,// sys_clk_i divided by 4 or 2 (2 for current configuration) needs to be used for the input interface
                
    input  wire             rbus_i_stb      [0 : CTRLS_NUM-1],
    input  wire             rbus_i_sof      [0 : CTRLS_NUM-1],
    input  wire    [71:0]   rbus_i_data     [0 : CTRLS_NUM-1],
    output wire     [1:0]   rbus_i_rdy      [0 : CTRLS_NUM-1],
    
    output wire             rbus_o_stb      [0 : CTRLS_NUM-1],
    output wire             rbus_o_sof      [0 : CTRLS_NUM-1],
    output wire    [71:0]   rbus_o_data     [0 : CTRLS_NUM-1],
    input  wire     [1:0]   rbus_o_rdy      [0 : CTRLS_NUM-1],
    
    // AXI                                  
    output wire    [28:0]   M_AXI_awaddr    [0 : CTRLS_NUM-1], // Write Address Channel Address
    output wire    [ 1:0]   M_AXI_awburst   [0 : CTRLS_NUM-1], // Write Address Channel Burst Type code (0-2) - incremental so each transaction increase address by AWSIZE bytes
    output wire    [ 3:0]   M_AXI_awcache   [0 : CTRLS_NUM-1], // Write Address Channel Cache Characteristics - no buffering and not-cachable
    output wire    [ 1:0]   M_AXI_awid      [0 : CTRLS_NUM-1], // Write Address Channel Transaction ID
    output wire    [ 7:0]   M_AXI_awlen     [0 : CTRLS_NUM-1], // Write Address Channel Burst Length (0-255) - burst = 8 transactions
    output wire             M_AXI_awlock    [0 : CTRLS_NUM-1], // Write Address Channel Atomic Access Type (0, 1) - atomic access by AXI functionality is not used in our system
    output wire    [ 2:0]   M_AXI_awprot    [0 : CTRLS_NUM-1], // Write Address Channel Protection Bits - Normal & secure & data access but I think it is not important in our system
    output wire    [ 3:0]   M_AXI_awqos     [0 : CTRLS_NUM-1], // AXI4 Write Address Channel Quality of Service - not used in a crossbar, only propagated from Slave to Master
    input  wire             M_AXI_awready   [0 : CTRLS_NUM-1], // Write Address Channel Ready
    output wire    [ 3:0]   M_AXI_awregion  [0 : CTRLS_NUM-1], //???
    output wire    [ 2:0]   M_AXI_awsize    [0 : CTRLS_NUM-1], // Write Address Channel Transfer Size code (0-7) - 8 bytes per transaction
    output wire             M_AXI_awvalid   [0 : CTRLS_NUM-1], //Write Address Channel Valid
    input  wire    [ 1:0]   M_AXI_bid       [0 : CTRLS_NUM-1], // Write Response Channel Transaction ID - always the same as awid, and there is no need to check it
    output wire             M_AXI_bready    [0 : CTRLS_NUM-1], // Write Response Channel Ready - always ready for a write reponse
    input  wire    [ 1:0]   M_AXI_bresp     [0 : CTRLS_NUM-1], // Write Response Channel Response Code (0-3) - 0(ok; 1(exok; 2(slverr; 3(decerr) - assumed to always be OK in our system
    input  wire             M_AXI_bvalid    [0 : CTRLS_NUM-1], // Write Response Channel Valid
    output wire    [63:0]   M_AXI_wdata     [0 : CTRLS_NUM-1], // Write Data Channel Data
    output wire             M_AXI_wlast     [0 : CTRLS_NUM-1], // Write Data Channel Last Data Beat
    input  wire             M_AXI_wready    [0 : CTRLS_NUM-1], // Write Data Channel Ready
    output wire    [ 7:0]   M_AXI_wstrb     [0 : CTRLS_NUM-1], // Write Data Channel Byte Strobes
    output wire             M_AXI_wvalid    [0 : CTRLS_NUM-1], // Write Data Channel Valid
    
    output wire    [28:0]   M_AXI_araddr    [0 : CTRLS_NUM-1], // Read Address Channel Address
    output wire    [ 1:0]   M_AXI_arburst   [0 : CTRLS_NUM-1], // Read Address Channel Burst Type (0-2) - incremental so each transaction increase address by ARSIZE bytes
    output wire    [ 3:0]   M_AXI_arcache   [0 : CTRLS_NUM-1], // Read Address Channel Cache Characteristics - no buffering and not-cachable
    output wire    [ 1:0]   M_AXI_arid      [0 : CTRLS_NUM-1], // Read Address Channel Transaction ID
    output wire    [ 7:0]   M_AXI_arlen     [0 : CTRLS_NUM-1], // Read Address Channel Burst Length code (0-255) - burst = 8 transactions
    output wire             M_AXI_arlock    [0 : CTRLS_NUM-1], // Read Address Channel Atomic Access Type (0, 1) - atomic access by AXI functionality is not used in our system
    output wire    [ 2:0]   M_AXI_arprot    [0 : CTRLS_NUM-1], // Read Address Channel Protection Bits - Normal & secure & data access but I think it is not important in our system
    output wire    [ 3:0]   M_AXI_arqos     [0 : CTRLS_NUM-1], // AXI4 Read Address Channel Quality of Service - not used in a crossbar, only propagated from Slave to Master
    input  wire             M_AXI_arready   [0 : CTRLS_NUM-1], // Read Address Channel Ready
    output wire    [ 3:0]   M_AXI_arregion  [0 : CTRLS_NUM-1], //???
    output wire    [ 2:0]   M_AXI_arsize    [0 : CTRLS_NUM-1], // Read Address Channel Transfer Size code (0-7) - 8 bytes per transaction
    output wire             M_AXI_arvalid   [0 : CTRLS_NUM-1], // Read Address Channel Valid
    input  wire    [63:0]   M_AXI_rdata     [0 : CTRLS_NUM-1], // Read Data Channel Data
    input  wire    [ 1:0]   M_AXI_rid       [0 : CTRLS_NUM-1], // Read Data Channel Transaction ID
    input  wire             M_AXI_rlast     [0 : CTRLS_NUM-1], // Read Data Channel Last Data Beat
    output wire             M_AXI_rready    [0 : CTRLS_NUM-1], // Read Data Channel Ready
    input  wire    [ 1:0]   M_AXI_rresp     [0 : CTRLS_NUM-1], // Read Data Channel Response Code (0-3) - not used in our system
    input  wire             M_AXI_rvalid    [0 : CTRLS_NUM-1], // Read Data Channel Valid
 
    output wire             ff_err,
        
    output wire    [8:0]    dbg             [0 : CTRLS_NUM-1],
    output wire    [9:0]    dbg2            [0 : CTRLS_NUM-1]
);
//===============================================================================
// variables
//=============================================================================================

wire [CTRLS_NUM-1 : 0] rbus_i_ff_err;
wire [CTRLS_NUM-1 : 0] rbus_o_ff_err;
reg          ff_ovr_err;
//=============================================================================================
  // User Port-0 command interface 
  wire         mif_cmd_wr_stb    [0 : CTRLS_NUM-1]; 
  wire         mif_cmd_rd_stb    [0 : CTRLS_NUM-1];     
  wire [38:0]  mif_cmd_byte_addr [0 : CTRLS_NUM-1]; 
  wire         mif_cmd_rd_rdy    [0 : CTRLS_NUM-1];
  wire         mif_cmd_wr_rdy    [0 : CTRLS_NUM-1];
  // User Port-0 data write interface 
  wire         mif_wr_en         [0 : CTRLS_NUM-1];
  wire [ 7:0]  mif_wr_mask       [0 : CTRLS_NUM-1];
  wire [63:0]  mif_wr_data       [0 : CTRLS_NUM-1];
  wire         mif_wr_data_end   [0 : CTRLS_NUM-1];
  wire         mif_wr_data_rdy   [0 : CTRLS_NUM-1];

  wire         mif_wr_mem_resp_en[0 : CTRLS_NUM-1];
  // User Port-0 data read interface 
  wire [63:0]  mif_rd_data       [0 : CTRLS_NUM-1];
  wire         mif_rd_data_end   [0 : CTRLS_NUM-1];
  wire         mif_rd_data_valid [0 : CTRLS_NUM-1];
//=============================================================================================
genvar if_id;
generate
for(if_id = 0; if_id < CTRLS_NUM; if_id = if_id + 1)
begin : bank_of_rbus_mif64_axi_insts   
  //=============================================================================================
  // port 0
  //=============================================================================================
  rbus_mif64_axi rbus_mif64_axi_inst
  (
  .net_clk  (clk),
  .net_rst  (rst),
  .mem_clk  (mcb_if_clk),
  .rst      (mcb_if_rst),   

  .i_stb    (rbus_i_stb   [if_id]),
  .i_sof    (rbus_i_sof   [if_id]),
  .i_data   (rbus_i_data  [if_id]),
  .i_rdy    (rbus_i_rdy   [if_id]),
  .i_ff_err (rbus_i_ff_err[if_id]),

  .o_stb    (rbus_o_stb   [if_id]),
  .o_sof    (rbus_o_sof   [if_id]),
  .o_data   (rbus_o_data  [if_id]),
  .o_rdy    (rbus_o_rdy   [if_id]),
  .o_ff_err (rbus_o_ff_err[if_id]),
  .o_dbg_err(),

  .co_rd_stb(mif_cmd_rd_stb    [if_id]),
  .co_wr_stb(mif_cmd_wr_stb    [if_id]),
  .co_addr  (mif_cmd_byte_addr [if_id]),
  .co_wr_rdy(mif_cmd_wr_rdy    [if_id]),
  .co_rd_rdy(mif_cmd_rd_rdy    [if_id]),

  .do_stb   (mif_wr_en         [if_id]),
  .do_mask  (mif_wr_mask       [if_id]),
  .do_data  (mif_wr_data       [if_id]),
  .do_rdy   (mif_wr_data_rdy   [if_id]), 
  .do_end   (mif_wr_data_end   [if_id]),

  .ci_wr_end(mif_wr_mem_resp_en[if_id]),

  .di_en    (mif_rd_data_valid [if_id]),
  .di_end   (mif_rd_data_end   [if_id]),
  .di_data  (mif_rd_data       [if_id]),

  .dbg      (dbg2              [if_id])
  );
  assign dbg[if_id] = {mif_cmd_rd_stb[if_id], mif_cmd_wr_stb[if_id], mif_wr_en[if_id], mif_wr_data_rdy[if_id], mif_wr_data_end[if_id], mif_rd_data_valid[if_id], mif_rd_data_end[if_id], rbus_o_ff_err[if_id], rbus_i_ff_err[if_id]}; 
  //=============================================================================================
  // MCB AXI interface
  //=============================================================================================
  assign M_AXI_awaddr       [if_id] = mif_cmd_byte_addr[if_id]; // Write Address Channel Address
  assign M_AXI_awburst      [if_id] = 2'b01; // Write Address Channel Burst Type code (0-2) - incremental so each transaction increase address by AWSIZE bytes
  assign M_AXI_awcache      [if_id] = 4'b0000; // Write Address Channel Cache Characteristics - no buffering and not-cachable
  assign M_AXI_awid         [if_id] = 2'd0; // Write Address Channel Transaction ID
  assign M_AXI_awlen        [if_id] = (BURST_BITS/8/8 - 1); // Write Address Channel Burst Length (0-255)
  assign M_AXI_awlock       [if_id] = 1'b0;// Write Address Channel Atomic Access Type (0, 1) - atomic access by AXI functionality is not used in our system
  assign M_AXI_awprot       [if_id] = 3'b000; // Write Address Channel Protection Bits - Normal & secure & data access but I think it is not important in our system
  assign M_AXI_awqos        [if_id] = 4'd0; // AXI4 Write Address Channel Quality of Service - not used in a crossbar, only propagated from Slave to Master
  assign mif_cmd_wr_rdy     [if_id] = M_AXI_awready [if_id]; // Write Address Channel Ready
  assign M_AXI_awregion     [if_id] = 4'd0; //???
  assign M_AXI_awsize       [if_id] = 3'b011; // Write Address Channel Transfer Size code (0-7) - 8 bytes per transaction
  assign M_AXI_awvalid      [if_id] = mif_cmd_wr_stb[if_id]; //Write Address Channel Valid
  //assign                          = M_AXI_bid[if_id]; // Write Response Channel Transaction ID - always the same as awid, and there is no need to check it
  assign M_AXI_bready       [if_id] = 1'b1/*input [1]*/; // Write Response Channel Ready - always ready for a write reponse
  //assign                          = M_AXI_bresp[if_id]; // Write Response Channel Response Code (0-3) - 0(ok; 1(exok; 2(slverr; 3(decerr) - assumed to always be OK in our system
  assign mif_wr_mem_resp_en [if_id] = M_AXI_bvalid [if_id]; // Write Response Channel Valid
  assign M_AXI_wdata        [if_id] = mif_wr_data[if_id]; // Write Data Channel Data
  assign M_AXI_wlast        [if_id] = mif_wr_data_end[if_id]; // Write Data Channel Last Data Beat
  assign mif_wr_data_rdy    [if_id] = M_AXI_wready [if_id]; // Write Data Channel Ready
  assign M_AXI_wstrb        [if_id] = ~mif_wr_mask[if_id]; // Write Data Channel Byte Strobes
  assign M_AXI_wvalid       [if_id] = mif_wr_en[if_id]; // Write Data Channel Valid

  assign M_AXI_araddr       [if_id] = mif_cmd_byte_addr[if_id]; // Read Address Channel Address
  assign M_AXI_arburst      [if_id] = 2'b01; // Read Address Channel Burst Type (0-2) - incremental so each transaction increase address by ARSIZE bytes
  assign M_AXI_arcache      [if_id] = 4'b0000; // Read Address Channel Cache Characteristics - no buffering and not-cachable
  assign M_AXI_arid         [if_id] = 2'd1; // Read Address Channel Transaction ID
  assign M_AXI_arlen        [if_id] = (BURST_BITS/8/8 - 1); // Write Address Channel Burst Length (0-255)
  assign M_AXI_arlock       [if_id] = 1'b0; // Read Address Channel Atomic Access Type (0, 1) - atomic access by AXI functionality is not used in our system
  assign M_AXI_arprot       [if_id] = 3'b000; // Read Address Channel Protection Bits - Normal & secure & data access but I think it is not important in our system
  assign M_AXI_arqos        [if_id] = 4'd0; // AXI4 Read Address Channel Quality of Service - not used in a crossbar, only propagated from Slave to Master
  assign mif_cmd_rd_rdy     [if_id] = M_AXI_arready [if_id]; // Read Address Channel Ready
  assign M_AXI_arregion     [if_id] = 4'd0; //???
  assign M_AXI_arsize       [if_id] = 3'b011; // Read Address Channel Transfer Size code (0-7) - 8 bytes per transaction
  assign M_AXI_arvalid      [if_id] = mif_cmd_rd_stb[if_id]; // Read Address Channel Valid
  assign mif_rd_data        [if_id]        = M_AXI_rdata [if_id]; // Read Data Channel Data
  //assign                          = M_AXI_rid[if_id]; // Read Data Channel Transaction ID
  assign mif_rd_data_end    [if_id] = M_AXI_rlast [if_id]; // Read Data Channel Last Data Beat
  assign M_AXI_rready       [if_id] = 1'b1; // Read Data Channel Ready
  //assign                          = M_AXI_rresp[if_id]; // Read Data Channel Response Code (0-3) - not used in our system
  assign mif_rd_data_valid  [if_id] = M_AXI_rvalid [if_id]; // Read Data Channel Valid
end
endgenerate 
//=============================================================================================
always @(posedge clk or posedge rst)                                                              
if( rst                )ff_ovr_err    <=                                                   1'b0; 
else if(|rbus_i_ff_err )ff_ovr_err    <=                                                   1'b1;   
else if(|rbus_o_ff_err )ff_ovr_err    <=                                                   1'b1;
else                    ff_ovr_err    <=                                             ff_ovr_err;  
//---------------------------------------------------------------------------------------------- 
assign ff_err =                                                                      ff_ovr_err;
//============================================================================================== 
endmodule
