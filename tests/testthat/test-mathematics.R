# Independent checks of the formulas: hand calculations on the four draws of the guide,
# direct enumeration, analytic solutions and fixed reference values. The expected results
# are computed without the functions under test.
nb <- list(women = cbind(d0 = 0, dX = c(10, 8, 6, 0), dY = c(1, 2, 1, 2)),
           men = cbind(d0 = 0, dX = c(2, 0, -4, 2), dY = c(4, 2, 3, 3)))
p <- c(women = 0.5, men = 0.5)

test_that("all numbers of the guide's worked example are reproduced", {
  util <- voi_partition(nb, p, w_utilitarian(), differentiated = TRUE)
  mm <- voi_partition(nb, p, w_maximin(), differentiated = TRUE)
  expect_equal(unname(unlist(util[c("A", "B", "C", "D")])), c(3, 4.5, 3.625, 4.75))
  expect_equal(unname(unlist(mm[c("A", "B", "C", "D")])), c(1.5, 2.25, 1.75, 2.75))
  expect_equal(voh_index(util), 2.4)
  expect_equal(voh_index(mm), 3)
  rules <- list(util = w_utilitarian(), mm = w_maximin(),
    prior = w_prioritarian(function(z) ifelse(z < 0, 2 * z, z)),
    atk1 = w_atkinson(1, 10), atk2 = w_atkinson(2, 10), floor = w_constrained(0))
  fs <- fairness_screen(nb, p, rules)
  expect_equal(unname(fs$scores["dX", c("util", "mm", "prior", "floor")]), c(3, -0.5, 2.5, -Inf))
  expect_equal(fs$table$option, c("dX", "dY", "dX", "dX", "dY", "dY"))
  expect_equal(fs$table$p_hidden_loss, c(.25, 0, 0, 0, 0, 0))
  expect_equal(fairness_screen(nb, p, rules[1:5])$rank_correlation, -.5)
  # Atkinson reference computed directly from the geometric/harmonic formula.
  for (d in 1:3) {
    a <- nb$women[, d] + 10
    b <- nb$men[, d] + 10
    expect_equal(fs$scores[d, "atk1"], mean(sqrt(a * b) - 10))
    expect_equal(fs$scores[d, "atk2"], mean(2 / (1 / a + 1 / b) - 10))
  }
  allowed <- rbind(c("d0", "d0"), c("dX", "d0"), c("d0", "dX"), c("dX", "dX"), c("dY", "dY"))
  restricted <- voi_partition(nb, p, w_utilitarian(), TRUE, allowed)
  expect_equal(restricted$B, 3)
  expect_equal(restricted$D, 3.875)
  expect_equal(marginalisation_count(nb, p, w_utilitarian())$by_group$share, c(0, .25))
  expect_equal(fidelity_threshold(nb, p, w_utilitarian())$f_star[2], .75, tolerance = 1e-8)
  expect_equal(fidelity_threshold(nb, p, rules$prior)$f_star[2], .9, tolerance = 1e-8)
})

test_that("values, choices, units and profiles of the worked example hold up", {
  rules <- list(utilitarian = w_utilitarian(), maximin = w_maximin(),
                prioritarian = w_prioritarian(function(z) ifelse(z < 0, 2 * z, z)))
  fs <- fairness_screen(nb, p, rules)
  expect_equal(unname(fs$scores[c("dX", "dY"), ]), cbind(c(3, 2.25), c(-0.5, 1.5), c(2.5, 2.25)))
  expect_equal(fs$table$p_group_loses[1:2], c(0.25, 0))
  # The household as the sum of women and men doubles the utilitarian values and the EVPI.
  household <- voi_partition(reporting_units(nb, list(household = c(women = 1, men = 1))),
                             1, w_utilitarian())
  expect_equal(unname(household$criterion[c("dX", "dY")]), c(6, 4.5))
  expect_equal(household$EVPI, 1.25)
  expect_equal(household$EVPI, 2 * voi_partition(nb, p, w_utilitarian())$EVPI)
  # Renaming and reordering groups and options changes no number.
  renamed <- list(g2 = nb$men[, c("dY", "d0", "dX")], g1 = nb$women[, c("dY", "d0", "dX")])
  renamed <- lapply(renamed, function(m) { colnames(m) <- c("o_y", "o_0", "o_x"); m })
  fs2 <- fairness_screen(renamed, c(g2 = 0.5, g1 = 0.5), rules)
  expect_identical(unname(c(o_y = "dY", o_0 = "d0", o_x = "dX")[fs2$table$option]), fs$table$option)
  columns <- c("EVPI", "p_group_loses", "p_hidden_loss")
  expect_equal(fs2$table[columns], fs$table[columns])
  split <- voi_partition(nb, p, w_utilitarian(), differentiated = TRUE)
  split2 <- voi_partition(renamed, c(g2 = 0.5, g1 = 0.5), w_utilitarian(), differentiated = TRUE)
  expect_equal(unlist(split2[c("A", "B", "C", "D")]), unlist(split[c("A", "B", "C", "D")]))
  # Listing every profile explicitly gives the same values as profiles = NULL.
  every <- as.matrix(expand.grid(women = colnames(nb$women), men = colnames(nb$men),
                                 stringsAsFactors = FALSE))
  listed <- voi_partition(nb, p, w_utilitarian(), differentiated = TRUE, profiles = every)
  expect_equal(unlist(listed[c("A", "B", "C", "D")]), unlist(split[c("A", "B", "C", "D")]))
  # Utilitarian rule values per draw, and the Atkinson fidelity threshold of dX (about 0.8974),
  # here from the explicit geometric-mean formula and uniroot().
  expect_equal(unname(welfare_draws(nb, p, w_utilitarian())),
               cbind(0, c(6, 4, 1, 1), c(2.5, 2, 2, 2.5)))
  target <- mean(sqrt((10 + nb$women[, "dY"]) * (10 + nb$men[, "dY"]))) - 10
  exact <- uniroot(function(f) mean(sqrt((10 + f * nb$women[, "dX"]) * (10 + f * nb$men[, "dX"]))) -
                     10 - target, c(0, 1), tol = 1e-12)$root
  atkinson <- fidelity_threshold(nb, p, w_atkinson(1, 10))
  expect_equal(atkinson$f_star[2], exact, tolerance = 1e-8)
  expect_equal(round(atkinson$f_star[2], 4), 0.8974)
})

test_that("no uncertainty, a dominant option and identical groups or options", {
  flat <- list(women = cbind(sq = 0, A = rep(3, 4), B = rep(1, 4)),
               men = cbind(sq = 0, A = rep(1, 4), B = rep(2, 4)))
  dominant <- list(women = cbind(sq = 0, A = c(5, 6, 7, 8), B = c(1, 2, 1, 2)),
                   men = cbind(sq = 0, A = c(4, 3, 5, 3), B = c(1, 0, 2, 1)))
  expect_equal(voi_partition(flat, p, w_utilitarian())$EVPI, 0)
  expect_equal(voi_partition(dominant, p, w_utilitarian())$EVPI, 0)
  set.seed(1)
  twin <- cbind(sq = 0, A = stats::rnorm(200, 1, 3), B = stats::rnorm(200, 1.2, 2))
  expect_equal(voi_partition(list(women = twin), 1, w_utilitarian())$EVPI,
               voi_partition(list(men = twin), 1, w_utilitarian())$EVPI)
  # One group without losses: the three rules give the same values.
  single <- list(only = cbind(sq = 0, A = c(3, 1, 4, 2), B = c(2, 2, 2, 5)))
  scores <- fairness_screen(single, 1, list(u = w_utilitarian(), m = w_maximin(),
    pr = w_prioritarian(function(z) ifelse(z < 0, 2 * z, z))))$scores
  expect_equal(scores[, "u"], scores[, "m"])
  expect_equal(scores[, "u"], scores[, "pr"])
  # Fidelity of a dominant option is the best other value over its own; identical options need f = 1.
  fd <- fidelity_threshold(dominant, p, w_utilitarian())
  expect_equal(fd$f_star[fd$option == "A"], 1.25 / 5.125, tolerance = 1e-8)
  same <- list(women = cbind(sq = 0, A = c(1, 2, 3, 4), B = c(1, 2, 3, 4)),
               men = cbind(sq = 0, A = c(2, 2, 2, 2), B = c(2, 2, 2, 2)))
  fs <- fidelity_threshold(same, p, w_utilitarian())
  expect_equal(fs$f_star[fs$option %in% c("A", "B")], c(1, 1), tolerance = 1e-8)
})

test_that("on 500 random draws the household sum doubles the EVPI and the floor keeps loss-free options", {
  set.seed(2)
  rnd <- list(women = cbind(sq = 0, A = stats::rnorm(500, 2, 4), B = stats::rnorm(500, 1, 2)),
              men = cbind(sq = 0, A = stats::rnorm(500, 0, 4), B = stats::rnorm(500, 1.5, 3)))
  household <- reporting_units(rnd, list(household = c(women = 1, men = 1)))
  expect_equal(voi_partition(household, 1, w_utilitarian())$EVPI,
               2 * voi_partition(rnd, p, w_utilitarian())$EVPI)
  for (x in list(nb, rnd)) {
    no_loss <- vapply(colnames(x$women), function(d)
      !any(x$women[, d] < 0 | x$men[, d] < 0), logical(1))
    kept <- is.finite(fairness_screen(x, p, list(floor = w_constrained(0)))$scores[, "floor"])
    expect_identical(unname(kept), unname(no_loss))
  }
})

# Reference values for the eight random cases below: voi_partition() of the implementation
# these functions replaced, on the same draws, recorded when both implementations were last
# run side by side (8 October 2026). z, x and y are the expected values V(d) of the options.
reference <- utils::read.csv(colClasses = c("integer", "character", rep("numeric", 4),
                                            "character", rep("numeric", 4)), text = "
trial,rule,A,B,C,D,d_star,p_ahead,z,x,y
1,utilitarian,2.39245045276,2.62184856258,2.87265937449,3.94205037302,y,0.5,1.03373357768,0.716509701934,2.39245045276
1,maximin,1.18844022474,1.34545803652,1.40114925866,3.19980041595,y,0.75,-1.12079388154,-1.67384191882,1.18844022474
1,atkinson_1,2.31492150514,2.49039242182,2.686204156,3.8515567597,y,0.5,0.70957392867,0.411928853179,2.31492150514
2,utilitarian,3.40084420802,3.49665173076,3.99872106439,4.83155228506,z,0.25,3.40084420802,0.430768439005,2.80383516657
2,maximin,0.600488228898,1.37580935494,1.42247886222,2.53733614238,z,0.25,0.600488228898,-1.15276498342,-0.525435978139
2,atkinson_1,3.16545119926,3.23538320254,3.69233197796,4.68872084074,z,0.5,3.16545119926,0.204309594513,2.42973294819
3,utilitarian,2.20454037628,2.59898972539,4.13967263033,4.56164260449,x,0.5,2.11658623868,2.20454037628,-0.243660000432
3,maximin,0.795592450886,0.875924262742,1.97746569884,3.31656868564,z,0.5,0.795592450886,-0.123631368158,-0.980997128587
3,atkinson_1,2.04515888513,2.43580754161,4.03507752127,4.50395225463,x,0.5,2.03892239102,2.04515888513,-0.276717029116
4,utilitarian,2.18780449145,2.95116945306,3.20983434353,4.17107084311,x,0.5,0.465622692229,2.18780449145,1.46940862348
4,maximin,-0.452776810504,1.59956879064,0.505566849082,2.80118136428,x,0.5,-0.538980903744,-0.452776810504,-0.909035847115
4,atkinson_1,1.99832109046,2.87523166806,2.90957783959,4.09890271627,x,0.5,0.340279360865,1.99832109046,1.21286864213
5,utilitarian,2.57616786826,3.23857284324,3.35804236911,3.55459003343,y,0.25,1.58581964637,2.39151587905,2.57616786826
5,maximin,0.801695152652,1.53408449807,1.92795334861,1.92795334861,y,0.25,0.456903262879,0.550402512425,0.801695152652
5,atkinson_1,2.43209093246,3.06137578082,3.17661082292,3.40606791337,y,0.25,1.52658424856,2.07394945385,2.43209093246
6,utilitarian,3.09506114816,3.26799584321,5.40969989626,6.3357449944,y,0.25,2.7038675231,2.39267442171,3.09506114816
6,maximin,0.943484184041,1.47383261495,3.3497811649,5.28044976469,x,0.25,0.0311212209635,0.943484184041,0.82045080961
6,atkinson_1,2.90381362927,3.1145508119,5.22888289031,6.30772899903,y,0.25,2.4022173895,2.26945390841,2.90381362927
7,utilitarian,3.27409887786,3.44191067211,4.23082636474,4.88747397534,x,0.75,2.2191452706,3.27409887786,1.62198061977
7,maximin,2.11444185936,2.92784740881,3.13961938542,4.20898308133,x,0.75,0.810801014944,2.11444185936,0.0683961502509
7,atkinson_1,3.1874520122,3.41005329834,4.1455664955,4.8354282185,x,0.75,2.01202657605,3.1874520122,1.46859722511
8,utilitarian,2.40196604391,2.46229898573,4.11828855714,4.55266865439,x,0.5,1.58976410686,2.40196604391,2.18737251707
8,maximin,1.60859666631,1.60859666631,2.80927266413,3.03579241462,x,0.75,0.53192660911,1.60859666631,-0.314567497058
8,atkinson_1,2.36668079431,2.36668079431,3.84598654885,4.44775110062,x,0.5,1.53806986435,2.36668079431,1.8505556236
")

test_that("profile enumeration agrees with a literal equation evaluator and the reference values", {
  set.seed(761)
  rules <- list(utilitarian = w_utilitarian(), maximin = w_maximin(), atkinson_1 = w_atkinson(1, 10))
  for (trial in 1:8) {
    x <- list(a = matrix(runif(12, -3, 8), 4, 3, dimnames = list(NULL, c("z", "x", "y"))),
              b = matrix(runif(12, -3, 8), 4, 3, dimnames = list(NULL, c("z", "x", "y"))))
    for (rule in names(rules)) {
      W <- rules[[rule]]
      profiles <- expand.grid(a = 1:3, b = 1:3)
      U <- matrix(0, 4, 3)
      R <- matrix(0, 4, 9)
      for (s in 1:4) {
        for (d in 1:3) U[s, d] <- W(c(x$a[s, d], x$b[s, d]), c(.3, .7))
        for (r in 1:9) R[s, r] <- W(c(x$a[s, profiles$a[r]], x$b[s, profiles$b[r]]), c(.3, .7))
      }
      actual <- voi_partition(x, c(.3, .7), W, TRUE)
      expect_equal(actual$A, max(colMeans(U)))
      expect_equal(actual$B, max(colMeans(R)))
      expect_equal(actual$C, mean(apply(U, 1, max)))
      expect_equal(actual$D, mean(apply(R, 1, max)))
      expect_equal(actual$VoH_static + actual$EVPI_sub, actual$EVPI + actual$VoH_dyn)
      expect_true(all(unlist(actual[c("EVPI", "VoH_static", "EVPI_sub", "VoH_dyn")]) >= -1e-12))
      expected <- reference[reference$trial == trial & reference$rule == rule, ]
      expect_equal(unlist(actual[c("A", "B", "C", "D", "p_ahead")]),
                   unlist(expected[c("A", "B", "C", "D", "p_ahead")]), info = paste(trial, rule))
      expect_identical(actual$d_star, expected$d_star, info = paste(trial, rule))
      expect_equal(actual$criterion, unlist(expected[c("z", "x", "y")]), info = paste(trial, rule))
    }
  }
})

test_that("the fidelity formula also finds an interior Atkinson crossing", {
  x <- list(a = cbind(sq = 0, mixed = 100, rival = 2),
            b = cbind(sq = 0, mixed = -9, rival = 2))
  # sqrt((10+100f)(10-9f)) - 10 >= 2
  # <=> -900 f^2 + 910 f - 44 >= 0. Smaller root is the requested minimum.
  # A search that skips every option behind its rival at f = 1 would report NA here.
  exact <- (910 - sqrt(910^2 - 4 * 900 * 44)) / 1800
  actual <- fidelity_threshold(x, c(.5, .5), w_atkinson(1, 10))
  expect_equal(actual$f_star[2], exact, tolerance = 1e-8)
  expect_lt(actual$value[2], actual$best_other[2])
  # A declining negative effect can already tie a rival at zero implementation.
  negative <- list(a = cbind(bad = -10, less_bad = -2))
  expect_equal(fidelity_threshold(negative, 1, w_utilitarian())$f_star, c(0, 0))
})

test_that("undefined domains, infeasible floors and exact ties are explicit", {
  negative <- list(g = cbind(a = c(-1, -2), b = c(-3, -4)))
  x <- voi_partition(negative, 1, w_constrained(0))
  expect_true(is.na(x$d_star))
  expect_true(is.na(x$EVPI))
  expect_equal(c(x$A, x$C), c(-Inf, -Inf))
  expect_error(fidelity_threshold(negative, 1, w_constrained()), "finite")
  # A small but genuine gap must not be turned into a tie by a relative tolerance.
  x <- list(g = cbind(a = 1, b = 1 + 1e-7))
  part <- voi_partition(x, 1, w_utilitarian())
  expect_equal(part$d_star, "b")
  expect_equal(part$p_ahead, 1)
  tied <- list(g = cbind(a = 1, b = 1))
  expect_equal(voi_partition(tied, 1, w_utilitarian())$d_star, "a")
  # An undefined Atkinson value must not disappear through na.rm=TRUE.
  expect_warning(out <- voi_partition(negative, 1, w_atkinson(1)), "non-positive")
  expect_true(is.na(out$d_star))
  expect_true(is.na(out$EVPI))
})

test_that("input edge cases are checked without losing singleton dimensions", {
  one <- list(g = matrix(2, 1, 1, dimnames = list(NULL, "x")))
  expect_equal(dim(welfare_draws(one, 1, w_utilitarian())), c(1L, 1L))
  expect_equal(voi_partition(one, 1, w_maximin(), TRUE)$EVPI, 0)
  bad <- one
  bad$g[1] <- NA
  expect_error(voi_partition(bad, 1, w_utilitarian()), "finite")
  bad$g[1] <- Inf
  expect_error(voi_partition(bad, 1, w_utilitarian()), "finite")
  expect_error(voi_partition(one, c(bad = 1), w_utilitarian()), "match")
  expect_error(marginalisation_count(one, 1, w_utilitarian(), 1.9), "identify")
  expect_error(w_constrained(NA), "finite")
  expect_error(w_prioritarian(function(x) 1)(c(1, 2), c(.5, .5)), "one number per group")
  expect_error(voi_partition(one, 1, function(nb, p) c(1, 2)), "length")
  expect_error(voi_partition(one, 1, w_utilitarian(), TRUE, max_profiles = NA), "finite")
  x <- list(a = cbind(sq = 0, x = 10), b = cbind(sq = 0, x = -2))
  expect_equal(unname(welfare_draws(x, c(1, 0), w_maximin())[1, "x"]), -2)
  expect_equal(unname(welfare_draws(x, c(1, 0), w_constrained())[1, "x"]), -Inf)
  set.seed(12)
  before <- .Random.seed
  invisible(fairness_screen(nb, p, list(util = w_utilitarian(), mm = w_maximin())))
  expect_identical(.Random.seed, before)
  expect_equal(nb_summary(one)$EVPI, 0)
  expect_equal(reporting_units(x, list(sum = c(a = 1, b = 1)))$sum, x$a + x$b)
})

test_that("references compare paired outcomes without pooling outcome units", {
  arrays <- lapply(nb, function(x) nb_array(money = x, hours = 2 * x))
  model <- function(claim) {
    out <- arrays
    out$women[, "dX", "money"] <- out$women[, "dX", "money"] - claim
    out
  }
  rules <- list(util = w_utilitarian(), mm = w_maximin())
  units <- list(household = c(women = 1, men = 1))
  actual <- baseline_pair(model, list(today = 0, claim = 3), p, rules, units)
  # Expected tables: the implementation these functions replaced, on the same input,
  # recorded when both implementations were last run side by side (8 October 2026).
  outcomes <- utils::read.csv(colClasses = c(rep("character", 3), rep("numeric", 5),
                                             rep("character", 2), "logical"), text = "
unit,outcome,option,mean_today,mean_claim,p_positive_today,p_positive_claim,difference,recommended_today,recommended_claim,flip
women,money,d0,0,0,0,0,0,dX,dX,FALSE
women,money,dX,6,3,0.75,0.75,-3,dX,dX,FALSE
women,money,dY,1.5,1.5,1,1,0,dX,dX,FALSE
women,hours,d0,0,0,0,0,0,dX,dX,FALSE
women,hours,dX,12,12,0.75,0.75,0,dX,dX,FALSE
women,hours,dY,3,3,1,1,0,dX,dX,FALSE
men,money,d0,0,0,0,0,0,dY,dY,FALSE
men,money,dX,0,0,0.5,0.5,0,dY,dY,FALSE
men,money,dY,3,3,1,1,0,dY,dY,FALSE
men,hours,d0,0,0,0,0,0,dY,dY,FALSE
men,hours,dX,0,0,0.5,0.5,0,dY,dY,FALSE
men,hours,dY,6,6,1,1,0,dY,dY,FALSE
household,money,d0,0,0,0,0,0,dX,dY,TRUE
household,money,dX,6,3,1,0.5,-3,dX,dY,TRUE
household,money,dY,4.5,4.5,1,1,0,dX,dY,TRUE
household,hours,d0,0,0,0,0,0,dX,dX,FALSE
household,hours,dX,12,12,1,1,0,dX,dX,FALSE
household,hours,dY,9,9,1,1,0,dX,dX,FALSE
")
  rule_table <- utils::read.csv(colClasses = c(rep("character", 4), "numeric", "numeric",
                                               "logical"), text = "
rule,outcome,reference,option,p_ahead,EVPI,flip
util,money,today,dX,0.5,0.625,TRUE
util,money,claim,dY,0.5,0.625,TRUE
mm,money,today,dY,0.75,0.25,FALSE
mm,money,claim,dY,0.75,0.25,FALSE
util,hours,today,dX,0.5,1.25,FALSE
util,hours,claim,dX,0.5,1.25,FALSE
mm,hours,today,dY,0.75,0.5,FALSE
mm,hours,claim,dY,0.75,0.5,FALSE
")
  expect_equal(actual$outcomes, outcomes)
  expect_equal(actual$rules, rule_table)
  expect_false(any(actual$outcomes$flip[actual$outcomes$outcome == "hours"]))
})
