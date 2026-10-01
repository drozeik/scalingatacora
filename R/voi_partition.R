#' Expected value of perfect information for a decision shared by several groups
#'
#' The first output is the expected value of perfect information (EVPI) of one
#' decision for all groups, valued with the rule `W`:
#' \deqn{A = \max_d E_\theta W(NB(d, \theta)), \quad
#'       C = E_\theta \max_d W(NB(d, \theta)), \quad EVPI = C - A.}
#' `A` is what an analysis at today's information reports for the recommended
#' option `d_star`; `C` is what the same decision would be worth if the
#' uncertain state were known before choosing.
#'
#' The rule is applied inside every draw and then averaged (ex post,
#' \eqn{E_\theta W(NB)}): only then can the value of information not become
#' negative for a non-linear rule, because \eqn{W(E_\theta NB)} is not the
#' expected value of anything.
#'
#' @section Decisions per group (`differentiated = TRUE`):
#' Only meaningful when groups can actually receive different options, e.g.
#' communes or regions. Groups derived from context, such as women and men
#' within one household, are reported through the EVPI of each group instead.
#' With `differentiated = TRUE` a planner may give each group its own option;
#' the planner picks the profile of options that maximises the rule's expected
#' value. This adds
#' \itemize{
#'   \item `B`: best profile at today's information, and `D`: the same under
#'     perfect information;
#'   \item `VoH_static = B - A`: the value of deciding per group today;
#'   \item `EVPI_sub = D - B`: the EVPI once decisions are made per group;
#'   \item `VoH_dyn = D - C`: the value of deciding per group under perfect
#'     information.
#' }
#' With the planner reading all of them are non-negative for every rule that
#' is non-decreasing in each group's value. See also
#' [voh_index()].
#' Espinoza et al. (2014, Fig. 2) use the letters A-D for distances (EVPI of
#' one decision, EVPI per group, static and dynamic value of heterogeneity),
#' whereas `A`-`D` here are levels, so that their static value (eq. 8) is
#' `B - A` and their dynamic value (Fig. 2c) is `D - C`.
#'
#' @section Restricted profiles (`profiles`):
#' Use profiles when some options cannot differ between groups, e.g. a
#' national rule or a public campaign that reaches every household. With
#' `profiles` the planner chooses among the listed profiles only:
#' \deqn{B = \max_{r \in R} E_\theta W(NB(r, \theta)), \quad
#'       D = E_\theta \max_{r \in R} W(NB(r, \theta)),}
#' where `D` is enumerated in every draw (the shortcut of giving each group
#' its own best option holds only without restriction). `A` and `C` remain
#' the values of one decision for all over every option; if every such
#' profile (the same option for all groups) is listed, `B >= A` and `D >= C`,
#' and with only these profiles `B = A` and `D = C`.
#'
#' @param nb_list Named list, one element per group: an `S x D` numeric matrix
#'   (draws x options) of net benefits against the reference state (`0` = no
#'   change), options in the same order in every group. One outcome per call.
#' @param p Numeric vector of group shares, one per group. Normalised
#'   internally; if named, aligned to the groups by name. No default: the
#'   shares are a choice of reporting unit.
#' @param W Valuation rule, a function `(nb, p)` returning one number, such as
#'   [w_utilitarian()]. No default.
#' @param differentiated `FALSE` (default) reports one decision for all.
#'   `TRUE` adds the decision per group (see the section above). The default is
#'   a deliberate exception to the rule that valuation choices have no default
#'   (FUNCTIONS.md, design rule 2): one decision for all is what the data describe unless
#'   the caller states that groups can be served differently.
#' @param profiles `NULL` (default: every profile) or, with
#'   `differentiated = TRUE`, the allowed profiles: a matrix with one row per
#'   profile and one column per group (named by group, otherwise in the order
#'   of `nb_list`), entries option names or option indices. See the section
#'   on restricted profiles.
#' @param max_profiles Guard for `differentiated = TRUE`: refuse to enumerate
#'   more than this many profiles of options (`n_options^n_groups`, or the
#'   rows of `profiles`).
#' @return An object of class `voi_partition`: a list with `EVPI`, `A`, `C`,
#'   the recommended option `d_star`, `p_ahead` (share of draws in which
#'   `d_star` is also the best option), the expected value of every option
#'   `criterion`, and, with `differentiated = TRUE`, `B`, `D`, `VoH_static`,
#'   `EVPI_sub`, `VoH_dyn`, the planner's profile, each group's own best
#'   option, `restricted` (whether `profiles` was given) and `n_profiles`.
#'
#' @examples
#' set.seed(1)
#' g1 <- cbind(status_quo = 0, scale = rnorm(500, 10, 20))
#' g2 <- cbind(status_quo = 0, scale = rnorm(500, -3, 20))
#' voi_partition(list(a = g1, b = g2), p = c(0.6, 0.4), W = w_utilitarian())
#' voi_partition(list(a = g1, b = g2), p = c(0.6, 0.4), W = w_maximin(),
#'               differentiated = TRUE)
#' # only 'scale' can be given to one group alone
#' allowed <- rbind(c("status_quo", "status_quo"), c("scale", "status_quo"),
#'                  c("status_quo", "scale"), c("scale", "scale"))
#' voi_partition(list(a = g1, b = g2), p = c(0.6, 0.4), W = w_utilitarian(),
#'               differentiated = TRUE, profiles = allowed)
#' @export
voi_partition <- function(nb_list, p, W, differentiated = FALSE,
                          profiles = NULL, max_profiles = 1e5) {
  if (missing(p))
    stop_missing("p", "group shares are a choice of reporting unit.")
  if (missing(W))
    stop_missing("W", "the valuation rule, e.g. w_utilitarian().")
  check_rule(W)
  if (!is.logical(differentiated) || length(differentiated) != 1L ||
      is.na(differentiated))
    stop("`differentiated` must be TRUE or FALSE.", call. = FALSE)
  if (!is.null(profiles) && !differentiated)
    stop("`profiles` restricts the decision per group; it needs ",
         "differentiated = TRUE.", call. = FALSE)
  obj <- prepare_nb(nb_list, p)
  if (!is.null(profiles)) profiles <- resolve_profiles(profiles, obj, max_profiles)
  partition_core(obj, W, differentiated = differentiated, profiles = profiles,
                 max_profiles = max_profiles)
}

# The computation, on a prepared object. Kept separate so that fairness_screen()
# and baseline_pair() can run many rules without re-validating the data.
# `profiles` is NULL or an integer matrix from resolve_profiles().
partition_core <- function(obj, W, differentiated = FALSE, profiles = NULL,
                           max_profiles = 1e5, w_sd = welfare_matrix(obj, W)) {
  crit <- colMeans(w_sd)
  # An option whose value is undefined under W (NA) makes the choice undefined.
  d_star <- if (anyNA(crit)) NA_integer_ else which_max1(crit)
  A <- if (is.na(d_star)) NA_real_ else crit[[d_star]]
  C <- mean(apply(w_sd, 1L, max))
  best_in_draw <- max.col(w_sd, ties.method = "first")

  out <- list(
    EVPI = C - A, A = A, C = C,
    d_star = if (is.na(d_star)) NA_character_ else obj$options[d_star],
    p_ahead = if (is.na(d_star)) NA_real_ else mean(best_in_draw == d_star),
    criterion = stats::setNames(crit, obj$options),
    differentiated = differentiated,
    p = obj$p, n_draws = obj$S, n_options = obj$D, n_groups = obj$G,
    groups = obj$groups, options = obj$options)

  if (differentiated) {
    restricted <- !is.null(profiles)
    grid <- if (restricted) profiles else profile_grid(obj, max_profiles)
    # B: the planner's best allowed profile at today's information. With a
    # restriction, D is enumerated alongside: per draw, the best allowed profile.
    vals <- numeric(nrow(grid))
    best_in_draw_r <- rep(-Inf, obj$S)
    for (i in seq_len(nrow(grid))) {
      w_i <- welfare_post(obj, W, const_sel(obj, grid[i, ]))
      vals[i] <- mean(w_i)
      if (restricted) best_in_draw_r <- pmax(best_in_draw_r, w_i)
    }
    best <- if (anyNA(vals)) NA_integer_ else which_max1(vals)
    B <- if (is.na(best)) NA_real_ else vals[[best]]
    # D without restriction: per draw each group's own best option maximises
    # any rule that is non-decreasing in every group's value, so no
    # enumeration is needed.
    D <- if (restricted) mean(best_in_draw_r)
         else mean(welfare_post(obj, W, own_opt_sel(obj)))
    own_best <- apply(matrix(colMeans(obj$u), nrow = obj$D), 2L, which_max1)
    out <- c(out, list(
      B = B, D = D,
      VoH_static = B - A, EVPI_sub = D - B, VoH_dyn = D - C,
      planner_profile = if (is.na(best)) NULL else
        stats::setNames(obj$options[grid[best, ]], obj$groups),
      d_star_group = stats::setNames(obj$options[own_best], obj$groups),
      restricted = restricted, n_profiles = nrow(grid)))
  }
  class(out) <- c("voi_partition", "list")
  out
}

# Allowed profiles as an integer matrix: rows = profiles, columns = groups in
# the order of the prepared object, entries = option indices.
resolve_profiles <- function(profiles, obj, max_profiles) {
  if (is.data.frame(profiles)) profiles <- as.matrix(profiles)
  if (!is.matrix(profiles) || !(is.character(profiles) || is.numeric(profiles)) ||
      nrow(profiles) < 1L || ncol(profiles) != obj$G)
    stop("`profiles` must be a matrix with at least one row and one column ",
         "per group (", obj$G, " expected).", call. = FALSE)
  cn <- colnames(profiles)
  if (!is.null(cn)) {
    if (anyDuplicated(cn) || !setequal(cn, obj$groups))
      stop("The column names of `profiles` do not match the groups in ",
           "`nb_list`.", call. = FALSE)
    profiles <- profiles[, obj$groups, drop = FALSE]
  }
  if (nrow(profiles) > max_profiles)
    stop("`profiles` lists ", nrow(profiles), " profiles (limit ",
         "`max_profiles` = ", format(max_profiles), ").", call. = FALSE)
  idx <- if (is.character(profiles)) match(profiles, obj$options) else {
    v <- as.vector(profiles)
    ifelse(is.finite(v) & v == round(v), v, NA_real_)
  }
  idx <- matrix(as.integer(idx), nrow = nrow(profiles), ncol = obj$G,
                dimnames = list(NULL, obj$groups))
  if (anyNA(idx) || any(idx < 1L) || any(idx > obj$D))
    stop("Every entry of `profiles` must be an option name or an option ",
         "index of `nb_list`.", call. = FALSE)
  if (anyDuplicated(idx))
    stop("`profiles` lists the same profile more than once.", call. = FALSE)
  idx
}

#' Value-of-heterogeneity index
#'
#' `(B - A) / (C - A)`: the value of deciding per group at today's
#' information, as a share of the EVPI of one decision for all. Above 1:
#' deciding per group is worth more than perfect information about a decision
#' for all. Only defined for a [voi_partition()] with `differentiated = TRUE`,
#' i.e. when groups can actually receive different options.
#'
#' @param x A `voi_partition` object computed with `differentiated = TRUE`.
#' @param tol Denominators with `abs(C - A) <= tol` are treated as zero.
#' @return A single number, or `NA_real_` with attribute `"reason"` when there
#'   is no information value to normalise against.
#' @examples
#' set.seed(1)
#' g1 <- cbind(status_quo = 0, scale = rnorm(500, 10, 20))
#' g2 <- cbind(status_quo = 0, scale = rnorm(500, -3, 20))
#' voh_index(voi_partition(list(a = g1, b = g2), c(0.5, 0.5), w_utilitarian(),
#'                         differentiated = TRUE))
#' @export
voh_index <- function(x, tol = .Machine$double.eps^0.5) {
  if (!all(c("A", "B", "C") %in% names(x)))
    stop("`x` must carry A, B and C: a voi_partition() computed with ",
         "differentiated = TRUE.", call. = FALSE)
  denom <- x$C - x$A
  if (!is.finite(denom) || abs(denom) <= tol) {
    out <- NA_real_
    attr(out, "reason") <- if (!is.finite(denom))
      "C - A is not finite" else "C == A: no information value"
    return(out)
  }
  (x$B - x$A) / denom
}
