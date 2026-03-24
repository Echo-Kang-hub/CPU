+incdir+../rtl/include
+incdir+../rtl/core
+incdir+../rtl/top
+incdir+../rtl/utils
+incdir+../rtl/hazard
+incdir+../rtl/periph

soc_top_tb.v

../rtl/core/IF_stage.v
../rtl/core/ID_stage.v
../rtl/core/EX_stage.v
../rtl/core/MA_stage.v
../rtl/core/WB_stage.v
../rtl/core/pipeline_top.v
../rtl/core/csr.v
../rtl/core/interrupt_ctrl.v
../rtl/top/soc_top.v
../rtl/hazard/forwarding.v
../rtl/hazard/hazard_detect.v

../rtl/utils/PC.v
../rtl/utils/NPC.v
../rtl/utils/alu.v
../rtl/utils/RF.v
../rtl/utils/EXT.v
../rtl/utils/ctrl.v
../rtl/utils/dm.v
../rtl/utils/imem.v
../rtl/periph/ps2_ctrl.v

// iverilog -o sim.out -c sim.f
