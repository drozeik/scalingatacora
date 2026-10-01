test_that("every factory returns a function of (nb, p)", {
  fs <- list(w_utilitarian(), w_maximin(),
             w_prioritarian(function(x) x), w_atkinson(1), w_constrained())
  for (f in fs) {
    expect_true(is.function(f))
    expect_identical(names(formals(f)), c("nb", "p"))
    expect_length(f(c(1, 2, 3), c(1, 1, 1) / 3), 1L)
  }
})

test_that("utilitarian is the share-weighted sum", {
  W <- w_utilitarian()
  expect_equal(W(c(10, -2), c(0.5, 0.5)), 4)
  expect_equal(W(c(10, -2), c(0.9, 0.1)), 8.8)
})

test_that("maximin ignores the shares and returns the worst-off group", {
  W <- w_maximin()
  expect_equal(W(c(10, -2), c(0.5, 0.5)), -2)
  expect_equal(W(c(10, -2), c(0.99, 0.01)), -2)
})

test_that("prioritarian with a loss counting twice", {
  W <- w_prioritarian(function(z) ifelse(z < 0, 2 * z, z))
  expect_equal(W(c(10, -2), c(0.5, 0.5)), 3)
  expect_equal(W(c(10, 2), c(0.5, 0.5)), 6)               # no loss: utilitarian
  expect_lt(W(c(16, -4), c(0.5, 0.5)), W(c(6, 6), c(0.5, 0.5)))
  expect_error(w_prioritarian(1), "must be a function")
  expect_error(w_prioritarian(), "`u` has no default")
})

# w_atkinson() is back since v8 (restored from 2fb2473 with its tests).
test_that("Atkinson reproduces the known means at eps = 0, 1, 2", {
  x <- c(10, 2); p <- c(0.5, 0.5)
  expect_equal(w_atkinson(0)(x, p), mean(x))                   # arithmetic
  expect_equal(w_atkinson(1)(x, p), sqrt(prod(x)))             # geometric
  expect_equal(w_atkinson(2)(x, p), 1 / mean(1 / x))           # harmonic
})

test_that("Atkinson is decreasing in eps and approaches the minimum", {
  x <- c(10, 2); p <- c(0.5, 0.5)
  vals <- vapply(c(0, 0.5, 1, 2, 5), function(e) w_atkinson(e)(x, p), numeric(1))
  expect_true(all(diff(vals) < 0))
  expect_lt(w_atkinson(20)(x, p), 2.5)                         # approaches min
  expect_gt(w_atkinson(20)(x, p), 2)
})

test_that("Atkinson returns NA with a warning for non-positive values", {
  expect_warning(v <- w_atkinson(1)(c(10, -2), c(0.5, 0.5)), "non-positive")
  expect_true(is.na(v))
  expect_warning(v0 <- w_atkinson(2)(c(10, 0), c(0.5, 0.5)), "non-positive")
  expect_true(is.na(v0))
})

test_that("Atkinson honours the offset convention: shift, evaluate, shift back", {
  shifted <- w_atkinson(1, offset = 100)(c(10, -2), c(0.5, 0.5))
  expect_false(is.na(shifted))
  expect_lt(shifted, 4)                # below the utilitarian value of 4
  expect_equal(shifted, sqrt(110 * 98) - 100)
  expect_equal(w_atkinson(0, offset = 100)(c(10, -2), c(0.5, 0.5)), 4)
  expect_equal(w_atkinson(0, offset = 7)(c(10, 2), c(0.3, 0.7)),
               w_utilitarian()(c(10, 2), c(0.3, 0.7)))
})

test_that("the fairness floor rules options out and is utilitarian otherwise", {
  W <- w_constrained(min_group_nb = 0)
  expect_identical(W(c(10, -2), c(0.5, 0.5)), -Inf)
  expect_equal(W(c(10, 2), c(0.5, 0.5)), 6)
  expect_equal(w_constrained(-5)(c(10, -2), c(0.5, 0.5)), 4)
  expect_identical(w_constrained(3)(c(10, 2), c(0.5, 0.5)), -Inf)
  expect_error(w_constrained("a"), "single number")
})

test_that("all rules are non-decreasing in every component", {
  set.seed(31)
  rules <- list(w_utilitarian(), w_maximin(),
                w_prioritarian(function(x) ifelse(x < 0, 2 * x, x)),
                w_atkinson(0.5, offset = 1000), w_atkinson(1, offset = 1000),
                w_atkinson(2, offset = 1000), w_constrained(-1e6))
  p <- c(0.3, 0.3, 0.4)
  for (W in rules) {
    for (i in 1:50) {
      v <- stats::runif(3, -100, 100)
      k <- sample(3, 1)
      v2 <- v; v2[k] <- v2[k] + stats::runif(1, 0, 50)
      expect_gte(W(v2, p), W(v, p) - 1e-9)
    }
  }
})


test_that("argument validation is strict", {
  expect_error(w_atkinson(), "`eps` has no default")
  expect_error(w_atkinson(-1), "finite number >= 0")
  expect_error(w_atkinson(c(1, 2)), "finite number >= 0")
  expect_error(w_atkinson(Inf), "finite number >= 0")
  expect_error(w_atkinson(1, offset = NA), "single finite number")
  expect_error(w_atkinson(1, offset = c(1, 2)), "single finite number")
})
