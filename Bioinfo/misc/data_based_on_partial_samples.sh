
1. 立即揭开“10% 比对率”的谜底
既然已经有 12 个样本跑完了 SORTMERNA，你不需要等流程结束。请执行以下步骤：
找到一个已完成样本的 work 目录：
在你的日志里看到 [4b/f8496d] NFCORE_RNASEQ:RNASEQ:SORTMERNA (C1_D)。
查看该样本的 rRNA 统计：
进入对应的目录：

cd /Work_bio/gao/projects/2026_Item2_0205_Jitu/scripts/work/4b/f8496dd082f8ea9b5800ad77a3418f

查看日志文件：
# 运行以下命令查看该样本到底有多少是 rRNA：

# grep "passing the E-value threshold" .command.log
# grep "passing the E-value threshold" .command.log
# grep -E "reads|aligned|%" .command.log <<==========  给出了 rRNA 的比对率（百分比）和数量。

# 既然已经跑完了，现在你可以运行下面这个命令，拿到那个决定性的百分比数字：
# 1. 运行这个命令获取结果：

grep -A 20 "RESULTS" .command.log

# 如果你想看那份漂亮的分表格统计（详细到 18S, 28S, 5S 分别占多少），请在这个目录下运行：
cat rRNA_reads.log

find . -find . -name "*.log"
./C1_D.sortmerna.log
./.command.log
./kvdb/000318.log


cat ./C1_D.sortmerna.log 
 Command:
    sortmerna --ref rfam-5.8s-database-id98.fasta --ref rfam-5s-database-id98.fasta --ref silva-arc-16s-id95.fasta --ref silva-arc-23s-id98.fasta --ref silva-bac-16s-id90.fasta --ref silva-bac-23s-id98.fasta --ref silva-euk-18s-id95.fasta --ref silva-euk-28s-id98.fasta --reads C1_D_1_val_1.fq.gz --reads C1_D_2_val_2.fq.gz --threads 12 --workdir . --aligned rRNA_reads --fastx --other non_rRNA_reads --paired_in --out2 --num_alignments 1 -v 

 Process pid = 

 Parameters summary: 
    Reference file: rfam-5.8s-database-id98.fasta
        Seed length = 18
        Pass 1 = 18, Pass 2 = 9, Pass 3 = 3
        Gumbel lambda = 0.617555
        Gumbel K = 0.343861
        Minimal SW score based on E-value = 57
    Reference file: rfam-5s-database-id98.fasta
        Seed length = 18
        Pass 1 = 18, Pass 2 = 9, Pass 3 = 3
        Gumbel lambda = 0.616694
        Gumbel K = 0.342032
        Minimal SW score based on E-value = 59
    Reference file: silva-arc-16s-id95.fasta
        Seed length = 18
        Pass 1 = 18, Pass 2 = 9, Pass 3 = 3
        Gumbel lambda = 0.596286
        Gumbel K = 0.322254
        Minimal SW score based on E-value = 60
    Reference file: silva-arc-23s-id98.fasta
        Seed length = 18
        Pass 1 = 18, Pass 2 = 9, Pass 3 = 3
        Gumbel lambda = 0.597507
        Gumbel K = 0.331576
        Minimal SW score based on E-value = 57
    Reference file: silva-bac-16s-id90.fasta
        Seed length = 18
        Pass 1 = 18, Pass 2 = 9, Pass 3 = 3
        Gumbel lambda = 0.602725
        Gumbel K = 0.329559
        Minimal SW score based on E-value = 62
    Reference file: silva-bac-23s-id98.fasta
        Seed length = 18
        Pass 1 = 18, Pass 2 = 9, Pass 3 = 3
        Gumbel lambda = 0.602436
        Gumbel K = 0.335011
        Minimal SW score based on E-value = 62
    Reference file: silva-euk-18s-id95.fasta
        Seed length = 18
        Pass 1 = 18, Pass 2 = 9, Pass 3 = 3
        Gumbel lambda = 0.612551
        Gumbel K = 0.33981
        Minimal SW score based on E-value = 61
    Reference file: silva-euk-28s-id98.fasta
        Seed length = 18
        Pass 1 = 18, Pass 2 = 9, Pass 3 = 3
        Gumbel lambda = 0.612082
        Gumbel K = 0.345772
        Minimal SW score based on E-value = 61
    Number of seeds = 2
    Edges = 4
    SW match = 2
    SW mismatch = -3
    SW gap open penalty = 5
    SW gap extend penalty = 2
    SW ambiguous nucleotide = -3
    SQ tags are not output
    Number of alignment processing threads = 12
    Reads file: C1_D_1_val_1.fq.gz
    Reads file: C1_D_2_val_2.fq.gz
    Total reads = 35425032

 Results:
    Total reads passing E-value threshold = 32449366 (91.60)
    Total reads failing E-value threshold = 2975666 (8.40)
    Minimum read length = 150
    Maximum read length = 20
    Mean read length    = 145

 Coverage by database:
    rfam-5.8s-database-id98.fasta               2.82
    rfam-5s-database-id98.fasta         0.04
    silva-arc-16s-id95.fasta            5.17
    silva-arc-23s-id98.fasta            15.32
    silva-bac-16s-id90.fasta            0.92
    silva-bac-23s-id98.fasta            3.15
    silva-euk-18s-id95.fasta            26.07
    silva-euk-28s-id98.fasta            38.08

 Fri Mar 20 16:58:38 2026


 # 在项目根目录下运行（假设你的 work 目录就在这里）
cd /Work_bio/gao/projects/2026_Item2_0205_Jitu/scripts
find work -name "*.sortmerna.log" -exec grep -H "Total reads passing E-value threshold" {} \;
# work/36/ba21c2887743f782a9baafd058dc6d/ch_1B.sortmerna.log:    Total reads passing E-value threshold = 56264504 (90.94)
# work/6b/ead007c39f4c13291f85443f154981/C2_D.sortmerna.log:    Total reads passing E-value threshold = 57706375 (90.95)
# work/fe/cc97a26894fa562bf7942eac9b48ed/C2_A.sortmerna.log:    Total reads passing E-value threshold = 47188439 (91.24)
# work/e4/a5e6be355a46436b44a4add160d261/C2_C.sortmerna.log:    Total reads passing E-value threshold = 41024711 (91.46)
# work/e4/fdda0533f0f8b3f13b78610727f519/ch_3A.sortmerna.log:    Total reads passing E-value threshold = 48589055 (89.58)
# work/93/1c4b4068c0bf7c7a312a2d21fca89f/ch_2B.sortmerna.log:    Total reads passing E-value threshold = 36099222 (93.14)
# work/bb/af141d723a30d622603b3bc470c9d3/C1_A.sortmerna.log:    Total reads passing E-value threshold = 37068257 (93.53)
# work/d5/b24f76985481355678538b6503a07e/C3_A.sortmerna.log:    Total reads passing E-value threshold = 59045529 (91.20)
# work/e6/5bba957cd295fa1d714f9f3eb2847d/ch_1D.sortmerna.log:    Total reads passing E-value threshold = 39298243 (94.43)
# work/e6/6d76f255b0642185fc9c6d939ce22c/C3_B.sortmerna.log:    Total reads passing E-value threshold = 40058139 (90.41)
# work/2e/35d8f6082d4cefa6842736deb78f82/ch_1A.sortmerna.log:    Total reads passing E-value threshold = 51332095 (93.05)
# work/9f/2efd793951faa51f40243cfecf048e/C3_D.sortmerna.log:    Total reads passing E-value threshold = 66899698 (90.10)
# work/4b/f8496dd082f8ea9b5800ad77a3418f/C1_D.sortmerna.log:    Total reads passing E-value threshold = 32449366 (91.60)

Ctrl B, then D 

find work -name "*.sortmerna.log" -exec grep -H "Total reads passing E-value threshold" {} \;