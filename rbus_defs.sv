
`ifndef __rbus_defs_sv 
`define __rbus_defs_sv 		
//=============================================================================================
//    Main contributors
//      - Jakub Siast         <mailto:jakubsiast@gmail.com>
//      - Adam Luczak         <mailto:adam.luczak@outlook.com>
//=============================================================================================
`default_nettype none
//=============================================================================================
package rbus_pkg;	 

typedef enum bit [1:0]
{
 MEM_READ_1 	=2'b00, 
 MEM_READ_8 	=2'b01, 
 MEM_WRITE   	=2'b10, 
 MEM_UPDATE  	=2'b11 
} mem_op_t;

typedef enum bit [0:0]
{
 PHYSICAL 		= 1'b0, 
 VIRTUAL 		= 1'b1 
} mem_space_t;

typedef struct packed 
{
   bit 	   		 [3:0]  lid4;
   bit 	   		 [3:0]  lid3;
   bit 	   		 [3:0]  lid2;
   bit 	   		 [3:0]  lid1;
   bit 	   		 [3:0]  lid0;
} net_addr_t;

typedef struct packed 
{
   bit 		  			frm_used;
   bit 		  			frm_owned;
   bit 		  	 [1:0]  frm_priority;
   net_addr_t           net_addr;
   bit 	   		 [3:0]  frm_sid;
   bit 	   		 [3:0]  frm_rid;
   bit         			frm_len;
   bit 	   		[35:0]  mem_addr;
   mem_space_t	   		mem_space;
   mem_op_t  	     	mem_op;
} rbus_header_t;

typedef struct packed
{
   bit 			 [7:0]  ben;
   bit 			[63:0]  data;
} rbus_payload_t;
      
      
`ifdef WORK_AROUND_XILINX_UNIONS

    typedef struct packed
    {
      rbus_header_t header;
    } rbus_word_t;

`else

    typedef union packed
    {
      rbus_header_t header;
      rbus_payload_t payload;
      bit [71:0] raw;        
    } rbus_word_t;
`endif
          
typedef struct packed 
{
  bit 		  			valid;
  bit 		  			len;
  bit 	   		 [1:0]  pp;
  bit 	   		 [3:0]  did;
  bit 	   		 [3:0]  rid;
} rbus_ctrl_t;

endpackage

//-----------------------------------------------------------------------------------------------
`ifdef ACTIVE83_TABLES_BUG_FIX
  `define assignB72(out,in) \     
      assign out[ 0] = in[71]; \     
      assign out[ 1] = in[70]; \  
      assign out[ 2] = in[69]; \     
      assign out[ 3] = in[68]; \  
      assign out[ 4] = in[67]; \     
      assign out[ 5] = in[66]; \  
      assign out[ 6] = in[65]; \     
      assign out[ 7] = in[64]; \  
      assign out[ 8] = in[63]; \     
      assign out[ 9] = in[62]; \ 
      assign out[10] = in[61]; \     
      assign out[11] = in[60]; \  
      assign out[12] = in[59]; \     
      assign out[13] = in[58]; \  
      assign out[14] = in[57]; \     
      assign out[15] = in[56]; \  
      assign out[16] = in[55]; \     
      assign out[17] = in[54]; \  
      assign out[18] = in[53]; \     
      assign out[19] = in[52]; \ 
      assign out[20] = in[51]; \     
      assign out[21] = in[50]; \  
      assign out[22] = in[49]; \     
      assign out[23] = in[48]; \  
      assign out[24] = in[47]; \     
      assign out[25] = in[46]; \  
      assign out[26] = in[45]; \     
      assign out[27] = in[44]; \  
      assign out[28] = in[43]; \     
      assign out[29] = in[42]; \ 
      assign out[30] = in[41]; \     
      assign out[31] = in[40]; \  
      assign out[32] = in[39]; \     
      assign out[33] = in[38]; \  
      assign out[34] = in[37]; \     
      assign out[35] = in[36]; \  
      assign out[36] = in[35]; \     
      assign out[37] = in[34]; \  
      assign out[38] = in[33]; \     
      assign out[39] = in[32]; \ 
      assign out[40] = in[31]; \     
      assign out[41] = in[30]; \  
      assign out[42] = in[29]; \     
      assign out[43] = in[28]; \  
      assign out[44] = in[27]; \     
      assign out[45] = in[26]; \  
      assign out[46] = in[25]; \     
      assign out[47] = in[24]; \  
      assign out[48] = in[23]; \     
      assign out[49] = in[22]; \ 
      assign out[50] = in[21]; \     
      assign out[51] = in[20]; \  
      assign out[52] = in[19]; \     
      assign out[53] = in[18]; \  
      assign out[54] = in[17]; \     
      assign out[55] = in[16]; \  
      assign out[56] = in[15]; \     
      assign out[57] = in[14]; \  
      assign out[58] = in[13]; \     
      assign out[59] = in[12]; \ 
      assign out[60] = in[11]; \     
      assign out[61] = in[10]; \  
      assign out[62] = in[ 9]; \     
      assign out[63] = in[ 8]; \  
      assign out[64] = in[ 7]; \     
      assign out[65] = in[ 6]; \  
      assign out[66] = in[ 5]; \     
      assign out[67] = in[ 4]; \  
      assign out[68] = in[ 3]; \     
      assign out[69] = in[ 2]; \ 
      assign out[70] = in[ 1]; \     
      assign out[71] = in[ 0]; 
                               
  //-----------------------------------------------------------------------------------------------
  `define assignB2(out,in) \     
      assign out[1] = in[0]; \     
      assign out[0] = in[1];  
`else 
  `define assignB72(out,in) \
    assign out = in;
  //-----------------------------------------------------------------------------------------------
  `define assignB2(out,in) \
    assign out = in;
`endif
//------------------------------------------------------------------------------------------------- 
`endif //__rbus_defs_sv