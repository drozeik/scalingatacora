#' Apply a valuation rule to every draw and option
#'
#' The one shared mathematical step: U[s,d] = W(NB_1[s,d], ..., NB_G[s,d]; p).
#' Keeping draws as rows makes the subsequent expectation simply colMeans(U).
#' @param nb_list List of numeric draws x options matrices, one per group.
#' @param p Group shares, normalised to one; named shares are aligned by name.
#' @param W Function(nb, p) returning one number for one draw and option.
#' @return Numeric matrix with draws in rows and options in columns.
#' @examples
#' nb <- list(a = cbind(sq = 0, x = c(8, 2)), b = cbind(sq = 0, x = c(-2, 4)))
#' welfare_draws(nb, p = c(1, 1), W = w_utilitarian())
#' @export
welfare_draws <- function(nb_list, p, W) {
  if (missing(p)) stop_missing("p", "state the group shares.")
  if (missing(W)) stop_missing("W", "state the valuation rule.")
  nb_list <- check_nb(nb_list)
  p <- resolve_p(p, names(nb_list))
  check_rule(W)
  value <- matrix(NA_real_, nrow(nb_list[[1L]]), ncol(nb_list[[1L]]),
                  dimnames = dimnames(nb_list[[1L]]))
  for (d in seq_len(ncol(value))) {
    # Each column of 'groups' is NB_g(d, theta_1), ..., NB_g(d, theta_S).
    groups <- do.call(cbind, lapply(nb_list, function(x) x[, d]))
    # A row is the vector NB(d, theta_s); apply W BEFORE taking a mean.
    value[, d] <- rule_by_draw(groups, p, W)
  }
  value
}

# The only rule evaluator; also used when different groups receive different
# options. vapply requires exactly one number from W for each draw.
rule_by_draw <- function(groups, p, W) {
  value <- vapply(seq_len(nrow(groups)), function(s) W(groups[s, ], p), numeric(1))
  if (any(value == Inf, na.rm = TRUE))
    stop("`W` returned +Inf; check its domain or numerical overflow.", call. = FALSE)
  value
}
