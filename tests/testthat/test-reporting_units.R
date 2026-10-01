# Axis 3: the reporting unit. reporting_units() re-expresses a group-level
# model in other units via explicit linear combinations.

mk_four <- function(S = 800, seed = 31, arrays = FALSE) {
  set.seed(seed)
  e <- function(m, s) stats::rnorm(S, m, s)
  grp <- function(m1, m2) {
    m <- cbind(sq = 0, o1 = e(m1, 40), o2 = e(m2, 25))
    if (arrays) nb_array(money = m, time = cbind(sq = 0, o1 = e(-1, 1), o2 = e(1, 1)))
    else m
  }
  list(c1_x = grp(30, 5), c2_x = grp(-10, 12), c1_y = grp(8, 20), c2_y = grp(-15, 18))
}
size <- c(c1_x = 15, c2_x = 17, c1_y = 10, c2_y = 13)

test_that("identity units reproduce the input", {
  nb <- mk_four()
  id <- lapply(names(nb), function(g) stats::setNames(1, g))
  names(id) <- names(nb)
  expect_identical(reporting_units(nb, id), nb)
})

test_that("a sum and a share-weighted mean are built attribute by attribute", {
  nb <- mk_four(arrays = TRUE)
  ru <- reporting_units(nb, list(
    pair_c1 = c(c1_x = 1, c1_y = 1),
    mean_x  = c(c1_x = 15 / 32, c2_x = 17 / 32)))
  expect_identical(names(ru), c("pair_c1", "mean_x"))
  expect_equal(ru$pair_c1, nb$c1_x + nb$c1_y)
  expect_equal(ru$mean_x[, , "time"],
               (15 * nb$c1_x[, , "time"] + 17 * nb$c2_x[, , "time"]) / 32)
  expect_identical(dim(ru$pair_c1), dim(nb$c1_x))
  expect_identical(dimnames(ru$pair_c1), dimnames(nb$c1_x))
})

test_that("matrices in give matrices out", {
  ru <- reporting_units(mk_four(), list(u = c(c1_x = 0.5, c2_x = 0.5)))
  expect_true(is.matrix(ru$u))
  expect_identical(colnames(ru$u), c("sq", "o1", "o2"))
})

test_that("coarsening keeps A and C and cannot raise B or D (utilitarian)", {
  # Partition the four groups into two units with share-weighted means and
  # unit shares equal to the summed group shares. The aggregate is unchanged,
  # so A and C are identical; differentiation is coarser, so B and D can only
  # fall. The reporting unit decides how much heterogeneity is visible.
  nb <- mk_four()
  p <- size / sum(size)
  units <- list(ux = c(c1_x = 15, c2_x = 17) / 32,
                uy = c(c1_y = 10, c2_y = 13) / 23)
  p_units <- c(ux = 32, uy = 23) / 55
  fine   <- voi_partition(nb, p, w_utilitarian(), differentiated = TRUE)
  coarse <- voi_partition(reporting_units(nb, units), p_units, w_utilitarian(),
                          differentiated = TRUE)
  expect_equal(coarse$A, fine$A, tolerance = 1e-10)
  expect_equal(coarse$C, fine$C, tolerance = 1e-10)
  expect_lte(coarse$B, fine$B + 1e-10)
  expect_lte(coarse$D, fine$D + 1e-10)
  expect_lte(coarse$VoH_static, fine$VoH_static + 1e-10)
})

test_that("reporting_units validates its units", {
  nb <- mk_four()
  expect_error(reporting_units(nb, list(u = c(nope = 1))), "unknown group")
  expect_error(reporting_units(nb, list(u = c(1, 1))), "named by group")
  expect_error(reporting_units(nb, list(u = c(c1_x = NA))), "finite")
  expect_error(reporting_units(nb, list(c(c1_x = 1))), "must be named")
  expect_error(reporting_units(nb, list()), "non-empty")
})
