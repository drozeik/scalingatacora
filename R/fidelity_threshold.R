#' Fidelity threshold: how much of an option's effect must arrive
#'
#' A switching value in the sense of decisionSupport; fidelity here means the
#' share of an option's effect that arrives among those reached.
#'
#' The effect of one option against the reference state (`0` = no change) is
#' scaled by a share \eqn{f}, every other option is left unchanged, and the
#' rule `W` is applied inside every draw and averaged (ex post), as in
#' [voi_partition()]:
#' \deqn{V_d(f) = E_\theta W(f \cdot NB(d, \theta)).}
#' The threshold \eqn{f^*_d} is the smallest \eqn{f \in [0, 1]} at which option
#' \eqn{d} is still (or would be) recommended, i.e. at which \eqn{V_d(f)}
#' reaches the best expected value among the other options at full effect.
#' For the recommended option this reads: it stays recommended as long as at
#' least \eqn{f^*} of its effect arrives. For another option \eqn{f^*} exists
#' only if some share of at most 1 would put it ahead; otherwise it is `NA`.
#'
#' The search assumes that \eqn{V_d(f)} does not fall as \eqn{f} rises for an
#' option whose full effect is worth at least as much as the best other
#' option. This holds for every rule with \eqn{W(f x) = f W(x)} for
#' \eqn{f \ge 0}, e.g. [w_utilitarian()], [w_maximin()] and [w_prioritarian()]
#' with a transform that is linear on each side of zero; for these
#' \eqn{f^* = \max(\text{others}) / V_d(1)}.
#'
#' @inheritParams voi_partition
#' @param tol Tolerance of the search for \eqn{f^*}.
#' @return An object of class `fidelity_threshold`: a data frame with one row
#'   per option, the columns `option`, `value` (expected value under `W` at
#'   full effect), `best_other` (the best expected value among the other
#'   options), `recommended` (`TRUE` for the option with the highest value;
#'   the first one on ties) and `f_star`.
#' @examples
#' set.seed(1)
#' nb <- list(a = cbind(sq = 0, x = rnorm(500, 6, 4), y = rnorm(500, 1.5, 1)),
#'            b = cbind(sq = 0, x = rnorm(500, 0, 4), y = rnorm(500, 3, 1)))
#' fidelity_threshold(nb, p = c(0.5, 0.5), W = w_utilitarian())
#' @export
fidelity_threshold <- function(nb_list, p, W, tol = 1e-9) {
  if (missing(p))
    stop_missing("p", "group shares are a choice of reporting unit.")
  if (missing(W))
    stop_missing("W", "the valuation rule, e.g. w_utilitarian().")
  check_rule(W)
  if (!is.numeric(tol) || length(tol) != 1L || !(tol > 0))
    stop("`tol` must be a single positive number.", call. = FALSE)
  obj <- prepare_nb(nb_list, p)

  value <- colMeans(welfare_matrix(obj, W))
  if (anyNA(value))
    stop("The value of some option is undefined (NA) under `W`.", call. = FALSE)
  value_at <- function(d, f) {                   # V_d(f): option d's effect scaled by f
    scaled <- obj
    scaled$u[, d, ] <- f * obj$u[, d, ]
    mean(welfare_post(scaled, W, const_sel(obj, d)))
  }

  f_star <- vapply(seq_len(obj$D), function(d) {
    target <- if (obj$D > 1L) max(value[-d]) else -Inf
    if (value[[d]] < target) return(NA_real_)    # not ahead even at full effect
    if (value_at(d, 0) >= target) return(0)      # ahead whatever share arrives
    lo <- 0; hi <- 1                             # V_d(lo) < target <= V_d(hi)
    while (hi - lo > tol) {
      mid <- (lo + hi) / 2
      if (value_at(d, mid) >= target) hi <- mid else lo <- mid
    }
    hi
  }, numeric(1))

  out <- data.frame(option = obj$options, value = as.numeric(value),
                    best_other = vapply(seq_len(obj$D), function(d)
                      if (obj$D > 1L) max(value[-d]) else NA_real_, numeric(1)),
                    recommended = seq_len(obj$D) == which_max1(value),
                    f_star = f_star, row.names = NULL, stringsAsFactors = FALSE)
  class(out) <- c("fidelity_threshold", "data.frame")
  out
}
