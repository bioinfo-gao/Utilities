# matplotlib 中文字体 —— 方框（tofu）与三个反直觉的判据

**一句话**：matplotlib 默认 `sans-serif` 是 **DejaVu Sans，不含任何 CJK 字形**，图里的中文全部
渲染成方框；它**不报错、不中断**，只在 stderr 留几行 `Glyph … missing from font(s)`，在 notebook
输出里极易被淹没，而**方框是渲染时就烤进 PNG/PDF 的**，事后无法补救，只能重跑。

实测环境：matplotlib **3.11.1**（env `sc_tut_main`），Ubuntu，2026-09-10。
本机可用中文字体：`Noto Sans CJK SC`（`/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc`）。

## 1. 修法（可直接抄）

```python
from matplotlib import font_manager
import matplotlib as mpl

_PREF = ("Noto Sans CJK SC", "Source Han Sans SC", "WenQuanYi Zen Hei", "Droid Sans Fallback")
_avail = {f.name for f in font_manager.fontManager.ttflist}
cjk = next((n for n in _PREF if n in _avail), None)
if cjk:
    mpl.rcParams["font.family"] = [cjk, "DejaVu Sans"]     # ← 逐字形回退靠这一行
    mpl.rcParams["font.sans-serif"] = [cjk] + [f for f in mpl.rcParams["font.sans-serif"] if f != cjk]
else:
    raise RuntimeError(f"本机无中文字体，图里中文会变方框；候选：{_PREF}")
```

**先探测再设置，不要硬编码字体名**；探测不到就**显式报错/告警**，别让它静默退化成方框。

## 2. 三个反直觉的点（都是实测，不是推测）

### 2.1 `font.sans-serif` 列表**不做**逐字形回退，`font.family` 才做

网上普遍把两者混为一谈。同一台机器、同一版本 mpl 3.11.1，渲染 `"中文 abc −1"`：

| 设置 | 缺字形告警 | 中文 |
| :--- | :---: | :---: |
| `font.family = ["DejaVu Sans", "Noto Sans CJK SC"]` | 0 | **正常** |
| `font.family = ["Noto Sans CJK SC", "DejaVu Sans"]` | 0 | **正常** |
| `font.sans-serif = ["DejaVu Sans", "Noto Sans CJK SC"]` | 2 | **方框** |
| `font.sans-serif = ["Noto Sans CJK SC", "DejaVu Sans"]` | 0 | **正常** |

- `font.family` 写成**具体字体名列表** ⇒ 真正的 per-glyph fallback，前面的字体缺哪个字形就落到后面。
- `font.sans-serif` 只是 `"sans-serif"` 这个**别名的解析顺序**：**第一个找得到的胜出，之后的一律不参与**。
  把中文字体排在第二位 = 完全无效，而且**告警只提第一个字体**（`missing from font(s) DejaVu Sans`），
  看告警会以为"没设上"，其实是设上了但机制不对。
- ⇒ 两处都设：`font.family` 拿回退，`font.sans-serif` 防某些库把 family 重置回 `"sans-serif"`。

### 2.2 缺字形告警走 **`warnings` 模块**，不走 matplotlib 的 logger

**这是一个会造出"恒为 0 的假通过检测器"的坑，我 2026-09-10 当场踩了一次：**

```python
# ❌ 抓不到任何东西 —— 无论字体对不对都打印 0，看起来像"验证通过"
logging.getLogger("matplotlib").addHandler(h)
...
print(len([m for m in rec if "missing from font" in m]))   # 恒为 0

# ✅ 正确通道
with warnings.catch_warnings(record=True) as w:
    warnings.simplefilter("always")
    fig.savefig(...)
n_missing = len([x for x in w if "missing from font" in str(x.message)])
assert n_missing == 0, f"仍有 {n_missing} 个字形缺失"
```

**判据：这个检测器必须先被证明能报出真阳性** —— 故意用纯 DejaVu 渲染一次中文，它应当报出
非零条数；报 0 说明抓错了通道，而不是字体没问题。（同类教训见
[dexseq.md](dexseq.md) 的"0 个显著"：先证明分母不是 NA。）

### 2.3 "系统装了" ≠ "matplotlib 看得到"

三层要分别验，任一层断掉症状完全一样：

| 层 | 检查命令 | 通过判据 |
| :--- | :--- | :---: |
| 系统 | `fc-list :lang=zh \| wc -l` | > 0 |
| matplotlib | `python -c "import matplotlib.font_manager as fm; print(sorted({f.name for f in fm.fontManager.ttflist} & {'Noto Sans CJK SC'}))"` | 非空 |
| 渲染 | 见 2.2 的 `catch_warnings` 断言 | `n_missing == 0` |

**新装字体后 matplotlib 仍看不到 ⇒ 字体缓存陈旧**，删掉再跑：

```bash
rm -rf "$(python -c 'import matplotlib; print(matplotlib.get_cachedir())')"
```

⚠ `.ttc` 是**字体集合**，`NotoSansCJK-Regular.ttc` 一个文件里有 SC/TC/JP/KR/HK 五个 face。
mpl 3.11.1 实测五个**全部**单独枚举得到，可以直接按 `"Noto Sans CJK SC"` 取。**务必写全 `SC`** ——
`JP`/`TC` 也含汉字、不报任何错，但字形是日文/繁体写法（骨、直、令 等差异肉眼可见）。

## 3. 不要抄的两条"标准做法"

| 网上常见写法 | 为什么别抄 |
| :--- | :--- |
| `plt.rcParams['font.sans-serif'] = ['SimHei']` | SimHei 是 Windows 字体，**Linux 服务器上没有**；找不到时 matplotlib 只 warn 然后**静默回退 DejaVu**，结果还是方框，却已经"设过字体了"，最难查 |
| `plt.rcParams['axes.unicode_minus'] = False` | 这条是给 SimHei 那类**缺 U+2212** 的字体擦屁股的，代价是负号退化成 hyphen。**Noto Sans CJK SC 实测含** U+2212(−)、U+221D(∝)、U+03BB(λ)、U+2014(—) ⇒ **不需要设**，设了反而降低排版质量 |

## 4. PDF 交付（图件只给 PDF 时）

`pdffonts` 实测，两种 `pdf.fonttype` **都能嵌入中文、都能 `pdftotext` 提取出中文**（可搜索）：

| `pdf.fonttype` | pdffonts 报告的类型 | 嵌入 | 备注 |
| :--- | :---: | :---: | :--- |
| 3（默认） | `Type 3` | yes(sub) | 部分期刊拒收 Type 3 |
| 42 | `CID Type 0C (OT)` | yes(sub) | poppler 会打印 `Mismatch between font type and embedded font file` **语法告警，但渲染与提取均正常**（已 `pdftoppm` 目视核对） |

⇒ 期刊要求非 Type 3 时设 `mpl.rcParams["pdf.fonttype"] = 42`，那两行 poppler 告警可以忽略。

## 5. 改完还是方框？先查内核有没有重新导入模块

**字体设置写在被 import 的共享模块里时，改文件对已经活着的 kernel 无效** ——
Python 把模块缓存在 `sys.modules`，`from x import setup` 在老内核里**不重新读盘**，
新代码一次都不会执行。症状与"根本没改"完全一致。

2026-09-10 proj22 实测（同一进程内三步模拟，`setup()` 里设字体）：

| 步骤 | 缺字形告警 | `font.family` |
| :--- | :---: | :---: |
| 内核早于改动启动，导入旧模块并 `setup()` | 8 | `['sans-serif']` |
| **磁盘文件已改好，只重跑 cell、不重启内核** | **8** | `['sans-serif']` |
| `importlib.reload(mod)` 后再 `setup()` | **0** | `['Noto Sans CJK SC', 'DejaVu Sans']` |

**补救**：重启 kernel 从头跑（最干净）；或在会话里

```python
import importlib, sc_tut_utils; importlib.reload(sc_tut_utils)
from sc_tut_utils import setup; setup(chapter="1-1")   # 然后重跑作图 cell
```

**判据（给人核对用）**：让 `setup()` 把选中的字体打进环境指纹（`中文字体 Noto Sans CJK SC`）。
**指纹里没有这一行 = 跑的是旧模块**，一眼可辨，不必去猜。

⚠ **对验证方式的教训**：修复方在**新进程**里验证会 100% 通过，而用户的**长活会话**照样是方框 ——
两边跑的根本不是同一份代码。**验证必须落在用户实际使用的那个会话里，或者至少交给用户一个
他自己能核对的判据**（上面那行指纹）。同类教训见 [[feedback_verify_every_number_against_source]]。

## 6. 踩坑记录

- **2026-09-10 · proj22（22_python_based_scRNA_tutorial）第 1 次**：24 章教程的共享
  `scripts/_common/sc_tut_utils.py::setup()` 设了 `savefig.*`、`axes.grid`，**唯独没设字体**，
  全部章节图内中文（标题/轴标签/注释）渲染成方框。修在 `setup()` 一处（SSOT，24 章一次生效），
  并在 `setup()` 的环境指纹里加打一行 `中文字体 <name>`，让状态每次运行都可见。
  同一轮里还连带踩了 2.1（回退机制搞反）、2.2（假通过检测器），以及 §5 —— 在新进程里验证通过并汇报“已修好”，
  而用户长活的 Positron 内核（早于改动 58 分钟启动）仍是方框，被当场指出“根本没改好”。
