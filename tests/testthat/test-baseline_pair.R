# baseline_pair(model, references, p, rules, units = NULL): the same decision against
# two reference states (axis 2), handoff v5.

mk_model <- function(S = 1200, seed = 99) {
  function(claim) {
    set.seed(seed)
    list(g1 = cbind(status_quo = 0, scale = stats::rnorm(S, 60, 150) - claim),
         g2 = cbind(status_quo = 0, scale = stats::rnorm(S, 15, 150) - claim))
  }
}
util <- list(utilitarian = w_utilitarian())

test_that("baseline_pair returns outcomes and rules for both references", {
  bp <- baseline_pair(mk_model(), list(today = 0, entitled = 40), p = c(0.6, 0.4),
                      rules = list(utilitarian = w_utilitarian(), maximin = w_maximin()))
  expect_s3_class(bp, "baseline_pair")
  expect_identical(nrow(bp$outcomes), 2L * 1L * 2L)             # groups x outcomes x options
  expect_true(all(c("mean_today", "mean_entitled", "p_positive_today", "p_positive_entitled",
                    "difference", "recommended_today", "recommended_entitled", "flip")
                  %in% names(bp$outcomes)))
  expect_equal(bp$outcomes$difference, bp$outcomes$mean_entitled - bp$outcomes$mean_today)
  expect_identical(nrow(bp$rules), 2L * 2L)                     # rules x references
  expect_identical(names(bp$rules), c("rule", "outcome", "reference", "option", "p_ahead", "EVPI", "flip"))
  m <- mk_model()(40)
  x <- voi_partition(m, c(0.6, 0.4), w_maximin())
  r <- bp$rules[bp$rules$rule == "maximin" & bp$rules$reference == "entitled", ]
  expect_equal(r$EVPI, x$EVPI); expect_identical(r$option, x$d_star); expect_equal(r$p_ahead, x$p_ahead)
})

test_that("an identical reference state gives identical results and no flip", {
  bp <- baseline_pair(mk_model(), list(a = 12, b = 12), p = c(0.6, 0.4), rules = util)
  expect_true(all(abs(bp$outcomes$difference) < 1e-12))
  expect_false(any(bp$outcomes$flip))
  expect_false(any(bp$rules$flip))
})

test_that("a harsher reference state can flip the recommendation", {
  bp <- baseline_pair(mk_model(), list(today = 0, entitled = 200), p = c(0.6, 0.4), rules = util)
  expect_identical(bp$rules$option, c("scale", "status_quo"))
  expect_true(all(bp$rules$flip))
})

test_that("several outcomes: every outcome reported, rules applied per outcome", {
  set.seed(3); S <- 300
  base <- list(g1 = nb_array(money = cbind(sq = 0, x = stats::rnorm(S, 5, 3)),
                             hours = cbind(sq = 0, x = stats::rnorm(S, -1, 1))),
               g2 = nb_array(money = cbind(sq = 0, x = stats::rnorm(S, 2, 3)),
                             hours = cbind(sq = 0, x = stats::rnorm(S, 1, 1))))
  model <- function(claim) lapply(base, function(a) { a[, "x", "money"] <- a[, "x", "money"] - claim; a })
  bp <- baseline_pair(model, list(r1 = 0, r2 = 10), p = c(1, 1), rules = util,
                      units = list(both = c(g1 = 1, g2 = 1)))
  expect_setequal(unique(bp$outcomes$unit), c("g1", "g2", "both"))
  expect_setequal(unique(bp$outcomes$outcome), c("money", "hours"))
  expect_identical(nrow(bp$rules), 1L * 2L * 2L)                # rules x outcomes x references
  hrs <- bp$rules[bp$rules$outcome == "hours", ]
  expect_false(any(hrs$flip))                                   # the claim is on money only
  both <- bp$outcomes[bp$outcomes$unit == "both" & bp$outcomes$outcome == "money" & bp$outcomes$option == "x", ]
  expect_equal(both$mean_r1, mean(base$g1[, "x", "money"] + base$g2[, "x", "money"]))
})

test_that("baseline_pair rejects incomparable model output and malformed references", {
  bad <- function(ref) {
    if (ref == 0) list(a = cbind(sq = 0, x = stats::rnorm(10)))
    else list(a = cbind(sq = 0, y = stats::rnorm(10)))
  }
  expect_error(baseline_pair(bad, list(a = 0, b = 1), p = 1, rules = util),
               "different groups, options, outcomes")
  expect_error(baseline_pair("not a function", list(a = 0, b = 1), p = 1, rules = util),
               "must be a function")
  expect_error(baseline_pair(mk_model(), list(0, 1), p = c(1, 1), rules = util), "named list of two")
  expect_error(baseline_pair(mk_model(), list(a = 0, b = 1, c = 2), p = c(1, 1), rules = util),
               "named list of two")
})
