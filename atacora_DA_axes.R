# FIVE AXES + FIDELITY. Run from the project root; results are in 'review'.

# Uses the existing 10,000 draws (seed 20260927); no new simulation or file writes.
source("load.R", local = TRUE)
simulation_results <- readRDS("outputs/v9/simulation_results.rds")
options <- c("sq", "out", "up_std", "up_inc", "deep")
nb <- function(groups, setting = "V1", prefix = "NB")
  nb_from_mc(simulation_results, paste0(prefix, "_{group}_{option}_", setting), groups, options)

# State the case's valuation choices once. K is fixed in the input table.

K <- unique(simulation_results$x$hullers_per_producer_hh)
stopifnot(length(K) == 1L, is.finite(K), K > 0)
p <- c(G = 1, H = K) / (1 + K)
p_women <- c(Wg = 1, H = K) / (1 + K)
status_quo_cash <- median(simulation_results$y$NPV_G_cash_sq)
largest_loss <- -min(unlist(lapply(c("V0", "V1", "PREF"), function(s) nb(c("G", "H"), s))))
offset <- if (largest_loss < status_quo_cash) status_quo_cash else
  ceiling((largest_loss + 1) / 1e5) * 1e5  # FCFA: status quo median, or next 100,000 above the largest loss
rules <- list(utilitarian = w_utilitarian(),
  prioritarian = w_prioritarian(function(z) ifelse(z < 0, 2 * z, z)),
  atkinson_0.5 = w_atkinson(0.5, offset), atkinson_1 = w_atkinson(1, offset),
  atkinson_2 = w_atkinson(2, offset), maximin = w_maximin())


# 1. SYSTEM BOUNDARY: totals per producer household; K converts H/person to H/HH.
# Operator O is already per household; it is not treated as another person.
boundary_units <- list(G = c(G = 1), GH = c(G = 1, H = K), GHO = c(G = 1, H = K, O = 1))
boundary <- lapply(c(V0 = "V0", V1 = "V1"), function(s)
  nb_summary(reporting_units(nb(c("G", "H", "O"), s), boundary_units)))

# 2. REFERENCE: both valuations come from the SAME simulated states of the world.
references <- baseline_pair(function(s) nb(c("G", "H"), s),
  references = list(behaviour = "V1", preference = "PREF"), p = p, rules = rules)

# 3. REPORTING UNIT: retain separate accounts alongside the pooled women's mean.
women <- nb(c("Wg", "H"))
units <- nb_summary(c(nb(c("G", "Wg", "H")),
  reporting_units(women, list(women_pooled = p_women))))
hidden <- lapply(options[-1L], function(d)
  marginalisation_count(women, p_women, w_utilitarian(), d_star = d))
names(hidden) <- options[-1L]

# 4. FAIRNESS: compare all options AND the two plan designs explicitly (H2).
people <- nb(c("G", "H"))
fairness <- fairness_screen(people, p, rules)
designs <- fairness_screen(lapply(people, function(x) x[, c("up_std", "up_inc")]), p, rules)
floor_by_group <- nb_summary(nb(c("G", "Wg", "H")))[, c("unit", "option", "p_loss")]
floor <- data.frame(option = options, admissible = vapply(options, function(d)
  all(floor_by_group$p_loss[floor_by_group$option == d] == 0), logical(1)))
# The floor is an admissibility check on EVERY group; no floor ranking or floor EVPI.

# 5. INFORMATION: each actor's own decision, and a common decision for the commune.
information <- lapply(c(V0 = "V0", V1 = "V1", PREF = "PREF"), function(s)
  unique(nb_summary(nb(c("Wg", "H", "G", "comm"), s))[, c("unit", "preferred", "EVPI")]))
# Different decisions are possible for household TYPES, not for household members.
types <- nb(c("self", "hire"), prefix = "NBc")
share_hire <- simulation_results$x$hiring_hh_share
types <- Map(function(x, share) share * x, types, list(1 - share_hire, share_hire))
allowed <- rbind(c("sq", "sq"), c("out", "sq"), c("sq", "out"), c("out", "out"),
  c("up_std", "up_std"), c("up_inc", "up_inc"), c("deep", "deep"))
colnames(allowed) <- c("self", "hire")
# Shares are already in each draw: sum contributions to get FCFA per household.
heterogeneity <- voi_partition(types, p = c(1, 1), W = function(nb, p) sum(nb),
  differentiated = TRUE, profiles = allowed)
heterogeneity_ratio <- voh_index(heterogeneity)

# ACROSS DIRECTIONS: scalar effect fidelity; component-specific delivery needs a rerun.
fidelity <- fidelity_threshold(nb("comm"), p = 1, W = w_utilitarian())
review <- list(settings = list(seed = 20260927, draws = nrow(simulation_results$y),
  K = K, p = p, atkinson_offset = offset, rules = names(rules)), boundary = boundary,
  references = references, units = units, hidden = hidden, fairness = fairness,
  designs = designs, floor_by_group = floor_by_group, floor = floor,
  information = information, heterogeneity = heterogeneity,
  heterogeneity_ratio = heterogeneity_ratio, fidelity = fidelity)
print(review$fairness)
