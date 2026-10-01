# The case model (v8 order, section 6): identities and null controls belong here, not in the results.
OPTS <- c("sq", "out", "up_std", "up_inc", "deep")
SETS <- c("V0", "V1", "PREF")
nb_names <- function(acc, opts = OPTS, sets = SETS)
  as.vector(outer(opts, sets, function(o, s) paste("NB", acc, o, s, sep = "_")))

test_that("make_variables() and decision_model() run on one draw, as in the template", {
  old <- setwd(.proj_root); on.exit(setwd(old))
  set.seed(3)
  invisible(utils::capture.output(suppressMessages(suppressWarnings(make_variables(v8_estimate())))))
  out <- decision_model()
  expect_true(is.list(out))
  expect_true(all(is.finite(unlist(out))))
  expect_true(all(c(nb_names("G"), nb_names("comm"), "wage_h", "p", "NPV_G_cash_sq",
                    "Lvl_kg_eaten_sq", "Lvl_hrs_Wg_sq", "Lvl_hrs_H_sq", "Lvl_H_cash_sq") %in% names(out)))
})

test_that("the input table has 31 rows; the model reads every row but the historical reference", {
  inp <- utils::read.csv(input_file, stringsAsFactors = FALSE)
  expect_equal(nrow(inp), 31L)
  expect_true(all(inp$status %in% c("L", "W", "T", "B", "P")))
  expect_true(all(nzchar(inp$edge)))
  expect_false("displacement_share" %in% inp$variable)
  expect_true("hiring_hh_share" %in% inp$variable)
  alt <- "own_consumption_share_behavioural_alt"
  used <- all.names(body(decision_model))
  expect_true(all(setdiff(inp$variable, alt) %in% used), info = paste(setdiff(inp$variable, used), collapse = ", "))
  # the historical reference is not read in the main run: only by the greyed-out line below the active one,
  # and it is the last row, so that every other input keeps its draws
  expect_false(alt %in% used)
  lines <- readLines(model_file)
  on <- grep("^  own_sq +<- rep\\(own_consumption_share_behavioural,", lines)
  expect_length(on, 1L)
  expect_match(lines[on + 1], "^  ## own_sq +<- rep\\(own_consumption_share_behavioural_alt,")
  expect_identical(inp$variable[nrow(inp)], alt)
  expect_identical(inp$status[nrow(inp)], "L")
  # rows with status T carry a source; L, W and T rows carry a source key
  expect_true(all(nzchar(inp$source_key[inp$status %in% c("L", "W", "T")])))
})

test_that("levels of the status quo: the reference of the progress index (T1b) and of the level rules (T4)", {
  for (seed in 1:3) {
    e <- model_on(seed = seed)
    y <- e$.out
    s <- e$hiring_hh_share; mixsq <- function(k) (1 - s) * e$sq_self[[k]] + s * e$sq_hire[[k]]
    expect_equal(y[["Lvl_kg_eaten_sq"]], sum(mixsq("eaten")), tolerance = 1e-12)
    expect_equal(y[["Lvl_hrs_Wg_sq"]], (1 - s) * e$n_years * e$Q / e$hand_hull_rate_kg_h, tolerance = 1e-10)
    expect_equal(y[["Lvl_hrs_H_sq"]], s * e$n_years * e$Q / e$hand_hull_rate_kg_h / e$K, tolerance = 1e-10)
    expect_equal(y[["Lvl_H_cash_sq"]] * e$K, e$npv(rep(s * e$Q * e$f_h, e$n_years)), tolerance = 1e-10)
    expect_true(all(unlist(y[c("Lvl_kg_eaten_sq", "Lvl_hrs_Wg_sq", "Lvl_hrs_H_sq", "NPV_G_cash_sq", "Lvl_H_cash_sq")]) > 0))
    # progress towards less drudgery is the mean machine share, for the women and for the hullers alike
    for (o in c("out", "up_std", "up_inc")) {
      expect_equal(y[[paste0("Hrs_G_saved_", o)]] / y[["Lvl_hrs_Wg_sq"]], y[[paste0("M_share_", o)]], tolerance = 1e-10)
      expect_equal(y[[paste0("Hrs_H_freed_", o)]] / y[["Lvl_hrs_H_sq"]], y[[paste0("M_share_", o)]], tolerance = 1e-10)
    }
    # deep moves no hour and never lowers the kg eaten
    expect_identical(y[["Hrs_G_saved_deep"]], 0)
    expect_gte(y[["Kg_eaten_deep"]], 0)
  }
})

test_that("historical reference: swapping the greyed-out line equals today's share replaced by the 2011 share", {
  old <- setwd(.proj_root); on.exit(setwd(old))
  eval(script_function(axes_file, "model_swapped"), envir = globalenv())
  hist_model <- model_swapped("^  own_sq +<- rep\\(own_consumption_share_behavioural,",
                              "^  ## own_sq +<- rep\\(own_consumption_share_behavioural_alt,")
  m <- input_medians()
  a <- model_on(m, seed = 8, model_body = body(hist_model))$.out
  b <- model_on(with_inputs(own_consumption_share_behavioural = m$own_consumption_share_behavioural_alt), seed = 8)$.out
  expect_identical(a, b)
  # null condition: with the historical share equal to today's, the swapped model is the main model
  c0 <- model_on(with_inputs(own_consumption_share_behavioural_alt = m$own_consumption_share_behavioural), seed = 8,
                 model_body = body(hist_model))$.out
  expect_identical(c0, model_on(m, seed = 8)$.out)
  # at kappa = 1 a kg eaten counts as much as a kg sold: no V1 or PREF account moves with the history
  main_out <- model_on(m, seed = 8)$.out
  vp <- grep("^NBc?_.*_(V1|PREF)$", names(a), value = TRUE)
  expect_length(vp, 90L)                                           # NB_{G, Wg, H, O, comm, Gself, Ghire}, NBc_{self, hire} x 5 options x 2
  for (k in vp) expect_equal(a[[k]], main_out[[k]], tolerance = 1e-8, info = k)
  expect_false(isTRUE(all.equal(a[["NB_G_deep_V0"]], main_out[["NB_G_deep_V0"]])))   # money only sees the share eaten
  # the re-run on the same draws keeps every input column
  main <- run_mc(100, seed = 20)
  h <- run_mc(100, seed = 20, model = hist_model)
  expect_identical(h$x, main$x)
  rm("model_swapped", envir = globalenv())
})

test_that("the two designs of the plan: they coincide at enforcement 0; the hullers are linear in it (T6 e*)", {
  m <- input_medians()
  y0 <- model_on(with_inputs(inclusive_rule_enforcement = 0), seed = 9)$.out
  for (s in SETS) for (a in c("G", "Wg", "H", "comm"))
    expect_equal(y0[[paste("NB", a, "up_inc", s, sep = "_")]], y0[[paste("NB", a, "up_std", s, sep = "_")]],
                 tolerance = 1e-10, info = paste(a, s))
  y1 <- model_on(m, seed = 9)$.out
  for (e_val in c(0.3, 0.88)) {
    ye <- model_on(with_inputs(inclusive_rule_enforcement = e_val), seed = 9)$.out
    for (s in SETS)
      expect_equal(ye[[paste0("NB_H_up_inc_", s)]],
                   y1[[paste0("NB_H_up_std_", s)]] + e_val * (y1[[paste0("NB_H_up_inc_", s)]] - y1[[paste0("NB_H_up_std_", s)]]),
                   tolerance = 1e-9, info = paste(e_val, s))
  }
})

test_that("mass balance: Qm + Qh = Q and grain = eaten + sold, every option, type and year", {
  for (seed in 1:3) {
    e <- model_on(seed = seed)
    for (o in c("sq", "out", "up_std", "up_inc", "deep")) for (k in c("self", "hire")) {
      x <- get(paste(o, k, sep = "_"), envir = e)
      expect_length(x$Qm, e$n_years)
      expect_equal(x$Qm + x$Qh, rep(e$Q, e$n_years), tolerance = 1e-12)
      expect_equal(x$eaten + x$sold, x$grain, tolerance = 1e-12)
      expect_equal(x$Qp + x$Qu, x$Qh, tolerance = 1e-12)
      expect_true(all(x$Qm >= 0 & x$Qm <= e$Q))
    }
  }
})

test_that("the mix of the types with hiring_hh_share equals one household with that paid share", {
  e <- model_on(seed = 2)
  s <- e$hiring_hh_share
  lin <- c("Qm", "Qh", "Qp", "Qu", "grain", "eaten", "sold", "fee", "wages", "marg",
           "G_cash", "H_cash", "O_cash", "G_hrs", "H_hrs")
  cases <- list(sq = list(e$m_sq, e$own_sq, e$op_none), out = list(e$m_out, e$own_sq, e$op_out),
                up_inc = list(e$m_up, e$own_sq, e$op_up_inc), deep = list(e$m_sq, e$own_deep, e$op_none))
  for (o in names(cases)) {
    a <- cases[[o]]
    old <- e$process_fonio(a[[1]], a[[2]], a[[3]], paid = s)       # the old reading: a paid share of hand hulling
    self <- e$process_fonio(a[[1]], a[[2]], a[[3]], paid = 0)
    hire <- e$process_fonio(a[[1]], a[[2]], a[[3]], paid = 1)
    for (k in lin) expect_equal((1 - s) * self[[k]] + s * hire[[k]], old[[k]], tolerance = 1e-10,
                                info = paste(o, k))
  }
})

test_that("status quo: every difference to sq is exactly 0", {
  sim <- run_mc(200, seed = 11)
  sq_cols <- grep("^(NPV_G_cash|Lvl_)", grep("_sq(_|$|[0-9])", names(sim$y), value = TRUE),   # the levels of the status
                  value = TRUE, invert = TRUE)                                                   #   quo are not differences
  expect_gt(length(sq_cols), 40L)
  expect_true(all(as.matrix(sim$y[, sq_cols]) == 0))
})

test_that("transfers cancel: the commune's money = sold x p - Qm x (f_m - margin)", {
  for (seed in 1:3) {
    e <- model_on(seed = seed)
    for (o in c("sq", "out", "up_std", "up_inc", "deep")) for (k in c("self", "hire")) {
      x <- get(paste(o, k, sep = "_"), envir = e)
      expect_equal(x$G_cash + x$H_cash + x$O_cash, x$sold * e$p - x$Qm * (e$f_m - e$margin),
                   tolerance = 1e-10, info = paste(o, k))
    }
  }
  sim <- run_mc(200, seed = 12)
  for (o in OPTS) for (s in SETS)
    expect_equal(sim$y[[paste("NB_comm", o, s, sep = "_")]],
                 sim$y[[paste("NB_G", o, s, sep = "_")]] + 0.25 * sim$y[[paste("NB_H", o, s, sep = "_")]] +
                   sim$y[[paste("NB_O", o, s, sep = "_")]], tolerance = 1e-9, info = paste(o, s))
})

test_that("hiring_hh_share = 0: H is 0 in every option except up_inc, where only the margin remains", {
  e <- model_on(with_inputs(hiring_hh_share = 0), seed = 4)
  y <- e$.out
  for (o in c("out", "up_std", "deep")) for (s in SETS)
    expect_identical(y[[paste("NB_H", o, s, sep = "_")]], 0, info = paste(o, s))
  expect_identical(y[["C_H_time_up_inc"]], 0)
  expect_equal(y[["C_H_cash_up_inc"]], e$inclusive_rule_enforcement * e$npv(e$margin * e$m_up * e$Q),
               tolerance = 1e-10)
  expect_gt(y[["C_H_cash_up_inc"]], 0)
})

test_that("kappa = 1: NB_G(deep) and the commune's deep are exactly 0 in every draw", {
  sim <- run_mc(300, seed = 13)
  for (s in c("V1", "PREF")) {
    expect_true(all(sim$y[[paste0("NB_G_deep_", s)]] == 0))
    expect_true(all(sim$y[[paste0("NB_comm_deep_", s)]] == 0))
  }
  # and deep is (kappa - 1) x p x the kg moved to the plate: under V0 (kappa = 0) minus their value
  expect_equal(sim$y$NB_G_deep_V0, -sim$y$C_G_kg_deep, tolerance = 1e-10)
  expect_true(all(sim$y$C_G_kg_deep >= 0))
})

test_that("the two rules of the plan give the same commune in every draw, at e = 1 and at any e", {
  sim <- run_mc(300, seed = 14)
  for (s in SETS) expect_identical(sim$y[[paste0("NB_comm_up_std_", s)]], sim$y[[paste0("NB_comm_up_inc_", s)]])
  for (e_val in c(0, 0.37, 0.5)) {
    y <- model_on(with_inputs(inclusive_rule_enforcement = e_val), seed = 5)$.out
    for (s in SETS) {
      expect_identical(y[[paste0("NB_comm_up_std_", s)]], y[[paste0("NB_comm_up_inc_", s)]])
      # what G gives up, H gains: the split differs, the sum does not
      expect_equal(y[[paste0("NB_G_up_std_", s)]] - y[[paste0("NB_G_up_inc_", s)]],
                   0.25 * (y[[paste0("NB_H_up_inc_", s)]] - y[[paste0("NB_H_up_std_", s)]]), tolerance = 1e-9)
    }
  }
})

test_that("plan_lag_years >= horizon: up equals the status quo", {
  y <- model_on(with_inputs(plan_lag_years = 12), seed = 6)$.out
  for (o in c("up_std", "up_inc")) {
    cols <- grep(paste0("_", o, "(_|$|[0-9])"), names(y), value = TRUE)
    expect_true(all(unlist(y[cols]) == 0), info = o)
  }
})

test_that("awareness_reach_share = 0: deep equals the status quo", {
  y <- model_on(with_inputs(awareness_reach_share = 0), seed = 7)$.out
  cols <- grep("_deep(_|$|[0-9])", names(y), value = TRUE)
  expect_gt(length(cols), 30L)
  expect_true(all(unlist(y[cols]) == 0))
})

test_that("reference 'preference': with the off-farm value equal to wage_h, NB_H(out) is 0", {
  m <- input_medians()
  wage <- m$hand_service_price_fcfa_kg * m$hand_hull_rate_kg_h
  for (seed in 1:3) {
    y <- model_on(with_inputs(opportunity_wage_fcfa_h = wage), seed = seed)$.out
    expect_equal(y[["NB_H_out_PREF"]], 0, tolerance = 1e-9)
    expect_equal(y[["NB_H_up_std_PREF"]], 0, tolerance = 1e-9)
  }
})

test_that("V1 and PREF differ only in the hour weights", {
  sim <- run_mc(300, seed = 15)
  y <- sim$y
  for (o in OPTS) {
    dW <- y$w_off_rel - 1; dH <- y$w_off_rel - y$theta
    expect_equal(y[[paste0("NB_G_", o, "_PREF")]] - y[[paste0("NB_G_", o, "_V1")]],
                 dW * y[[paste0("C_G_time_", o)]], tolerance = 1e-8, info = o)
    expect_equal(y[[paste0("NB_H_", o, "_PREF")]] - y[[paste0("NB_H_", o, "_V1")]],
                 dH * y[[paste0("C_H_time_", o)]] / 0.25, tolerance = 1e-8, info = o)
    expect_equal(y[[paste0("NB_O_", o, "_PREF")]], y[[paste0("NB_O_", o, "_V1")]])
  }
})

test_that("out targeted to type self leaves the hullers' account unchanged", {
  sim <- run_mc(200, seed = 16)
  y <- sim$y
  expect_true(all(y$C_Hself_cash_out == 0 & y$C_Hself_time_out == 0))
  # the commune value of type self under out has no huller part; that of type hire has one
  expect_equal(y$NBc_self_out_V1, y$NB_Gself_out_V1 + y$C_Oself_cash_out, tolerance = 1e-9)
  expect_true(all(y$C_Hhire_cash_out <= 0))
  # the commune is the mix of the two types
  s <- sim$x$hiring_hh_share
  for (o in OPTS) for (st in SETS)
    expect_equal((1 - s) * y[[paste("NBc_self", o, st, sep = "_")]] + s * y[[paste("NBc_hire", o, st, sep = "_")]],
                 y[[paste("NB_comm", o, st, sep = "_")]], tolerance = 1e-8, info = paste(o, st))
})

test_that("profiles on the model: only the diagonal gives VoH_static = VoH_dyn = 0 and EVPI_sub = EVPI", {
  sim <- run_mc(300, seed = 17)
  s <- sim$x$hiring_hh_share
  nb <- nb_from_mc(sim, "NBc_{group}_{option}_V1", groups = c("self", "hire"), options = OPTS)
  nb$self <- (1 - s) * nb$self; nb$hire <- s * nb$hire
  diag_prof <- cbind(self = OPTS, hire = OPTS)
  x <- voi_partition(nb, c(1, 1), w_utilitarian(), differentiated = TRUE, profiles = diag_prof)
  expect_equal(x$VoH_static, 0, tolerance = 1e-9)
  expect_equal(x$VoH_dyn, 0, tolerance = 1e-9)
  expect_equal(x$EVPI_sub, x$EVPI, tolerance = 1e-9)
  # 2 x A is the commune's best expected value per producer household (the p normalisation undone)
  expect_equal(2 * x$A, max(sapply(OPTS, function(o) mean(sim$y[[paste0("NB_comm_", o, "_V1")]]))),
               tolerance = 1e-9)
})

test_that("re-runs (T6): the same seed gives the same inputs; (1, 1) reproduces the main run", {
  eval(script_function(axes_file, "decision_model_fidelity"), envir = globalenv())
  main <- run_mc(150, seed = 18)
  assign("F_REACH", 1, envir = globalenv()); assign("F_RULE", 1, envir = globalenv())
  same <- run_mc(150, seed = 18, model = decision_model_fidelity)
  expect_identical(same$x, main$x)
  expect_identical(same$y, main$y)
  assign("F_REACH", 0.25, envir = globalenv()); assign("F_RULE", 0.75, envir = globalenv())
  a <- run_mc(150, seed = 18, model = decision_model_fidelity)
  b <- run_mc(150, seed = 18, model = decision_model_fidelity)
  expect_identical(a$x, main$x)                  # no input column other than the two scaled ones changes
  expect_identical(a$y, b$y)                     # two identical compositions, identical outputs
  changed <- names(main$y)[vapply(names(main$y), function(k) !identical(a$y[[k]], main$y[[k]]), logical(1))]
  expect_true(length(changed) > 0)
  expect_true(all(grepl("up_(std|inc)", changed)), info = paste(head(changed[!grepl("up_", changed)]), collapse = ", "))
  rm("F_REACH", "F_RULE", envir = globalenv())
})

test_that("alternative O2: with kappa = 1.5 only the outputs that contain kappa change", {
  lines <- readLines(model_file)
  on <- grep("^  kappa +<- 1 ", lines); off <- grep("^  ## kappa +<- 1\\.5", lines)
  expect_length(on, 1L); expect_length(off, 1L)
  alt <- lines
  alt[on] <- sub("^  kappa", "  ## kappa", lines[on]); alt[off] <- sub("^  ## kappa", "  kappa", lines[off])
  ex <- parse(text = alt, keep.source = FALSE)
  def <- Filter(function(e) is.call(e) && identical(e[[2]], as.name("decision_model")), as.list(ex))[[1]]
  decision_model_alt <- eval(def[[3]], envir = globalenv())
  main <- run_mc(150, seed = 19)
  alt_run <- run_mc(150, seed = 19, model = decision_model_alt)
  expect_identical(alt_run$x, main$x)
  changed <- names(main$y)[vapply(names(main$y), function(k) !isTRUE(all.equal(alt_run$y[[k]], main$y[[k]],
                                                                               tolerance = 1e-12)), logical(1))]
  expect_true(all(grepl("^NB(c)?_(G|Gself|Ghire|comm|self|hire)_.*_(V1|PREF)$", changed)),
              info = paste(changed, collapse = ", "))
  expect_true("NB_G_deep_V1" %in% changed)
  expect_equal(alt_run$y$NB_G_deep_V1, 0.5 * main$y$C_G_kg_deep, tolerance = 1e-10)
  expect_identical(alt_run$y$NB_G_deep_V0, main$y$NB_G_deep_V0)
})
