#' Compare explicitly chosen fairness rules
#' @inheritParams welfare_draws
#' @param rules Named list of functions(nb, p); no default valuation choice.
#' @return Class fairness_screen: table (one row per rule), scores (options x
#'   rules), rank_correlation (smallest pairwise Spearman correlation),
#'   partitions (underlying VOI summaries), and group/option/share labels.
#' @examples
#' nb <- list(a = cbind(sq = 0, x = c(8, 2)), b = cbind(sq = 0, x = c(-2, 4)))
#' fairness_screen(nb, c(1, 1), list(util = w_utilitarian(), maximin = w_maximin()))
#' @export
fairness_screen <- function(nb_list, p, rules) {
  if (missing(p)) stop_missing("p", "state the group shares.")
  if (missing(rules)) stop_missing("rules", "state the valuation rules.")
  nb_list <- check_nb(nb_list)
  p <- resolve_p(p, names(nb_list))
  check_rules(rules)
  parts <- rows <- list()
  for (r in names(rules)) {
    value <- welfare_draws(nb_list, p, rules[[r]])
    part <- partition_values(value)       # one calculation supplies scores, choice AND EVPI
    d <- match(part$d_star, colnames(value))
    loss <- if (is.na(d)) c(any = NA_real_, hidden = NA_real_) else {
      below <- do.call(cbind, lapply(nb_list, function(x) x[, d] < 0))
      c(any = mean(rowSums(below) > 0),
        hidden = mean(value[, d] > 0 & rowSums(below) > 0))
    }
    rows[[r]] <- data.frame(rule = r, option = part$d_star,
      p_ahead = part$p_ahead, EVPI = part$EVPI,
      p_group_loses = unname(loss["any"]), p_hidden_loss = unname(loss["hidden"]))
    parts[[r]] <- part
  }
  scores <- do.call(cbind, lapply(parts, function(x) x$criterion))
  correlation <- NA_real_
  if (length(rules) > 1L && nrow(scores) > 1L) {
    ranks <- apply(-scores, 2L, rank, ties.method = "min", na.last = "keep")
    pairs <- suppressWarnings(stats::cor(ranks, method = "spearman"))
    correlation <- min(pairs[upper.tri(pairs)])
  }
  table <- do.call(rbind, rows)
  rownames(table) <- NULL
  structure(list(table = table, scores = scores, rank_correlation = correlation,
    partitions = parts, p = p, options = colnames(nb_list[[1L]]),
    groups = names(nb_list)), class = c("fairness_screen", "list"))
}

#' Count draws with an aggregate gain and a group loss
#' @inheritParams welfare_draws
#' @param d_star Option name or integer index; NULL uses the option with largest
#'   expected W. A positive aggregate and a negative group value are strict tests.
#' @return Class marginalisation_count: share, by_group, d_star, n_draws and p.
#' @examples
#' nb <- list(a = cbind(sq = 0, x = c(8, 2)), b = cbind(sq = 0, x = c(-2, 4)))
#' marginalisation_count(nb, c(1, 1), w_utilitarian(), d_star = "x")
#' @export
marginalisation_count <- function(nb_list, p, W, d_star = NULL) {
  if (missing(p)) stop_missing("p", "state the group shares.")
  if (missing(W)) stop_missing("W", "state the aggregate rule.")
  nb_list <- check_nb(nb_list)
  p <- resolve_p(p, names(nb_list))
  value <- welfare_draws(nb_list, p, W)
  d <- if (is.null(d_star)) best_option(colMeans(value)) else
    if (is.character(d_star)) match(d_star, colnames(value)) else d_star
  if (!is.numeric(d) || length(d) != 1L || !is.finite(d) ||
      d != round(d) || d < 1L || d > ncol(value))
    stop("`d_star` does not identify an option; the optimum may be undefined.", call. = FALSE)
  below <- do.call(cbind, lapply(nb_list, function(x) x[, d] < 0))
  gain <- value[, d] > 0                   # W(NB(d, theta_s)) > 0
  hidden <- gain & rowSums(below) > 0      # AND min_g NB_g(d, theta_s) < 0
  structure(list(share = mean(hidden),    # mean(TRUE/FALSE) = sum of indicators / S
    by_group = data.frame(group = names(nb_list), share = colMeans(gain & below),
                          row.names = NULL),
    d_star = colnames(value)[d], n_draws = nrow(value), p = p),
    class = c("marginalisation_count", "list"))
}
