#' Smallest implemented share whose value reaches the best unchanged alternative
#'
#' V_d(f) = mean_s W(f * NB(d,theta_s)); f* = min{f in [0,1]: V_d(f) >= target}.
#' A tie meets the threshold even when first-option tie breaking reports a rival.
#' The numerical search requires V_d(f) to be finite, continuous and concave on
#' [0,1]. This includes utilitarian, maximin, the loss-linear prioritarian rule
#' with loss multiplier >= 1, and Atkinson within its positive domain. For a
#' user-supplied rule this is a caller contract, not something data can prove.
#' The strict floor is a feasibility condition; use fairness_screen() instead.
#' @inheritParams welfare_draws
#' @param tol Positive absolute tolerance in f, default 1e-9.
#' @return Class fidelity_threshold/data.frame: option, value at f=1, best_other,
#'   recommended (at f=1; exact ties go to the first), f_star. NA means the
#'   option never reaches its target on [0,1]. If only an intermediate interval
#'   is feasible, f_star is its LOWER endpoint; it is not a guarantee for all
#'   larger f. The full-effect value column makes that limitation visible.
#' @examples
#' nb <- list(a = cbind(sq = 0, x = c(6, 2), y = c(1, 3)))
#' fidelity_threshold(nb, 1, w_utilitarian())
#' @export
fidelity_threshold <- function(nb_list, p, W, tol = 1e-9) {
  if (missing(p)) stop_missing("p", "state the group shares.")
  if (missing(W)) stop_missing("W", "state the valuation rule.")
  check_scalar(tol, "`tol`", .Machine$double.xmin)
  nb_list <- check_nb(nb_list)
  p <- resolve_p(p, names(nb_list))
  value <- colMeans(welfare_draws(nb_list, p, W))
  if (any(!is.finite(value)))
    stop("Fidelity requires finite values; check the rule domain. Report floors separately.", call. = FALSE)
  other <- vapply(seq_along(value), function(d)
    if (length(value) == 1L) -Inf else max(value[-d]), numeric(1))
  threshold <- numeric(length(value))
  for (d in seq_along(value)) {
    groups <- do.call(cbind, lapply(nb_list, function(x) x[, d]))
    value_at <- function(f) {
      result <- mean(rule_by_draw(f * groups, p, W))  # scale NB, apply W, THEN average
      if (!is.finite(result)) stop("W(f * NB) is undefined for f = ", f, ".", call. = FALSE)
      result
    }
    if (value_at(0) >= other[d]) {        # the minimum of [0,1] already satisfies the inequality
      threshold[d] <- 0
      next
    }
    hi <- 1
    if (value[d] < other[d]) {
      # Mixed positive/negative effects can give an interior maximum under
      # Atkinson. 'Loses at f=1' therefore does NOT prove 'never reaches target'.
      peak <- stats::optimize(value_at, c(0, 1), maximum = TRUE, tol = tol)
      if (peak$objective < other[d]) {
        threshold[d] <- NA_real_
        next
      }
      hi <- peak$maximum
    }
    lo <- 0                              # V(lo) < target <= V(hi)
    while (hi - lo > tol) {              # concavity makes the feasible set an interval
      mid <- (lo + hi) / 2
      if (value_at(mid) >= other[d]) hi <- mid else lo <- mid
    }
    threshold[d] <- hi                   # upper bracket: smallest feasible f to tolerance
  }
  other[other == -Inf] <- NA_real_
  structure(data.frame(option = names(value), value = as.numeric(value),
    best_other = other, recommended = seq_along(value) == which.max(value),
    f_star = threshold, row.names = NULL), class = c("fidelity_threshold", "data.frame"))
}
