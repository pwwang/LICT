#' @import reticulate
#' @import dplyr
#' @import stringr
#' @export

GPT_interact = function(positive_gene = NULL,negative_gene = NULL){
  .lict_openai_setup()
  # 继续对话 (使用相同的聊天对象)
    # 如果任一不为空，执行以下代码positive_gene is expressed in the
  user_input <- GPT_generate_gene_text(positive_gene = positive_gene, negative_gene = negative_gene)
  result = py$chat_with_gpt4(user_input)
  print(result)
  rows <- strsplit(result, "\n")[[1]]
  data <- sapply(rows, function(row) strsplit(row, ": ")[[1]])
  df <- data.frame(clusters = as.integer(gsub(">", "", data[1, ]))-1, cell_type = data[2, ])
  return(df)
}
