❯ 在我手动运行 /home/gao/projects_2026H2/6_jinlong_mouse/scripts/5_run_enrichment.R 的时候，R console 出现： --- GSEA ---
    Ranked gene list: 13368 genes
  ℹ The package "ggridges" is required for `ridgeplot()`.
  ✖ Would you like to install it?

  1: Yes
  2: No

  Selection:
  1
  trying URL 'https://cran.rstudio.com/src/contrib/ggridges_0.5.7.tar.gz'
  Content type 'application/x-gzip' length 2210918 bytes (2.1 MB) ，以后，你应该自主安装，并把这个要求写入markdown 文件，永久记忆

明白，更新记忆为通用原则。

  Wrote 2 memories

已更新。原则现在是：任何脚本运行前，主动扫描所有依赖（R包、Python包、CLI工具），缺什么就安装什么，不等用户碰到报错。




❯ 永久记忆写在哪个文件？

两个位置：

1. 索引文件（每条一行）：
   /home/gao/.claude/projects/-home-gao-projects-2026H2/memory/MEMORY.md
2. 具体记忆文件（每条独立 .md）：
   /home/gao/.claude/projects/-home-gao-projects-2026H2/memory/

- feedback_background_job_followup.md
- feedback_client_report_style.md
- reference_de_r45_packages.md（刚才写的那条）
- 等等……

MEMORY.md 是索引，每次对话开始时会自动加载进我的 context，所以能跨会话记住。具体内容在各自的独立文件里，按需读取。
