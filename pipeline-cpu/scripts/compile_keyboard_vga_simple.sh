#!/bin/bash
# compile_keyboard_vga_simple.sh
# 编译简化版键盘VGA测试

echo "Compiling simplified keyboard VGA test..."

# 设置路径
PROJECT_DIR="D:/FileDownload/Projects/CPU/pipeline-cpu"
cd "$PROJECT_DIR"

# 使用iverilog编译
iverilog -o keyboard_vga_simple.vvp \
    -y rtl/core \
    -y rtl/utils \
    -y rtl/hazard \
    -y fpga \
    -I rtl/include \
    -D DMEM_INIT \
    tb/keyboard_vga_simple_tb.v

if [ $? -eq 0 ]; then
    echo "Compilation successful!"
    echo "Running simulation..."
    vvp keyboard_vga_simple.vvp
else
    echo "Compilation failed!"
fi
