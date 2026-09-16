#' @import reticulate
NULL

# Shared helpers for the Python provider wrappers.
#
# API keys and endpoints are resolved in R and handed to Python as arguments
# rather than read from Python's os.environ: reticulate does not propagate
# environment variables that R sets after the Python session has started, so a
# key exported in R (e.g. through readRenviron) would be invisible to Python.

# First non-empty environment variable among `vars`, or an error naming the
# provider and every variable that was tried.
.lict_key <- function(provider, vars) {
  for (v in vars) {
    value <- Sys.getenv(v, "")
    if (nzchar(value)) {
      return(value)
    }
  }
  stop(sprintf("%s API key not found: set %s.", provider, paste(vars, collapse = " / ")),
       call. = FALSE)
}

# Python-side building blocks shared by every provider. `lict_import` turns a
# missing SDK into an error that names the package, the provider that wanted it
# and the command that installs it.
.lict_py_bootstrap <- function() {
  reticulate::py_run_string('
import importlib


def lict_import(module, provider, pip_name=None):
    try:
        return importlib.import_module(module)
    except ImportError as e:
        raise ImportError(
            "Python package %r is required by the %s provider but is not installed. "
            "Install it with reticulate::py_install(%r)." % (module, provider, pip_name or module)
        ) from e
')
}

# Modern OpenAI client (openai >= 1.0): OpenAI(...).chat.completions.create(...)
# Re-running this is safe: the conversation histories live in the interpreter and
# are only reset explicitly, so GPT_input -> GPT_interact keeps its context.
.lict_openai_setup <- function() {
  .lict_py_bootstrap()
  api_key <- .lict_key("OpenAI", c("OPENAI_API_KEY", "openai_api_key", "openai.api_key"))
  base_url <- Sys.getenv("OPENAI_BASE_URL", "")
  model <- Sys.getenv("OPENAI_MODEL", "gpt-4-turbo-preview")
  reticulate::py_run_string('
lict_openai_conf = globals().get("lict_openai_conf") or {}
lict_openai_histories = globals().get("lict_openai_histories") or {}


def lict_openai_configure(api_key, base_url="", model=""):
    lict_openai_conf.update({"api_key": api_key, "base_url": base_url or None, "model": model})


def lict_openai_chat(prompt, key="gpt4", trim=0, reset=False):
    openai = lict_import("openai", "ChatGPT")
    if reset or key not in lict_openai_histories:
        lict_openai_histories[key] = []
    history = lict_openai_histories[key]
    history.append({"role": "user", "content": prompt})
    if trim and len(history) > trim:
        history = history[-trim:]
        lict_openai_histories[key] = history
    client = openai.OpenAI(api_key=lict_openai_conf["api_key"], base_url=lict_openai_conf["base_url"])
    response = client.chat.completions.create(model=lict_openai_conf["model"], messages=history)
    reply = response.choices[0].message.content
    history.append({"role": "assistant", "content": reply})
    return reply


def lict_openai_reset(key="gpt4"):
    lict_openai_histories.pop(key, None)


def chat_with_gpt4(prompt, reset=False):
    return lict_openai_chat(prompt, "gpt4", reset=reset)


def chat_with_gpt4_validate(prompt):
    return lict_openai_chat(prompt, "validate", trim=2)
')
  py$lict_openai_configure(api_key, base_url, model)
  invisible(NULL)
}

# Anthropic SDK (anthropic >= 0.25): Anthropic(api_key=...).messages.create(...)
# Restarts the conversation, as the py_run_string in Claude_input used to do.
.lict_claude_setup <- function() {
  .lict_py_bootstrap()
  api_key <- .lict_key("Claude", "ANTHROPIC_API_KEY")
  reticulate::py_run_string('
lict_claude = globals().get("lict_claude") or {}
conversation_history = []


def lict_claude_configure(api_key):
    lict_claude["api_key"] = api_key


def converse_with_claude(prompt):
    anthropic = lict_import("anthropic", "Claude")
    client = anthropic.Anthropic(api_key=lict_claude["api_key"])
    conversation_history.append({"role": "user", "content": prompt})
    response = client.messages.create(
        model="claude-opus-4-8",
        max_tokens=4096,
        messages=conversation_history
    )
    # response.content is a list of blocks; the answer is the text one.
    reply = next(block.text for block in response.content if block.type == "text")
    conversation_history.append({"role": "assistant", "content": reply})
    return reply
')
  py$lict_claude_configure(api_key)
  invisible(NULL)
}

# Current Gemini SDK (google-genai): genai.Client(api_key=...).chats.create(...)
.lict_gemini_setup <- function() {
  .lict_py_bootstrap()
  api_key <- .lict_key("Gemini", "GEMINI_api_key")
  reticulate::py_run_string('
lict_gemini = globals().get("lict_gemini") or {}


def lict_gemini_configure(api_key, model):
    lict_gemini.update({"api_key": api_key, "model": model})


def lict_gemini_session():
    if "chat" not in lict_gemini:
        genai = lict_import("google.genai", "Gemini", "google-genai")
        client = genai.Client(api_key=lict_gemini["api_key"])
        # keep the client referenced: the chat does not hold it, and a collected
        # client closes its transport ("Cannot send a request, as the client has
        # been closed").
        lict_gemini["client"] = client
        lict_gemini["chat"] = client.chats.create(model=lict_gemini["model"])
    return lict_gemini["chat"]


def chat_response(user_input):
    return lict_gemini_session().send_message(user_input).text
')
  py$lict_gemini_configure(api_key, "gemini-2.5-flash")
  invisible(NULL)
}
