//=============================================================================================
//    Main contributors   
//      - Jakub Siast                                                                           
//=============================================================================================  
// Reflector device has space for 127 uP (ID 1-127) and space for 128 Devices (ID 128-255)
// Reflector device itself has ID=0 and system events (info that new uP was registered etc.) is
// send with src ID = 0 - system events can be recognized by this value (bits 63-56 in the 
// second package word).

// Pamiec na DevInf moze byc scieta o 8 bitow przez usuniecie miejsca na RID i SID, ktore i tak
// nie sa teraz zapamietywane (wstawiane jest tam zawsze 8'd0), to miejsce jest jedynie uzywane
// przez informacje o wersji reflectora, ale to nie bedzie duza strata jak sie to przytnie
// do 16 bitow zamiast 24.    

// 17.11.2015 - dodane wysylanie pakietu z potwierdzeniem zapisu
//=============================================================================================
`default_nettype wire
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//==============================================================================================
`include "mem_spaces.vh"
//=============================================================================================
module shell_reflector
(
input  wire             clk,
input  wire             rst, 
//---------------------------------------------------------------------------------------------   
input  wire             i_stb,
input  wire             i_sof,
input  wire   [71:0]    i_data,
output wire    [1:0]    i_rdy, 
//---------------------------------------------------------------------------------------------
output reg              o_stb,
output reg              o_sof,
output reg    [71:0]    o_data,
input  wire    [1:0]    o_rdy
);                                                                                                           
//=============================================================================================
// parameters
//============================================================================================= 
parameter        MODE                =                                         "dbg";//"nodbg"; 
parameter [ 7:0] REF_SYS_UP_ID       =                                                    8'd1;   
parameter [ 7:0] REF_DEV_ID          =                                                    8'd0;
parameter [38:0] PHY_ADDR            =                             `MEM_SP_REFLECTOR_START_PHY; 
parameter [27:0] REFLECTOR_VER       =                                             28'h18_0100;                             
parameter        SEND_WR_FB          =                                                  "TRUE"; // "TRUE", "FALSE"     
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
//============================================================================================= 
// variables
//=============================================================================================
integer i;      
//=============================================================================================
// input buffer
//============================================================================================= 
wire          i0_stb;
wire          i0_sof;
wire  [71:0]  i0_data;
wire          i0_ack;
wire          i0_ena; 

wire          i0_head_stb;  
wire  [ 1:0]  i0_mode; 
wire          i0_wra;
wire          i0_wra_ack_en;
//---------------------------------------------------------------------------------------------
reg           i1_stb;
reg           i1_sof;
reg   [71:0]  i1_data;  
reg   [ 1:0]  i1_evnt_type;  
//---------------------------------------------------------------------------------------------
reg           i1_from_exeb; 
//---------------------------------------------------------------------------------------------
reg           i1_forced_sys_ev; 
//=============================================================================================
// variables
//============================================================================================= 
//event buffer
//=============================================================================================
(* syn_ramstyle = "no_rw_check" *) reg   [57:0]    EB [0:1023];    
//---------------------------------------------------------------------------------------------
wire  [ 9:0]    ebA_addrx;
//reg   [ 9:0]    ebA_addr;
wire            ebA_wr;     
reg   [57:0]    ebA_dataOutx/* synthesis syn_replicate =  0 */; 
reg   [57:0]    ebA_dataOut/* synthesis syn_replicate =  0 */; 
wire  [57:0]    ebA_dataIn;                        
//---------------------------------------------------------------------------------------------
wire  [ 9:0]    ebB_addrx;
//reg   [ 9:0]    ebB_addr;
wire            ebB_wr;     
//reg   [51:0]    ebB_dataOutx;
//reg   [51:0]    ebB_dataOut;
wire  [57:0]    ebB_dataIn;                                                                      
//=============================================================================================
// excessive event buffer                                                                  
//=============================================================================================
(* syn_ramstyle = "no_rw_check" *) reg   [73:0]    ExEB [0:1023]; 
//---------------------------------------------------------------------------------------------
wire  [ 9:0]    exebA_addrx;
//reg   [ 9:0]    exebA_addr;
wire            exebA_wr;     
//reg   [79:0]    exebA_dataOut;
wire  [73:0]    exebA_dataIn;  
//---------------------------------------------------------------------------------------------
wire  [ 9:0]    exebB_addrx;
//reg   [ 9:0]    exebB_addr;
wire            exebB_wr;      
reg   [73:0]    exebB_dataOutx/* synthesis syn_replicate =  0 */; 
reg   [73:0]    exebB_dataOut/* synthesis syn_replicate =  0 */; 
wire  [73:0]    exebB_dataIn;  
//---------------------------------------------------------------------------------------------
// fifo pointers
reg   [ 9:0]    exfifo_begin; 
reg   [ 9:0]    exfifo_end;     
reg   [ 9:0]    exfifo_slot_left;     // almost full counter
reg             exfifo_af;            // almost full system event trigger                                                    
//=============================================================================================
// excessive event buffer searching pipe stages                                                
//=============================================================================================
// stage 0 - Excessive events buffer read start            
wire  [ 9:0]   x0_exeb_addr;
wire           x0_stb;        
//---------------------------------------------------------------------------------------------
// stage 1 - Excessive events buffer response waiting          
//reg   [ 9:0]   x1_exeb_addr;
reg            x1_stb;               
//--------------------------------------------------------------------------------------------- 
// stage 2 - Excessive events buffer response & device info table read start                   
//reg   [ 9:0]   x2_exeb_addr;
reg            x2_stb;       
wire  [73:0]   x2_exeb_entry;    
wire  [ 7:0]   x2_exeb_entry_dev;
wire  [ 7:0]   x2_exeb_entry_evNum; 
wire  [ 1:0]   x2_exeb_entry_type;    
//--------------------------------------------------------------------------------------------- 
// stage 3 - Device info table response waiting               
//reg   [ 9:0]   x3_exeb_addr;
reg            x3_stb;       
reg   [73:0]   x3_exeb_entry;    
wire  [ 7:0]   x3_exeb_entry_dev;
wire  [ 7:0]   x3_exeb_entry_evNum; 
wire  [ 1:0]   x3_exeb_entry_type; 
//--------------------------------------------------------------------------------------------- 
// stage 4 - Device info table response & decision if event can be push to reflector entry once 
    // more (if there is an empty place in device fifo), or if to push it back to excessive 
    // buffer (no place in device buffer or this is not the first event waiting in excessive 
    // buffer to be put into this device fifo)
//reg   [ 9:0]   x4_exeb_addr;
reg            x4_stb;       
reg   [73:0]   x4_exeb_entry;    
wire  [ 7:0]   x4_exeb_entry_dev;
wire  [ 7:0]   x4_exeb_entry_evNum;
wire  [ 1:0]   x4_exeb_entry_type; 
wire  [71:0]   x4_devinf_entry;              
wire  [ 7:0]   x4_devinf_entry_firstExEvNum;
wire  [ 2:0]   x4_devinf_entry_DefCnt;  
wire           x4_wr_exev_to_input;
wire           x4_wr_exev_to_exeb;   
//--------------------------------------------------------------------------------------------- 
// stage 5 - buffer for decision from stage 4,                                      
reg   [73:0]   x5_exeb_entry;
reg            x5_wr_exev_to_input;
reg            x5_wr_exev_to_exeb; 
reg            x5_wr_exev_to_x;
//--------------------------------------------------------------------------------------------- 
// stage 6 - buffer for decision from stage 5, and driver signal for writing        
reg   [73:0]   x6_exeb_entry;
reg            x6_wr_exev_to_input;
reg            x6_wr_exev_to_exeb; 
reg            x6_wr_exev_to_x;
//=============================================================================================
// devices info// 2xBRAM 9K simple dual port - one port for write and one for read operations 
(* syn_ramstyle = "no_rw_check" *) reg   [71:0]    DInf [0:255];  
reg   [ 7:0]    dinf_first_free_up_slot;
reg   [ 7:0]    dinf_first_free_dev_slot; 
//---------------------------------------------------------------------------------------------
wire  [ 7:0]    dinfWR_addr; 
wire            dinfWR_wr;                     
wire  [71:0]    dinfWR_dataIn;  
//---------------------------------------------------------------------------------------------      
wire  [ 7:0]    dinfRD_addrx;          
//reg   [ 7:0]    dinfRD_addr;       
reg   [71:0]    dinfRD_dataOutx/* synthesis syn_replicate =  0 */;   
reg   [71:0]    dinfRD_dataOut/* synthesis syn_replicate =  0 */;              
wire            dinfRD_Valid;           // device description entry valid   
wire            dinfRD_new_event_trg_af;// lot of excesive events stored for this device and next excesive event should triger system event to nottify system about "device excessive events buffer almost full" issue occurence
wire            dinfRD_ExEvPresent;     // some events are in excessive events buffer                                                                                                                                    
wire  [ 7:0]    dinfRD_firstExEvNum;    // number of first event that was puted into the excessive event buffer
wire  [ 7:0]    dinfRD_lastExEvNum;     // number of last event that was puted into the device fifo or into the excessive event buffer
wire  [27:0]    dinfRD_devAddr; 
wire  [ 2:0]    dinfRD_DefCnt;
wire  [ 1:0]    dinfRD_DefOff;                                                                 
//=============================================================================================
integer reciever_state;                
//---------------------------------------------------------------------------------------------       
localparam  R_INIT        = 32'h40;
localparam  R_WAIT        = 32'h00;
localparam  R_REG_UP      = 32'h01;
localparam  R_REG_DEV     = 32'h02;
localparam  R_UNREG       = 32'h03;
localparam  R_READ        = 32'h04;
localparam  R_WRITE       = 32'h05;
localparam  R_EVENT       = 32'h06;
localparam  R_EVENT_CONF  = 32'h07;
localparam  R_SET_FREE_PTR= 32'h08;
localparam  R_XDAT1       = 32'h10;
localparam  R_XDAT2       = 32'h11;
localparam  R_XDAT3       = 32'h12;
localparam  R_SYS_EV      = 32'h20;
localparam  R_READ_OUT    = 32'h21;
localparam  R_EVENT_SENT0 = 32'h30;
localparam  R_EVENT_SENT1 = 32'h31;
//--------------------------------------------------------------------------------------------- 
wire f_R_INIT         =                                     (reciever_state == R_INIT        );
wire f_R_WAIT         =                                     (reciever_state == R_WAIT        );
wire f_R_REG_UP       =                                     (reciever_state == R_REG_UP      );
wire f_R_REG_DEV      =                                     (reciever_state == R_REG_DEV     );
wire f_R_UNREG        =                                     (reciever_state == R_UNREG       );
wire f_R_READ         =                                     (reciever_state == R_READ        );
wire f_R_WRITE        =                                     (reciever_state == R_WRITE       );
wire f_R_EVENT        =                                     (reciever_state == R_EVENT       );
wire f_R_EVENT_CONF   =                                     (reciever_state == R_EVENT_CONF  );
wire f_R_SET_FREE_PTR =                                     (reciever_state == R_SET_FREE_PTR);
wire f_R_XDAT1        =                                     (reciever_state == R_XDAT1       );
wire f_R_XDAT2        =                                     (reciever_state == R_XDAT2       );
wire f_R_XDAT3        =                                     (reciever_state == R_XDAT3       );
wire f_R_SYS_EV       =                                     (reciever_state == R_SYS_EV      ); 
wire f_R_READ_OUT     =                                     (reciever_state == R_READ_OUT    );
wire f_R_EVENT_SENT0  =                                     (reciever_state == R_EVENT_SENT0 );
wire f_R_EVENT_SENT1  =                                     (reciever_state == R_EVENT_SENT1 ); 
//============================================================================================= 
// initialization                  
//============================================================================================= 
reg  [ 8:0] init_cnt;
wire        init_bsy;                                                                            
//============================================================================================= 
// input parsing                  
//=============================================================================================  
wire            i1_head_stb;
wire [38:0]     i1_addr;                                                                        

wire [ 1:0]     i1_mode; 

wire            i1_len;
wire            i1_rd1; 
wire            i1_rd8;
wire            i1_wra; 
wire            i1_upda;
wire            i1_rd_len;

wire            i1_wr;  
wire            i1_rd;
wire            i1_rd_wr;                                                                        
//----------------------------------------------------------------------------------------------                                                                       
wire            i1_stb_reg_up;
wire            i1_stb_reg_dev;
wire            i1_stb_unregister;
wire            i1_stb_read;
wire            i1_stb_write;
wire            i1_stb_event;
wire            i1_stb_ev_confirm;
wire            i1_stb_trace;
wire            i1_stb_tr_confirm;
wire            i1_stb_set_free_ptr;  
//----------------------------------------------------------------------------------------------
// start of operations that uses 
wire            i1_stb_from_input;    
//----------------------------------------------------------------------------------------------  
wire  [39:0]    i1_ptr;  
wire  [ 7:0]    i1_dev;
wire  [ 7:0]    i1_src;
wire  [ 7:0]    i1_cmd;   
//----------------------------------------------------------------------------------------------
wire            i1_forcedDevValid;
wire  [27:0]    i1_forcedDevAddr;
wire  [ 2:0]    i1_forcedDevCnt; 
wire  [ 1:0]    i1_forcedDevOff;
//---------------------------------------------------------------------------------------------- 
wire  [ 7:0]    i1_forcedUpPtr; 
wire  [ 7:0]    i1_forcedDevPtr;                                                               
//---------------------------------------------------------------------------------------------
reg             i2_header_stb;
reg   [71:0]    i2_header;                                                                
wire  [27:0]    i2_header_dev_addr; 
wire  [11:0]    i2_header_mem_addr;                        
wire  [ 1:0]    i2_header_prior;                                                          
wire            i2_header_len;                                                             
wire  [ 1:0]    i2_header_mop;
wire            i2_header_mop_rd8; 
wire            i2_header_mop_upd8;
wire            i2_header_rd_len;       
//=============================================================================================                  
// stage 1                                                                                     
//============================================================================================= 
reg [39:0]  s1_ptr;         
reg [ 7:0]  s1_cmd; 
//----------------------------------------------------------------------------------------------
reg         s1_from_exeb; 
//----------------------------------------------------------------------------------------------
reg         s1_new_event_stb;    
reg         s1_event_confirm;  
reg  [ 7:0] s1_event_dev; 
reg  [ 7:0] s1_src_dev; 
reg  [ 1:0] s1_evnt_type; 
//----------------------------------------------------------------------------------------------
reg [ 7:0]  s1_sys_trg_dev;
reg         s1_sys_trg_norm; 
reg  [ 3:0] s1_sys_trg_norm_reason; 
reg         s1_read_trg;
//----------------------------------------------------------------------------------------------
reg         s1_forced_sys_ev;
//=============================================================================================                  
// stage 2                                                                                     
//=============================================================================================   
reg [39:0]  s2_ptr;         
reg [ 7:0]  s2_cmd;    
//----------------------------------------------------------------------------------------------
reg         s2_from_exeb; 
//----------------------------------------------------------------------------------------------
reg         s2_new_event_stb;
wire        s2_send_event_stb; 
reg         s2_event_confirm;                                                               
reg  [ 7:0] s2_event_dev;                                                                
reg  [ 7:0] s2_src_dev; 
reg  [ 1:0] s2_evnt_type;  
//----------------------------------------------------------------------------------------------
reg         s2_forced_sys_ev;
//----------------------------------------------------------------------------------------------
reg [ 7:0]  s2_sys_trg_dev;
reg         s2_sys_trg_norm; 
reg  [ 3:0] s2_sys_trg_norm_reason; 
reg         s2_read_trg;
wire        s2_sys_trg_err;   
wire        s2_sys_trg_err_dev_err;
wire        s2_sys_trg_dev_almost_full; // zostalo tylko 15 miejsc do 256 eventw jakie mona trzyma dla jednego urzdzenia
wire        s2_sys_trg_almost_full;     // zostalo tylko 64 miejsc do 1024 eventw jakie mona trzyma dla wszystkich urzdzen     
wire [ 3:0] s2_sys_trg_err_reason;
//---------------------------------------------------------------------------------------------- 
wire [ 9:0] s2_dinf_wr_dev;   
wire [71:0] s2_dinf_wr_dat;
wire        s2_dinf_wr_stb;                                               
//=============================================================================================                  
// stage 3 - event sent                                                                                     
//=============================================================================================
reg         s3_dinf_wr_stb;
reg  [ 7:0] s3_dinf_wr_dev;
reg  [71:0] s3_dinf_wr_dat;                                                        
//----------------------------------------------------------------------------------------------
reg         s3_forced_sys_ev;
//----------------------------------------------------------------------------------------------
reg         s3_send_out_stb; 
reg  [ 7:0] s3_send_out_dev;   
reg  [27:0] s3_send_out_devAddr; 
reg  [ 3:0] s3_send_out_sid;
reg         s3_send_is_read;
reg  [ 3:0] s3_send_out_rid;
reg  [11:0] s3_send_out_phadr;
reg  [ 1:0] s3_send_out_mop;
reg  [ 1:0] s3_send_out_prior;
reg         s3_send_out_len;
wire [71:0] s3_send_out_header;
//----------------------------------------------------------------------------------------------
reg  [ 3:0] s3_sys_trg_reason; 
reg  [ 7:0] s3_sys_trg_dev;                                                       
reg  [71:0] s3_sys_trg_devinf;
//=============================================================================================                  
// stage 4 - event sent                                                                                     
//=============================================================================================  
reg         s4_send_event_stb; 
reg         s4_send_read_stb;
reg  [ 3:0] s4_read_cnt;
wire        s4_read_cnt_end_f;
wire [ 1:0] s4_send_event_type;
reg  [ 7:0] s4_send_event_dev;                                                                  
wire [ 7:0] s4_send_event_cmd;
wire [ 7:0] s4_send_event_src;
wire [39:0] s4_send_event_ptr;
reg  [71:0] s4_send_dinfo_word; 
wire [71:0] s4_send_event_word;
//---------------------------------------------------------------------------------------------- 
reg         o0_wr_ack_hen;
wire        o0_wr_ack_en;
reg         o0_wr_ack_den;  
wire [71:0] o0_wr_ack_hdr;
wire [71:0] o0_wr_ack_dat; 
//---------------------------------------------------------------------------------------------- 
reg         o1_stb;
reg         o1_sof;
reg         o1_change_sid;         
reg  [71:0] o1_data;
//----------------------------------------------------------------------------------------------  
reg         s4_sys_trg_stb;
wire [ 7:0] s4_sys_trg_cmd;
wire [39:0] s4_sys_trg_devinf_form;
wire [71:0] s4_sys_trg_word;
reg  [ 3:0] s4_sys_trg_reason;  
reg  [ 7:0] s4_sys_trg_dev;
reg  [71:0] s4_sys_trg_devinf;   
//=============================================================================================
// input buffer  for 16 words                                                                  
//============================================================================================= 
rbus_dffs input_fifo
(
.clk            (clk), 
.rst            (rst),   

.i_stb          (i_stb),
.i_sof          (i_sof),
.i_data         (i_data),
.i_rdy          (i_rdy),
.i_err          (),

.o_stb          (i0_stb),
.o_sof          (i0_sof),
.o_data         (i0_data),
.o_ack          (i0_ack),
.o_err          ()
);   
//---------------------------------------------------------------------------------------------
reg i_not_busy; 
//---------------------------------------------------------------------------------------------
assign i0_ena = i0_stb && i_not_busy && !(i0_sof && x5_wr_exev_to_input) && !x6_wr_exev_to_input;//jeeli ju udao si znalezc event w buforze nadmiarowych eventw ktory mozna przepisac do bufora eventow to poczekaj z nowymi danymi i zrob to           
//---------------------------------------------------------------------------------------------
assign i0_ack       =                        i0_ena && (!i0_sof || (reciever_state == R_WAIT));                          
assign i0_head_stb  =                        i0_ena &&   i0_sof && (reciever_state == R_WAIT) ;   
assign i0_mode      =                                                             i0_data[1:0];
assign i0_wra       =                                                    i0_mode[1:0] == 2'b10;
assign i0_wra_ack_en=                                                     i0_head_stb & i0_wra; 
//=============================================================================================   
always@(posedge clk or posedge rst)        
 if(  rst ) i_not_busy <=                      1'b0;
                   //(output not busy)   (  s4_sys_trg_stb           ) (                        )
 else       i_not_busy <= (&o_rdy) && !init_bsy   &&!((reciever_state == R_SYS_EV)) ;// || (i1_stb && !i1_sof));        
//=============================================================================================  
// mux for input and folded events
//=============================================================================================                         
always@(posedge clk or posedge rst)        
 if(  rst )  
     begin                
         i1_stb          <= 1'b0;
         i1_sof          <= 1'b0;
         
         i1_from_exeb    <= 1'b0;
         
         i1_forced_sys_ev<= 1'b0;
     end                                                                                           
 else
     begin                
         i1_stb          <= (x6_wr_exev_to_input || s4_sys_trg_stb)? 1'b1                : i0_ack;
         i1_sof          <= (x6_wr_exev_to_input || s4_sys_trg_stb)? 1'b0                : i0_sof; 
         
         i1_from_exeb    <=  x6_wr_exev_to_input;  
         
         i1_forced_sys_ev<= s4_sys_trg_stb;
     end 
//---------------------------------------------------------------------------------------------                     
always@(posedge clk) begin 
  i1_data         <= (x6_wr_exev_to_input                  )? x6_exeb_entry[63: 0] : 
                     (s4_sys_trg_stb                       )?      s4_sys_trg_word :   i0_data; // 8'src, 8' cmd, 8' dev, 40' ptr/data 
  // event type: trace event(1) / normal event(2) / system event(3)
  i1_evnt_type    <= (x6_wr_exev_to_input                  )? x6_exeb_entry[65:64] : 
                     (s4_sys_trg_stb                       )?                2'b11 :   ((i1_stb_trace)? 2'b01 : 2'b10);       
end                     
//============================================================================================= 
// input parsing                  
//============================================================================================= 
assign          i1_head_stb  =                                                 i1_stb & i1_sof;

assign          i1_mode      =                                                    i1_data[1:0];

assign          i1_len       =                                                     i1_data[39];
assign          i1_rd1       =                                           i1_data[1:0] == 2'b00; 
assign          i1_rd8       =                                           i1_data[1:0] == 2'b01;
assign          i1_wra       =                                           i1_data[1:0] == 2'b10; 
assign          i1_upda      =                                           i1_data[1:0] == 2'b11;
assign          i1_rd_len    =                                     i1_rd8 | (i1_upda & i1_len);

assign          i1_wr        =                               (i1_wra | i1_upda) && i1_head_stb;  
assign          i1_rd        =                      (i1_rd1 | i1_rd8 | i1_upda) && i1_head_stb;
assign          i1_rd_wr     =                                         i1_upda  && i1_head_stb; 
 
assign          i1_addr      =                                           {i1_data[38:3], 3'd0};
                                                                                                
assign          i1_stb_reg_up      =   i1_head_stb && i1_wr && (i1_addr[ 9:7] ==        3'd0) ;
assign          i1_stb_reg_dev     =   i1_head_stb && i1_wr && (i1_addr[ 9:7] ==        3'd1) ;
assign          i1_stb_unregister  =   i1_head_stb && i1_wr && (i1_addr[ 9:7] ==        3'd2) ;
//assign          i1_stb_read        =   i1_head_stb && (i1_addr[9:7] == 3'd3);
assign          i1_stb_read        =   i1_head_stb && i1_rd                                   ;
assign          i1_stb_write       =   i1_head_stb && i1_wr && (i1_addr[ 9:7] ==        3'd4) ;
assign          i1_stb_event       =   i1_head_stb && i1_wr && (i1_addr[10:7] == {1'b0, 3'h5});
assign          i1_stb_ev_confirm  =   i1_head_stb && i1_wr && (i1_addr[10:7] == {1'b0, 3'h6});
assign          i1_stb_trace       =   i1_head_stb && i1_wr && (i1_addr[10:7] == {1'b1, 3'h5});
assign          i1_stb_tr_confirm  =   i1_head_stb && i1_wr && (i1_addr[10:7] == {1'b1, 3'h6});
assign          i1_stb_set_free_ptr=   i1_head_stb && i1_wr && (i1_addr[ 9:7] ==        3'd7) ;

// start of operations that uses 
assign          i1_stb_from_input=i1_stb_reg_up     || i1_stb_reg_dev      || i1_stb_unregister  || 
                                  i1_stb_read       || i1_stb_write        || i1_stb_set_free_ptr||
                                  i1_stb_event      || i1_stb_ev_confirm   || 
                                  i1_stb_trace      || i1_stb_tr_confirm;
                                                                                               
assign          i1_ptr           = /*(((MODE == "dbg") && (!i1_stb || i1_sof)))? 39'd0:*/i1_data[39 :0];
assign          i1_cmd           = /*(((MODE == "dbg") && (!i1_stb || i1_sof)))?  8'd0:*/i1_data[55:48];  
assign          i1_dev           = /*(((MODE == "dbg") && (!i1_stb || i1_sof)))?  8'd0:*/i1_data[47:40];
assign          i1_src           = /*(((MODE == "dbg") && (!i1_stb || i1_sof)))?  8'd0:*/i1_data[63:56];

assign          i1_forcedDevCnt  = /*(((MODE == "dbg") && (!i1_stb || i1_sof)))?  3'd0:*/i1_data[34:32];  
assign          i1_forcedDevOff  = /*(((MODE == "dbg") && (!i1_stb || i1_sof)))?  2'd0:*/i1_data[31:30];
assign          i1_forcedDevValid= /*(((MODE == "dbg") && (!i1_stb || i1_sof)))?  1'd0:*/i1_data[   28]; 
assign          i1_forcedDevAddr = /*(((MODE == "dbg") && (!i1_stb || i1_sof)))? 24'd0:*/i1_data[27: 0]; 

assign          i1_forcedUpPtr   = /*(((MODE == "dbg") && (!i1_stb || i1_sof)))?  8'd0:*/i1_data[ 7: 0]; 
assign          i1_forcedDevPtr  = /*(((MODE == "dbg") && (!i1_stb || i1_sof)))?  8'd0:*/i1_data[15: 8]; 
                                                                                                             
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)      i2_header_stb <=                                         i1_head_stb;            
//--------------------------------------------------------------------------------------------- 
always@(posedge clk)
      if(i1_head_stb)     i2_header <=                                                 i1_data;
 else                     i2_header <=                                               i2_header;  
//---------------------------------------------------------------------------------------------                                                             
assign          i2_header_dev_addr  =                                         i2_header[67:40];
assign          i2_header_mem_addr  =                                  {i2_header[11: 3],3'd0};                               
assign          i2_header_prior     =                                         i2_header[69:68];                                                             
assign          i2_header_len       =                                         i2_header[   39];                                                             
assign          i2_header_mop       =                                         i2_header[ 1: 0]; 
assign          i2_header_mop_rd8   =                i2_header_mop ==  2'b01                  ;  
assign          i2_header_mop_upd8  =               (i2_header_mop ==  2'b11) && i2_header_len;  
assign          i2_header_rd_len    =                  i2_header_mop_rd8 || i2_header_mop_upd8;                                                                                                
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
      if(rst)             init_cnt  <=                                                   'd255; 
 else if(init_bsy   )     init_cnt  <=                                          init_cnt - 'd1;
 else                     init_cnt  <=                                          init_cnt      ; 
//---------------------------------------------------------------------------------------------  
assign    init_bsy                =                                               !init_cnt[8];
//=============================================================================================                  
// stage 0                                                                                     
//=============================================================================================  
always@(posedge clk or posedge rst)
 if(rst)                                 reciever_state  <=                       R_INIT;
 else case(reciever_state)    
 R_INIT:     if(!init_bsy          )     reciever_state  <=                       R_WAIT;                                                       
 R_WAIT:     if(i1_stb_read        )     reciever_state  <=                       R_READ;
        else if(i1_stb_reg_up      )     reciever_state  <=                       R_REG_UP;  
        else if(i1_stb_reg_dev     )     reciever_state  <=                       R_REG_DEV;
        else if(i1_stb_unregister  )     reciever_state  <=                       R_UNREG;
        else if(i1_stb_write       )     reciever_state  <=                       R_WRITE;                     
        else if(i1_stb_event       )     reciever_state  <=                       R_EVENT;                   
        else if(i1_stb_trace       )     reciever_state  <=                       R_EVENT;
        else if(x6_wr_exev_to_input)     reciever_state  <=                       R_EVENT;// event z kolejki nadmiarowych zdarze
        else if(s4_sys_trg_stb     )     reciever_state  <=                       R_EVENT;// event do systemu                           
        else if(i1_stb_ev_confirm  )     reciever_state  <=                       R_EVENT_CONF;                        
        else if(i1_stb_tr_confirm  )     reciever_state  <=                       R_EVENT_CONF;
        else if(i1_stb_set_free_ptr)     reciever_state  <=                       R_SET_FREE_PTR;
        else                             reciever_state  <=                       R_WAIT;                    
//----------------------------------------------------------------------------------------------         
 R_REG_UP:                               reciever_state  <=                       R_XDAT1; // zapis danych, 
//----------------------------------------------------------------------------------------------         
 R_REG_DEV:                              reciever_state  <=                       R_XDAT1; // zapis danych, 
//----------------------------------------------------------------------------------------------   
 R_UNREG:                                reciever_state  <=                       R_XDAT1; // rozpoczcie odczytu z DInf,                       
//----------------------------------------------------------------------------------------------   
 R_READ:                                 reciever_state  <=                       R_XDAT1; // rozpoczcie odczytu z DInf                      
//----------------------------------------------------------------------------------------------           
 R_EVENT:                                reciever_state  <=                       R_XDAT1; // rozpoczcie odczytu z DInf   
//----------------------------------------------------------------------------------------------                          
 R_EVENT_CONF:                           reciever_state  <=                       R_XDAT1; // rozpoczcie odczytu z DInf                                                             
//----------------------------------------------------------------------------------------------                             
 R_XDAT1:                                reciever_state  <=                       R_XDAT2;       // oczekiwanie na dane urzdzenia,              rozpoczcie odczytu danych pierwszego procka z DInf           
 R_XDAT2:          if(s2_sys_trg_norm  ) reciever_state  <=                       R_SYS_EV;      // dane urzdzenia w rejestrze dinfRD_dataOut,  zapis uaktualnionej wartoci z powrotem do DInf
              else if(s2_sys_trg_norm  ) reciever_state  <=                       R_SYS_EV;      // dane urzdzenia w rejestrze dinfRD_dataOut,  zapis uaktualnionej wartoci z powrotem do DInf
              else if(s2_read_trg      ) reciever_state  <=                       R_READ_OUT;    // dane urzdzenia w rejestrze dinfRD_dataOut,
              else if(s2_sys_trg_err   ) reciever_state  <=                       R_SYS_EV;      // dane urzdzenia w rejestrze dinfRD_dataOut - wykrycie braku urzdzenia,                             
              else if(s2_send_event_stb) reciever_state  <=                       R_EVENT_SENT0; // dane urzdzenia w rejestrze dinfRD_dataOut,  zapis uaktualnionej wartoci z powrotem do DInf   odczyt eventa z eb ( adres ebB_addrx)
              else                       reciever_state  <=                       R_XDAT3;       // dane urzdzenia w rejestrze dinfRD_dataOut,  zapis uaktualnionej wartoci z powrotem do DInf,  wstawienie zdarzenia na list zdarze urzdzenia lub do bufora przepenienia 
 R_XDAT3:                                reciever_state  <=                       R_WAIT;        // dane urzdzenia w rejestrze dinfRD_dataOut,  zapis uaktualnionej wartoci z powrotem do DInf,  wstawienie zdarzenia na list zdarze urzdzenia lub do bufora przepenienia
//----------------------------------------------------------------------------------------------     
 R_SYS_EV:                               reciever_state  <=                       R_WAIT;        // dane urzdzenia w rejestrze dinfRD_dataOut,  zapis uaktualnionej wartoci z powrotem do DInf,  wstawienie zdarzenia na list zdarze urzdzenia lub do bufora przepenienia
//----------------------------------------------------------------------------------------------     
 R_READ_OUT:       if(s4_read_cnt_end_f) reciever_state  <=                       R_WAIT;        // dane urzdzenia w rejestrze dinfRD_dataOut,                                                  
              else                       reciever_state  <=                       R_READ_OUT; 
 //----------------------------------------------------------------------------------------------     
 R_EVENT_SENT0:                          reciever_state  <=                       R_WAIT;        // dane eventa w rejestrze ebA_dataOut,  wysanie danyh eventa
 //R_EVENT_SENT1:                        reciever_state  <=                       R_WAIT;        // dane eventa w rejestrze ebA_dataOut,  wysanie danyh eventa 
//----------------------------------------------------------------------------------------------     
 R_WRITE:                                reciever_state  <=                       R_WAIT; // zapis danych 
//----------------------------------------------------------------------------------------------      
 R_SET_FREE_PTR:                         reciever_state  <=                       R_WAIT; // zapis wartoci wskanika                                                                
//----------------------------------------------------------------------------------------------   
 endcase                                                                               
//=============================================================================================      
//device info - BRAM in simple mode 256x36b signals definition          
//============================================================================================= 
assign dinfRD_addrx =                                                                 
(reciever_state == R_UNREG       )?                                                      i1_dev: // numer wyrejestrowywanego urzdzenia  
(reciever_state == R_READ        )?                                                      i1_dev: // numer odczytywanego      urzdzenia
(reciever_state == R_EVENT       )?                                                      i1_dev: // numer wykonawczego       urzdzenia
(reciever_state == R_EVENT_CONF  )?                                                      i1_dev: // numer wykonawczego       urzdzenia
(reciever_state == R_XDAT1       )?                                          REF_SYS_UP_ID[7:0]: // numer pierwszego procka
                                                                              x2_exeb_entry_dev; 
//---------------------------------------------------------------------------------------------- 
always@(posedge clk)        
 if(dinfWR_wr) DInf [dinfWR_addr] <= dinfWR_dataIn;  
//----------------------------------------------------------------------------------------------     
//device info - BRAM in simple mode 256x36b signals definition
always@(posedge clk)  
begin      
// if(  rst )         dinfRD_dataOut <= 72'd0;                                                                      
                     dinfRD_dataOutx <= DInf [dinfRD_addrx];                                                          
                     dinfRD_dataOut  <= dinfRD_dataOutx; 
end 
//----------------------------------------------------------------------------------------------
assign dinfRD_Valid                 = dinfRD_dataOut[   56]; // device description entry valid 
assign dinfRD_new_event_trg_af      = dinfRD_dataOut[   53]; // lot of excesive events stored for this device and next excesive event should triger system event to nottify system about "device excessive events buffer almost full" issue occurence
assign dinfRD_ExEvPresent           = dinfRD_dataOut[   52]; // some events are in excessive events buffer                                                                                                                                    
assign dinfRD_firstExEvNum          = dinfRD_dataOut[51:44]; // number of first event that was puted into the excessive event buffer
assign dinfRD_lastExEvNum           = dinfRD_dataOut[43:36]; // number of last event that was puted into the device fifo or into the excessive event buffer
assign dinfRD_devAddr               = dinfRD_dataOut[35: 8]; 
assign dinfRD_DefCnt                = dinfRD_dataOut[ 6: 4];
assign dinfRD_DefOff                = dinfRD_dataOut[ 1: 0];                     
//=============================================================================================      
//always@(posedge clk or posedge rst)        
// if(  rst )         dinfRD_addr <=                                                         8'd0;                                                                      
// else               dinfRD_addr <=                                                 dinfRD_addrx;                                                      
//---------------------------------------------------------------------------------------------- 
assign dinfWR_addr =                                                                       
(reciever_state == R_INIT        )?                                               init_cnt[7:0]: 
(reciever_state == R_WRITE       )?                                                      i1_dev: 
(reciever_state == R_REG_UP      )?                                     dinf_first_free_up_slot:
(reciever_state == R_REG_DEV     )?                                    dinf_first_free_dev_slot: 
(reciever_state == R_XDAT3       )?                                              s3_dinf_wr_dev: 
(reciever_state == R_EVENT_SENT0 )?                                              s3_dinf_wr_dev: 
(reciever_state == R_SYS_EV      )?                                              s3_dinf_wr_dev: 8'hFF; 
//----------------------------------------------------------------------------------------------
assign dinfWR_dataIn =                                                                                                                              
(reciever_state == R_INIT        )? {1'b0,              3'd0, 1'd0, 8'd0, 8'hFF,            REFLECTOR_VER[27:0], 1'd0,            3'd0, 2'd0,            2'd0}:
(reciever_state == R_WRITE       )? {i1_forcedDevValid, 3'd0, 1'd0, 8'd0, 8'hFF,               i1_forcedDevAddr, 1'd0, i1_forcedDevCnt, 2'd0, i1_forcedDevOff}:  
(reciever_state == R_REG_UP      )? {1'b1,              3'd0, 1'd0, 8'd0, 8'hFF, i2_header_dev_addr[27:8], 8'd0, 1'd0,            3'd0, 2'd0,            2'd0}:
(reciever_state == R_REG_DEV     )? {1'b1,              3'd0, 1'd0, 8'd0, 8'hFF, i2_header_dev_addr[27:8], 8'd0, 1'd0,            3'd0, 2'd0,            2'd0}:
(reciever_state == R_XDAT3       )?                                                                                                s3_dinf_wr_dat:
(reciever_state == R_EVENT_SENT0 )?                                                                                                s3_dinf_wr_dat:
(reciever_state == R_SYS_EV      )?                                                                                                s3_dinf_wr_dat: 72'd0; 
//----------------------------------------------------------------------------------------------
assign dinfWR_wr =                                                                            
(reciever_state == R_INIT        )?                                                        1'b1:
(reciever_state == R_WRITE       )?                                                        1'b1:
(reciever_state == R_REG_UP      )?                                                        1'b1:
(reciever_state == R_REG_DEV     )?                                                        1'b1: 
(reciever_state == R_XDAT3       )?                                              s3_dinf_wr_stb: 
(reciever_state == R_EVENT_SENT0 )?                                              s3_dinf_wr_stb: 
(reciever_state == R_SYS_EV      )?                                              s3_dinf_wr_stb: 1'b0;  
//=============================================================================================  
// pointer to first free up slot. Used to assign new uP reflector number
always@(posedge clk or posedge rst)        
 if(  rst )                                dinf_first_free_up_slot  <=                            8'd1;  
 else if(reciever_state == R_REG_UP      ) dinf_first_free_up_slot  <=  dinf_first_free_up_slot + 8'd1;
 else if(reciever_state == R_SET_FREE_PTR) dinf_first_free_up_slot  <=                  i1_forcedUpPtr;
 else                                      dinf_first_free_up_slot  <=  dinf_first_free_up_slot + 8'd0;
//----------------------------------------------------------------------------------------------
// pointer to first free device slot. Used to assign new device reflector number
always@(posedge clk or posedge rst)        
 if(  rst )                                dinf_first_free_dev_slot <=                          8'd128;  
 else if(reciever_state == R_REG_DEV     ) dinf_first_free_dev_slot <= dinf_first_free_dev_slot + 8'd1;
 else if(reciever_state == R_SET_FREE_PTR) dinf_first_free_dev_slot <=                 i1_forcedDevPtr;
 else                                      dinf_first_free_dev_slot <= dinf_first_free_dev_slot + 8'd0;   
//=============================================================================================      
// s1         
//=============================================================================================   
always@(posedge clk or posedge rst)        
 if(  rst )                                s1_forced_sys_ev <=                             1'b0;
 else if(reciever_state == R_EVENT       ) s1_forced_sys_ev <=                 i1_forced_sys_ev;
//---------------------------------------------------------------------------------------------- 
always@(posedge clk) 
if(reciever_state == R_EVENT       )
     begin                                                                           
                                           s1_ptr <=                                     i1_ptr; 
                                           s1_cmd <=                                     i1_cmd; 
     end                                                                                         
//---------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)        
 if(  rst )                                s1_new_event_stb <=                             1'b0;  
 else if(reciever_state == R_EVENT       ) s1_new_event_stb <=                             1'b1;   
 else                                      s1_new_event_stb <=                             1'b0;    
//----------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)                                                     
 if(  rst )                                s1_from_exeb <=                                 1'b0;  
 else if(reciever_state == R_EVENT       ) s1_from_exeb <=                         i1_from_exeb;  
 else if(reciever_state == R_EVENT_CONF  ) s1_from_exeb <=                                 1'b0;   
 else                                      s1_from_exeb <=                                 1'b0;     
//----------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)                                                     
 if(  rst )                                s1_event_confirm <=                             1'b0;  
 else if(reciever_state == R_EVENT_CONF  ) s1_event_confirm <=                             1'b1;   
 else                                      s1_event_confirm <=                             1'b0;  
//----------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)        
 if(  rst )                                s1_event_dev <=                                 8'd0;  
 else if(reciever_state == R_EVENT       ) s1_event_dev <=                               i1_dev;   
 else if(reciever_state == R_EVENT_CONF  ) s1_event_dev <=                               i1_dev;   
 else if(reciever_state == R_READ        ) s1_event_dev <=                               i1_dev;   
 else                                      s1_event_dev <=                                 8'd0; 
//----------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)        
 if(  rst )                                s1_src_dev   <=                                 8'd0;  
 else if(reciever_state == R_EVENT       ) s1_src_dev   <=                               i1_src;   
 else if(reciever_state == R_EVENT_CONF  ) s1_src_dev   <=                               i1_src;   
 else                                      s1_src_dev   <=                                 8'd0;  
//---------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)        
 if(  rst )                                s1_sys_trg_norm       <=                        1'b0;  
 else if(reciever_state == R_REG_UP      ) s1_sys_trg_norm       <=                        1'b1;  
 else if(reciever_state == R_REG_DEV     ) s1_sys_trg_norm       <=                        1'b1;  
 else if(reciever_state == R_UNREG       ) s1_sys_trg_norm       <=                        1'b1;   
 else                                      s1_sys_trg_norm       <=                        1'b0; 
//---------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)        
 if(  rst )                                s1_read_trg           <=                        1'b0;  
 else if(reciever_state == R_READ        ) s1_read_trg           <=                        1'b1;   
 else                                      s1_read_trg           <=                        1'b0;  
//---------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)        
 if(  rst )                                s1_sys_trg_dev <=                               8'd0;
 else if(reciever_state == R_EVENT      )  s1_sys_trg_dev <=                             i1_dev;  
 else if(reciever_state == R_EVENT_CONF )  s1_sys_trg_dev <=                             i1_dev;   
 else if(reciever_state == R_REG_UP     )  s1_sys_trg_dev <=            dinf_first_free_up_slot; 
 else if(reciever_state == R_REG_DEV    )  s1_sys_trg_dev <=           dinf_first_free_dev_slot;
 else                                      s1_sys_trg_dev <=/*(MODE == "dbg")? 8'hff :*/ i1_dev;  
//---------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)        
 if(  rst )                                s1_sys_trg_norm_reason<=                        4'd0;  
 else if(reciever_state == R_REG_UP      ) s1_sys_trg_norm_reason<=                        4'd1;  
 else if(reciever_state == R_REG_DEV     ) s1_sys_trg_norm_reason<=                        4'd2;  
 else if(reciever_state == R_UNREG       ) s1_sys_trg_norm_reason<=                        4'd3;   
 else                                      s1_sys_trg_norm_reason<=                        4'd0; 
//---------------------------------------------------------------------------------------------- 
  // event type: trace event(1) / normal event(2) / system event(3)
always@(posedge clk or posedge rst)        
 if(  rst )                                s1_evnt_type   <=                               2'd0; 
 else if(reciever_state == R_EVENT       ) s1_evnt_type   <=                       i1_evnt_type;    
 else                                      s1_evnt_type   <=                       s1_evnt_type; 
//=============================================================================================      
// s2         
//=============================================================================================   
always@(posedge clk or posedge rst)        
 if(  rst )
     begin
         s2_new_event_stb      <=                                                         1'b0; 
         s2_from_exeb          <=                                                         1'b0;  
         s2_event_confirm      <=                                                         1'b0;
                                  
         s2_forced_sys_ev      <=                                                         1'd0;
         
         s2_sys_trg_norm       <=                                                         1'b0;
         s2_sys_trg_norm_reason<=                                                         4'd0;
         s2_sys_trg_dev        <=                                                         8'b0;  
      end  
 else      
     begin 
         s2_from_exeb          <=                                                 s1_from_exeb;
         s2_new_event_stb      <=                                             s1_new_event_stb;
         s2_event_confirm      <=                                             s1_event_confirm;
                                 
         s2_forced_sys_ev      <=                                             s1_forced_sys_ev;
                                                                                                 
         s2_sys_trg_dev        <=                                               s1_sys_trg_dev;  
         s2_sys_trg_norm       <=                                              s1_sys_trg_norm;
         s2_read_trg           <=                                                  s1_read_trg;
         s2_sys_trg_norm_reason<=                                       s1_sys_trg_norm_reason; 
     end      
//---------------------------------------------------------------------------------------------- 

always@(posedge clk)                                                         
     begin                                                                                     
         s2_ptr                <=                                                       s1_ptr; 
         s2_cmd                <=                                                       s1_cmd;
         s2_event_dev          <=                                                 s1_event_dev; 
         s2_src_dev            <=                                                   s1_src_dev;
         s2_evnt_type          <=                                                 s1_evnt_type;   
     end      
//---------------------------------------------------------------------------------------------- 

// zmiana wpisu w tablicy opisu urzdze zwizana z dodaniem nowego zdarzenia, lub potwierdzeniem wykonania zdarzenia
wire       s2_dev_eve_fifo_blocked  = (dinfRD_DefCnt == 3'd4) || (!s2_from_exeb && dinfRD_ExEvPresent);// kolejka peana lub zlecenia w ExEB 

// first excessive event number should be increased if event from Excessive Event Buffer is poped
wire [7:0] s2_new_event_firstExEvNum  = (s2_from_exeb)? (dinfRD_firstExEvNum + 8'd1) : dinfRD_firstExEvNum;
// counters if new event fits to Event Buffer
wire [7:0] s2_new_event_lastExEvNum   = dinfRD_lastExEvNum;                                      
wire [2:0] s2_new_event_DefCnt        = dinfRD_DefCnt + 3'd1; 
//// last valid counter
//wire [2:0] s2_last_event_DefCnt        = dinfRD_DefCnt; 
// counters if new event DOES NOT fits to Event Buffer
wire [7:0] s2_new_blcd_event_lastExEvNum= dinfRD_lastExEvNum + 8'd1;                                      
wire [2:0] s2_new_blcd_vent_DefCnt      = dinfRD_DefCnt;                                     
wire       s2_new_event_ExEvPresent     = (s2_from_exeb)? (dinfRD_firstExEvNum != dinfRD_lastExEvNum) : dinfRD_ExEvPresent;  
wire       s2_new_event_af_trg          = ((dinfRD_firstExEvNum - 8'd16) == dinfRD_lastExEvNum[7:0]); // flag that informs that if next event wil be stored to ExEvBuffer than "almost full" event should be sent to system
// counters update if event is confirmed                                                                                                  
wire [2:0] s2_event_cnf_DefCnt        =                                    dinfRD_DefCnt - 3'd1;
wire [1:0] s2_event_cnf_DefOff        =                                    dinfRD_DefOff + 3'd1; 
//---------------------------------------------------------------------------------------------- 
//  s2_new_event_stb                      - aktualizacja wpisu przy nowym evencie (wpadajcym do EB czy to do ExEB) lub 
//  s2_event_confirm                      - potwierdzeniu poprzedniego, 
// !s2_sys_trg_err                        - ale jedynie gdy zlecenie nie jest bdne (brak urzdzenia, lub brak potwierdzanego eventa) i
// !(s2_forced_sys_ev &&!dinfRD_Valid)    - i nie jest to wiadomo do systemu, ktrego jeszcze nie ma zarejestrowanego w lustrze  
assign      s2_dinf_wr_stb = (s2_new_event_stb || s2_event_confirm) && (!s2_sys_trg_err_dev_err && !(s2_forced_sys_ev &&!dinfRD_Valid));                     
assign      s2_dinf_wr_dev =  s2_event_dev;                
assign      s2_dinf_wr_dat = (s2_new_event_stb &&!s2_dev_eve_fifo_blocked)? {dinfRD_Valid, 2'd0,                1'd0, s2_new_event_ExEvPresent, s2_new_event_firstExEvNum,      s2_new_event_lastExEvNum, dinfRD_devAddr, 1'd0,     s2_new_event_DefCnt, 2'd0, dinfRD_DefOff      }:
                             (s2_new_event_stb && s2_dev_eve_fifo_blocked)? {dinfRD_Valid, 2'd0, s2_new_event_af_trg,                     1'b1, s2_new_event_firstExEvNum, s2_new_blcd_event_lastExEvNum, dinfRD_devAddr, 1'd0, s2_new_blcd_vent_DefCnt, 2'd0, dinfRD_DefOff      }:
                           /*(s2_event_confirm                          )?*/{dinfRD_Valid, 2'd0,                1'd0,       dinfRD_ExEvPresent, s2_new_event_firstExEvNum,            dinfRD_lastExEvNum, dinfRD_devAddr, 1'd0,     s2_event_cnf_DefCnt, 2'd0, s2_event_cnf_DefOff};
//---------------------------------------------------------------------------------------------- 
assign      s2_send_event_stb  = dinfRD_Valid && //!(s2_forced_sys_ev &&!dinfRD_Valid)             &&
                                 ((s2_event_confirm && dinfRD_DefCnt  > 3'd1) || 
                                  (s2_new_event_stb && dinfRD_DefCnt == 3'd0)   );               
//----------------------------------------------------------------------------------------------       
assign      s2_sys_trg_err_dev_err    = !(dinfRD_Valid || s2_forced_sys_ev) || (s2_event_confirm && dinfRD_DefCnt == 3'd0);  
assign      s2_sys_trg_err             = s2_sys_trg_err_dev_err || s2_sys_trg_almost_full || s2_sys_trg_dev_almost_full;
assign      s2_sys_trg_dev_almost_full = s2_new_event_stb && dinfRD_new_event_trg_af;// zostalo tylko 15 miejsc do 256 eventw jakie mona trzyma dla jednego urzdzenia
assign      s2_sys_trg_almost_full     = s2_new_event_stb && exfifo_af;// zostalo tylko 64 miejsc do 1024 eventw jakie mona trzyma dla wszystkich urzdzen
assign      s2_sys_trg_err_reason = (s2_sys_trg_almost_full    )?                         4'd8:
                                    (s2_sys_trg_dev_almost_full)?                         4'd7:
                                    (s2_event_confirm)?                                   4'd5:
                                  /*(s2_new_event_stb)?*/                                 4'd6; 
//=============================================================================================      
// s3 - path to output       
//============================================================================================= 
// zmiana wpisu w tablicy opisu urzdze zwizana z dodaniem nowego zdarzenia, lub potwierdzeniem wykonania zdarzenia
always@(posedge clk or posedge rst)        
 if(  rst )
         s3_dinf_wr_stb       <=                                                           1'b0; 
 else 
         s3_dinf_wr_stb       <=                                                 s2_dinf_wr_stb;
//---------------------------------------------------------------------------------------------- 

always@(posedge clk)      
     begin                
         s3_dinf_wr_dev       <=                                                s2_dinf_wr_dev; 
         s3_dinf_wr_dat       <=                                                s2_dinf_wr_dat;         
     end 
//=============================================================================================  
     always@(posedge clk or posedge rst)        
 if(  rst )  s3_forced_sys_ev <=                                                           1'b0;
 else        s3_forced_sys_ev <=                                               s2_forced_sys_ev;      
//---------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)        
 if(  rst )                                s3_send_out_stb     <=                          1'b0;  
 else if(f_R_XDAT2 && s2_read_trg        ) s3_send_out_stb     <=                          1'b1;  
 else if(f_R_XDAT2 && s2_send_event_stb  ) s3_send_out_stb     <=                          1'b1;  
 else                                      s3_send_out_stb     <=                          1'b0;    
//---------------------------------------------------------------------------------------------- 
always@(posedge clk)                                               
      if(f_R_XDAT2 && s2_read_trg        ) s3_send_out_dev     <=                  s2_event_dev;   
 else if(f_R_XDAT2 && s2_send_event_stb  ) s3_send_out_dev     <=                  s2_event_dev;   
 else                                      s3_send_out_dev     <=                  s2_event_dev;   
//---------------------------------------------------------------------------------------------- 
always@(posedge clk)        
      if(f_R_XDAT2 && s2_read_trg        ) s3_send_out_devAddr <=            i2_header_dev_addr;  
 else if(f_R_XDAT2 && s2_send_event_stb  ) s3_send_out_devAddr <=                dinfRD_devAddr;  
 else                                      s3_send_out_devAddr <=                dinfRD_devAddr;  
//---------------------------------------------------------------------------------------------- 
always@(posedge clk)        
      if(f_R_XDAT2 && s2_read_trg        ) s3_send_is_read     <=                          1'b1;
 else                                      s3_send_is_read     <=                          1'b0; 
//---------------------------------------------------------------------------------------------- 
always@(posedge clk)        
      if(f_R_XDAT2 && s2_read_trg        ) s3_send_out_sid     <=      i2_header_dev_addr[ 7:4];
 else                                      s3_send_out_sid     <=                       4'b11xx; // sid for events are filled based on event so it is known after event data is read        
//---------------------------------------------------------------------------------------------- 
always@(posedge clk)        
      if(f_R_XDAT2 && s2_read_trg        ) s3_send_out_rid     <=      i2_header_dev_addr[ 3:0];  
 else if(f_R_XDAT2 && s2_send_event_stb  ) s3_send_out_rid     <=                          4'hF; 
 else                                      s3_send_out_rid     <=                          4'hF;     
//---------------------------------------------------------------------------------------------- 
always@(posedge clk)        
      if(f_R_XDAT2 && s2_read_trg        ) s3_send_out_phadr   <=      i2_header_mem_addr[11:0];  
 else if(f_R_XDAT2 && s2_send_event_stb  ) s3_send_out_phadr   <=                       12'h000; 
 else                                      s3_send_out_phadr   <=                       12'h000;    
//---------------------------------------------------------------------------------------------- 
always@(posedge clk)        
      if(f_R_XDAT2 && s2_read_trg        ) s3_send_out_mop     <=            i2_header_mop[1:0];  
 else if(f_R_XDAT2 && s2_send_event_stb  ) s3_send_out_mop     <=                          2'd0; // event as "read 1 DW" 
 else                                      s3_send_out_mop     <=                          2'd0;    
//---------------------------------------------------------------------------------------------- 
always@(posedge clk)        
      if(f_R_XDAT2 && s2_read_trg        ) s3_send_out_prior   <=               i2_header_prior;  
 else if(f_R_XDAT2 && s2_send_event_stb  ) s3_send_out_prior   <=                          2'd3;  
 else                                      s3_send_out_prior   <=                          2'd3;     
//---------------------------------------------------------------------------------------------- 
always@(posedge clk)        
      if(f_R_XDAT2 && s2_read_trg        ) s3_send_out_len     <=              i2_header_rd_len;  
 else if(f_R_XDAT2 && s2_send_event_stb  ) s3_send_out_len     <=                          1'd0;   
 else                                      s3_send_out_len     <=                          1'd0;
//----------------------------------------------------------------------------------------------                                
assign  s3_send_out_header = {1'b1,1'b0,s3_send_out_prior[1:0], s3_send_out_devAddr[27:8], s3_send_out_sid, s3_send_out_rid, s3_send_out_len, PHY_ADDR[38:12], s3_send_out_phadr[11:3], 1'b0, s3_send_out_mop[1:0]};
//=============================================================================================     
// s3 - new system event to event buffer 
//=============================================================================================  
always@(posedge clk)                      
     begin                         
         s3_sys_trg_reason     <= (s2_sys_trg_norm)?                    s2_sys_trg_norm_reason:
                               /* (s2_sys_trg_err )?*/                  s2_sys_trg_err_reason ; 
         s3_sys_trg_dev        <=                                               s2_sys_trg_dev; 
         s3_sys_trg_devinf     <=                                               dinfRD_dataOut;
     end                                                                                        
//----------------------------------------------------------------------------------------------  
// assign  s3_sys_trg_devinf   = dinfRD_dataOut;                                                   
//=============================================================================================      
// s4 - path to output         
//=============================================================================================  
always@(posedge clk or posedge rst)        
 if(  rst )                                s4_send_event_stb  <=                           1'b0;   
 else if(f_R_EVENT_SENT0 )                 s4_send_event_stb  <=                           1'b1;   
 else                                      s4_send_event_stb  <=                           1'b0;    
//----------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)        
 if(  rst )                                s4_send_read_stb   <=                           1'b0;  
 else if(f_R_READ_OUT    )                 s4_send_read_stb   <=                           1'b1;    
 else                                      s4_send_read_stb   <=                           1'b0; 
//----------------------------------------------------------------------------------------------
always@(posedge clk)         
      if(f_R_WAIT        )                 s4_read_cnt        <=  (i1_rd_len)?      4'd6 : 4'hF;    
 else if(f_R_READ_OUT    )                 s4_read_cnt        <=             s4_read_cnt - 4'd1;    
 else                                      s4_read_cnt        <=             s4_read_cnt       ; 
//---------------------------------------------------------------------------------------------- 
assign s4_read_cnt_end_f =                                                       s4_read_cnt[3];
//---------------------------------------------------------------------------------------------- 
always@(posedge clk)        
                s4_send_event_dev           <=                                  s3_send_out_dev; 
//----------------------------------------------------------------------------------------------   
assign s4_send_event_type= ebA_dataOut[57:56];   
assign s4_send_event_src = ebA_dataOut[55:48];
assign s4_send_event_cmd = ebA_dataOut[47:40];
assign s4_send_event_ptr = ebA_dataOut[39: 0];                                                                  
assign s4_send_event_word = {8'hFF, s4_send_event_src, s4_send_event_cmd, s4_send_event_dev, s4_send_event_ptr};
//---------------------------------------------------------------------------------------------- 
always@(posedge clk)          
if(f_R_XDAT2)  s4_send_dinfo_word <= {dinfRD_new_event_trg_af, dinfRD_ExEvPresent,             //[61],[60]
                                      dinfRD_firstExEvNum[7:0],                                //[59:52]
                                      dinfRD_lastExEvNum[7:0],                                 //[51:44]   
                                      s2_event_dev,                                            //[43:36]    
                                      1'd0, dinfRD_DefCnt[2:0], dinfRD_DefOff[1:0], 1'd0,      //[34:32],[31:30],
                                      dinfRD_Valid,                                            //[28]
                                      dinfRD_devAddr[27:0]};                                   //[27:0]                               
else           s4_send_dinfo_word <=                                        s4_send_dinfo_word;
//=============================================================================================    
// output
//=============================================================================================    
always@(posedge clk or posedge rst)      
if(rst)                      o0_wr_ack_hen <=                                             1'b0; 
else                         o0_wr_ack_hen <=           (SEND_WR_FB == "TRUE") & i0_wra_ack_en;   
always@(posedge clk or posedge rst)      
if(rst)                      o0_wr_ack_den <=                                             1'b0; 
else                         o0_wr_ack_den <=           (SEND_WR_FB == "TRUE") & o0_wr_ack_hen;  
assign o0_wr_ack_en  =                                           o0_wr_ack_hen | o0_wr_ack_den; 
assign o0_wr_ack_hdr =                                   {i1_data[71:40], 1'b0, i1_data[38:0]};
assign o0_wr_ack_dat =                                               {1'b0, 7'd0, 8'd0, 56'd0};
//=============================================================================================   
always@(posedge clk or posedge rst)      
if(rst)                      o1_stb        <=                                             1'b0; 
else if(s3_send_out_stb    ) o1_stb        <=                                             1'b1; 
else if(s4_send_event_stb  ) o1_stb        <=                                             1'b1; 
else if(s4_send_read_stb   ) o1_stb        <=                                             1'b1;
else if(o0_wr_ack_en       ) o1_stb        <=                                             1'b1;  
else                         o1_stb        <=                                             1'b0; 
always@(posedge clk) begin                         
                             o1_sof        <=                  o0_wr_ack_hen | s3_send_out_stb; 
                             o1_change_sid <=               s3_send_out_stb & !s3_send_is_read;         
                             o1_data       <=          (o0_wr_ack_hen    )?      o0_wr_ack_hdr: 
                                                       (o0_wr_ack_den    )?      o0_wr_ack_dat: 
                                                       (s3_send_out_stb  )? s3_send_out_header: 
                                                       (s4_send_event_stb)? s4_send_event_word: 
                                                     /*(s4_send_read_stb)?*/s4_send_dinfo_word;
  end
//=============================================================================================   
always@(posedge clk or posedge rst)      
if(rst)                      o_stb         <=                                             1'b0; 
else                         o_stb         <=                                           o1_stb;   
always@(posedge clk) begin                
                             o_sof         <=                                           o1_sof;          
                             o_data        <=   (!o1_change_sid)?                o1_data[71:0]: 
                                      {o1_data[71:46], s4_send_event_type[1:0], o1_data[43:0]};
end                                                 
//=============================================================================================     
// s4 - new system event to event buffer 
//=============================================================================================                                   
always@(posedge clk or posedge rst)        
 if(  rst )                                s4_sys_trg_stb   <=                             1'b0;   
 else if(reciever_state == R_SYS_EV      ) s4_sys_trg_stb   <=                             1'b1;   
 else                                      s4_sys_trg_stb   <=                             1'b0;  
//----------------------------------------------------------------------------------------------     
always@(posedge clk)     
     begin                                                                                      
         s4_sys_trg_dev        <=                                                s3_sys_trg_dev;
         s4_sys_trg_devinf     <=                                             s3_sys_trg_devinf;
         s4_sys_trg_reason     <=                                             s3_sys_trg_reason;
     end 
//---------------------------------------------------------------------------------------------- 
wire            s4_sys_trg_devinf_Valid                 = s4_sys_trg_devinf[   56]; // device description entry valid
wire            s4_sys_trg_devinf_ExEvPresent           = s4_sys_trg_devinf[   52]; // some events are in excessive events buffer                                                                                                                                    
wire  [ 7:0]    s4_sys_trg_devinf_firstExEvNum          = s4_sys_trg_devinf[51:44]; // number of first event that was puted into the excessive event buffer
wire  [ 7:0]    s4_sys_trg_devinf_lastExEvNum           = s4_sys_trg_devinf[43:36]; // number of last event that was puted into the device fifo or into the excessive event buffer
wire  [27:0]    s4_sys_trg_devinf_devAddr               = s4_sys_trg_devinf[35: 8]; 
wire  [ 2:0]    s4_sys_trg_devinf_DefCnt                = s4_sys_trg_devinf[ 6: 4];
wire  [ 1:0]    s4_sys_trg_devinf_DefOff                = s4_sys_trg_devinf[ 1: 0]; 


assign s4_sys_trg_cmd  = {1'b1, 3'd0, s4_sys_trg_reason};
assign s4_sys_trg_devinf_form = {s4_sys_trg_dev, s4_sys_trg_devinf_ExEvPresent, |s4_sys_trg_devinf_DefCnt, 1'b0, s4_sys_trg_devinf_Valid, s4_sys_trg_devinf_devAddr};
assign s4_sys_trg_word = {8'hFF, REF_DEV_ID[7:0], s4_sys_trg_cmd, REF_SYS_UP_ID[7:0], s4_sys_trg_devinf_form[39:0]}; 
//=============================================================================================       
// Events Buffer - 3 BRAMs in true dual port mode 1024x54b 
// divided into 256 fifos for devices and uPs, 4 word length each
//=============================================================================================  
initial for(i = 0; i<1024; i=i+1) EB [i] <= 58'd0;   
always@(posedge clk) 
  begin                                       
      if(ebA_wr) EB [ebA_addrx] <= ebA_dataIn; 
  end                                         
//----------------------------------------------------------------------------------------------  
always@(posedge clk)       
  begin
    if(ebA_wr)       
      ebA_dataOutx <= ebA_dataIn; //WRITE_FIRST
    else
      ebA_dataOutx <= EB [ebA_addrx];                                                                      
      ebA_dataOut  <= ebA_dataOutx; 
  end
//============================================================================================= 
wire [1:0] ebB_addrx_offset = 2'd2 + dinfRD_DefOff[1:0];    
wire [1:0] ebA_addrx_offset = s2_new_event_DefCnt[1:0] + dinfRD_DefOff[1:0];                                         
assign ebA_addrx  = (s2_new_event_stb       )?                 {s2_event_dev, ebA_addrx_offset}: // adres bufora urzdze + offset wynikajcy z poczatku cyklicznej kolejki fifo i iloci zajtych miejsc
                                                               {s2_event_dev, ebB_addrx_offset};                                 
//----------------------------------------------------------------------------------------------
assign ebA_dataIn =                                  {s2_evnt_type, s2_src_dev, s2_cmd, s2_ptr}; 
assign ebA_wr     = (s2_new_event_stb       )?                  !s2_dev_eve_fifo_blocked : 1'b0; 

//---------------------------------------------------------------------------------------------- 
assign ebB_addrx =  (s2_new_event_stb )?                       {s2_event_dev, ebA_addrx_offset}: // adres zapisu dopiero co przyjtego eventa, 
                  /*(s2_event_confirm)?*/                      {s2_event_dev, ebB_addrx_offset}; // adres kolejnego eventa - w sumie to jest taki sam jak adres pod ktry zapisany by zosta nowy event wic wpis jest taki sam:)                                                          
//----------------------------------------------------------------------------------------------
assign ebB_dataIn = 56'd0; 
//----------------------------------------------------------------------------------------------
assign ebB_wr =  1'd0;                                                                                      
//=============================================================================================       
// Excessive Events Buffer - 3 BRAMs in true dual port mode 1024x54b 
// divided into 256 fifos for devices and uPs, 4 word length each
//============================================================================================= 
initial for(i = 0; i<1024; i=i+1) ExEB [i] <= 74'd0;
always@(posedge clk)
 begin                                            
     if(exebA_wr) 
         ExEB [exebA_addrx] <= exebA_dataIn;   
 end                                   
//---------------------------------------------------------------------------------------------- 
always@(posedge clk)           
    begin                                                                                                   
        exebB_dataOutx <= ExEB [exebB_addrx];      
        if(rst)
            exebB_dataOut  <= 74'd0;       
        else
            exebB_dataOut  <= exebB_dataOutx; 
    end                                                                                                     
//=============================================================================================  
always@(posedge clk or posedge rst)        
 if(  rst )                     exfifo_begin <= 10'd0;                                                                      
 else if (x6_wr_exev_to_exeb )  exfifo_begin <= exfifo_begin + 10'd1;
 else if (x6_wr_exev_to_input)  exfifo_begin <= exfifo_begin + 10'd1;                         
//---------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)        
 if(  rst )                                            exfifo_end   <= 10'd0;                                                         
 else if (s2_new_event_stb && s2_dev_eve_fifo_blocked) exfifo_end   <= exfifo_end + 10'd1;                                          
 else if (x6_wr_exev_to_exeb                         ) exfifo_end   <= exfifo_end + 10'd1;                                                                    
 else                                                  exfifo_end   <= exfifo_end;                
//---------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)        
 if(  rst )                      exfifo_slot_left   <=                                    10'd0;                                                                                 
 else                            exfifo_slot_left   <=              (exfifo_begin - exfifo_end); 
//---------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)        
 if(  rst )                      exfifo_af              <=                                 1'd0;                                                                                 
 else                            exfifo_af              <=           exfifo_slot_left == 10'd64;  
//---------------------------------------------------------------------------------------------- 
assign exebA_addrx = /*(MODE != "dbg")? */                                           exfifo_end/*:                                                              
(s2_new_event_stb        )?                                                          exfifo_end: // adres bufora urzdze + offset wynikajcy z poczatku cyklicznej kolejki fifo i iloci zajtych miejsc
                                                                                           8'h0*/; // x0_exeb_addr;                                            
//---------------------------------------------------------------------------------------------- 
                                                         
assign exebA_dataIn =        //                       [7:0],        [1:0],     [7:0],  [7:0],        [7:0], [39:0]                                         
(s2_new_event_stb        )? { s2_new_blcd_event_lastExEvNum, s2_evnt_type,s2_src_dev, s2_cmd, s2_event_dev, s2_ptr}:                                                                            
(x6_wr_exev_to_exeb      )?                                                                           x6_exeb_entry: 
                          /*(MODE == "dbg")?                                                80'd0 :*/ x6_exeb_entry; 
//----------------------------------------------------------------------------------------------
assign exebA_wr =                                   
(s2_new_event_stb       )?                                              s2_dev_eve_fifo_blocked: 
                                                                             x6_wr_exev_to_exeb; 

//----------------------------------------------------------------------------------------------
assign exebB_addrx  =                                                              x0_exeb_addr;                                                                                
//----------------------------------------------------------------------------------------------
assign exebB_dataIn =                                                                     74'd0; 
//----------------------------------------------------------------------------------------------
assign exebB_wr     =                                                                      1'b0;                                                                                                                                          
//=============================================================================================      
// excessive event buffer searching pipe stages
//=============================================================================================  
// stage 0 - Excessive events buffer read start                                            
//---------------------------------------------------------------------------------------------
assign   x0_exeb_addr = exfifo_begin;
assign   x0_stb = (exfifo_begin != exfifo_end) && !x6_wr_exev_to_x && !i1_stb && (reciever_state == R_WAIT);        
//---------------------------------------------------------------------------------------------
// stage 1 - Excessive events buffer response waiting           
//---------------------------------------------------------------------------------------------    
always@(posedge clk or posedge rst)        
 if(  rst )
     begin                      
         x1_stb       <=  1'd0;
         //x1_exeb_addr <= 10'd0;  
     end
 else                
     begin                             
         x1_stb       <= x0_stb && !x6_wr_exev_to_x &&!i1_stb;
         //x1_exeb_addr <= x0_exeb_addr;  
     end                             
//--------------------------------------------------------------------------------------------- 
// stage 2 - Excessive events buffer response & device info table read start        
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)        
 if(  rst )
     begin                      
         x2_stb       <=  1'd0;
         //x2_exeb_addr <= 10'd0;  
     end
 else                
     begin                             
         x2_stb       <= x1_stb && !x6_wr_exev_to_x &&!i1_stb;
         //x2_exeb_addr <= x1_exeb_addr;  
     end                    
       
assign   x2_exeb_entry       = exebB_dataOut;    
assign   x2_exeb_entry_dev   = x2_exeb_entry[47:40];
assign   x2_exeb_entry_type  = x2_exeb_entry[65:64]; 
assign   x2_exeb_entry_evNum = x2_exeb_entry[73:66];    
//--------------------------------------------------------------------------------------------- 
// stage 3 - Device info table response waiting                    
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)        
 if(  rst ) x3_stb       <=  1'd0;
 else       x3_stb       <= x2_stb && !x6_wr_exev_to_x &&!i1_stb;
//---------------------------------------------------------------------------------------------
always@(posedge clk)        
            x3_exeb_entry<= x2_exeb_entry;   
     
assign   x3_exeb_entry_dev   = x3_exeb_entry[47:40];
assign   x3_exeb_entry_type  = x3_exeb_entry[65:64]; 
assign   x3_exeb_entry_evNum = x3_exeb_entry[73:66];                                                         
//--------------------------------------------------------------------------------------------- 
// stage 4 - Device info table response & decision if event can be push to reflector entry once 
    // more (if there is an empty place in device fifo), or if to push it back to excessive 
    // buffer (no place in device buffer or this is not the first event waiting in excessive 
    // buffer to be put into this device fifo)           
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)        
if(  rst ) x4_stb       <=  1'd0;
else       x4_stb       <= x3_stb && !x6_wr_exev_to_x &&!i1_stb;
//---------------------------------------------------------------------------------------------
always@(posedge clk)        
           x4_exeb_entry<= x3_exeb_entry;  
        
assign   x4_exeb_entry_dev   = x4_exeb_entry[47:40];
assign   x4_exeb_entry_type  = x4_exeb_entry[65:64]; 
assign   x4_exeb_entry_evNum = x4_exeb_entry[73:66]; 
                                    
assign   x4_devinf_entry              = dinfRD_dataOut;              
assign   x4_devinf_entry_firstExEvNum = x4_devinf_entry[51:44];
assign   x4_devinf_entry_DefCnt       = x4_devinf_entry[ 6: 4];

assign   x4_wr_exev_to_input = x4_stb &&((x4_exeb_entry_evNum == x4_devinf_entry_firstExEvNum) && (x4_devinf_entry_DefCnt != 3'd4));
assign   x4_wr_exev_to_exeb  = x4_stb &&((x4_exeb_entry_evNum != x4_devinf_entry_firstExEvNum) || (x4_devinf_entry_DefCnt == 3'd4));
//--------------------------------------------------------------------------------------------- 
// stage 5 - buffer for decision from stage 4,      
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)        
 if(  rst )
     begin                                
         x5_wr_exev_to_input <=  1'd0;
         x5_wr_exev_to_exeb  <=  1'd0; 
         x5_wr_exev_to_x     <=  1'b0;
     end
 else                
     begin                                      
         x5_wr_exev_to_input <= x4_wr_exev_to_input && !x6_wr_exev_to_x &&!i1_stb; 
         x5_wr_exev_to_exeb  <= x4_wr_exev_to_exeb  && !x6_wr_exev_to_x &&!i1_stb;
         x5_wr_exev_to_x     <= x4_stb              && !x6_wr_exev_to_x &&!i1_stb;  
     end 
//---------------------------------------------------------------------------------------------
always@(posedge clk)  
         x5_exeb_entry       <= x4_exeb_entry;
//--------------------------------------------------------------------------------------------- 
// stage 6 - buffer for decision from stage 5, and driver signal for writing        
//---------------------------------------------------------------------------------------------
always@(posedge clk or posedge rst)        
 if(  rst )
     begin                               
         x6_wr_exev_to_input <=  1'd0;
         x6_wr_exev_to_exeb  <=  1'd0; 
         x6_wr_exev_to_x     <=  1'b0;
     end
 else                
     begin                                         
         x6_wr_exev_to_input <= x5_wr_exev_to_input && !x6_wr_exev_to_x &&!i1_stb; 
         x6_wr_exev_to_exeb  <= x5_wr_exev_to_exeb  && !x6_wr_exev_to_x &&!i1_stb;
         x6_wr_exev_to_x     <= x5_wr_exev_to_x     && !x6_wr_exev_to_x &&!i1_stb;  
     end 
//---------------------------------------------------------------------------------------------
always@(posedge clk)   
         x6_exeb_entry       <= x5_exeb_entry;
//=============================================================================================  
endmodule 