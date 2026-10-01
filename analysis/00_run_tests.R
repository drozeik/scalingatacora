# Run the full test suite. Nothing in analysis/ may write results unless this
# script reports zero failures.
local_lib <- 'renv/library/macos/R-4.6/aarch64-apple-darwin23'
if (dir.exists(local_lib)) .libPaths(c(normalizePath(local_lib), .libPaths()))
library(testthat)

res <- test_dir("tests/testthat", reporter = "silent", stop_on_failure = FALSE)
df <- as.data.frame(res)

test_summary <- list(
  blocks   = nrow(df),   # test_that() blocks, not files
  passed   = sum(df$passed),
  failed   = sum(df$failed),
  errors   = sum(df$error),
  warnings = sum(df$warning),
  skipped  = sum(df$skipped)
)
test_summary$total <- test_summary$passed + test_summary$failed + test_summary$errors

cat(sprintf("tests: %d passed / %d total (%d failed, %d errors, %d skipped)\n",
            test_summary$passed, test_summary$total, test_summary$failed,
            test_summary$errors, test_summary$skipped))

if (test_summary$failed > 0 || test_summary$errors > 0)
  stop("Test suite is not green -- no results may be written.")

invisible(test_summary)
