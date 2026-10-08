# A rule is a function(nb, p) -> one numeric value. nb is the named group
# vector for ONE draw and ONE option; p has already been normalised by callers.
# Each factory returns such a rule: W = w_atkinson(eps = 1, offset = 10).

#' Share-weighted utilitarian value
#' @return Function(nb, p): sum_g p_g NB_g.
#' @examples
#' w_utilitarian()(c(10, -2), c(0.5, 0.5))
#' @export
w_utilitarian <- function() {
  function(nb, p) sum(p * nb)               # multiply each NB_g by p_g, then sum over g
}

#' Value of the worst-off group
#' @return Function(nb, p): min_g NB_g; p is deliberately ignored.
#' @examples
#' w_maximin()(c(10, -2), c(0.5, 0.5))
#' @export
w_maximin <- function() {
  function(nb, p) min(nb)                   # the minimum WITHIN this draw, not of group means
}

#' Share-weighted value after an explicit priority transform
#' @param u Increasing element-wise transform; for priority to worse-off groups,
#'   use a concave transform, e.g. losses counting twice gains.
#' @return Function(nb, p): sum_g p_g u(NB_g).
#' @examples
#' w_prioritarian(function(z) ifelse(z < 0, 2 * z, z))(c(10, -2), c(0.5, 0.5))
#' @export
w_prioritarian <- function(u) {
  if (missing(u)) stop_missing("u", "state the priority transform.")
  if (!is.function(u)) stop("`u` must be a function.", call. = FALSE)
  force(u)
  function(nb, p) {
    transformed <- u(nb)                   # phi_lambda(z) = lambda*z below zero, z otherwise
    if (!is.numeric(transformed) || length(transformed) != length(nb))
      stop("`u` must return one number per group.", call. = FALSE)
    sum(p * transformed)                  # sum_g p_g phi_lambda(NB_g)
  }
}

#' Atkinson equally distributed equivalent, shifted back
#' @param eps Finite inequality aversion >= 0, explicitly chosen.
#' @param offset Constant k in x_g = NB_g + k, default 0. This is a valuation choice.
#' @return Function(nb, p), or NA with a warning outside x_g > 0.
#' @examples
#' w_atkinson(1, offset = 10)(c(10, -2), c(0.5, 0.5))
#' @export
w_atkinson <- function(eps, offset = 0) {
  if (missing(eps)) stop_missing("eps", "state the inequality aversion.")
  check_scalar(eps, "`eps`", 0)
  check_scalar(offset, "`offset`")
  force(eps)
  force(offset)
  function(nb, p) {
    x <- nb + offset                      # x_g = NB_g + k; positivity is part of the formula
    if (any(!is.finite(x)) || any(x <= 0)) {
      warning("w_atkinson(): non-positive group value; returning NA. Check `offset`.",
              call. = FALSE)
      return(NA_real_)
    }
    if (eps == 1) {                       # epsilon = 1: weighted geometric mean, minus k
      exp(sum(p * log(x))) - offset
    } else {                              # epsilon != 1: weighted power mean, minus k
      sum(p * x^(1 - eps))^(1 / (1 - eps)) - offset
    }
  }
}

#' Utilitarian value subject to a floor for every group
#' @param min_group_nb Finite lower bound m; default 0 means no loss to any group.
#' @return Function(nb, p): sum(p * nb) if every NB_g >= m, otherwise -Inf.
#'   One violating draw excludes an option from a fixed decision. If all options
#'   are excluded, there is no recommended option. Do not interpret -Inf as money.
#' @examples
#' w_constrained(0)(c(10, -2), c(0.5, 0.5))
#' @export
w_constrained <- function(min_group_nb = 0) {
  if (!is.numeric(min_group_nb) || length(min_group_nb) != 1L || !is.finite(min_group_nb))
    stop("`min_group_nb` must be a single number, finite.", call. = FALSE)
  force(min_group_nb)
  function(nb, p) {
    if (any(nb < min_group_nb)) -Inf else sum(p * nb)  # indicator of feasibility, including p_g = 0
  }
}
