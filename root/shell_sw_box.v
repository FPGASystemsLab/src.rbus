//==============================================================================================
//    Main contributors                                          
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//==============================================================================================
`default_nettype none
//----------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//==============================================================================================
`include "mem_spaces.vh"
//==============================================================================================
module shell_ws_box
#
(
parameter               BRANCH_NUM = 4
) 
(
 input  wire          rst,                /*synthesis syn_keep=1*/
 input  wire          clk,                /*synthesis syn_keep=1*/

 output wire  [14:0]  dbg,                /*synthesis syn_keep=1*/       
 
 // bootrom/flash port 

 output wire          mem0_o_stb,         /*synthesis syn_keep=1*/
 output wire          mem0_o_sof,         /*synthesis syn_keep=1*/
 output wire  [71:0]  mem0_o_data,        /*synthesis syn_keep=1*/
 input  wire  [ 1:0]  mem0_o_af,          /*synthesis syn_keep=1*/

 input  wire          mem0_i_stb,         /*synthesis syn_keep=1*/
 input  wire          mem0_i_sof,         /*synthesis syn_keep=1*/
 input  wire  [71:0]  mem0_i_data,        /*synthesis syn_keep=1*/  
 output wire  [ 1:0]  mem0_i_af,          /*synthesis syn_keep=1*/  
 
 // external RAM port (DDR) 

 output wire          mem1_o_stb,         /*synthesis syn_keep=1*/
 output wire          mem1_o_sof,         /*synthesis syn_keep=1*/
 output wire  [71:0]  mem1_o_data,        /*synthesis syn_keep=1*/
 input  wire  [ 1:0]  mem1_o_af,          /*synthesis syn_keep=1*/

 input  wire          mem1_i_stb,         /*synthesis syn_keep=1*/
 input  wire          mem1_i_sof,         /*synthesis syn_keep=1*/
 input  wire  [71:0]  mem1_i_data,        /*synthesis syn_keep=1*/
 output wire  [ 1:0]  mem1_i_af,          /*synthesis syn_keep=1*/
 
 //
 
 input  wire          branch_d2r_stb [BRANCH_NUM-1:0],   /*synthesis syn_keep=1*/
 input  wire          branch_d2r_sof [BRANCH_NUM-1:0],   /*synthesis syn_keep=1*/
 input  wire  [71:0]  branch_d2r_data[BRANCH_NUM-1:0],  /*synthesis syn_keep=1*/
 output wire  [ 1:0]  branch_d2r_af  [BRANCH_NUM-1:0],    /*synthesis syn_keep=1*/
 
 output wire          branch_r2d_stb [BRANCH_NUM-1:0],   /*synthesis syn_keep=1*/
 output wire          branch_r2d_sof [BRANCH_NUM-1:0],   /*synthesis syn_keep=1*/
 output wire  [71:0]  branch_r2d_data[BRANCH_NUM-1:0],  /*synthesis syn_keep=1*/
 input  wire  [ 1:0]  branch_r2d_af  [BRANCH_NUM-1:0],    /*synthesis syn_keep=1*/ 
 
 output wire          ff_err              /*synthesis syn_keep=1*/
);    
//==============================================================================================
// variables                                                  
//==============================================================================================   
wire            d2r_sof  [0:9+BRANCH_NUM];
wire    [11:0]  d2r_ctrl [0:9+BRANCH_NUM];
wire    [71:0]  d2r_data [0:9+BRANCH_NUM];
//---------------------------------------------------------------------------------------------- 
wire            r2d_sof  [0:9+BRANCH_NUM];
wire    [71:0]  r2d_data [0:9+BRANCH_NUM];
//----------------------------------------------------------------------------------------------        
wire            branch0_inj_ff_err;
wire            branch1_inj_ff_err;  
//----------------------------------------------------------------------------------------------  
 reg            ff_ovr_err;
//==============================================================================================
// Frame  generator for D2R ring
//==============================================================================================
rbus_frame_generator d2r_frame_generator
(
.clk            (clk),
.rst            (rst),                                          
                                                            
.i_sof          (d2r_sof  [0]),
.i_ctrl         (d2r_ctrl [0]),
.i_data         (d2r_data [0]),   

.o_sof          (d2r_sof  [1]),
.o_ctrl         (d2r_ctrl [1]),
.o_data         (d2r_data [1])
); 
//..............................................................................................
assign           r2d_sof  [1]   =                                                  r2d_sof  [0];
assign           r2d_data [1]   =                                                  r2d_data [0];
//==============================================================================================
// RBUS access manager
//==============================================================================================
wire d2r_mgr_ff_err;
rbus_d2r_mgr d2r_mgr 
(
.clk            (clk),
.rst            (rst), 

.i_sof          (d2r_sof  [1]),
.i_ctrl         (d2r_ctrl [1]),
.i_data         (d2r_data [1]),
                 
.o_sof          (d2r_sof  [2]),
.o_ctrl         (d2r_ctrl [2]),
.o_data    	    (d2r_data [2]),

.ff_err         (d2r_mgr_ff_err)
); 
//..............................................................................................
assign           r2d_sof [2] = r2d_sof [1];
assign           r2d_data[2] = r2d_data[1];
//==============================================================================================
// memory address map PHY->LOGICAL
//==============================================================================================
shell_mem_map
#(     
  .DIRECTION("PHY2LOG")
)
mem_map_phy2log
(
.clk            (clk),
.rst            (rst),    
 
.i_sof          (r2d_sof  [2]),
.i_ctrl         (8'd0),
.i_data         (r2d_data [2]),   
            
.o_sof          (r2d_sof  [3]),
.o_ctrl         (),
.o_data         (r2d_data [3])
);                
//..............................................................................................
assign           d2r_sof  [3]   =                                                  d2r_sof  [2];
assign           d2r_ctrl [3]   =                                                  d2r_ctrl [2];
assign           d2r_data [3]   =                                                  d2r_data [2];
//==============================================================================================
// branch 0
//==============================================================================================
generate
genvar i;
  for(i=0;i<BRANCH_NUM;i=i+1)
  begin : BRANCH
  
    rbus_r2d_extractor
    #
    (                     
    .BASE_ID         (i),                                                
    .LAST_ID         (i)
    )
    r2d_extractor
    (                                                                                                                      
    .clk            (clk),                                   
    .rst            (rst),                                   
                                                             
    .r2d_i_sof      (r2d_sof [i+3]),                         
    .r2d_i_data     (r2d_data[i+3]),                         
                                                             
    .r2d_o_sof      (r2d_sof [i+4]),                         
    .r2d_o_data     (r2d_data[i+4]),                         
    
    .o_stb          (branch_r2d_stb  [i]),  
    .o_sof          (branch_r2d_sof  [i]),  
    .o_iid          (),
    .o_data         (branch_r2d_data [i]),
    .o_af           (branch_r2d_af   [i])
    );         
    
    rbus_d2r_injector
    #(                  
    .BASE_ID         (i),                                                
    .LAST_ID         (i)
    )  
    d2r_injector
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   
    
    .i_stb          (branch_d2r_stb  [i]),                                                               
    .i_sof          (branch_d2r_sof  [i]),
    .i_iid          (4'd0),
    .i_data         (branch_d2r_data [i]),
    .i_af           (branch_d2r_af   [i]), 
    
    .d2r_i_sof      (d2r_sof  [i+3]),
    .d2r_i_ctrl     (d2r_ctrl [i+3]),
    .d2r_i_data     (d2r_data [i+3]),
                                  
    .d2r_o_sof      (d2r_sof  [i+4]),
    .d2r_o_ctrl     (d2r_ctrl [i+4]),
    .d2r_o_data     (d2r_data [i+4]),
    
    .ff_err         (branch0_inj_ff_err)
    );                                
  end                 
endgenerate                                                                                
//==============================================================================================
// Frame  generator for R2D ring
//==============================================================================================
rbus_frame_generator r2d_frame_generator
(
.clk            (clk),
.rst            (rst),                                          
                                                            
.i_sof          (r2d_sof  [3+BRANCH_NUM]),
.i_ctrl         (8'd0),
.i_data         (r2d_data [3+BRANCH_NUM]),   

.o_sof          (r2d_sof  [4+BRANCH_NUM]),
.o_ctrl         (),
.o_data         (r2d_data [4+BRANCH_NUM])
); 
//..............................................................................................
assign           d2r_sof  [4+BRANCH_NUM]   =                            d2r_sof  [3+BRANCH_NUM];   
assign           d2r_ctrl [4+BRANCH_NUM]   =                            d2r_ctrl [3+BRANCH_NUM];
assign           d2r_data [4+BRANCH_NUM]   =                            d2r_data [3+BRANCH_NUM];
//==============================================================================================
// memory address map LOGICAL->PHY
//==============================================================================================
shell_mem_map
#(
  .DIRECTION("LOG2PHY")
)
mem_map_log2phy
(
.clk            (clk),
.rst            (rst),   

.i_sof          (d2r_sof  [4+BRANCH_NUM]),
.i_ctrl         (d2r_ctrl [4+BRANCH_NUM]),
.i_data         (d2r_data [4+BRANCH_NUM]),   
              
.o_sof          (d2r_sof  [5+BRANCH_NUM]),
.o_ctrl         (d2r_ctrl [5+BRANCH_NUM]),
.o_data         (d2r_data [5+BRANCH_NUM])
);                
//..............................................................................................
assign           r2d_sof  [5+BRANCH_NUM] =                              r2d_sof  [4+BRANCH_NUM];
assign           r2d_data [5+BRANCH_NUM] =                              r2d_data [4+BRANCH_NUM];
//==============================================================================================
// mutex manager                                                                            
//==============================================================================================
wire           mux_inj_ff_err; 
begin : MUTEX

    wire           to_mux_stb;
    wire           to_mux_sof;
    wire   [71:0]  to_mux_data;
    wire    [1:0]  to_mux_af;      
    
    wire           from_mux_stb;
    wire           from_mux_sof;
    wire   [71:0]  from_mux_data;
    wire    [1:0]  from_mux_af; 
                                  
  
    rbus_d2r_extractor       
    #(                                    
    .SPACE_CHECKING      ("ON"),       
    .SPACE_START_ADDRESS (`MEM_SP_MUTEX_START_PHY),
    .SPACE_LAST_ADDRESS  (`MEM_SP_MUTEX_START_PHY + `MEM_SP_MUTEX_LEN - 'd1)
    )
    d2r_extractor
    (
    .clk            (clk),
    .rst            (rst), 
                                          
    .d2r_i_sof      (d2r_sof  [5+BRANCH_NUM]),
    .d2r_i_ctrl     (d2r_ctrl [5+BRANCH_NUM]),
    .d2r_i_data     (d2r_data [5+BRANCH_NUM]),
                                          
    .d2r_o_sof      (d2r_sof  [6+BRANCH_NUM]),
    .d2r_o_ctrl     (d2r_ctrl [6+BRANCH_NUM]),
    .d2r_o_data     (d2r_data [6+BRANCH_NUM]),
    
    .o_stb          (to_mux_stb),
    .o_sof          (to_mux_sof),
    .o_data         (to_mux_data),
    .o_af           (to_mux_af)   
    );

    shell_muxmgr muxmgr
    (
    .clk            (clk),
    .rst            (rst), 
  
    .i_stb          (to_mux_stb),
    .i_sof          (to_mux_sof),
    .i_data         (to_mux_data),
    .i_af           (to_mux_af),
    
    .o_stb          (from_mux_stb),
    .o_sof          (from_mux_sof),
    .o_data         (from_mux_data),
    .o_af           (from_mux_af)
    ); 

    rbus_r2d_injector r2d_injector
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   

    .i_stb          (from_mux_stb),
    .i_sof          (from_mux_sof),
    .i_data         (from_mux_data),
    .i_af           (from_mux_af),
    
    .r2d_i_sof      (r2d_sof [5+BRANCH_NUM]),
    .r2d_i_data     (r2d_data[5+BRANCH_NUM]),
                                                     
    .r2d_o_sof      (r2d_sof [6+BRANCH_NUM]),
    .r2d_o_data     (r2d_data[6+BRANCH_NUM]), 
    
    .ff_err         (mux_inj_ff_err)
    );                                
end                                                                                 
//==============================================================================================
// system reflector
//============================================================================================== 
wire           ref_inj_ff_err;
begin : REFLECTOR

    wire           to_ref_stb;
    wire           to_ref_sof;
    wire   [71:0]  to_ref_data;
    wire    [1:0]  to_ref_af;      
    
    wire           from_ref_stb;
    wire           from_ref_sof;
    wire   [71:0]  from_ref_data;
    wire    [1:0]  from_ref_af;     
  
    rbus_d2r_extractor       
    #(                                     
    .SPACE_CHECKING      ("ON"),           
    .SPACE_START_ADDRESS (`MEM_SP_REFLECTOR_START_PHY),
    .SPACE_LAST_ADDRESS  (`MEM_SP_REFLECTOR_START_PHY + `MEM_SP_REFLECTOR_LEN - 'd1)
    )
    d2r_extractor
    (
    .clk            (clk),
    .rst            (rst), 
                                          
    .d2r_i_sof      (d2r_sof  [6+BRANCH_NUM]),
    .d2r_i_ctrl     (d2r_ctrl [6+BRANCH_NUM]),
    .d2r_i_data     (d2r_data [6+BRANCH_NUM]),
                                          
    .d2r_o_sof      (d2r_sof  [7+BRANCH_NUM]),
    .d2r_o_ctrl     (d2r_ctrl [7+BRANCH_NUM]),
    .d2r_o_data     (d2r_data [7+BRANCH_NUM]),
    
    .o_stb          (to_ref_stb),
    .o_sof          (to_ref_sof),
    .o_data         (to_ref_data),
    .o_af           (to_ref_af)   
    );
    
    shell_reflector
    #(                                           
    .PHY_ADDR   (39'h00_0010_0000)
    )
    sys_reflector
    (
    .clk            (clk),
    .rst            (rst),   

    // internal ring       
    .i_stb          (to_ref_stb),
    .i_sof          (to_ref_sof),
    .i_data         (to_ref_data),
    .i_af           (to_ref_af),

    .o_stb          (from_ref_stb),
    .o_sof          (from_ref_sof),
    .o_data         (from_ref_data),
    .o_af           (from_ref_af)
    );   

    rbus_r2d_injector r2d_injector
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   

    .i_stb          (from_ref_stb),
    .i_sof          (from_ref_sof),
    .i_data         (from_ref_data),
    .i_af           (from_ref_af), 
    
    .r2d_i_sof      (r2d_sof  [6+BRANCH_NUM]),
    .r2d_i_data     (r2d_data [6+BRANCH_NUM]),
                                                     
    .r2d_o_sof      (r2d_sof  [7+BRANCH_NUM]),
    .r2d_o_data     (r2d_data [7+BRANCH_NUM]), 
    
    .ff_err         (ref_inj_ff_err)
    );                                
end                                                                                 
//==============================================================================================
// bootrom 
//==============================================================================================   
wire           mem0_inj_ff_err;
begin : BOOTROM                    

    rbus_d2r_extractor       
    #(                                           
    .SPACE_CHECKING       ("ON"),            
    .SPACE_START_ADDRESS (`MEM_SP_BOOTROM_START_PHY),
    .SPACE_LAST_ADDRESS  (`MEM_SP_BOOTROM_START_PHY + `MEM_SP_BOOTROM_LEN - 'd1)
    )
    d2r_extractor
    (
    .clk            (clk),
    .rst            (rst), 
                                          
    .d2r_i_sof      (d2r_sof  [7+BRANCH_NUM]),
    .d2r_i_ctrl     (d2r_ctrl [7+BRANCH_NUM]),
    .d2r_i_data     (d2r_data [7+BRANCH_NUM]),
                                                        
    .d2r_o_sof      (d2r_sof  [8+BRANCH_NUM]),
    .d2r_o_ctrl     (d2r_ctrl [8+BRANCH_NUM]),
    .d2r_o_data     (d2r_data [8+BRANCH_NUM]),                  
    
    .o_stb          (mem0_o_stb),   
    .o_sof          (mem0_o_sof),   
    .o_data         (mem0_o_data),  
    .o_af           (mem0_o_af)     
    );              
    
    rbus_r2d_injector r2d_injector
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   

    .i_stb          (mem0_i_stb),
    .i_sof          (mem0_i_sof),
    .i_data         (mem0_i_data),
    .i_af           (mem0_i_af),  
    
    .r2d_i_sof      (r2d_sof  [7+BRANCH_NUM]),
    .r2d_i_data     (r2d_data [7+BRANCH_NUM]),
                                                     
    .r2d_o_sof      (r2d_sof  [8+BRANCH_NUM]),
    .r2d_o_data     (r2d_data [8+BRANCH_NUM]), 
    
    .ff_err         (mem0_inj_ff_err)
    );                                
end                                                                                 
//==============================================================================================
// mem interface
//==============================================================================================    
wire           mem1_inj_ff_err;
begin : MEMORY                      

    rbus_d2r_extractor       
    #(                                           
    .SPACE_CHECKING      ("ON"),            
    .SPACE_START_ADDRESS (`MEM_SP_KERNEL_START_PHY),
    .SPACE_LAST_ADDRESS  (`MEM_SP_USER_START_PHY + `MEM_SP_USER_LEN - 'd1)
    )
    d2r_extractor
    (
    .clk            (clk),
    .rst            (rst), 
                                          
    .d2r_i_sof      (d2r_sof  [8+BRANCH_NUM]),
    .d2r_i_ctrl     (d2r_ctrl [8+BRANCH_NUM]),
    .d2r_i_data     (d2r_data [8+BRANCH_NUM]),
                                                        
    .d2r_o_sof      (d2r_sof  [9+BRANCH_NUM]),
    .d2r_o_ctrl     (d2r_ctrl [9+BRANCH_NUM]),
    .d2r_o_data     (d2r_data [9+BRANCH_NUM]),                  
    
    .o_stb          (mem1_o_stb),   
    .o_sof          (mem1_o_sof),   
    .o_data         (mem1_o_data),  
    .o_af           (mem1_o_af)     
    );              
    
    rbus_r2d_injector r2d_injector
    (                                                                                                                               
    .clk            (clk),
    .rst            (rst),   

    .i_stb          (mem1_i_stb),
    .i_sof          (mem1_i_sof),
    .i_data         (mem1_i_data),
    .i_af           (mem1_i_af),  
    
    .r2d_i_sof      (r2d_sof  [8+BRANCH_NUM]),
    .r2d_i_data     (r2d_data [8+BRANCH_NUM]),
                                                     
    .r2d_o_sof      (r2d_sof  [9+BRANCH_NUM]),
    .r2d_o_data     (r2d_data [9+BRANCH_NUM]), 
    
    .ff_err         (mem1_inj_ff_err)
    );                                
end                                                                                 
//==============================================================================================
// mem interface
//==============================================================================================
wire devnull_active;                                                                           
//----------------------------------------------------------------------------------------------
shell_devnull
#(                                     
  .INSERT_DWORD  (64'hABBA_FACE_CAFE_BACA) 
)
DEVNULL
(
  .clk              (clk),       
  .rst              (rst),   

  // internal ring  
  .d2r_i_sof       (d2r_sof  [8+BRANCH_NUM]),
  .d2r_i_ctrl      (d2r_ctrl [8+BRANCH_NUM]),
  .d2r_i_data      (d2r_data [8+BRANCH_NUM]), 
  
  .d2r_o_sof       (d2r_sof  [0]),
  .d2r_o_ctrl      (d2r_ctrl [0]),
  .d2r_o_data      (d2r_data [0]),
   
  .r2d_i_sof       (r2d_sof  [8+BRANCH_NUM]),
  .r2d_i_data      (r2d_data [8+BRANCH_NUM]), 
    
  .r2d_o_sof       (r2d_sof  [0]),
  .r2d_o_data      (r2d_data [0]),

  .pkt_intercepted (devnull_active)
);                                                                                          
//============================================================================================== 
always @(posedge clk or posedge rst)                                                            
if(rst                     ) ff_ovr_err <=                                                 1'b0;                               
else if( d2r_mgr_ff_err    ) ff_ovr_err <=                                                 1'b1; 
else if( branch0_inj_ff_err) ff_ovr_err <=                                                 1'b1; // ff for data from branch 0
else if( branch1_inj_ff_err) ff_ovr_err <=                                                 1'b1; // ff for data from branch 1 
else if( mem0_inj_ff_err   ) ff_ovr_err <=                                                 1'b1; // ff for data from memory0  
else if( mem1_inj_ff_err   ) ff_ovr_err <=                                                 1'b1; // ff for data from memory1   
else if( ref_inj_ff_err    ) ff_ovr_err <=                                                 1'b1; // ff for data from reflector     
else                         ff_ovr_err <=                                           ff_ovr_err;
//---------------------------------------------------------------------------------------------- 
assign ff_err =                                                                      ff_ovr_err;
//==============================================================================================
assign dbg = {0
//       devnull_active, branch_0_d2r_af [1:0], 
       //mem1_o_af[1:0],        mem1_o_af[1:0]
       //to_ref_af [1:0],    from_ref_af [1:0],
//branch_1_d2r_af [1:0], branch_1_d2r_af [1:0]
};
//==============================================================================================

endmodule            