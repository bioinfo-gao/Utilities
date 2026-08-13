# pysam —— `count_coverage()` 在病态高覆盖区永久挂起，无报错无进度

**症状**：一段普通的"取局部平均深度"代码，在绝大多数位点毫秒级返回，
但整个脚本会在某个位点**永久卡住**：不崩溃、不报错、不打日志、CPU 100% 在跑，
看上去像"在算大数据"。用 `timeout` 杀掉只得到退出码 124，没有任何线索。

**实测**（P29，2026-08-13，GRCh38 40× 人 WGS）：

| 位点 | 窗口 | 读段数 | 粗略深度 | `count_coverage` |
| :--- | :--- | ---: | ---: | :--- |
| `chr20:10,657,646-10,659,827` | 2.2 kb | 607 | 42× | **0.02 s** |
| `chr2:32,915,867-32,916,988` | 1.1 kb | **≥3,000,000** | **≥401,000×** | **>10 min，未返回** |

**根因**：`count_coverage()` 底层走 pileup 并**逐碱基构建 4 条（A/C/G/T）计数数组**，
代价随该区域的**读段总数**线性增长。人基因组里存在大量"比对黑洞"
（着丝粒旁、卫星重复、rDNA、segmental duplication），
这些位置的堆叠深度可以是全基因组中位深度的**四个数量级**。
一旦窗口落在这种区域，函数实际要处理数百万条读段，等于不返回。

**怎么定位**（关键：不要靠猜）：
```python
python -X faulthandler -c "
import faulthandler, runpy, sys
faulthandler.dump_traceback_later(45, exit=True)   # 45 秒后打印所有线程调用栈并退出
sys.argv = ['prog', ...]
runpy.run_path('your_script.py', run_name='__main__')
"
```
它会直接指出卡在哪个文件哪一行。本次就是靠这一条把范围从"整个脚本"缩到 `count_coverage` 那一行。
⚠ 排查时注意：**Python 重定向到文件时 stdout 是块缓冲的**，"没有输出"不等于"没跑到那里" ——
必须加 `-u` 或 `flush=True`，否则会误判卡住的位置。

**修复：换成有上界的 `fetch()`，别用 `count_coverage()`。**
```python
def local_cov(bam, chrom, lo, hi, mapq=20, cap=20_000):
    """平均深度；读满 cap 条就提前返回 inf。"""
    span, n, bases = hi - lo + 1, 0, 0
    for r in bam.fetch(chrom, lo - 1, hi):
        if r.is_unmapped or r.is_secondary or r.is_supplementary: continue
        if r.mapping_quality < mapq: continue
        n += 1
        bases += min(r.reference_end, hi) - max(r.reference_start + 1, lo) + 1
        if n >= cap:
            return float("inf")        # 已远超"覆盖充足"，无需继续
    return bases / span
```
**为什么返回 `inf` 是对的而不是偷懒**：这类函数通常只需要在**低端**精确
（判断"这里读段为零可不可信"）。深度高到离谱时结论必然是"覆盖充足"，
多读一条都是浪费。语义上界即算法上界。

**顺带一个白捡的收获**：`inf` 本身就是有用的信号。
把"局部覆盖度 > 中位深度 × 10"单独列为一类（比对黑洞），
可以把这类位点从候选整合位点里**机制性地**剔除 ——
P29 的 `chr2:32.9M` 原先只能凭"四个样本都有"推断是伪影，
拿到 401,000× 这个数字后就变成了直接证据。

**相关**：`fetch()` 本身不受影响（3,000,000 条读段仅 3 s），慢的只有逐碱基的 pileup 类接口
（`count_coverage`、`pileup`）。需要真正的逐碱基深度时用 `mosdepth`
（见 [mosdepth_vs_samtools_depth.md](mosdepth_vs_samtools_depth.md)），别用 pysam 硬算。
