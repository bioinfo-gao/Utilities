
Nextflow + SLURM + Singularity (nextflow.config) 生产级配置指南在 Linux HPC 高性能计算集群（使用 SLURM 调度器）环境下，通过配置文件绑定 Singularity 容器，可以实现任务资源动态重试与环境完全隔离。1. 配置文件结构说明 (nextflow.config)此配置文件包含了：SLURM 任务提交与 Singularity 自动绑定；错误自动重试（Dynamic Retries）：针对节点 OOM（Exit Code 137/140）或超时自动提升 CPU / 内存并重新提交；按任务负载（Label）分类资源配额。Groovy/*
================================================================================================================================================================================================================================================================================================================================================================================================================================================

Nextflow SLURM + Singularity Production Configuration
=====================================================

*/

// 1. 执行器与容器基本配置
process {
    executor = 'slurm'
    clusterOptions = '--qos=normal'

    // Singularity 容器自动关联与挂载
    singularity.enabled    = true
    singularity.autoMounts = true
    singularity.cacheDir   = "${projectDir}/singularity_cache"

    // 默认基础资源设置
    cpus   = { check_max( 2 * task.attempt, 'cpus' ) }
    memory = { check_max( 8.GB * task.attempt, 'memory' ) }
    time   = { check_max( 4.h * task.attempt, 'time' ) }

    // 节点内存溢出 (OOM) 或超时自动重试逻辑
    errorStrategy = { task.exitStatus in [140,143,137,104,134,139] ? 'retry' : 'finish' }
    maxRetries    = 3
    maxErrors     = '-1'

    // 2. 根据资源 Label 标签分配任务配额
    withLabel:process_single {
        cpus   = { check_max( 1, 'cpus' ) }
        memory = { check_max( 6.GB * task.attempt, 'memory' ) }
        time   = { check_max( 2.h * task.attempt, 'time' ) }
    }
    withLabel:process_low {
        cpus   = { check_max( 2     * task.attempt, 'cpus' ) }
        memory = { check_max( 12.GB * task.attempt, 'memory' ) }
        time   = { check_max( 6.h   * task.attempt, 'time' ) }
    }
    withLabel:process_medium {
        cpus   = { check_max( 8     * task.attempt, 'cpus' ) }
        memory = { check_max( 36.GB * task.attempt, 'memory' ) }
        time   = { check_max( 12.h  * task.attempt, 'time' ) }
    }
    withLabel:process_high {
        cpus   = { check_max( 16    * task.attempt, 'cpus' ) }
        memory = { check_max( 72.GB * task.attempt, 'memory' ) }
        time   = { check_max( 24.h  * task.attempt, 'time' ) }
    }
}

// 3. 全局参数限制防护（防止超过集群单节点最大限制）
params {
    max_cpus   = 32
    max_memory = 128.GB
    max_time   = 72.h
}

// 资源上限检查逻辑
def check_max(obj, type) {
    if (type == 'memory') {
        try {
            if (obj.compareTo(params.max_memory as nextflow.util.MemoryUnit) == 1)
                return params.max_memory as nextflow.util.MemoryUnit
            else
                return obj
        } catch (all) {
            return obj
        }
    } else if (type == 'time') {
        try {
            if (obj.compareTo(params.max_time as nextflow.util.Duration) == 1)
                return params.max_time as nextflow.util.Duration
            else
                return obj
        } catch (all) {
            return obj
        }
    } else if (type == 'cpus') {
        try {
            return Math.min(obj, params.max_cpus as int)
        } catch (all) {
            return obj
        }
    }
}
2. 终端编辑与完整启动命令序列Bash# 1. 创建并进入保活后台 screen 会话，避免网络掉线中断主进程
screen -S nextflow_pipeline

# 2. 激活指定的生信分析环境

mamba activate R44

# 3. 使用 vim 创建或编辑配置文件（也可直接在 VS Code 中打开编辑）

vim nextflow.config

# 4. 运行 Nextflow 流程命令序列

nextflow run main.nf 
    -c nextflow.config 
    --input samplesheet.csv 
    --outdir ./results 
    -resume

# 5. 按 Ctrl+A 然后按 D 剥离会话 (Detach) 保持后台安全运行

文档二：WDL / Cromwell + SLURM + Singularity (cromwell_slurm.conf) 生产级配置指南WDL 流程依赖 Cromwell 引擎调度。此配置文件使用 HOCON 语法，将 WDL 中定义的 runtime 属性（如 CPU、Memory、Docker 镜像）自动转化为 SLURM 的 sbatch 提交脚本，并通过 Singularity 挂载运行。1. 配置文件结构说明 (cromwell_slurm.conf)代码段# Cromwell SLURM + Singularity 后端配置文件
include required(classpath("application"))

backend {
  default = "SLURM"

  providers {
    SLURM {
      actor-factory = "cromwell.backend.impl.sbt.CommandLineBackendLifecycleActorFactory"
      config {
        concurrent-job-limit = 50
        script-epilogue = ""

        // 定义 WDL runtime 中支持读取的变量
        runtime-attributes = """
        Int? cpu
        Int? memory_gb
        String? time
        String? docker
        """

        // 将 WDL 任务转换为 sbatch 脚本提交
        submit = """
            sbatch 
            --job-name=${job_name} 
            --output=${out} 
            --error=${err} 
            --cpus-per-task=${select_first([cpu, 2])} 
            --mem=${select_first([memory_gb, 8])}G 
            --time=${select_first([time, "04:00:00"])} 
            --wrap="singularity exec --bind ${cwd}:${cwd} docker://${select_first([docker, 'ubuntu:22.04'])} /bin/bash ${script}"
        """

        kill = "scancel ${job_id}"
        check-exit-code = "squeue -j ${job_id}"
        job-id-regex = "Submitted batch job (\\d+)"
      }
    }
  }
}
2. 终端编辑与完整启动命令序列Bash# 1. 创建并进入保活后台 screen 会话
screen -S cromwell_pipeline

# 2. 激活环境

mamba activate R44

# 3. 使用 vim 或直接用 VS Code 打开编辑 cromwell_slurm.conf

vim cromwell_slurm.conf

# 4. 启动 Cromwell 并提交 WDL 任务

java -Dconfig.file=cromwell_slurm.conf 
     -jar cromwell-85.jar run workflow.wdl 
     --inputs inputs.json 
     --options options.json

# 5. 按 Ctrl+A 然后按 D 剥离会话 (Detach)

两者调度机制差异对比特性维度Nextflow (nextflow.config)Cromwell/WDL (cromwell_slurm.conf)配置文件格式Groovy DSL2 原生语法HOCON (Human-Optimized Config Object Notation)SLURM 提交机制内置 SLURM Executor，原生控制 sbatch配置文件中通过模版宏渲染 (--wrap="singularity...")容器转换规则自动识别 Docker 镜像地址并转换为 Singularity在 sbatch 的 --wrap 命令中显式调用 singularity exec资源动态重试代码内内置 task.attempt，逻辑极简需要配合 Workflow 层面的 retry 策略及后端规则Raw Markdown 代码Markdown| 特性维度 | Nextflow (`nextflow.config`) | Cromwell/WDL (`cromwell_slurm.conf`) |
| :--- | :--- | :--- |
| **配置文件格式** | Groovy DSL2 原生语法 | HOCON (Human-Optimized Config Object Notation) |
| **SLURM 提交机制** | 内置 SLURM Executor，原生控制 `sbatch` | 配置文件中通过模版宏渲染 (`--wrap="singularity..."`) |
| **容器转换规则** | 自动识别 Docker 镜像地址并转换为 Singularity | 在 `sbatch` 的 `--wrap` 命令中显式调用 `singularity exec` |
| **资源动态重试** | 代码内内置 `task.attempt`，逻辑极简 | 需要配合 Workflow 层面的 `retry` 策略及后端规则 |
