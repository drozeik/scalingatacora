#' Screen a decision against a set of fairness rules
#'
#' Runs the same decision through an open list of valuation rules and reports
#' one row per rule: the option the rule recommends, how often that option is
#' also the best one in a draw, what perfect information would be worth under
#' the rule, and how often the recommended option leaves a group worse off
#' than the reference state. `rules` has no default: the set of defensible
#' rules is open, and a built-in menu would make that choice for the caller.
#'
#' Every rule is applied inside each draw and then averaged (ex post), as in
#' [voi_partition()].
#'
#' @inheritParams voi_partition
#' @param rules Named list of valuation rules, e.g.
#'   `list(utilitarian = w_utilitarian(), maximin = w_maximin())`.
#' @return An object of class `fairness_screen`: a list with
#'   \itemize{
#'     \item `table`, one row per rule: `rule`, the recommended `option`,
#'       `p_ahead` (share of draws in which it is also the best option under
#'       the rule), `EVPI`, `p_group_loses` (share of draws in which it leaves
#'       at least one group below zero) and `p_hidden_loss` (share of draws in
#'       which the rule's value is positive while a group is below zero, see
#'       [marginalisation_count()]);
#'     \item `scores`, options x rules: the expected value of every option;
#'     \item `rank_correlation`, one number: the smallest Spearman correlation
#'       between the rules' rankings of the options (1 = all rules rank the
#'       options alike);
#'     \item `partitions`, the underlying [voi_partition()] objects.
#'   }
#' @examples
#' set.seed(1)
#' nb <- list(a = cbind(sq = 0, scale = rnorm(500, 8, 15)),
#'            b = cbind(sq = 0, scale = rnorm(500, -2, 15)))
#' fairness_screen(nb, p = c(0.6, 0.4),
#'                 rules = list(util = w_utilitarian(), mmin = w_maximin()))
#' @export
fairness_screen <- function(nb_list, p, rules) {
  if (missing(p))
    stop_missing("p", "group shares are a choice of reporting unit.")
  if (missing(rules))
    stop_missing("rules", "a named list of valuation rules; the set is open.")
  check_rules(rules)

  obj <- prepare_nb(nb_list, p)
  parts <- list()
  losses <- list()
  for (r in names(rules)) {
    w_sd <- welfare_matrix(obj, rules[[r]])
    parts[[r]] <- partition_core(obj, rules[[r]], w_sd = w_sd)
    d <- match(parts[[r]]$d_star, obj$options)
    losses[[r]] <- if (is.na(d)) list(any_loss = NA_real_, hidden_loss = NA_real_)
                   else loss_shares(obj, rules[[r]], d, w_sd)
  }

  num <- function(x, k) vapply(x, function(v) as.numeric(v[[k]]), numeric(1))
  tab <- data.frame(
    rule          = names(rules),
    option        = vapply(parts, function(x) x$d_star, character(1)),
    p_ahead       = num(parts, "p_ahead"),
    EVPI          = num(parts, "EVPI"),
    p_group_loses = num(losses, "any_loss"),
    p_hidden_loss = num(losses, "hidden_loss"),
    row.names = NULL, stringsAsFactors = FALSE)

  scores <- matrix(vapply(parts, function(x) x$criterion, numeric(obj$D)),
                   nrow = obj$D, dimnames = list(obj$options, names(rules)))
  rc <- NA_real_
  if (length(rules) > 1L && obj$D > 1L) {
    # rank 1 = best; -Inf (ruled out by a floor) lands last, as it should
    ranks <- apply(-scores, 2L, rank, ties.method = "min", na.last = "keep")
    cm <- suppressWarnings(stats::cor(ranks, method = "spearman"))
    rc <- min(cm[upper.tri(cm)], na.rm = FALSE)
  }

  out <- list(table = tab, scores = scores, rank_correlation = rc,
              partitions = parts, p = obj$p, options = obj$options,
              groups = obj$groups)
  class(out) <- c("fairness_screen", "list")
  out
}

#' Count hidden losses: the aggregate gains while a group loses
#'
#' Share of Monte Carlo draws in which the evaluated option shows a gain in
#' the aggregate (the rule `W` is positive) *and* leaves at least one group
#' below zero, i.e. worse off than in the reference state. A single aggregate
#' number reports a gain in these draws; the loss of the group is hidden in
#' it. Reported for all groups together and for each group.
#'
#' @inheritParams voi_partition
#' @param W Valuation rule that forms the aggregate, e.g. [w_utilitarian()].
#'   Also picks the option to evaluate when `d_star` is `NULL`.
#' @param d_star Option to evaluate (name or column index). If `NULL`, the
#'   option recommended under `W`, as in [voi_partition()].
#' @return An object of class `marginalisation_count`: `share` (all groups
#'   together), `by_group` (a data frame with the share per group), `d_star`
#'   and `n_draws`.
#' @examples
#' set.seed(1)
#' nb <- list(a = cbind(sq = 0, scale = rnorm(500, 8, 15)),
#'            b = cbind(sq = 0, scale = rnorm(500, -2, 15)))
#' marginalisation_count(nb, p = c(0.6, 0.4), W = w_utilitarian())
#' @export
marginalisation_count <- function(nb_list, p, W, d_star = NULL) {
  if (missing(p))
    stop_missing("p", "group shares are a choice of reporting unit.")
  if (missing(W))
    stop_missing("W", "the rule that forms the aggregate, e.g. w_utilitarian().")
  check_rule(W)
  obj <- prepare_nb(nb_list, p)

  w_sd <- welfare_matrix(obj, W)
  if (is.null(d_star)) {
    crit <- colMeans(w_sd)
    if (anyNA(crit))
      stop("The value of some option is undefined (NA) under `W`; pass ",
           "`d_star` explicitly or fix the rule.", call. = FALSE)
    d_idx <- which_max1(crit)
  } else {
    d_idx <- if (is.character(d_star)) match(d_star, obj$options)
             else suppressWarnings(as.integer(d_star))
    if (length(d_idx) != 1L || is.na(d_idx) || d_idx < 1L || d_idx > obj$D)
      stop("`d_star` does not identify an option of `nb_list`.", call. = FALSE)
  }

  ls <- loss_shares(obj, W, d_idx, w_sd)
  out <- list(share = ls$hidden_loss,
              by_group = data.frame(group = obj$groups,
                                    share = as.numeric(ls$hidden_loss_by_group),
                                    row.names = NULL, stringsAsFactors = FALSE),
              d_star = obj$options[d_idx], n_draws = obj$S, p = obj$p)
  class(out) <- c("marginalisation_count", "list")
  out
}
