# SoC 系统模块连接图 — AI 绘图提示词

> 生成一张 RISC-V SoC 系统架构框图。白色背景，专业技术风格。
> 模块用圆角矩形表示，连线用直角折线+箭头，信号名标注在线旁。
> 图中不要标题，不要集中文字块，所有信息通过模块标签和连线标注表达。

---

## 模块清单（共 9 个矩形方框）

| 模块 | 标签（大字） | 副标签（小字） | 填充色 | 大小 |
|------|------------|--------------|--------|------|
| CPU | `pipeline_top` | `5-Stage Pipeline CPU` | 浅橙 | 最大 |
| MIO_BUS | `MIO_BUS` | `Bus Controller / MMIO Decoder` | 浅紫 | 大 |
| imem | `imem` | `Instruction ROM 2048×32` | 浅绿 | 中 |
| dmem | `dmem` | `Data RAM 128×32` | 浅绿 | 中 |
| VGA | `vga_display` | `VGA 640×480 Char Terminal` | 浅青 | 大 |
| Keyboard | `ps2_keyboard` | `PS/2 Controller + FIFO` | 浅粉 | 中 |
| CLK_DIV | `CLK_DIV` | `Clock Divider` | 浅蓝 | 小 |
| MULTI_CH32 | `MULTI_CH32` | `Debug MUX 8-CH` | 浅灰 | 中 |
| SEG7x16 | `SEG7x16` | `7-Segment Driver` | 浅灰 | 小 |

---

## 布局（左→右五列）

```
列1(左)        列2              列3(中央)              列4             列5(右)
输入引脚       外设             核心                   外设             输出引脚

             ps2_keyboard                           vga_display      → VGA {r,g,b,hsync,vsync}
                 ↑                                      ↑
              CLK_DIV → MIO_BUS ←── pipeline_top ──→ imem
                         ↕  ↕         (CPU)            ↕
                        dmem ↕                       MULTI_CH32
                             ↕                           ↓
                          ps2_                       SEG7x16
                          keyboard                      ↓
                                                   → disp_seg_o, disp_an_o
```

具体坐标建议：

```
y=1  │ CLK_DIV       │                  │ imem                              │
y=2  │               │ ps2_keyboard     │                                   │ vga_display
y=3  │ sw_i[15:0]    │      ↕           │       pipeline_top (CPU)          │
y=4  │               │ MIO_BUS          │                                   │
y=5  │               │      ↕           │                                   │ MULTI_CH32
y=6  │               │ dmem             │                                   │
y=7  │               │                  │                                   │ SEG7x16
```

---

## 连线（45 条，严格来自代码）

### 时钟/复位（蓝色 / 红色）

```
clk(100MHz) ──→ CLK_DIV.clk                          [蓝色]
CLK_DIV.Clk_CPU ──→ CPU.clk                          [蓝色 粗] 标注 "cpu_clk"
CLK_DIV.Clk_CPU ──→ MIO_BUS.clk                      [蓝色]
CLK_DIV.Clk_CPU ──→ dmem.clk                         [蓝色]
clk(100MHz) ──→ ps2_keyboard.clk                      [蓝色]
clk(100MHz) ──→ MULTI_CH32.clk                       [蓝色]
clk(100MHz) ──→ SEG7x16.clk                          [蓝色]
clk ÷4 ──→ vga_display.vga_clk                       [蓝色] 标注 "vga_clk 25MHz"
clk(100MHz) ──→ vga_display.cpu_clk                   [蓝色]
~rstn ──→ 全部模块 .reset                             [红色] 标注 "reset"
```

### 取指通路（深绿色 粗线）

```
CPU.instr_addr[12:2] ──────→ imem.a[10:0]            [深绿 粗] 标注 "instr_addr"
imem.spo[31:0] ─────────────→ CPU.instr[31:0]         [深绿 粗] 标注 "instr"
```

### CPU ↔ MIO_BUS 数据总线（橙色 粗线）

```
CPU.bus_write_enable ─────→ MIO_BUS.bus_write_enable  [橙色]
CPU.bus_read_enable ──────→ MIO_BUS.bus_read_enable   [橙色]
CPU.bus_write_addr[31:0] ─→ MIO_BUS.bus_write_addr    [橙色 粗] 标注 "addr"
CPU.bus_write_data[31:0] ─→ MIO_BUS.bus_write_data    [橙色 粗] 标注 "wdata"
CPU.bus_DM_Type[2:0] ────→ MIO_BUS.bus_DM_Type        [橙色]
MIO_BUS.bus_read_data ────→ CPU.bus_read_data[31:0]   [橙色 粗] 标注 "rdata"
```

### MIO_BUS ↔ dmem（深紫色）

```
MIO_BUS.DM_write_enable ──→ dmem.DM_write_enable      [深紫]
MIO_BUS.DM_write_addr ────→ dmem.addr                 [深紫 粗]
MIO_BUS.DM_write_data ────→ dmem.din                  [深紫 粗]
MIO_BUS.DM_Type ──────────→ dmem.DM_Type              [深紫]
dmem.dout ─────────────────→ MIO_BUS.DM_read_data     [深紫 粗]
```

### MIO_BUS ↔ ps2_keyboard（粉色）

```
MIO_BUS.key_read_acknowledge → ps2_keyboard.key_read_acknowledge  [粉色]
ps2_keyboard.key_code[7:0] ──→ MIO_BUS.key_code      [粉色] 标注 "经2级同步器"
ps2_keyboard.key_ready ──────→ MIO_BUS.key_ready      [粉色] 标注 "经2级同步器"
```

### 键盘中断 → CPU（红色 粗线）

```
MIO_BUS.key_interrupt ────→ CPU.ext_interrupt         [红色 粗] 标注 "key_int = ready & en"
```

### MIO_BUS ↔ vga_display（青色）

```
MIO_BUS.vga_write_enable ─→ vga_display.vga_write_enable  [青色]
MIO_BUS.vga_write_addr ───→ vga_display.vga_write_addr    [青色]
MIO_BUS.vga_write_data ───→ vga_display.vga_write_data    [青色] 标注 "ASCII"
MIO_BUS.vga_read_addr ────→ vga_display.vga_read_addr     [青色]
vga_display.vga_read_data ─→ MIO_BUS.vga_read_data        [青色]
```

### VGA 输出（黑色）

```
vga_display ──→ FPGA引脚: vga_r[3:0], vga_g[3:0], vga_b[3:0], vga_hsync, vga_vsync  [黑色]
```

### MIO_BUS → 数码管调试通路（灰色）

```
MIO_BUS.cpuseg7_data ────→ MULTI_CH32.Data0          [灰色]
MIO_BUS.seg7_write_enable → MULTI_CH32.EN            [灰色]
```

### 调试信号接入 MULTI_CH32（灰色 虚线）

```
sw_i[10:6] ──→ CPU.reg_sel                           [灰色 虚线] 标注 "reg_sel"
CPU.reg_data ──→ MULTI_CH32.reg_data                  [灰色 虚线] 标注 "reg_data"
sw_i[5:0] ──→ MULTI_CH32.ctrl                        [灰色 虚线] 标注 "ctrl"
CPU.instr_addr ──→ MULTI_CH32.data2                   [灰色 虚线] 标注 "PC"
{2'b0,PC[31:2]} ──→ MULTI_CH32.data1                  [灰色 虚线]
imem.spo ──→ MULTI_CH32.data3                         [灰色 虚线] 标注 "instr"
CPU.bus_write_addr ──→ MULTI_CH32.data4               [灰色 虚线]
CPU.bus_write_data ──→ MULTI_CH32.data5               [灰色 虚线]
dmem.dout ──→ MULTI_CH32.data6                        [灰色 虚线]
MIO_BUS.DM_write_addr ──→ MULTI_CH32.data7            [灰色 虚线]
```

### MULTI_CH32 → SEG7x16 → 输出（灰色）

```
MULTI_CH32.seg7_data[31:0] ──→ SEG7x16.i_data        [灰色]
SEG7x16 ──→ FPGA引脚: disp_seg_o[7:0], disp_an_o[7:0]  [黑色]
```

### 外部输入（黑色）

```
FPGA引脚 ──→ ps2_keyboard: ps2_clk, ps2_data          [黑色]
FPGA引脚 sw_i[15:0] ──→ 分发到各模块                  [黑色]
```

---

## MMIO 地址映射（图右下角小表格，浅黄背景）

```
┌──────────────┬─────────────────┐
│ Address      │ Device          │
├──────────────┼─────────────────┤
│ FFFF_0004    │ Switches (R)    │
│ FFFF_000C    │ 7-Segment (W)   │
│ FFFF_0010    │ Keyboard Data(R)│
│ FFFF_0014    │ Keyboard Stat(R)│
│ FFFF_0018    │ KBD Int En (W)  │
│ FFFF_0020~   │ VGA Char Mem    │
│   ~FFFF_257C │ 2400B (R/W)     │
│ Other        │ Data RAM (R/W)  │
└──────────────┴─────────────────┘
```

---

## 图例（图左下角，浅黄背景）

```
┌──────────────────────────┐
│ Legend                    │
├──────────────────────────┤
│ ── Blue    Clock          │
│ ── Red     Reset/Interrupt│
│ ── Green   Instruction    │
│ ── Orange  Data Bus       │
│ ── Purple  Data Memory    │
│ ── Pink    Keyboard       │
│ ── Cyan    VGA            │
│ ─- Gray    Debug          │
│ Thick = 32-bit bus        │
│ Thin  = control (1-bit)   │
└──────────────────────────┘
```
