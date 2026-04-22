#!/bin/bash
# compile_keyboard_vga.sh
# 编译键盘VGA测试

echo "Compiling keyboard VGA test..."

# 设置路径
PROJECT_DIR="D:/FileDownload/Projects/CPU/pipeline-cpu"
cd "$PROJECT_DIR"

# 使用绝对路径编译
iverilog -o keyboard_vga_test.vvp \
    -I "$PROJECT_DIR/rtl/include" \
    -I "$PROJECT_DIR/rtl" \
    -I "$PROJECT_DIR/rtl/core" \
    -I "$PROJECT_DIR/rtl/utils" \
    -I "$PROJECT_DIR/rtl/hazard" \
    -I "$PROJECT_DIR/rtl/top" \
    -I "$PROJECT_DIR/fpga" \
    -D DMEM_INIT \
    "$PROJECT_DIR/tb/keyboard_vga_tb.v"

if [ $? -eq 0 ]; then
    echo "Compilation successful!"
    echo "Running simulation..."
    vvp keyboard_vga_test.vvp
else
    echo "Compilation failed!"
fi
