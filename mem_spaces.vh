`ifndef __mem_spaces_vh 
`define __mem_spaces_vh 

//`ifdef MARS_AX3_256MB 
// Enclustra Mars AX3 module with Artix7 100T and 256MB DDR RAM 
`define   MEM_SP_DEVNULL_START_LOG     39'h00FE000000   
`define   MEM_SP_DEVNULL_START_PHY     39'h4000000000   
`define   MEM_SP_DEVNULL_LEN           39'h0001000000   
`define   MEM_SP_DEBUG_START_LOG       39'h00F3000000   
`define   MEM_SP_DEBUG_START_PHY       39'h0000300000   
`define   MEM_SP_DEBUG_LEN             39'h0000010000   
`define   MEM_SP_MUTEX_START_LOG       39'h00F2000000   
`define   MEM_SP_MUTEX_START_PHY       39'h0000200000   
`define   MEM_SP_MUTEX_LEN             39'h0000020000   
`define   MEM_SP_REFLECTOR_START_LOG   39'h00F1000000   
`define   MEM_SP_REFLECTOR_START_PHY   39'h0000100000   
`define   MEM_SP_REFLECTOR_LEN         39'h0000000700   
`define   MEM_SP_BOOTROM_START_LOG     39'h00F0000000   
`define   MEM_SP_BOOTROM_START_PHY     39'h0000000000   
`define   MEM_SP_BOOTROM_LEN           39'h0000100000   
`define   MEM_SP_KERNEL_START_LOG      39'h00C0000000   
`define   MEM_SP_KERNEL_START_PHY      39'h0000400000   
`define   MEM_SP_KERNEL_LEN            39'h0003C00000   
`define   MEM_SP_DEVICES_START_LOG     39'h0080000000   
`define   MEM_SP_DEVICES_START_PHY     39'h0004000000   
`define   MEM_SP_DEVICES_LEN           39'h0004000000   
`define   MEM_SP_GLOBAL_START_LOG      39'h0040000000   
`define   MEM_SP_GLOBAL_START_PHY      39'h0008000000   
`define   MEM_SP_GLOBAL_LEN            39'h0004000000   
`define   MEM_SP_USER_START_LOG        39'h0000000000   
`define   MEM_SP_USER_START_PHY        39'h000C000000   
`define   MEM_SP_USER_LEN              39'h0004000000   
//`endif //MARS_AX3_256MB 


`endif //__mem_spaces_vh
