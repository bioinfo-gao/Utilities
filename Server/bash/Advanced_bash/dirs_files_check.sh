cd /home/gao/Dropbox/Quote_02052601_lnc # 进入数据文件夹

# 显示所有文件夹的大小（人类可读） # du -sh C* ch_* 2>/dev/null | sort -h
# 包含数据文件夹 + Sequencing_QC dir 
du -sh C* ch_* Sequencing_QC 2>/dev/null | sort -h

# list 每个文件夹的文件列表和大小
sudo tree -h --du -P "*.fastq*|*.fq*|*.md5" C* ch_* 'Sequencing QC'

for dir in C* ch_*; do
    [ -d "$dir" ] || continue
    # 总大小
    # total=$(du -sh "$dir" 2>/dev/null | cut -f1)
    # # fastq 文件数
    # fcount=$(ls "$dir"/*.fq.gz 2>/dev/null | wc -l)
    # # 大于 1G 的文件数
    # large=$(find "$dir" -name "*.fq.gz" -size +1G 2>/dev/null | wc -l)
    # MD5 存在？
    md5=$(test -f "$dir/MD5.txt" && echo "✓" || echo "✗")
    printf "%-10s %8s %6s %6s %4s\n" "$dir" "$total" "$fcount" "$large" "$md5"
done

# 3. MD5 验证 # 10 seconds for each dir, total ~ 1-2 minutes
echo "=== MD5 验证 ==="
for dir in C* ch_*; do
    [ -f "$dir/MD5.txt" ] || continue #  MD5.txt here，but may be *.md5 in some other cases
    
    # 验证并统计
    result=$(cd "$dir" && md5sum -c MD5.txt 2>&1)u
    ok=$(echo "$result" | grep ": OK" | wc -l)
    fail=$(echo "$result" | grep "FAILED" | wc -l)
    
    if [ "$fail" -eq 0 ]; then
        echo "✓ $dir: $ok/$((ok+fail)) 通过"
    else
        echo "✗ $dir: $ok 通过, $fail 失败"
        echo "$result" | grep "FAILED" | head -3 | sed 's/^/    /'
    fi
done

=== MD5 验证 ===

✓ C1_A: 4/4 通过
✓ C1_B: 4/4 通过
✓ C1_C: 4/4 通过
.....
✓ ch_3D: 4/4 通过