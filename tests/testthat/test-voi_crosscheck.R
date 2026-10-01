skip_if_not_installed("voi")

test_that("EVPI agrees with voi::evpi in the aggregate and per group", {
  set.seed(21)
  S <- 5000
  nb <- list(
    g1 = cbind(status_quo = 0, o1 = stats::rnorm(S, 120, 300),
              o2 = stats::rnorm(S, 80, 150)),
    g2 = cbind(status_quo = 0, o1 = stats::rnorm(S, -40, 200),
              o2 = stats::rnorm(S, 110, 140))
  )
  p <- c(0.55, 0.45)

  # aggregate: voi::evpi on the share-weighted net benefit
  nb_agg <- Reduce(`+`, Map(function(m, w) w * m, nb, p))
  x <- vp(nb, p)
  expect_equal(x$EVPI, as.numeric(voi::evpi(nb_agg)), tolerance = 1e-10)

  # per group: EVPI of each group's own decision
  for (g in names(nb)) {
    xg <- vp(nb[g], p = 1)
    expect_equal(xg$EVPI, as.numeric(voi::evpi(nb[[g]])), tolerance = 1e-10,
                 info = g)
  }
})

test_that("EVPI_sub is the share-weighted sum of the group EVPIs", {
  set.seed(22)
  S <- 4000
  nb <- list(a = cbind(sq = 0, o1 = stats::rnorm(S, 20, 90),
                       o2 = stats::rnorm(S, 10, 40)),
             b = cbind(sq = 0, o1 = stats::rnorm(S, -15, 90),
                       o2 = stats::rnorm(S, 25, 40)))
  p <- c(0.6, 0.4)
  x <- vp(nb, p, differentiated = TRUE)
  evpi_g <- vapply(nb, function(m) as.numeric(voi::evpi(m)), numeric(1))
  # D - B = sum_g p_g (E max_d NB_g - max_d E NB_g) = sum_g p_g EVPI_g
  expect_equal(x$EVPI_sub, sum(p * evpi_g), tolerance = 1e-10)
})
