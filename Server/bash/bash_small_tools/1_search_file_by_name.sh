# 查找本文件夹下所有 xlsx 文件，并保留路径信息
find "$(pwd)" -type f -name "*.xlsx" #  递归查找 + 完整路径
find . -type f -name "*.xlsx"        #  只要相对路径（有时更方便）
find "$(pwd)" -type f -name "*.xlsx" -exec ls -lh {} \; # （带文件大小/时间）
find "$(pwd)" -type f -iname "*.xlsx" > xlsx_list.txt   # 输出到文件（常用）


tree -P "*.xlsx" --prune # （只显示包含 xlsx 的目录）
# --prune 👉 隐藏没有 xlsx 的目录
# 输出更干净（强烈推荐）