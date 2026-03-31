@echo off
REM 最小中断测试运行脚本 (使用 Icarus Verilog)

echo === Minimal Interrupt Test ===
echo Copying test program...
copy /Y inst.txt ..\..\inst.txt

echo Compiling...
cd ..\..

iverilog -o sim\interrupt_test\interrupt_minimal.vvp -f sim\interrupt_test\sim_simple.f

if errorlevel 1 (
    echo Compilation failed!
    pause
    exit /b 1
)

echo Running simulation...
vvp sim\interrupt_test\interrupt_minimal.vvp

echo.
echo Test completed.
pause
