#  ------------------------------------------------------------------------
#  RUN - Atacora case model v9, the one entry point:
#  tests -> model (10 000 draws, EVPI, PLS) -> axis tests T0-T6 and H3 -> key findings -> figures
#  From the project root:  Rscript --vanilla atacora_DA_run.R
#  ------------------------------------------------------------------------
local_lib <- "renv/library/macos/R-4.6/aarch64-apple-darwin23"                     # the project's library, without renv's activation
if (dir.exists(local_lib)) .libPaths(c(normalizePath(local_lib), .libPaths()))
t_start <- Sys.time()
quiet <- function(expr) withCallingHandlers(suppressMessages(expr), warning = function(w)   # the 'fit' rows of the input table log their
  if (grepl("Fitted value of|deviation of calculated", conditionMessage(w))) invokeRestart("muffleWarning"))  # fitting; known and harmless

test_summary <- source("analysis/00_run_tests.R")$value                             # 1. tests: nothing is written unless all are green
invisible(capture.output(quiet(source("atacora_DA_model.R"))))                      # 2. model: simulation, EVPI and PLS of the decisive comparisons
quiet(source("atacora_DA_axes.R"))                                                  # 3. axis tests -> outputs/v9/T*.csv, axes_results.rds
saveRDS(simulation_results, "outputs/v9/simulation_results.rds")                    #    the draws, for the figures (not versioned)
source("analysis/write_key_findings.R")                                             # 4. key findings -> outputs/v9/key_findings.md
source("atacora_DA_figures.R")                                                      # 5. figures -> outputs/v9/figures/ (F1, F2, supplement/)
source("analysis/make_walkthrough.R")                                               #    docs/model_walkthrough.md: decision_model() at the medians
source("analysis/make_review_checklist.R")                                          #    docs/review_checklist.md: the review path with line numbers

cat(sprintf("v9 run done: seed %d, %d draws, %d tests green, %.1f min\n", SEED, N_DRAWS,
            test_summary$passed, as.numeric(difftime(Sys.time(), t_start, units = "mins"))))
