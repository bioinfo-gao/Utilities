# openpyxl / .xlsx —— `cell.value` 把 rich text 拍平，**颜色标注的答案会被整段读丢**

## 症状

用 openpyxl 读客户送来的 Excel 表（送样单 / 注册表 / 元数据表），
`ws.cell(...).value` 返回的字符串**看起来就是模板原文**，于是判定"客户什么都没填"。
**实际上客户填了 —— 他是把模板句子里适用的那个词染成红色来作答的。**

```
# 表单模板原文：Is this a paired-sample design? Answer Yes or No.
# 客户的作答方式：把句尾的 "No" 染成深红
# openpyxl 读到：'Is this a paired-sample design? Answer Yes or No.'  ← 与模板逐字相同
```

`cell.value` 只给拼接后的纯文本，**每个 run 的字体颜色/加粗全部丢失**，
而答案**只存在于颜色里**。零报错、零警告。

## 根因

`.xlsx` 里一个单元格的富文本存成 `sharedStrings.xml` 的多个 `<r>`（run），
每个 run 各带自己的 `<rPr><color rgb="..."/>`。openpyxl 默认（`rich_text=False`）
把这些 run 的 `<t>` 直接拼起来返回。

## 修复：直接解 XML，逐 run 读颜色

```python
import zipfile, xml.etree.ElementTree as ET
NS = '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
z = zipfile.ZipFile(path)
sis = list(ET.fromstring(z.read('xl/sharedStrings.xml')))
for rn in sis[idx].findall(NS+'r'):
    rpr = rn.find(NS+'rPr')
    color = rpr.find(NS+'color').attrib.get('rgb') if rpr is not None and rpr.find(NS+'color') is not None else ''
    text  = rn.find(NS+'t').text
```
（openpyxl ≥3.1 也可 `load_workbook(..., rich_text=True)`，但直接解 XML 更可控，
且能同时拿到下面这个"客户动过没有"的判据。）

## 附赠判据：**sharedStrings 的 si 索引能告诉你哪些单元格被客户编辑过**

模板作者写的字符串占据靠前的 si 索引；Excel 在单元格被编辑时会把新字符串**追加到表尾**。
所以 `si >= (模板原生 si 的最大值)` 的单元格 ≈ **客户动过的格子**。
proj31 实测：客户录入的样本名/试剂/体积落在 si 90–99，三处颜色作答落在 si 101–103，
模板原文全在 si 10–44 —— 一眼分清"客户答的"和"模板自带的"。

## 怎么分辨"客户的红"和"模板自带的红"

模板本身通常也用红字做强调（`*`、`(REQUIRED)`、`NO extra fee`）。判据是**具体色值不同**：
proj31 的模板用 `FFC9211E`（亮红）+ `FF0000EE`（蓝），
客户用的是 Excel 标准色盘的 **`FFC00000`（Dark Red）**，且**全文件仅出现在客户作答的 3 处**。
⇒ 先把全文件的颜色值统计一遍（`grep -o 'rgb="FF[0-9A-Fa-f]*"' xl/styles.xml` +
逐 run 扫描），再判定哪个色值是"客户的笔"。

## 通用教训

**送样单/注册表这类客户手填的表，永远不要只读 `cell.value` 就下"客户没填"的结论。**
客户会用高亮、字体颜色、删除线、批注、甚至只改单元格底色来作答 ——
这些在纯文本读取里全部不可见。至少要扫一遍：逐 run 字体颜色、单元格填充色、批注、
以及 si 索引反映的编辑痕迹。

事故：proj31（2026-08-21）初次解析客户表单，报告"8 个必填字段客户一个字都没填"，
用户肉眼打开 Excel 一看就说"客户把很多选项改成了红色的 No" —— 3 项已作答被完全读丢。

实现参考：`projects_2026M7/31_Yeji_Park_RPE1_CRISPR_dual_cut_wgs/scripts/1_inspect_registration_form.py`

关联：[[conda_run.md]]（同一轮里 `conda run python - <<EOF` 静默读不到 stdin，
使"没发现 rich text"这个错误结论被二次坐实）。
