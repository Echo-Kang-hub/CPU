# SoC 系统模块连接图 — AI 绘图提示词

生成一张硬件架构框图，图中不要写标题。

---

## 模块（共 9 个圆角矩形）

| 模块标签 | 实例名 | 颜色 | 附加标注 |
|---------|--------|------|---------|
| 五级流水线 CPU | U_CPU | 蓝色 | RV32I |
| 指令存储器 | U_IM | 灰色 | ROM 2048 words |
| 数据存储器 | U_DM | 蓝色 | RAM 128 words |
| MMIO 总线控制器 | U_MIO | 蓝色 | |
| PS/2 键盘控制器 | U_KBD | 绿色 | 8 级 FIFO |
| VGA 文本显示控制器 | U_VGA | 紫色 | 640×480 8×16字体 |
| 八通道显示选择器 | U_Multi | 绿色 | |
| 七段数码管驱动 | U_7SEG | 绿色 | |
| 时钟分频器 | U_CLKDIV | 绿色 | |

颜色说明：蓝色 = cpu_clk(~12.5MHz)，绿色 = clk(100MHz)，紫色 = 双时钟域，灰色 = 无时钟(纯组合)

---

## 布局

```
                    ┌─────────┐
                    │  U_IM   │
                    │ 指令ROM  │
                    └────┬────┘
                   instr │ instr_addr
          ┌──────────────┴──────────────┐
          │                             │
     ┌────┴────┐    cpu_clk    ┌────────┴────────┐
     │ U_CLKDIV│──────────────>│     U_CPU       │
     │ 分频器   │               │  五级流水线CPU    │
     └────┬────┘               └───┬─────────┬───┘
          │                        │         │
  clk(100M)                   bus信号    调试信号
          │                        │         │
          │               ┌────────┴───┐     │
          │               │   U_MIO    │     │
          │               │ MMIO总线    │     │
          │               └─┬───┬───┬──┘     │
          │            DM总线│   │   │VGA字符  │
          │                 │   │   │        │
     ┌────┴────┐       ┌───┴┐  │  ┌┴──────┐ │
     │  U_KBD  │       │U_DM│  │  │ U_VGA │ │
     │ PS/2键盘 │       │数据│  │  │ VGA   │ │
     └────┬────┘       │RAM │  │  └───┬───┘ │
          │            └────┘  │      │     │
    key_code                   │  VGA信号    │
    key_ready                  │      │     │
          │                    │      │     │
          └──>U_MIO            │      │     │
                                │      │     │
               ┌────────────────┘      │     │
               │                       │     │
          ┌────┴─────┐           ┌─────┴──┐  │
          │ U_Multi  │<──────────│        │  │
          │ 8通道选择 │  调试信号  │        │  │
          └────┬─────┘           │        │  │
               │seg7_data        │        │  │
          ┌────┴─────┐           │        │  │
          │ U_7SEG   │           │        │  │
          │ 七段驱动  │           │        │  │
          └──────────┘           │        │  │
                                  └────────┘  │
```

---

## 连线标注（信号名写在连线上）

| 起点 | 终点 | 信号 | 位宽 |
|------|------|------|------|
| U_CPU | U_IM | instr_addr | 32 bit（取 PC[12:2]） |
| U_IM | U_CPU | instr | 32 bit |
| U_CPU | U_MIO | bus_write_enable, bus_read_enable | 1+1 bit |
| U_CPU | U_MIO | bus_write_addr | 32 bit |
| U_CPU | U_MIO | bus_write_data | 32 bit |
| U_CPU | U_MIO | bus_DM_Type | 3 bit |
| U_MIO | U_CPU | bus_read_data | 32 bit |
| U_MIO | U_DM | DM_write_enable, DM_Type | 1+3 bit |
| U_MIO | U_DM | DM_write_addr | 32 bit |
| U_MIO | U_DM | DM_write_data | 32 bit |
| U_DM | U_MIO | DM_read_data | 32 bit |
| U_MIO | U_VGA | vga_write_enable | 1 bit |
| U_MIO | U_VGA | vga_write_addr | 13 bit |
| U_MIO | U_VGA | vga_write_data | 8 bit |
| U_VGA | U_MIO | vga_read_data | 8 bit |
| U_KBD | U_MIO | key_code, key_ready | 8+1 bit |
| U_MIO | U_KBD | key_read_acknowledge | 1 bit |
| U_MIO | U_CPU | key_interrupt | 1 bit |
| U_MIO | U_Multi | cpuseg7_data | 32 bit |
| U_MIO | U_Multi | seg7_write_enable | 1 bit |
| U_Multi | U_7SEG | seg7_data | 32 bit |
| U_CLKDIV | U_CPU,U_IM,U_DM,U_MIO | cpu_clk | 1 bit |
| 顶层 | U_VGA | vga_clk(25MHz) | 1 bit |

---

## 外部 I/O（图的边缘，用特殊形状如五边形或箭头）

| 方向 | 信号 | 连接到 |
|------|------|--------|
| 左侧输入 | clk(100MHz) | U_CLKDIV, U_KBD, U_Multi, U_7SEG |
| 左侧输入 | rstn | 所有模块（取反为 reset） |
| 左侧输入 | sw_i[15:0] | U_MIO, U_Multi |
| 右上输入 | ps2_clk, ps2_data | U_KBD |
| 右侧输出 | disp_seg_o[7:0], disp_an_o[7:0] | U_7SEG |
| 右下输出 | vga_r/g/b[3:0], vga_hsync, vga_vsync | U_VGA |

---

## 跨时钟域同步标注

在 U_KBD 和 U_MIO 之间的 key_code/key_ready 连线上，画两个串联的小方块（触发器），标注 "2-FF sync"，表示从 clk 域同步到 cpu_clk 域。

---

## 图例（右下角）

| 颜色 | 时钟域 | 频率 |
|------|--------|------|
| 蓝色 | cpu_clk | ~12.5 MHz |
| 绿色 | clk | 100 MHz |
| 紫色 | cpu_clk + vga_clk | 双时钟 |
| 灰色 | 无时钟 | 纯组合逻辑 |
