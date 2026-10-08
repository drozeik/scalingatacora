#  ------------------------------------------------------------------------
#  AXIS TESTS - Atacora case model v9, all on the same 10 000 draws of atacora_DA_model.R
#  Built like the EVPI part of the walnut template: one block of settings, then one numbered block per
#  test. Each block calls the axis functions of R/ directly behind mcSimulation(): nb_from_mc(),
#  voi_partition(), fairness_screen(), marginalisation_count(), baseline_pair(), fidelity_threshold(),
#  voh_index(), w_*(). No bridge or analysis layer in between.
#  Every test is a switch on the same draws and shows what H1-H4 and the five axes ask of it (handoff v9):
#  the mechanism and when it disappears, the losses of each group, the floor (no group below its status
#  quo), what the switch changes in the ranking, and the value of information under both of its settings.
#  H3 is tested without a monetary indicator, as progress towards aims people stated themselves (T1b);
#  H2 compares the plan's two rule designs, not the options (T4).
#  No recommendation: every statement holds under these priors.
#  Writes outputs/v9/T*.csv and outputs/v9/axes_results.rds (read by the key findings and the figures).
#  ------------------------------------------------------------------------
for (f in list.files("R", pattern = "[.]R$", full.names = TRUE)) source(f)            # layer 1: the axis functions
if (!exists("simulation_results")) source("atacora_DA_model.R")                     # the model, its simulation, EVPI and PLS
OUT <- "outputs/v9"
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)



#  SETTINGS
V_MAIN      <- "V1"                                                                 # main run: reference "behaviour" (atacora_DA_model.R, section 7)
K_H         <- 0.25                                                                 # paid hullers per producer household (= hullers_per_producer_hh)
stopifnot(all(simulation_results$x$hullers_per_producer_hh == K_H))
P_GH        <- c(G = 1, H = K_H) / (1 + K_H)                                        # persons: one producer household and its K_H hullers
P_WH        <- c(Wg = 1, H = K_H) / (1 + K_H)                                       # "women" pooled: one woman per producer household and K_H hullers
WOMEN       <- list(women = P_WH)                                                   # the pooled unit as a reporting unit (axis 3)
REFERENCES  <- list(behaviour = "V1", preference = "PREF")                          # the two reference states of axis 2 (T2)
ATKINSON_MEDIAN <- median(simulation_results$y$NPV_G_cash_sq)                       # FCFA: median NPV of a producer household's status quo money
atkinson_offset <- function(k){                                                     # that median, unless a person's loss in some draw, option or
  loss <- -min(sapply(c("V0", "V1", "PREF"), function(s) min(                      # setting reaches it: then the next 100 000 FCFA above the
    sapply(OPTIONS, function(o) min(simulation_results$y[[paste0("NB_G_", o, "_", s)]],  # largest loss, so that every shifted value is > 0
                                    simulation_results$y[[paste0("NB_H_", o, "_", s)]] * K_H / k)))))
  if (loss < ATKINSON_MEDIAN) ATKINSON_MEDIAN else ceiling((loss + 1) / 1e5) * 1e5
}
ATKINSON_OFFSET <- atkinson_offset(K_H)                                             # FCFA, reported with the median in the key findings
loss_twice  <- function(z) ifelse(z < 0, 2 * z, z)                                  # prioritarian transform: a loss counts twice
RULES <- list(utilitarian    = w_utilitarian(),                                     # the rules of axis 4 that rank, in the order of the T4 table
              prioritarian   = w_prioritarian(loss_twice),
              atkinson_0.5   = w_atkinson(0.5, offset = ATKINSON_OFFSET),
              atkinson_1     = w_atkinson(1,   offset = ATKINSON_OFFSET),
              atkinson_2     = w_atkinson(2,   offset = ATKINSON_OFFSET),
              maximin        = w_maximin())
FLOOR       <- w_constrained(0)                                                     # the strict floor constrains the option set, it does not rank:
                                                                                    #   reported as admissibility (T4), never with a value or an EVPI
FLOOR_ALPHA <- 0.10                                                                 # a group is flagged when it is below its status quo in > 10 % of draws
DESIGNS     <- c("up_std", "up_inc")                                                # T4: the plan's two rule designs; the status quo is the reference only
ADDRESSEES  <- list(up_std = "G", up_inc = c("G", "H"))                             # T4: the groups each rule names ("counts whoever the rule addresses")
AIMS <- data.frame(                                                                 # T1b: the perception-informed reference -- aims stated locally, with
  aim      = c("more fonio eaten", "less drudgery", "a future outside farming", "higher income"),   # their direction and source; no levels are set
  wording  = c("Amener la population à consommer davantage le fonio (améliorer la nutrition)",
               "Améliorer les équipements de transformation (réduire la pénibilité)",
               "young women name a future outside farming",
               "Augmenter la productivité et la production du fonio (améliorer les revenus)"),
  source   = c("workshop, objective Nutrition & health (Whitney 2025; W)",
               "workshop, objective Production & processing (Whitney 2025; W); processing named as arduous (Ballogou et al. 2014; L)",
               "Mausch et al. 2025, youth sample (L)",
               "workshop, objective Income & livelihoods (Whitney 2025; W)"),
  quantity = c("kg eaten at home", "hours of hand hulling", "hours of fonio work (in the thin core: hand hulling)",
               "money (FCFA, discounted)"),
  s        = c(1, -1, -1, 1),                                                       # +1: more is wanted; -1: less is wanted
  accounts = c("G", "Wg, H", "Wg, H", "G, H"), stringsAsFactors = FALSE)
AIMS_NOT_MODELLED <- c("harmonise prices (workshop objective Equity)", "ecology (workshop objective)",
                       "relations and agency in the narrower sense")                # stated, but no quantity of the thin core carries them
ROWS_DEEP   <- c("awareness_reach_share", "awareness_consumption_change_share",     # the input rows that carry deep (D1, D2)
                 "awareness_decay_rate", "awareness_campaign_years")
COMPOSITIONS <- data.frame(reach = c(1, 0.5, 0.25, 0.75),                           # T6: delivery of the plan's two components, as ratios of the design (H4)
                           rule  = c(1, 0.5, 0.75, 0.25))
E_GRID      <- seq(0, 1, by = 0.05)                                                 # T6: delivery ratio of the rule at full machine delivery
N_BOOT      <- 1000                                                                 # bootstrap resamples for the MCSE of T5 (c)
INPUTS      <- read.csv("data/estimates/atacora_DA_inputs_v8.csv", stringsAsFactors = FALSE)   # status and edge of every input
Y <- simulation_results$y; X <- simulation_results$x                                # outputs and inputs, one row per draw

# helpers: straight from the simulation into the axis functions
nb_of  <- function(accounts, setting, pattern = "NB_{group}_{option}_", sim = simulation_results)   # an nb_list of accounts under one setting
  nb_from_mc(sim, paste0(pattern, setting), groups = accounts, options = OPTIONS)
one    <- function(m) voi_partition(list(unit = m), p = 1, W = w_utilitarian())     # one account on its own: its expected value decides
comp   <- function(name, y = Y) sapply(OPTIONS, function(o) y[[paste0("C_", name, "_", o)]])   # draws x options matrix of one component, FCFA
unit_of <- function(name, y = Y) sapply(OPTIONS, function(o) y[[paste0(name, "_", o)]])        # draws x options matrix of one natural unit
status <- function(v) INPUTS$status[match(v, INPUTS$variable)]                      # L/W/T/B/P of an input row
describe <- function(m, unit_name) data.frame(unit = unit_name, option = OPTIONS,   # mean and shares of gain and loss per option
                                              mean = colMeans(m), p_gain = colMeans(m > 0),
                                              p_loss = colMeans(m < 0), row.names = NULL)
switch_point <- function(a, b, target){                                             # E[value] = a + t * b per option: where is target ahead?
  lo <- 0; hi <- Inf                                                                #   the interval [lo, hi] of t >= 0 in which target is ahead of all
  for (o in setdiff(names(a), target)) {
    da <- a[[target]] - a[[o]]; db <- b[[target]] - b[[o]]
    if (db > 0) lo <- max(lo, -da / db) else if (db < 0) hi <- min(hi, da / -db) else if (da < 0) return(c(lo = NA, hi = NA))
  }
  if (lo > hi) c(lo = NA, hi = NA) else c(lo = lo, hi = hi)
}
decisive_of <- function(m, rival = "mean"){                                         # the option ahead minus its rival, per draw. The rival is the
  same <- function(a, b) isTRUE(all.equal(unname(m[, a]), unname(m[, b])))         #   runner-up by mean ("mean", as in v8) or the option with the
  o <- names(sort(colMeans(m), decreasing = TRUE))                                  #   largest expected regret against the one ahead ("regret").
  others <- o[!sapply(o, same, b = o[1])]                                           #   Options equal to the one ahead in every draw are ties, not
  r <- if (rival == "mean") others[1] else                                          #   rivals; of two equal rivals (up_std = up_inc for the
         others[which.max(sapply(others, function(k) mean(pmax(0, m[, k] - m[, o[1]]))))]   # commune) the first in OPTIONS is named
  r <- intersect(OPTIONS, others[sapply(others, same, b = r)])[1]
  list(pair = paste(o[1], r, sep = "_vs_"), ahead = o[1], rival = r, v = m[, o[1]] - m[, r])
}
rule_draws <- function(nb, p, W)                                                    # a rule's value per draw and option (draws x options)
  sapply(OPTIONS, function(o) apply(sapply(nb, function(m) m[, o]), 1, W, p = p))
top_evpi <- function(ev, k = 3){                                                    # the k leading rows of a multi_EVPI() table, with status
  if (is.null(ev)) return(data.frame(variable = character(0), EVPI = numeric(0), status = character(0)))
  tab <- ev[[1]][order(-ev[[1]]$EVPI), c("variable", "EVPI")]
  tab <- head(tab[tab$EVPI > 0, ], k)
  tab$status <- status(tab$variable)
  tab
}
multi_evpi_of <- function(v, name){                                                 # multi_EVPI() in the template's mc_table idiom, quietly
  mc_table <- data.frame(simulation_results$x, v)
  names(mc_table)[ncol(mc_table)] <- name
  invisible(capture.output(ev <- suppressMessages(multi_EVPI(mc = mc_table, first_out_var = name))))
  ev
}
EVPI_JOBS <- list(); EVPI_NONE <- list()                                            # the decisive pair of every test; multi_EVPI() runs once for all
evpi_job <- function(name, d){                                                      #   of them, side by side (VALUE OF INFORMATION, below)
  if (all(d$v >= 0) || all(d$v <= 0)) EVPI_NONE[[name]] <<- d else EVPI_JOBS[[name]] <<- d   # no draw reverses the pair: every partial
  invisible(NULL)                                                                   #   EVPI is 0, there is nothing to measure for it
}
rerun <- function(model){                                                           # a variant of decision_model() on the same draws: the same seed
  set.seed(SEED)                                                                    #   gives mcSimulation() the same inputs and the same downtime years
  invisible(capture.output(sim <- suppressMessages(suppressWarnings(mcSimulation(
    estimate = estimate_read_csv("data/estimates/atacora_DA_inputs_v8.csv"),
    model_function = model, numberOfModelRuns = N_DRAWS, functionSyntax = "plainNames")))))
  stopifnot(identical(sim$x, simulation_results$x))                                 # no input column changed
  sim
}
model_swapped <- function(active, alternative){                                     # decision_model() with one greyed-out '##' line swapped in,
  lines <- readLines("atacora_DA_model.R")                                          #   as a reader of the model file would do by hand
  on <- grep(active, lines); off <- grep(alternative, lines)
  stopifnot(length(on) == 1, length(off) == 1)
  lines[on]  <- sub("^(\\s*)", "\\1## ", lines[on])
  lines[off] <- sub("^(\\s*)## ", "\\1", lines[off])
  ex <- parse(text = lines, keep.source = FALSE)
  def <- Filter(function(e) is.call(e) && identical(e[[1]], as.name("<-")) &&
                  identical(e[[2]], as.name("decision_model")), as.list(ex))[[1]]
  eval(def[[3]], envir = globalenv())
}
res <- list(settings = list(seed = SEED, draws = N_DRAWS, V_MAIN = V_MAIN, K_H = K_H,
                            ATKINSON_OFFSET = ATKINSON_OFFSET, ATKINSON_MEDIAN = ATKINSON_MEDIAN,
                            atkinson_draws_below_median = sum(apply(sapply(c("V0", "V1", "PREF"), function(s)   # draws in which some person's
                              apply(sapply(OPTIONS, function(o) pmin(Y[[paste0("NB_H_", o, "_", s)]],            # value + the median <= 0
                                                                     Y[[paste0("NB_G_", o, "_", s)]])), 1, min)), 1, min) + ATKINSON_MEDIAN <= 0),
                            FLOOR_ALPHA = FLOOR_ALPHA, rules = names(RULES), aims = AIMS,
                            aims_not_modelled = AIMS_NOT_MODELLED))



# T0 · THE CONVENTIONAL READING (the slide): producer household, money only (V0), one decision for the commune

vp_T0 <- voi_partition(nb_of("G", "V0"), p = 1, W = w_utilitarian())
T0 <- data.frame(reading = "producer household (G), money only (V0), one decision for the commune",
                 option = vp_T0$d_star, p_ahead = vp_T0$p_ahead, EVPI = vp_T0$EVPI,
                 decisive_pair = dec_T0)
T0_means <- describe(nb_of("G", "V0")$G, "G, V0")
T0_multi <- top_evpi(evpi_T0)                                                        # multi_EVPI() of the decisive pair (atacora_DA_model.R)
res$T0 <- list(summary = T0, means = T0_means, multi_evpi = T0_multi, partition = vp_T0)



# T1 · SYSTEM BOUNDARY (axis 1; H1 out, H3 deep)
# (a) whose accounts count: G -> G + H -> G + H + O, under V0 and under V1. The commune without the
#     operator is NB_comm - NB_O; for up the operator account is 0, so up_std and up_inc stay tied exactly.

boundary <- function(setting){
  comm <- nb_of("comm", setting)$comm
  list("G" = nb_of("G", setting)$G, "G + H" = comm - nb_of("O", setting)$O, "G + H + O" = comm)
}
T1a <- do.call(rbind, lapply(c("V0", "V1"), function(s){
  b <- boundary(s)
  do.call(rbind, lapply(names(b), function(k){
    vp <- one(b[[k]])
    cbind(setting = s, boundary = k, describe(b[[k]], k)[, -1], preferred = vp$d_star, p_ahead = vp$p_ahead, EVPI = vp$EVPI)
  }))
}))
T1a$sign <- sign(round(T1a$mean, 6))
T1a_flips <- aggregate(sign ~ setting + option, data = T1a, FUN = function(z) length(unique(z)) > 1)
names(T1a_flips)[3] <- "sign_changes_across_boundaries"

# the objectives in money: V0 -> time only (omega = 1, kappa = 0) -> V1, for G and the commune.
# All values are linear in the weights, so the path and the thresholds follow from the components.
cG <- comp("G_cash"); tG <- comp("G_time"); kG <- comp("G_kg"); tH <- comp("H_time"); money <- comp("money")
val_G    <- function(omega, kappa) cG + omega * tG + kappa * kG                                   # NB_G at any weights
val_comm <- function(omega, omega_H, kappa) money + omega * tG + omega_H * tH + kappa * kG        # NB_comm at any weights
stopifnot(isTRUE(all.equal(val_G(0, 0), as.matrix(nb_of("G", "V0")$G), check.attributes = FALSE)),
          isTRUE(all.equal(val_G(1, 1), as.matrix(nb_of("G", "V1")$G), check.attributes = FALSE)),
          isTRUE(all.equal(val_comm(1, Y$theta, 1), as.matrix(nb_of("comm", "V1")$comm), check.attributes = FALSE)))
path <- list("V0 (money only)"            = list(G = val_G(0, 0), comm = val_comm(0, 0, 0)),
             "time only (omega 1, kappa 0)" = list(G = val_G(1, 0), comm = val_comm(1, Y$theta, 0)),
             "V1 (omega 1, kappa 1)"       = list(G = val_G(1, 1), comm = val_comm(1, Y$theta, 1)))
T1_path <- do.call(rbind, lapply(names(path), function(k) do.call(rbind, lapply(c("G", "comm"), function(a){
  vp <- one(path[[k]][[a]])
  cbind(step = k, account = a, describe(path[[k]][[a]], a)[, -1], preferred = vp$d_star, p_ahead = vp$p_ahead)
}))))

# thresholds in closed form (expected values are straight lines in each weight)
w_off_q <- quantile(Y$w_off_rel, c(0.05, 0.5, 0.95))                                # context: the off-farm hour / wage_h under the priors
thr <- function(account, weight, kappa = 1, omega = 1){                             # omega* or kappa* of every option, vs sq and vs the best other
  if (weight == "omega") {
    a <- if (account == "G") colMeans(cG + kappa * kG) else colMeans(money + Y$theta * tH + kappa * kG)
    b <- colMeans(tG)
  } else {
    a <- if (account == "G") colMeans(cG + omega * tG) else colMeans(money + omega * tG + Y$theta * tH)
    b <- colMeans(kG)
  }
  do.call(rbind, lapply(setdiff(OPTIONS, "sq"), function(o){
    vs_sq <- switch_point(a[c("sq", o)], b[c("sq", o)], o)
    vs_all <- switch_point(a, b, o)
    data.frame(account = account, weight = weight, fixed = if (weight == "omega") paste("kappa =", kappa) else paste("omega =", omega),
               option = o, vs_sq_from = vs_sq[["lo"]], vs_sq_to = vs_sq[["hi"]],
               vs_best_other_from = vs_all[["lo"]], vs_best_other_to = vs_all[["hi"]])
  }))
}
T1_thresholds <- rbind(thr("G", "omega", kappa = 1), thr("G", "omega", kappa = 0), thr("comm", "omega", kappa = 1),
                       thr("G", "kappa", omega = 1), thr("comm", "kappa", omega = 1))
T1_deep_identity <- all(Y$NB_G_deep_V1 == 0) && isTRUE(all.equal(Y$NB_G_deep_V0, -Y$C_G_kg_deep))   # NB_G(deep) = (kappa - 1) p dkg

# (b) H3 · the valuation layer as a boundary. A monetary indicator commits the model to the lowest layer of
#     valuation (IPBES: worldviews, broad values, specific values, indicators; Pascual et al. 2023). Deep and
#     the other options are therefore measured, without a chosen indicator, as progress towards the aims the
#     people stated themselves (AIMS): per account g, aim k and option d, per draw,
#         progress = s_k (Y_gk(d) - Y_gk(sq)) / |Y_gk(sq)|,    s_k = +1 (more wanted) or -1 (less wanted).
#     > 0 = closer to the stated aim. Unit-free, a share of today's level (section 9 of the model). For less
#     drudgery it is the share of today's distance that the option closes (the aim has an end point: no hand
#     hulling). For more eaten and higher income no target level is stated (to be asked, field work 2027):
#     the ranking of the options within an aim does not depend on it, the comparison across aims does.
#     No weights and no sum over the aims: that would be a chosen indicator again.
aim_quantity <- list(                                                               # Y(d) - Y(sq) (draws x options) and |Y(sq)|, per aim | account
  "more fonio eaten|G"         = list(chg =  unit_of("Kg_eaten"),    lvl = Y$Lvl_kg_eaten_sq),   # S1 kg over the horizon, per producer household
  "less drudgery|Wg"           = list(chg = -unit_of("Hrs_G_saved"), lvl = Y$Lvl_hrs_Wg_sq),     # L1 h of hand hulling, per woman
  "less drudgery|H"            = list(chg = -unit_of("Hrs_H_freed"), lvl = Y$Lvl_hrs_H_sq),      # L2 h of hand hulling, per huller
  "a future outside farming|Wg" = list(chg = -unit_of("Hrs_G_saved"), lvl = Y$Lvl_hrs_Wg_sq),    # the thin core has no other fonio hours: the
  "a future outside farming|H"  = list(chg = -unit_of("Hrs_H_freed"), lvl = Y$Lvl_hrs_H_sq),    #   same hours as drudgery (stated, not merged)
  "higher income|G"            = list(chg =  comp("G_cash"),         lvl = Y$NPV_G_cash_sq),     # M FCFA discounted, per producer household
  "higher income|H"            = list(chg =  comp("H_cash") / K_H,   lvl = Y$Lvl_H_cash_sq))     # M FCFA discounted, per huller
progress <- lapply(names(aim_quantity), function(k){                                # the index per draw and option
  q <- aim_quantity[[k]]
  AIMS$s[AIMS$aim == sub("[|].*", "", k)] * q$chg / abs(q$lvl)
})
names(progress) <- names(aim_quantity)
aim_of <- function(k) sub("[|].*", "", k); acc_of <- function(k) sub(".*[|]", "", k)
T1b_aims <- do.call(rbind, lapply(names(progress), function(k){                     # T1b_aspiration.csv: account x aim x option
  P <- progress[[k]]; a <- acc_of(k)
  V0 <- as.matrix(nb_of(a, "V0")[[1]]); V1 <- as.matrix(nb_of(a, "V1")[[1]])
  q <- function(pr) apply(P, 2, quantile, pr)
  data.frame(account = a, aim = aim_of(k), option = OPTIONS, mean = colMeans(P), q05 = q(.05), q10 = q(.10),
             median = q(.5), q90 = q(.90), q95 = q(.95), p_closer = colMeans(P > 0), p_further = colMeans(P < 0),
             money_V0_mean = colMeans(V0), money_V0_p_pos = colMeans(V0 > 0),
             money_V1_mean = colMeans(V1), money_V1_p_pos = colMeans(V1 > 0),
             level_sq_median = median(aim_quantity[[k]]$lvl), row.names = NULL)
}))
# (1) the shift of layer: in money deep is never ahead; at market prices it is 0 (identity); on the stated aims
eat <- progress[["more fonio eaten|G"]]
G_V0 <- as.matrix(nb_of("G", "V0")$G); G_V1 <- as.matrix(nb_of("G", "V1")$G)
ahead_strict <- function(m, o) mean(m[, o] > apply(m[, setdiff(colnames(m), o), drop = FALSE], 1, max))
T1b_shift <- data.frame(
  reading = c("money, V0 (kappa = 0)", "money, V1 (kappa = 1)", "stated aim: more fonio eaten"),
  deep_mean = c(mean(G_V0[, "deep"]), mean(G_V1[, "deep"]), mean(eat[, "deep"])),
  deep_p_ahead_of_all = c(ahead_strict(G_V0, "deep"), ahead_strict(G_V1, "deep"), ahead_strict(eat, "deep")),
  deep_p_positive = c(mean(G_V0[, "deep"] > 0), mean(G_V1[, "deep"] > 0), mean(eat[, "deep"] > 0)),
  options_with_positive_mean = c(paste(OPTIONS[colMeans(G_V0) > 0], collapse = ", "),
                                 paste(OPTIONS[colMeans(G_V1) > 1e-9], collapse = ", "),
                                 paste(OPTIONS[colMeans(eat) > 0], collapse = ", ")))
# (2) group-specific consequences against the money: per account and option, closer to or further from each aim
T1b_directions <- T1b_aims[T1b_aims$option != "sq", c("account", "aim", "option", "mean", "p_closer", "money_V0_mean", "money_V1_mean")]
T1b_directions$direction <- ifelse(abs(T1b_directions$mean) < 1e-12, "unchanged",
                                   ifelse(T1b_directions$mean > 0, "closer", "further"))
# (3) Pareto per account: which options no other option matches on every stated aim and beats on one
acc_aims <- split(names(progress), acc_of(names(progress)))
dominates <- function(A, B) Reduce(`&`, Map(`>=`, A, B)) & Reduce(`|`, Map(`>`, A, B))  # elementwise over draws (or one row of means)
T1b_pareto <- do.call(rbind, lapply(names(acc_aims), function(a){
  ks <- acc_aims[[a]]
  mean_of <- function(o) lapply(ks, function(k) mean(progress[[k]][, o]))
  draw_of <- function(o) lapply(ks, function(k) progress[[k]][, o])
  do.call(rbind, lapply(OPTIONS, function(o){
    by <- Filter(function(e) dominates(mean_of(e), mean_of(o)), setdiff(OPTIONS, o))
    dom_draw <- Reduce(`|`, lapply(setdiff(OPTIONS, o), function(e) dominates(draw_of(e), draw_of(o))))
    data.frame(account = a, aims = paste(unique(aim_of(ks)), collapse = "; "), option = o,
               non_dominated = length(by) == 0, dominated_by = paste(by, collapse = ", "),
               p_non_dominated = mean(!dom_draw))
  }))
}))
# the explicit rule that ranks across the household's aims: kappa = 1.5 (the greyed-out alternative O2 of the model)
G15 <- cG + tG + 1.5 * kG                                                           # every option for G at kappa = 1.5, hours as in V1
vp15 <- one(G15)
d15 <- decisive_of(G15)
T1b_kappa15 <- data.frame(rule = "kappa = 1.5 (alternative O2, greyed out in section 7)", preferred_G = vp15$d_star,
                          p_ahead = vp15$p_ahead, mean_deep_vs_sq = mean(G15[, "deep"]), p_deep_gain = mean(G15[, "deep"] > 0),
                          EVPI = vp15$EVPI, decisive_pair = d15$pair)
evpi_job("H3_kappa15", d15)                                                          # under the explicit rule: do deep's rows carry value?
# value of information on the stated aim (axis 5): the decision "more fonio eaten" in kg over the horizon. By mean
# the runner-up of deep is the status quo, which deep beats in every draw; the rival with information value is
# the option with the largest expected regret against deep (where the machine recovers more grain than the hand).
kg <- unit_of("Kg_eaten")
vp_kg <- one(kg)
d_kg <- decisive_of(kg, rival = "regret")
evpi_job("H3_kg_eaten", d_kg)
T1b_kg <- data.frame(decision = "more fonio eaten, kg over the horizon per producer household", option = vp_kg$d_star,
                     p_ahead = vp_kg$p_ahead, EVPI_kg = vp_kg$EVPI, decisive_pair = d_kg$pair,
                     p_rival_ahead = mean(d_kg$v < 0), runner_up_by_mean = decisive_of(kg)$rival,
                     p_runner_up_ahead = mean(decisive_of(kg)$v < 0))
res$T1 <- list(boundary = T1a, flips = T1a_flips, path = T1_path, thresholds = T1_thresholds,
               w_off_quantiles = w_off_q, deep_identity = T1_deep_identity,
               lines_G = list(a1 = colMeans(cG + kG), a0 = colMeans(cG), b = colMeans(tG)),
               aims = T1b_aims, shift = T1b_shift, directions = T1b_directions, pareto = T1b_pareto,
               kappa15 = T1b_kappa15, kg = T1b_kg, kg_pair = d_kg[c("pair", "ahead", "rival")],
               progress_summary = lapply(progress, function(P) apply(P, 2, quantile, c(.1, .5, .9))))



# T3 · REPORTING UNIT (axis 3; H1): women in producer households against paid hullers, under V1
#      A change of the reporting unit changes what is visible, not the collective decision rule: the option each
#      unit prefers is its own ranking, not a decision for the commune. Whether the groups can receive separate
#      interventions is a different question (T5: only out can be steered to one household type).

units_T3 <- list("producer household (G)"   = nb_of("G", V_MAIN)$G,
                 "women in producer households (Wg)" = nb_of("Wg", V_MAIN)$Wg,
                 "paid hullers (H, per person)" = nb_of("H", V_MAIN)$H,
                 "women pooled"             = reporting_units(nb_of(c("Wg", "H"), V_MAIN), WOMEN)$women,
                 "commune (per producer household)" = nb_of("comm", V_MAIN)$comm)
T3 <- do.call(rbind, lapply(names(units_T3), function(k) describe(units_T3[[k]], k)))
T3_own_ranking <- data.frame(unit = names(units_T3),                                # each unit's own ranking of the options, by mean
                             own_ranking = sapply(units_T3, function(m) paste(names(sort(colMeans(m), decreasing = TRUE)), collapse = " > ")),
                             collective_decision = FALSE, row.names = NULL)
T3_hidden <- do.call(rbind, lapply(c("out", "up_std", "up_inc"), function(o){       # "women" gain while the hullers lose
  mc <- marginalisation_count(nb_of(c("Wg", "H"), V_MAIN), p = P_WH, W = w_utilitarian(), d_star = o)
  data.frame(option = o, p_women_gain_some_group_loses = mc$share,
             p_women_gain_hullers_lose = mc$by_group$share[mc$by_group$group == "H"],
             p_women_gain_growers_lose = mc$by_group$share[mc$by_group$group == "Wg"])
}))
# threshold: the hiring_hh_share at which "women" pooled change sign under out (linear in the share)
A_self <- mean(Y$C_Gself_time_out + Y$C_Hself_cash_out + Y$theta * Y$C_Hself_time_out)   # women's value per producer household of type self
A_hire <- mean(Y$C_Ghire_time_out + Y$C_Hhire_cash_out + Y$theta * Y$C_Hhire_time_out)   # the same, type hire
s_star <- if (sign(A_self) != sign(A_hire)) A_self / (A_self - A_hire) else NA
T3_threshold <- data.frame(option = "out", value_self = A_self, value_hire = A_hire, hiring_share_star = s_star,
                           prior_5 = quantile(X$hiring_hh_share, 0.05), prior_95 = quantile(X$hiring_hh_share, 0.95),
                           p_prior_above = mean(X$hiring_hh_share > s_star), row.names = NULL)
T3_evpi <- data.frame(unit = c("women pooled", "women in producer households (Wg)", "paid hullers (H, per person)"),
                      EVPI = c(voi_partition(nb_of(c("Wg", "H"), V_MAIN), p = P_WH, W = w_utilitarian())$EVPI,
                               one(units_T3[[2]])$EVPI, one(units_T3[[3]])$EVPI))
d_pooled <- decisive_of(units_T3[["women pooled"]])
evpi_job("T3_women_pooled", d_pooled)
res$T3 <- list(units = T3, own_ranking = T3_own_ranking, hidden = T3_hidden, threshold = T3_threshold,
               evpi = T3_evpi, pooled_pair = d_pooled$pair)



# T2 · REFERENCE STATE (axis 2)
# (a) behaviour against preference in the value of freed time ("improvement relative to expected practice");
#     baseline_pair() runs the same decision against both references; the model returns both settings.
#     The non-monetary reading ("progress towards a valued situation") is the index of T1b for the aims less
#     drudgery and a future outside farming; it is reported there, not repeated here.

model_ref <- function(accounts) function(setting) nb_of(accounts, setting)          # an nb_list of accounts under one reference
bp_accounts <- list(
  "women in producer households (Wg)" = baseline_pair(model_ref("Wg"), REFERENCES, p = 1, rules = list(expected_value = w_utilitarian())),
  "paid hullers (H, per person)"      = baseline_pair(model_ref("H"),  REFERENCES, p = 1, rules = list(expected_value = w_utilitarian())),
  "producer household (G)"            = baseline_pair(model_ref("G"),  REFERENCES, p = 1, rules = list(expected_value = w_utilitarian())),
  "women pooled"                      = baseline_pair(model_ref(c("Wg", "H")), REFERENCES, p = P_WH,
                                                      rules = list(expected_value = w_utilitarian()), units = WOMEN),
  "commune (per producer household)"  = baseline_pair(model_ref("comm"), REFERENCES, p = 1, rules = list(expected_value = w_utilitarian())))
T2 <- do.call(rbind, lapply(names(bp_accounts), function(k){
  o <- bp_accounts[[k]]$outcomes
  o <- if (k == "women pooled") o[o$unit == "women", ] else o
  cbind(account = k, o[, setdiff(names(o), c("unit", "outcome"))])
}))
bp_rules <- baseline_pair(model_ref(c("G", "H")), REFERENCES, p = P_GH, rules = RULES)    # the rules over persons, both references
T2_rules <- bp_rules$rules[, c("rule", "reference", "option", "p_ahead", "EVPI", "flip")]
# thresholds: for the hullers under out and up_std the off-farm value must exceed wage_h (identity: nothing
# else reaches them); for household and commune the constant off-farm value w (FCFA/h) at which the
# preferred option changes. With every hour at w: E[NB] = a + w * (discounted hours), a straight line in w.
hours_G    <- tG / Y$wage_h; hours_comm <- (tG + tH) / Y$wage_h                     # discounted hours saved or freed per producer household
envelope <- function(a, h, w_max = 2000){                                           # preferred option along w and its switch points
  grid <- seq(0, w_max, by = 1)
  best <- OPTIONS[apply(outer(grid, h) + matrix(a, length(grid), length(a), byrow = TRUE), 1, which.max)]
  ch <- which(best[-1] != best[-length(best)])
  data.frame(from = c(0, grid[ch + 1]), preferred = best[c(1, ch + 1)])
}
T2_switch <- rbind(cbind(account = "G", envelope(colMeans(cG + kG), colMeans(hours_G))),
                   cbind(account = "comm", envelope(colMeans(money + kG), colMeans(hours_comm))))
T2_hullers <- data.frame(option = c("out", "up_std", "up_inc"),
                         p_gain_behaviour = colMeans(nb_of("H", "V1")$H[, c("out", "up_std", "up_inc")] > 0),
                         p_gain_preference = colMeans(nb_of("H", "PREF")$H[, c("out", "up_std", "up_inc")] > 0),
                         identity_threshold = c("w_off = wage_h", "w_off = wage_h", "below wage_h (margin)"))
T2_prior <- c(p_off_above_wage = mean(Y$w_off_rel > 1), quantile(X$opportunity_wage_fcfa_h, c(0.05, 0.5, 0.95)),
              wage_h = quantile(Y$wage_h, c(0.05, 0.5, 0.95)))
d_pref <- decisive_of(as.matrix(nb_of("comm", "PREF")$comm))                        # the commune's decisive pair under preference
evpi_job("T2_commune_PREF", d_pref)                                                  #   (under behaviour: dec_main of the model file)

# (b) a historically informed reference: the greyed-out line of block (0) swapped in -- today's share of the
#     grain eaten at home replaced by the share of the 2011 survey (Ballogou et al. 2014; L) -- and the model
#     re-run on the same draws. The historical row is documented; that does not make a return to it desirable.
decision_model_historical <- model_swapped("^  own_sq +<- rep\\(own_consumption_share_behavioural,",
                                           "^  ## own_sq +<- rep\\(own_consumption_share_behavioural_alt,")
sim_hist <- rerun(decision_model_historical)
Yh <- sim_hist$y
T2_historical <- do.call(rbind, lapply(c("V0", "V1"), function(s) do.call(rbind, lapply(c("G", "Wg", "H", "comm"), function(a){
  today <- one(nb_of(a, s)[[1]]); hist <- one(nb_of(a, s, sim = sim_hist)[[1]])
  data.frame(setting = s, account = a, preferred_today = today$d_star, p_ahead_today = today$p_ahead, EVPI_today = today$EVPI,
             preferred_historical = hist$d_star, p_ahead_historical = hist$p_ahead, EVPI_historical = hist$EVPI,
             flips = today$d_star != hist$d_star)
}))))
T2_historical_means <- do.call(rbind, lapply(c("V0", "V1"), function(s) do.call(rbind, lapply(c("G", "H", "comm"), function(a)
  data.frame(setting = s, account = a, option = OPTIONS, mean_today = colMeans(nb_of(a, s)[[1]]),
             mean_historical = colMeans(nb_of(a, s, sim = sim_hist)[[1]]), row.names = NULL)))))
T2_historical_rules <- data.frame(rule = names(RULES),
                                  today = fairness_screen(nb_of(c("G", "H"), V_MAIN), p = P_GH, rules = RULES)$table$option,
                                  historical = fairness_screen(nb_of(c("G", "H"), V_MAIN, sim = sim_hist), p = P_GH, rules = RULES)$table$option)
eat_hist <- unit_of("Kg_eaten", Yh) / Yh$Lvl_kg_eaten_sq                            # progress towards "more fonio eaten", historical reference
T2_historical_eat <- data.frame(reference = c("today (P)", "historical, 2011 survey (L)"),
                                share_eaten_median = c(median(X$own_consumption_share_behavioural), median(X$own_consumption_share_behavioural_alt)),
                                level_kg_median = c(median(Y$Lvl_kg_eaten_sq), median(Yh$Lvl_kg_eaten_sq)),
                                deep_kg_mean = c(mean(kg[, "deep"]), mean(unit_of("Kg_eaten", Yh)[, "deep"])),
                                deep_progress_mean = c(mean(eat[, "deep"]), mean(eat_hist[, "deep"])),
                                deep_progress_q10 = c(quantile(eat[, "deep"], .1), quantile(eat_hist[, "deep"], .1)),
                                deep_progress_q90 = c(quantile(eat[, "deep"], .9), quantile(eat_hist[, "deep"], .9)),
                                deep_p_closer = c(mean(eat[, "deep"] > 0), mean(eat_hist[, "deep"] > 0)),
                                deep_p_ahead_of_all = c(ahead_strict(eat, "deep"), ahead_strict(eat_hist, "deep")),
                                p_share_capped_at_1 = c(NA, mean(X$own_consumption_share_behavioural_alt *
                                  (1 + X$awareness_consumption_change_share * X$awareness_reach_share) >= 1)))
res$T2 <- list(accounts = T2, rules = T2_rules, switch = T2_switch, hullers = T2_hullers, prior = T2_prior,
               pairs = bp_accounts, pair_rules = bp_rules, pref_pair = d_pref$pair,
               historical = T2_historical, historical_means = T2_historical_means,
               historical_rules = T2_historical_rules, historical_eat = T2_historical_eat)



# T4 · FAIRNESS CRITERION (axis 4; H2 up): the plan's two rule designs, up_std against up_inc
#      What is distributed: changes of valued money under V1 (section 8 of the model), per person -- a
#      producer household, a paid huller. Level variant: the status quo money from fonio plus the change
#      (other income is unknown and not assumed). The status quo is the reference only: over all five
#      options every rule chooses it (one line, not the test).

nb_GH <- nb_of(c("G", "H"), V_MAIN)
offset_ok <- c(V1 = min(unlist(nb_GH)) + ATKINSON_OFFSET > 0,                      # every shifted value must be > 0,
               PREF = min(unlist(nb_of(c("G", "H"), "PREF"))) + ATKINSON_OFFSET > 0) # also under the other reference (T2)
fs_T4 <- fairness_screen(nb_GH, p = P_GH, rules = RULES)                            # every option under every rule
T4_all_options <- fs_T4$table[, c("rule", "option", "p_ahead", "EVPI")]
ranks_T4 <- apply(-fs_T4$scores, 2, rank, ties.method = "min")                      # rank 1 = best, over the five options
T4_rank_cor <- suppressWarnings(cor(ranks_T4, method = "spearman"))                 # pairwise; fairness_screen() reports the smallest
# the design table: one row per measure, the two designs side by side
LV_OPTIONS <- c("sq", DESIGNS)                                                      # level variant for the designs and their reference:
levels_GH <- list(G = (Y$NPV_G_cash_sq + nb_GH$G)[, LV_OPTIONS],                    #   status quo money from fonio + the change, per person
                  H = (Y$Lvl_H_cash_sq + nb_GH$H)[, LV_OPTIONS])
LEVEL_OFFSET <- if (min(unlist(levels_GH)) > 0) 0 else                              # Atkinson needs positive levels: no offset unless a level
  ceiling((1 - min(unlist(levels_GH))) / 1000) * 1000                              #   is not positive (then the next 1000 FCFA above it)
fs_levels <- fairness_screen(levels_GH, p = P_GH, rules = list(maximin = w_maximin(), atkinson_1 = w_atkinson(1, offset = LEVEL_OFFSET)))
addressed <- function(d){                                                           # the utilitarian value over the groups the design names
  g <- ADDRESSEES[[d]]; w <- P_GH[g] / sum(P_GH[g])
  mean(Reduce(`+`, Map(function(k, wk) wk * nb_GH[[k]][, d], g, w)))
}
T4_designs <- rbind(
  data.frame(measure = "reach", computes = "mean machine share of the paddy (M_share)",
             value_up_std = mean(Y$M_share_up_std), value_up_inc = mean(Y$M_share_up_inc)),
  data.frame(measure = "compliance", computes = "implemented share of the plan (U2, plan_implementation_share), the same for both designs",
             value_up_std = mean(X$plan_implementation_share), value_up_inc = mean(X$plan_implementation_share)),
  data.frame(measure = "addressees' account", computes = "each rule on the groups it names: up_std producer households; up_inc producer households and hullers, per person",
             value_up_std = addressed("up_std"), value_up_inc = addressed("up_inc")),
  data.frame(measure = names(RULES), computes = paste(c("utilitarian", "prioritarian (a loss counts twice)", "Atkinson eps 0.5", "Atkinson eps 1",
                                                        "Atkinson eps 2", "maximin"), "on the changes of G and H per person (V1)"),
             value_up_std = fs_T4$scores["up_std", ], value_up_inc = fs_T4$scores["up_inc", ]),
  data.frame(measure = c("maximin on levels", "atkinson_1 on levels"),
             computes = "on the levels: status quo money from fonio plus the change (V1), per person",
             value_up_std = fs_levels$scores["up_std", ], value_up_inc = fs_levels$scores["up_inc", ]))
gap <- T4_designs$value_up_std - T4_designs$value_up_inc
T4_designs$ranking <- ifelse(abs(gap) <= 1e-9 * pmax(1, abs(T4_designs$value_up_std)), "equal",
                             ifelse(gap > 0, "std > inc", "inc > std"))
rownames(T4_designs) <- NULL
# the floor: the rule's threshold applied to every group, also to those the rule does not name -- no group below its
# status quo. Who remains below it is the answer; the strict floor only says which design stays admissible.
nb_GWH <- nb_of(c("G", "Wg", "H"), V_MAIN)
T4_floor <- do.call(rbind, lapply(setdiff(OPTIONS, "sq"), function(o) do.call(rbind, lapply(names(nb_GWH), function(g){
  v <- nb_GWH[[g]][, o]
  data.frame(option = o, group = g, p_below = mean(v < 0), mean_shortfall = if (any(v < 0)) -mean(v[v < 0]) else 0,
             flag = mean(v < 0) > FLOOR_ALPHA)
}))))
strict <- fairness_screen(nb_GWH, p = c(1, 1, 1) / 3, rules = list(strict = FLOOR))$scores[, "strict"]   # -Inf = ruled out (a group below 0 in some draw)
T4_admissible <- data.frame(design = DESIGNS,
                            alpha_0 = sapply(DESIGNS, function(o) all(T4_floor$p_below[T4_floor$option == o] == 0)),
                            alpha_0.10 = sapply(DESIGNS, function(o) all(T4_floor$p_below[T4_floor$option == o] <= FLOOR_ALPHA)),
                            alpha_star = sapply(DESIGNS, function(o) max(T4_floor$p_below[T4_floor$option == o])),
                            strict_floor_admits = is.finite(strict[DESIGNS]), row.names = NULL)
stopifnot(all(T4_admissible$alpha_0 == T4_admissible$strict_floor_admits))          # the floor at alpha = 0 is w_constrained(0)
# which group is the minimum: on the changes the group gaining least, on the levels the group with the lowest level
T4_minimum <- data.frame(design = DESIGNS,
                         changes_min_is_hullers = sapply(DESIGNS, function(d) mean(nb_GH$H[, d] < nb_GH$G[, d])),
                         levels_min_is_hullers = sapply(DESIGNS, function(d) mean(levels_GH$H[, d] < levels_GH$G[, d])),
                         row.names = NULL)
# value of information of the design choice under each rule (the status quo left out: the choice is between designs)
nb_designs <- lapply(nb_GH, function(m) m[, DESIGNS, drop = FALSE])
T4_evpi <- do.call(rbind, lapply(names(RULES), function(r){
  v <- voi_partition(nb_designs, p = P_GH, W = RULES[[r]])
  wd <- sapply(DESIGNS, function(d) apply(cbind(nb_GH$G[, d], nb_GH$H[, d]), 1, RULES[[r]], p = P_GH))
  tie <- isTRUE(all.equal(unname(wd[, 1]), unname(wd[, 2])))                        # the same value in every draw (utilitarian: the commune)
  data.frame(rule = r, preferred_design = if (tie) "tie" else v$d_star, p_ahead = if (tie) NA else v$p_ahead,
             EVPI = if (tie) 0 else v$EVPI)
}))
w_mm <- rule_draws(nb_GH, P_GH, w_maximin())                                        # maximin per draw and option
evpi_job("T4_designs_maximin", list(pair = "up_inc_vs_up_std", ahead = "up_inc", rival = "up_std",
                                    v = w_mm[, "up_inc"] - w_mm[, "up_std"]))
T4_plan_split <- data.frame(option = DESIGNS,
                            G_mean = colMeans(nb_GH$G[, DESIGNS]),
                            H_mean_per_huller = colMeans(nb_GH$H[, DESIGNS]),
                            H_per_producer_hh = K_H * colMeans(nb_GH$H[, DESIGNS]),
                            p_hullers_lose = colMeans(nb_GH$H[, DESIGNS] < 0),
                            commune_identical = identical(Y$NB_comm_up_std_V1, Y$NB_comm_up_inc_V1), row.names = NULL)
T4_K <- do.call(rbind, lapply(c(0.1, 0.25, 0.5), function(k){                       # sensitivity: NB_H is inversely proportional to K_H
  nb_k <- nb_GH; nb_k$H <- nb_GH$H * K_H / k
  off_k <- atkinson_offset(k)                                                       # the offset rule of the settings, at this K_H
  rules_k <- RULES
  for (e in c(0.5, 1, 2)) rules_k[[paste0("atkinson_", e)]] <- w_atkinson(e, offset = off_k)
  sc <- fairness_screen(lapply(nb_k, function(m) m[, DESIGNS]), p = c(G = 1, H = k) / (1 + k), rules = rules_k)$scores
  data.frame(K_H = k, t(setNames(ifelse(abs(sc["up_std", ] - sc["up_inc", ]) <= 1e-9 * pmax(1, abs(sc["up_std", ])), "equal",
                                        ifelse(sc["up_std", ] > sc["up_inc", ], "std > inc", "inc > std")), colnames(sc))),
             atkinson_offset = off_k, offset_ok = min(nb_k$G, nb_k$H) + off_k > 0, check.names = FALSE)
}))
EPS_GRID <- seq(0, 5, by = 0.25)                                                    # the inequality curve (supplement S9): Atkinson from eps 0 to 5,
curve_rules <- c(setNames(lapply(EPS_GRID, function(e) w_atkinson(e, offset = ATKINSON_OFFSET)),   # then maximin and the prioritarian point
                          paste0("eps_", EPS_GRID)),
                 list(maximin = w_maximin(), prioritarian = w_prioritarian(loss_twice)))
T4_curve <- fairness_screen(nb_GH, p = P_GH, rules = curve_rules)$scores             # expected value of every option under every rule
res$T4 <- list(distributed = "changes of valued money under V1, per person (a producer household; a paid huller); level variant: status quo money from fonio plus the change",
               level_offset = LEVEL_OFFSET, level_min = min(unlist(levels_GH)),
               all_options = T4_all_options, rank_cor = T4_rank_cor, rank_cor_min = fs_T4$rank_correlation,
               designs = T4_designs, floor = T4_floor, admissible = T4_admissible, minimum = T4_minimum,
               evpi = T4_evpi, scores = fs_T4$scores, plan_split = T4_plan_split, K = T4_K,
               offset_ok = offset_ok, screen = fs_T4, curve = T4_curve, eps_grid = EPS_GRID)



# T5 · ACTOR-DIFFERENTIATED VALUE OF INFORMATION (axis 5)
#      From persons over households to the commune; never across communes.

# (a) EVPI ladder under V0, V1 and PREF (the strict floor is not in it: it constrains, it does not rank)
ladder <- function(setting){
  rows <- list(
    "person: woman in a producer household (Wg)" = one(nb_of("Wg", setting)$Wg),
    "person: paid huller (H)"                    = one(nb_of("H", setting)$H),
    "household: type self"                       = one(nb_of("Gself", setting)$Gself),
    "household: type hire"                       = one(nb_of("Ghire", setting)$Ghire),
    "household: average (G)"                     = one(nb_of("G", setting)$G),
    "women pooled"                               = voi_partition(nb_of(c("Wg", "H"), setting), p = P_WH, W = w_utilitarian()),
    "commune (per producer household)"           = one(nb_of("comm", setting)$comm))
  fs <- fairness_screen(nb_of(c("G", "H"), setting), p = P_GH, rules = RULES)      # the commune under each rule of T4
  rbind(data.frame(setting = setting, level = names(rows),
                   option = sapply(rows, `[[`, "d_star"), p_ahead = sapply(rows, `[[`, "p_ahead"),
                   EVPI = sapply(rows, `[[`, "EVPI"), row.names = NULL),
        data.frame(setting = setting, level = paste("commune, rule:", fs$table$rule),
                   option = fs$table$option, p_ahead = fs$table$p_ahead, EVPI = fs$table$EVPI))
}
T5a <- do.call(rbind, lapply(c("V0", "V1", "PREF"), ladder))

# (b) multi_EVPI() of the decisive pair per level (V1), and of the commune under the utilitarian rule and under
#     maximin over persons: does the research priority depend on the criterion? (run below, side by side)
levels_b <- list(Wg = nb_of("Wg", V_MAIN)$Wg, H = nb_of("H", V_MAIN)$H, G = nb_of("G", V_MAIN)$G,
                 commune = nb_of("comm", V_MAIN)$comm)
pairs_b <- lapply(levels_b, decisive_of)
stopifnot(pairs_b$commune$pair == sub("^comm_V1_", "", dec_main),                   # the commune's pair is the model file's main pair:
          isTRUE(all.equal(unname(pairs_b$commune$v), unname(decisive("comm", "V1")))))   #   its multi_EVPI() is reused, not repeated
for (k in c("Wg", "H", "G")) evpi_job(paste0("T5_level_", k), pairs_b[[k]])
rule_pairs <- list(utilitarian = decisive_of(rule_draws(nb_GH, P_GH, RULES$utilitarian)),
                   maximin     = decisive_of(w_mm))
for (r in names(rule_pairs)) evpi_job(paste0("T5_commune_", r), rule_pairs[[r]])

# (c) value of heterogeneity over the household types of the commune (V1)
#     Groups self and hire; the commune value of a type with the H and O flows it causes. The type shares
#     change per draw, so the values enter weighted with their share, W utilitarian, p = (1, 1): the
#     normalisation p = (1/2, 1/2) halves every level, so A, B, C, D are multiplied by 2 below.
nb_types <- nb_of(c("self", "hire"), V_MAIN, pattern = "NBc_{group}_{option}_")
nb_types$self <- (1 - X$hiring_hh_share) * nb_types$self
nb_types$hire <- X$hiring_hh_share * nb_types$hire
ALLOWED <- rbind(c("sq", "sq"), c("out", "sq"), c("sq", "out"), c("out", "out"),     # only out can be steered to one type (registration);
                 c("up_std", "up_std"), c("up_inc", "up_inc"), c("deep", "deep"))    # a national plan and a campaign reach both alike
colnames(ALLOWED) <- c("self", "hire")
vp_types <- list(restricted   = voi_partition(nb_types, p = c(1, 1), W = w_utilitarian(), differentiated = TRUE, profiles = ALLOWED),
                 unrestricted = voi_partition(nb_types, p = c(1, 1), W = w_utilitarian(), differentiated = TRUE))
S_DRAWS <- nrow(Y)
boot_voh <- function(prof){                                                          # MCSE: bootstrap over draws, the choices re-optimised
  w_one  <- 0.5 * (nb_types$self + nb_types$hire)                                   # utilitarian value per draw, one decision for all
  w_prof <- sapply(seq_len(nrow(prof)), function(r)
    0.5 * (nb_types$self[, prof[r, 1]] + nb_types$hire[, prof[r, 2]]))              # per draw, every allowed profile
  stat <- function(i) {
    A <- max(colMeans(w_one[i, ])); C <- mean(apply(w_one[i, ], 1, max))
    B <- max(colMeans(w_prof[i, ])); D <- mean(apply(w_prof[i, ], 1, max))
    c(2 * c(A = A, B = B, C = C, D = D, EVPI = C - A, VoH_static = B - A, EVPI_sub = D - B, VoH_dyn = D - C),
      voh_index = (B - A) / (C - A))                                                 # levels x 2: the normalisation of p undone
  }
  set.seed(SEED)
  list(point = stat(seq_len(S_DRAWS)), mcse = apply(replicate(N_BOOT, stat(sample.int(S_DRAWS, replace = TRUE))), 1, sd))
}
all_prof <- as.matrix(expand.grid(self = OPTIONS, hire = OPTIONS, stringsAsFactors = FALSE))
bt <- list(restricted = boot_voh(ALLOWED), unrestricted = boot_voh(all_prof))
T5c <- do.call(rbind, lapply(names(vp_types), function(k){
  v <- vp_types[[k]]
  pt <- 2 * c(A = v$A, B = v$B, C = v$C, D = v$D, EVPI = v$EVPI, VoH_static = v$VoH_static,
              EVPI_sub = v$EVPI_sub, VoH_dyn = v$VoH_dyn)
  stopifnot(isTRUE(all.equal(pt, bt[[k]]$point[names(pt)], tolerance = 1e-9)))       # the bootstrap statistic reproduces voi_partition()
  data.frame(profiles = k, quantity = c(names(pt), "voh_index"), value = c(pt, voh_index(v)),
             mcse = bt[[k]]$mcse[c(names(pt), "voh_index")],
             planner_profile = paste(names(v$planner_profile), v$planner_profile, sep = ": ", collapse = ", "),
             d_star = v$d_star, row.names = NULL)
}))
res$T5 <- list(ladder = T5a, heterogeneity = T5c, partitions = vp_types,
               level_pairs = sapply(pairs_b, `[[`, "pair"), rule_pairs = sapply(rule_pairs, `[[`, "pair"),
               rule_evpi = data.frame(rule = names(rule_pairs),
                                      EVPI = sapply(names(rule_pairs), function(r) T5a$EVPI[T5a$setting == V_MAIN & T5a$level == paste("commune, rule:", r)])))



# T6 · FIDELITY (across the directions; H4)
# (a) fidelity_threshold(): the share f* of the preferred option's effect that must arrive for it to stay ahead
#     (reported in the csv only: where the runner-up is the status quo the function says nothing)

fid_single <- do.call(rbind, lapply(c(G = "G", H = "H", commune = "comm"), function(a){
  ft <- fidelity_threshold(list(unit = nb_of(a, V_MAIN)[[1]]), p = 1, W = w_utilitarian())
  cbind(account = a, rule = "expected value", as.data.frame(ft))
}))
fid_rules <- do.call(rbind, lapply(names(RULES), function(r){
  ft <- fidelity_threshold(nb_GH, p = P_GH, W = RULES[[r]])
  cbind(account = "G and H", rule = r, as.data.frame(ft))
}))
T6a <- rbind(fid_single, fid_rules)

# (b) composition of up_inc: the plan's reach component (machines, U2) and its distributive component
#     (the inclusive rule, U3) delivered as ratios of the design. decision_model() is re-run on the same
#     draws: the same seed gives mcSimulation() the same inputs and the same downtime years; only the two
#     named inputs are scaled. (1, 1) is the main run (tests/testthat/test-model.R shows the re-run equals it).
decision_model_fidelity <- function(){
  plan_implementation_share  <- F_REACH * plan_implementation_share                 # U2 share of the designed machines that arrive
  inclusive_rule_enforcement <- F_RULE  * inclusive_rule_enforcement                # U3 share of the designed margin rule that is enforced
  eval(body(decision_model))                                                        # the unchanged model, on this draw
}
composition_run <- function(reach, rule){
  if (reach == 1 && rule == 1) return(simulation_results)
  F_REACH <<- reach; F_RULE <<- rule
  rerun(decision_model_fidelity)
}
runs_T6 <- parallel::mclapply(seq_len(nrow(COMPOSITIONS)), function(i)            # the re-runs side by side
  composition_run(COMPOSITIONS$reach[i], COMPOSITIONS$rule[i])$y, mc.cores = 4)
T6b <- do.call(rbind, lapply(seq_len(nrow(COMPOSITIONS)), function(i){
  cr <- COMPOSITIONS[i, ]
  yy <- runs_T6[[i]]
  do.call(rbind, lapply(c("up_inc", "up_std"), function(o) data.frame(
    reach = cr$reach, rule = cr$rule, mean_fidelity = (cr$reach + cr$rule) / 2, option = o,
    G_mean = mean(yy[[paste0("NB_G_", o, "_V1")]]), G_p_loss = mean(yy[[paste0("NB_G_", o, "_V1")]] < 0),
    Wg_mean = mean(yy[[paste0("NB_Wg_", o, "_V1")]]),
    H_mean = mean(yy[[paste0("NB_H_", o, "_V1")]]), H_p_loss = mean(yy[[paste0("NB_H_", o, "_V1")]] < 0),
    comm_mean = mean(yy[[paste0("NB_comm_", o, "_V1")]]), comm_p_loss = mean(yy[[paste0("NB_comm_", o, "_V1")]] < 0))))
}))
T6_draws <- lapply(runs_T6, function(yy) yy[, c("NB_G_up_inc_V1", "NB_H_up_inc_V1", "NB_comm_up_inc_V1")])  # per draw, for F2 (f) and S7
T6_preferred <- data.frame(COMPOSITIONS, t(sapply(runs_T6, function(yy) sapply(c(commune = "comm", G = "G", H = "H"),   # the option each
  function(a) one(nb_of(a, V_MAIN, sim = list(y = yy))[[1]])$d_star))), row.names = NULL)                               #   account prefers

# (c) the threshold of the rule's delivery at full machine delivery (reach 1): the model is linear in the
#     enforcement e of the inclusive rule, NB_H(e) = NB_H(up_std) + e (NB_H(up_inc) - NB_H(up_std)) in every
#     draw (tests/testthat/test-model.R), so e* -- the hullers' mean at 0 -- is closed; the e from which the
#     hullers lose in at most FLOOR_ALPHA of the draws is read off a grid.
H_std <- Y$NB_H_up_std_V1; H_inc <- Y$NB_H_up_inc_V1
e_star <- -mean(H_std) / (mean(H_inc) - mean(H_std))
T6_rule_grid <- data.frame(e = E_GRID, H_mean = sapply(E_GRID, function(e) mean(H_std + e * (H_inc - H_std))),
                           H_p_loss = sapply(E_GRID, function(e) mean(H_std + e * (H_inc - H_std) < 0)))
e_alpha <- if (any(T6_rule_grid$H_p_loss <= FLOOR_ALPHA)) min(T6_rule_grid$e[T6_rule_grid$H_p_loss <= FLOOR_ALPHA]) else NA
T6_e_star <- data.frame(e_star = e_star, e_star_in_0_1 = e_star >= 0 && e_star <= 1,
                        e_alpha = e_alpha, alpha = FLOOR_ALPHA, H_p_loss_at_e1 = mean(H_inc < 0),
                        H_p_loss_at_e_star = mean(H_std + e_star * (H_inc - H_std) < 0))
T6_e_star_draws <- H_std + e_star * (H_inc - H_std)                                 # the hullers per draw at e*, for F2 (f)
# (d) "aggregate fidelity will conceal": the three compositions with mean fidelity 0.5, commune against hullers
half <- T6b[T6b$option == "up_inc" & T6b$mean_fidelity == 0.5, ]
T6_conceal <- data.frame(compositions = nrow(half), commune_min = min(half$comm_mean), commune_max = max(half$comm_mean),
                         commune_range = diff(range(half$comm_mean)), hullers_min = min(half$H_mean), hullers_max = max(half$H_mean),
                         hullers_range = diff(range(half$H_mean)), hullers_range_per_producer_hh = K_H * diff(range(half$H_mean)),
                         household_range = diff(range(half$G_mean)))
# value of information under both settings of the test: the hullers' decision at (1, 1) and at (0.75, 0.25)
i_mach <- which(COMPOSITIONS$reach == 0.75 & COMPOSITIONS$rule == 0.25)
H_mach <- as.matrix(nb_of("H", V_MAIN, sim = list(y = runs_T6[[i_mach]]))$H)
T6_evpi <- data.frame(composition = c("(1, 1)", "(0.75, 0.25)"),
                      preferred = c(one(nb_of("H", V_MAIN)$H)$d_star, one(H_mach)$d_star),
                      EVPI = c(one(nb_of("H", V_MAIN)$H)$EVPI, one(H_mach)$EVPI))
d_mach <- decisive_of(H_mach)
evpi_job("T6_hullers_0.75_0.25", d_mach)
res$T6 <- list(thresholds = T6a, composition = T6b, compositions = COMPOSITIONS, draws = T6_draws, preferred = T6_preferred,
               e_star = T6_e_star, rule_grid = T6_rule_grid, e_star_draws = T6_e_star_draws, conceal = T6_conceal,
               evpi = T6_evpi, mach_pair = d_mach$pair)



#  VALUE OF INFORMATION OF EVERY TEST: multi_EVPI() of each decisive pair above, in the template's mc_table idiom,
#  side by side (one call takes minutes); the model file's two calls (T0 and the main run) are reused, not repeated.
evpi_runs <- parallel::mclapply(names(EVPI_JOBS), function(k)
  tryCatch(multi_evpi_of(EVPI_JOBS[[k]]$v, k), error = function(e) NULL),
  mc.cores = max(1, min(length(EVPI_JOBS), parallel::detectCores() - 1)))
names(evpi_runs) <- names(EVPI_JOBS)
evpi_runs$T0_model <- evpi_T0; evpi_runs$main_model <- evpi_main                    # G under V0; the commune under V1 (model file; = T5 level commune)
EVPI_PAIRS <- c(sapply(EVPI_JOBS, `[[`, "pair"), sapply(EVPI_NONE, `[[`, "pair"),
                T0_model = sub("^G_V0_", "", dec_T0), main_model = sub("^comm_V1_", "", dec_main))
T_evpi <- do.call(rbind, c(lapply(names(evpi_runs), function(k){
  tp <- top_evpi(evpi_runs[[k]])
  if (nrow(tp)) cbind(job = k, pair = EVPI_PAIRS[[k]], rank = seq_len(nrow(tp)), tp) else
    data.frame(job = k, pair = EVPI_PAIRS[[k]], rank = NA, variable = if (is.null(evpi_runs[[k]])) "(failed)" else "(none)",
               EVPI = 0, status = NA)
}), lapply(names(EVPI_NONE), function(k)
  data.frame(job = k, pair = EVPI_PAIRS[[k]], rank = NA, variable = "(no draw reverses the pair)", EVPI = 0, status = NA))))
rownames(T_evpi) <- NULL
evpi_of_rows <- function(k, rows){                                                  # the partial EVPI of named input rows in one job
  if (k %in% names(EVPI_NONE)) return(setNames(rep(0, length(rows)), rows))         #   (0 where no draw reverses the pair)
  e <- evpi_runs[[k]]
  if (is.null(e)) return(setNames(rep(NA_real_, length(rows)), rows))
  setNames(e[[1]]$EVPI[match(rows, e[[1]]$variable)], rows)
}
T_evpi_deep_rows <- data.frame(row = ROWS_DEEP, status = status(ROWS_DEEP),        # deep's rows: in money, on the stated aim (kg),
                               money_G_V0 = evpi_of_rows("T0_model", ROWS_DEEP),    #   and under the explicit rule kappa = 1.5
                               money_commune_V1 = evpi_of_rows("main_model", ROWS_DEEP),
                               kg_more_eaten = evpi_of_rows("H3_kg_eaten", ROWS_DEEP),
                               money_G_kappa15 = evpi_of_rows("H3_kappa15", ROWS_DEEP), row.names = NULL)
res$evpi <- list(table = T_evpi, deep_rows = T_evpi_deep_rows, pairs = EVPI_PAIRS, full = evpi_runs)



#  WRITE
tables <- list(T0_conventional = T0, T0_means = T0_means, T0_multi_evpi = T0_multi,
               T1_boundary = T1a, T1_flips = T1a_flips, T1_path = T1_path, T1_thresholds = T1_thresholds,
               T1b_aspiration = T1b_aims, T1b_shift = T1b_shift, T1b_directions = T1b_directions, T1b_pareto = T1b_pareto,
               T1b_kappa15 = T1b_kappa15, T1b_kg = T1b_kg,
               T2_references = T2, T2_rules = T2_rules, T2_switch = T2_switch, T2_hullers = T2_hullers,
               T2_historical = T2_historical, T2_historical_means = T2_historical_means,
               T2_historical_rules = T2_historical_rules, T2_historical_eat = T2_historical_eat,
               T3_units = T3, T3_own_ranking = T3_own_ranking, T3_hidden_loss = T3_hidden, T3_threshold = T3_threshold,
               T3_evpi = T3_evpi,
               T4_designs = T4_designs, T4_floor = T4_floor, T4_admissible = T4_admissible, T4_minimum = T4_minimum,
               T4_design_evpi = T4_evpi, T4_all_options = T4_all_options,
               T4_rank_correlation = data.frame(rule = rownames(T4_rank_cor), T4_rank_cor, row.names = NULL, check.names = FALSE),
               T4_plan_split = T4_plan_split, T4_K_sensitivity = T4_K,
               T5_evpi_ladder = T5a, T5_heterogeneity = T5c,
               T6_fidelity_threshold = T6a, T6_composition = T6b, T6_e_star = T6_e_star, T6_rule_grid = T6_rule_grid,
               T6_conceal = T6_conceal, T6_evpi = T6_evpi, T6_preferred = T6_preferred,
               T_evpi_leading_rows = T_evpi, T_evpi_deep_rows = T_evpi_deep_rows)
for (k in names(tables)) write.csv(tables[[k]], file.path(OUT, paste0(k, ".csv")), row.names = FALSE)
res$model <- list(dec_T0 = dec_T0, dec_main = dec_main, evpi_T0 = evpi_T0, evpi_main = evpi_main,   # the model file's EVPI and PLS
                  pls_T0 = pls_T0, pls_main = pls_main)                                               # (template idiom), for S1
saveRDS(res, file.path(OUT, "axes_results.rds"))
