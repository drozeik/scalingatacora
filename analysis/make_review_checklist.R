# docs/review_checklist.md: Daniel's review path through decision_model() (v9). One row per section of
# the model: its lines in atacora_DA_model.R, one sentence on what to look at, and the tests that hold
# it. Generated from the source, so the line numbers stay right; the script stops if a named test or a
# section is missing.
# Called at the end of atacora_DA_run.R. Standalone:  Rscript analysis/make_review_checklist.R

local({
  model_file <- "atacora_DA_model.R"
  src <- readLines(model_file, warn = FALSE)
  tests <- readLines("tests/testthat/test-model.R", warn = FALSE)
  test_names <- sub('^test_that\\("(.*)", \\{.*$', "\\1", grep('^test_that\\("', tests, value = TRUE))
  body_start <- grep("^decision_model <- function", src)
  body_end <- grep("^}", src); body_end <- body_end[body_end > body_start][1]
  heads <- grep("^  # ([0-9]\\.|\\([0-9]\\)) ", src)
  heads <- heads[heads > body_start & heads < body_end]
  key <- sub("^  # ((\\([0-9]\\))|([0-9]))[. ].*$", "\\1", src[heads])
  title <- trimws(sub("^  # ", "", src[heads]))
  ends <- c(heads[-1] - 1, body_end)

  look <- c(                                                                        # what to look at, per section
    "1" = "The horizon is fixed at 10 years; year 1 is not discounted (decisionSupport's discount()).",
    "2" = "Downtime years are drawn once per draw and hit out and up alike; the lost machine paddy goes back to hand hulling.",
    "3" = "Paddy per producer household is constant over the horizon; there is no area path in v8.",
    "4" = "p is the producer's price (retail x producer share); the machine fee and the hourly wage are both tied to the hand-hulling price.",
    "5" = "The mass balance and who pays whom: fees are paid by the household, wages go to the hullers, the margin goes where op says.",
    "(0)" = "Two pure household types: self (the women hull everything) and hire (paid hullers hull everything); the ## line below own_sq is the historical reference (T2).",
    "(1)" = "Capacity: units x throughput / (households x paddy), at most 1; the same m for both types.",
    "(2)" = "The plan acts after its lag and equips a share; the two rules differ only in who receives the operator margin.",
    "(3)" = "The campaign raises the share eaten at home; nothing else changes, so deep only moves kg from sale to the plate.",
    "6" = "All accounts are option minus status quo; the commune is the mix of the two types with hiring_hh_share.",
    "7" = "Three named settings; the kappa = 1.5 alternative is the ## line; theta and the off-farm value are censored/derived here.",
    "8" = "NB_comm is summed from rule-independent parts, so up_std and up_inc are identical for the commune in every draw.",
    "9" = "The outputs follow NB_{account}_{option}_{setting}, C_{account}_{component}_{option}, as nb_from_mc() reads them; the levels of the status quo (Lvl_*, NPV_G_cash_sq) are the reference of H3 and of the level rules of T4.")
  held_by <- list(                                                                  # the tests of tests/testthat/test-model.R per section
    "1" = "make_variables() and decision_model() run on one draw, as in the template",
    "2" = "re-runs (T6): the same seed gives the same inputs; (1, 1) reproduces the main run",
    "3" = "mass balance: Qm + Qh = Q and grain = eaten + sold, every option, type and year",
    "4" = "transfers cancel: the commune's money = sold x p - Qm x (f_m - margin)",
    "5" = c("mass balance: Qm + Qh = Q and grain = eaten + sold, every option, type and year",
            "the mix of the types with hiring_hh_share equals one household with that paid share"),
    "(0)" = c("status quo: every difference to sq is exactly 0",
              "historical reference: swapping the greyed-out line equals today's share replaced by the 2011 share"),
    "(1)" = c("out targeted to type self leaves the hullers' account unchanged",
              "hiring_hh_share = 0: H is 0 in every option except up_inc, where only the margin remains"),
    "(2)" = c("the two rules of the plan give the same commune in every draw, at e = 1 and at any e",
              "plan_lag_years >= horizon: up equals the status quo",
              "the two designs of the plan: they coincide at enforcement 0; the hullers are linear in it (T6 e*)"),
    "(3)" = c("awareness_reach_share = 0: deep equals the status quo",
              "kappa = 1: NB_G(deep) and the commune's deep are exactly 0 in every draw"),
    "6" = c("status quo: every difference to sq is exactly 0",
            "out targeted to type self leaves the hullers' account unchanged"),
    "7" = c("V1 and PREF differ only in the hour weights",
            "reference 'preference': with the off-farm value equal to wage_h, NB_H(out) is 0",
            "alternative O2: with kappa = 1.5 only the outputs that contain kappa change"),
    "8" = c("transfers cancel: the commune's money = sold x p - Qm x (f_m - margin)",
            "the two rules of the plan give the same commune in every draw, at e = 1 and at any e"),
    "9" = c("profiles on the model: only the diagonal gives VoH_static = VoH_dyn = 0 and EVPI_sub = EVPI",
            "levels of the status quo: the reference of the progress index (T1b) and of the level rules (T4)"))
  missing_sec <- setdiff(names(look), key)
  if (length(missing_sec)) stop("Sections not found in decision_model(): ", paste(missing_sec, collapse = ", "))
  missing_t <- setdiff(unlist(held_by), test_names)
  if (length(missing_t)) stop("Tests not found in test-model.R: ", paste(missing_t, collapse = " | "))
  kappa_line <- grep("^  ## kappa +<- 1\\.5", src)
  hist_line <- grep("^  ## own_sq +<- rep\\(own_consumption_share_behavioural_alt", src)

  out <- c("# Review checklist (v9)", "",
           sprintf("Generated by `analysis/make_review_checklist.R` from `%s` (%s). The path: open the model,", model_file, format(Sys.Date())),
           "run `make_variables()` (top of the file), then step through `decision_model()` section by section,",
           "next to `docs/model_walkthrough.md` (every line at the medians) and F1 (`outputs/v9/figures/F1_core_en.svg`).",
           "", sprintf("The greyed-out alternatives: O2 (kappa = 1.5, Daniel 27.09.) is line %d; the historical reference (Ballogou et al. 2014, survey 2011; T2) is line %d.", kappa_line, hist_line), "",
           "| section | lines | what to look at | held by the test (tests/testthat/test-model.R) |",
           "|---|---|---|---|")
  for (i in seq_along(heads)) {
    k <- key[i]
    out <- c(out, sprintf("| %s | %d-%d | %s | %s |", title[i], heads[i], ends[i], look[[k]],
                          paste0("\"", held_by[[k]], "\"", collapse = "; ")))
  }
  out <- c(out, "",
           "After the model: `atacora_DA_axes.R` (T0-T6 and H3, one block per test, the axis functions of `R/` directly",
           "behind `mcSimulation()`), then `outputs/v9/key_findings.md`, then F1 and F2 in `outputs/v9/figures/`.")
  writeLines(out, "docs/review_checklist.md")
})
