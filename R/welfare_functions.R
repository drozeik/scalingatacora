# Valuation rules W: axis 4 (fairness criterion).
#
# Contract
# --------
# A valuation rule is a function
#
#     W(nb, p) -> one number
#
# where `nb` is the numeric vector of net benefits of the G groups (one draw,
# one option) and `p` the numeric vector of group shares, normalised to sum 1.
# Every factory below returns such a function. The contract is deliberately
# minimal so that users can pass their own rules to fairness_screen().
#
# W must be non-decreasing in every group's value. voi_partition() relies on
# this for the decision per group (differentiated = TRUE); w_constrained() is
# the boundary case (weakly non-decreasing, -Inf where a group is below the
# floor). w_atkinson() is non-decreasing where it is defined (all shifted
# values strictly positive) and NA otherwise.

#' Utilitarian valuation
#'
#' \eqn{W(nb) = \sum_g p_g\, nb_g}: the share-weighted sum of group net benefits.
#' This is the implicit rule of any analysis that reports a single aggregate
#' net present value.
#'
#' @return A function `(nb, p)` returning one number.
#' @examples
#' w_utilitarian()(c(10, -2), c(0.5, 0.5))
#' @export
w_utilitarian <- function() {
  function(nb, p) sum(p * nb)
}

#' Maximin (Rawlsian) valuation
#'
#' \eqn{W(nb) = \min_g nb_g}: the option is valued by its worst-off group. Group
#' shares are accepted for the common signature but ignored, which is the
#' substantive point of the rule.
#'
#' @return A function `(nb, p)` returning one number.
#' @examples
#' w_maximin()(c(10, -2), c(0.9, 0.1))
#' @export
w_maximin <- function() {
  function(nb, p) min(nb)
}

#' Prioritarian valuation
#'
#' \eqn{W(nb) = \sum_g p_g\, u(nb_g)} for an increasing transform `u` that
#' gives more weight to low values, e.g. a loss counting twice a gain. Weight
#' is shifted towards groups that fare badly without going all the way to
#' maximin.
#'
#' @param u An increasing function applied element-wise to the group net
#'   benefits. No default: the transform is a valuation and must be stated.
#' @return A function `(nb, p)` returning one number.
#' @examples
#' # a loss counts twice a gain
#' w_prioritarian(function(z) ifelse(z < 0, 2 * z, z))(c(10, -2), c(0.5, 0.5))
#' @export
w_prioritarian <- function(u) {
  if (missing(u))
    stop_missing("u", "the transform is a valuation, e.g. a loss counting twice.")
  if (!is.function(u)) stop("`u` must be a function.", call. = FALSE)
  force(u)
  function(nb, p) sum(p * u(nb))
}

#' Atkinson valuation (equally distributed equivalent)
#'
#' The Atkinson equally distributed equivalent with inequality aversion `eps`,
#' evaluated at \eqn{x_g = nb_g + \mathrm{offset}} and shifted back:
#' \eqn{W = (\sum_g p_g x_g^{1-\varepsilon})^{1/(1-\varepsilon)} - \mathrm{offset}}
#' for \eqn{\varepsilon \neq 1}, and
#' \eqn{W = \exp(\sum_g p_g \log x_g) - \mathrm{offset}} for \eqn{\varepsilon = 1}.
#' Shifting back keeps `eps = 0` equal to the utilitarian value for any offset,
#' so the offset changes the *curvature* the index sees, not the level.
#'
#' The index is defined for strictly positive quantities only. Net benefits are
#' differences and may be negative, so an `offset` must usually be supplied to
#' move the reference state into the positive orthant. The choice of `offset`
#' changes the result and is therefore an explicit argument rather than a silent
#' choice: report it with the results.
#'
#' @param eps Inequality aversion, `eps >= 0`. `eps = 0` reproduces the
#'   utilitarian rule; `eps -> Inf` approaches maximin. No default: the
#'   aversion is a valuation.
#' @param offset Numeric constant added to every group net benefit before the
#'   index is evaluated. Default `0`.
#' @return A function `(nb, p)` returning one number, or `NA_real_` with a
#'   warning if any shifted value is not strictly positive.
#' @examples
#' w_atkinson(eps = 0)(c(10, 2), c(0.5, 0.5))   # = utilitarian mean
#' w_atkinson(eps = 2)(c(10, 2), c(0.5, 0.5))   # below the mean
#' w_atkinson(eps = 1, offset = 100)(c(10, -2), c(0.5, 0.5))
#' @export
w_atkinson <- function(eps, offset = 0) {
  if (missing(eps))
    stop_missing("eps", "the inequality aversion is a valuation, e.g. eps = 1.")
  if (!is.numeric(eps) || length(eps) != 1L || !is.finite(eps) || eps < 0)
    stop("`eps` must be a single finite number >= 0.", call. = FALSE)
  if (!is.numeric(offset) || length(offset) != 1L || !is.finite(offset))
    stop("`offset` must be a single finite number.", call. = FALSE)
  force(eps); force(offset)
  function(nb, p) {
    x <- nb + offset
    if (any(!is.finite(x)) || any(x <= 0)) {
      warning("w_atkinson(): non-positive group value; returning NA. ",
              "Supply an `offset` that moves all net benefits above zero.",
              call. = FALSE)
      return(NA_real_)
    }
    if (isTRUE(all.equal(eps, 1))) {
      exp(sum(p * log(x))) - offset
    } else {
      sum(p * x^(1 - eps))^(1 / (1 - eps)) - offset
    }
  }
}

#' Constrained utilitarian valuation (fairness floor as a rule)
#'
#' Utilitarian, but an option that pushes any group below `min_group_nb` in a
#' draw is valued `-Inf` in that draw. Averaged over the draws (ex post), an
#' option is ruled out as soon as a single draw leaves a group below the floor.
#' This is the strict "do no harm" reading; reporting the share of draws in
#' which a group loses is the alternative that does not rule anything out
#' (see [fairness_screen()]).
#'
#' @param min_group_nb Lower bound each group's net benefit must respect.
#'   Default `0`, i.e. no group may be made worse off than the reference state.
#' @return A function `(nb, p)` returning one number or `-Inf`.
#' @examples
#' w_constrained()(c(10, -2), c(0.5, 0.5))   # -Inf
#' w_constrained()(c(10,  2), c(0.5, 0.5))   # 6
#' @export
w_constrained <- function(min_group_nb = 0) {
  if (!is.numeric(min_group_nb) || length(min_group_nb) != 1L)
    stop("`min_group_nb` must be a single number.", call. = FALSE)
  force(min_group_nb)
  function(nb, p) {
    if (any(nb < min_group_nb)) -Inf else sum(p * nb)
  }
}
