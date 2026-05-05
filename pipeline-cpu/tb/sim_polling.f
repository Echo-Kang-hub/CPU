+incdir+../rtl/include
+incdir+../rtl/core
+incdir+../rtl/utils
+incdir+../rtl/hazard
+incdir+../fpga

tb_polling_keyboard.v

// FPGA top (includes CLK_DIV, MIO_BUS, SEG7x16, imem, dmem,
//           pipeline_top, ps2_keyboard, vga_display via `include chain)
../fpga/xgriscv_fpga_top.v

// Instantiated but NOT included by xgriscv_fpga_top.v
../fpga/MULTI_CH32.v

// Utility modules (instantiated by pipeline stages, not included)
../rtl/utils/PC.v
../rtl/utils/NPC.v
../rtl/utils/ctrl.v
../rtl/utils/RF.v
../rtl/utils/EXT.v
../rtl/utils/alu.v

// Hazard modules (instantiated by EX_stage/ID_stage, not included)
../rtl/hazard/forwarding.v
../rtl/hazard/hazard_detect.v

// iverilog -o sim_polling.vvp -c sim_polling.f
// vvp sim_polling.vvp
