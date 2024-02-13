//=============================================================================================
//    Main contributors
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//      - Jakub Siast        
//=============================================================================================
`default_nettype none
//---------------------------------------------------------------------------------------------
`timescale 1ns / 1ns                            
//=============================================================================================
module rsbus_d2r_injector
#(                                                        
parameter   [3:0]   BASE_ID  =                  4'd0, // 
parameter   [3:0]   LAST_ID  =                  4'd0, //
parameter           DBG_MSG  =                  1'b0
)
(                                                                                                                               
input  wire         clk,
input  wire         rst,   

input  wire         frm_i_stb,                                 
input  wire  [3:0]  frm_i_iid,
input  wire         frm_i_sof,
input  wire [71:0]  frm_i_bus,
output wire  [1:0]  frm_i_rdy, 
output wire  [1:0]  frm_i_rdyE, 

input  wire         i_sof,
input  wire [11:0]  i_ctrl,
input  wire [71:0]  i_bus,
                                                          
output wire         o_sof,                                                                
output wire [11:0]  o_ctrl,                                                               
output wire [71:0]  o_bus, 

output reg          ff_err
);      
//=============================================================================================
// parameters
//=============================================================================================   
// pragma translate_off
initial
    begin
        if({1'b0, BASE_ID} > {1'b0, LAST_ID}) 
            begin
              $display( "!!!ERROR!!! rbus_d2r_injector. BASE_ID (%d) lower than LAST_ID (%d)", BASE_ID, LAST_ID ); 
              $finish;
            end
    end
// pragma translate_on 
//=============================================================================================
// variables
//============================================================================================= 
reg             bus_rdy; 
//---------------------------------------------------------------------------------------------       
reg             w0_stb;
reg             w0_sof;
reg             w0_sofS;
reg             w0_sofL;
reg      [5:0]  w0_xpa;
reg      [5:0]  w0_mm_setS;
reg      [3:0]  w0_lid;
reg     [71:0]  w0_bus;		 
reg      [7:0]  w0_sr_long;
reg      [7:0]  w0_sr_short;
//---------------------------------------------------------------------------------------------       
reg             w1_mm_we;
reg      [5:0]  w1_mm_addr;
reg      [5:0]  w1_mm_setS;
reg      [4:0]  w1_mm_setL;
reg             w1_req_stb;
reg      [3:0]  w1_req_rid;
reg      [1:0]  w1_req_pp;
reg      [3:0]  w1_req_lid;
reg             w1_req_len;
reg             w1_sof;
reg     [71:0]  w1_bus;
//---------------------------------------------------------------------------------------------
reg      [5:0]  mm_spa;
reg      [4:0]  mm_lpa;
`ifdef ALTERA
reg     [71:0]  mm_buff [0:56]/* synthesis syn_ramstyle="no_rw_check,MLAB" */;  
reg     [71:0]  mm_buff_outX;      
`else
reg     [71:0]  mm_buff [0:56]/* synthesis syn_ramstyle="select_ram,no_rw_check" */;          
`endif                                       
//---------------------------------------------------------------------------------------------
reg             r0_sof;
reg     [71:0]  r0_bus;
reg     [11:0]  r0_ctrl;
reg      [5:0]  r0_mm_addr;
reg      [5:0]  r0_mm_addrX;
//---------------------------------------------------------------------------------------------       
reg     [71:0]  r1_mm_bus;
reg             r1_sof;
reg     [71:0]  r1_bus;
reg     [11:0]  r1_ctrl;	  
reg             r1_insert_ena;	
reg             r1_insert_clr;	
reg             r1_insert_req;
//---------------------------------------------------------------------------------------------
reg      [5:0]  r2_mm_clrS;
reg      [4:0]  r2_mm_clrL;
reg             r2_sof;
reg     [71:0]  r2_bus;
reg     [11:0]  r2_ctrl;	  
reg             r2_free_long;
reg             r2_free_short;
//---------------------------------------------------------------------------------------------               
wire            req_stb; 
wire            req_len; 
wire     [1:0]  req_pp;  
wire     [3:0]  req_lid;            																					
wire     [3:0]  req_rid;            																					 
//---------------------------------------------------------------------------------------------
wire     [3:0]  ff_errs;
reg      [1:0]  ff_errs_r;
//=============================================================================================
// rbus initialization wait
//============================================================================================= 
always@(posedge clk or posedge rst)
if(rst)         bus_rdy      <=                                                           1'b0;
else            bus_rdy      <=                                               bus_rdy || i_sof;
//=============================================================================================
// input 
//=============================================================================================
// stage w0
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
wire     f_insert_long  =                                frm_i_bus[39] & frm_i_stb & frm_i_sof;
wire     f_insert_short =                               !frm_i_bus[39] & frm_i_stb & frm_i_sof;
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
 if(rst)
  begin
   w0_stb               <=                                                                 'd0;   
   w0_lid               <=                                                                 'd0;   
   w0_sof               <=                                                                 'd0;   
   w0_sofL              <=                                                                 'd0;  
   w0_sofS              <=                                                                 'd0;  
   w0_mm_setS           <=                                                                 'b0;    
   w0_bus[71:68]        <=                                                                 'd0;
   
   w0_sr_long           <=                                                        8'b1111_1111;
   w0_sr_short          <=                                                        8'b1111_1111;
  end                                                                                        
 else
  begin
   w0_stb               <=                                                           frm_i_stb; 
   w0_lid               <=                                                           frm_i_iid; 
   w0_sof               <=                                                           frm_i_sof;  
   w0_sofL              <=                              frm_i_stb & frm_i_sof &  frm_i_bus[39];  
   w0_sofS              <=                              frm_i_stb & frm_i_sof & !frm_i_bus[39]; 
   w0_xpa               <=   (frm_i_bus[39])?                          {1'b1, mm_lpa} : mm_spa;   
   w0_bus[71:68]        <=                                                    frm_i_bus[71:68];
   
   w0_sr_long           <= ( f_insert_long  &  !r2_free_long) ?         {w0_sr_long[6:0],1'b0}:
                           (!f_insert_long  &   r2_free_long) ?         {1'b1,w0_sr_long[7:1]}:
                                                                              w0_sr_long[7:0] ; 
   
   w0_sr_short          <= ( f_insert_short & !r2_free_short) ?        {w0_sr_short[6:0],1'b0}:
                           (!f_insert_short &  r2_free_short) ?        {1'b1,w0_sr_short[7:1]}:
                                                                             w0_sr_short[7:0] ; 
   if(frm_i_stb & frm_i_sof & !frm_i_bus[39])
    begin
          if(~mm_spa[0])w0_mm_setS    <=                                              'b000001;  // slot 0  
     else if(~mm_spa[1])w0_mm_setS    <=                                              'b000010;  // slot 1  
     else if(~mm_spa[2])w0_mm_setS    <=                                              'b000100;  // slot 2  
     else if(~mm_spa[3])w0_mm_setS    <=                                              'b001000;  // slot 3  
     else if(~mm_spa[4])w0_mm_setS    <=                                              'b010000;  // slot 4  
     else if(~mm_spa[5])w0_mm_setS    <=                                              'b100000;  // slot 5  
     else               w0_mm_setS    <=                                              'b000000; 
    end  
   else                 w0_mm_setS    <=                                              'b000000;   

  end
//--------------------------------------------------------------------------------------------- 
always@(posedge clk) 
  begin                                                                                         
   w0_bus[67: 0]        <=                                                    frm_i_bus[67: 0]; 
  end
//--------------------------------------------------------------------------------------------- 
assign    frm_i_rdy[1]       =                                                  w0_sr_long [3];
assign    frm_i_rdy[0]       =                                                  w0_sr_short[3];
//--------------------------------------------------------------------------------------------- 
assign    frm_i_rdyE[1]      =                                                  w0_sr_long [4];
assign    frm_i_rdyE[0]      =                                                  w0_sr_short[5];
//--------------------------------------------------------------------------------------------- 
assign    ff_errs[3]         =                                                 !w0_sr_long [5];
assign    ff_errs[2]         =                                                 !w0_sr_short[6];
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// stage w1																								   																	   
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++	 
wire [3:0] _W_LID_       =                                                 ~(BASE_ID + w0_lid);
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
 if(rst)
  begin
   w1_mm_we             <=                                                                 'b0;   
   w1_mm_addr           <=                                                                 'b0;   
   w1_mm_setS           <=                                                                 'b0;   
   w1_mm_setL           <=                                                                 'b0;   
   
   w1_req_stb           <=                                                                 'b0;   
   w1_req_len           <=                                                                 'b0;   
   w1_req_pp            <=                                                                 'b0;   
   w1_req_rid           <=                                                                 'b0;
   w1_req_lid           <=                                                                 'b0;
   w1_sof               <=                                                                 'b0;   
   w1_bus[71:68]        <=                                                                 'd0;
  end                                                                                        
 else
  begin
   w1_mm_we             <=                                                              w0_stb;   
   
   if(w0_sofS)//w0_sof && w0_stb && !w0_bus[39])
    begin
          if(~w0_xpa[0])w1_mm_setS    <=                                              'b000001;  // slot 0  
     else if(~w0_xpa[1])w1_mm_setS    <=                                              'b000010;  // slot 1  
     else if(~w0_xpa[2])w1_mm_setS    <=                                              'b000100;  // slot 2  
     else if(~w0_xpa[3])w1_mm_setS    <=                                              'b001000;  // slot 3  
     else if(~w0_xpa[4])w1_mm_setS    <=                                              'b010000;  // slot 4  
     else if(~w0_xpa[5])w1_mm_setS    <=                                              'b100000;  // slot 5  
     else               w1_mm_setS    <=                                              'b000000; 
    end  
   else                 w1_mm_setS    <=                                              'b000000;   

   if(w0_sofL)//w0_sof && w0_stb && w0_bus[39])
    begin
	        if(~w0_xpa[0])w1_mm_setL    <=                                               'b00001;  // slot 0 
     else if(~w0_xpa[1])w1_mm_setL    <=                                               'b00010;  // slot 1 
     else if(~w0_xpa[2])w1_mm_setL    <=                                               'b00100;  // slot 2 
     else if(~w0_xpa[3])w1_mm_setL    <=                                               'b01000;  // slot 3 
     else if(~w0_xpa[4])w1_mm_setL    <=                                               'b10000;  // slot 4 
     else               w1_mm_setL    <=                                               'b00000;   
    end
   else                 w1_mm_setL    <=                                               'b00000;   

   //if(w0_sofS)//w0_sof && w0_stb && !w0_bus[39])
	 //  casex(mm_spa)
   //    6'bxxxxx0:       w1_mm_addr    <=                                                  'd45;  // slot 0 -> addr 46
   //    6'bxxxx01:       w1_mm_addr    <=                                                  'd47;  // slot 1 -> addr 48
   //    6'bxxx011:       w1_mm_addr    <=                                                  'd49;  // slot 2 -> addr 50
   //    6'bxx0111:       w1_mm_addr    <=                                                  'd51;  // slot 3 -> addr 52                
   //    6'bx01111:       w1_mm_addr    <=                                                  'd53;  // slot 4 -> addr 54 (EVENT)
   //    6'b011111:       w1_mm_addr    <=                                                  'd55;  // slot 5 -> addr 56 (EVENT)
   //    default:         w1_mm_addr    <=                                                  'd00;   
	 //  endcase
   //else if(w0_sofL)//w0_sof && w0_stb && w0_bus[39])
	 //  casex(mm_lpa)
   //    5'bxxxx0:        w1_mm_addr    <=                                                  'd00;  // slot 0 -> addr 0
   //    5'bxxx01:        w1_mm_addr    <=                                                  'd09;  // slot 1 -> addr 9
   //    5'bxx011:        w1_mm_addr    <=                                                  'd18;  // slot 2 -> addr 18
   //    5'bx0111:        w1_mm_addr    <=                                                  'd27;  // slot 3 -> addr 27
   //    5'b01111:        w1_mm_addr    <=                                                  'd36;  // slot 4 -> addr 36 (EVENT)
   //    default:         w1_mm_addr    <=                                                  'd00;   
	 //  endcase
   //else/*if(w0_stb)*/   w1_mm_addr    <=                                      w1_mm_addr + 'd1;   
	 /*  
   casex({w0_sofS,w0_sofL,w0_xpa[4:0]})
     8'b1_x_xxxx0:              w1_mm_addr    <=                                        'd45;  // slot 0 -> addr 46
     8'b1_x_xxx01:              w1_mm_addr    <=                                        'd47;  // slot 1 -> addr 48
     8'b1_x_xx011:              w1_mm_addr    <=                                        'd49;  // slot 2 -> addr 50
     8'b1_x_x0111:              w1_mm_addr    <=                                        'd51;  // slot 3 -> addr 52                
     8'b1_x_01111:              w1_mm_addr    <=                                        'd53;  // slot 4 -> addr 54 (EVENT)
     8'b1_x_11111:              w1_mm_addr    <=                                        'd55;  // slot 5 -> addr 56 (EVENT)
     8'bx_1_xxxx0:              w1_mm_addr    <=                                        'd00;  // slot 0 -> addr 0
     8'bx_1_xxx01:              w1_mm_addr    <=                                        'd09;  // slot 1 -> addr 9
     8'bx_1_xx011:              w1_mm_addr    <=                                        'd18;  // slot 2 -> addr 18
     8'bx_1_x0111:              w1_mm_addr    <=                                        'd27;  // slot 3 -> addr 27
     8'bx_1_01111:              w1_mm_addr    <=                                        'd36;  // slot 4 -> addr 36 (EVENT)
     default:                   w1_mm_addr    <=                            w1_mm_addr + 'd1;   
   endcase*/
   
        if(  w0_sofS==1'b1 /*&&  w0_sofL == 1'b0*/ && !w0_xpa[0]) w1_mm_addr    <=             'd45;  // slot 0 -> addr 46
   else if(  w0_sofS==1'b1 /*&&  w0_sofL == 1'b0*/ && !w0_xpa[1]) w1_mm_addr    <=             'd47;  // slot 1 -> addr 48
   else if(  w0_sofS==1'b1 /*&&  w0_sofL == 1'b0*/ && !w0_xpa[2]) w1_mm_addr    <=             'd49;  // slot 2 -> addr 50
   else if(  w0_sofS==1'b1 /*&&  w0_sofL == 1'b0*/ && !w0_xpa[3]) w1_mm_addr    <=             'd51;  // slot 3 -> addr 52        
   else if(  w0_sofS==1'b1 /*&&  w0_sofL == 1'b0*/ && !w0_xpa[4]) w1_mm_addr    <=             'd53;  // slot 4 -> addr 54 (EVENT)
   else if(  w0_sofS==1'b1 /*&&  w0_sofL == 1'b0*/              ) w1_mm_addr    <=             'd55;  // slot 5 -> addr 56 (EVENT)
   else if(/*w0_sofS==1'b0  &&*/ w0_sofL == 1'b1   && !w0_xpa[0]) w1_mm_addr    <=             'd00;  // slot 0 -> addr 0
   else if(/*w0_sofS==1'b0  &&*/ w0_sofL == 1'b1   && !w0_xpa[1]) w1_mm_addr    <=             'd09;  // slot 1 -> addr 9
   else if(/*w0_sofS==1'b0  &&*/ w0_sofL == 1'b1   && !w0_xpa[2]) w1_mm_addr    <=             'd18;  // slot 2 -> addr 18
   else if(/*w0_sofS==1'b0  &&*/ w0_sofL == 1'b1   && !w0_xpa[3]) w1_mm_addr    <=             'd27;  // slot 3 -> addr 27
   else if(/*w0_sofS==1'b0  &&*/ w0_sofL == 1'b1                ) w1_mm_addr    <=             'd36;  // slot 4 -> addr 36 (EVENT)
   else                                                           w1_mm_addr    <= w1_mm_addr + 'd1;   
 
	  /* 
   if(w0_sofS)//w0_sof && !w0_bus[39])
	   casex(w0_xpa)
       6'bxxxxx0:       w1_req_rid    <=                                                   'h0;  // slot 0 
       6'bxxxx01:       w1_req_rid    <=                                                   'h1;  // slot 1 
       6'bxxx011:       w1_req_rid    <=                                                   'h2;  // slot 2  
       6'bxx0111:       w1_req_rid    <=                                                   'h3;  // slot 3 
       6'bx01111:       w1_req_rid    <=                                                   'h4;  // slot 4  
       6'b011111:       w1_req_rid    <=                                                   'h5;  // slot 5  
       default:         w1_req_rid    <=                                                   'hF;   
	   endcase																										 
   else if(w0_sofL)//w0_sof && w0_bus[39])
	   casex(w0_xpa)
       6'bxxxxx0:       w1_req_rid    <=                                                   'h8;  // slot 0 
       6'bxxxx01:       w1_req_rid    <=                                                   'h9;  // slot 1 
       6'bxxx011:       w1_req_rid    <=                                                   'hA;  // slot 2 
       6'bxx0111:       w1_req_rid    <=                                                   'hB;  // slot 3 
       6'bx01111:       w1_req_rid    <=                                                   'hC;  // slot 4 
       default:         w1_req_rid    <=                                                   'hF;   
	   endcase	*/

        if(  w0_sofS==1'b1 /*&&  w0_sofL == 1'b0*/ && !w0_xpa[0]) w1_req_rid    <=           'h0;  // slot 0 
   else if(  w0_sofS==1'b1 /*&&  w0_sofL == 1'b0*/ && !w0_xpa[1]) w1_req_rid    <=           'h1;  // slot 1 
   else if(  w0_sofS==1'b1 /*&&  w0_sofL == 1'b0*/ && !w0_xpa[2]) w1_req_rid    <=           'h2;  // slot 2 
   else if(  w0_sofS==1'b1 /*&&  w0_sofL == 1'b0*/ && !w0_xpa[3]) w1_req_rid    <=           'h3;  // slot 3 
   else if(  w0_sofS==1'b1 /*&&  w0_sofL == 1'b0*/ && !w0_xpa[4]) w1_req_rid    <=           'h4;  // slot 4 
   else if(  w0_sofS==1'b1 /*&&  w0_sofL == 1'b0*/              ) w1_req_rid    <=           'h5;  // slot 5 
   else if(/*w0_sofS==1'b0  &&*/ w0_sofL == 1'b1   && !w0_xpa[0]) w1_req_rid    <=           'h8;  // slot 0 
   else if(/*w0_sofS==1'b0  &&*/ w0_sofL == 1'b1   && !w0_xpa[1]) w1_req_rid    <=           'h9;  // slot 1 
   else if(/*w0_sofS==1'b0  &&*/ w0_sofL == 1'b1   && !w0_xpa[2]) w1_req_rid    <=           'hA;  // slot 2 
   else if(/*w0_sofS==1'b0  &&*/ w0_sofL == 1'b1   && !w0_xpa[3]) w1_req_rid    <=           'hB;  // slot 3 
   else if(/*w0_sofS==1'b0  &&*/ w0_sofL == 1'b1                ) w1_req_rid    <=           'hC;  // slot 4 
   else                                                           w1_req_rid    <=           'hF;  
 

   w1_req_stb           <=                                                    w0_stb && w0_sof;   
   w1_req_len           <=                                                          w0_bus[39];   
   w1_req_pp            <=                                                       w0_bus[69:68];   
   w1_req_lid           <=                                                             _W_LID_; 
	   																									 																					 
   w1_sof               <=                                                              w0_sof; 
   w1_bus[71:68]        <=                                                       w0_bus[71:68];   
  end
//--------------------------------------------------------------------------------------------- 
always@(posedge clk) 
  begin                                                                                         
   w1_bus[47: 0]        <=                                                       w0_bus[47: 0]; 
   w1_bus[67:48]        <=                                                       w0_bus[67:48]; 	  
  end
//=============================================================================================
// buffer flags
//============================================================================================= 
// short packet availability
//--------------------------------------------------------------------------------------------- 			 		 
always@(posedge clk or posedge rst) 
 if(rst)                mm_spa[0]   <=                                                     1'd0; 
 else if(r2_mm_clrS[0]) mm_spa[0]   <=                                                     1'd0;
 else if(w0_mm_setS[0]) mm_spa[0]   <=                                                     1'd1;				
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst) 
 if(rst)                mm_spa[1]   <=                                                     1'd0; 
 else if(r2_mm_clrS[1]) mm_spa[1]   <=                                                     1'd0;					   
 else if(w0_mm_setS[1]) mm_spa[1]   <=                                                     1'd1;				
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst) 
 if(rst)                mm_spa[2]   <=                                                     1'd0; 
 else if(r2_mm_clrS[2]) mm_spa[2]   <=                                                     1'd0;					   
 else if(w0_mm_setS[2]) mm_spa[2]   <=                                                     1'd1;				
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst) 
 if(rst)                mm_spa[3]   <=                                                     1'd0; 
 else if(r2_mm_clrS[3]) mm_spa[3]   <=                                                     1'd0;					   
 else if(w0_mm_setS[3]) mm_spa[3]   <=                                                     1'd1;				
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst) 
 if(rst)                mm_spa[4]   <=                                                     1'd0; 
 else if(r2_mm_clrS[4]) mm_spa[4]   <=                                                     1'd0;					   
 else if(w0_mm_setS[4]) mm_spa[4]   <=                                                     1'd1;				
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst) 
 if(rst)                mm_spa[5]   <=                                                     1'd0; 
 else if(r2_mm_clrS[5]) mm_spa[5]   <=                                                     1'd0;					   
 else if(w0_mm_setS[5]) mm_spa[5]   <=                                                     1'd1;				
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst) 
 if(rst)               ff_errs_r[1]<=                                                     1'd0; 
 else                  ff_errs_r[1]<=                !w0_bus[39] & (&mm_spa) & w0_sof & w0_stb;
//--------------------------------------------------------------------------------------------- 
// long packet availability
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst) 
 if(rst)                mm_lpa[0]  <=                                                     1'd0; 
 else if(r2_mm_clrL[0]) mm_lpa[0]  <=                                                     1'd0;
 else if(w1_mm_setL[0]) mm_lpa[0]  <=                                                     1'd1;
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst) 
 if(rst)                mm_lpa[1]  <=                                                     1'd0; 
 else if(r2_mm_clrL[1]) mm_lpa[1]  <=                                                     1'd0;
 else if(w1_mm_setL[1]) mm_lpa[1]  <=                                                     1'd1;
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst) 
 if(rst)                mm_lpa[2]  <=                                                     1'd0; 
 else if(r2_mm_clrL[2]) mm_lpa[2]  <=                                                     1'd0;
 else if(w1_mm_setL[2]) mm_lpa[2]  <=                                                     1'd1;
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst) 
 if(rst)                mm_lpa[3]  <=                                                     1'd0; 
 else if(r2_mm_clrL[3]) mm_lpa[3]  <=                                                     1'd0;
 else if(w1_mm_setL[3]) mm_lpa[3]  <=                                                     1'd1;
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst) 
 if(rst)                mm_lpa[4]  <=                                                     1'd0; 
 else if(r2_mm_clrL[4]) mm_lpa[4]  <=                                                     1'd0;
 else if(w1_mm_setL[4]) mm_lpa[4]  <=                                                     1'd1;
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst) 
 if(rst)               ff_errs_r[0]<=                                                     1'd0; 
 else                  ff_errs_r[0]<=                 w0_bus[39] & (&mm_lpa) & w0_sof & w0_stb;
//=============================================================================================
// buffer
//============================================================================================= 
// for packets																							  
//=============================================================================================			  
always@(posedge clk) 
 begin
  if(w1_mm_we) mm_buff[w1_mm_addr]  <=                                                  w1_bus;
    //if(w1_sof & w1_mm_we) $display("%d %m WR : %H",$time,w1_bus);
`ifdef ALTERA
       mm_buff_outX    <=                                                 mm_buff[r0_mm_addrX]; // https://tams.informatik.uni-hamburg.de/lehre/2015ws/projekt/mikrorechner/doc/quartusQPS-handbook.pdf str 791 (12sta w rozdziale)
`endif  
 end																						   
//---------------------------------------------------------------------------------------------
`ifndef ALTERA 		
wire [71:0] mm_buff_out              =                                     mm_buff[r0_mm_addr];	
`endif  														
//=============================================================================================
// for requests
//=============================================================================================
`ifdef NO_SHIFT_REGS
ff_dram_af_ack_d16 #(.WIDTH(11)) fifo_for_requests	
`else
ff_srl_af_ack_d16 #(.WIDTH(11)) fifo_for_requests	
`endif												  
(                     																			  
 .clk           (clk),                                             
 .rst           (rst),                                   											
 																									   
 .i_stb         (w1_req_stb),
 .i_data        ({w1_req_pp,w1_req_len,w1_req_lid,w1_req_rid}),
 .i_af          (),								
 .i_full        (),															   
 .i_err         (ff_errs[0]), 												   
 																				   
 .o_stb         (req_stb),
 .o_data        ({req_pp,req_len,req_lid,req_rid}),											 
 .o_ack         (r1_insert_req),  
 .o_ae          (),            
 .o_err         (ff_errs[1])
 ); 
//=============================================================================================
// main path 
//============================================================================================= 
// stage r0
//=============================================================================================
always@(posedge clk or posedge rst)																				 
 if(rst)																										
  begin
   r0_sof               <=                                                                 'b0;   
   r0_bus[71:68]        <=                                                                 'd0;
   
   r0_ctrl              <=                                                               12'b0;    
   
   r0_mm_addr           <=                                                                6'd0; 
  end                                                                                        
 else
  begin
   r0_sof               <=                                                               i_sof; 
   r0_bus[71:68]        <=                                                        i_bus[71:68];
   
   r0_ctrl              <=                                                              i_ctrl;    
   
   if(i_sof)
	   case(i_ctrl[3:0])
       4'h0:    r0_mm_addr            <=                                                  'd45; // slot 0 -> addr 46   
       4'h1:    r0_mm_addr            <=                                                  'd47; // slot 1 -> addr 48
       4'h2:    r0_mm_addr            <=                                                  'd49; // slot 2 -> addr 50  
       4'h3:    r0_mm_addr            <=                                                  'd51; // slot 3 -> addr 52
       4'h4:    r0_mm_addr            <=                                                  'd53; // slot 4 -> addr 54 (EVENT)
       4'h5:    r0_mm_addr            <=                                                  'd55; // slot 5 -> addr 56 (EVENT)
									                                                  
       4'h8:    r0_mm_addr            <=                                                  'd00; // slot 0 -> addr 0
       4'h9:    r0_mm_addr            <=                                                  'd09; // slot 1 -> addr 9   
       4'hA:    r0_mm_addr            <=                                                  'd18; // slot 2 -> addr 18     
       4'hB:    r0_mm_addr            <=                                                  'd27; // slot 3 -> addr 27   
       4'hC:    r0_mm_addr            <=                                                  'd36; // slot 4 -> addr 36 (EVENT) 
	   									                                                  
       default: r0_mm_addr            <=                                                  'd00;   
	   endcase
   else 	    r0_mm_addr            <=                                      r0_mm_addr + 'd1;
  end		
`ifdef ALTERA
always@(*)	
  begin
   if(i_sof)
	   case(i_ctrl[3:0])
       4'h0:    r0_mm_addrX           <=                                                  'd45; // slot 0 -> addr 46   
       4'h1:    r0_mm_addrX           <=                                                  'd47; // slot 1 -> addr 48
       4'h2:    r0_mm_addrX           <=                                                  'd49; // slot 2 -> addr 50  
       4'h3:    r0_mm_addrX           <=                                                  'd51; // slot 3 -> addr 52
       4'h4:    r0_mm_addrX           <=                                                  'd53; // slot 4 -> addr 54 (EVENT)
       4'h5:    r0_mm_addrX           <=                                                  'd55; // slot 5 -> addr 56 (EVENT)
									                                                  
       4'h8:    r0_mm_addrX           <=                                                  'd00; // slot 0 -> addr 0
       4'h9:    r0_mm_addrX           <=                                                  'd09; // slot 1 -> addr 9   
       4'hA:    r0_mm_addrX           <=                                                  'd18; // slot 2 -> addr 18     
       4'hB:    r0_mm_addrX           <=                                                  'd27; // slot 3 -> addr 27   
       4'hC:    r0_mm_addrX           <=                                                  'd36; // slot 4 -> addr 36 (EVENT) 
	   									                                                  
       default: r0_mm_addrX           <=                                                  'd00;   
	   endcase
   else 	    r0_mm_addrX           <=                                      r0_mm_addr + 'd1;
  end		
`endif  
//--------------------------------------------------------------------------------------------- 
always@(posedge clk) 																										
  begin                                                                                         
   r0_bus[67: 0]        <=                                                        i_bus[67: 0]; 							
  end
//=============================================================================================
// stage r1
//=============================================================================================	  
wire        f_lid_ok	 =            (~r0_ctrl[7:4] >= BASE_ID) && (~r0_ctrl[7:4] <= LAST_ID);
wire        f_frm_grant  =                                             f_lid_ok && r0_ctrl[11];			 
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)																  												
 if(rst)
  begin
   r1_sof               <=                                                                 'b0;   
   r1_bus[71:68]        <=                                                                 'd0;
   r1_ctrl              <=                                                               12'b0;    
  
`ifdef ALTERA
   r1_mm_bus[71:68]     <=                                                                4'b0;
//   r1_mm_bus[71: 0]     <=                                                                 'b0;
`else
   r1_mm_bus[71:68]     <=                                                                4'b0;
`endif  
   
   r1_insert_ena        <=                                                                1'b0;
   r1_insert_clr        <=                                                                1'b0;
   r1_insert_req        <=                                                                1'b0;
  end                                                                                        
 else
  begin
   r1_sof               <=                                                              r0_sof; 
   r1_bus[71:68]        <=                                                       r0_bus[71:68];
   r1_ctrl              <=                                                             r0_ctrl;    

`ifdef ALTERA
   r1_mm_bus[71:68]     <=                                                 mm_buff_outX[71:68];
//   r1_mm_bus[71: 0]     <=                                                 mm_buff_outX[71:0];
`else
   r1_mm_bus[71:68]     <=                                                  mm_buff_out[71:68];
`endif  
   
   r1_insert_ena        <= (r0_sof) ?                              f_frm_grant : r1_insert_ena;
   r1_insert_clr        <= (r0_sof) ?                              f_frm_grant :           'd0;
   r1_insert_req        <= (!r0_sof & !r0_ctrl[11] & !r1_insert_req & bus_rdy)? req_stb : 1'b0;    
  end
//--------------------------------------------------------------------------------------------- 
always@(posedge clk) 																										
  begin                                                                                         		
   r1_bus    [67: 0]    <=                                                       r0_bus[67: 0];
`ifdef ALTERA
   r1_mm_bus [67: 0]    <=                                                 mm_buff_outX[67: 0];
//   r1_mm_bus [71: 0]    <=                                                 mm_buff_outX[71: 0];
`else
   r1_mm_bus [67: 0]    <=                                                  mm_buff_out[67: 0];
`endif  
  end
//=============================================================================================
// stage r2
//=============================================================================================
wire [3:0] _R_LID_       =                                                        r1_ctrl[7:4];
//--------------------------------------------------------------------------------------------- 
always@(posedge clk or posedge rst)
 if(rst)
  begin
   r2_mm_clrS           <=                                                          6'b11_1111; 
   r2_mm_clrL           <=                                                           5'b1_1111; 
   r2_sof               <=                                                                1'b0;   
   r2_ctrl              <=                                                               12'd0;   
   r2_bus[71:68]        <=                                                                4'd0;
   r2_free_long         <=                                                                1'b0;   
   r2_free_short        <=                                                                1'b0;   
  end                                                                                        
 else
  begin                  
   if(r1_insert_ena && r1_sof && !r1_ctrl[3]) 
       case(r1_ctrl[2:0])
       3'h0:    r2_mm_clrS            <=                                              'b000001;  // slot 0  
       3'h1:    r2_mm_clrS            <=                                              'b000010;  // slot 1  
       3'h2:    r2_mm_clrS            <=                                              'b000100;  // slot 2  
       3'h3:    r2_mm_clrS            <=                                              'b001000;  // slot 3  
       3'h4:    r2_mm_clrS            <=                                              'b010000;  // slot 4  
       3'h5:    r2_mm_clrS            <=                                              'b100000;  // slot 5  
       default: r2_mm_clrS    <=                                                      'b000000;   
	   endcase	    
   else         r2_mm_clrS    <=                                                      'b000000;   					   
   
   if(r1_insert_ena && r1_sof && r1_ctrl[3]) 
       case(r1_ctrl[2:0])
       3'h0:    r2_mm_clrL            <=                                               'b00001;  // slot 0  
       3'h1:    r2_mm_clrL            <=                                               'b00010;  // slot 1  
       3'h2:    r2_mm_clrL            <=                                               'b00100;  // slot 2 
       3'h3:    r2_mm_clrL            <=                                               'b01000;  // slot 3  
       3'h4:    r2_mm_clrL            <=                                               'b10000;  // slot 4  
       default: r2_mm_clrL            <=                                               'b00000;   
	   endcase	    
   else         r2_mm_clrL            <=                                               'b00000;   					   
    
   r2_sof               <=                                                              r1_sof; 
   r2_ctrl              <= (r1_insert_req) ?             {1'b1,req_len,req_pp,req_lid,req_rid}: 
                           (r1_insert_clr) ?                                             12'd0: 
                                                                                       r1_ctrl;   
   r2_bus[71:68]        <= (r1_insert_ena && r1_sof) ? {r1_mm_bus[71], 1'b0, r1_mm_bus[69:68]}:
                           (r1_insert_ena          ) ?                        r1_mm_bus[71:68]: 
                                                                                 r1_bus[71:68];

																				   
   r2_free_long         <=                                       r1_mm_bus[39] & r1_insert_clr;   
   r2_free_short        <=                                      !r1_mm_bus[39] & r1_insert_clr;   

																				
 // if(r1_insert_ena && r1_sof) $display("%d %m RD : ------------------ %H",$time, {{r1_mm_bus[71], 1'b0, r1_mm_bus[69:68]},{r1_mm_bus[63:48],_R_LID_},r1_mm_bus[47: 0]});
                           
                           
  end
//--------------------------------------------------------------------------------------------- 
always@(posedge clk) 
  begin                                                                                         
   r2_bus[47: 0]        <= (r1_insert_ena) ?                  r1_mm_bus[47: 0] : r1_bus[47: 0]; 
   r2_bus[67:48]        <= (r1_insert_ena && r1_sof) ?              {r1_mm_bus[63:48],_R_LID_}:
                           (r1_insert_ena          ) ?                        r1_mm_bus[67:48]:
                                                                                 r1_bus[67:48]; 	  
  end 
//=============================================================================================	
// output
//=============================================================================================  
always@(posedge clk or posedge rst)
 if(rst)              ff_err           <=                                                 1'b0;                                                                                    
 else if(|ff_errs   ) ff_err           <=                                                 1'b1;                                                                                    
 else if(|ff_errs_r ) ff_err           <=                                                 1'b1;                                                                                    
 else                 ff_err           <=                                               ff_err;
//=============================================================================================   
assign  o_sof       =                                                                   r2_sof;
assign  o_ctrl      =                                                                  r2_ctrl;
assign  o_bus       =                                                                   r2_bus;
//=============================================================================================                      
endmodule