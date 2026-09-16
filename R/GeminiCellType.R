#' @import reticulate
#' @import dplyr
#' @export

GeminiCellType = function(input,topgenenumber,species,tissuename){
  Gemini_input_result = Gemini_input(input = input,
                                     topgenenumber = topgenenumber,
                                     species = species,
                                     tissuename = tissuename)
  rows <- strsplit(Gemini_input_result, "\n")[[1]]
  data <- sapply(rows, function(row) strsplit(row, ": ")[[1]])
  df1 <- data.frame(clusters = as.integer(gsub(">", "", data[1, ]))-1, cell_type = data[2, ])
  return(df1)
}
