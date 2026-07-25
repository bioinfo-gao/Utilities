# 这个目录是我一个月前的工作目录，
#/home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216 
# 我需要造出了我最终修改的文件和文件夹是哪几个，并按照时间排列，最新修改在前

# 由于这个目录可能包含大量 Nextflow 的中间缓存（如 work/ 目录），我们需要过滤掉那些杂讯，只看你真正关心的 脚本、配置文件和结果输出。

# 1. 查找最近修改的前 20 个文件/文件夹
# 请在终端执行以下命令。它会递归搜索所有文件，并按修改时间（Newest first）排列：
find /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216 -maxdepth 3 -not -path '*/.*' -printf '%TY-%Tm-%Td %TT %p\n' | sort -r | head -n 20
# -maxdepth 3: 限制搜索深度，避免陷入过深的子目录。
# -not -path '*/.*': 排除隐藏文件（如 .nextflow）。
# sort -r: 将最新的排在最前面。
2026-02-25 06:59:16.0133446380 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/scripts
2026-02-23 05:28:11.2642097900 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/Final_Report
2026-02-23 05:20:37.5724471110 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216
2026-02-23 05:17:48.3146728040 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/scripts/GZ_Mouse_Full_Annotation.R
2026-02-23 05:15:51.7876770380 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/Final_Report/Mouse_Full_Annotation.tsv
2026-02-23 05:15:32.8158992740 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/Mouse_Annotation.tsv
2026-02-23 05:11:05.7420610270 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/rubbish
2026-02-23 05:08:07.8640855310 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/scripts/lGZ_Mouse_Full_Annotation.R
2026-02-23 04:57:31.3006250080 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/rubbish/Mouse_Full_Genome_Annotation_GRCm39.tsv
2026-02-23 04:57:30.9446023480 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/scripts/Export_All_Mouse_Genes.R
2026-02-23 04:57:22.2560460340 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/rubbish/Mouse_Full_Genome_Annotation_GRCm39.csv
2026-02-23 04:52:30.5560049530 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/scripts/generate_mouse_anno.R
2026-02-23 04:48:12.1196255710 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/Final_Report/samples.merged.gene_fpkm.tsv
2026-02-23 04:48:09.9391384030 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/scripts/get_FPKM_final.R
2026-02-23 04:41:36.9671364770 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/scripts/get_fpkm.R
2026-02-23 04:02:28.0000000000 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/Final_Report/setting.xlsx
2026-02-23 03:41:36.2511666320 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/Final_Report/samplesheet_full.csv
2026-02-22 10:56:26.5748726090 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/scripts/DE_analysis_Refined.R
2026-02-22 09:32:41.0530707130 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/Final_Report/01.RawData
2026-02-22 09:28:55.6415234140 /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/01.fq/01.RawData

# 2. 排除 work 目录（精准定位你的修改）
# 如果你在一个月前运行过流程，work/ 文件夹里会有数万个自动生成的临时文件。为了找到你本人手动修改的脚本或最终生成的 output，请使用这个更精准的命令：

ls -ltR /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216 --exclude=work --exclude=.nextflow | head -n 25
# --exclude=work: 过滤掉 Nextflow 的缓存垃圾。
# -lt: 按修改时间排序（最新在前）。
# R: 递归显示。

songz:~/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/scripts$ ll -tr
总计 3152
-rw-rw-r--  1 songz songz    2734 Feb 23 05:17 GZ_Mouse_Full_Annotation.R
-rw-rw-r--  1 songz songz    2137 Feb 23 05:08 lGZ_Mouse_Full_Annotation.R
-rw-rw-r--  1 songz songz    1135 Feb 23 04:57 Export_All_Mouse_Genes.R
-rw-rw-r--  1 songz songz    1940 Feb 23 04:52 generate_mouse_anno.R
-rw-rw-r--  1 songz songz    2370 Feb 23 04:48 get_FPKM_final.R
-rw-rw-r--  1 songz songz    1715 Feb 23 04:41 get_fpkm.R
-rw-rw-r--  1 songz songz    4532 Feb 22 10:56 DE_analysis_Refined.R
-rw-rw-r--  1 songz songz    4052 Feb 22 09:14 DE_analysis_v3.R
-rw-rw-r--  1 songz songz    1978 Feb 22 08:47 DE_analysis_v2.R
-rw-rw-r--  1 songz songz    3338 Feb 22 08:37 DE_analysis.R
-rw-rw-r--  1 songz songz    1845 Feb 22 06:38 merge_counts.R
-rw-rw-r--  1 songz songz     517 Feb 22 05:36 final_16_cores.sh
-rw-rw-r--  1 songz songz     600 Feb 22 05:36 final_2_cores.sh
-rw-rw-r--  1 songz songz     880 Feb 21 08:14 All_9_samples.sh
-rw-rw-r--  1 songz songz     517 Feb 21 06:03 Untitled-1.sh
-rwxrwxr-x  1 songz songz     955 Feb 21 05:16 run_mamba_rnaseq.sh*
-rw-rw-r--  1 songz songz     960 Feb 21 05:16 run_mamba_rnaseq_full.sh
-rw-rw-r--  1 songz songz 3113437 Feb 21 02:48 D6_final_fix.html
-rw-rw-r--  1 songz songz     703 Feb 21 01:50 D6.sh
-rw-rw-r--  1 songz songz    2710 Feb 21 01:34 D6_manual.log
-rw-rw-r--  1 songz songz    1289 Feb 20 12:19 D6_fix_run.log
-rw-rw-r--  1 songz songz    2099 Feb 20 11:29 full_run.sh
-rw-rw-r--  1 songz songz    2652 Feb 20 01:23 clean_screen_debris.sh
-rw-rw-r--  1 songz songz     878 Feb 19 21:54 screen_then_conda.sh
-rw-rw-r--  1 songz songz    1766 Feb 19 20:53 screen_0219.sh

# 3. 重点排查以下几个“关键嫌疑文件”
# 根据你之前的工作习惯，最有可能被修改的“最终版”通常是：

# .nf 脚本：例如你之前提到的 2_steps_pipeline.nf 或 main.nf。
# 配置文件：nextflow.config 或特定的 .yaml / .json 文件。
# 样本表：samplesheet.csv 或 design.csv。
# Output 目录：查看 /output/ 文件夹下的时间戳，确认哪一波数据是最后跑出来的。

# 💡 快速确认修改内容
# 一旦你通过上面的命令找到了某个文件（比如 nextflow.config），但不确定改了什么，可以配合 stat 命令查看精确的最后修改时间：
stat /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/nextflow.config