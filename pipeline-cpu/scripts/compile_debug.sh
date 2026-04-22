#!/bin/bash
echo "Compiling debug test..."
cd D:/FileDownload/Projects/CPU/pipeline-cpu

iverilog -o keyboard_vga_debug.vvp \
    -y rtl/core \
    -y rtl/utils \
    -y rtl/hazard \
    -y rtl/top \
    -y fpga \
    -I rtl/include \
    -I rtl \
    -I rtl/core \
    -I rtl/utils \
    -I rtl/hazard \
    -I fpga \
    -D DMEM_INIT \
    tb/keyboard_vga_debug_tb.v

if [ $? -eq 0 ]; then
    echo "Running simulation..."
    vvp keyboard_vga_debug.vvp 2>&1 | head -100
else
    echo "Compilation failed!"
fi
