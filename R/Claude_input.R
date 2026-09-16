#' @import reticulate
#' @import dplyr
#' @import stringr
#' @export

Claude_input <- function(input,topgenenumber, species, tissuename) {
  .lict_claude_setup()
  # 开始连续对话
  top_markers <- input %>% dplyr::group_by(cluster) %>% dplyr::top_n(n = topgenenumber, wt = avg_log2FC)
  cluster_genes <- top_markers %>%
    dplyr::group_by(cluster) %>%
    dplyr::summarise(genes = paste(gene, collapse=", ")) %>%
    dplyr::ungroup()
  formatted_output <- paste(cluster_genes$genes, collapse="\n")
  user_input <-paste('ldentify cell types of', species, tissuename, 'using the following markers.ldentify one celltype for each row.Just reply to the cell type, no need to reply to the reasoning section or explanation section.\n', formatted_output, 'Reply in the following format:
1: xx
2: xx
N: xx
N is the line number, xx is a phrase that only includes cell types, such as pluripotent stem cells and smooth muscle cells.')
  result = py$converse_with_claude(user_input)
  print(result)
  return(result)
}
