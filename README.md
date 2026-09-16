## LICT:Large language model-based Identifier for Cell Types

Our [article](https://arxiv.org/abs/2409.15678) is currently published on arXiv.

Reliability in cell type annotation is challenging in single-cell RNA-sequencing data analysis because both expert-driven and automated methods can be biased or constrained by their training data, especially for novel or rare cell types. Although large language models (LLMs) are useful, our evaluation found that only a few matched expert annotations due to biased data sources and inflexible training inputs. To overcome these limitations, we developed the LICT (Large language model-based Identifier for Cell Types) software package using a multi-model integration and “talk-to-machine” strategy. Tested across various single-cell RNA sequencing datasets, our approach significantly improved annotation reliability, especially in datasets with low cellular heterogeneity. Notably, we established an objective framework to assess annotation reliability using the “talk-to-machine” approach, which addresses discrepancies between our annotations and expert ones, enabling reliable evaluation even without reference data. This strategy enhances annotation credibility and sets the stage for advancing future LLM-based cell type annotation methods.

## Installation 

To install the latest version of LICT package via Github, run the following commands in R:
```{r eval = FALSE}
remotes::install_github("Glowworm-cell/LICT")
```

This fork tracks the current Python LLM SDKs and is installable with
`remotes::install_github("pwwang/LICT")`. See [MODERNIZATION.md](MODERNIZATION.md)
for what changed and how it was verified.

## Necessary preparation before start

The recommended version for Python is 3.9 or higher, and for R, it is 4.2 or above.
<br>**Necessary Python modules**: 
<br>openai (>= 1.0, for the GPT provider — declared through `reticulate::py_require()` and provisioned by reticulate on first use); <br>anthropic (Claude); <br>google-genai (Gemini); <br>requests (ERNIE and Llama 3)
<br>Only the modules for the providers you actually use are needed: a provider whose module or API key is missing is skipped with a message naming the missing package or variable, e.g. `Python package 'anthropic' is required by the Claude provider but is not installed. Install it with reticulate::py_install('anthropic').`
<br>API keys are read from the R environment (`Sys.setenv()` or `readRenviron()`), not from Python; run `reticulate::py_install("google-genai")` (or the relevant module) once for the providers you want.

##  🚀 Quick start with Seurat pipeline 


```{r eval = FALSE}

# Load Seurat object

librar(Seurat)
seurat_obj = readRDS('../../gc.rds')

# IMPORTANT! Assign your API key. See Vignette for details
# Only the keys of the providers you want to use need to be set; the others are
# skipped with a message naming the missing variable.
Sys.setenv(Llama3_api_key = 'Replace_your_key')
Sys.setenv(Llama3_secret_key = 'Replace_your_key')
Sys.setenv(ERNIE_api_key = 'Replace_your_key')
Sys.setenv(ERNIE_secret_key = 'Replace_your_key')
Sys.setenv(GEMINI_api_key = 'Replace_your_key')
Sys.setenv(ANTHROPIC_API_KEY = "Replace_your_key")

# OpenAI keys are looked up in this order: OPENAI_API_KEY, openai_api_key,
# openai.api_key. OPENAI_BASE_URL and OPENAI_MODEL (default gpt-4-turbo-preview)
# are honoured when set, which is what makes an OpenAI-compatible endpoint work.
Sys.setenv(OPENAI_API_KEY = 'Replace_your_key')
Sys.setenv(OPENAI_BASE_URL = 'Replace_with_your_endpoint')  # optional
Sys.setenv(OPENAI_MODEL = 'Replace_with_your_model')        # optional

# Load packages
library(LICT)

# Assume you have already run the Seurat pipeline https://satijalab.org/seurat/
# "markers" is the output from FindAllMarkers(obj)
# Cell type annotation by LICT
LLMCelltype_res = LLMCellType(FindAllMarkersResult = markers,
                             species = 'human',
                             topgenenumber = 10,
                             tissuename = 'gastric tumor')

# To check whether LLMs rendered reliable results, we can use the Validate() function to evaluate the results. Three parameters were needed:
# 1 The LLM_res parameter, the results generated from the LLMCelltype();
# 2 Previously loaded Seurat object;
# 3 The threshold for defining positive genes. Here, we will use 0.6 as the threshold, as stated in the article.That mean cell type annotations with four or more positive marker genes (expressed in over 60% of cells) are considered validated.
Validate_res = Validate(LLM_res = LLMCelltype_res, seurat_obj = seurat_obj, Percent = 0.6)

# Talk-to-machine
# If most of cell annotation failed to be reliable, LICT would apply another strategy ‘talk-to-machine’ to refine LLM’s response.
# Both positive gene and negative gene marker together with additional differential expressed gene in the original datasets will provide to each LLMs and request cell annotation update.
# This strategy can simply achieve through Feedback_Info(). Users need to provide:
# 1. validation result from Validate(),2.Differential expression gene table generated from Seurat::FindAllMarkers()
Validate_Result_to_Df = Validate_Result_to_Df(Validate_res)
#input Validate_Result_to_Df() result and you want to put top how many FindAllMarkers() result next top DEGs to LLMs. Here we use top 11 to 20 DEGs.
interacted_res = Feedback_Info(Validate_Result_to_Df, 11, 20, markers)
```

### ⚠️Warning: avoid sharing your API key with others or uploading it to public spaces.

## Vignette
You can view the complete vignette [here](https://glowworm-cell.github.io/Wenjin-Ye.github.io/vignette.html).

## Contact

Authors: Wenjin Ye (yewj27@mail2.sysu.edu.cn), Yuanchen Ma (maych25@mail.sysu.edu.cn).

Report bugs and provide suggestions by sending email to the maintainer Dr. Wenjin Ye  (yewj27@mail2.sysu.edu.cn) or open a new issue on this Github page. 
