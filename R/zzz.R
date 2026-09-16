#' @import reticulate
NULL

.onLoad <- function(libname, pkgname) {
  # Declare the Python SDK the GPT provider needs so reticulate resolves an
  # interpreter that has it, instead of failing on `import openai`.
  # The other providers import their SDK lazily and name the missing package.
  tryCatch(reticulate::py_require("openai"), error = function(e) NULL)
}
