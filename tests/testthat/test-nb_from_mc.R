# nb_from_mc(): flat Monte Carlo output -> nb_list. It selects columns and
# values nothing (handoff-code-atacora-v3.md, section 5).

mk_y <- function(S = 50, seed = 7) {
  set.seed(seed)
  cols <- as.vector(outer(c("inc", "time"), outer(c("a", "b"), c("x", "y", "z"),
                                                    paste, sep = "_"), paste, sep = "_"))
  y <- as.data.frame(matrix(stats::rnorm(S * length(cols)), S, length(cols),
                            dimnames = list(NULL, cols)))
  y$other <- stats::runif(S)
  y
}

test_that("one outcome: an S x D matrix per group, columns in option order", {
  y <- mk_y()
  nb <- nb_from_mc(y, "inc_{group}_{option}", groups = c(first = "a", second = "b"),
                   options = c("z", "x"))
  expect_identical(names(nb), c("first", "second"))
  for (g in names(nb)) {
    expect_true(is.matrix(nb[[g]]))
    expect_identical(dim(nb[[g]]), c(50L, 2L))
    expect_identical(colnames(nb[[g]]), c("z", "x"))
  }
  expect_identical(nb$first[, "z"], y$inc_a_z)
  expect_identical(nb$second[, "x"], y$inc_b_x)
})

test_that("unnamed codes name themselves; named ones are relabelled", {
  y <- mk_y()
  nb <- nb_from_mc(y, "inc_{group}_{option}", groups = c("a", "b"),
                   options = c(opt1 = "x", opt2 = "y"))
  expect_identical(names(nb), c("a", "b"))
  expect_identical(colnames(nb$a), c("opt1", "opt2"))
  expect_identical(nb$b[, "opt2"], y$inc_b_y)
})

test_that("several outcomes: an S x D x K array per group via nb_array()", {
  y <- mk_y()
  nb <- nb_from_mc(y, "{attribute}_{group}_{option}", groups = c("a", "b"),
                   options = c("x", "y", "z"),
                   attributes = c(money = "inc", hours = "time"))
  for (g in names(nb)) {
    expect_identical(dim(nb[[g]]), c(50L, 3L, 2L))
    expect_identical(dimnames(nb[[g]])[[2]], c("x", "y", "z"))
    expect_identical(dimnames(nb[[g]])[[3]], c("money", "hours"))
  }
  expect_identical(nb$a[, "y", "hours"], y$time_a_y)
  expect_identical(nb$b[, "z", "money"], y$inc_b_z)
})

test_that("an mcSimulation-like object is read through its element y", {
  y <- mk_y()
  mc <- list(y = y, x = data.frame(p = stats::runif(nrow(y))))
  expect_identical(nb_from_mc(mc, "inc_{group}_{option}", c("a", "b"), c("x", "y")),
                   nb_from_mc(y, "inc_{group}_{option}", c("a", "b"), c("x", "y")))
})

test_that("the result feeds the layer-1 functions unchanged", {
  y <- mk_y(S = 300)
  nb <- nb_from_mc(y, "inc_{group}_{option}", c(a = "a", b = "b"), c("x", "y", "z"))
  by_hand <- list(a = cbind(x = y$inc_a_x, y = y$inc_a_y, z = y$inc_a_z),
                  b = cbind(x = y$inc_b_x, y = y$inc_b_y, z = y$inc_b_z))
  p <- c(a = 0.3, b = 0.7)
  expect_identical(vp(nb, p, w_maximin(), differentiated = TRUE)[c("A", "B", "C", "D")],
                   vp(by_hand, p, w_maximin(), differentiated = TRUE)[c("A", "B", "C", "D")])
})

test_that("a missing column is an error that names it", {
  y <- mk_y()
  expect_error(nb_from_mc(y, "inc_{group}_{option}", c("a", "b"), c("x", "w")),
               "not found.*inc_a_w")
  expect_error(nb_from_mc(y, "{attribute}_{group}_{option}", "a", "x",
                          attributes = c("inc", "cons")),
               "cons_a_x")
})

test_that("pattern, placeholders and codes are validated", {
  y <- mk_y()
  expect_error(nb_from_mc(y, "inc_{option}", "a", "x"), "placeholder \\{group\\}")
  expect_error(nb_from_mc(y, "inc_{group}", "a", "x"), "placeholder \\{option\\}")
  expect_error(nb_from_mc(y, "{attribute}_{group}_{option}", "a", "x"),
               "`attributes` is NULL")
  expect_error(nb_from_mc(y, "inc_{group}_{option}", "a", "x", attributes = "inc"),
               "no placeholder \\{attribute\\}")
  expect_error(nb_from_mc(y, c("a", "b"), "a", "x"), "single string")
  expect_error(nb_from_mc(y, "inc_{group}_{option}", c("a", "a"), "x"), "unique")
  expect_error(nb_from_mc(y, "inc_{group}_{option}", c(u = "a", u = "b"), "x"),
               "unique")
  expect_error(nb_from_mc(y, "inc_{group}_{option}", character(0), "x"),
               "non-empty")
  expect_error(nb_from_mc(y, "inc_{group}_{option}", 1, "x"), "character")
  expect_error(nb_from_mc(list(x = y), "inc_{group}_{option}", "a", "x"),
               "element `y`")
  expect_error(nb_from_mc(y, "inc_{group}_{option}", "a", c("x", "")), "non-empty")
  y3 <- data.frame(n_a_x = 1:3 + 0, n_b_x = c("p", "q", "r"))
  expect_error(nb_from_mc(y3, "n_{group}_{option}", c("a", "b"), "x"),
               "not numeric.*n_b_x")
})

test_that("generated names that collide are refused", {
  y <- data.frame(n_abc = 1)
  expect_error(nb_from_mc(y, "n_{group}{option}", c("a", "ab"), c("bc", "c")),
               "same column name")
})
