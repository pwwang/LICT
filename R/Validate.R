#' @import reticulate
#' @import dplyr
#' @import stringr
#' @export
#'
#'
Validate <- function(LLM_res, seurat_obj, Percent,species) {
  .lict_openai_setup()
  # 每次调用 Validate 都从新一轮对话开始（与旧代码中 py_run_string 重置历史记录一致）
  py$lict_openai_reset("validate")
  if (!is.data.frame(LLM_res)) {
    print('list')
    for(n in names(LLM_res)){
      input = LLM_res[[n]]
      Marker_Prompt = MarkerPrompt(result = input,
                                   species = species)
      result = py$chat_with_gpt4_validate(Marker_Prompt)
      print(result)
      Marker_Prompt2 = ('
  Transform the above reply into an R language dataframe code.
  Do not reply with any words other than follow format:
  markerdata <- data_frame(
  Row = c(1,2,3...),##the row number before the gene
  Marker_Gene = c(
    "NCR1, KIR2DL1, KIR2DL3...",##row1 marker gene
    "CD3D, CD3E, CD3G...",##row2 marker gene
    "ACTA2, MYH11, TAGLN..."##row3 marker gene
    ...
  )
)')
      result2 = py$chat_with_gpt4_validate(Marker_Prompt2)
      #print(result2)
      formatted_result2 <- gsub("\\\\n", "\n", result2)
      # 移除最开始的 "R\n"，因为它不是有效的R代码的一部分
      formatted_result2 <- sub("R\n", "", formatted_result2)
      # 移除最开始的 "r\n"，因为它不是有效的R代码的一部分
      formatted_result2 <- sub("r\n", "", formatted_result2)
      # 移除开头的Markdown代码块标记（如果存在）
      formatted_result2 <- gsub("^```", "", formatted_result2)
      # 移除末尾的Markdown代码块标记（如果存在）
      formatted_result2 <- gsub("```$", "", formatted_result2)
      # 使用parse和eval来运行处理后的字符串中的R代码
      eval(parse(text = formatted_result2))
      cluster = markerdata$Row
      unique(Idents(seurat_obj))
      levels_order <- levels(Idents(seurat_obj))
      pn_gene <- data.frame(cluters = numeric(), positive_marker = character(), negative_marker = character(), stringsAsFactors = FALSE)

      for(i in cluster){
        #print(i)
        all_cells <- subset(seurat_obj, idents = levels_order[i])
        marker_gene = unlist(str_split(markerdata[markerdata$Row == i,]$Marker_Gene, ', '))
        positive_marker = character()
        negative_marker = character()
        for(j in marker_gene){
          tryCatch({
            if(any(rownames(all_cells) == j)){
              #print(j)
              code <- paste0("positive_cell = subset(all_cells,", j , ">0)")
              eval(parse(text = code))
              percent = nrow(positive_cell@meta.data)/nrow(all_cells@meta.data)
              if (percent>=Percent){
                positive_marker = c(positive_marker,j)
              }else{
                negative_marker = c(negative_marker,j)
              }
            }else{
              #print(j)
              #print('Can not find marker gene in the data')
            }
          }, error = function(e) {
            # 打印错误消息
            #print(paste("Error at marker gene ", j, ":", e$message))
          })
        }
        positive_marker = paste(positive_marker, collapse=",")
        negative_marker = paste(negative_marker, collapse=",")
        pn_gene1 <- as.data.frame(t(c(i, positive_marker,negative_marker)))
        pn_gene = rbind(pn_gene,pn_gene1)
      }
      colnames(pn_gene) = c('row', paste0(n, "_positive_marker"), paste0(n, "_negative_marker"))
      pn_gene$row = as.numeric(pn_gene$row)
      input$row = seq(1,nrow(input))
      input = input%>%
        left_join(pn_gene, by = c("row" = "row"))
      LLM_res[[n]] = input
    }
    return(LLM_res)
  } else if (is.data.frame(LLM_res)) {
    print('dataframe')
    input = LLM_res
    Marker_Prompt = MarkerPrompt(result = input,
                                 species = species)
    print('Marker_Prompt')
    result = py$chat_with_gpt4_validate(Marker_Prompt)
    print(result)
    Marker_Prompt2 = ('
  Transform the above reply into an R language dataframe code.
  Do not reply with any words other than follow format:
  markerdata <- data_frame(
  Row = c(1,2,3...),##row number
  Marker_Gene = c(
    "NCR1, KIR2DL1, KIR2DL3...",##row1 marker gene
    "CD3D, CD3E, CD3G...",##row2 marker gene
    "ACTA2, MYH11, TAGLN..."##row3 marker gene
    ...
  )
)')
    result2 = py$chat_with_gpt4_validate(Marker_Prompt2)
    print(result2)
    formatted_result2 <- gsub("\\\\n", "\n", result2)
    # 移除最开始的 "R\n"，因为它不是有效的R代码的一部分
    formatted_result2 <- sub("R\n", "", formatted_result2)
    # 移除最开始的 "r\n"，因为它不是有效的R代码的一部分
    formatted_result2 <- sub("r\n", "", formatted_result2)
    # 移除开头的Markdown代码块标记（如果存在）
    formatted_result2 <- gsub("^```", "", formatted_result2)
    # 移除末尾的Markdown代码块标记（如果存在）
    formatted_result2 <- gsub("```$", "", formatted_result2)
    # 使用parse和eval来运行处理后的字符串中的R代码
    eval(parse(text = formatted_result2))
    cluster = markerdata$Row
    unique(Idents(seurat_obj))
    levels_order <- levels(Idents(seurat_obj))
    pn_gene <- data.frame(cluters = numeric(), positive_marker = character(), negative_marker = character(), stringsAsFactors = FALSE)

    for(i in cluster){
      #print(i)
      all_cells <- subset(seurat_obj, idents = levels_order[i])
      marker_gene = unlist(str_split(markerdata[markerdata$Row == i,]$Marker_Gene, ', '))
      positive_marker = character()
      negative_marker = character()
      for(j in marker_gene){
        tryCatch({
          if(any(rownames(all_cells) == j)){
            #print(j)
            code <- paste0("positive_cell = subset(all_cells,", j , ">0)")
            eval(parse(text = code))
            percent = nrow(positive_cell@meta.data)/nrow(all_cells@meta.data)
            if (percent>=Percent){
              positive_marker = c(positive_marker,j)
            }else{
              negative_marker = c(negative_marker,j)
            }
          }else{
            #print(j)
            #print('Can not find marker gene in the data')
          }
        }, error = function(e) {
          # 打印错误消息
          #print(paste("Error at marker gene ", j, ":", e$message))
        })
      }
      positive_marker = paste(positive_marker, collapse=",")
      negative_marker = paste(negative_marker, collapse=",")
      pn_gene1 <- as.data.frame(t(c(i, positive_marker,negative_marker)))
      pn_gene = rbind(pn_gene,pn_gene1)
    }
    colnames(pn_gene) = c('row', "positive_marker","_negative_marker")
    pn_gene$row = as.numeric(pn_gene$row)
    input$row = seq(1,nrow(input))
    input = input%>%
      left_join(pn_gene, by = c("row" = "row"))
    LLM_res = input
    return(LLM_res)
  } else {
    print("Unknown result, please enter the result of LLMcelltype()")  # 如果输入既不是列表也不是数据框
  }
}
