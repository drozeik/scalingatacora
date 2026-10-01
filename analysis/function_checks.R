# The check battery "Do the functions give sensible results?" (handoff v5, section 3.10).
#
# One definition, used twice:
#   tests/testthat/test-function_checks.R  expects every row of blocks a-e and g to pass (and f on a
#                                          small case run)
#   atacora_DA_run.R                       writes all rows, with block f from the full run, to
#                                          outputs/function_checks.md
# Each check returns one row: block, check, expected, obtained, passed ("yes", "no", or
# "warning" where the handoff asks for a flag instead of a failure).
# Needs the layer-1 functions (R/) in the calling environment. No side effects.

check_row <- function(block, check, expected, obtained, ok) {
  data.frame(block = block, check = check, expected = expected, obtained = obtained,
             passed = if (is.na(ok)) "no" else if (is.character(ok)) ok else if (ok) "yes" else "no",
             stringsAsFactors = FALSE)
}
num <- function(v, d = 3) paste(formatC(v, format = "f", digits = d), collapse = " / ")
pct <- function(v) paste0(formatC(100 * v, format = "f", digits = 0), " %", collapse = " / ")
same <- function(a, b, tol = 1e-10) isTRUE(all.equal(a, b, tolerance = tol, check.attributes = FALSE))

# the worked example: four worlds, women and men, status quo, A and B (p = 1/2, 1/2)
worked_example <- function() list(
  women = cbind(sq = 0, A = c(10, 8, 6, 0), B = c(1, 2, 1, 2)),
  men   = cbind(sq = 0, A = c(2, 0, -4, 2), B = c(4, 2, 3, 3)))
loss_twice <- function(z) ifelse(z < 0, 2 * z, z)
RULES_CHECK <- list(utilitarian = w_utilitarian(), maximin = w_maximin(),
                    prioritarian = w_prioritarian(loss_twice))

function_checks_synthetic <- function() {
  nb <- worked_example(); p <- c(women = 0.5, men = 0.5)
  fs <- fairness_screen(nb, p, RULES_CHECK)
  sc <- fs$scores; tab <- fs$table
  vd <- voi_partition(nb, p, w_utilitarian(), differentiated = TRUE)
  hh <- reporting_units(nb, list(household = c(women = 1, men = 1)))
  vh <- voi_partition(hh, 1, w_utilitarian())
  claim <- function(extra) { x <- nb; x$women[, "A"] <- x$women[, "A"] - extra; x }
  bp <- baseline_pair(claim, list(behavioural = 0, preference = 3), p, list(utilitarian = w_utilitarian()))

  a <- rbind(
    check_row("a", "utilitarian value of A / B; recommended option", "3.000 / 2.250; A",
              paste0(num(sc[c("A", "B"), "utilitarian"]), "; ", tab$option[1]),
              same(sc[c("A", "B"), "utilitarian"], c(3, 2.25)) && tab$option[1] == "A"),
    check_row("a", "maximin value of A / B; recommended option", "-0.500 / 1.500; B",
              paste0(num(sc[c("A", "B"), "maximin"]), "; ", tab$option[2]),
              same(sc[c("A", "B"), "maximin"], c(-0.5, 1.5)) && tab$option[2] == "B"),
    check_row("a", "prioritarian (a loss counts twice) value of A / B; recommended option", "2.500 / 2.250; A",
              paste0(num(sc[c("A", "B"), "prioritarian"]), "; ", tab$option[3]),
              same(sc[c("A", "B"), "prioritarian"], c(2.5, 2.25)) && tab$option[3] == "A"),
    check_row("a", "P(a group loses) under A (utilitarian choice) / B (maximin choice)", "25 % / 0 %",
              pct(tab$p_group_loses[1:2]), same(tab$p_group_loses[1:2], c(0.25, 0))),
    check_row("a", "hidden loss under A: the aggregate gains while a group loses", "25 %",
              pct(marginalisation_count(nb, p, w_utilitarian())$share),
              same(marginalisation_count(nb, p, w_utilitarian())$share, 0.25)),
    check_row("a", "EVPI, utilitarian", "0.625", num(tab$EVPI[1]), same(tab$EVPI[1], 0.625)),
    check_row("a", "differentiated = TRUE: B / D / VoH_static", "4.500 / 4.750 / 1.500",
              num(c(vd$B, vd$D, vd$VoH_static)), same(c(vd$B, vd$D, vd$VoH_static), c(4.5, 4.75, 1.5))),
    check_row("a", "household as the sum of women and men: A / B; EVPI", "6.000 / 4.500; 1.250",
              paste0(num(vh$criterion[c("A", "B")]), "; ", num(vh$EVPI)),
              same(vh$criterion[c("A", "B")], c(6, 4.5)) && same(vh$EVPI, 1.25)),
    check_row("a", "baseline_pair(): women's claim at A higher by 3 flips the choice", "A -> B, flip = TRUE",
              paste0(paste(bp$rules$option, collapse = " -> "), ", flip = ", bp$rules$flip[1]),
              identical(bp$rules$option, c("A", "B")) && all(bp$rules$flip)))

  # b: the same numbers after renaming and reordering groups and options
  perm <- list(g2 = nb$men[, c("B", "sq", "A")], g1 = nb$women[, c("B", "sq", "A")])
  perm <- lapply(perm, function(m) { colnames(m) <- c("o_b", "o_sq", "o_a"); m })
  fs2 <- fairness_screen(perm, c(g2 = 0.5, g1 = 0.5), RULES_CHECK)
  vd2 <- voi_partition(perm, c(g2 = 0.5, g1 = 0.5), w_utilitarian(), differentiated = TRUE)
  map <- c(o_b = "B", o_sq = "sq", o_a = "A")
  b <- rbind(
    check_row("b", "rename and reorder groups and options: recommended option per rule", "A / B / A",
              paste(map[fs2$table$option], collapse = " / "), identical(unname(map[fs2$table$option]), tab$option)),
    check_row("b", "rename and reorder: EVPI, P(a group loses), P(hidden loss) per rule", "unchanged",
              if (same(fs2$table[, c("EVPI", "p_group_loses", "p_hidden_loss")],
                       tab[, c("EVPI", "p_group_loses", "p_hidden_loss")])) "unchanged" else "changed",
              same(fs2$table[, c("EVPI", "p_group_loses", "p_hidden_loss")], tab[, c("EVPI", "p_group_loses", "p_hidden_loss")])),
    check_row("b", "rename and reorder: A, B, C, D (differentiated)", "unchanged",
              if (same(unlist(vd2[c("A", "B", "C", "D")]), unlist(vd[c("A", "B", "C", "D")]))) "unchanged" else "changed",
              same(unlist(vd2[c("A", "B", "C", "D")]), unlist(vd[c("A", "B", "C", "D")]))))

  # c: edge cases
  flat <- list(women = cbind(sq = 0, A = rep(3, 4), B = rep(1, 4)), men = cbind(sq = 0, A = rep(1, 4), B = rep(2, 4)))
  dominant <- list(women = cbind(sq = 0, A = c(5, 6, 7, 8), B = c(1, 2, 1, 2)),
                   men = cbind(sq = 0, A = c(4, 3, 5, 3), B = c(1, 0, 2, 1)))
  set.seed(1)
  twin <- cbind(sq = 0, A = stats::rnorm(200, 1, 3), B = stats::rnorm(200, 1.2, 2))
  single <- list(only = cbind(sq = 0, A = c(3, 1, 4, 2), B = c(2, 2, 2, 5)))
  s_scores <- fairness_screen(single, 1, RULES_CHECK)$scores
  cc <- rbind(
    check_row("c", "no uncertainty (all draws equal): EVPI", "0", num(voi_partition(flat, p, w_utilitarian())$EVPI),
              same(voi_partition(flat, p, w_utilitarian())$EVPI, 0)),
    check_row("c", "one option best in every draw: EVPI", "0", num(voi_partition(dominant, p, w_utilitarian())$EVPI),
              same(voi_partition(dominant, p, w_utilitarian())$EVPI, 0)),
    check_row("c", "two identical groups: EVPI(women) = EVPI(men)", "equal",
              num(c(voi_partition(list(women = twin), 1, w_utilitarian())$EVPI,
                    voi_partition(list(men = twin), 1, w_utilitarian())$EVPI)),
              same(voi_partition(list(women = twin), 1, w_utilitarian())$EVPI,
                   voi_partition(list(men = twin), 1, w_utilitarian())$EVPI)),
    check_row("c", "a single group without losses: utilitarian = maximin = prioritarian", "equal",
              paste(apply(s_scores, 2, function(v) num(v, 2)), collapse = " | "),
              same(s_scores[, 1], s_scores[, 2]) && same(s_scores[, 1], s_scores[, 3])))

  # d: scale -- the household as a sum counts twice the mean of women and men
  set.seed(2)
  rnd <- list(women = cbind(sq = 0, A = stats::rnorm(500, 2, 4), B = stats::rnorm(500, 1, 2)),
              men   = cbind(sq = 0, A = stats::rnorm(500, 0, 4), B = stats::rnorm(500, 1.5, 3)))
  evpi_sum <- function(x) voi_partition(reporting_units(x, list(household = c(women = 1, men = 1))), 1, w_utilitarian())$EVPI
  evpi_util <- function(x) voi_partition(x, p, w_utilitarian())$EVPI
  d <- rbind(
    check_row("d", "EVPI(household as sum) = 2 x EVPI(utilitarian, p = 1/2, 1/2), worked example",
              "1.250 = 2 x 0.625", paste0(num(evpi_sum(nb)), " = 2 x ", num(evpi_util(nb))),
              same(evpi_sum(nb), 2 * evpi_util(nb))),
    check_row("d", "the same, 500 random draws", "ratio 2", num(evpi_sum(rnd) / evpi_util(rnd)),
              same(evpi_sum(rnd), 2 * evpi_util(rnd))))

  # e: floor as a share (FLOOR_MODE "share") and as a rule ("rule") agree on the options without loss
  floor_agree <- function(x) {
    share <- vapply(colnames(x[[1]]), function(o) mean(Reduce(`|`, lapply(x, function(m) m[, o] < 0))), numeric(1))
    rule <- fairness_screen(x, p, list(floor = w_constrained(0)))$scores[, "floor"]
    list(share = names(share)[share == 0], rule = names(rule)[is.finite(rule)])
  }
  e1 <- floor_agree(nb); e2 <- floor_agree(rnd)
  e <- rbind(
    check_row("e", "options with P(a group loses) = 0 (share) = options w_constrained() keeps (rule), worked example",
              paste(e1$share, collapse = ", "), paste(e1$rule, collapse = ", "), setequal(e1$share, e1$rule)),
    check_row("e", "the same, 500 random draws", paste(e2$share, collapse = ", "), paste(e2$rule, collapse = ", "),
              setequal(e2$share, e2$rule)))

  # g: fidelity_threshold() (handoff v7, 6): the share of an option's effect that must arrive
  fa <- fidelity_threshold(nb, p, w_utilitarian())
  fd <- fidelity_threshold(dominant, p, w_utilitarian())
  same_ab <- list(women = cbind(sq = 0, A = c(1, 2, 3, 4), B = c(1, 2, 3, 4)),
                  men   = cbind(sq = 0, A = c(2, 2, 2, 2), B = c(2, 2, 2, 2)))
  fs <- fidelity_threshold(same_ab, p, w_utilitarian())
  g <- rbind(
    check_row("g", "fidelity: worked example, utilitarian A 3.0 against B 2.25; f*(A); f*(B)", "0.750; NA",
              paste0(num(fa$f_star[fa$option == "A"]), "; ", fa$f_star[fa$option == "B"]),
              same(fa$f_star[fa$option == "A"], 0.75, 1e-8) && is.na(fa$f_star[fa$option == "B"])),
    check_row("g", "fidelity: a dominant option, f* = best other value / its own", "0.244 (1.25 / 5.125)",
              num(fd$f_star[fd$option == "A"]), same(fd$f_star[fd$option == "A"], 1.25 / 5.125, 1e-8)),
    check_row("g", "fidelity: two identical options, f* of both", "1.000 / 1.000",
              num(fs$f_star[fs$option %in% c("A", "B")]), same(fs$f_star[fs$option %in% c("A", "B")], c(1, 1), 1e-8)))

  rbind(a, b, cc, d, e, g)
}

# Block f, on the case: `accounts` is a data frame with one row per setting x account and the
# columns setting, account, EVPI, p_ahead; `spearman` the rank correlation of multi_EVPI()
# against voi::evppi() (NULL when it was not computed).
function_checks_case <- function(accounts, spearman = NULL) {
  tol <- 1e-9
  f <- rbind(
    check_row("f", "EVPI >= 0 in every account (setting x household, women, men, rule)",
              sprintf("%d of %d", nrow(accounts), nrow(accounts)),
              sprintf("%d of %d, smallest %s", sum(accounts$EVPI >= -tol), nrow(accounts),
                      formatC(min(accounts$EVPI), format = "f", digits = 1)),
              all(accounts$EVPI >= -tol)),
    check_row("f", "EVPI > 0 only where another option is best in some draw (share = 1 - p_ahead)",
              "EVPI > 0 exactly where the share > 0",
              sprintf("share %s to %s; %d accounts with EVPI > 0", pct(min(1 - accounts$p_ahead)),
                      pct(max(1 - accounts$p_ahead)), sum(accounts$EVPI > tol)),
              all((accounts$EVPI > tol) == (accounts$p_ahead < 1))))
  if (!is.null(spearman))
    f <- rbind(f, check_row("f", "multi_EVPI() ranking of the variables against voi::evppi() (Spearman)",
                            ">= 0.6 (below: warning)", num(spearman, 2),
                            if (is.na(spearman)) "no" else if (spearman >= 0.6) "yes" else "warning"))
  f
}

# The same accounts the run reports (handoff v5, 3.8): the household, women, men, and every
# rule over women and men, for one setting. `y` is the model output, one row per draw.
evpi_accounts <- function(y, setting, options, rules, p_groups) {
  m <- function(q) { v <- as.matrix(y[paste(q, options, setting, sep = "_")]); colnames(v) <- options; v }
  one <- function(v) voi_partition(list(unit = v), 1, w_utilitarian())
  two <- list(women = m("money_w"), men = m("money_m"))
  res <- c(list(household = one(m("money_hh")), women = one(m("money_w")), men = one(m("money_m"))),
           lapply(rules, function(W) voi_partition(two, p_groups, W)))
  data.frame(setting = setting, account = names(res),
             option = vapply(res, function(x) x$d_star, character(1)),
             EVPI = vapply(res, function(x) x$EVPI, numeric(1)),
             p_ahead = vapply(res, function(x) x$p_ahead, numeric(1)),
             A = vapply(res, function(x) x$A, numeric(1)),
             row.names = NULL, stringsAsFactors = FALSE)
}
