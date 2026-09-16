#' @import reticulate
#' @import dplyr
#' @import stringr
#' @export

ERNIE_input <- function(input,topgenenumber, species, tissuename) {
  .lict_py_bootstrap()
  api_key <- .lict_key("ERNIE", "ERNIE_api_key")
  secret_key <- .lict_key("ERNIE (secret key)", "ERNIE_secret_key")
  reticulate::py_run_string("
import json
requests = lict_import('requests', 'ERNIE')

payload = globals().get('payload') or {
    'user_id': 'python',
    'messages': [],
    'disable_search': False,
    'enable_citation': False
}

def lict_ernie_configure(api_key, secret_key):
    token = requests.post(
        'https://aip.baidubce.com/oauth/2.0/token',
        params={'grant_type': 'client_credentials', 'client_id': api_key, 'client_secret': secret_key}
    ).json().get('access_token')
    if not token:
        raise RuntimeError('ERNIE access token request failed; check ERNIE_api_key / ERNIE_secret_key.')
    globals()['url'] = 'https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/completions_pro?access_token=' + str(token)

def add_ERNIE_message(role, content):
    message = {
        'role': role,
        'content': content
    }
    payload['messages'].append(message)


def add_ERNIE_message_2(role, content):
    message = {
        'role': role,
        'content': content
    }
    payload['messages'].append(message)
    if len(payload['messages']) > 2:
        payload['messages'] = payload['messages'][:-2]

def send_request(user_input):
    add_ERNIE_message('user', user_input)
    headers = {'Content-Type': 'application/json'}
    json_payload = json.dumps(payload)
    response = requests.request('POST', url, headers=headers, data=json_payload)
    result = response.json().get('result')
    add_ERNIE_message('assistant', result)
    return result

def send_request_2(user_input):
    add_ERNIE_message('user', user_input)
    headers = {'Content-Type': 'application/json'}
    json_payload = json.dumps(payload)
    response = requests.request('POST', url, headers=headers, data=json_payload)
    result = response.json().get('result')
    add_ERNIE_message_2('assistant', result)
    return result
")
  py$lict_ernie_configure(api_key, secret_key)
  top_markers <- input %>% dplyr::group_by(cluster) %>% dplyr::top_n(n = topgenenumber, wt = avg_log2FC)
  cluster_genes <- top_markers %>%
    dplyr::group_by(cluster) %>%
    dplyr::summarise(genes = paste(gene, collapse=", ")) %>%
    dplyr::ungroup()
  row_prefixes <- paste("row", 1:nrow(cluster_genes), ":", sep="")
  formatted_rows <- paste(row_prefixes, cluster_genes$genes, sep=" ")
  formatted_output <- paste(formatted_rows, collapse="; ")
  user_input <-paste('You are a cell classification expert who uses the following markers to identify the cell type of',species, tissuename,'ldentify cell types of', species, tissuename, 'using the following markers.Identify one cell type for each of the following rows of marker genes, providing only one cell type.Just reply to the cell type, no need to reply to the reasoning section or explanation section:\n', formatted_output, 'Reply in the following format:
1: xx
2: xx
N: xx
N is the line number, xx is a phrase that only includes cell types, such as pluripotent stem cells and smooth muscle cells. Do not add additional text!Use "undefined" as a substitute if identification cannot be made.')
  result1 <- py$send_request(user_input)
  user_input <- paste(result1,"将上面的文本中的数字和细胞类型或者Undefined按照如下格式提取出来，1: xx
2: xx
...: xx
N: xx
N为对应的行数，xx为对应的细胞类型，N和xx之间用英文的冒号加空格“: ”分隔", sep = "\n")
  result = py$send_request_2(user_input)
  print(result)
  start_position <- regexpr("1:", result)
  result <- substring(result, start_position)
  end_position <- regexpr("\n\n", result)
  # 检查是否找到'\n\n'
  if (end_position > 0) { # 如果找到'\n\n'
    # 以'\n\n'之前的内容作为新的字符串
    result <- substring(result, 1, end_position - 1)
  } else { # 如果没有找到'\n\n'
    # 不做改变，保留原字符串
  }
  rows <- strsplit(result, "\n")[[1]]
  data <- sapply(rows, function(row) strsplit(row, ": ")[[1]])
  df1 <- data.frame(clusters = as.integer(gsub(">", "", data[1, ]))-1, cell_type = data[2, ])
  return(df1)
}
