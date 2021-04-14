
module Interconnect (
   input  clk,
   output [31:0] read_config_data,
   input  reset,
   input [23:0] stall,

   input [31:0] config_0_config_addr,
   input [31:0] config_0_config_data,
   input [0:0] config_0_read,
   input [0:0] config_0_write,
   input [31:0] config_1_config_addr,
   input [31:0] config_1_config_data,
   input [0:0] config_1_read,
   input [0:0] config_1_write,
   input [31:0] config_2_config_addr,
   input [31:0] config_2_config_data,
   input [0:0] config_2_read,
   input [0:0] config_2_write,
   input [31:0] config_3_config_addr,
   input [31:0] config_3_config_data,
   input [0:0] config_3_read,
   input [0:0] config_3_write,
   input [31:0] config_4_config_addr,
   input [31:0] config_4_config_data,
   input [0:0] config_4_read,
   input [0:0] config_4_write,
   input [31:0] config_5_config_addr,
   input [31:0] config_5_config_data,
   input [0:0] config_5_read,
   input [0:0] config_5_write,
   input [31:0] config_6_config_addr,
   input [31:0] config_6_config_data,
   input [0:0] config_6_read,
   input [0:0] config_6_write,
   input [31:0] config_7_config_addr,
   input [31:0] config_7_config_data,
   input [0:0] config_7_read,
   input [0:0] config_7_write,
   input [31:0] config_8_config_addr,
   input [31:0] config_8_config_data,
   input [0:0] config_8_read,
   input [0:0] config_8_write,
   input [31:0] config_9_config_addr,
   input [31:0] config_9_config_data,
   input [0:0] config_9_read,
   input [0:0] config_9_write,
   input [31:0] config_10_config_addr,
   input [31:0] config_10_config_data,
   input [0:0] config_10_read,
   input [0:0] config_10_write,
   input [31:0] config_11_config_addr,
   input [31:0] config_11_config_data,
   input [0:0] config_11_read,
   input [0:0] config_11_write,
   input [31:0] config_12_config_addr,
   input [31:0] config_12_config_data,
   input [0:0] config_12_read,
   input [0:0] config_12_write,
   input [31:0] config_13_config_addr,
   input [31:0] config_13_config_data,
   input [0:0] config_13_read,
   input [0:0] config_13_write,
   input [31:0] config_14_config_addr,
   input [31:0] config_14_config_data,
   input [0:0] config_14_read,
   input [0:0] config_14_write,
   input [31:0] config_15_config_addr,
   input [31:0] config_15_config_data,
   input [0:0] config_15_read,
   input [0:0] config_15_write,
   input [31:0] config_16_config_addr,
   input [31:0] config_16_config_data,
   input [0:0] config_16_read,
   input [0:0] config_16_write,
   input [31:0] config_17_config_addr,
   input [31:0] config_17_config_data,
   input [0:0] config_17_read,
   input [0:0] config_17_write,
   input [31:0] config_18_config_addr,
   input [31:0] config_18_config_data,
   input [0:0] config_18_read,
   input [0:0] config_18_write,
   input [31:0] config_19_config_addr,
   input [31:0] config_19_config_data,
   input [0:0] config_19_read,
   input [0:0] config_19_write,
   input [31:0] config_20_config_addr,
   input [31:0] config_20_config_data,
   input [0:0] config_20_read,
   input [0:0] config_20_write,
   input [31:0] config_21_config_addr,
   input [31:0] config_21_config_data,
   input [0:0] config_21_read,
   input [0:0] config_21_write,
   input [31:0] config_22_config_addr,
   input [31:0] config_22_config_data,
   input [0:0] config_22_read,
   input [0:0] config_22_write,
   input [31:0] config_23_config_addr,
   input [31:0] config_23_config_data,
   input [0:0] config_23_read,
   input [0:0] config_23_write,
   input [0:0] glb2io_1_X00_Y00,
   output [0:0] io2glb_1_X00_Y00,
   input [15:0] glb2io_16_X00_Y00,
   output [15:0] io2glb_16_X00_Y00,
   input [0:0] glb2io_1_X01_Y00,
   output [0:0] io2glb_1_X01_Y00,
   input [15:0] glb2io_16_X01_Y00,
   output [15:0] io2glb_16_X01_Y00,
   input [0:0] glb2io_1_X02_Y00,
   output [0:0] io2glb_1_X02_Y00,
   input [15:0] glb2io_16_X02_Y00,
   output [15:0] io2glb_16_X02_Y00,
   input [0:0] glb2io_1_X03_Y00,
   output [0:0] io2glb_1_X03_Y00,
   input [15:0] glb2io_16_X03_Y00,
   output [15:0] io2glb_16_X03_Y00,
   input [0:0] glb2io_1_X04_Y00,
   output [0:0] io2glb_1_X04_Y00,
   input [15:0] glb2io_16_X04_Y00,
   output [15:0] io2glb_16_X04_Y00,
   input [0:0] glb2io_1_X05_Y00,
   output [0:0] io2glb_1_X05_Y00,
   input [15:0] glb2io_16_X05_Y00,
   output [15:0] io2glb_16_X05_Y00,
   input [0:0] glb2io_1_X06_Y00,
   output [0:0] io2glb_1_X06_Y00,
   input [15:0] glb2io_16_X06_Y00,
   output [15:0] io2glb_16_X06_Y00,
   input [0:0] glb2io_1_X07_Y00,
   output [0:0] io2glb_1_X07_Y00,
   input [15:0] glb2io_16_X07_Y00,
   output [15:0] io2glb_16_X07_Y00,
   input [0:0] glb2io_1_X08_Y00,
   output [0:0] io2glb_1_X08_Y00,
   input [15:0] glb2io_16_X08_Y00,
   output [15:0] io2glb_16_X08_Y00,
   input [0:0] glb2io_1_X09_Y00,
   output [0:0] io2glb_1_X09_Y00,
   input [15:0] glb2io_16_X09_Y00,
   output [15:0] io2glb_16_X09_Y00,
   input [0:0] glb2io_1_X0A_Y00,
   output [0:0] io2glb_1_X0A_Y00,
   input [15:0] glb2io_16_X0A_Y00,
   output [15:0] io2glb_16_X0A_Y00,
   input [0:0] glb2io_1_X0B_Y00,
   output [0:0] io2glb_1_X0B_Y00,
   input [15:0] glb2io_16_X0B_Y00,
   output [15:0] io2glb_16_X0B_Y00,
   input [0:0] glb2io_1_X0C_Y00,
   output [0:0] io2glb_1_X0C_Y00,
   input [15:0] glb2io_16_X0C_Y00,
   output [15:0] io2glb_16_X0C_Y00,
   input [0:0] glb2io_1_X0D_Y00,
   output [0:0] io2glb_1_X0D_Y00,
   input [15:0] glb2io_16_X0D_Y00,
   output [15:0] io2glb_16_X0D_Y00,
   input [0:0] glb2io_1_X0E_Y00,
   output [0:0] io2glb_1_X0E_Y00,
   input [15:0] glb2io_16_X0E_Y00,
   output [15:0] io2glb_16_X0E_Y00,
   input [0:0] glb2io_1_X0F_Y00,
   output [0:0] io2glb_1_X0F_Y00,
   input [15:0] glb2io_16_X0F_Y00,
   output [15:0] io2glb_16_X0F_Y00,
   input [0:0] glb2io_1_X10_Y00,
   output [0:0] io2glb_1_X10_Y00,
   input [15:0] glb2io_16_X10_Y00,
   output [15:0] io2glb_16_X10_Y00,
   input [0:0] glb2io_1_X11_Y00,
   output [0:0] io2glb_1_X11_Y00,
   input [15:0] glb2io_16_X11_Y00,
   output [15:0] io2glb_16_X11_Y00,
   input [0:0] glb2io_1_X12_Y00,
   output [0:0] io2glb_1_X12_Y00,
   input [15:0] glb2io_16_X12_Y00,
   output [15:0] io2glb_16_X12_Y00,
   input [0:0] glb2io_1_X13_Y00,
   output [0:0] io2glb_1_X13_Y00,
   input [15:0] glb2io_16_X13_Y00,
   output [15:0] io2glb_16_X13_Y00,
   input [0:0] glb2io_1_X14_Y00,
   output [0:0] io2glb_1_X14_Y00,
   input [15:0] glb2io_16_X14_Y00,
   output [15:0] io2glb_16_X14_Y00,
   input [0:0] glb2io_1_X15_Y00,
   output [0:0] io2glb_1_X15_Y00,
   input [15:0] glb2io_16_X15_Y00,
   output [15:0] io2glb_16_X15_Y00,
   input [0:0] glb2io_1_X16_Y00,
   output [0:0] io2glb_1_X16_Y00,
   input [15:0] glb2io_16_X16_Y00,
   output [15:0] io2glb_16_X16_Y00,
   input [0:0] glb2io_1_X17_Y00,
   output [0:0] io2glb_1_X17_Y00,
   input [15:0] glb2io_16_X17_Y00,
   output [15:0] io2glb_16_X17_Y00
);
endmodule
