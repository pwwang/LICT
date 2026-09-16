# Modernization notes

Fork `pwwang/LICT`, branch `modernize`, based on `Glowworm-cell/LICT` `main` at
commit `7d22367` ("Create LICENSE").

The upstream code calls the LLM providers through Python SDKs that no longer work
(`openai.ChatCompletion.create`, `google.generativeai`) or through Python globals
that are never defined (`ERNIE_api_key`, `GEMINI_api_key`, …), so no provider could
answer. This branch moves every provider to its current SDK, reports missing
packages/keys by name, and keeps the R-level function names, arguments and return
shapes unchanged.

## Providers

| Provider | Upstream | Now | Touched at |
| --- | --- | --- | --- |
| OpenAI (GPT) | `openai.ChatCompletion.create(model="gpt-4-turbo-preview")` (openai 0.28) | `OpenAI(api_key=…, base_url=…).chat.completions.create(model=…, messages=…)` (openai ≥ 1.0) | `R/py_helpers.R:46` (client `:69`, call `:70`), `R/GPT_input.R:7,20`, `R/GPT_interect.R:7,11`, `R/Validate.R:8,10,17,31,95,109` |
| Claude | `anthropic` SDK (already current) with the retired model `claude-3-opus-20240229` | same SDK, model `claude-opus-4-8`, lazy import, key passed from R, text block picked out of the `response.content` union | `R/py_helpers.R:93` (model `:110`, import `:106`), `R/Claude_input.R:7` |
| Gemini | `google.generativeai` + `genai.configure(api_key=GEMINI_api_key…)` (undefined name), `IPython.display.Markdown`, `gemini-1.5-pro-latest` | `google-genai`: `genai.Client(api_key=…).chats.create(model="gemini-2.5-flash").send_message(…).text` | `R/py_helpers.R:124` (client `:138`, chat `:143`), `R/Gemini_input.R:6`, `R/Gemini_interect.R:6` |
| ERNIE | `requests` POST to Baidu with `ERNIE_api_key`/`ERNIE_secret_key` read as undefined Python globals, plus an automatic `pip install` | same endpoints, keys passed from R, guarded `requests` import, token failure names both variables | `R/ERNIE_input.R:7-13,21-28,65` |
| Llama 3 | same pattern as ERNIE (`Llama3_api_key`/`Llama3_secret_key` undefined) | same treatment | `R/Llama3_input.R:7-13,21-28,49` |

Shared Python helpers live in the new `R/py_helpers.R`: `lict_import()`
(`:32`) turns a missing SDK into
`Python package 'anthropic' is required by the Claude provider but is not installed. Install it with reticulate::py_install('anthropic').`,
and `.lict_key()` (`:25`) resolves the first non-empty environment variable or
stops with `OpenAI API key not found: set OPENAI_API_KEY / openai_api_key / openai.api_key.`

Key and endpoint resolution:

- OpenAI keys are read in the order `OPENAI_API_KEY`, `openai_api_key`,
  `openai.api_key`; `OPENAI_BASE_URL` and `OPENAI_MODEL` are honoured when set
  (`OPENAI_MODEL` defaults to `gpt-4-turbo-preview`). `R/py_helpers.R:48-50`
- Keys are resolved **in R** and handed to Python as arguments. reticulate does
  not propagate environment variables that R sets after the Python session has
  started (verified: `Sys.setenv()` followed by `os.environ.get()` in Python
  returns `<unset>`), so reading `os.environ` inside Python — what the upstream
  snippets did — is not reliable for keys set with `readRenviron()`/`Sys.setenv()`.
- `R/zzz.R:8` declares `reticulate::py_require("openai")` in `.onLoad()`, so the
  GPT provider gets an interpreter that has the SDK without any manual setup.
  The other providers are imported lazily and name their missing package, so you
  only install the SDKs you use.

Failure behaviour (`R/LLMCelltype.R`): the OpenAI key check now also accepts
`OPENAI_API_KEY` (`:26`), and every provider call is wrapped in an error handler
(`:16,25,34,43,52`) that prints
`Error: <provider> provider skipped: <message>` and moves on. When no provider
answers, `LLMCellType()` still returns the string `"error"`, as before.

Two further bugs fixed while rewiring:

- `R/GeminiCellType.R:12` returned the column `cluster`; every other provider (and
  the biopipen runner) uses `clusters`.
- `R/GPT_interect.R:10` called `Gemini_generate_gene_text()` instead of
  `GPT_generate_gene_text()` — the two build the same text but put the
  "modify my previous answer" instruction *below* the gene list instead of above it.

## Verification

Everything below was run on this machine (Linux/WSL2, R 4.x, reticulate
provisioning CPython 3.12 through `py_require()`), against the OpenAI-compatible
endpoint configured in the `.env` referenced by the task. No value from that file
is printed, logged or committed here — only structure and label columns are shown.

### Install

```
$ Rscript -e 'remotes::install_local("/home/pwwang/github/LICT", upgrade = "never")'
* installing *source* package ‘LICT’ ...
** testing if installed package keeps a record of temporary installation path
* DONE (LICT)
```

`library(LICT)` reported `0.1.0` before (the upstream build) and `0.2.0` after.
remotes keys a *local* directory by its version, so re-running the same command
after further edits prints `Skipping install … the SHA1 (0.2.0) has not changed
since last install`; the final build was therefore installed with the same command
plus `force = TRUE`.

### Acceptance 1 — public surface unchanged

```
$ Rscript -e 'library(LICT); print(packageVersion("LICT")); print(names(formals(LLMCellType)))'
[1] ‘0.2.0’
[1] "FindAllMarkersResult" "topgenenumber"        "species"             
[4] "tissuename"          
```

### Acceptance 2 — real annotation (`/tmp/lict_real.R`)

Marker table: 200 rows, 8 clusters, columns `cluster, gene, avg_log2FC, p_val, p_val_adj`;
`OPENAI_MODEL` and `OPENAI_BASE_URL` were both set from the `.env`.

```
[1] "Error: ERNIE API key or secret key not provided"
[1] "Error: Gemini API key not provided"
[1] "ChatGPT is analyzing"
[1] "1: CD8 T cells\n2: B cells\n3: NK cells\n4: Monocytes\n5: Dendritic cells\n6: Platelets\n7: Non-classical monocytes\n8: Regulatory T cells"
[1] "Error: Llama3 API key not provided"
[1] "Error: Claude API key not provided"

--- result -----------------------------------------------------------
class: list 
providers: GPT 

[GPT] columns:clusters, cell_type
                           clusters               cell_type
1: CD8 T cells                    0             CD8 T cells
2: B cells                        1                 B cells
3: NK cells                       2                NK cells
4: Monocytes                      3               Monocytes
5: Dendritic cells                4         Dendritic cells
6: Platelets                      5               Platelets
7: Non-classical monocytes        6 Non-classical monocytes
8: Regulatory T cells             7      Regulatory T cells
```

All eight labels match the cell types the marker genes were drawn from.

### Acceptance 2b — clean skipping (`/tmp/lict_skip.R`, child R session)

```
== (1) every provider missing its key ==
[1] "Error: ERNIE API key or secret key not provided"
[1] "Error: Gemini API key not provided"
[1] "Error: ChatGPT API key not provided"
[1] "Error: Llama3 API key not provided"
[1] "Error: Claude API key not provided"
-> returned: [1] "error"

== (2) key present but Python package missing (dummy Claude key) ==
[1] "Error: ERNIE API key or secret key not provided"
[1] "Error: Gemini API key not provided"
[1] "Error: ChatGPT API key not provided"
[1] "Error: Llama3 API key not provided"
[1] "Claude is analyzing"
[1] "Error: Claude provider skipped: ImportError: Python package 'anthropic' is required by the Claude provider but is not installed. Install it with reticulate::py_install('anthropic').\nRun `reticulate::py_last_error()` for details."
-> returned: [1] "error"
```

### Acceptance 3 — through the biopipen engine

```
$ Rscript -e 'readRenviron("/home/pwwang/github/biopipen/tests/test_scrna/CellTypeAnnotationSCAgentType/.env"); pkgload::load_all("/home/pwwang/github/biopipen.utils.R"); obj <- readRDS("/home/pwwang/github/biopipen/tests/running/biopipen-tests-1/CellTypeAnnotation/pipen/test_scrna.CellTypeAnnotation/PrepData/0/output/pbmc3k.RDS"); res <- RunCellTypeAnnotation(obj, "lict", args = list(species = "Human", tissue = "PBMC"), ident = "seurat_clusters"); print(res$type); print(res$mapping)'
ℹ Loading biopipen.utils
Registered S3 method overwritten by 'SeuratDisk':
  method            from  
  as.sparse.H5Group Seurat
INFO    [2026-09-15 19:26:41] Running cell type annotation tool 'lict' ...
INFO    [2026-09-15 19:26:41] Find the markers for seurat_clusters ...
INFO    [2026-09-15 19:26:41] Using cached results from: /tmp/biopipen.utils.RunSeuratDEAnalysis.1e179d0e
INFO    [2026-09-15 19:26:41] Running LICT with species 'Human' ...
[1] "Error: ERNIE API key or secret key not provided"
[1] "Error: Gemini API key not provided"
[1] "ChatGPT is analyzing"
[1] "1: naive T cells\n2: memory T cells\n3: B cells\n4: MAIT cells\n5: neutrophils\n6: monocytes\n7: eosinophils\n8: neutrophils\n9: proliferating NK cells\n10: dendritic cells\n11: platelets"
[1] "Error: Llama3 API key not provided"
[1] "Error: Claude API key not provided"
INFO    [2026-09-15 19:29:30] Validating the LICT labels ...
[1] "list"
[1] "Provide key marker genes for the following Human cell types, with 15 key marker genes per cell type. Provide only the abbreviated gene names of key marker genes, full names are not required:\nrow 1 : naive T cells\nrow 2 : memory T cells\nrow 3 : B cells\nrow 4 : MAIT cells\nrow 5 : neutrophils\nrow 6 : monocytes\nrow 7 : eosinophils\nrow 8 : neutrophils\nrow 9 : proliferating NK cells\nrow 10 : dendritic cells\nrow 11 : platelets\nThe format of the final response should be:\n\row1: gene1, gene2, gene3\nrow2: gene1, gene2, gene3\nrowN: gene1, gene2, gene3\n\n...where rowN represents the row number and gene1, gene2, gene3 represent key marker genes."
[1] "row1: CCR7, SELL, TCF7, LEF1, IL7R, CD27, CD28, CD3D, CD3E, CD3G, CD4, CD8A, CD8B, PTPRC, ITK\nrow2: CD3D, CD3E, CD3G, CD4, CD8A, CD8B, IL7R, S100A4, CD44, CD27, CD28, CCR7, KLRG1, GZMB, IFNG\nrow3: MS4A1, CD19, CD79A, CD79B, PAX5, EBF1, CD74, HLA-DRA, HLA-DRB1, CD37, CD40, CD22, IGHM, IGHD, CD38\nrow4: TRAV1-2, TRAJ33, KLRB1, SLC4A10, ZBTB16, RORC, RORA, IL18R1, IL18RAP, CD3D, CD3E, CD3G, CD8A, CD8B, CXCR6\nrow5: FCGR3B, CSF3R, CXCR2, S100A8, S100A9, S100A12, MPO, ELANE, PRTN3, LTF, CAMP, MMP8, MMP9, FPR1, ITGAM\nrow6: CD14, FCGR1A, FCGR3A, LYZ, S100A8, S100A9, S100A12, CCR2, CX3CR1, CSF1R, ITGAM, CD68, CD163, HLA-DRA, FCN1\nrow7: IL5RA, CCR3, SIGLEC8, PRG2, PRG3, EPX, RNASE2, RNASE3, CLC, GATA1, GATA2, CSF2RB, CD69, CD52, IL3RA\nrow8: FCGR3B, CSF3R, CXCR2, S100A8, S100A9, S100A12, MPO, ELANE, PRTN3, LTF, CAMP, MMP8, MMP9, FPR1, ITGAM\nrow9: NCAM1, NCR1, KLRD1, KLRF1, NKG7, GNLY, PRF1, GZMB, FCGR3A, TYROBP, MKI67, TOP2A, BIRC5, CENPF, UBE2C\nrow10: HLA-DRA, HLA-DRB1, HLA-DPA1, HLA-DPB1, CD74, ITGAX, ITGAM, CD1C, CLEC9A, XCR1, LILRA4, CLEC4C, FCER1A, CD83, CD86\nrow11: PPBP, PF4, ITGA2B, ITGB3, GP9, GP1BA, GP1BB, GP6, VWF, SELP, PECAM1, CD36, THBS1, TUBB1, NRGN"
WARN    [2026-09-15 19:30:06] The LICT validate stage failed: invalid 'length' argument
INFO    [2026-09-15 19:30:06] Annotated 11 cluster(s) with 'GPT'
Warning message:
`data_frame()` was deprecated in tibble 1.1.0.
ℹ Please use `tibble()` instead.
ℹ The deprecated feature was likely used in the LICT package.
  Please report the issue to the authors. 
[1] "cluster"
$`0`
[1] "naive T cells"
$`1`
[1] "memory T cells"
$`2`
[1] "B cells"
$`3`
[1] "MAIT cells"
$`4`
[1] "neutrophils"
$`5`
[1] "monocytes"
$`6`
[1] "eosinophils"
$`7`
[1] "neutrophils"
$`8`
[1] "proliferating NK cells"
$`9`
[1] "dendritic cells"
$`10`
[1] "platelets"
```

The 11 clusters of the test object are annotated and returned in the shape the
runner expects (`res$type` = `"cluster"`, `res$mapping` = cluster → label).
`WARN … The LICT validate stage failed: invalid 'length' argument` comes from the
runner's best-effort validate stage and is non-fatal — see below. (The
`data_frame()` warning is emitted while that stage evaluates model-written R
code.)

### Provider probes without usable keys

Each provider was called once with clearly-fake keys to check how far the new code
gets. The messages below are what the SDK returned; the fake keys are masked by the
SDKs themselves.

| Provider | Result with a dummy key |
| --- | --- |
| Claude (`anthropic` installed) | `anthropic.AuthenticationError: Error code: 401 … 'Your api key: ****ummy is invalid'` — client, model argument and request shape accepted |
| Gemini (`google-genai` installed) | `google.genai.errors.ClientError: 400 INVALID_ARGUMENT … reason: API_KEY_INVALID` — request shape accepted |
| ERNIE (`requests` installed) | `RuntimeError: ERNIE access token request failed; check ERNIE_api_key / ERNIE_secret_key.` |
| Llama 3 (`requests` installed) | `RuntimeError: Llama3 access token request failed; check Llama3_api_key / Llama3_secret_key.` |

With the SDKs absent, all four answer with the "Python package … is required by …"
message quoted above instead of a traceback.

## Not done / known issues

- **Claude, Gemini, ERNIE and Llama 3 are not verified end to end.** The machine
  has no usable key for any of them, so the checks stop at "the SDK accepted the
  request and rejected the credentials". Gemini's model is pinned to
  `gemini-2.5-flash` (`R/py_helpers.R:147`) and Claude's to `claude-opus-4-8`
  (`R/py_helpers.R:110`); both are current as of this change, but a real answer
  from either API was never seen. The retired upstream Claude model
  (`claude-3-opus-20240229`, shut down 2026-01-05) was replaced by its documented
  drop-in successor.
- **The biopipen validate stage warns and is skipped.** The runner calls
  `LICT::Validate(res[provider], …)` — which returns a **list** of provider data
  frames — and passes that list straight into `LICT::Feedback_Info()`, which
  expects the **data.frame** produced by `LICT::Validate_Result_to_Df()` (its own
  first argument is a `for`/`nrow()`-style table: `character(nrow(Validate_df))`
  with `nrow(<list>)` = `NULL` raises exactly `invalid 'length' argument`).
  Even with the type mismatch worked around, `Feedback_Info()` selects its result
  by position (`Validate_df[, 29:31]`), which only holds for the 28-column layout
  of the upstream flow. This is a pre-existing contract mismatch between the fork
  and the caller, not an SDK problem; it is left alone because the runner is out
  of scope for this change and the runner already treats the stage as best-effort
  (`res$mapping` is returned regardless). The "talk-to-machine" path is reachable
  from R by following the README order — `Validate()` → `Validate_Result_to_Df()`
  → `Feedback_Info()`.
- **`data_frame()` deprecation warning.** It comes from the R code that `Validate()`
  asks the model to emit and then `eval()`s (`R/Validate.R`); the warning is
  attributed to LICT because the code is evaluated in its namespace. Changing the
  prompt to ask for `tibble()` is possible but would alter the prompts, so it was
  left as-is.
- **Only `openai` is declared to reticulate** (`R/zzz.R:8`). Declaring the other
  SDKs would force every user to download all five; the README explains how to add
  the ones you need.
- The vignette (`vignettes/`) and the `man/` pages of the exported functions were
  not touched — no exported function signature changed. README and DESCRIPTION
  were updated (pip packages, environment variables, real title/authors/licence,
  `Version: 0.2.0`).

## Credentials

No value from the `.env` file (API keys, base URL, model) is printed, logged or
committed on this branch; commands that read it only print structure and label
columns. The dummy keys used by the probes above are literal placeholders, not
credentials.
