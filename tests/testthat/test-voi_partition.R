# voi_partition(): EVPI first; B, D and the values of heterogeneity only with
# differentiated = TRUE (handoff v5, 3.7). Ex post and planner only (3.1, 3.2).

# Reference implementation from the handoff (utilitarian case).
ref_partition <- function(nb_list, p) {
  p <- p / sum(p)
  nb_agg <- Reduce(`+`, Map(function(m, w) w * m, nb_list, p))
  list(A = max(colMeans(nb_agg)),
       C = mean(apply(nb_agg, 1, max)),
       B = sum(mapply(function(m, w) w * max(colMeans(m)), nb_list, p)),
       D = sum(mapply(function(m, w) w * mean(apply(m, 1, max)), nb_list, p)))
}

make_nb <- function(S = 2000, seed = 42) {
  set.seed(seed)
  list(
    g1 = cbind(sq = 0, o1 = stats::rnorm(S,  120, 300), o2 = stats::rnorm(S,  80, 150)),
    g2 = cbind(sq = 0, o1 = stats::rnorm(S,   60, 250), o2 = stats::rnorm(S,  95, 160)),
    g3 = cbind(sq = 0, o1 = stats::rnorm(S,  -40, 200), o2 = stats::rnorm(S, 110, 140)),
    g4 = cbind(sq = 0, o1 = stats::rnorm(S,   20, 220), o2 = stats::rnorm(S,  70, 130))
  )
}

test_that("the default output is EVPI, A and C; the decision per group is opt-in", {
  x <- vp(make_nb(), c(15, 17, 10, 13))
  expect_s3_class(x, "voi_partition")
  expect_equal(x$EVPI, x$C - x$A)
  expect_false(x$differentiated)
  expect_true(all(c("EVPI", "A", "C", "d_star", "p_ahead", "criterion") %in% names(x)))
  expect_false(any(c("B", "D", "VoH_static", "EVPI_sub", "VoH_dyn") %in% names(x)))
  y <- vp(make_nb(), c(15, 17, 10, 13), differentiated = TRUE)
  expect_true(all(c("B", "D", "VoH_static", "EVPI_sub", "VoH_dyn") %in% names(y)))
  expect_equal(y[c("EVPI", "A", "C", "d_star", "p_ahead")], x[c("EVPI", "A", "C", "d_star", "p_ahead")])
})

test_that("the utilitarian case matches the reference implementation exactly", {
  nb <- make_nb()
  p  <- c(15, 17, 10, 13)
  ref <- ref_partition(nb, p)
  x <- vp(nb, p, differentiated = TRUE)
  for (k in c("A", "B", "C", "D"))
    expect_equal(x[[k]], ref[[k]], tolerance = 1e-10, info = k)
})

test_that("derived quantities are the documented differences", {
  x <- vp(make_nb(), c(15, 17, 10, 13), differentiated = TRUE)
  expect_equal(x$VoH_static, x$B - x$A)
  expect_equal(x$EVPI,       x$C - x$A)
  expect_equal(x$EVPI_sub,   x$D - x$B)
  expect_equal(x$VoH_dyn,    x$D - x$C)
  expect_equal(voh_index(x), (x$B - x$A) / (x$C - x$A))
  # the two ways to D - A
  expect_equal(x$VoH_static + x$EVPI_sub, x$EVPI + x$VoH_dyn)
})

test_that("p_ahead is the share of draws in which the recommended option is best", {
  nb <- make_nb(S = 500)
  x <- vp(nb, c(1, 1, 1, 1))
  agg <- Reduce(`+`, nb) / 4
  expect_equal(x$p_ahead, mean(max.col(agg, ties.method = "first") == match(x$d_star, colnames(agg))))
})

test_that("sign properties hold for every non-decreasing rule (planner, ex post)", {
  nb <- make_nb()
  p  <- c(15, 17, 10, 13)
  rules <- list(
    utilitarian  = w_utilitarian(),
    maximin      = w_maximin(),
    prioritarian = w_prioritarian(function(x) ifelse(x < 0, 2 * x, x)),
    constrained  = w_constrained(min_group_nb = -1e9)
  )
  for (nm in names(rules)) {
    x <- vp(nb, p, W = rules[[nm]], differentiated = TRUE)
    expect_gte(x$EVPI,       -1e-8)
    expect_gte(x$VoH_static, -1e-8)
    expect_gte(x$EVPI_sub,   -1e-8)
    expect_gte(x$VoH_dyn,    -1e-8)
  }
})

test_that("the per-draw shortcut for D equals brute-force enumeration of profiles", {
  set.seed(12)
  S <- 40
  nb <- list(a = cbind(sq = 0, o1 = stats::rnorm(S, 5, 10), o2 = stats::rnorm(S, 2, 10)),
             b = cbind(sq = 0, o1 = stats::rnorm(S, -2, 10), o2 = stats::rnorm(S, 1, 10)))
  prof <- expand.grid(1:3, 1:3)
  for (W in list(w_maximin(), w_prioritarian(function(z) ifelse(z < 0, 2 * z, z)))) {
    x <- voi_partition(nb, c(1, 1), W, differentiated = TRUE)
    brute <- mean(vapply(seq_len(S), function(s) max(vapply(seq_len(nrow(prof)), function(i)
      W(c(nb$a[s, prof[i, 1]], nb$b[s, prof[i, 2]]), c(0.5, 0.5)), numeric(1))), numeric(1)))
    expect_equal(x$D, brute, tolerance = 1e-12)
  }
})

test_that("VoH_static is zero when the same option is best for every group", {
  set.seed(7)
  S <- 3000
  nb <- list(
    a = cbind(status_quo = 0, scale = stats::rnorm(S, 50, 100)),
    b = cbind(status_quo = 0, scale = stats::rnorm(S, 30, 100)),
    c = cbind(status_quo = 0, scale = stats::rnorm(S, 80, 100))
  )
  x <- vp(nb, c(0.2, 0.5, 0.3), differentiated = TRUE)
  expect_true(all(x$d_star_group == "scale"))
  expect_identical(x$d_star, "scale")
  expect_equal(x$VoH_static, 0, tolerance = 1e-10)
})

test_that("with a single group B equals A and D equals C, for every rule", {
  set.seed(11)
  nb <- list(only = cbind(status_quo = 0, scale = stats::rnorm(2000, 10, 40),
                          scale_hard = stats::rnorm(2000, 8, 15)))
  rules <- list(utilitarian  = w_utilitarian(),
                maximin      = w_maximin(),
                prioritarian = w_prioritarian(function(x) ifelse(x < 0, 2 * x, x)))
  for (nm in names(rules)) {
    x <- vp(nb, p = 1, W = rules[[nm]], differentiated = TRUE)
    expect_equal(x$B, x$A, tolerance = 1e-10, info = nm)
    expect_equal(x$D, x$C, tolerance = 1e-10, info = nm)
    expect_equal(x$VoH_static, 0, tolerance = 1e-10, info = nm)
    expect_equal(x$VoH_dyn, 0, tolerance = 1e-10, info = nm)
  }
})

test_that("group shares are normalised", {
  nb <- make_nb(S = 500)
  a <- vp(nb, p = c(15, 17, 10, 13), differentiated = TRUE)
  b <- vp(nb, p = c(15, 17, 10, 13) / 55, differentiated = TRUE)
  expect_equal(a$A, b$A); expect_equal(a$D, b$D)
  expect_equal(unname(a$p), c(15, 17, 10, 13) / 55)
})

test_that("voh_index guards the degenerate denominator and needs the decision per group", {
  nb <- list(a = cbind(status_quo = 0, scale = rep(10, 100)))  # no uncertainty
  x <- vp(nb, p = 1, differentiated = TRUE)
  expect_equal(x$C, x$A, tolerance = 1e-12)
  vi <- voh_index(x)
  expect_true(is.na(vi))
  expect_match(attr(vi, "reason"), "no information value")
  expect_error(voh_index(vp(nb, p = 1)), "differentiated = TRUE")
})

test_that("input validation rejects malformed nb_list, p and differentiated", {
  m <- cbind(a = 0, b = stats::rnorm(10))
  expect_error(vp(list(), p = 1), "non-empty list")
  expect_error(vp(list(x = m, y = m[1:5, ]), p = c(1, 1)), "same dimensions")
  expect_error(vp(list(x = m), p = c(1, 2)), "one share per group")
  expect_error(vp(list(x = m), p = -1), "non-negative")
  expect_error(vp(list(x = m, y = m[, 2:1]), p = c(1, 1)),
               "Column names \\(options\\) differ")
  expect_error(vp(list(x = m, x = m), p = c(1, 1)), "non-empty and unique")
  expect_error(vp(list(x = m, y = m), p = c(x = 1, z = 1)), "do not match")
  expect_error(vp(list(x = m), p = 1, differentiated = NA), "TRUE or FALSE")
  two <- nb_array(money = m, hours = m)
  expect_error(vp(list(x = two), p = 1), "one outcome at a time")
})

test_that("the decision per group refuses to enumerate too many profiles", {
  set.seed(9)
  S <- 50
  nb <- lapply(1:6, function(i)
    matrix(stats::rnorm(S * 8), S, 8, dimnames = list(NULL, paste0("opt", 1:8))))
  names(nb) <- paste0("g", 1:6)
  expect_error(vp(nb, p = rep(1, 6), W = w_maximin(), differentiated = TRUE,
                  max_profiles = 1e4), "would enumerate")
  expect_silent(vp(nb, p = rep(1, 6), W = w_maximin()))   # one decision for all: no enumeration
})

# ---- restricted profiles (v8 order, 3b) ------------------------------------

rules_all <- list(
  utilitarian  = w_utilitarian(),
  maximin      = w_maximin(),
  prioritarian = w_prioritarian(function(x) ifelse(x < 0, 2 * x, x)),
  atkinson     = w_atkinson(1, offset = 5000))

test_that("profiles listing every profile give the same result as NULL", {
  nb <- make_nb(S = 800)[1:3]
  p  <- c(15, 17, 10)
  all_prof <- as.matrix(expand.grid(g1 = colnames(nb$g1), g2 = colnames(nb$g1),
                                    g3 = colnames(nb$g1), stringsAsFactors = FALSE))
  for (nm in names(rules_all)) {
    a <- voi_partition(nb, p, rules_all[[nm]], differentiated = TRUE)
    b <- voi_partition(nb, p, rules_all[[nm]], differentiated = TRUE, profiles = all_prof)
    for (k in c("A", "B", "C", "D", "VoH_static", "EVPI_sub", "VoH_dyn"))
      expect_equal(b[[k]], a[[k]], tolerance = 1e-10, info = paste(nm, k))
    expect_identical(b$planner_profile, a$planner_profile, info = nm)
    expect_false(a$restricted); expect_true(b$restricted)
  }
})

test_that("a restriction can only lower B and D", {
  nb <- make_nb(S = 800)[1:2]
  p  <- c(1, 1)
  allowed <- rbind(c("sq", "sq"), c("o1", "o1"), c("o2", "o2"), c("o1", "sq"),
                   c("sq", "o1"))
  for (nm in names(rules_all)) {
    free <- voi_partition(nb, p, rules_all[[nm]], differentiated = TRUE)
    res  <- voi_partition(nb, p, rules_all[[nm]], differentiated = TRUE, profiles = allowed)
    expect_lte(res$B, free$B + 1e-10)
    expect_lte(res$D, free$D + 1e-10)
    expect_gte(res$B, res$A - 1e-10)          # every diagonal profile is allowed
    expect_gte(res$D, res$C - 1e-10)
    expect_equal(res[c("A", "C", "EVPI")], free[c("A", "C", "EVPI")])
  }
})

test_that("with only the diagonal profiles B = A and D = C", {
  nb <- make_nb(S = 800)
  p  <- c(15, 17, 10, 13)
  diag_prof <- t(vapply(colnames(nb$g1), function(o) rep(o, 4), character(4)))
  colnames(diag_prof) <- names(nb)
  for (nm in names(rules_all)) {
    x <- voi_partition(nb, p, rules_all[[nm]], differentiated = TRUE, profiles = diag_prof)
    expect_equal(x$B, x$A, tolerance = 1e-10, info = nm)
    expect_equal(x$D, x$C, tolerance = 1e-10, info = nm)
    expect_equal(x$VoH_static, 0, tolerance = 1e-10, info = nm)
    expect_equal(x$VoH_dyn, 0, tolerance = 1e-10, info = nm)
    expect_equal(x$EVPI_sub, x$EVPI, tolerance = 1e-10, info = nm)
  }
})

test_that("restricted D is the per-draw maximum over the allowed profiles", {
  set.seed(13)
  S <- 60
  nb <- list(a = cbind(sq = 0, o1 = stats::rnorm(S, 5, 10), o2 = stats::rnorm(S, 2, 10)),
             b = cbind(sq = 0, o1 = stats::rnorm(S, -2, 10), o2 = stats::rnorm(S, 1, 10)))
  allowed <- rbind(c(1, 1), c(2, 1), c(1, 2), c(2, 2), c(3, 3))   # o2 only for all
  for (W in rules_all[c("utilitarian", "maximin", "prioritarian")]) {
    x <- voi_partition(nb, c(1, 1), W, differentiated = TRUE, profiles = allowed)
    per_draw <- vapply(seq_len(S), function(s) max(vapply(seq_len(nrow(allowed)), function(i)
      W(c(nb$a[s, allowed[i, 1]], nb$b[s, allowed[i, 2]]), c(0.5, 0.5)), numeric(1))), numeric(1))
    expect_equal(x$D, mean(per_draw), tolerance = 1e-12)
    means <- vapply(seq_len(nrow(allowed)), function(i) mean(vapply(seq_len(S), function(s)
      W(c(nb$a[s, allowed[i, 1]], nb$b[s, allowed[i, 2]]), c(0.5, 0.5)), numeric(1))), numeric(1))
    expect_equal(x$B, max(means), tolerance = 1e-12)
  }
})

test_that("profiles are aligned by group name and validated", {
  nb <- make_nb(S = 200)[1:2]
  p <- c(1, 1)
  by_pos  <- rbind(c("sq", "o1"), c("o1", "sq"), c("o1", "o1"), c("sq", "sq"))
  by_name <- by_pos[, 2:1]; colnames(by_name) <- c("g2", "g1")
  a <- voi_partition(nb, p, w_utilitarian(), differentiated = TRUE, profiles = by_pos)
  b <- voi_partition(nb, p, w_utilitarian(), differentiated = TRUE, profiles = by_name)
  expect_equal(a[c("B", "D")], b[c("B", "D")])
  expect_error(voi_partition(nb, p, w_utilitarian(), profiles = by_pos), "differentiated = TRUE")
  expect_error(voi_partition(nb, p, w_utilitarian(), differentiated = TRUE,
                             profiles = rbind(c("sq", "nope"))), "option name or an option")
  expect_error(voi_partition(nb, p, w_utilitarian(), differentiated = TRUE,
                             profiles = rbind(c(1, 1), c(1, 1))), "more than once")
  expect_error(voi_partition(nb, p, w_utilitarian(), differentiated = TRUE,
                             profiles = matrix(1, 1, 3)), "one column")
  bad <- by_pos; colnames(bad) <- c("g1", "zz")
  expect_error(voi_partition(nb, p, w_utilitarian(), differentiated = TRUE,
                             profiles = bad), "do not match")
  expect_error(voi_partition(nb, p, w_utilitarian(), differentiated = TRUE,
                             profiles = rbind(c(1.5, 1))), "option name or an option")
})
