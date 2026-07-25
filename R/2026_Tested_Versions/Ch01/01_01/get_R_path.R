# 获取 R 可执行文件的完整绝对路径
file.path(R.home("bin"), "R")
# or
R.home()
# 或者
Sys.getenv("R_HOME")
# R version
R.version.string
#
.libPaths() # 查看R加载包的路径  # << ============== base env 的 path
