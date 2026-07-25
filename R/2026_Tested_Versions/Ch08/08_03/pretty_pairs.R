getwd()
setwd("/home/gao/projects/Utilities/R/2026_Tested_Versions/Ch08/08_03")

png("plot27.png")
pairs(iris[1:4], main = "Anderson's Iris Data -- 3 species", pch = 21, 
bg = c("red", "green3", "blue")[unclass(iris$Species)])
dev.off()

png("plot29.png")
pairs(iris[1:4], 
  panel = panel.smooth,
  main = "Scatterplot Matrix for Iris Data Using pairs Function",
  diag.panel = panel.hist, 
  pch = 16, 
  col = brewer.pal(3, "Pastel1")[unclass(iris$Species)])
  dev.off()
  # 加载数据
  
  data(iris)
  
  # Create palette with RColorBrewer
  require("RColorBrewer")
  display.brewer.pal(3, "Pastel1")
  # 生成并保存图表
png("plot31.png", width = 800, height = 800)
pairs(
    iris[1:4],
    main = "Anderson's Iris Data -- 3 species",
    pch = 21,
    #bg = c("red", "green3", "blue")[unclass(iris$Species)]
    col = brewer.pal(3, "Pastel1")[unclass(iris$Species)]
  )
  
dev.off()
  
# png("plot32.png")
# pairs(iris[1:4], 
#     panel = panel.smooth,
#     main = "Scatterplot Matrix for Iris Data Using pairs Function",
#     diag.panel = panel.hist, 
#     pch = 21, 
#     col = brewer.pal(3, "Pastel1")[unclass(iris$Species)])
# dev.off()
    # 加载数据

png("plot32.png")
pairs(iris[1:4], 
    panel = panel.smooth,
    main = "Scatterplot Matrix for Iris Data Using pairs Function",
    diag.panel = panel.hist, 
    pch = 21, 
    col = brewer.pal(3, "Pastel1")[unclass(iris$Species)])
dev.off()
    # 加载数据