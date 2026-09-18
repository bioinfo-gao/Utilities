# Tangram —— `random_state=0` 等于没给种子，去卷积完全不可复现

实测版本：tangram-sc（`sc_tut_spatial` env，2026-09-17，proj37）。
**症状**：同一份输入、同一个 `random_state`、同一套参数，两次运行的 spot 级细胞类型比例
**最大差 0.29（绝对比例）**；下游"去卷积 vs marker 表达"的相关性随之漂移 0.007–0.017。
没有任何报错，两次的比例都通过"和为 1、无负值"的硬断言。

## 根因

`tangram/mapping_optimizer.py`（两个 Mapper 类各一处，约 76/165 与 257/389 行）：

```python
if self.random_state:                 # ← 0 是 falsy
    np.random.seed(seed=self.random_state)
...
if self.random_state:
    torch.manual_seed(seed=self.random_state)
```

`random_state=0` ⇒ 条件为假 ⇒ **播种整段被跳过**，训练用的是全局随机状态。
`0` 恰恰是最常见的"默认种子"写法。

**这是同一个家族的第二次**：decoupler 2.x 的 `_ridx` 也写成 `if seed:`，
`seed=0` 让 1000 次置换一次都不打乱（见 [decoupler.md](decoupler.md)）。
⇒ **看到 `seed`/`random_state` 参数，先去源码搜 `if ` 再决定给不给 0。**

## 修复

```python
RNG = 0              # 只用于参考分层下采样（与 RCTD 共用同一份下采样 ⇒ 必须保持不变）
TANGRAM_SEED = 42    # 非零

np.random.seed(TANGRAM_SEED)          # 不依赖库内部那个 if
torch.manual_seed(TANGRAM_SEED)
ad_map = tg.map_cells_to_space(..., device="cpu", random_state=TANGRAM_SEED)
```

CPU 上还要固定线程数（`torch.set_num_threads(8)`），否则归约顺序变化仍会带来末位差异。

⚠ **改种子时注意别把不该动的一起动了**：若同一个常量既做下采样种子又做训练种子，
换掉它会让"RCTD 与 Tangram 吃同一份参考"这个前提失效，两法差异就不再只来自算法。
proj37 的做法是**拆成两个常量**。

## 判据

1. **同参数跑两遍，`md5sum` 比产物**。这是唯一可靠的检测，代价通常只是一次重跑。
2. 库里搜 `if self.random_state:` / `if seed:` / `if not seed` 一类 falsy 判断。
3. 结果"看起来都合理、断言全过、但数字对不上上次"——这正是未播种，而不是数值噪声：
   浮点归约顺序带来的差异在 1e-6 量级，**0.29 的绝对比例差只可能是不同的随机初始化**。

## 另一条：Tangram 没有"参考细胞数不足"的护栏

同一批数据里 Adipocyte 在参考中只有 15 个细胞。RCTD（`CELL_MIN_INSTANCE=25`）**直接拒绝运行**；
Tangram 照常输出一列比例，而该列与自身 marker 表达的 Spearman **rho ≈ −0.02**。
⇒ 跑通 ≠ 可信；**必须配一个不经过该算法的独立证据**（如 marker 表达的空间相关性）。
