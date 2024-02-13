//=============================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rbus_memhub_axis
#(
parameter [0:0] HUB_ID       = 1'd0,
parameter       SEND_WR_FB   = "TRUE"  // "TRUE", "FALSE"
)
(
    input  wire             clk,
    input  wire             rst,   

    input  wire             mcb_if_rst,// reset signal correlated with the memory controler initialization process
    input  wire             mcb_if_clk,// sys_clk_i divided by 4 or 2 (2 for current configuration) needs to be used for the input interface
                
    input  wire             rbus_i_stb      ,
    input  wire             rbus_i_sof      ,
    input  wire    [71:0]   rbus_i_data     ,
    output wire     [1:0]   rbus_i_rdy      ,
    
    output wire             rbus_o_stb      ,
    output wire             rbus_o_sof      ,
    output wire    [71:0]   rbus_o_data     ,
    input  wire     [1:0]   rbus_o_rdy      ,
    
    // AXI                                  
    output wire    [28:0]   M_AXI_awaddr    , // Write Address Channel Address
    output wire    [ 1:0]   M_AXI_awburst   , // Write Address Channel Burst Type code (0-2) - incremental so each transaction increase address by AWSIZE bytes
    output wire    [ 3:0]   M_AXI_awcache   , // Write Address Channel Cache Characteristics - no buffering and not-cachable
    output wire    [ 1:0]   M_AXI_awid      , // Write Address Channel Transaction ID
    output wire    [ 7:0]   M_AXI_awlen     , // Write Address Channel Burst Length (0-255) - burst = 8 transactions
    output wire             M_AXI_awlock    , // Write Address Channel Atomic Access Type (0, 1) - atomic access by AXI functionality is not used in our system
    output wire    [ 2:0]   M_AXI_awprot    , // Write Address Channel Protection Bits - Normal & secure & data access but I think it is not important in our system
    output wire    [ 3:0]   M_AXI_awqos     , // AXI4 Write Address Channel Quality of Service - not used in a crossbar, only propagated from Slave to Master
    input  wire             M_AXI_awready   , // Write Address Channel Ready
    output wire    [ 3:0]   M_AXI_awregion  , //???
    output wire    [ 2:0]   M_AXI_awsize    , // Write Address Channel Transfer Size code (0-7) - 8 bytes per transaction
    output wire             M_AXI_awvalid   , //Write Address Channel Valid
    input  wire    [ 1:0]   M_AXI_bid       , // Write Response Channel Transaction ID - always the same as awid, and there is no need to check it
    output wire             M_AXI_bready    , // Write Response Channel Ready - always ready for a write reponse
    input  wire    [ 1:0]   M_AXI_bresp     , // Write Response Channel Response Code (0-3) - 0(ok; 1(exok; 2(slverr; 3(decerr) - assumed to always be OK in our system
    input  wire             M_AXI_bvalid    , // Write Response Channel Valid
    output wire    [63:0]   M_AXI_wdata     , // Write Data Channel Data
    output wire             M_AXI_wlast     , // Write Data Channel Last Data Beat
    input  wire             M_AXI_wready    , // Write Data Channel Ready
    output wire    [ 7:0]   M_AXI_wstrb     , // Write Data Channel Byte Strobes
    output wire             M_AXI_wvalid    , // Write Data Channel Valid
    
    output wire    [28:0]   M_AXI_araddr    , // Read Address Channel Address
    output wire    [ 1:0]   M_AXI_arburst   , // Read Address Channel Burst Type (0-2) - incremental so each transaction increase address by ARSIZE bytes
    output wire    [ 3:0]   M_AXI_arcache   , // Read Address Channel Cache Characteristics - no buffering and not-cachable
    output wire    [ 1:0]   M_AXI_arid      , // Read Address Channel Transaction ID
    output wire    [ 7:0]   M_AXI_arlen     , // Read Address Channel Burst Length code (0-255) - burst = 8 transactions
    output wire             M_AXI_arlock    , // Read Address Channel Atomic Access Type (0, 1) - atomic access by AXI functionality is not used in our system
    output wire    [ 2:0]   M_AXI_arprot    , // Read Address Channel Protection Bits - Normal & secure & data access but I think it is not important in our system
    output wire    [ 3:0]   M_AXI_arqos     , // AXI4 Read Address Channel Quality of Service - not used in a crossbar, only propagated from Slave to Master
    input  wire             M_AXI_arready   , // Read Address Channel Ready
    output wire    [ 3:0]   M_AXI_arregion  , //???
    output wire    [ 2:0]   M_AXI_arsize    , // Read Address Channel Transfer Size code (0-7) - 8 bytes per transaction
    output wire             M_AXI_arvalid   , // Read Address Channel Valid
    input  wire    [63:0]   M_AXI_rdata     , // Read Data Channel Data
    input  wire    [ 1:0]   M_AXI_rid       , // Read Data Channel Transaction ID
    input  wire             M_AXI_rlast     , // Read Data Channel Last Data Beat
    output wire             M_AXI_rready    , // Read Data Channel Ready
    input  wire    [ 1:0]   M_AXI_rresp     , // Read Data Channel Response Code (0-3) - not used in our system
    input  wire             M_AXI_rvalid    , // Read Data Channel Valid
 
    output wire             ff_err,
        
    output wire    [8:0]    dbg             ,
    output wire    [9:0]    dbg2            
);        
//=============================================================================================
// parameters check
//=============================================================================================   
// pragma translate_off
initial
    begin
        if((SEND_WR_FB != "TRUE") && (SEND_WR_FB != "FALSE"))        
            begin
            $display( "%m !!!ERROR!!! SEND_WR_FB = %s, is out of range (\"TRUE\" \"FALSE\")", SEND_WR_FB );
            $finish;
            end 
    end
// pragma translate_on   
//===============================================================================
// variables
//=============================================================================================

wire  rbus_i_ff_err;
wire  rbus_o_ff_err;
reg          ff_ovr_err;
//=============================================================================================
  // User Port-0 command interface 
  wire         mif_cmd_wr_stb    ; 
  wire         mif_cmd_rd_stb    ;     
  wire [38:0]  mif_cmd_byte_addr ; 
  wire         mif_cmd_rd_rdy    ;
  wire         mif_cmd_wr_rdy    ;
  // User Port-0 data write inter
  wire         mif_wr_en         ;
  wire [ 7:0]  mif_wr_mask       ;
  wire [63:0]  mif_wr_data       ;
  wire         mif_wr_data_end   ;
  wire         mif_wr_data_rdy   ;

  wire         mif_wr_mem_resp_en;
  // User Port-0 data read interf
  wire [63:0]  mif_rd_data       ;
  wire         mif_rd_data_end   ;
  wire         mif_rd_data_valid ;
  
//=============================================================================================
// port 0
//=============================================================================================
rbus_mif64_axi 
#( 
.BURST_BORDER (1024*4), // read/write burst should not cross border of 4KB
.SEND_WR_FB   (SEND_WR_FB)
)
rbus_mif64_axi_inst
(
.net_clk  (clk),
.net_rst  (rst),
.mem_clk  (mcb_if_clk),
.rst      (mcb_if_rst),   

.i_stb    (rbus_i_stb   ),
.i_sof    (rbus_i_sof   ),
.i_data   (rbus_i_data  ),
.i_rdy    (rbus_i_rdy   ),
.i_ff_err (rbus_i_ff_err),

.o_stb    (rbus_o_stb   ),
.o_sof    (rbus_o_sof   ),
.o_data   (rbus_o_data  ),
.o_rdy    (rbus_o_rdy   ),
.o_ff_err (rbus_o_ff_err),
.o_dbg_err(),

.co_rd_stb(mif_cmd_rd_stb    ),
.co_wr_stb(mif_cmd_wr_stb    ),
.co_addr  (mif_cmd_byte_addr ),
.co_wr_rdy(mif_cmd_wr_rdy    ),
.co_rd_rdy(mif_cmd_rd_rdy    ),

.do_stb   (mif_wr_en         ),
.do_mask  (mif_wr_mask       ),
.do_data  (mif_wr_data       ),
.do_rdy   (mif_wr_data_rdy   ), 
.do_end   (mif_wr_data_end   ),

.ci_wr_end(mif_wr_mem_resp_en),

.di_en    (mif_rd_data_valid ),
.di_end   (mif_rd_data_end   ),
.di_data  (mif_rd_data       ),

.dbg      (dbg2              )
);
assign dbg  = {mif_cmd_rd_stb , mif_cmd_wr_stb , mif_wr_en , mif_wr_data_rdy , mif_wr_data_end , mif_rd_data_valid , mif_rd_data_end , rbus_o_ff_err , rbus_i_ff_err }; 
//=============================================================================================
// MCB AXI interface
//=============================================================================================
assign M_AXI_awaddr         = mif_cmd_byte_addr ; // Write Address Channel Address
assign M_AXI_awburst        = 2'b01; // Write Address Channel Burst Type code (0-2) - incremental so each transaction increase address by AWSIZE bytes
assign M_AXI_awcache        = 4'b0000; // Write Address Channel Cache Characteristics - no buffering and not-cachable
assign M_AXI_awid           = {HUB_ID, 1'b0}; // Write Address Channel Transaction ID
assign M_AXI_awlen          = 8'd7; // Write Address Channel Burst Length (0-255) - 8 x transactions per command
assign M_AXI_awlock         = 1'b0;// Write Address Channel Atomic Access Type (0, 1) - atomic access by AXI functionality is not used in our system
assign M_AXI_awprot         = 3'b000; // Write Address Channel Protection Bits - Normal & secure & data access but I think it is not important in our system
assign M_AXI_awqos          = 4'd0; // AXI4 Write Address Channel Quality of Service - not used in a crossbar, only propagated from Slave to Master
assign mif_cmd_wr_rdy       = M_AXI_awready  ; // Write Address Channel Ready
assign M_AXI_awregion       = 4'd0; //???
assign M_AXI_awsize         = 3'b011; // Write Address Channel Transfer Size code (0-7) - 8 bytes per transaction
assign M_AXI_awvalid        = mif_cmd_wr_stb ; //Write Address Channel Valid
//assign                          = M_AXI_bid ; // Write Response Channel Transaction ID - always the same as awid, and there is no need to check it
assign M_AXI_bready         = 1'b1/*input [1]*/; // Write Response Channel Ready - always ready for a write reponse
//assign                          = M_AXI_bresp ; // Write Response Channel Response Code (0-3) - 0(ok; 1(exok; 2(slverr; 3(decerr) - assumed to always be OK in our system
assign mif_wr_mem_resp_en   = M_AXI_bvalid  ; // Write Response Channel Valid
assign M_AXI_wdata          = mif_wr_data ; // Write Data Channel Data
assign M_AXI_wlast          = mif_wr_data_end ; // Write Data Channel Last Data Beat
assign mif_wr_data_rdy      = M_AXI_wready  ; // Write Data Channel Ready
assign M_AXI_wstrb          = ~mif_wr_mask ; // Write Data Channel Byte Strobes
assign M_AXI_wvalid         = mif_wr_en ; // Write Data Channel Valid

assign M_AXI_araddr         = mif_cmd_byte_addr ; // Read Address Channel Address
assign M_AXI_arburst        = 2'b01; // Read Address Channel Burst Type (0-2) - incremental so each transaction increase address by ARSIZE bytes
assign M_AXI_arcache        = 4'b0000; // Read Address Channel Cache Characteristics - no buffering and not-cachable
assign M_AXI_arid           = {HUB_ID, 1'b0}; // Read Address Channel Transaction ID
assign M_AXI_arlen          = 8'd7; // Read Address Channel Burst Length code (0-255) - 8 x transactions per command
assign M_AXI_arlock         = 1'b0; // Read Address Channel Atomic Access Type (0, 1) - atomic access by AXI functionality is not used in our system
assign M_AXI_arprot         = 3'b000; // Read Address Channel Protection Bits - Normal & secure & data access but I think it is not important in our system
assign M_AXI_arqos          = 4'd0; // AXI4 Read Address Channel Quality of Service - not used in a crossbar, only propagated from Slave to Master
assign mif_cmd_rd_rdy       = M_AXI_arready  ; // Read Address Channel Ready
assign M_AXI_arregion       = 4'd0; //???
assign M_AXI_arsize         = 3'b011; // Read Address Channel Transfer Size code (0-7) - 8 bytes per transaction
assign M_AXI_arvalid        = mif_cmd_rd_stb ; // Read Address Channel Valid
assign mif_rd_data                 = M_AXI_rdata  ; // Read Data Channel Data
//assign                          = M_AXI_rid ; // Read Data Channel Transaction ID
assign mif_rd_data_end      = M_AXI_rlast  ; // Read Data Channel Last Data Beat
assign M_AXI_rready         = 1'b1; // Read Data Channel Ready
//assign                          = M_AXI_rresp ; // Read Data Channel Response Code (0-3) - not used in our system
assign mif_rd_data_valid    = M_AXI_rvalid  ; // Read Data Channel Valid

//=============================================================================================
always @(posedge clk or posedge rst)                                                              
if( rst                )ff_ovr_err    <=                                                   1'b0; 
else if(rbus_i_ff_err  )ff_ovr_err    <=                                                   1'b1;   
else if(rbus_o_ff_err  )ff_ovr_err    <=                                                   1'b1;
else                    ff_ovr_err    <=                                             ff_ovr_err;  
//---------------------------------------------------------------------------------------------- 
assign ff_err =                                                                      ff_ovr_err;
//============================================================================================== 
endmodule
