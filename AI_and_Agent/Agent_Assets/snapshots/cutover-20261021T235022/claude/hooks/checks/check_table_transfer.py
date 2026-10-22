#!/usr/bin/env python3
"""判据：聊天里给过的表格,落盘成文档时有没有整行漏掉。

为什么需要它（2026-09-13 实测失败）：
    我在一轮回复里给了一张 8 行的对比表,用户说"写成文档",我下一轮写了文档 ——
    其中一行(空间大数据工程 / Xenium / VisiumHD 的惰性加载)**整行没进去**。
    文档本身格式全对、内容自洽,**看不出少了东西**,是用户自己发现的。
    这类缺失不报错、不违反任何格式判据,与「本来就没打算写」无法区分。

为什么是 Stop 而不是 PostToolUse：
    写文件的那一刻,「这张表是不是该进这个文件」还不好判;要等整轮结束、
    文件最终形态定了再比。而且表往往在**上一轮**回复里(用户看完表才说"写成文档"),
    所以回看窗口必须跨轮 —— 调用方负责给足文本,本模块只管比对。

**本模块只做分诊,不下判断 —— 这是实测逼出来的定性(2026-09-13)**：
    真实用例里,聊天行标是 `上游 QC / normalization / integration`,
    文档把它改写成中文并**拆成了两行**(`质控/归一化/聚类降维` + `批次整合`),
    那三个英文词在文档里出现 **0 次**。内容完整落盘了,词面零重叠。
    ⇒ 「这一行的内容到底进没进去」是**语义判断**,正则永远判不了。
    所以输出一律写成「**这几行没匹配上,请逐条确认**」,
    **绝不写成「缺失」,调用方也绝不能据此 block** —— 那会拦住正确的文档。

刻意不做的事：
    · 不判断内容对不对,只判断**词面上匹配不上哪几行**。
    · 表命中率 < REL 视为「这张表跟这个文件无关」,直接跳过 ——
      否则每次回复里随手一张汇总表都会报,警告会被无视。
"""
import difflib
import os
import re

REL = 0.6        # 命中率 ≥ 此值才认为「这张表确实是往这个文件搬的」
MIN_ROWS = 3     # 少于 3 行的表不查(太短,判不准)
FUZZ = 0.62      # 整行相似度兜底阈值(容忍改写措辞)

_SEP = re.compile(r"^\|(?:\s*:?-{3,}:?\s*\|)+\s*$")
_FENCE = re.compile(r"```.*?```", re.S)
_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")


def norm(s):
    """去掉 markdown 修饰与全部空白 —— 中文里空白不承载语义,留着只会造成假阴性。"""
    s = _LINK.sub(r"\1", s or "")
    s = re.sub(r"[`*_~]", "", s)
    return re.sub(r"\s+", "", s).strip()


def _tables(text):
    """抽出所有 markdown 表格的【数据行首列】。跳过代码块里的假表。"""
    text = _FENCE.sub("", text or "")
    lines = text.split("\n")
    out, i = [], 0
    while i < len(lines) - 1:
        if lines[i].lstrip().startswith("|") and _SEP.match(lines[i + 1].strip()):
            j, labels = i + 2, []
            while j < len(lines) and lines[j].lstrip().startswith("|"):
                cells = lines[j].strip().strip("|").split("|")
                if cells:
                    labels.append(cells[0])
                j += 1
            if labels:
                out.append(labels)
            i = j
        else:
            i += 1
    return out


def _usable(label):
    """✓ / — / 空白这类行标没有检索价值,留着会把命中率算歪。"""
    n = norm(label)
    if len(n) < 2:
        return None
    if not re.search(r"[一-鿿 A-Za-z0-9]", n):
        return None
    return n


def _present(label, blob, lines):
    n = norm(label)
    if n in blob:
        return True
    # 拉丁/数字专名(Xenium、VisiumHD、PyDESeq2…)最能证明这一行确实搬过去了
    for t in re.findall(r"[A-Za-z][A-Za-z0-9._+-]{2,}", label):
        if t.lower() in blob.lower():
            return True
    # 中文改写了措辞 ⇒ 用三字 gram 覆盖率兜底
    cjk = "".join(re.findall(r"[一-鿿]", n))
    if len(cjk) >= 3:
        grams = [cjk[k:k + 3] for k in range(len(cjk) - 2)]
        if sum(1 for g in grams if g in blob) / len(grams) >= 0.6:
            return True
    return max((difflib.SequenceMatcher(None, n, l).ratio() for l in lines),
               default=0.0) >= FUZZ


def run(said, md_paths):
    """said: 本轮+上一轮我说过的话(str 或 list)。md_paths: 本轮写过的 .md 路径。

    返回 list[str],每条描述一个「这张表有整行没落进这个文件」的发现。
    """
    if isinstance(said, (list, tuple)):
        said = "\n".join(t for t in said if t)
    paths = [p for p in (md_paths or [])
             if p and p.lower().endswith(".md") and os.path.isfile(p)]
    if not said or not paths:
        return []

    tables = [t for t in _tables(said) if len(t) >= MIN_ROWS]
    if not tables:
        return []

    findings = []
    for labels in tables:
        usable = [(raw, n) for raw in labels if (n := _usable(raw))]
        if len(usable) < MIN_ROWS:
            continue
        best = None
        for p in paths:
            try:
                txt = open(p, errors="replace").read()
            except Exception:
                continue
            blob = norm(txt)
            lines = [norm(l) for l in txt.split("\n") if l.strip()]
            missing = [raw.strip() for raw, _ in usable
                       if not _present(raw, blob, lines)]
            rate = 1 - len(missing) / len(usable)
            if rate >= REL and missing and (best is None or rate > best[0]):
                best = (rate, p, missing, len(usable))
        if best:
            _, p, missing, total = best
            got = total - len(missing)
            findings.append(
                f"表格落盘逐行确认：{os.path.basename(p)} 匹配上 {got}/{total} 行，"
                f"以下 {len(missing)} 行未匹配 → "
                + "；".join(f"「{m}」" for m in missing[:4])
                + ("…" if len(missing) > 4 else "")
                + "。**这不等于漏写** —— 改写措辞或拆并行都会匹配不上；"
                  "请逐条打开文件确认，漏了就补，是有意省略就在回复里说一句。")
    return findings


if __name__ == "__main__":
    import sys
    said = open(sys.argv[1], errors="replace").read()
    for f in run(said, sys.argv[2:]):
        print(f)
