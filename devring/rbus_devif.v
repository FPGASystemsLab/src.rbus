//=============================================================================================
//    Main contributors 
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//==============================================================================================
`include "mem_spaces.vh"
//=============================================================================================
module rbus_devif    
(                                                                                                                               
input  wire         clk, 
input  wire         rst, 

// network interface
input  wire         net_i_stb, 
input  wire         net_i_sof,
input  wire [71:0]  net_i_data,
output wire  [1:0]  net_i_rdy,

output wire         net_o_stb,  
output wire         net_o_sof,  
output wire [71:0]  net_o_data, 
input wire   [1:0]  net_o_rdy, 
input wire   [1:0]  net_o_rdyE, 

//device interface 
output wire         dev_o_rst,

input  wire         dev_i_stb, 
input  wire         dev_i_sof,
input  wire [71:0]  dev_i_data,
output wire  [1:0]  dev_i_rdy, 

input  wire         dev_i_eve_stb, 
input  wire [ 7:0]  dev_i_eve_dev,
input  wire [ 7:0]  dev_i_eve_cmd,
input  wire [39:0]  dev_i_eve_ptr,
output wire         dev_i_eve_ack,   
 
output wire         dev_o_stb,  
output wire         dev_o_sof,  
output wire [71:0]  dev_o_data,
input  wire  [1:0]  dev_o_rdy,  

output wire         dev_o_eve_stb, 
output wire [ 7:0]  dev_o_eve_cmd,
output wire [39:0]  dev_o_eve_ptr,
input  wire         dev_o_eve_ack,

output reg          ff_err
);                       
//=============================================================================================
// parameters
//=============================================================================================      
parameter [ 7:0] DEVICE_CLASS         =                                                   8'h0; 
parameter [ 7:0] DEVICE_VER           =                                                   8'h0; 
parameter [47:0] DEVICE_FEATURES      =                                                  48'h0;
//=============================================================================================
localparam [38:0] EV_ADDR             =         `MEM_SP_REFLECTOR_START_LOG + 39'h00_0000_0000; 
localparam [38:0] EV_DEV_REG_ADDR     =         `MEM_SP_REFLECTOR_START_LOG + 39'h00_0000_0080; 
localparam [38:0] EV_CONF_ADDR        =         `MEM_SP_REFLECTOR_START_LOG + 39'h00_0000_0300; 
localparam [38:0] EV_EVENT_ADDR       =         `MEM_SP_REFLECTOR_START_LOG + 39'h00_0000_0280; 
//--------------------------------------------------------------------------------------------- 
localparam [ 7:0] CMD_DEV_RST         =                                                  8'h01; 
localparam [ 7:0] CMD_GET_DEV_INF     =                                                  8'h02;  
//=============================================================================================
// variables
//============================================================================================= 
wire        netf_i_stb; 
wire        netf_i_sof;
wire [71:0] netf_i_data;
wire        netf_i_ack; 

// network input parsing 
wire [38:0] netf_i_addr; 
wire        netf_i_addr_event;
wire        netf_i_is_event_f;

wire [ 7:0] netf_i_eve_cmd;
wire [ 7:0] netf_i_eve_dev;
wire [39:0] netf_i_eve_ptr;
wire        netf_i_eve_srst;
wire        netf_i_eve_info; 

reg  [38:0] dev_info_send_addr;

wire        netf_i_dat_sof_f;
wire        netf_i_dat_pyld_f;
            
wire        netf_i_ack_event;
wire        netf_i_ack_data;
//--------------------------------------------------------------------------------------------- 
wire        net_omux_event_stb;
wire        devf_i_len;        
wire        net_omux_data_stb; 
//--------------------------------------------------------------------------------------------- 
wire        devf_i_stb;  
wire        devf_i_sof;  
wire [71:0] devf_i_data; 
wire        devf_i_ack;  
wire        devf_i_hack; 
wire        devf_i_dack; 
//--------------------------------------------------------------------------------------------- 
wire        dev_po_eve_h_ena; 
wire        dev_po_eve_hack;
wire        dev_po_eve_dack; 
wire        dev_po_eve_ack; 
//reg         dev_po_eve_pending;
//---------------------------------------------------------------------------------------------
wire [ 7:0] device_reflector_ptr; // numer urzdzenia przypisany w reflektorze i wyciagnity z ostatniego eventa
//---------------------------------------------------------------------------------------------
reg         dev_po_eve_d_trg;
reg         dev_po_eve_d_ena;
reg  [55:0] dev_po_eve_d;
//---------------------------------------------------------------------------------------------
reg         dev_x_rst;
//---------------------------------------------------------------------------------------------
integer     event_state;                         
//---------------------------------------------------------------------------------------------     
wire        ff_err_dev_i;    
wire        ff_err_dev_o;
wire        ff_err_net_i;
wire        ff_err_net_o;
//=============================================================================================
// data from network input fifo    32 words
//=============================================================================================       
rbus_dff net_input_fifo
(                     
.clk      (clk), 
.rst      (rst), 

.i_stb    (net_i_stb),
.i_sof    (net_i_sof),
.i_data   (net_i_data),  
.i_rdy    (net_i_rdy),
.i_err    (ff_err_net_i),

.o_stb    (netf_i_stb),
.o_sof    (netf_i_sof),
.o_data   (netf_i_data),
.o_ack    (netf_i_ack),
.o_err    (ff_err_net_o)
);  
//=============================================================================================
// data from device input fifo  16 words
//=============================================================================================       
rbus_dffs dev_input_fifo
(                     
.clk      (clk), 
.rst      (rst), 

.i_stb    (dev_i_stb),
.i_sof    (dev_i_sof),
.i_data   (dev_i_data),
.i_rdy    (dev_i_rdy),  
.i_err    (ff_err_dev_i),

.o_stb    (devf_i_stb),
.o_sof    (devf_i_sof),
.o_data   (devf_i_data),
.o_ack    (devf_i_ack),
.o_err    (ff_err_dev_o)
); 
//---------------------------------------------------------------------------------------------                            
reg         dev_omux_sel; 
reg         dev_omux_stb; 
reg         dev_omux_sof; 
reg  [71:0] dev_omux_data; 
//=============================================================================================
// events handling state machine
//============================================================================================= 
localparam E_IDLE           = 'hFF; 
localparam E_REG_DEV_H      = 'h10; 
localparam E_REG_DEV_D      = 'h11; 
localparam E_WAIT           = 'h00; 
localparam E_CHECK_EVENT    = 'h20; 
localparam E_SET_RST        = 'h30; 
localparam E_SEND_INFO_H    = 'h40; 
localparam E_SEND_INFO_D    = 'h41; 
localparam E_SET_EVENT      = 'h50; 
localparam E_PENDING_EVENT  = 'h51; 
localparam E_SEND_ECONF_H   = 'h21; 
localparam E_SEND_ECONF_D   = 'h22; 
localparam E_SEND_EVENT_H   = 'h70; 
localparam E_SEND_EVENT_D   = 'h71;                                      
//============================================================================================= 
assign netf_i_addr              = {netf_i_data[38:3], 3'd0};
assign netf_i_addr_event        = netf_i_addr == EV_ADDR; //event 
assign netf_i_is_event_f        = netf_i_addr_event;

assign netf_i_eve_cmd           = netf_i_data[55:48];
assign netf_i_eve_dev           = netf_i_data[47:40];
assign netf_i_eve_ptr           = netf_i_data[39: 0];
assign netf_i_eve_srst          = netf_i_eve_cmd == CMD_DEV_RST;
assign netf_i_eve_info          = netf_i_eve_cmd == CMD_GET_DEV_INF;

assign netf_i_dat_sof_f         = netf_i_stb && netf_i_sof && !netf_i_is_event_f;
assign netf_i_dat_pyld_f        = netf_i_stb &&!netf_i_sof && !dev_po_eve_d_trg; 

assign netf_i_ack_event         = (((event_state == E_WAIT) && dev_po_eve_h_ena) || dev_po_eve_d_trg);
assign netf_i_ack_data          = (dev_o_rdy[1] && netf_i_dat_sof_f) || netf_i_dat_pyld_f; 
assign netf_i_ack               = netf_i_ack_event || netf_i_ack_data;
//============================================================================================= 
assign dev_po_eve_h_ena         = netf_i_stb && netf_i_sof && netf_i_is_event_f; 
//============================================================================================= 
always@(posedge clk or posedge rst)
 if(rst)                                 event_state  <=                       E_IDLE;
 else case(event_state)                                                                         
//----------------------------------------------------------------------------------------------
 E_IDLE:                                 event_state  <=                       E_REG_DEV_H;     
//----------------------------------------------------------------------------------------------
 E_REG_DEV_H:   if(dev_po_eve_hack )     event_state  <=                       E_REG_DEV_D;
        else                             event_state  <=                       E_REG_DEV_H; 
//----------------------------------------------------------------------------------------------                 
 E_REG_DEV_D:   if(dev_po_eve_dack )     event_state  <=                       E_WAIT;          
        else                             event_state  <=                       E_REG_DEV_D;                 
//**********************************************************************************************
 E_WAIT:     if(dev_i_eve_stb      )     event_state  <=                       E_SEND_EVENT_H;
        else if(dev_po_eve_h_ena   )     event_state  <=                       E_CHECK_EVENT;
        else                             event_state  <=                       E_WAIT;                    
//**********************************************************************************************         
 E_CHECK_EVENT:if(netf_i_eve_srst  )     event_state  <=                       E_SET_RST;
        else if(netf_i_eve_info    )     event_state  <=                       E_SEND_INFO_H;
        else                             event_state  <=                       E_SET_EVENT;              
//**********************************************************************************************          
 E_SET_RST:                              event_state  <=                       E_SEND_ECONF_H;           
//**********************************************************************************************          
 E_SEND_INFO_H:if(dev_po_eve_hack  )     event_state  <=                       E_SEND_INFO_D;
        else                             event_state  <=                       E_SEND_INFO_H;        
//----------------------------------------------------------------------------------------------         
 E_SEND_INFO_D:if(net_omux_last_dat)     event_state  <=                       E_SEND_ECONF_H; 
        else                             event_state  <=                       E_SEND_INFO_D;           
//**********************************************************************************************          
 E_SET_EVENT:if(dev_o_eve_ack      )     event_state  <=                       E_SEND_ECONF_H;
        else                             event_state  <=                       E_PENDING_EVENT;      
//----------------------------------------------------------------------------------------------         
 E_PENDING_EVENT:if(dev_o_eve_ack  )     event_state  <=                       E_SEND_ECONF_H;
        else                             event_state  <=                       E_PENDING_EVENT;         
//**********************************************************************************************                   
 E_SEND_ECONF_H:if(dev_po_eve_hack )     event_state  <=                       E_SEND_ECONF_D;
        else                             event_state  <=                       E_SEND_ECONF_H; 
//----------------------------------------------------------------------------------------------                 
 E_SEND_ECONF_D:if(dev_po_eve_dack )     event_state  <=                       E_WAIT;          
//**********************************************************************************************           
 E_SEND_EVENT_H:if(dev_po_eve_hack )     event_state  <=                       E_SEND_EVENT_D;
        else                             event_state  <=                       E_SEND_EVENT_H; 
//----------------------------------------------------------------------------------------------                 
 E_SEND_EVENT_D:if(dev_po_eve_dack )     event_state  <=                       E_WAIT; 
        else                             event_state  <=                       E_SEND_EVENT_D;       
//**********************************************************************************************   
 endcase               
//=============================================================================================  
always@(posedge clk or posedge rst)
 if(rst)                                dev_x_rst           <=                            1'd0; 
 else if(event_state == E_SET_RST)      dev_x_rst           <=                            1'd1; 
 else if(event_state == E_WAIT   )      dev_x_rst           <=                            1'd0; 
 else                                   dev_x_rst           <=                       dev_x_rst;
//---------------------------------------------------------------------------------------------
assign dev_o_rst =                                                                   dev_x_rst; 
//=============================================================================================          
always@(posedge clk or posedge rst)
 if(rst)                                dev_info_send_addr  <=                           39'd0; 
 else if(event_state == E_CHECK_EVENT)  dev_info_send_addr  <=            netf_i_eve_ptr[38:0]; 
 else                                   dev_info_send_addr  <=                           39'd0; 
//=============================================================================================
always@(posedge clk or posedge rst)
 if(rst)
   begin 
     dev_po_eve_d_trg               <=                                                    1'b0;
     dev_po_eve_d_ena               <=                                                    1'b0;
     dev_po_eve_d                   <=                                    56'hFF_FF_FFFFFFFFFF;
   end 
 else if(event_state == E_CHECK_EVENT)
   begin 
     dev_po_eve_d_trg               <=                                                    1'b0;
     dev_po_eve_d_ena               <=                                                    1'b0;
     dev_po_eve_d                   <=                                       netf_i_data[55:0];
   end 
 else if(event_state == E_SET_EVENT)
   begin 
     dev_po_eve_d_trg               <=                                                    1'b0;
     dev_po_eve_d_ena               <=                                          !dev_o_eve_ack;
     dev_po_eve_d                   <=                                            dev_po_eve_d;
   end 
 else if(event_state == E_PENDING_EVENT)
   begin 
     dev_po_eve_d_trg               <=                                                    1'b0;
     dev_po_eve_d_ena               <=                                          !dev_o_eve_ack;
     dev_po_eve_d                   <=                                            dev_po_eve_d;
   end 
 else if((event_state == E_WAIT) && dev_po_eve_h_ena)
   begin 
     dev_po_eve_d_trg               <=                                                    1'b1;
     dev_po_eve_d_ena               <=                                                    1'b0;
     dev_po_eve_d                   <=                                            dev_po_eve_d;
   end                                      
 else
   begin 
     dev_po_eve_d_trg               <=                                                    1'b0;
     dev_po_eve_d_ena               <=                                        dev_po_eve_d_ena;
     dev_po_eve_d                   <=                                            dev_po_eve_d;
   end            
//---------------------------------------------------------------------------------------------
assign dev_o_eve_stb                =                                         dev_po_eve_d_ena;  
assign dev_o_eve_cmd                =                                      dev_po_eve_d[55:48];
assign device_reflector_ptr         =                                      dev_po_eve_d[47:40];
assign dev_o_eve_ptr                =                                      dev_po_eve_d[39: 0]; 
//=============================================================================================
// net_omux
//=============================================================================================
reg         net_omux_stb;  
reg         net_omux_sof;  
reg [71:0]  net_omux_data; 
reg [ 1:0]  net_omux_sel; 
reg [ 4:0]  net_omux_dat_dcnt; 
wire        net_omux_last_dat =                                           net_omux_dat_dcnt[4]; 
//---------------------------------------------------------------------------------------------
assign net_omux_event_stb =(((event_state == E_SEND_ECONF_H) || 
                             (event_state == E_REG_DEV_H   ) ||
                             (event_state == E_SEND_EVENT_H)) && net_o_rdyE[0]) || 
                            ((event_state == E_SEND_INFO_H )  && net_o_rdy[1]);  // tutaj to tak na prawde nie jest event tylko zwykly zapis do pamici ale atwiej tu to wcisnc
                            
assign devf_i_len         =                                                    devf_i_data[39];
assign net_omux_data_stb  =                                        devf_i_stb && devf_i_sof && 
                                ((net_o_rdy[0] &&!devf_i_len) || (net_o_rdy[1] && devf_i_len));               
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)
 if(rst)
   begin 
     net_omux_sel       <=                                                                2'd0;
     net_omux_stb       <=                                                                1'b0;
   end 
 else if(net_omux_sel == 2'b00)
   begin 
     net_omux_sel   <= (net_omux_event_stb)?                                             2'b01: 
                       (net_omux_data_stb )?                                     2'b10 : 2'b00; 
     net_omux_stb   <=                                 net_omux_event_stb || net_omux_data_stb;
   end 
 else if(net_omux_sel == 2'b01)
   begin 
     net_omux_sel   <=  (net_omux_last_dat)?                                     2'b00 : 2'b01; 
     net_omux_stb   <=                                                                    1'b1;
   end 
 else if(net_omux_sel == 2'b10)
   begin 
     net_omux_sel   <=  (devf_i_stb && !devf_i_sof)?                             2'b10 : 2'b00; 
     net_omux_stb   <=  (devf_i_stb && !devf_i_sof)?                             1'b1  :  1'b0;
   end 
 
//---------------------------------------------------------------------------------------------
always@(posedge clk)
 if(net_omux_sel == 2'b00)
   begin 
     net_omux_sof   <=                                 net_omux_event_stb || net_omux_data_stb;
     net_omux_data  <= (net_omux_event_stb & (event_state == E_REG_DEV_H   ))?   {2'b10, 2'b11 /*Hi prior*/, 28'd0, 1'b0/*L*/, EV_DEV_REG_ADDR   [38:3],3'd2}: 
                       (net_omux_event_stb & (event_state == E_SEND_INFO_H ))?   {2'b10, 2'b11 /*Hi prior*/, 28'd0, 1'b1/*L*/, dev_info_send_addr[38:3],3'd2}:
                       (net_omux_event_stb & (event_state == E_SEND_EVENT_H))?   {2'b10, 2'b11 /*Hi prior*/, 28'd0, 1'b0/*L*/, EV_EVENT_ADDR     [38:3],3'd2}:
                       (net_omux_event_stb & (event_state == E_SEND_ECONF_H))?   {2'b10, 2'b11 /*Hi prior*/, 28'd0, 1'b0/*L*/, EV_CONF_ADDR      [38:3],3'd2}:
                       (net_omux_data_stb            )?                                       devf_i_data:
                                                                                              devf_i_data;
     net_omux_dat_dcnt <=(event_state == E_SEND_INFO_H )?                                    5'd6 : 5'h1F;
   end 
 else if(net_omux_sel == 2'b01)
   begin 
     net_omux_sof   <=                                                                    1'b0;
     net_omux_data  <= (event_state == E_SEND_INFO_D )? {8'hFF, DEVICE_CLASS[7:0], DEVICE_VER[7:0], DEVICE_FEATURES[47:0]}: 
                       (event_state == E_SEND_ECONF_D)? {8'hFF, device_reflector_ptr[7:0], dev_i_eve_cmd[7:0], device_reflector_ptr[7:0], dev_i_eve_ptr[39:0]}: 
                       (event_state == E_REG_DEV_D   )? {8'hFF, device_reflector_ptr[7:0], dev_i_eve_cmd[7:0], device_reflector_ptr[7:0], dev_i_eve_ptr[39:0]}: 
                       (event_state == E_SEND_EVENT_D)? {8'hFF, device_reflector_ptr[7:0], dev_i_eve_cmd[7:0],        dev_i_eve_dev[7:0], dev_i_eve_ptr[39:0]}: 
                                                        {8'hFF, device_reflector_ptr[7:0], dev_i_eve_cmd[7:0],        dev_i_eve_dev[7:0], dev_i_eve_ptr[39:0]};
     net_omux_dat_dcnt <=                                             net_omux_dat_dcnt - 5'd1;
   end 
 else if(net_omux_sel == 2'b10)
   begin 
     net_omux_sof   <=                                                                    1'b0;
     net_omux_data  <=                                                       devf_i_data[71:0];
   end    
  
//---------------------------------------------------------------------------------------------  
assign dev_po_eve_hack  =   (net_omux_sel == 2'b00) && net_omux_event_stb                     ; 
assign dev_po_eve_dack  =                        (net_omux_sel[0]      ); 
assign dev_po_eve_ack   =                                   dev_po_eve_hack || dev_po_eve_dack;    
//--------------------------------------------------------------------------------------------- 
assign devf_i_hack      =   (net_omux_sel == 2'b00) &&!net_omux_event_stb && net_omux_data_stb; 
assign devf_i_dack      =                       (net_omux_sel[1] && devf_i_stb && !devf_i_sof); 
assign devf_i_ack       =                                           devf_i_hack || devf_i_dack; 
//--------------------------------------------------------------------------------------------- 
assign dev_i_eve_ack    =                   (event_state == E_SEND_EVENT_D) && dev_po_eve_dack;
//============================================================================================= 
always@(posedge clk or posedge rst)
 if(rst)
   begin 
     dev_omux_stb   <=                                                                    1'b0;
     dev_omux_sof   <=                                                                    1'b0;
     dev_omux_data  <=                                                                   72'd0;
   end 
 else
   begin 
     dev_omux_stb   <=                 (dev_o_rdy[1] && netf_i_dat_sof_f) || netf_i_dat_pyld_f;
     dev_omux_sof   <=                                                        netf_i_dat_sof_f;
     dev_omux_data  <=                                                             netf_i_data; 
   end 
//=============================================================================================
assign net_o_stb    =                                                             net_omux_stb; 
assign net_o_sof    =                                                             net_omux_sof;  
assign net_o_data   =                                                            net_omux_data;
//============================================================================================= 
assign dev_o_stb    =                                                             dev_omux_stb; 
assign dev_o_sof    =                                                             dev_omux_sof;  
assign dev_o_data   =                                                            dev_omux_data; 
//============================================================================================= 
always@(posedge clk or posedge rst)
if(rst)                        ff_err    <=                                               1'b0;
else if(ff_err_dev_i         ) ff_err    <=                                               1'b1; 
else if(ff_err_dev_o         ) ff_err    <=                                               1'b1; 
else if(ff_err_net_i         ) ff_err    <=                                               1'b1; 
else if(ff_err_net_o         ) ff_err    <=                                               1'b1; 
else                           ff_err    <=                                             ff_err; 
//=============================================================================================
endmodule
