skip_if_not_installed("decisionSupport")
skip_if_not_installed("fANCOVA")

# What decisionSupport::multi_EVPI() computes -- see FUNCTIONS.md, Step 11.
#
# empirical_EVPI(mc, test_var, out_var) sorts the draws by the input variable,
# fits a loess smoother of the output on that input to obtain E[out | input],
# weights it with a NORMAL density fitted to the input's sample mean and sd, and
# integrates the positive and the negative part separately. multi_EVPI() repeats
# this for every input column and picks the part that matches the sign of the
# average expected gain. The result is therefore the *partial* EVPI (EVPPI) of
# ONE input, for a binary do/don't decision on the SIGN of one output variable.
#
# It follows that it coincides with the total EVPI of a two-option decision only
# when (i) there is exactly one uncertain input and (ii) that input is
# approximately normal. Both tests below are built on that reading.

ds_evpi <- function(mc, out_var, test_var) {
  invisible(utils::capture.output(
    res <- decisionSupport::multi_EVPI(mc, first_out_var = out_var)))
  res[[out_var]]$EVPI[res[[out_var]]$variable == test_var]
}

test_that("with a single normal input, multi_EVPI equals the EVPI", {
  # Tolerance: 4 % relative at 6e3 draws. Justified by the calibration in
  # analysis/02_voi_partition_checks.R, which runs the same comparison over a
  # grid of seeds, means and sample sizes and reports the relative deviation
  # against the analytic value E[max(0, -NPV)] = sd*dnorm(mu/sd) - mu*pnorm(-mu/sd).
  # The observed deviation is Monte Carlo noise plus the loess/quadrature step
  # and shrinks roughly with 1/sqrt(n); 6e3 draws keeps the loess affordable.
  for (mu in c(-30, 0, 30)) {
    set.seed(100 + mu)
    n <- 6000
    x <- stats::rnorm(n, mu, 100)
    mc <- data.frame(price_premium = x, NPV = x)

    ds   <- ds_evpi(mc, "NPV", "price_premium")
    ours <- vp(list(one = cbind(status_quo = 0, scale = x)),
                          p = 1)$EVPI

    expect_equal(ds, ours, tolerance = 0.04, info = paste("mu =", mu))
  }
})

test_that("the equivalence survives a non-linear but deterministic model", {
  set.seed(303)
  n <- 6000
  x <- stats::rnorm(n, 0.5, 0.35)              # e.g. an adoption share
  npv <- 400 * (x - 0.45) - 250 * (x - 0.45)^2  # smooth, monotone on the range
  mc <- data.frame(adoption = x, NPV = npv)

  ds   <- ds_evpi(mc, "NPV", "adoption")
  ours <- vp(list(one = cbind(status_quo = 0, scale = npv)),
                        p = 1)$EVPI
  expect_equal(ds, ours, tolerance = 0.05)
})

test_that("multi_EVPI is a PER-INPUT EVPI, not the total EVPI", {
  # Two independent uncertain inputs. Each partial EVPI is strictly below the
  # total, and their sum need not equal it either: EVPPI is not additive.
  set.seed(404)
  n <- 6000
  a <- stats::rnorm(n, 20, 120)
  b <- stats::rnorm(n, 10, 120)
  npv <- a + b
  mc <- data.frame(yield_gain = a, price_gain = b, NPV = npv)

  ds_a <- ds_evpi(mc, "NPV", "yield_gain")
  ds_b <- ds_evpi(mc, "NPV", "price_gain")
  total <- vp(list(one = cbind(status_quo = 0, scale = npv)),
                         p = 1)$EVPI

  expect_lt(ds_a, total)
  expect_lt(ds_b, total)
  expect_gt(total, 0)
  # neither input alone explains the information value
  expect_lt(ds_a / total, 0.9)
  expect_lt(ds_b / total, 0.9)
})

test_that("multi_EVPI has no counterpart for a decision with three options", {
  # decisionSupport frames the decision as the sign of ONE output variable, so a
  # three-option comparison cannot be expressed. voi_partition() handles it
  # directly; this test only pins down that the option dimension is real.
  set.seed(505)
  n <- 5000
  nb <- list(one = cbind(status_quo = 0,
                         o1 = stats::rnorm(n, 40, 200),
                         o2 = stats::rnorm(n, 55, 90)))
  x3 <- vp(nb, p = 1)
  x2 <- vp(list(one = nb$one[, c("status_quo", "o1")]), p = 1)
  expect_gt(x3$EVPI, x2$EVPI)
  expect_identical(x3$n_options, 3L)
})
