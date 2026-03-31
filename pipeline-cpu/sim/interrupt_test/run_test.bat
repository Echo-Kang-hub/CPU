@echo off
REM 中断测试运行脚本
REM 需要将 inst.txt 复制到仿真运行目录

echo Copying test program...
copy /Y inst.txt ..\..\inst.txt

echo Running simulation with Vivado xsim...
cd ..\..\

REM 如果使用 Vivado，可以这样运行:
REM xvlog -sv rtl\include\definition.vh rtl\core\*.v rtl\utils\*.v rtl\hazard\*.v rtl\top\soc_top.v sim\interrupt_test\interrupt_test_tb.v
REM xelab interrupt_test_tb -s interrupt_test_sim
REM xsim interrupt_test_sim -runall

echo.
echo === Manual Run Instructions ===
echo 1. Copy inst.txt to project root (where you run simulation)
echo 2. In Vivado: Add sim/interrupt_test/interrupt_test_tb.v as simulation source
echo 3. Set interrupt_test_tb as top module
echo 4. Run simulation
echo.
echo Expected results:
echo   - mepc = address of instruction at interrupt time
echo   - mcause = 0x8000000B
echo   - mstatus[3]=0, mstatus[7]=1 after interrupt
echo   - mstatus[3]=1, mstatus[7]=1 after mret
echo   - PC = 0x100 during interrupt handler
echo   - t2 = 1 after handler runs
echo.
pause
