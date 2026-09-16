#' @import reticulate
#' @import dplyr
#' @import stringr
#' @export


LLMCellType = function(FindAllMarkersResult,topgenenumber,species,tissuename){
  tryCatch(if(Sys.getenv("ERNIE_api_key", "") != ""&Sys.getenv("ERNIE_secret_key", "") != ""){
    print('ERNIE is analyzing')
    ERNIE = ERNIECellType(input = FindAllMarkersResult,
                          topgenenumber = topgenenumber,
                          species = species,
                          tissuename = tissuename)
  }else{
    print('Error: ERNIE API key or secret key not provided')
  }, error = function(e) print(paste0('Error: ERNIE provider skipped: ', conditionMessage(e))))
  tryCatch(if(Sys.getenv("Gemini_api_key", "") != ""){
    print('Gemini is analyzing')
    Gemini = GeminiCellType(input = FindAllMarkersResult,
                            topgenenumber = topgenenumber,
                            species = species,
                            tissuename = tissuename)
  }else{
    print('Error: Gemini API key not provided')
  }, error = function(e) print(paste0('Error: Gemini provider skipped: ', conditionMessage(e))))
  tryCatch(if(Sys.getenv("OPENAI_API_KEY", "") != ""|Sys.getenv("openai.api_key", "") != ""|Sys.getenv("openai_api_key", "") != ""){
    print('ChatGPT is analyzing')
    GPT = GPTCellType(input = FindAllMarkersResult,
                      topgenenumber = topgenenumber,
                      species = species,
                      tissuename = tissuename)
  }else{
    print('Error: ChatGPT API key not provided')
  }, error = function(e) print(paste0('Error: ChatGPT provider skipped: ', conditionMessage(e))))
  tryCatch(if(Sys.getenv("Llama3_api_key", "") != ""&Sys.getenv("Llama3_secret_key", "") != ""){
    print('Llama is analyzing')
    Llama = LlamaCellType(input = FindAllMarkersResult,
                          topgenenumber = topgenenumber,
                          species = species,
                          tissuename = tissuename)
  }else{
    print('Error: Llama3 API key not provided')
  }, error = function(e) print(paste0('Error: Llama provider skipped: ', conditionMessage(e))))
  tryCatch(if(Sys.getenv("ANTHROPIC_API_KEY", "") != ""){
    print('Claude is analyzing')
    Claude = ClaudeCellType(input = FindAllMarkersResult,
                            topgenenumber = topgenenumber,
                            species = species,
                            tissuename = tissuename)
  }else{
    print('Error: Claude API key not provided')
  }, error = function(e) print(paste0('Error: Claude provider skipped: ', conditionMessage(e))))
  tryCatch(if (exists("ERNIE") && exists("Gemini") && exists("GPT") && exists("Llama") && exists("Claude")) {
    res <- list(ERNIE = ERNIE, Gemini = Gemini, GPT = GPT, Llama = Llama, Claude = Claude)
  } else if (exists("ERNIE")) {
    res <- list(ERNIE = ERNIE)
  } else if (exists("Gemini")) {
    res <- list(Gemini = Gemini)
  } else if (exists("GPT")) {
    res <- list(GPT = GPT)
  } else if (exists("Llama")) {
    res <- list(Llama = Llama)
  } else if (exists("Claude")) {
    res <- list(Claude = Claude)
  } else {
    res <- 'error'
  })
  return(res)
}
