# No function knows the groups, the options or the rules, and none makes a
# valuation choice on the caller's behalf: every argument that encodes such a
# choice has no default. One deliberate exception: voi_partition(differentiated
# = FALSE), one decision for all unless the caller says otherwise (FUNCTIONS.md, "Shared arguments").
# voi_partition(profiles = NULL) is not a valuation: it allows every profile,
# as before v8, and only matters once the caller has chosen differentiated = TRUE.
# w_atkinson(offset = 0) is the documented convention of the index (v8 order, 3a).

has_default <- function(f, arg) {
  fm <- formals(f)
  arg %in% names(fm) && !identical(fm[[arg]], quote(expr = ))
}

test_that("arguments that encode valuation choices have no default", {
  required <- list(
    voi_partition         = c("p", "W"),
    fairness_screen       = c("p", "rules"),
    baseline_pair         = c("references", "p", "rules"),
    marginalisation_count = c("p", "W"),
    reporting_units       = "units",
    w_prioritarian        = "u",
    w_atkinson            = "eps",
    nb_from_mc            = c("pattern", "groups", "options")
  )
  for (fn in names(required)) {
    f <- get(fn)
    for (arg in required[[fn]]) {
      expect_true(arg %in% names(formals(f)), info = paste(fn, arg))
      expect_false(has_default(f, arg), info = paste(fn, arg))
    }
  }
})

test_that("the one documented exception: differentiated = FALSE", {
  expect_identical(formals(voi_partition)$differentiated, FALSE)
  expect_null(formals(voi_partition)$profiles)
  expect_true(exists("w_atkinson"))
})

test_that("timing, subgroup_aggregation, type and attributes are gone (handoff v5); w_atkinson() is back (v8)", {
  for (fn in c("voi_partition", "fairness_screen", "marginalisation_count", "baseline_pair"))
    expect_false(any(c("timing", "subgroup_aggregation", "type", "attributes") %in%
                       names(formals(get(fn)))), info = fn)
  for (gone in c("w_on_attributes", "w_attribute_floor", "a_weighted_sum"))
    expect_false(exists(gone), info = gone)
})

test_that("omitting a valuation argument is an error that names it", {
  set.seed(1)
  nb <- list(a = cbind(sq = 0, x = stats::rnorm(50)),
             b = cbind(sq = 0, x = stats::rnorm(50)))
  p <- c(0.5, 0.5)
  W <- w_utilitarian()

  expect_error(voi_partition(nb), "`p` has no default")
  expect_error(voi_partition(nb, p), "`W` has no default")
  expect_error(fairness_screen(nb, p), "`rules` has no default")
  expect_error(marginalisation_count(nb, p), "`W` has no default")

  mk <- function(ref) nb
  expect_error(baseline_pair(mk), "`references` has no default")
  expect_error(baseline_pair(mk, list(a = 0, b = 1)), "`p` has no default")
  expect_error(baseline_pair(mk, list(a = 0, b = 1), p), "`rules` has no default")

  expect_error(reporting_units(nb), "`units` has no default")

  y <- data.frame(nb_a_x = 1, nb_a_y = 2)
  expect_error(nb_from_mc(y), "`pattern` has no default")
  expect_error(nb_from_mc(y, "nb_{group}_{option}"), "`groups` has no default")
  expect_error(nb_from_mc(y, "nb_{group}_{option}", "a"), "`options` has no default")
})

test_that("named group shares are aligned by name, not by position", {
  set.seed(3)
  nb <- list(a = cbind(sq = 0, x = stats::rnorm(300, 5, 20)),
             b = cbind(sq = 0, x = stats::rnorm(300, -2, 20)),
             c = cbind(sq = 0, x = stats::rnorm(300, 1, 20)))
  pos   <- voi_partition(nb, c(0.2, 0.3, 0.5), w_maximin(), differentiated = TRUE)
  named <- voi_partition(nb, c(c = 0.5, a = 0.2, b = 0.3), w_maximin(), differentiated = TRUE)
  for (k in c("A", "B", "C", "D")) expect_identical(pos[[k]], named[[k]])
  expect_identical(pos$p, named$p)
})

test_that("fidelity_threshold() takes no valuation default either (v7)", {
  for (arg in c("p", "W")) {
    expect_true(arg %in% names(formals(fidelity_threshold)), info = arg)
    expect_false(has_default(fidelity_threshold, arg), info = arg)
  }
  nb <- list(a = cbind(sq = 0, x = c(1, 2)), b = cbind(sq = 0, x = c(2, 1)))
  expect_error(fidelity_threshold(nb), "`p` has no default")
  expect_error(fidelity_threshold(nb, c(0.5, 0.5)), "`W` has no default")
})
