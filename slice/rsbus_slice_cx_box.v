//==============================================================================================
//    Main contributors
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//==============================================================================================
`default_nettype none
//----------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//==============================================================================================
module rsbus__slice_cx_box
(
 input  wire            clk,                    /*synthesis syn_keep=1*/
 input  wire            rst,                    /*synthesis syn_keep=1*/

 input  wire            i_stb,                  /*synthesis syn_keep=1*/
 input  wire            i_sof,                  /*synthesis syn_keep=1*/
 input  wire    [71:0]  i_data,                 /*synthesis syn_keep=1*/
 output wire     [1:0]  i_rdy,                  /*synthesis syn_keep=1*/  

 output wire            o_stb,                  /*synthesis syn_keep=1*/
 output wire            o_sof,                  /*synthesis syn_keep=1*/
 output wire    [71:0]  o_data,                 /*synthesis syn_keep=1*/
 input  wire     [1:0]  o_rdy,                  /*synthesis syn_keep=1*/
 input  wire     [1:0]  o_rdyE,                 /*synthesis syn_keep=1*/
 
 input  wire            dbg_i_stb,              /*synthesis syn_keep=1*/
 input  wire      [7:0] dbg_i_data,             /*synthesis syn_keep=1*/
 output wire            dbg_i_ack,              /*synthesis syn_keep=1*/
 
 output wire            dbg_o_stb,              /*synthesis syn_keep=1*/
 output wire      [7:0] dbg_o_data,             /*synthesis syn_keep=1*/
 input  wire            dbg_o_ack,              /*synthesis syn_keep=1*/
 
 output wire            ff_err                  /*synthesis syn_keep=1*/ 
);                                                                                                                                                                  
//==============================================================================================
// local param
//==============================================================================================
parameter               CORE_NUM      =                                                    'h10;
//==============================================================================================
// variables
//==============================================================================================    
wire                d2r_sof  [0:CORE_NUM+3];
wire        [11:0]  d2r_ctrl [0:CORE_NUM+3];
wire        [71:0]  d2r_data [0:CORE_NUM+3];
wire  [CORE_NUM:0]  d2r_inf_ff_err; 
wire                d2r_mgr_ff_err;
//---------------------------------------------------------------------------------------------- 
wire                r2d_sof  [0:CORE_NUM+3];
wire        [71:0]  r2d_data [0:CORE_NUM+3];
//---------------------------------------------------------------------------------------------- 
wire                dbg_stb  [0:CORE_NUM];
wire        [ 7:0]  dbg_data [0:CORE_NUM];
wire                dbg_ack  [0:CORE_NUM];
//---------------------------------------------------------------------------------------------- 
reg                 ff_ovr_err;
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
.FF_DEPTH          ((CORE_NUM > 8)? 64 : ((CORE_NUM > 4)? 32 : 16)),       
// if ff depth is set as above than internal ffs can not overflow because d2r_injectors can 
// insert only 4 requests so it gives #(CORE_NUM*4) requests of each packets type 
// (various combinations of length and priority)
// Situation changed because of additional slots for packets with packet priority 3 that
// are now available in d2r_injectors. If an unlikely situation occures and all devices in a ring 
// sends packets with PP3 than a total number of those types of request can be #(CORE_NUM*5) for 
// a long packets and #(CORE_NUM*6) for a short packets. This situation is indeed very unlikely 
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
// debug chain
//==============================================================================================
assign          dbg_stb  [0]        = dbg_i_stb;
assign          dbg_data [0]        = dbg_i_data;
assign          dbg_i_ack           = dbg_ack[0];
//==============================================================================================
assign          dbg_o_stb           = dbg_stb[CORE_NUM];
assign          dbg_o_data          = dbg_data[CORE_NUM];
assign          dbg_ack[CORE_NUM]   = dbg_o_ack;
//==============================================================================================
// risc core
//==============================================================================================
generate        
genvar i;
    for(i=0;i<CORE_NUM;i=i+1)                                                     
        begin : CORE
              
            wire                    to_root_stb;
            wire                    to_root_sof;
            wire             [3:0]  to_root_iid;
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
            .BASE_ID         (i[3:0]*2),                                                
            .LAST_ID         (i[3:0]*2+1),
            .PASS_WR_ACK     ("FALSE")				  		 
            )
            r2d_extractor
            (                                                                                                                               
            .clk            (clk),
            .rst            (rst),   
                                           
            .i_sof          (r2d_sof [i+2]),
            .i_bus          (r2d_data[i+2]),
                                              
            .o_sof          (r2d_sof [i+3]),
            .o_bus          (r2d_data[i+3]),
            
            .frm_o_stb      (from_root_stb),  
            .frm_o_sof      (from_root_sof),  
            .frm_o_iid      (from_root_iid),
            .frm_o_bus      (from_root_data),
            .frm_o_rdy      (from_root_rdy)
            );         
                
            eco32_core_box core
            (                                       
            .clk            (clk),                                                 
            .rst            (rst),   
            .ena            (2'b11),   

            .i_stb          (from_root_stb),
            .i_sof          (from_root_sof),
            .i_iid          (from_root_iid),
            .i_data         (from_root_data),  
            .i_rdy          (from_root_rdy), 

            .o_stb          (to_root_stb),
            .o_sof          (to_root_sof),
            .o_iid          (to_root_iid),                                     
            .o_data         (to_root_data),
            .o_rdy          (to_root_rdy), 
            .o_rdyE         (to_root_rdyE),                                
            
            .dbg_i_stb      (dbg_stb [i]),
            .dbg_i_data     (dbg_data[i]),                                             
            .dbg_i_ack      (dbg_ack [i]),                                               
            
            .dbg_o_stb      (dbg_stb [i+1]),
            .dbg_o_data     (dbg_data[i+1]),
            .dbg_o_ack      (dbg_ack [i+1]) 
            );   

            rsbus_d2r_injector
            #(                
            .BASE_ID         (i[3:0]*2),                                                
            .LAST_ID         (i[3:0]*2+1) 
            )  
            d2r_injector
            (                                                                                                                               
            .clk            (clk),
            .rst            (rst),   
            
            .frm_i_stb      (to_root_stb),                                                               
            .frm_i_sof      (to_root_sof),
            .frm_i_iid      (to_root_iid),
            .frm_i_bus      (to_root_data),
            .frm_i_rdy      (to_root_rdy), 
            .frm_i_rdyE     (to_root_rdyE), 
            
            .i_sof          (d2r_sof  [i+2]),
            .i_ctrl         (d2r_ctrl [i+2]),
            .i_bus          (d2r_data [i+2]),
                                          
            .o_sof          (d2r_sof  [i+3]),
            .o_ctrl         (d2r_ctrl [i+3]),
            .o_bus          (d2r_data [i+3]),
            
            .ff_err         (d2r_inf_ff_err[i])
            );                                                                          
			
`ifdef SIMULATION                                                                                        
	if(1)	
			begin : dbg
              
              integer time_cnt;
              integer fout_0;
              string  m_0;
              
              initial $sformat(m_0,"log__%m_th0.txt");
              initial fout_0 = $fopen(m_0,"w");

              integer fout_1;
              string  m_1;
              
              initial $sformat(m_1,"log__%m_th1.txt");
              initial fout_1 = $fopen(m_1,"w");

              always@(posedge clk or posedge rst)  
                if(rst) time_cnt <= 0;
                else    time_cnt++;
                
              wire  [3:0] req_SID   = to_root_data[47:44];  
              wire  [3:0] req_RID   = to_root_data[43:40];  
              wire  [3:0] req_MOD   = to_root_data[2:0];  
              wire        req_LEN   = to_root_data[39];  
              wire [31:0] req_TIME  = time_cnt;  
              wire [31:0] req_ADDR  = {to_root_data[31:3],3'd0};  

              wire  [3:0] ans_SID   = from_root_data[47:44];  
              wire  [3:0] ans_RID   = from_root_data[43:40];  
              wire  [3:0] ans_MOD   = from_root_data[2:0];  
              wire        ans_LEN   = from_root_data[39];  
              wire [31:0] ans_TIME  = time_cnt;  
              wire [31:0] ans_ADDR  = {from_root_data[31:3],3'd0};  
              
              
              always@(posedge clk)  
              begin    
                
                if(!rst && to_root_stb && to_root_sof && to_root_iid[0]=='d0)
                  begin
                    $fdisplay(fout_0,"OP:0,TIME:%H,SID:%H,RID:%H,MODE:%H,LEN:%H,ADDR:%H",req_TIME,req_SID,req_RID,req_MOD,req_LEN,req_ADDR); 
                  end
                if(!rst && from_root_stb && from_root_sof && from_root_iid[0]=='d0) 
                  begin
                    $fdisplay(fout_0,"OP:1,TIME:%H,SID:%H,RID:%H,MODE:%H,LEN:%H,ADDR:%H",ans_TIME,ans_SID,ans_RID,ans_MOD,ans_LEN,ans_ADDR); 
                  end

                  
                if(!rst && to_root_stb && to_root_sof && to_root_iid[0]=='d1)
                  begin
                    $fdisplay(fout_1,"OP:0,TIME:%H,SID:%H,RID:%H,MODE:%H,LEN:%H,ADDR:%H",req_TIME,req_SID,req_RID,req_MOD,req_LEN,req_ADDR); 
                  end
                if(!rst && from_root_stb && from_root_sof && from_root_iid[0]=='d1) 
                  begin
                    $fdisplay(fout_1,"OP:1,TIME:%H,SID:%H,RID:%H,MODE:%H,LEN:%H,ADDR:%H",ans_TIME,ans_SID,ans_RID,ans_MOD,ans_LEN,ans_ADDR); 
                  end  
                  
                  $fflush(fout_0);
                  $fflush(fout_1);
              end    
            end
`endif //SIMULATION
        end 
endgenerate			
//==============================================================================================
// Frame  generator for R2D ring
//==============================================================================================
rsbus_frame_generator r2d_frame_generator
(
.clk            (clk),
.rst            (rst),                                          
                                                            
.i_sof          (r2d_sof  [CORE_NUM+2]),
.i_ctrl         (12'd0),
.i_bus          (r2d_data [CORE_NUM+2]),   

.o_sof          (r2d_sof  [CORE_NUM+3]),
.o_ctrl         (),
.o_bus          (r2d_data [CORE_NUM+3])
); 
//..............................................................................................
assign           d2r_sof  [CORE_NUM+3] = d2r_sof  [CORE_NUM+2];                                                                    
assign           d2r_ctrl [CORE_NUM+3] = d2r_ctrl [CORE_NUM+2];
assign           d2r_data [CORE_NUM+3] = d2r_data [CORE_NUM+2];
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
                                      
.i_sof                  (d2r_sof  [CORE_NUM+3]),
.i_ctrl                 (d2r_ctrl [CORE_NUM+3]),
.i_bus                  (d2r_data [CORE_NUM+3]),
                                      
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

.i_sof                  (r2d_sof [CORE_NUM+3]),
.i_bus                  (r2d_data[CORE_NUM+3]),
                                      
.o_sof                  (r2d_sof [0]),
.o_bus                  (r2d_data[0]),  

.ff_err                 (d2r_inf_ff_err[CORE_NUM])
);  
//==============================================================================================
always @(posedge clk or posedge rst)                                                                           
if( rst                  ) ff_ovr_err    <=                                                1'b0;
else if(  d2r_mgr_ff_err ) ff_ovr_err    <=                                                1'b1;                 
else if( |d2r_inf_ff_err ) ff_ovr_err    <=                                                1'b1;  
else                       ff_ovr_err    <=                                          ff_ovr_err;    
//---------------------------------------------------------------------------------------------- 
assign ff_err =                                                                      ff_ovr_err;
//============================================================================================== 
endmodule            