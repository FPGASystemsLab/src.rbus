//==============================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//==============================================================================================
`default_nettype none
//----------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//==============================================================================================
module rsbus_slice_dr_box
(
 input  wire            clk,  
 input  wire            rst,    
 
 // lower level ring bus interface
 input  wire            i_stb,
 input  wire            i_sof,
 input  wire    [71:0]  i_data,
 output wire     [1:0]  i_rdy, 

 output wire            o_stb,
 output wire            o_sof,
 output wire    [71:0]  o_data,
 input  wire     [1:0]  o_rdy, 
 input  wire     [1:0]  o_rdyE,  
                            
 // RS 232 ports
 output wire            rs_rst,   
 
 input  wire            rs_d2r_stb, 
 input  wire            rs_d2r_sof, 
 input  wire    [71:0]  rs_d2r_data,
 output wire     [1:0]  rs_d2r_rdy, 
 
 input  wire            rs_d2r_eve_stb, 
 input  wire    [ 7:0]  rs_d2r_eve_dev, 
 input  wire    [ 7:0]  rs_d2r_eve_cmd, 
 input  wire    [39:0]  rs_d2r_eve_ptr, 
 output wire            rs_d2r_eve_ack,  
                           
 output wire            rs_r2d_stb,     
 output wire            rs_r2d_sof,     
 output wire    [71:0]  rs_r2d_data,    
 input  wire     [1:0]  rs_r2d_rdy,      
                                       
 output wire            rs_r2d_eve_stb, 
 output wire    [ 7:0]  rs_r2d_eve_cmd, 
 output wire    [39:0]  rs_r2d_eve_ptr, 
 input  wire            rs_r2d_eve_ack, 
 
 // VGA ports
 output wire            vga_rst,   
 
 input  wire            vga_d2r_stb, 
 input  wire            vga_d2r_sof, 
 input  wire    [71:0]  vga_d2r_data,
 output wire     [1:0]  vga_d2r_rdy, 
 
 input  wire            vga_d2r_eve_stb, 
 input  wire    [ 7:0]  vga_d2r_eve_dev, 
 input  wire    [ 7:0]  vga_d2r_eve_cmd,
 input  wire    [39:0]  vga_d2r_eve_ptr,
 output wire            vga_d2r_eve_ack,  
                       
 output wire            vga_r2d_stb,    
 output wire            vga_r2d_sof, 
 output wire    [71:0]  vga_r2d_data,
 input  wire     [1:0]  vga_r2d_rdy, 
 
 output wire            vga_r2d_eve_stb, 
 output wire    [ 7:0]  vga_r2d_eve_cmd,
 output wire    [39:0]  vga_r2d_eve_ptr,
 input  wire            vga_r2d_eve_ack,
                             
 // EXTERNAL DEV0 ports            
 input  wire            ext0_d2r_stb, 
 input  wire            ext0_d2r_sof,
 input  wire    [ 3:0]  ext0_d2r_iid,
 input  wire    [71:0]  ext0_d2r_data,
 output wire     [1:0]  ext0_d2r_rdy,   
 output wire     [1:0]  ext0_d2r_rdyE,         
                       
 output wire            ext0_r2d_stb,   
 output wire            ext0_r2d_sof, 
 output wire    [ 3:0]  ext0_r2d_iid,
 output wire    [71:0]  ext0_r2d_data,
 input  wire     [1:0]  ext0_r2d_rdy,  
                                  
 // EXTERNAL DEV1 ports            
 input  wire            ext1_d2r_stb, 
 input  wire            ext1_d2r_sof,  
 input  wire    [ 3:0]  ext1_d2r_iid,
 input  wire    [71:0]  ext1_d2r_data,
 output wire     [1:0]  ext1_d2r_rdy,  
 output wire     [1:0]  ext1_d2r_rdyE,         
                       
 output wire            ext1_r2d_stb,   
 output wire            ext1_r2d_sof, 
 output wire    [ 3:0]  ext1_r2d_iid,
 output wire    [71:0]  ext1_r2d_data,
 input  wire     [1:0]  ext1_r2d_rdy, 
 
 // EXTERNAL DEV2 ports            
 input  wire            ext2_d2r_stb, 
 input  wire            ext2_d2r_sof,  
 input  wire    [ 3:0]  ext2_d2r_iid,
 input  wire    [71:0]  ext2_d2r_data,
 output wire     [1:0]  ext2_d2r_rdy, 
 output wire     [1:0]  ext2_d2r_rdyE, 
 
 output wire            ext2_r2d_stb,   
 output wire            ext2_r2d_sof,
 output wire    [ 3:0]  ext2_r2d_iid, 
 output wire    [71:0]  ext2_r2d_data,
 input  wire     [1:0]  ext2_r2d_rdy, 
 
 output reg     [15:0]  dbg,
 output wire            ff_err
);                             
//==============================================================================================
// local param
//==============================================================================================
localparam         DEVNUM =                                                                   5;
// pragma translate_off
// pragma translate_on       
//==============================================================================================
// variables
//==============================================================================================    
wire            d2r_sof  [0:DEVNUM + 5];
wire    [11:0]  d2r_ctrl [0:DEVNUM + 5];
wire    [71:0]  d2r_data [0:DEVNUM + 5];
//---------------------------------------------------------------------------------------------- 
wire            r2d_sof  [0:DEVNUM + 5];
wire    [71:0]  r2d_data [0:DEVNUM + 5];
//----------------------------------------------------------------------------------------------
wire            d2r_mgr_ff_err;  
wire [DEVNUM:0] d2r_inj_ff_err; 
wire [     1:0] devif_ff_err;
reg             ff_ovr_err;                    
//==============================================================================================
// Frame  generator for D2R ring
//==============================================================================================
rsbus_frame_generator d2r_frame_generator
(
.clk            (clk),
.rst            (rst),                                          
                                                            
.i_sof          (d2r_sof  [0]),
.i_ctrl         (d2r_ctrl [0]),
.i_bus          (d2r_data [0]),   

.o_sof          (d2r_sof  [1]),
.o_ctrl         (d2r_ctrl [1]),
.o_bus          (d2r_data [1])
); 
//..............................................................................................
assign           r2d_sof  [1]   =                                                  r2d_sof  [0];
assign           r2d_data [1]   =                                                  r2d_data [0];
//==============================================================================================
// RBUS access manager
//==============================================================================================
rsbus_d2r_mgr 
#(                                         
.FF_DEPTH          ((DEVNUM > 8)? 64 : ((DEVNUM > 4)? 32 : 16)),     
// if ff depth is set as above than internal ffs can not overflow because d2r_injectors can 
// insert only 4 requests so it gives #(DEVNUM*4) requests of each packets type 
// (various combinations of length and priority)
// Situation changed because of additional slots for packets with packet priority 3 that
// are now available in d2r_injectors. If an unlikely situation occures and all devices in a ring 
// sends packets with PP3 than a total number of those types of request can be #(DEVNUM*5) for 
// a long packets and #(DEVNUM*6) for a short packets. This situation is indeed very unlikely 
// but to preserve a valid network operation under all conditions a new parameter is introduced. 
// That is the FF_CAN_OVERFLOW_JUST_FOR_PP3 parameter that can be set instead of FF_NEVER_OVERFLOW 
.FF_NEVER_OVERFLOW (1'b0),
.FF_CAN_OVERFLOW_JUST_FOR_PP3 (1'b1)              
// Long fifos for request, that can be never filled, guarantee that all requests with a given 
// priority will be served in an order of arrival, and no request will circulate in a ring. Now
// such a circulation can occure just for packets with PP3 but it is a very unlikely situation
// that enough such packets can be generated by devices in a ring.
)
d2r_mgr 
(
.clk            (clk),
.rst            (rst), 

.i_sof          (d2r_sof  [1]),
.i_ctrl         (d2r_ctrl [1]),
.i_bus          (d2r_data [1]),
                 
.o_sof          (d2r_sof  [2]),
.o_ctrl         (d2r_ctrl [2]),
.o_bus          (d2r_data [2]),

.ff_err         (d2r_mgr_ff_err)
); 
//..............................................................................................
assign           r2d_sof [2] = r2d_sof [1];
assign           r2d_data[2] = r2d_data[1];
//==============================================================================================
// RS232 EP
//============================================================================================== 
generate
begin : RS232_EP
    localparam DEVID = 32'd0;
    wire                    to_root_stb;
    wire                    to_root_sof;
    wire             [3:0]  to_root_iid = 4'd0;
    wire            [71:0]  to_root_data;
    wire             [1:0]  to_root_rdy;  
    wire             [1:0]  to_root_rdyE;                                                                                                                                                                                                   
    
    wire                    from_root_stb;
    wire                    from_root_sof;
    wire             [3:0]  from_root_iid;
    wire            [71:0]  from_root_data;
    wire             [1:0]  from_root_rdy;
  
    rsbus_r2d_extractor
    #
    (                           
    .BASE_ID        (DEVID * 2),                                                
    .LAST_ID        (DEVID * 2 + 1),
    .PASS_WR_ACK    ("FALSE")
    )
    rs_r2d_extractor
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   
                                   
    .i_sof          (r2d_sof  [2 + DEVID]),
    .i_bus          (r2d_data [2 + DEVID]),
                                      
    .o_sof          (r2d_sof  [3 + DEVID]),
    .o_bus          (r2d_data [3 + DEVID]),
                    
    .frm_o_stb      (from_root_stb),  
    .frm_o_sof      (from_root_sof),  
    .frm_o_iid      (from_root_iid),
    .frm_o_bus      (from_root_data),
    .frm_o_rdy      (from_root_rdy)
    );          
    
    rbus_devif 
    #(
      .DEVICE_CLASS   (8'h2), 
      .DEVICE_VER     (8'h10),  
      .DEVICE_FEATURES(48'd0)
    )
    rs_rbus_if
    (
      .clk            (clk),     
      .rst            (rst),   
                                 
      .net_i_stb      (from_root_stb),
      .net_i_sof      (from_root_sof),
      .net_i_data     (from_root_data),
      .net_i_rdy      (from_root_rdy),
                             
      .net_o_stb      (to_root_stb),            
      .net_o_sof      (to_root_sof),           
      .net_o_data     (to_root_data),          
      .net_o_rdy      (to_root_rdy),           
      .net_o_rdyE     (to_root_rdyE),            
                                               
      .dev_o_rst      (rs_rst), 
    
      .dev_i_stb      (rs_d2r_stb ),
      .dev_i_sof      (rs_d2r_sof ),
      .dev_i_data     (rs_d2r_data),
      .dev_i_rdy      (rs_d2r_rdy ),             
      .dev_i_eve_stb  (rs_d2r_eve_stb),  
                                                 
      .dev_i_eve_dev  (rs_d2r_eve_dev),  
      .dev_i_eve_cmd  (rs_d2r_eve_cmd),  
      .dev_i_eve_ptr  (rs_d2r_eve_ptr),  
      .dev_i_eve_ack  (rs_d2r_eve_ack),  
                                        
      .dev_o_stb      (rs_r2d_stb),      
      .dev_o_sof      (rs_r2d_sof),      
      .dev_o_data     (rs_r2d_data),     
      .dev_o_rdy      (rs_r2d_rdy),       
                                              
      .dev_o_eve_stb  (rs_r2d_eve_stb),  
      .dev_o_eve_cmd  (rs_r2d_eve_cmd),  
      .dev_o_eve_ptr  (rs_r2d_eve_ptr),  
      .dev_o_eve_ack  (rs_r2d_eve_ack),
      
      .ff_err         (devif_ff_err[DEVID])   
    );      
    
    rsbus_d2r_injector
    #(                          
    .BASE_ID        (DEVID * 2),                                                
    .LAST_ID        (DEVID * 2 + 1)
    )  
    rs_d2r_injector
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   
    
    .frm_i_stb      (to_root_stb),                                                               
    .frm_i_sof      (to_root_sof),
    .frm_i_iid      (to_root_iid),
    .frm_i_bus      (to_root_data),   
    .frm_i_rdy      (to_root_rdy),   
    .frm_i_rdyE     (to_root_rdyE), 
                    
    .i_sof          (d2r_sof  [2 + DEVID]),
    .i_ctrl         (d2r_ctrl [2 + DEVID]),
    .i_bus          (d2r_data [2 + DEVID]),
                                  
    .o_sof          (d2r_sof  [3 + DEVID]),
    .o_ctrl         (d2r_ctrl [3 + DEVID]),
    .o_bus          (d2r_data [3 + DEVID]),
    
    .ff_err         (d2r_inj_ff_err[DEVID])
    );                              
end   
endgenerate                                                                              
//==============================================================================================
// VGA EP
//============================================================================================== 
generate
begin : VGA_EP

    localparam DEVID = 32'd1;

    wire                    to_root_stb;
    wire                    to_root_sof;
    wire             [3:0]  to_root_iid = 4'd0;
    wire            [71:0]  to_root_data;
    wire             [1:0]  to_root_rdy;  
    wire             [1:0]  to_root_rdyE;                                                                                                                                                                                                   
    
    wire                    from_root_stb;
    wire                    from_root_sof;
    wire             [3:0]  from_root_iid;
    wire            [71:0]  from_root_data;
    wire             [1:0]  from_root_rdy;
  
    rsbus_r2d_extractor
    #
    (                           
    .BASE_ID        (DEVID * 2),                                                
    .LAST_ID        (DEVID * 2 + 1),
    .PASS_WR_ACK    ("FALSE")
    )
    vga_r2d_extractor
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   
                                   
    .i_sof          (r2d_sof  [2 + DEVID]),
    .i_bus          (r2d_data [2 + DEVID]),
                                      
    .o_sof          (r2d_sof  [3 + DEVID]),
    .o_bus          (r2d_data [3 + DEVID]),
                    
    .frm_o_stb      (from_root_stb),  
    .frm_o_sof      (from_root_sof),  
    .frm_o_iid      (from_root_iid),
    .frm_o_bus      (from_root_data),
    .frm_o_rdy      (from_root_rdy)
    );       
    
    rbus_devif 
    #(
      .DEVICE_CLASS   (8'h3), 
      .DEVICE_VER     (8'h10),  
      .DEVICE_FEATURES(48'd0)
    )
    vga_rbus_if
    (
    .clk            (clk),     
    .rst            (rst),   
                               
    .net_i_stb      (from_root_stb),
    .net_i_sof      (from_root_sof),
    .net_i_data     (from_root_data),
    .net_i_rdy      (from_root_rdy),
                           
    .net_o_stb      (to_root_stb),            
    .net_o_sof      (to_root_sof),           
    .net_o_data     (to_root_data),          
    .net_o_rdy      (to_root_rdy),           
    .net_o_rdyE     (to_root_rdyE),            
                                             
    .dev_o_rst      (vga_rst), 
  
    .dev_i_stb      (vga_d2r_stb ),
    .dev_i_sof      (vga_d2r_sof ),
    .dev_i_data     (vga_d2r_data),
    .dev_i_rdy      (vga_d2r_rdy ),             
    .dev_i_eve_stb  (vga_d2r_eve_stb),  
                                               
    .dev_i_eve_dev  (vga_d2r_eve_dev),  
    .dev_i_eve_cmd  (vga_d2r_eve_cmd),  
    .dev_i_eve_ptr  (vga_d2r_eve_ptr),  
    .dev_i_eve_ack  (vga_d2r_eve_ack),  
                                      
    .dev_o_stb      (vga_r2d_stb),      
    .dev_o_sof      (vga_r2d_sof),      
    .dev_o_data     (vga_r2d_data),     
    .dev_o_rdy      (vga_r2d_rdy),       
                                            
    .dev_o_eve_stb  (vga_r2d_eve_stb),  
    .dev_o_eve_cmd  (vga_r2d_eve_cmd),  
    .dev_o_eve_ptr  (vga_r2d_eve_ptr),  
    .dev_o_eve_ack  (vga_r2d_eve_ack),
          
    .ff_err         (devif_ff_err[DEVID])    
    );      
    
    rsbus_d2r_injector
    #(                          
    .BASE_ID        (DEVID * 2),                                                
    .LAST_ID        (DEVID * 2 + 1)
    )  
    vga_d2r_injector
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   
    
    .frm_i_stb      (to_root_stb),                                                               
    .frm_i_sof      (to_root_sof),
    .frm_i_iid      (to_root_iid),
    .frm_i_bus      (to_root_data),  
    .frm_i_rdy      (to_root_rdy), 
    .frm_i_rdyE     (to_root_rdyE), 
                    
    .i_sof          (d2r_sof  [2 + DEVID]),
    .i_ctrl         (d2r_ctrl [2 + DEVID]),
    .i_bus          (d2r_data [2 + DEVID]),
                                  
    .o_sof          (d2r_sof  [3 + DEVID]),
    .o_ctrl         (d2r_ctrl [3 + DEVID]),
    .o_bus          (d2r_data [3 + DEVID]),
    
    .ff_err         (d2r_inj_ff_err[DEVID])
    );                              
end     
endgenerate                                                                            

//==============================================================================================
// EXTERNAL EP0
//============================================================================================== 
generate
begin : EXT0_EP

    localparam DEVID = 32'd2;
  
    rsbus_r2d_extractor
    #
    (                           
    .BASE_ID        (DEVID * 2),                                                
    .LAST_ID        (DEVID * 2 + 1),
    .PASS_WR_ACK    ("FALSE")
    )
    ext0_r2d_extractor
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   
                                   
    .i_sof          (r2d_sof  [2 + DEVID]),
    .i_bus          (r2d_data [2 + DEVID]),
                                      
    .o_sof          (r2d_sof  [3 + DEVID]),
    .o_bus          (r2d_data [3 + DEVID]),
                    
    .frm_o_stb      (ext0_r2d_stb),  
    .frm_o_sof      (ext0_r2d_sof),  
    .frm_o_iid      (ext0_r2d_iid),
    .frm_o_bus      (ext0_r2d_data),
    .frm_o_rdy      (ext0_r2d_rdy)
    );         
        
    rsbus_d2r_injector
    #(                          
    .BASE_ID        (DEVID * 2),                                                
    .LAST_ID        (DEVID * 2 + 1)
    )  
    ext0_d2r_injector
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   
    
    .frm_i_stb      (ext0_d2r_stb),                                                               
    .frm_i_sof      (ext0_d2r_sof),
    .frm_i_iid      (ext0_d2r_iid),
    .frm_i_bus      (ext0_d2r_data),   
    .frm_i_rdy      (ext0_d2r_rdy),    
    .frm_i_rdyE     (ext0_d2r_rdyE),  
                    
    .i_sof          (d2r_sof  [2 + DEVID]),
    .i_ctrl         (d2r_ctrl [2 + DEVID]),
    .i_bus          (d2r_data [2 + DEVID]),
                                  
    .o_sof          (d2r_sof  [3 + DEVID]),
    .o_ctrl         (d2r_ctrl [3 + DEVID]),
    .o_bus          (d2r_data [3 + DEVID]),
    
    .ff_err         (d2r_inj_ff_err[DEVID])
    );                              
end 
endgenerate

//==============================================================================================
// EXTERNAL EP0
//============================================================================================== 
generate
begin : EXT1_EP

    localparam DEVID = 32'd3;
  
    rsbus_r2d_extractor
    #
    (                           
    .BASE_ID        (DEVID * 2),                                                
    .LAST_ID        (DEVID * 2 + 1),
    .PASS_WR_ACK    ("FALSE")
    )
    ext1_r2d_extractor
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   
                                   
    .i_sof          (r2d_sof  [2 + DEVID]),
    .i_bus          (r2d_data [2 + DEVID]),
                                      
    .o_sof          (r2d_sof  [3 + DEVID]),
    .o_bus          (r2d_data [3 + DEVID]),
                    
    .frm_o_stb      (ext1_r2d_stb),  
    .frm_o_sof      (ext1_r2d_sof),  
    .frm_o_iid      (ext1_r2d_iid),
    .frm_o_bus      (ext1_r2d_data),
    .frm_o_rdy      (ext1_r2d_rdy)
    );         
        
    rsbus_d2r_injector
    #(                          
    .BASE_ID        (DEVID * 2),                                                
    .LAST_ID        (DEVID * 2 + 1)
    )  
    ext1_d2r_injector
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   
    
    .frm_i_stb      (ext1_d2r_stb),                                                               
    .frm_i_sof      (ext1_d2r_sof),
    .frm_i_iid      (ext1_d2r_iid),
    .frm_i_bus      (ext1_d2r_data),   
    .frm_i_rdy      (ext1_d2r_rdy),  
    .frm_i_rdyE     (ext1_d2r_rdyE),
                    
    .i_sof          (d2r_sof  [2 + DEVID]),
    .i_ctrl         (d2r_ctrl [2 + DEVID]),
    .i_bus          (d2r_data [2 + DEVID]),
                                  
    .o_sof          (d2r_sof  [3 + DEVID]),
    .o_ctrl         (d2r_ctrl [3 + DEVID]),
    .o_bus          (d2r_data [3 + DEVID]),
    
    .ff_err         (d2r_inj_ff_err[DEVID])
    );                              
end 
endgenerate

//==============================================================================================
// EXTERNAL EP0
//============================================================================================== 
generate
begin : EXT2_EP

    localparam DEVID = 32'd4;
  
    rsbus_r2d_extractor
    #
    (                          
    .BASE_ID        (DEVID * 2),                                                
    .LAST_ID        (DEVID * 2 + 1),
    .PASS_WR_ACK    ("FALSE")
    )
    ext2_r2d_extractor
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   
                                   
    .i_sof          (r2d_sof  [2 + DEVID]),
    .i_bus          (r2d_data [2 + DEVID]),
                                      
    .o_sof          (r2d_sof  [3 + DEVID]),
    .o_bus          (r2d_data [3 + DEVID]),
                    
    .frm_o_stb      (ext2_r2d_stb),  
    .frm_o_sof      (ext2_r2d_sof),  
    .frm_o_iid      (ext2_r2d_iid),
    .frm_o_bus      (ext2_r2d_data),
    .frm_o_rdy      (ext2_r2d_rdy)
    );         
        
    rsbus_d2r_injector
    #(                          
    .BASE_ID        (DEVID * 2),                                                
    .LAST_ID        (DEVID * 2 + 1)
    )  
    ext2_d2r_injector
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   
    
    .frm_i_stb      (ext2_d2r_stb),                                                               
    .frm_i_sof      (ext2_d2r_sof),
    .frm_i_iid      (ext2_d2r_iid),
    .frm_i_bus      (ext2_d2r_data),   
    .frm_i_rdy      (ext2_d2r_rdy),  
    .frm_i_rdyE     (ext2_d2r_rdyE),
                    
    .i_sof          (d2r_sof  [2 + DEVID]),
    .i_ctrl         (d2r_ctrl [2 + DEVID]),
    .i_bus          (d2r_data [2 + DEVID]),
                                  
    .o_sof          (d2r_sof  [3 + DEVID]),
    .o_ctrl         (d2r_ctrl [3 + DEVID]),
    .o_bus          (d2r_data [3 + DEVID]),
    
    .ff_err         (d2r_inj_ff_err[DEVID])
    );                              
end 
endgenerate

//==============================================================================================
// Frame  generator for R2D ring
//==============================================================================================
rsbus_frame_generator r2d_frame_generator
(
.clk            (clk),
.rst            (rst),                                          
                                                            
.i_sof          (r2d_sof  [2 + DEVNUM ]),
.i_ctrl         (12'd0),
.i_bus          (r2d_data [2 + DEVNUM ]),   

.o_sof          (r2d_sof  [3 + DEVNUM ]),
.o_ctrl         (),
.o_bus          (r2d_data [3 + DEVNUM ])
); 
//..............................................................................................
assign           d2r_sof  [3 + DEVNUM ] = d2r_sof  [2 + DEVNUM ];
assign           d2r_ctrl [3 + DEVNUM ] = d2r_ctrl [2 + DEVNUM ];
assign           d2r_data [3 + DEVNUM ] = d2r_data [2 + DEVNUM ];             
//==============================================================================================
// ring bus switch (internal ring to external ring)
//==============================================================================================
rsbus_d2r_extractor #
(                        
.SPACE_CHECKING         ("OFF"),
.SPACE_START_ADDRESS    (39'h00_0000_0000),
.SPACE_LAST_ADDRESS     (39'h00_0000_0000)
)
d2r_extractor
(
.clk                    (clk),
.rst                    (rst),   
                                      
.i_sof                  (d2r_sof  [3 + DEVNUM ]),
.i_ctrl                 (d2r_ctrl [3 + DEVNUM ]),
.i_bus                  (d2r_data [3 + DEVNUM ]),
                                      
.o_sof                  (d2r_sof  [0]),
.o_ctrl                 (d2r_ctrl [0]),
.o_bus                  (d2r_data [0]),
                        
.frm_o_stb              (o_stb), 
.frm_o_sof              (o_sof), 
.frm_o_bus              (o_data),
.frm_o_rdy              (o_rdy),
.frm_o_rdyE             (o_rdyE)   
);  
//..............................................................................................   
rsbus_r2d_injector       r2d_injector
(                                                                                                                               
.clk                    (clk),
.rst                    (rst),

.frm_i_stb              (i_stb), 
.frm_i_sof              (i_sof), 
.frm_i_bus              (i_data),
.frm_i_rdy              (i_rdy),
                    
.i_sof                  (r2d_sof [3 + DEVNUM ]),
.i_bus                  (r2d_data[3 + DEVNUM ]),
                                      
.o_sof                  (r2d_sof [0]),
.o_bus                  (r2d_data[0]),  

.ff_err                 (d2r_inj_ff_err[DEVNUM])
);                                                                                     
//============================================================================================== 
always @(posedge clk or posedge rst)                                                            
if(rst                     ) ff_ovr_err <=                                                 1'b0; 
else if( |d2r_inj_ff_err   ) ff_ovr_err <=                                                 1'b1; // injectors fifo error
else if( d2r_mgr_ff_err    ) ff_ovr_err <=                                                 1'b1; // ring manager fifo error 
else if( |devif_ff_err     ) ff_ovr_err <=                                                 1'b1; // dev interface fifo error
else                         ff_ovr_err <=                                           ff_ovr_err;
//---------------------------------------------------------------------------------------------- 
always @(posedge clk or posedge rst)                                                            
if(rst                     ) dbg        <=                                                  'd0;
else                         dbg        <= dbg | {d2r_inj_ff_err, devif_ff_err, d2r_mgr_ff_err};
//---------------------------------------------------------------------------------------------- 
assign ff_err =                                                                      ff_ovr_err;
//==============================================================================================       
endmodule            