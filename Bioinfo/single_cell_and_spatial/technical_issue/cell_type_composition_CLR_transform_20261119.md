# 细胞类型组成分析：CLR 变换是什么、能解决什么、不能解决什么

> 2026-11-19 · 背景：差异丰度（differential abundance）分析建议"用 scCODA / sccomp / propeller，或至少做 CLR 变换后再检验"，本文解释 CLR。

## 结论

**CLR = centered log-ratio transformation（中心对数比变换）**，Aitchison 为成分数据（compositional data）提出的标准变换。把每个样本里各细胞类型的数量除以该样本所有类型的几何平均数，再取对数，就把"加起来必须等于 1"的比例拉回到普通欧氏空间，之后才能用 t-test、limma、线性模型这类检验。

**它不能还原绝对丰度。** 结论只能写成相对丰度变化。

## 为什么要做：比例数据的闭合问题

每个样本的细胞类型比例总和固定为 1，这叫闭合（closure）。只要有一个类型真的扩增，其余所有类型的比例都会被动下降。直接拿比例做 t-test / Wilcoxon，就会把这种被动下降误报成"显著减少"，类型之间也会出现虚假的负相关。

## 定义

样本 $s$ 有 $D$ 种细胞类型，计数为 $x_1,\dots,x_D$：

$$
\mathrm{clr}(x)_i = \ln\frac{x_i}{g(x)},\qquad g(x)=\Big(\prod_{j=1}^{D}x_j\Big)^{1/D}
$$

- 每个样本内部，各类型的 CLR 值相加等于 0，参照点是"该样本的平均细胞类型"。
- 计数里有 0 时 log 无定义，必须先加 pseudocount（常用 0.5 或 1），或者用乘性替换（multiplicative replacement）。
- 变换之后，对每种细胞类型按组做 t-test 或 limma，再做多重校正。

## 用数字看它能解决什么、不能解决什么

两个样本，只有 Mono 真的扩增了：

| 细胞类型 | 样本 A 计数 | 样本 B 计数 | A 比例 | B 比例 | A 的 CLR | B 的 CLR | ΔCLR |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| T | 50 | 50 | 0.50 | 0.25 | 0.476 | −0.122 | −0.60 |
| B | 30 | 30 | 0.30 | 0.15 | −0.035 | −0.632 | −0.60 |
| Mono | 20 | 120 | 0.20 | 0.60 | −0.441 | 0.754 | +1.19 |

几个关键点：

1. **CLR 也显示 T 和 B "下降"了。** CLR 不能还原绝对丰度，测序只给相对量，这个信息本来就丢了，任何纯成分方法都恢复不出来。
2. **CLR 带来的是统计上的合法性和可解释的结构。** 去掉了闭合约束，方差和协方差才有意义，常规检验的前提才成立。T 和 B 的 ΔCLR 完全相同，说明它们之间的比值 log(T/B) 没变。"一个类型变、其余同步平移"这种模式，就是在提示真正变化的可能只有 Mono。
3. **要明确说"Mono 扩增、T 和 B 不变"，必须加一条外部假设。** scCODA 的做法就是如此：指定一个参照类型（reference cell type），假设它不变，所有结论都相对于它。

## 和三个专用方法的关系

| 方法 | 核心做法 | 怎么处理成分问题 | 适用场景 |
| :--- | :---: | :---: | :---: |
| CLR + t-test/limma | 几何平均作参照，取 log 后做常规检验 | 相对于"平均类型"，不需要指定参照 | 最低门槛；样本数中等以上 |
| scCODA | Bayesian Dirichlet-multinomial | 指定参照类型，假设它不变 | 样本少（每组约 3）时更稳 |
| sccomp | Beta-binomial 模型，带离群点检测，同时建模均值和变异度 | 在模型内处理成分约束 | 有离群样本，或想检验"变异度"差异 |
| propeller（speckle） | 比例先做 logit 或 arcsin-sqrt 变换，再用 limma | 只做方差稳定，**不**真正解决闭合 | 快速、支持复杂设计；类型很多时闭合偏倚较小 |

## 最小实现（Python）

```python
import numpy as np, pandas as pd
from scipy.stats import ttest_ind
from statsmodels.stats.multitest import multipletests

# counts: 行=样本, 列=细胞类型（原始细胞数, 不是比例）
def clr(counts, pseudo=0.5):
    logx = np.log(counts + pseudo)
    return logx.sub(logx.mean(axis=1), axis=0)   # 减去 log 几何平均

z = clr(counts)
g = meta.loc[z.index, "group"]
p = [ttest_ind(z.loc[g=="Ctrl", c], z.loc[g=="Treat", c]).pvalue for c in z.columns]
res = pd.DataFrame({"dCLR": z[g=="Treat"].mean() - z[g=="Ctrl"].mean(),
                    "p": p, "padj": multipletests(p, method="fdr_bh")[1]})
```

## 实际使用时要注意的三点

- **观测单位是样本，不是细胞。** 每个 donor/样本一行，n 是样本数。把细胞当作重复单位去做 Fisher 检验，就是伪重复（pseudoreplication）。
- **结果对 pseudocount 敏感，稀有类型尤其如此。** pseudocount 0.5 和 1 各跑一遍，结论翻转的类型不要报。
- **报告措辞要写"相对丰度变化"（relative abundance shift）。** 不要写成"细胞数量增加或减少"，除非有绝对计数（例如 flow 计数或 spike-in）作佐证。
