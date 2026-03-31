import re

# 1. 读取你导出的原始文本文件
with open("raw.txt", "r", encoding="utf-8") as f:
    content = f.read()

# 2. 正则表达式提取所有十六进制数 (比如 00H, 18H)
# 它会过滤掉 DB, 逗号, 注释和空格
hex_values = re.findall(r'([0-9A-F]{2})H', content)

# 3. 保存为 Verilog 识别的 .mem 文件
with open("font_data.mem", "w") as f:
    for val in hex_values:
        f.write(val + "\n")

print(f"清理完成！共提取 {len(hex_values)} 个字节，已存入 font_data.mem")