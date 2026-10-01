# The check battery of analysis/function_checks.R (handoff v5, 3.10): the worked
# example and its variants stay green (v8 order, section 6). Block f belongs to
# the v7 case model and is not run here.
source(file.path(.proj_root, "analysis", "function_checks.R"), local = TRUE)

test_that("every synthetic check of the battery passes (blocks a-e, g)", {
  tab <- function_checks_synthetic()
  expect_gt(nrow(tab), 15L)
  expect_true(all(tab$passed == "yes"), info = paste(tab$check[tab$passed != "yes"], collapse = "; "))
})

test_that("the worked example is unchanged by profiles = NULL and by all profiles", {
  nb <- worked_example(); p <- c(women = 0.5, men = 0.5)
  vd <- voi_partition(nb, p, w_utilitarian(), differentiated = TRUE)
  all_prof <- as.matrix(expand.grid(women = colnames(nb$women), men = colnames(nb$men),
                                    stringsAsFactors = FALSE))
  vr <- voi_partition(nb, p, w_utilitarian(), differentiated = TRUE, profiles = all_prof)
  expect_equal(c(vd$B, vd$D, vd$VoH_static), c(4.5, 4.75, 1.5))
  expect_equal(unlist(vr[c("A", "B", "C", "D")]), unlist(vd[c("A", "B", "C", "D")]))
})
