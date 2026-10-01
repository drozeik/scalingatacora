mk_nb <- function(S = 1500, seed = 77) {
  set.seed(seed)
  list(g1 = cbind(status_quo = 0, o1 = stats::rnorm(S, 90, 200),
                  o2 = stats::rnorm(S, 60, 100)),
       g2 = cbind(status_quo = 0, o1 = stats::rnorm(S, -30, 180),
                  o2 = stats::rnorm(S, 85, 110)))
}
rules3 <- list(utilitarian = w_utilitarian(), maximin = w_maximin(),
               prioritarian = w_prioritarian(function(z) ifelse(z < 0, 2 * z, z)))

test_that("fairness_screen returns one row per rule with the documented columns", {
  nb <- mk_nb(); p <- c(0.6, 0.4)
  fs <- fairness_screen(nb, p, rules3)
  expect_s3_class(fs, "fairness_screen")
  expect_identical(names(fs$table),
                   c("rule", "option", "p_ahead", "EVPI", "p_group_loses", "p_hidden_loss"))
  expect_identical(fs$table$rule, names(rules3))
  expect_identical(dim(fs$scores), c(3L, 3L))
  expect_length(fs$rank_correlation, 1L)
  for (i in seq_along(rules3)) {
    part <- voi_partition(nb, p, rules3[[i]])
    expect_identical(fs$table$option[i], part$d_star)
    expect_equal(fs$table$EVPI[i], part$EVPI)
    expect_equal(fs$table$p_ahead[i], part$p_ahead)
    expect_identical(fs$table$option[i], rownames(fs$scores)[which.max(fs$scores[, i])])
  }
})

test_that("P(a group loses) and P(hidden loss) are computed on the recommended option", {
  nb <- mk_nb(); p <- c(0.6, 0.4)
  fs <- fairness_screen(nb, p, list(utilitarian = w_utilitarian()))
  d <- fs$table$option
  loses <- nb$g1[, d] < 0 | nb$g2[, d] < 0
  agg <- 0.6 * nb$g1[, d] + 0.4 * nb$g2[, d]
  expect_equal(fs$table$p_group_loses, mean(loses))
  expect_equal(fs$table$p_hidden_loss, mean(loses & agg > 0))
  expect_equal(fs$table$p_hidden_loss,
               marginalisation_count(nb, p, w_utilitarian())$share)
})

test_that("maximin cannot hide a loss", {
  fs <- fairness_screen(mk_nb(), c(0.6, 0.4), rules3)
  expect_identical(fs$table$p_hidden_loss[fs$table$rule == "maximin"], 0)
})

test_that("the rank correlation is the smallest pairwise Spearman correlation", {
  fs <- fairness_screen(mk_nb(), c(0.6, 0.4), rules3)
  ranks <- apply(-fs$scores, 2, rank, ties.method = "min")
  cm <- stats::cor(ranks, method = "spearman")
  expect_equal(fs$rank_correlation, min(cm[upper.tri(cm)]))
  one <- fairness_screen(mk_nb(), c(0.6, 0.4), list(u = w_utilitarian()))
  expect_true(is.na(one$rank_correlation))
})

test_that("the rule list is an argument, not a fixed menu", {
  nb <- mk_nb(); p <- c(0.6, 0.4)
  custom <- function(nb, p) sum(p * nb) - 0.5 * stats::sd(nb)   # mean - spread penalty
  fs <- fairness_screen(nb, p, list(mine = custom))
  expect_identical(fs$table$rule, "mine")
  expect_true(is.finite(fs$table$EVPI))
  expect_error(fairness_screen(nb, p, list()), "non-empty list")
  expect_error(fairness_screen(nb, p, list(1)), "must be a valuation function")
  expect_error(fairness_screen(nb, p, list(w_utilitarian())), "must be named")
})

test_that("a floor rule that rules options out still yields a finite EVPI", {
  fs <- fairness_screen(mk_nb(), c(0.6, 0.4), list(floor = w_constrained(0)))
  expect_true(any(is.infinite(fs$scores[, "floor"])))
  expect_identical(fs$table$option, "status_quo")
  expect_true(is.finite(fs$table$EVPI))
})

test_that("marginalisation_count reports the hidden loss, overall and per group", {
  nb <- mk_nb(); p <- c(0.6, 0.4)
  mc <- marginalisation_count(nb, p, w_utilitarian())
  expect_s3_class(mc, "marginalisation_count")
  expect_identical(mc$d_star, vp(nb, p)$d_star)
  d <- mc$d_star
  agg <- 0.6 * nb$g1[, d] + 0.4 * nb$g2[, d]
  expect_equal(mc$by_group$share, c(mean(agg > 0 & nb$g1[, d] < 0), mean(agg > 0 & nb$g2[, d] < 0)))
  expect_gte(sum(mc$by_group$share), mc$share)
  expect_lte(max(mc$by_group$share), mc$share)
})

test_that("a dominant option hides no loss", {
  set.seed(88); S <- 1000
  nb <- list(a = cbind(status_quo = 0, scale = stats::runif(S, 10, 50)),
             b = cbind(status_quo = 0, scale = stats::runif(S, 5, 40)))
  mc <- marginalisation_count(nb, c(0.5, 0.5), w_utilitarian())
  expect_identical(mc$d_star, "scale")
  expect_equal(mc$share, 0)
})

test_that("marginalisation_count accepts an explicit option and validates it", {
  nb <- mk_nb(); p <- c(0.6, 0.4)
  by_name <- marginalisation_count(nb, p, w_utilitarian(), d_star = "o1")
  by_index <- marginalisation_count(nb, p, w_utilitarian(), d_star = 2)
  expect_identical(by_name$share, by_index$share)
  expect_identical(by_name$d_star, "o1")
  expect_error(marginalisation_count(nb, p, w_utilitarian(), d_star = "nope"), "does not identify")
  expect_error(marginalisation_count(nb, p, w_utilitarian(), d_star = 99), "does not identify")
})
