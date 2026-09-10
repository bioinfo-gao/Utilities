# DEXSeq — 两个不报错的静默失败

## 1. 「0 个显著」可能是行名对不上，不是生物学结论

用 `DEXSeqResults` 之外的对象（如建表用的 `SummarizedExperiment`）按行名去取每个 bin 的
read 支持数时：

```r
# ❌ 错：DEXSeqResults 的行名是 ENSMUSG...:E001，与 se 的行名不是一套
res_df$bin_total <- rowSums(assay(se))[match(rownames(res_df), rownames(se))]
```

`match` 全不命中 ⇒ `bin_total` **整列 NA** ⇒ 任何 `bin_total >= X` 的过滤把**所有** bin 滤光
⇒ 报告"0 个显著"，**零报错、零警告**。

**实测**：P34 里 254,656 个受检 bin 实际有 **9,301 个 padj<0.05**，却输出 0。
之所以被抓到，只是因为 rMATS 在同一份数据上给出 1,031 个显著事件形成反差。

**修法**：计数本来就在结果表里，别去第二个对象取。

```r
cnt_cols <- grep("^countData\\.", names(res_df), value = TRUE)
res_df$bin_total <- as.integer(rowSums(res_df[, cnt_cols, drop = FALSE], na.rm = TRUE))
stopifnot(sum(is.na(res_df$bin_total)) == 0)   # 断言，不要靠肉眼
```

**判据**：任何"结果为 0 / 为空"的输出，先证明分母不是 NA，再当结论。

## 2. `write.table(as.data.frame(DEXSeqResults))` 必崩

```
Error in write.table(...) : unimplemented type 'list' in 'EncodeElement'
```

`DEXSeqResults` 含 list 列与 matrix 列（`countData`、`genomicData`、`transcripts`）。

**修法**：只导出原子列，并把被丢弃的列名打出来（避免"悄悄少了东西"）：

```r
atom <- vapply(df, function(x) is.atomic(x) && is.null(dim(x)), logical(1))
cat("丢弃的非原子列:", paste(names(df)[!atom], collapse=", "), "\n")
flat <- df[, atom, drop = FALSE]
```

**配套**：把 `saveRDS(dxd, ...)` 放在 `write.table` **之前** ——
P34 正因如此，导出崩溃时 190 MB 的 `dxd.rds` 完好，得以恢复而不必重跑最贵的
`summarizeOverlaps` + 检验两步。

## 相关

- 首次踩坑：P34（2026-09-09）
