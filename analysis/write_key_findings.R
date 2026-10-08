# outputs/v9/key_findings.md: H1-H4 and the five axes as the manuscript states them (handoff v9): the checklist,
# the shift table, one card with six points per test; outputs/v9/shift_map.csv for figure S8; the v9 block of
# RESULTS.md. Every number comes from the run: outputs/v9/axes_results.rds and the draws in simulation_results.
# Wording is conditional on the numbers, so a new run keeps it right.
# Called by atacora_DA_run.R after atacora_DA_axes_full.R. Standalone (after a run):
#   Rscript analysis/write_key_findings.R

local({
  OUT <- "outputs/v9"
  res <- readRDS(file.path(OUT, "axes_results.rds"))
  sim <- if (exists("simulation_results")) simulation_results else readRDS(file.path(OUT, "simulation_results.rds"))
  Y <- sim$y; X <- sim$x
  inp <- read.csv("data/estimates/atacora_DA_inputs_v8.csv", stringsAsFactors = FALSE)
  ts <- if (exists("test_summary")) test_summary else NULL
  git <- function(...) tryCatch(trimws(system2("git", c(...), stdout = TRUE, stderr = FALSE)), error = function(e) NA_character_)
  commit <- git("rev-parse", "--short", "HEAD"); branch <- git("rev-parse", "--abbrev-ref", "HEAD")
  OPT <- c("sq", "out", "up_std", "up_inc", "deep")
  LAB <- c(sq = "the status quo", out = "out (equipment)", up_std = "up with the standard rule",
           up_inc = "up with the inclusive rule", deep = "deep (awareness)")
  ACC <- c(G = "producer household", Wg = "women in producer households", H = "paid hullers", comm = "commune", O = "operator")
  f0  <- function(x) ifelse(is.na(x), "n/a", format(round(x) + 0, big.mark = ",", trim = TRUE, scientific = FALSE))   # + 0: no "-0"
  f1  <- function(x) ifelse(is.na(x), "n/a", formatC(round(x, 1) + 0, format = "f", digits = 1, big.mark = ","))
  fk  <- function(x) paste(f0(x), "FCFA")
  pc  <- function(x) ifelse(is.na(x), "n/a", sprintf("%.0f %%", 100 * x))
  pc1 <- function(x) ifelse(is.na(x), "n/a", ifelse(abs(100 * x) < 0.05, "0.0 %", sprintf("%.1f %%", 100 * x)))
  f2  <- function(x) ifelse(is.na(x), "n/a", formatC(x, format = "f", digits = 2))
  f3  <- function(x) ifelse(is.na(x), "n/a", formatC(x, format = "f", digits = 3))
  st  <- function(v) inp$status[match(v, inp$variable)]
  rows_status <- function(v) paste(sprintf("`%s` (%s)", v, st(v)), collapse = ", ")
  mean_of <- function(col, y = Y) mean(y[[col]])
  p_loss  <- function(col, y = Y) mean(y[[col]] < 0)
  yn <- function(b) if (isTRUE(b)) "yes" else "no"
  set <- res$settings
  EV <- res$evpi$table
  lead_txt <- function(job, k = 3, digits = 0){                                     # the leading rows of one multi_EVPI() job
    z <- EV[EV$job == job, ]
    if (!nrow(z)) return("n/a")
    if (is.na(z$rank[1])) return(sprintf("%s: %s", z$pair[1], z$variable[1]))
    z <- head(z[z$EVPI >= 0.01 * max(z$EVPI), ], k)                                # rows below 1 % of the leading one are noise of the smoother
    fmt <- if (digits == 0) f0 else f1
    sprintf("%s: %s", z$pair[1], paste(sprintf("`%s` %s (%s)", z$variable, fmt(z$EVPI), z$status), collapse = ", "))
  }
  lead1 <- function(job){ z <- EV[EV$job == job & !is.na(EV$rank), ]; if (nrow(z)) z$variable[1] else NA_character_ }
  ld <- res$T5$ladder
  ev  <- function(setting, level) ld$EVPI[ld$setting == setting & ld$level == level]
  evo <- function(setting, level) ld$option[ld$setting == setting & ld$level == level]
  L <- character(0); add <- function(...) L <<- c(L, ...)
  card <- function(mech, null, losses, floor, ranking, info){                       # the six points of the closing paragraph of H1-H4
    add(paste("1. **Mechanism and the assumptions that enable it:**", mech),
        paste("2. **When it disappears (null condition, tested):**", null),
        paste("3. **Losses per group:**", losses),
        paste("4. **Floor and threshold violations:**", floor),
        paste("5. **Change in the ranking:**", ranking),
        paste("6. **Value of information (both settings of the test):**", info), "")
  }

  # ---------------------------------------------------------------- facts per test
  t0 <- res$T0$summary; t0m <- res$T0$means
  runner <- sub("^.*_vs_", "", t0$decisive_pair)
  # T1a
  b <- res$T1$boundary
  pref_b <- function(s, k) b$preferred[b$setting == s & b$boundary == k][1]
  mean_b <- function(s, k, o) b$mean[b$setting == s & b$boundary == k & b$option == o]
  pg_b   <- function(s, k, o) b$p_gain[b$setting == s & b$boundary == k & b$option == o]
  ev_b   <- function(s, k) b$EVPI[b$setting == s & b$boundary == k][1]
  signs_T1a <- res$T1$flips[res$T1$flips$sign_changes_across_boundaries, ]
  # T1b money path and thresholds
  pth <- res$T1$path
  pref_p <- function(step, a) pth$preferred[pth$step == step & pth$account == a][1]
  pa_p   <- function(step, a) pth$p_ahead[pth$step == step & pth$account == a][1]
  steps <- unique(pth$step)
  thr <- res$T1$thresholds
  th <- function(acc, w, fixed, o, col) thr[[col]][thr$account == acc & thr$weight == w & thr$fixed == fixed & thr$option == o]
  omega_out_sq <- th("G", "omega", "kappa = 1", "out", "vs_sq_from")
  omega_out_best <- th("G", "omega", "kappa = 1", "out", "vs_best_other_from")
  omega_out_sq_comm <- th("comm", "omega", "kappa = 1", "out", "vs_sq_from")
  omega_upstd_sq <- th("G", "omega", "kappa = 1", "up_std", "vs_sq_from")
  kappa_deep_best <- th("G", "kappa", "omega = 1", "deep", "vs_best_other_from")
  kappa_deep_best_comm <- th("comm", "kappa", "omega = 1", "deep", "vs_best_other_from")
  wq <- res$T1$w_off_quantiles
  # H3
  A <- res$T1$aims; shf <- res$T1$shift; par <- res$T1$pareto; k15 <- res$T1$kappa15; kgd <- res$T1$kg
  am <- function(a, aim, o, col = "mean") A[[col]][A$account == a & A$aim == aim & A$option == o]
  eat_ahead <- shf$deep_p_ahead_of_all[3]; eat_closer <- shf$deep_p_positive[3]
  eat_pos <- shf$options_with_positive_mean[3]
  deep_only_eat <- identical(eat_pos, "deep")
  pareto_set <- function(a) par$option[par$account == a & par$non_dominated]
  dominant <- sapply(c("G", "Wg", "H"), function(a) if (length(pareto_set(a)) == 1) pareto_set(a) else NA)
  one_dominates_all <- length(unique(dominant)) == 1 && !anyNA(dominant)
  dr <- res$evpi$deep_rows
  AIMS <- set$aims
  # T2
  t2 <- res$T2$accounts
  pref_t2 <- function(acc) t2[t2$account == acc, c("recommended_behaviour", "recommended_preference")][1, ]
  m_t2 <- function(acc, o, r) t2[[paste0("mean_", r)]][t2$account == acc & t2$option == o]
  pg_t2 <- function(acc, o, r) t2[[paste0("p_positive_", r)]][t2$account == acc & t2$option == o]
  comm_acc <- "commune (per producer household)"; hull_acc <- "paid hullers (H, per person)"
  G_acc <- "producer household (G)"; Wg_acc <- "women in producer households (Wg)"
  t2r <- res$T2$rules
  rule_flips_t2 <- unique(t2r$rule[t2r$flip])
  sw <- res$T2$switch; sw_comm <- sw[sw$account == "comm", ]; sw_G <- sw[sw$account == "G", ]
  p_off_above <- res$T2$prior[["p_off_above_wage"]]
  off_q <- quantile(X$opportunity_wage_fcfa_h, c(.05, .5, .95)); wage_q <- quantile(Y$wage_h, c(.05, .5, .95))
  first_switch <- function(d) if (nrow(d) > 1) d$from[2] else NA
  w_star_comm <- first_switch(sw_comm); w_star_G <- first_switch(sw_G)
  hs <- res$T2$historical; he <- res$T2$historical_eat; hr <- res$T2$historical_rules
  hist_flips <- hs[hs$flips, ]
  hist_rule_flips <- hr$rule[hr$today != hr$historical]
  # T3
  u <- res$T3$units
  mu <- function(unit, o, col = "mean") u[[col]][u$unit == unit & u$option == o]
  own <- res$T3$own_ranking; hid <- res$T3$hidden; t3thr <- res$T3$threshold; t3e <- res$T3$evpi
  # T4
  dsg <- res$T4$designs; fl <- res$T4$floor; adm <- res$T4$admissible; mn <- res$T4$minimum; t4e <- res$T4$evpi
  rk <- function(m) dsg$ranking[dsg$measure == m]
  dv <- function(m, d) dsg[[paste0("value_", d)]][dsg$measure == m]
  flr <- function(o, g, col = "p_below") fl[[col]][fl$option == o & fl$group == g]
  below <- function(o) { z <- fl[fl$option == o & fl$p_below > 0, ]; if (nrow(z)) paste(sprintf("%s %s", ACC[z$group], pc(z$p_below)), collapse = ", ") else "no group" }
  worse_off_rules <- c("prioritarian", "atkinson_0.5", "atkinson_1", "atkinson_2", "maximin", "maximin on levels", "atkinson_1 on levels")
  neutral <- c("reach", "compliance", "utilitarian")
  core_t4 <- all(dsg$ranking[dsg$measure %in% neutral] == "equal") && rk("addressees' account") == "std > inc" &&
             all(dsg$ranking[dsg$measure %in% worse_off_rules] == "inc > std")
  all_opts <- res$T4$all_options
  # T5
  het <- res$T5$heterogeneity
  hv <- function(k, q, col = "value") het[[col]][het$profiles == k & het$quantity == q]
  planner_r <- het$planner_profile[het$profiles == "restricted"][1]
  pp <- res$T5$partitions$restricted$planner_profile
  planner_words <- if (is.null(pp)) "no profile" else if (pp[["self"]] == pp[["hire"]]) sprintf("%s for both household types", LAB[[pp[["self"]]]]) else
    sprintf("%s for the households that hull themselves and %s for those that hire", LAB[[pp[["self"]]]], LAB[[pp[["hire"]]]])
  planner_u <- het$planner_profile[het$profiles == "unrestricted"][1]
  evpi_row <- function(job, v) { e <- res$evpi$full[[job]]; if (is.null(e)) NA else e[[1]]$EVPI[e[[1]]$variable == v] }
  tvr_H <- evpi_row("T5_level_H", "time_value_ratio_hullers"); tvr_comm <- evpi_row("main_model", "time_value_ratio_hullers")
  lead_util <- lead1("T5_commune_utilitarian"); lead_mm <- lead1("T5_commune_maximin")
  mm_top <- evpi_row("T5_commune_maximin", lead_mm); util_in_mm <- evpi_row("T5_commune_maximin", lead_util)
  util_top <- evpi_row("T5_commune_utilitarian", lead_util); mm_in_util <- evpi_row("T5_commune_utilitarian", lead_mm)
  prio_close <- !identical(lead_util, lead_mm) && isTRUE(util_in_mm >= 0.8 * mm_top)       # the utilitarian's leading row stays level
  prio_txt <- if (identical(lead_util, lead_mm)) sprintf("does not depend on the criterion here (`%s` leads under both)", lead_util) else
    if (prio_close) sprintf("shifts with the criterion: under the utilitarian rule `%s` leads (%s) and `%s` is worth %s; under maximin `%s` (%s) and `%s` (%s) are almost level, at a much smaller information value",
                            lead_util, fk(util_top), lead_mm, fk(mm_in_util), lead_mm, fk(mm_top), lead_util, fk(util_in_mm)) else
    sprintf("depends on the criterion: under the utilitarian rule `%s` leads (%s), under maximin `%s` (%s)", lead_util, fk(util_top), lead_mm, fk(mm_top))
  # T6
  cmp <- res$T6$composition; es <- res$T6$e_star; cc <- res$T6$conceal; t6e <- res$T6$evpi; t6p <- res$T6$preferred
  cm <- function(r, l, o, col) cmp[[col]][cmp$reach == r & cmp$rule == l & cmp$option == o]
  H_signs <- sign(round(cmp$H_mean[cmp$option == "up_inc"], 6))
  t6_sign_change <- length(unique(H_signs)) > 1

  # ---------------------------------------------------------------- the shift table (S8 reads shift_map.csv)
  shift <- list(
    list(test = "T1a", axis = "Axis 1 system boundary; H1 (out)", kind = if (pref_b("V1", "G") != pref_b("V1", "G + H + O")) "preferred option flips" else "sign or visibility",
         from_to = "producer household G -> G + hullers H + operator O (behaviour V1)",
         what = sprintf("preferred option %s -> %s; out: %s -> %s per producer household",
                        pref_b("V1", "G"), pref_b("V1", "G + H + O"), fk(mean_b("V1", "G", "out")), fk(mean_b("V1", "G + H + O", "out"))),
         size = sprintf("hullers under out %s per person (loss in %s of draws); operator %s", fk(mean_of("NB_H_out_V1")),
                        pc(p_loss("NB_H_out_V1")), fk(mean_of("NB_O_out_V1"))),
         threshold = "none: a boundary is included or not", carrying = rows_status(c("hiring_hh_share", "hand_service_price_fcfa_kg", "time_value_ratio_hullers", "operator_margin_share")),
         measure = "share of hand hulling done for pay; hullers' fallback earnings (field work 2027; BOLDER request on hulling prices)",
         conv = pref_b("V1", "G"), p_conv = b$p_ahead[b$setting == "V1" & b$boundary == "G"][1], set_conv = "G, V1", open = pref_b("V1", "G + H + O"),
         p_open = b$p_ahead[b$setting == "V1" & b$boundary == "G + H + O"][1], set_open = "G + H + O, V1", thr = NA, lo = NA, hi = NA, thr_lab = "", thr_unit = ""),
    list(test = "T1b", axis = "Axis 1 objectives in money", kind = if (pref_p(steps[1], "G") != pref_p(steps[3], "G")) "preferred option flips" else "size only",
         from_to = "money only V0 -> hulling time valued (omega = 1) -> kg eaten valued (kappa = 1), producer household",
         what = sprintf("preferred option %s -> %s -> %s", pref_p(steps[1], "G"), pref_p(steps[2], "G"), pref_p(steps[3], "G")),
         size = sprintf("out %s -> %s; up_std %s -> %s", fk(mean_of("NB_G_out_V0")), fk(mean_of("NB_G_out_V1")),
                        fk(mean_of("NB_G_up_std_V0")), fk(mean_of("NB_G_up_std_V1"))),
         threshold = sprintf("omega* out vs sq %s, vs best other %s; up_std vs sq %s; off-farm value / wage 5-95 %%: %s-%s",
                             f2(omega_out_sq), f2(omega_out_best), f2(omega_upstd_sq), f2(wq[[1]]), f2(wq[[3]])),
         carrying = rows_status(c("hand_service_price_fcfa_kg", "hand_hull_rate_kg_h", "machine_cost_ratio_to_manual", "recovery_hand_share", "recovery_machine_share")),
         measure = "how hulling hours are valued (field work 2027)",
         conv = pref_p(steps[1], "G"), p_conv = pa_p(steps[1], "G"), set_conv = "G, V0", open = pref_p(steps[3], "G"),
         p_open = pa_p(steps[3], "G"), set_open = "G, V1", thr = omega_out_sq, lo = wq[[1]], hi = wq[[3]],
         thr_lab = sprintf("ω* out = %s", f2(omega_out_sq)), thr_unit = "ω (multiples of wage_h)"),
    list(test = "H3", axis = "Axis 1 valuation layer; H3 (deep)", kind = "valuation layer: a ranking needs an explicit rule",
         from_to = "money (V0, V1) -> progress towards the aims people stated (kg eaten, hours, money; no weights)",
         what = sprintf("deep: never ahead in money (V0 %s, V1 exactly 0); on 'more fonio eaten' closer in %s of draws and ahead of all options in %s; non-dominated options: G %s, Wg %s, H %s",
                        fk(mean_of("NB_G_deep_V0")), pc(eat_closer), pc(eat_ahead),
                        paste(pareto_set("G"), collapse = "/"), paste(pareto_set("Wg"), collapse = "/"), paste(pareto_set("H"), collapse = "/")),
         size = sprintf("deep: %s %% more kg eaten (mean share of today's level); out: less drudgery %s for women and hullers alike, hullers' income %s",
                        f1(100 * am("G", "more fonio eaten", "deep")), pc(am("Wg", "less drudgery", "out")), pc(am("H", "higher income", "out"))),
         threshold = sprintf("the explicit rule kappa = 1.5 puts %s ahead for the household in %s of draws; kappa* deep vs best other %s",
                             k15$preferred_G, pc(k15$p_ahead), f2(kappa_deep_best)),
         carrying = rows_status(c("awareness_consumption_change_share", "awareness_reach_share", "recovery_hand_share", "recovery_machine_share", "hand_hull_rate_kg_h")),
         measure = "target levels of the stated aims (how much more fonio, how much less hulling); relational values, worldviews and broad values (field work 2027)",
         conv = pref_p(steps[1], "G"), p_conv = pa_p(steps[1], "G"), set_conv = "G, money V0", open = "deep", p_open = eat_ahead,
         set_open = "aim: more eaten", thr = NA, lo = NA, hi = NA, thr_lab = "", thr_unit = ""),
    list(test = "T2", axis = "Axis 2 reference state", kind = if (pref_t2(comm_acc)[[1]] != pref_t2(comm_acc)[[2]]) "preferred option flips" else "sign or visibility",
         from_to = "behaviour V1 -> preference PREF (value of a freed hour); today -> historical share eaten (2011)",
         what = sprintf("commune: %s -> %s; hullers under out: gain in %s -> %s of draws; historical reference: %s",
                        pref_t2(comm_acc)[[1]], pref_t2(comm_acc)[[2]], pc(pg_t2(hull_acc, "out", "behaviour")), pc(pg_t2(hull_acc, "out", "preference")),
                        if (nrow(hist_flips)) paste(sprintf("%s %s %s -> %s", hist_flips$account, hist_flips$setting, hist_flips$preferred_today, hist_flips$preferred_historical), collapse = "; ") else "no preferred option changes"),
         size = sprintf("hullers under out %s -> %s per person; commune out %s -> %s", fk(m_t2(hull_acc, "out", "behaviour")),
                        fk(m_t2(hull_acc, "out", "preference")), fk(m_t2(comm_acc, "out", "behaviour")), fk(m_t2(comm_acc, "out", "preference"))),
         threshold = sprintf("hullers under out: off-farm value > wage_h (identity), P under the priors %s; commune switches at %s FCFA/h (prior 5-95 %%: %s-%s FCFA/h)",
                             pc(p_off_above), f0(w_star_comm), f0(off_q[[1]]), f0(off_q[[3]])),
         carrying = rows_status(c("opportunity_wage_fcfa_h", "hand_service_price_fcfa_kg", "hand_hull_rate_kg_h", "time_value_ratio_hullers", "own_consumption_share_behavioural_alt")),
         measure = "local off-farm hourly earnings and whether they are open to women who stop hulling (BOLDER request: casual wage rates; field work 2027)",
         conv = pref_t2(comm_acc)[[1]], p_conv = NA, set_conv = "commune, V1", open = pref_t2(comm_acc)[[2]], p_open = NA,
         set_open = "commune, PREF", thr = w_star_comm, lo = off_q[[1]], hi = off_q[[3]],
         thr_lab = sprintf("w* = %s FCFA/h", f0(w_star_comm)), thr_unit = "off-farm value (FCFA/h)"),
    list(test = "T3", axis = "Axis 3 reporting unit; H1 (out)", kind = "sign or visibility",
         from_to = "producer household -> women in producer households vs paid hullers (per person, V1)",
         what = sprintf("hidden loss: 'women' pooled gain while the hullers lose in %s of draws under out; each unit's own ranking differs, the collective rule does not",
                        pc(hid$p_women_gain_hullers_lose[hid$option == "out"])),
         size = sprintf("out: women in producer households %s (gain in %s), hullers %s (loss in %s) per person",
                        fk(mu(Wg_acc, "out")), pc(mu(Wg_acc, "out", "p_gain")), fk(mu(hull_acc, "out")), pc(mu(hull_acc, "out", "p_loss"))),
         threshold = sprintf("women pooled under out change sign at hiring share %s (prior 5-95 %%: %s-%s)",
                             f2(t3thr$hiring_share_star), f2(t3thr$prior_5), f2(t3thr$prior_95)),
         carrying = rows_status(c("hiring_hh_share", "time_value_ratio_hullers", "hand_service_price_fcfa_kg")),
         measure = "who hulls for whom: the share of producer households that hire hullers, and the number of hullers (field work 2027)",
         conv = "sq", p_conv = NA, set_conv = "commune, V1", open = "sq", p_open = NA, set_open = "commune (units reported apart)",
         thr = t3thr$hiring_share_star, lo = t3thr$prior_5, hi = t3thr$prior_95,
         thr_lab = sprintf("s* = %s", f2(t3thr$hiring_share_star)), thr_unit = "hiring household share"),
    list(test = "T4", axis = "Axis 4 fairness criterion; H2 (up)", kind = "ranking of the rule designs",
         from_to = "reach, compliance, the addressees' account -> utilitarian, prioritarian, Atkinson, maximin (changes and levels); floor (G, Wg, H; V1)",
         what = sprintf("up_std vs up_inc: reach %s, compliance %s, addressees %s, utilitarian %s, prioritarian %s, Atkinson 1 %s, maximin %s, maximin on levels %s",
                        rk("reach"), rk("compliance"), rk("addressees' account"), rk("utilitarian"), rk("prioritarian"), rk("atkinson_1"), rk("maximin"), rk("maximin on levels")),
         size = sprintf("below the floor: under up_std %s; under up_inc %s", below("up_std"), below("up_inc")),
         threshold = sprintf("admissible at alpha = 0: %s; at alpha = %s: %s; each design becomes admissible from alpha = %s (up_std) and %s (up_inc)",
                             if (any(adm$alpha_0)) paste(adm$design[adm$alpha_0], collapse = ", ") else "none", f2(set$FLOOR_ALPHA),
                             if (any(adm$alpha_0.10)) paste(adm$design[adm$alpha_0.10], collapse = ", ") else "none",
                             pc(adm$alpha_star[adm$design == "up_std"]), pc(adm$alpha_star[adm$design == "up_inc"])),
         carrying = rows_status(c("operator_margin_share", "hiring_hh_share", "time_value_ratio_hullers", "inclusive_rule_enforcement")),
         measure = "who operates the plan's machines and who receives the operator margin (BOLDER request 14; field work 2027)",
         conv = "up_std", p_conv = NA, set_conv = "addressees' account", open = "up_inc", p_open = t4e$p_ahead[t4e$rule == "maximin"],
         set_open = "maximin", thr = NA, lo = NA, hi = NA, thr_lab = "", thr_unit = ""),
    list(test = "T5", axis = "Axis 5 value of information", kind = if (!is.null(pp) && pp[["self"]] != pp[["hire"]]) "preferred option flips" else "size only",
         from_to = "one decision for the commune -> a decision per household type (V1); utilitarian -> maximin",
         what = sprintf("the planner's profile %s (only out targetable) against %s for all; leading row utilitarian `%s`, maximin `%s`",
                        planner_r, het$d_star[het$profiles == "restricted"][1], lead_util, lead_mm),
         size = sprintf("static VoH %s (MCSE %s), dynamic VoH %s (MCSE %s) per producer household; EVPI of one decision %s",
                        fk(hv("restricted", "VoH_static")), f0(hv("restricted", "VoH_static", "mcse")),
                        fk(hv("restricted", "VoH_dyn")), f0(hv("restricted", "VoH_dyn", "mcse")), fk(hv("restricted", "EVPI"))),
         threshold = sprintf("voh_index %s (static VoH / EVPI)", f2(hv("restricted", "voh_index"))),
         carrying = rows_status(c("hiring_hh_share", "time_value_ratio_hullers", "recovery_hand_share", "plan_machine_share")),
         measure = "which households hull themselves and which hire, and whether machine access can be registered by household (field work 2027)",
         conv = het$d_star[het$profiles == "restricted"][1], p_conv = NA, set_conv = "one decision",
         open = "mixed", p_open = NA, set_open = planner_r, thr = NA, lo = NA, hi = NA, thr_lab = "", thr_unit = ""),
    list(test = "T6", axis = "Fidelity (across directions); H4", kind = if (t6_sign_change) "sign or visibility" else "size only",
         from_to = "full delivery (1, 1) -> the same mean fidelity 0.5 with different compositions (up_inc)",
         what = sprintf("hullers under up_inc: %s at (1, 1); %s at (0.5, 0.5); %s at (0.25, 0.75); %s at (0.75, 0.25) per person",
                        fk(cm(1, 1, "up_inc", "H_mean")), fk(cm(.5, .5, "up_inc", "H_mean")), fk(cm(.25, .75, "up_inc", "H_mean")), fk(cm(.75, .25, "up_inc", "H_mean"))),
         size = sprintf("at mean fidelity 0.5 the commune moves by %s per producer household, the hullers by %s per person",
                        fk(cc$commune_range), fk(cc$hullers_range)),
         threshold = sprintf("rule delivery e* = %s at full machine delivery (hullers' mean 0); P(hullers lose) <= %s %s",
                             f2(es$e_star), pc(set$FLOOR_ALPHA), if (is.na(es$e_alpha)) sprintf("for no e up to 1 (at e = 1: %s)", pc(es$H_p_loss_at_e1)) else sprintf("from e = %s", f2(es$e_alpha))),
         carrying = rows_status(c("plan_implementation_share", "inclusive_rule_enforcement", "operator_margin_share", "hiring_hh_share")),
         measure = "which components of the plan arrive: machines (reach) and the operator rule (distribution), separately (BOLDER request 14)",
         conv = "up_inc", p_conv = NA, set_conv = "(1, 1)", open = "up_inc", p_open = NA, set_open = "mean 0.5",
         thr = es$e_star, lo = 1, hi = 1, thr_lab = sprintf("e* = %s", f2(es$e_star)), thr_unit = "rule delivery e (design: 1, const)"))
  strength <- c("preferred option flips" = 3, "ranking of the rule designs" = 3, "valuation layer: a ranking needs an explicit rule" = 3,
                "sign or visibility" = 2, "size only" = 1)
  sh <- do.call(rbind, lapply(shift, function(z) as.data.frame(z[c("test", "axis", "kind", "from_to", "what", "size", "threshold",
                                                                   "carrying", "measure")], stringsAsFactors = FALSE)))
  sh <- sh[order(-strength[sh$kind], seq_len(nrow(sh))), ]
  sm <- do.call(rbind, lapply(shift, function(z) data.frame(test = z$test, kind = z$kind, option_conv = z$conv, p_conv = z$p_conv,
    setting_conv = z$set_conv, option_open = z$open, p_open = z$p_open, setting_open = z$set_open, threshold = z$thr,
    prior_lo = z$lo, prior_hi = z$hi, threshold_label = z$thr_lab, threshold_unit = z$thr_unit, stringsAsFactors = FALSE)))
  sm <- rbind(data.frame(test = "T0", kind = "", option_conv = t0$option, p_conv = t0$p_ahead, setting_conv = "G, V0",
                         option_open = t0$option, p_open = t0$p_ahead, setting_open = "(the reading itself)", threshold = NA,
                         prior_lo = NA, prior_hi = NA, threshold_label = "", threshold_unit = "", stringsAsFactors = FALSE), sm)
  write.csv(sm, file.path(OUT, "shift_map.csv"), row.names = FALSE)

  # ---------------------------------------------------------------- the document
  n_status <- table(factor(inp$status, levels = c("L", "W", "T", "B", "P")))
  add("# Key findings v9: H1-H4 and the five axes as the manuscript states them (Atacora fonio case)", "",
      "*Basis for part 04. Generated by `analysis/write_key_findings.R` from the run of `atacora_DA_run.R`; every number comes from that run. Values against the status quo in FCFA (CFA francs), discounted over 10 years, per producer household of the commune unless stated otherwise (per woman, per huller). No recommendation: every statement holds under these priors.*", "")

  add("## 0 · Status", "",
      sprintf("- Branch `%s`, commit `%s` (the run's code; outputs and docs are written by the run). Seed %s, %s Monte Carlo draws. Tests: %s.",
              branch, commit, set$seed, format(set$draws, big.mark = ","),
              if (is.null(ts)) "see `analysis/00_run_tests.R`" else sprintf("%d of %d passed", ts$passed, ts$total)),
      sprintf("- Input rows (`data/estimates/atacora_DA_inputs_v8.csv`, %d): %s. L literature (Benin, West Africa), W workshop or Dataverse, T transferred, B to be asked at BOLDER (broad prior until then), P prior set by us.",
              nrow(inp), paste(names(n_status), n_status, collapse = ", ")),
      "- New in v9: the historical reference `own_consumption_share_behavioural_alt` (L, Ballogou et al. 2014, survey of 2011) is back as the last row; the main run does not read it (greyed-out line in block (0) of the model), T2 swaps it in and re-runs the model on the same draws. Every other input keeps its v8 draws; the downtime years, drawn inside the model after the inputs, are new draws, so the v9 numbers differ from v8 within Monte Carlo error.",
      "- Settings: **V0** money only; **V1** reference *behaviour* (main run): unpaid hulling time at replacement cost (omega = 1), a freed huller hour at theta (0-1) of the wage, a kg eaten at the market price (kappa = 1); **PREF** reference *preference*: every freed hour at the off-farm hourly value (B row), kappa = 1.",
      sprintf("- Accounts: G producer household; Wg its women (time only); H paid hullers, per person (%s per producer household); O private operator (out only). Commune = G + %s H + O, per producer household. Household types self and hire, mixed with `hiring_hh_share`.", set$K_H, set$K_H),
      sprintf("- Rules that rank (over G and H per person, p = (1, %s) / %s): %s. The strict floor (`w_constrained(0)`) constrains the option set and does not rank: it appears only as admissibility (T4), without a value and without an EVPI. Floor flag: a group below its status quo in more than %s of the draws.",
              set$K_H, 1 + set$K_H, paste(set$rules, collapse = ", "), pc(set$FLOOR_ALPHA)),
      sprintf("- Atkinson offset on the changes: the median NPV of a producer household's status quo money is %s. %s Offset used: %s; every shifted value > 0: %s. On the levels (T4): offset %s.",
              fk(set$ATKINSON_MEDIAN),
              if (set$atkinson_draws_below_median > 0) sprintf("In %d of %s draws a paid huller's loss reaches it (under V0, V1 or PREF), where the index is undefined; the offset is therefore raised to the next 100,000 FCFA above the largest loss.", set$atkinson_draws_below_median, format(set$draws, big.mark = ",")) else "No shifted value reaches 0.",
              fk(set$ATKINSON_OFFSET), yn(all(res$T4$offset_ok)), fk(res$T4$level_offset)), "")

  # ---------------------------------------------------------------- §1 checklist
  ad_rank <- sprintf("reach %s, compliance %s, utilitarian %s; addressees' account %s; prioritarian, Atkinson and maximin (changes and levels) %s",
                     rk("reach"), rk("compliance"), rk("utilitarian"), rk("addressees' account"),
                     paste(unique(dsg$ranking[dsg$measure %in% worse_off_rules]), collapse = "/"))
  check <- rbind(
    c("**H1** (out)", "compares an adopting-unit boundary with an extension covering a specified displaced activity, then compares aggregate and group outcomes",
      "T1a (boundary G -> G + H + O), T3 (units)", "yes",
      sprintf("preferred %s -> %s (V1); hullers under out lose in %s of draws, hidden in 'women' pooled in %s", pref_b("V1", "G"), pref_b("V1", "G + H + O"),
              pc(p_loss("NB_H_out_V1")), pc(hid$p_women_gain_hullers_lose[hid$option == "out"]))),
    c("**H2** (up)", "counts whoever the rule addresses; uses the rule's threshold as a floor; compares consequences under different fairness rules; ranks rule designs differently than compliance or reach; who remains below the floor",
      "T4 (design table, floor table, EVPI of the design choice)", "yes",
      sprintf("%s; below the floor: up_std %s, up_inc %s", ad_rank, below("up_std"), below("up_inc"))),
    c("**H3** (deep)", "retains a relevant non-monetary outcome and compares group-specific consequences with the monetary assessment; a ranking change requires an explicit rule; awareness alone is no norm change",
      "H3 card (T1b_aspiration.csv, T1b_pareto.csv)", "yes",
      sprintf("deep never ahead in money; closer to 'more fonio eaten' in %s of draws; %s; kappa = 1.5 puts %s ahead in %s",
              pc(eat_closer), if (one_dominates_all) sprintf("%s dominates on every aim", dominant[1]) else "no option is closer on every aim of every account",
              k15$preferred_G, pc(k15$p_ahead))),
    c("**H4** (fidelity)", "varies component delivery separately as a ratio of the designed component and examines group outcomes",
      "T6 (compositions, e*, concealment)", "yes",
      sprintf("e* = %s; at mean fidelity 0.5 the commune moves by %s, the hullers by %s per person", f2(es$e_star), fk(cc$commune_range), fk(cc$hullers_range))),
    c("**Closing paragraph**", "per test: enabling assumptions and when the mechanism disappears; group losses, threshold violations, ranking changes, information value; an unchanged ranking can coexist with a consequential distributive difference",
      "section 4, one card with six points per test", "yes", "six points per test; 'unchanged ranking, consequential distributive difference' named in T3, T4 and T6 where it holds"),
    c("**Axis 1** boundary", "the boundary decides over the valuation layer in which an effect can enter the model; one monetary indicator commits the model to the lowest layer",
      "T1a, T1b (money), H3 (stated aims)", "partly",
      "the stated aims enter as directions, next to the money; worldviews, broad values and relational values are not represented (survey, field work 2027)"),
    c("**Axis 2** reference", "progress towards a valued situation; running the same decision against a presence- and a historically-informed baseline",
      "T2 (behaviour vs preference; historical re-run), H3 index", "yes",
      sprintf("commune %s -> %s (V1 -> PREF); historical reference: %s", pref_t2(comm_acc)[[1]], pref_t2(comm_acc)[[2]],
              if (nrow(hist_flips)) "the preferred option changes" else "no preferred option changes (under V1 by identity)")),
    c("**Axis 3** reporting unit", "changing the reporting unit alone does not change the collective decision rule; separate reporting does not establish independent interventions",
      "T3 (visibility), T5 (only out can be targeted)", "yes",
      sprintf("hidden loss %s under out; own rankings are not a collective decision", pc(hid$p_women_gain_hullers_lose[hid$option == "out"]))),
    c("**Axis 4** fairness", "state what is distributed; maximising the minimum gain does not necessarily prioritise the lowest initial welfare; the preferred option under each rule and the rank correlation; the floor constrains instead of ranking",
      "T4", "yes",
      sprintf("changes of valued money (V1) per person; minimum on the changes: hullers in %s (up_inc), on the levels in %s; smallest rank correlation over the five options %s",
              pc(mn$changes_min_is_hullers[mn$design == "up_inc"]), pc(mn$levels_min_is_hullers[mn$design == "up_inc"]), f3(res$T4$rank_cor_min))),
    c("**Axis 5** information", "research priorities depend on the criterion; small groups; groups whose stake lies in values that do not translate into the outcome variable",
      "T5 (ladder, rules, types), H3 (EVPI in kg)", "yes",
      sprintf("the research priority %s; `time_value_ratio_hullers` %s for the hullers, %s for the commune; EVPI in kg %s (deep's own rows 0)", prio_txt,
              fk(tvr_H), fk(tvr_comm), f1(kgd$EVPI_kg))))
  add("## 1 · Checklist H1-H4 and the five axes (handoff v9, section 0)", "",
      "| requirement (manuscript) | what the text asks | where shown (v9) | fulfilled | v9 result |", "|---|---|---|---|---|")
  for (i in seq_len(nrow(check))) add(sprintf("| %s |", paste(check[i, ], collapse = " | ")))
  add("", sprintf("Partly fulfilled: %s.", paste(sub("^\\*\\*(.*)\\*\\*.*$", "\\1", check[check[, 4] == "partly", 1]), collapse = ", ")), "")

  # ---------------------------------------------------------------- §2 T0
  add("## 2 · The conventional reading (T0)", "",
      sprintf("- Preferred option: **%s**, best in %s of the draws.", LAB[[t0$option]], pc(t0$p_ahead)),
      sprintf("- Closest option: %s, mean %s (above 0 in %s of the draws).", LAB[[runner]], fk(t0m$mean[t0m$option == runner]), pc(t0m$p_gain[t0m$option == runner])),
      sprintf("- EVPI of this decision: %s per producer household; the inputs with the largest partial EVPI: %s.",
              fk(t0$EVPI), lead_txt("T0_model")), "",
      sprintf("Read with money only and one decision for the commune, %s is ahead: every option with a machine costs the household a fee, the hours it saves are not counted, and the kg kept at home count for nothing.", LAB[[t0$option]]),
      "")

  # ---------------------------------------------------------------- §3 shift table
  add("## 3 · Shift table", "",
      "One row per test, ordered by the kind of shift (the preferred option or the ranking of designs flips, or the valuation layer needs a rule > a sign or the visibility of a group changes > size only). Values against the status quo, FCFA.", "",
      "| test (axis; H) | conventional -> opened | what shifts | size | threshold against prior | carrying rows (status) | to be measured | kind |",
      "|---|---|---|---|---|---|---|---|")
  for (i in seq_len(nrow(sh))) add(sprintf("| %s (%s) | %s | %s | %s | %s | %s | %s | %s |", sh$test[i], sh$axis[i], sh$from_to[i],
                                           sh$what[i], sh$size[i], sh$threshold[i], sh$carrying[i], sh$measure[i], sh$kind[i]))
  byid <- setNames(shift, sapply(shift, `[[`, "test"))
  seven <- rbind(
    c("T1 boundary and objectives in money (axis 1; H1)", "G -> G + H + O; money -> hours -> kg valued",
      sprintf("%s -> %s once hullers and operator count; %s -> %s once hours are valued", byid$T1a$conv, byid$T1a$open, byid$T1b$conv, byid$T1b$open),
      sprintf("omega* out %s (off-farm/wage %s-%s)", f2(omega_out_sq), f2(wq[[1]]), f2(wq[[3]]))),
    c("H3 valuation layer (axis 1; H3)", byid$H3$from_to, byid$H3$what, byid$H3$threshold),
    c("T2 reference (axis 2)", byid$T2$from_to, byid$T2$what, sprintf("off-farm > wage_h in %s of draws; commune w* %s FCFA/h", pc(p_off_above), f0(w_star_comm))),
    c("T3 reporting unit (axis 3; H1)", byid$T3$from_to, byid$T3$size, byid$T3$threshold),
    c("T4 fairness criterion (axis 4; H2)", "the plan's two rule designs under reach, compliance, the addressees' account and the fairness rules", byid$T4$what, byid$T4$size),
    c("T5 value of information (axis 5)", byid$T5$from_to, byid$T5$size, byid$T5$threshold),
    c("T6 fidelity (H4)", byid$T6$from_to, byid$T6$what, byid$T6$threshold))
  add("", "**Table for part 04 (one row per test):**", "",
      "| test | switch | what shifts | threshold / condition |", "|---|---|---|---|")
  for (i in seq_len(nrow(seven))) add(sprintf("| %s |", paste(seven[i, ], collapse = " | ")))
  add("")

  # ---------------------------------------------------------------- §4 the test cards
  add("## 4 · The tests, one card each", "",
      "Each card opens with the shift in one sentence and then gives the six points of the closing paragraph of H1-H4: the mechanism and the assumptions that enable it (with the status of the carrying rows), when it disappears (the null condition, tested in `tests/testthat/test-model.R`), the losses per group, floor and threshold violations, the change in the ranking, and the value of information under both settings of the test with its leading rows (`multi_EVPI()`, partial EVPI of one input for the decisive pair).", "")

  # T1a
  add("### T1a · System boundary: whose accounts count (axis 1; H1 out)", "",
      sprintf("**Whether equipment counts as a gain depends on whose accounts are inside the boundary: for the producer household under the behavioural reference %s is ahead; once the paid hullers and the operator are counted, %s is.** (Money only: %s -> %s.)",
              LAB[[pref_b("V1", "G")]], LAB[[pref_b("V1", "G + H + O")]], LAB[[pref_b("V0", "G")]], LAB[[pref_b("V0", "G + H + O")]]), "")
  card(mech = sprintf("the machine displaces paid hand hulling; what the hiring household saves in fees, the hullers lose in wages, and the fee goes to the operator. Carrying rows: %s.",
                      rows_status(c("hiring_hh_share", "hand_service_price_fcfa_kg", "time_value_ratio_hullers", "operator_margin_share"))),
       null = "no household hires hullers (`hiring_hh_share` = 0): the hullers' account is 0 under out, up_std and deep in every setting.",
       losses = sprintf("out, V1: producer household %s (loss in %s), its women %s (loss in %s), hullers %s per person (loss in %s), operator %s. up_std: hullers loss in %s.",
                        fk(mean_of("NB_G_out_V1")), pc(p_loss("NB_G_out_V1")), fk(mean_of("NB_Wg_out_V1")), pc(p_loss("NB_Wg_out_V1")),
                        fk(mean_of("NB_H_out_V1")), pc(p_loss("NB_H_out_V1")), fk(mean_of("NB_O_out_V1")), pc(p_loss("NB_H_up_std_V1"))),
       floor = sprintf("under out below the floor: %s; flagged over %s: %s. No threshold: a boundary is included or not.",
                       below("out"), pc(set$FLOOR_ALPHA), paste(ACC[fl$group[fl$option == "out" & fl$flag]], collapse = ", ")),
       ranking = sprintf("G -> G + H + O under V1: %s -> %s; under V0: %s -> %s. Options whose mean changes sign across the three boundaries: %s.",
                         pref_b("V1", "G"), pref_b("V1", "G + H + O"), pref_b("V0", "G"), pref_b("V0", "G + H + O"),
                         if (nrow(signs_T1a)) paste(sprintf("%s (%s)", signs_T1a$option, signs_T1a$setting), collapse = ", ") else "none"),
       info = sprintf("EVPI G %s -> G + H + O %s per producer household (V1). Leading rows: G %s; commune %s. The leading row %s.",
                      fk(ev_b("V1", "G")), fk(ev_b("V1", "G + H + O")), lead_txt("T5_level_G"), lead_txt("main_model"),
                      if (identical(lead1("T5_level_G"), lead1("main_model"))) "does not change" else "changes"))

  # T1b money
  add("### T1b · Which workshop objectives count, in money (axis 1)", "",
      sprintf("**In money, whether the household gains from scaling turns on how women's hulling time and the food kept at home are valued: with money only %s is ahead, with the hours valued at replacement cost %s, and with the kg eaten at the market price as well %s.**",
              LAB[[pref_p(steps[1], "G")]], LAB[[pref_p(steps[2], "G")]], LAB[[pref_p(steps[3], "G")]]), "",
      sprintf("- Producer household, V0 -> time only -> V1: out %s -> %s -> %s; up_std %s -> %s -> %s; deep %s -> %s -> %s.",
              fk(mean(Y$C_G_cash_out)), fk(mean(Y$C_G_cash_out + Y$C_G_time_out)), fk(mean_of("NB_G_out_V1")),
              fk(mean(Y$C_G_cash_up_std)), fk(mean(Y$C_G_cash_up_std + Y$C_G_time_up_std)), fk(mean_of("NB_G_up_std_V1")),
              fk(mean(Y$C_G_cash_deep)), fk(mean(Y$C_G_cash_deep + Y$C_G_time_deep)), fk(mean_of("NB_G_deep_V1"))),
      sprintf("- Thresholds (closed form, expected values; kappa = 1): out beats the status quo for the household from omega* = %s and every other option from %s; for the commune from %s. up_std beats the status quo from omega* = %s. Context: the off-farm hour is worth %s-%s times the hulling wage (5-95 %% of the draws). Against the best other option deep needs kappa > %s (household) and %s (commune).",
              f2(omega_out_sq), f2(omega_out_best), f2(omega_out_sq_comm), f2(omega_upstd_sq), f2(wq[[1]]), f2(wq[[3]]), f2(kappa_deep_best), f2(kappa_deep_best_comm)),
      "- The same test in the stated aims instead of money is H3 below; the six points are given there and in T1a.", "")

  # H3
  add("### H3 · The valuation layer as a boundary: deep and the stated aims (axis 1; H3 deep)", "",
      sprintf("**Measured in money, deep is never ahead (money only it loses %s per producer household; at market prices it is exactly 0, an identity); measured against the aims people stated themselves, %s: it brings 'more fonio eaten' closer in %s of the draws and is ahead of every other option on that aim in %s. %s**",
              fk(-mean_of("NB_G_deep_V0")), if (deep_only_eat) "it is the only option that brings more eating closer on average" else sprintf("the options that bring more eating closer on average are %s", eat_pos),
              pc(eat_closer), pc(eat_ahead),
              if (one_dominates_all) sprintf("%s is closer on every aim of every account.", LAB[[dominant[1]]]) else
                "No option is closer on every aim; for the household and for the hullers no option dominates, so any ranking needs an explicit rule."),
      "", "The perception-informed reference: aims stated locally, with direction and source; no target levels are set.", "",
      "| stated aim | wording / source | quantity in the model | direction | accounts |", "|---|---|---|---|---|")
  for (i in seq_len(nrow(AIMS))) add(sprintf("| %s | \"%s\" (%s) | %s | %s | %s |", AIMS$aim[i], AIMS$wording[i], AIMS$source[i], AIMS$quantity[i],
                                             if (AIMS$s[i] > 0) "more" else "less", AIMS$accounts[i]))
  add("", sprintf("Not modelled (no quantity of the thin core carries them): %s.", paste(set$aims_not_modelled, collapse = "; ")), "",
      "Index of progress towards the stated aim: `progress = s (Y(d) - Y(sq)) / |Y(sq)|`, s = +1 where more is wanted and -1 where less is; > 0 = closer. Unit-free, a share of today's level. For less drudgery it is the share of today's distance that the option closes (the aim has an end point: no hand hulling). For more eaten and higher income the target level is not stated (to be asked, field work 2027): the ranking of the options **within** an aim does not depend on it, the comparison **across** aims does. No weights and no sum over the aims. In the thin core, less drudgery and a future outside farming are measured by the same hours (hand hulling; the model has no field hours and no hours of operating machines), so their rows coincide; they are stated aims of their own and are kept apart.", "",
      "| account | aim | out | up_std | up_inc | deep | money V0: out / up_std / up_inc / deep | money V1: out / up_std / up_inc / deep |",
      "|---|---|---|---|---|---|---|---|")
  for (k in unique(paste(A$account, A$aim, sep = "|"))) {
    a <- sub("[|].*", "", k); aim <- sub(".*[|]", "", k)
    cell <- function(o) sprintf("%s [%s; %s], closer %s", pc1(am(a, aim, o)), pc1(am(a, aim, o, "q10")), pc1(am(a, aim, o, "q90")), pc(am(a, aim, o, "p_closer")))
    mon <- function(col) paste(f0(sapply(c("out", "up_std", "up_inc", "deep"), function(o) am(a, aim, o, col))), collapse = " / ")
    add(sprintf("| %s | %s | %s | %s | %s | %s | %s | %s |", ACC[[a]], aim, cell("out"), cell("up_std"), cell("up_inc"), cell("deep"),
                mon("money_V0_mean"), mon("money_V1_mean")))
  }
  add("", "Cells: mean progress [10-90 %], share of draws closer. Money: expected value against the status quo, FCFA per account.", "")
  pareto_line <- paste(sapply(c("G", "Wg", "H"), function(a) sprintf("%s: %s (on %s)", ACC[[a]], paste(pareto_set(a), collapse = ", "),
                                                                     par$aims[par$account == a][1])), collapse = "; ")
  dirs <- res$T1$directions
  dir_line <- function(a, o) { z <- dirs[dirs$account == a & dirs$option == o, ]
    paste(sprintf("%s %s (closer in %s of the draws)", c(closer = "closer to", further = "further from", unchanged = "unchanged on")[z$direction],
                  z$aim, pc(z$p_closer)), collapse = ", ") }
  card(mech = sprintf("the campaign raises the share of the grain eaten at home, so kg move from sale to the plate (D1, D2); machines take over hand hulling (P1) and change the grain recovered (P3); the paid hullers' income falls with the paid kg (M2). The index compares each option with today's level (section 9 of the model). Carrying rows: %s.",
                      rows_status(c("awareness_consumption_change_share", "awareness_reach_share", "awareness_decay_rate", "recovery_hand_share", "recovery_machine_share", "hand_hull_rate_kg_h"))),
       null = "no household reached (`awareness_reach_share` = 0): deep equals the status quo in every output; kappa = 1: deep's money is exactly 0 in every draw; deep moves no hour and never lowers the kg eaten.",
       losses = sprintf("on the aims (direction of the mean; share of draws closer): household under out %s; under deep %s; hullers under out %s; under up_inc %s. In money (V1) the household under deep loses nothing (0 by identity), under V0 in every draw.",
                        dir_line("G", "out"), dir_line("G", "deep"), dir_line("H", "out"), dir_line("H", "up_inc")),
       floor = sprintf("the index has no floor of its own; in money (V1) deep leaves no group below its status quo, out leaves %s. The explicit rule kappa = 1.5 (greyed out in section 7 of the model) is such a threshold: deep against the status quo %s for the household, above 0 in %s of the draws.",
                       below("out"), fk(k15$mean_deep_vs_sq), pc(k15$p_deep_gain)),
       ranking = sprintf("money V0: %s; V1: %s (deep tied with the status quo). On the stated aims, the options no other option matches on every aim and beats on one (Pareto, on expected progress): %s. Where more than one option remains, a ranking needs an explicit rule; kappa = 1.5 is one: it puts %s ahead for the household in %s of the draws.",
                         pref_p(steps[1], "G"), pref_p(steps[3], "G"), pareto_line, LAB[[k15$preferred_G]], pc(k15$p_ahead)),
       info = sprintf("in money deep's rows are worth %s (G, V0) and %s (commune, V1): deep is never ahead. On the aim 'more fonio eaten' the decision is worth %s kg per producer household over ten years (EVPI; decisive pair %s, the rival ahead in %s of the draws; by mean the runner-up is %s, which deep beats in every draw). Its leading rows: %s. Deep's own rows on this aim: %s. Under the explicit rule kappa = 1.5 (money, G): %s; deep's rows %s. %s",
                      paste(f0(dr$money_G_V0), collapse = "/"), paste(f0(dr$money_commune_V1), collapse = "/"), f1(kgd$EVPI_kg), kgd$decisive_pair,
                      pc(kgd$p_rival_ahead), kgd$runner_up_by_mean, lead_txt("H3_kg_eaten", digits = 1),
                      paste(sprintf("`%s` %s", dr$row, f1(pmax(dr$kg_more_eaten, 0))), collapse = ", "),
                      lead_txt("H3_kappa15"), paste(sprintf("`%s` %s", dr$row, f0(pmax(dr$money_G_kappa15, 0))), collapse = ", "),
                      if (all(dr$kg_more_eaten < 0.05, na.rm = TRUE)) "On the stated aim the information value lies in the recovery rows (whether the machine recovers more grain than the hand), not in deep's rows: deep stays ahead of its rival in expectation whatever the size of the campaign, so no single one of its rows can reverse the choice." else ""))
  add("- Caveats: the index measures closeness to stated aims in the quantities the model contains. It does not measure relational values, relations or agency; these are left to the survey (worldviews and broad values). A campaign alone does not show a change of norms: the change in consumption is a transferred behavioural row (T).", "")

  # T2
  add("### T2 · Reference state: behaviour, preference and history (axis 2)", "",
      sprintf("**Whether displacement is a loss for the paid hullers depends on the reference: measured against what they do today they lose under out in %s of the draws; measured against where young women say they want to be, they gain in %s. Against the historical reference (the share eaten at home in 2011) %s.**",
              pc(1 - pg_t2(hull_acc, "out", "behaviour")), pc(pg_t2(hull_acc, "out", "preference")),
              if (nrow(hist_flips)) sprintf("the preferred option changes (%s): the recommendation hangs on the history chosen", paste(sprintf("%s %s", hist_flips$account, hist_flips$setting), collapse = ", ")) else
                "no preferred option changes: the recommendation does not hang on the history chosen"), "",
      sprintf("- Per person under out: hullers %s (behaviour) -> %s (preference); women in producer households %s -> %s. Commune: out %s -> %s; preferred %s -> %s.",
              fk(m_t2(hull_acc, "out", "behaviour")), fk(m_t2(hull_acc, "out", "preference")),
              fk(m_t2(Wg_acc, "out", "behaviour")), fk(m_t2(Wg_acc, "out", "preference")),
              fk(m_t2(comm_acc, "out", "behaviour")), fk(m_t2(comm_acc, "out", "preference")), pref_t2(comm_acc)[[1]], pref_t2(comm_acc)[[2]]),
      sprintf("- Preferred option per account, behaviour -> preference: %s.",
              paste(sprintf("%s %s -> %s", unique(t2$account), sapply(unique(t2$account), function(a) pref_t2(a)[[1]]),
                            sapply(unique(t2$account), function(a) pref_t2(a)[[2]])), collapse = "; ")),
      sprintf("- Rules over G and H whose choice flips between behaviour and preference: %s.", if (length(rule_flips_t2)) paste(rule_flips_t2, collapse = ", ") else "none"),
      sprintf("- Non-monetary reading (progress towards a valued situation): the index of H3 for less drudgery and a future outside farming, next to the money under V1 -- out brings the women of producer households and the hullers alike %s closer (the machine share), while the hullers' income moves %s. Not repeated here.",
              pc(am("Wg", "less drudgery", "out")), pc(am("H", "higher income", "out"))),
      sprintf("- Historical reference (the greyed-out line swapped in, the model re-run on the same draws): median share eaten at home %s today (P) against %s in the 2011 survey (L). Preferred option, today -> historical: %s. Rules over G and H (V1): %s. Deep's progress towards more fonio eaten %s -> %s (closer in %s -> %s; the share reaches 1 during the campaign in %s of the draws), in kg %s -> %s.",
              pc(he$share_eaten_median[1]), pc(he$share_eaten_median[2]),
              paste(sprintf("%s %s %s -> %s", hs$account, hs$setting, hs$preferred_today, hs$preferred_historical), collapse = "; "),
              if (length(hist_rule_flips)) paste("flip:", paste(hist_rule_flips, collapse = ", ")) else "no rule changes its choice",
              pc1(he$deep_progress_mean[1]), pc1(he$deep_progress_mean[2]), pc(he$deep_p_closer[1]), pc(he$deep_p_closer[2]),
              pc(he$p_share_capped_at_1[2]), f1(he$deep_kg_mean[1]), f1(he$deep_kg_mean[2])),
      "- Why V1 cannot move with the history: at kappa = 1 a kg eaten counts as much as a kg sold, so the share eaten drops out of every V1 and PREF account (identity); only money only (V0) sees the share, and there the preferred option stays the same.",
      "- Caveats: the historical row is documented; that does not make a return to it desirable. The aspirations come from a youth sample (14-40 years, three communes, only Natitingou in the Atacora; Mausch et al. 2025, L); an aspiration is not an opportunity; the off-farm hourly value is a B row.", "")
  card(mech = sprintf("the reference fixes what a freed hour is measured against -- under behaviour the status quo is the activity chosen, under preference a distance to the state wanted; the historical reference changes the share of the grain eaten at home. Carrying rows: %s.",
                      rows_status(c("opportunity_wage_fcfa_h", "hand_service_price_fcfa_kg", "hand_hull_rate_kg_h", "time_value_ratio_hullers", "own_consumption_share_behavioural", "own_consumption_share_behavioural_alt"))),
       null = "off-farm value = wage_h: the hullers' account under out and up_std is 0 under PREF; a historical share equal to today's reproduces the main run exactly; V1 and PREF differ only in the hour weights.",
       losses = sprintf("hullers under out lose in %s (behaviour) and in %s (preference) of the draws; women in producer households lose in %s and %s.",
                        pc(1 - pg_t2(hull_acc, "out", "behaviour")), pc(1 - pg_t2(hull_acc, "out", "preference")),
                        pc(mean(Y$NB_Wg_out_V1 < 0)), pc(mean(Y$NB_Wg_out_PREF < 0))),
       floor = sprintf("under PREF the hullers stay below their status quo under out in %s of the draws (flag over %s: %s). Threshold: the off-farm value must exceed wage_h (identity), which it does in %s of the draws (off-farm 5-95 %%: %s-%s FCFA/h; wage_h %s-%s FCFA/h); the commune's preferred option changes at %s FCFA/h (household %s FCFA/h), %s.",
                       pc(mean(Y$NB_H_out_PREF < 0)), pc(set$FLOOR_ALPHA), yn(mean(Y$NB_H_out_PREF < 0) > set$FLOOR_ALPHA),
                       pc(p_off_above), f0(off_q[[1]]), f0(off_q[[3]]), f0(wage_q[[1]]), f0(wage_q[[3]]), f0(w_star_comm), f0(w_star_G),
                       if (!is.na(w_star_comm) && w_star_comm < off_q[[1]]) "below the 5 % quantile of the prior" else if (!is.na(w_star_comm) && w_star_comm > off_q[[3]]) "above the 95 % quantile of the prior" else "inside the 90 % range of the prior"),
       ranking = sprintf("commune %s -> %s (V1 -> PREF); historical reference: %s.", pref_t2(comm_acc)[[1]], pref_t2(comm_acc)[[2]],
                         if (nrow(hist_flips)) "the preferred option changes" else "unchanged ranking under V0 and V1; under V0 the size of the values changes"),
       info = sprintf("EVPI of the commune %s (behaviour) -> %s (preference); leading rows %s -> %s. Historical reference: EVPI of the commune under V0 %s -> %s, under V1 %s -> %s.",
                      fk(ev("V1", comm_acc)), fk(ev("PREF", comm_acc)), lead_txt("main_model"), lead_txt("T2_commune_PREF"),
                      fk(hs$EVPI_today[hs$setting == "V0" & hs$account == "comm"]), fk(hs$EVPI_historical[hs$setting == "V0" & hs$account == "comm"]),
                      fk(hs$EVPI_today[hs$setting == "V1" & hs$account == "comm"]), fk(hs$EVPI_historical[hs$setting == "V1" & hs$account == "comm"])))

  # T3
  add("### T3 · Reporting unit: women against women (axis 3; H1 out)", "",
      sprintf("**Reported per person, the same equipment is a gain for the women of producer households and a loss for the paid hullers: under out the first gain in %s of the draws, the second lose in %s; pooled as \"women\", the gain hides the loss in %s of the draws. The shift is one of visibility: the collective decision rule does not change.**",
              pc(mu(Wg_acc, "out", "p_gain")), pc(mu(hull_acc, "out", "p_loss")), pc(hid$p_women_gain_hullers_lose[hid$option == "out"])), "",
      sprintf("- Each unit's own ranking of the options (by mean, V1) -- not a collective decision: %s.",
              paste(sprintf("%s: %s", own$unit, own$own_ranking), collapse = "; ")),
      "- Reporting the two groups separately does not establish that they can receive separate interventions. That is tested in T5: of the options, only out can be steered to one household type.",
      sprintf("- Hidden loss (`marginalisation_count()`, women pooled gain while the hullers lose): out %s, up_std %s, up_inc %s of the draws.",
              pc(hid$p_women_gain_hullers_lose[hid$option == "out"]), pc(hid$p_women_gain_hullers_lose[hid$option == "up_std"]),
              pc(hid$p_women_gain_hullers_lose[hid$option == "up_inc"])), "")
  card(mech = sprintf("the hours a self-hulling household saves are the hours a hiring household no longer pays for; the first are the women's own, the second were the hullers' income. Carrying rows: %s.",
                      rows_status(c("hiring_hh_share", "time_value_ratio_hullers", "hand_service_price_fcfa_kg"))),
       null = "no household hires hullers (`hiring_hh_share` = 0): the hullers' account is 0 under out, nothing can be hidden.",
       losses = sprintf("under V1 (mean; loss share): %s.",
                        paste(sapply(c(Wg_acc, hull_acc, "women pooled"), function(k) sprintf("%s: out %s (%s), up_std %s (%s), up_inc %s (%s)", k,
                              f0(mu(k, "out")), pc(mu(k, "out", "p_loss")), f0(mu(k, "up_std")), pc(mu(k, "up_std", "p_loss")),
                              f0(mu(k, "up_inc")), pc(mu(k, "up_inc", "p_loss")))), collapse = "; ")),
       floor = sprintf("the hullers stay below their status quo under out in %s of the draws (flagged); the women in producer households in %s. Threshold: 'women' pooled change sign under out at a hiring household share of %s (prior 5-95 %%: %s-%s; above it in %s of the draws).",
                       pc(flr("out", "H")), pc(flr("out", "Wg")), f2(t3thr$hiring_share_star), f2(t3thr$prior_5), f2(t3thr$prior_95), pc(t3thr$p_prior_above)),
       ranking = sprintf("unchanged ranking, consequential distributive difference: the commune's preferred option stays %s whatever the unit; the units' own rankings differ (women %s first, hullers %s first).",
                         sub(" .*", "", own$own_ranking[own$unit == "commune (per producer household)"]),
                         sub(" .*", "", own$own_ranking[own$unit == Wg_acc]), sub(" .*", "", own$own_ranking[own$unit == hull_acc])),
       info = sprintf("EVPI women pooled %s, women in producer households %s, hullers %s (V1). Leading rows: pooled %s; hullers %s; women %s.",
                      fk(t3e$EVPI[1]), fk(t3e$EVPI[2]), fk(t3e$EVPI[3]), lead_txt("T3_women_pooled"), lead_txt("T5_level_H"), lead_txt("T5_level_Wg")))

  # T4
  add("### T4 · Fairness criterion: the plan's two rule designs (axis 4; H2 up)", "",
      sprintf("**What is distributed:** %s.", res$T4$distributed), "",
      if (core_t4) sprintf("**Reach, compliance and the utilitarian sum cannot tell the two designs apart. The addressees' account prefers the standard rule. Every rule that looks at the worse-off group prefers the inclusive one. Under the standard rule the paid hullers remain below their status quo in %s of the draws, under the inclusive rule in %s.**",
                           pc(flr("up_std", "H")), pc(flr("up_inc", "H"))) else
        sprintf("**Ranking of the two designs per measure: %s. Under the standard rule the paid hullers remain below their status quo in %s of the draws, under the inclusive rule in %s.**", ad_rank, pc(flr("up_std", "H")), pc(flr("up_inc", "H"))), "",
      "| measure | what it computes | up_std | up_inc | ranking |", "|---|---|---|---|---|")
  for (i in seq_len(nrow(dsg))) {
    fmt <- if (dsg$measure[i] %in% c("reach", "compliance")) function(x) f2(x) else f0
    add(sprintf("| %s | %s | %s | %s | %s |", dsg$measure[i], dsg$computes[i], fmt(dsg$value_up_std[i]), fmt(dsg$value_up_inc[i]), dsg$ranking[i]))
  }
  add(sprintf("| floor (strict, `w_constrained(0)`) | constrains: admissible or not, no value | %s | %s | %s |",
              if (adm$alpha_0[adm$design == "up_std"]) "admissible" else "ruled out", if (adm$alpha_0[adm$design == "up_inc"]) "admissible" else "ruled out",
              if (all(!adm$alpha_0)) "neither admissible" else "differs"), "",
      "The floor: the rule's threshold applied to every group, also to those it does not name -- no group below its status quo.", "",
      "| design | group | P(below the floor) | mean shortfall where it occurs | flag (> 10 %) |", "|---|---|---|---|---|")
  for (o in c("up_std", "up_inc")) for (g in c("G", "Wg", "H"))
    add(sprintf("| %s | %s | %s | %s | %s |", o, ACC[[g]], pc(flr(o, g)), fk(flr(o, g, "mean_shortfall")), if (flr(o, g, "flag")) "yes" else ""))
  add("",
      sprintf("- Who remains below the floor: under up_std %s; under up_inc %s. Admissible under the strict floor (alpha = 0): %s; at alpha = %s: %s. A design becomes admissible only from alpha = %s (up_std) and %s (up_inc).",
              below("up_std"), below("up_inc"), if (any(adm$alpha_0)) paste(adm$design[adm$alpha_0], collapse = ", ") else "none",
              f2(set$FLOOR_ALPHA), if (any(adm$alpha_0.10)) paste(adm$design[adm$alpha_0.10], collapse = ", ") else "none",
              pc(adm$alpha_star[adm$design == "up_std"]), pc(adm$alpha_star[adm$design == "up_inc"])),
      sprintf("- Maximin protects the group gaining least, not the group with the lowest initial welfare: on the changes the hullers are the minimum in %s of the draws under up_std and in %s under up_inc; on the levels (status quo money from fonio plus the change) in %s and %s. The level is money from fonio only; other income is unknown and not assumed.",
              pc(mn$changes_min_is_hullers[mn$design == "up_std"]), pc(mn$changes_min_is_hullers[mn$design == "up_inc"]),
              pc(mn$levels_min_is_hullers[mn$design == "up_std"]), pc(mn$levels_min_is_hullers[mn$design == "up_inc"])),
      sprintf("- Over all five options every rule that ranks chooses %s (%s): the recommendation does not depend on the criterion. Between the two designs it does. Smallest rank correlation between the rules over the five options: %s (1 = all rules rank the options alike).",
              paste(unique(all_opts$option), collapse = ", "), paste(sprintf("%s %s", all_opts$rule, pc(all_opts$p_ahead)), collapse = ", "), f3(res$T4$rank_cor_min)),
      sprintf("- Sensitivity of the hullers' weight (design ranking per rule, %s): %s.", paste(setdiff(names(res$T4$K), c("K_H", "atkinson_offset", "offset_ok")), collapse = "/"),
              paste(apply(res$T4$K, 1, function(r) sprintf("K_H = %s: %s", trimws(r[["K_H"]]),
                    paste(trimws(r[setdiff(names(r), c("K_H", "offset_ok", "atkinson_offset"))]), collapse = "/"))), collapse = "; ")), "")
  card(mech = sprintf("the rule moves the operator margin between producer groups and hullers' groups; the sum does not change, the distribution does. That the plan co-finances machines is an assumption by decision (BOLDER request 14). Carrying rows: %s.",
                      rows_status(c("operator_margin_share", "machine_cost_ratio_to_manual", "hiring_hh_share", "inclusive_rule_enforcement", "plan_machine_share"))),
       null = "enforcement of the inclusive rule 0: the two designs coincide for every account; at any enforcement the commune is the same under both in every draw.",
       losses = sprintf("up_std: producer household %s (loss in %s), hullers %s per person (loss in %s); up_inc: %s (%s), hullers %s (%s). Women in producer households never lose.",
                        fk(mean_of("NB_G_up_std_V1")), pc(flr("up_std", "G")), fk(mean_of("NB_H_up_std_V1")), pc(flr("up_std", "H")),
                        fk(mean_of("NB_G_up_inc_V1")), pc(flr("up_inc", "G")), fk(mean_of("NB_H_up_inc_V1")), pc(flr("up_inc", "H"))),
       floor = sprintf("flagged under up_std: %s; under up_inc: %s. The strict floor admits %s.",
                       paste(ACC[fl$group[fl$option == "up_std" & fl$flag]], collapse = ", "), paste(ACC[fl$group[fl$option == "up_inc" & fl$flag]], collapse = ", "),
                       if (any(adm$alpha_0)) paste(adm$design[adm$alpha_0], collapse = ", ") else "neither design"),
       ranking = sprintf("%s. The rule designs are ranked differently by the fairness rules than by reach or compliance, which cannot tell them apart.", ad_rank),
       info = sprintf("EVPI of the design choice: utilitarian %s (the designs are equal in every draw; nothing to measure), maximin %s per person, prioritarian %s. Leading rows under maximin: %s.",
                      fk(t4e$EVPI[t4e$rule == "utilitarian"]), fk(t4e$EVPI[t4e$rule == "maximin"]), fk(t4e$EVPI[t4e$rule == "prioritarian"]),
                      lead_txt("T4_designs_maximin")))

  # T5
  add("### T5 · Value of information by actor, criterion and household type (axis 5)", "",
      sprintf("**Once the commune can decide per household type, %s is worth %s per producer household at today's information (static value of heterogeneity, MCSE %s), %s of perfect information about one decision for all (%s). What is worth measuring %s.**",
              planner_words, fk(hv("restricted", "VoH_static")), f0(hv("restricted", "VoH_static", "mcse")),
              if (hv("restricted", "voh_index") > 1) sprintf("%.1f times the value", hv("restricted", "voh_index")) else sprintf("%s of the value", pc(hv("restricted", "voh_index"))),
              fk(hv("restricted", "EVPI")), prio_txt), "",
      "| level | V0 option | V0 EVPI | V1 option | V1 EVPI | PREF option | PREF EVPI |", "|---|---|---|---|---|---|---|")
  for (lv in unique(ld$level)) add(sprintf("| %s | %s | %s | %s | %s | %s | %s |", lv, evo("V0", lv), f0(ev("V0", lv)),
                                           evo("V1", lv), f0(ev("V1", lv)), evo("PREF", lv), f0(ev("PREF", lv))))
  add("",
      "- The strict floor is not in the ladder: it constrains the option set and does not rank, so it has no EVPI.",
      sprintf("- multi_EVPI() of the decisive pair per level (V1; the three leading inputs): Wg %s; H %s; G %s; commune %s.",
              lead_txt("T5_level_Wg"), lead_txt("T5_level_H"), lead_txt("T5_level_G"), lead_txt("main_model")),
      sprintf("- The commune under the rules over persons (V1): utilitarian %s; maximin %s. The research priority %s.",
              lead_txt("T5_commune_utilitarian"), lead_txt("T5_commune_maximin"), prio_txt),
      sprintf("- A small group: `time_value_ratio_hullers` is worth %s per huller for the hullers' own decision and %s per producer household for the commune's. Their uncertainty counts in the aggregate with the weight of the group (%s hullers per producer household).",
              fk(tvr_H), fk(tvr_comm), set$K_H),
      sprintf("- A stake in values that do not translate into money: on the aim 'more fonio eaten' the EVPI is %s kg per producer household over ten years (H3); leading rows %s.",
              f1(kgd$EVPI_kg), lead_txt("H3_kg_eaten", digits = 1)),
      "", "Value of heterogeneity over the household types (commune value per producer household, V1; MCSE by bootstrap over draws):", "",
      "| quantity | only out can be targeted | MCSE | all options targetable | MCSE |", "|---|---|---|---|---|")
  for (q in c("A", "B", "C", "D", "EVPI", "VoH_static", "EVPI_sub", "VoH_dyn", "voh_index"))
    add(sprintf("| %s | %s | %s | %s | %s |", q, if (q == "voh_index") f2(hv("restricted", q)) else f0(hv("restricted", q)),
                if (q == "voh_index") f2(hv("restricted", q, "mcse")) else f0(hv("restricted", q, "mcse")),
                if (q == "voh_index") f2(hv("unrestricted", q)) else f0(hv("unrestricted", q)),
                if (q == "voh_index") f2(hv("unrestricted", q, "mcse")) else f0(hv("unrestricted", q, "mcse"))))
  add("", sprintf("- Planner's profile: %s (restricted); %s (unrestricted). A to D are levels; Espinoza et al. (2014, Fig. 2) use the letters for distances: static VoH = B - A (their eq. 8), dynamic VoH = D - C (their Fig. 2c).", planner_r, planner_u),
      "- Aggregated from persons over households to the commune; never across the two communes.", "")
  card(mech = sprintf("a self-hulling household that gets the machine displaces no paid hulling; a hiring household does. Under maximin the value of an option is that of its worst-off group, so the rows that decide the worst-off group's outcome lead. Carrying rows: %s.",
                      rows_status(c("hiring_hh_share", "time_value_ratio_hullers", "recovery_hand_share", "plan_machine_share"))),
       null = "only the profiles that give both types the same option: static and dynamic value of heterogeneity are 0 and EVPI_sub = EVPI; out targeted to type self leaves the hullers' account unchanged.",
       losses = sprintf("under the planner's profile out reaches only the households that hull themselves: the hullers' account is 0 (tested); the producer household of type self loses under out in %s of the draws, its women in %s.",
                        pc(mean(Y$NB_Gself_out_V1 < 0)), pc(mean(Y$NB_Wg_out_V1 < 0))),
       floor = sprintf("under the planner's profile no paid huller is below the floor; households of type self under out below it in %s of the draws.", pc(mean(Y$NB_Gself_out_V1 < 0))),
       ranking = sprintf("one decision %s -> per type %s; the leading row of the commune's decision %s -> %s (utilitarian -> maximin)%s.",
                         het$d_star[het$profiles == "restricted"][1], planner_r, lead_util, lead_mm,
                         if (prio_close) sprintf(", with `%s` almost level under maximin", lead_util) else ""),
       info = sprintf("EVPI of one decision %s, EVPI once decided per type %s (restricted) per producer household; commune under the utilitarian rule %s, under maximin %s per person.",
                      fk(hv("restricted", "EVPI")), fk(hv("restricted", "EVPI_sub")),
                      fk(res$T5$rule_evpi$EVPI[res$T5$rule_evpi$rule == "utilitarian"]), fk(res$T5$rule_evpi$EVPI[res$T5$rule_evpi$rule == "maximin"])))

  # T6
  add("### T6 · Fidelity (H4)", "",
      sprintf("**At the same mean fidelity of 0.5, who benefits from the inclusive plan depends on which component arrives: the hullers' mean is %s when half of both arrives, %s when the rule arrives but few machines, and %s when the machines arrive but the rule does not. At full machine delivery the rule must arrive at e* = %s for the hullers' mean to reach 0%s.**",
              fk(cm(.5, .5, "up_inc", "H_mean")), fk(cm(.25, .75, "up_inc", "H_mean")), fk(cm(.75, .25, "up_inc", "H_mean")), f2(es$e_star),
              if (is.na(es$e_alpha)) sprintf(", and no delivery up to 1 keeps their loss share within %s (at e = 1: %s)", pc(set$FLOOR_ALPHA), pc(es$H_p_loss_at_e1)) else sprintf("; their loss share falls to %s from e = %s", pc(set$FLOOR_ALPHA), f2(es$e_alpha))), "",
      "| machines (reach) | rule | mean fidelity | producer household | hullers per person | P(hullers lose) | commune |", "|---|---|---|---|---|---|---|")
  for (i in which(cmp$option == "up_inc")) add(sprintf("| %s | %s | %s | %s | %s | %s | %s |", f2(cmp$reach[i]), f2(cmp$rule[i]), f2(cmp$mean_fidelity[i]),
                                                       f0(cmp$G_mean[i]), f0(cmp$H_mean[i]), pc(cmp$H_p_loss[i]), f0(cmp$comm_mean[i])))
  add("",
      sprintf("- Aggregate fidelity conceals the difference: across the three compositions with mean fidelity 0.5 the commune's value moves by %s per producer household (%s to %s), the hullers' by %s per person (%s to %s; %s per producer household).",
              fk(cc$commune_range), fk(cc$commune_min), fk(cc$commune_max), fk(cc$hullers_range), fk(cc$hullers_min), fk(cc$hullers_max), fk(cc$hullers_range_per_producer_hh)),
      "- `fidelity_threshold()` is reported in `T6_fidelity_threshold.csv` only: where the runner-up is the status quo it says nothing.", "")
  card(mech = sprintf("machines displace paid hulling in proportion to reach; the margin that compensates the hullers arrives only with the rule. The model is linear in the rule's delivery e, so e* is closed. Carrying rows: %s.",
                      rows_status(c("plan_implementation_share", "inclusive_rule_enforcement", "operator_margin_share", "hiring_hh_share"))),
       null = "composition (1, 1) reproduces the main run; rule delivery 0 gives the standard design; the hullers' account is linear in e (all tested).",
       losses = sprintf("hullers lose in %s / %s / %s / %s of the draws at (1, 1), (0.5, 0.5), (0.25, 0.75), (0.75, 0.25); the producer household in %s / %s / %s / %s.",
                        pc(cm(1, 1, "up_inc", "H_p_loss")), pc(cm(.5, .5, "up_inc", "H_p_loss")), pc(cm(.25, .75, "up_inc", "H_p_loss")), pc(cm(.75, .25, "up_inc", "H_p_loss")),
                        pc(cm(1, 1, "up_inc", "G_p_loss")), pc(cm(.5, .5, "up_inc", "G_p_loss")), pc(cm(.25, .75, "up_inc", "G_p_loss")), pc(cm(.75, .25, "up_inc", "G_p_loss"))),
       floor = sprintf("e* = %s (the hullers' mean at 0; at e* they still lose in %s of the draws); P(hullers lose) <= %s %s.",
                       f2(es$e_star), pc(es$H_p_loss_at_e_star), pc(set$FLOOR_ALPHA),
                       if (is.na(es$e_alpha)) "is reached for no rule delivery up to 1" else sprintf("from e = %s", f2(es$e_alpha))),
       ranking = if (length(unique(t6p$commune)) == 1) sprintf("unchanged ranking, consequential distributive difference: the commune prefers %s at every composition, while the hullers' own choice moves from %s at (1, 1) to %s at (0.75, 0.25).",
                         t6p$commune[1], t6e$preferred[1], t6e$preferred[2]) else
                 sprintf("the commune's preferred option changes across the compositions (%s); the hullers' own choice moves from %s at (1, 1) to %s at (0.75, 0.25).",
                         paste(sprintf("(%s, %s) %s", f2(t6p$reach), f2(t6p$rule), t6p$commune), collapse = ", "), t6e$preferred[1], t6e$preferred[2]),
       info = sprintf("hullers' EVPI %s at (1, 1) and %s at (0.75, 0.25) per person; leading rows %s -> %s.",
                      fk(t6e$EVPI[1]), fk(t6e$EVPI[2]), lead_txt("T5_level_H"), lead_txt("T6_hullers_0.75_0.25")))

  add("## 5 · Null controls and identities (tests/testthat/test-model.R, all passing)", "",
      "- Mass balance: paddy hulled by machine plus by hand equals paddy; grain eaten plus sold equals grain; every option, household type and year.",
      "- The mix of the two household types with `hiring_hh_share` equals one household with that paid share of hand hulling, for every linear output.",
      "- Status quo: every difference to sq is exactly 0 (the levels of the status quo excepted). Transfers cancel: the commune's money = kg sold x p - machine paddy x (fee - margin).",
      "- The levels of the status quo are what the model computes; progress towards less drudgery equals the mean machine share, for the women and the hullers alike; deep moves no hour and never lowers the kg eaten.",
      "- `hiring_hh_share` = 0: the hullers' account is 0 in every option except up_inc (only the margin). `plan_lag_years` >= horizon: up = sq. `awareness_reach_share` = 0: deep = sq.",
      "- kappa = 1: NB_G(deep) = 0 exactly in every draw. up_std and up_inc give the same commune in every draw; at enforcement 0 they coincide for every account; the hullers are linear in the enforcement.",
      "- Off-farm value = wage_h: the hullers' account under out is 0 under PREF; V1 and PREF differ only in the hour weights.",
      "- The historical reference: swapping the greyed-out line equals today's share replaced by the 2011 share; with the two shares equal the swapped model is the main model; the re-run keeps every input.",
      "- out targeted to type self leaves the hullers' account unchanged. Only the diagonal profiles: static and dynamic VoH are 0 and EVPI_sub = EVPI.",
      "- A re-run keeps every input column; composition (1, 1) reproduces the main run; kappa = 1.5 changes only the outputs that contain kappa.", "")
  add("## 6 · Limits", "",
      sprintf("- Broad priors: %d of %d input rows are P and %d are B; the results map which valuation choice moves what, not an impact estimate.", n_status[["P"]], nrow(inp), n_status[["B"]]),
      "- One producer household of the commune in two pure types; no price or demand feedback, no traders or urban consumers, no season or yield risk, no men's accounts, no programme costs (outside the community boundary).",
      "- The stated aims are measured in the quantities of the thin core (kg, hours, money); their target levels are not stated, relational values, worldviews and broad values are not represented.",
      "- The plan's machine channel is an assumption by decision (BOLDER request 14); the operator margin and the producer price share are priors.",
      "- The preference reference values freed hours at an off-farm wage (B); aspirations come from a youth sample and are not weights.",
      "- `multi_EVPI()` gives the partial EVPI of one input for the decisive pair (loess smoother); it is not the joint EVPI.")
  writeLines(L, file.path(OUT, "key_findings.md"))

  # ---------------------------------------------------------------- RESULTS.md, block v9 (replaced, not repeated)
  block <- c("## v9 · 28.09.2026 · H1-H4 and the five axes as the manuscript states them",
             "",
             sprintf("Seed **%s**, **%s** draws, commit `%s` (branch `%s`). Tests: %s. Entry point `atacora_DA_run.R`; outputs in `outputs/v9/` (key findings, T0-T6 and H3 tables, shift map, figures).",
                     set$seed, format(set$draws, big.mark = ","), commit, branch,
                     if (is.null(ts)) "see analysis/00_run_tests.R" else sprintf("%d of %d passed", ts$passed, ts$total)),
             "",
             sprintf("- T0: %s ahead in %s of the draws (producer household, money only); EVPI %s.", t0$option, pc(t0$p_ahead), fk(t0$EVPI)),
             sprintf("- H3: deep never ahead in money; closer to 'more fonio eaten' in %s, ahead of all options on it in %s; non-dominated: G %s, Wg %s, H %s; kappa = 1.5 puts %s ahead in %s. EVPI in kg %s.",
                     pc(eat_closer), pc(eat_ahead), paste(pareto_set("G"), collapse = "/"), paste(pareto_set("Wg"), collapse = "/"),
                     paste(pareto_set("H"), collapse = "/"), k15$preferred_G, pc(k15$p_ahead), f1(kgd$EVPI_kg)),
             sprintf("- T4 (H2): %s. Hullers below the floor: up_std %s, up_inc %s.", ad_rank, pc(flr("up_std", "H")), pc(flr("up_inc", "H"))),
             sprintf("- T2: commune %s -> %s (V1 -> PREF); historical reference: %s.", pref_t2(comm_acc)[[1]], pref_t2(comm_acc)[[2]],
                     if (nrow(hist_flips)) "flips" else "no preferred option changes"),
             sprintf("- T5: leading row utilitarian `%s`, maximin `%s`%s; static VoH %s (MCSE %s).", lead_util, lead_mm,
                     if (prio_close) sprintf(" (with `%s` almost level)", lead_util) else "",
                     fk(hv("restricted", "VoH_static")), f0(hv("restricted", "VoH_static", "mcse"))),
             sprintf("- T6: e* = %s; hullers under up_inc at mean fidelity 0.5: %s / %s / %s per person.", f2(es$e_star),
                     fk(cm(.5, .5, "up_inc", "H_mean")), fk(cm(.25, .75, "up_inc", "H_mean")), fk(cm(.75, .25, "up_inc", "H_mean"))),
             "")
  head <- c("# RESULTS", "",
            "One block per run; each states seed and draws. Earlier blocks (v7, community rebuild) are in the git history and the tag `community-2026-09-27`.", "")
  old <- if (file.exists("RESULTS.md")) readLines("RESULTS.md", warn = FALSE) else character(0)
  keep <- character(0)
  if (length(old) && identical(old[1], "# RESULTS")) {
    starts <- grep("^## ", old)
    if (length(starts)) {
      blocks <- split(old[starts[1]:length(old)], cumsum(grepl("^## ", old[starts[1]:length(old)])))
      keep <- unlist(Filter(function(b) !startsWith(b[1], "## v9 "), blocks))
    }
  }
  writeLines(c(head, block, keep), "RESULTS.md")
})
