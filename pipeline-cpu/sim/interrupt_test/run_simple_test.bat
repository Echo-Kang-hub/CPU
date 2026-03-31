@echo off
REM 简化中断测试运行脚本 (使用 Icarus Verilog)

echo === Simple Interrupt Test ===
echo Copying test program...
copy /Y inst.txt ..\..\inst.txt

echo Compiling...
cd ..\..

iverilog -o sim\interrupt_test\interrupt_simple.vvp ^
  -I rtl\include ^
  -I rtl\core ^
  -I rtl\utils ^
  -I rtl\hazard ^
  -I rtl\top ^
  rtl\core\*.v ^
  rtl\utils\*.v ^
  rtl\hazard\*.v ^
  rtl\top\soc_top.v ^
  sim\interrupt_test\interrupt_simple_tb.v

if errorlevel 1 (
    echo Compilation failed!
    pause
    exit /b 1
)

echo Running simulation...
vvp sim\interrupt_test\interrupt_simple.vvp

echo.
echo Test completed.
pause
