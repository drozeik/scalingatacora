#' Value of information for one decision, optionally decisions per group
#'
#' A = max_d mean_s W(NB[d,s]); C = mean_s max_d W(NB[d,s]); EVPI = C - A.
#' With differentiated decisions, B and D replace options by allowed profiles.
#' W must be non-decreasing in each group for the unrestricted D shortcut.
#' @inheritParams welfare_draws
#' @param differentiated FALSE for one decision for all, TRUE for decisions per group.
#' @param profiles Optional matrix: rows are allowed profiles, columns are groups,
#'   entries are option names or integer indices. Requires differentiated = TRUE.
#' @param max_profiles Maximum number of profiles to enumerate, default 100000.
#' @return List of class voi_partition with A, C, EVPI, d_star, p_ahead, criterion
#'   and input labels. With differentiated = TRUE also B, D, VoH_static = B-A,
#'   EVPI_sub = D-B, VoH_dyn = D-C, planner_profile and d_star_group.
#'   NA rule values propagate. If all options are excluded, d_star is NA.
#'   Exact ties are resolved by the first option/profile in input order.
#' @examples
#' nb <- list(a = cbind(sq = 0, x = c(8, 2)), b = cbind(sq = 0, x = c(-2, 4)))
#' voi_partition(nb, c(1, 1), w_utilitarian())
#' voi_partition(nb, c(1, 1), w_maximin(), differentiated = TRUE)
#' @export
voi_partition <- function(nb_list, p, W, differentiated = FALSE,
                          profiles = NULL, max_profiles = 1e5) {
  if (missing(p)) stop_missing("p", "state the group shares.")
  if (missing(W)) stop_missing("W", "state the valuation rule.")
  nb_list <- check_nb(nb_list)
  p <- resolve_p(p, names(nb_list))
  if (!is.logical(differentiated) || length(differentiated) != 1L || is.na(differentiated))
    stop("`differentiated` must be TRUE or FALSE.", call. = FALSE)
  if (!is.null(profiles) && !differentiated)
    stop("`profiles` requires differentiated = TRUE.", call. = FALSE)

  value <- welfare_draws(nb_list, p, W)     # U[s,d] = W(NB(d,theta_s); p)
  out <- partition_values(value)           # columns -> A; rows -> C (see below)
  out <- c(out, list(differentiated = differentiated, p = p,
    n_draws = nrow(value), n_options = ncol(value), n_groups = length(nb_list),
    groups = names(nb_list), options = colnames(value)))

  if (differentiated) {
    grid <- profile_grid(nb_list, profiles, max_profiles)
    expected <- numeric(nrow(grid))
    best_draw <- rep(-Inf, nrow(value))
    for (r in seq_len(nrow(grid))) {
      # A profile assigns option grid[r,g] to group g, constant across draws.
      groups <- do.call(cbind, Map(function(x, d) x[, d], nb_list, grid[r, ]))
      profile_value <- rule_by_draw(groups, p, W)
      expected[r] <- mean(profile_value)  # E_theta W(NB_1(d_1), ..., NB_G(d_G))
      if (!is.null(profiles)) best_draw <- pmax(best_draw, profile_value)
    }
    best <- best_option(expected)
    B <- max(expected)                    # B = max_profile E_theta W
    if (is.null(profiles)) {
      # Each group can choose freely. For non-decreasing W, its componentwise
      # maximum also maximises W. This shortcut is invalid for restricted profiles.
      groups <- do.call(cbind, lapply(nb_list, function(x) apply(x, 1L, max)))
      best_draw <- rule_by_draw(groups, p, W)
    }
    D <- mean(best_draw)                  # D = E_theta max_profile W
    own_best <- vapply(nb_list, function(x) best_option(colMeans(x)), integer(1))
    out <- c(out, list(B = B, D = D,
      VoH_static = B - out$A, EVPI_sub = D - B, VoH_dyn = D - out$C,
      planner_profile = if (is.na(best)) NULL else
        stats::setNames(colnames(value)[grid[best, ]], names(nb_list)),
      d_star_group = stats::setNames(colnames(value)[own_best], names(nb_list)),
      restricted = !is.null(profiles), n_profiles = nrow(grid)))
  }
  class(out) <- c("voi_partition", "list")
  out
}

# Equations A1 (eq-value) and A4 (eq-voi), with no data conversion or valuation choices.
partition_values <- function(value) {
  criterion <- colMeans(value)            # V(d) = (1/S) sum_s U[s,d]
  d <- best_option(criterion)             # d* = argmax_d V(d)
  A <- max(criterion)                     # max AFTER averaging: today's choice
  C <- mean(apply(value, 1L, max))         # max BEFORE averaging: perfect information
  ahead <- apply(value, 1L, best_option)
  EVPI <- C - A                          # information changes the order of max and mean
  if (is.nan(EVPI)) EVPI <- NA_real_      # -Inf - (-Inf) has no defined value
  list(EVPI = EVPI, A = A, C = C, d_star = colnames(value)[d],
       p_ahead = if (is.na(d)) NA_real_ else mean(ahead == d), criterion = criterion)
}

# Profile validation kept away from A-D so the equations remain easy to read.
profile_grid <- function(nb_list, profiles, max_profiles) {
  check_scalar(max_profiles, "`max_profiles`", 1)
  groups <- names(nb_list)
  options <- colnames(nb_list[[1L]])
  n <- if (is.null(profiles)) length(options)^length(groups) else nrow(profiles)
  if (is.null(n)) stop("`profiles` must be a matrix.", call. = FALSE)
  if (n > max_profiles)
    stop("The decision per group would enumerate ", n,
         " profiles (limit `max_profiles` = ", max_profiles, ").", call. = FALSE)
  if (is.null(profiles))
    return(as.matrix(expand.grid(rep(list(seq_along(options)), length(groups)))))
  if (is.data.frame(profiles)) profiles <- as.matrix(profiles)
  if (!is.matrix(profiles) || nrow(profiles) < 1L || ncol(profiles) != length(groups))
    stop("`profiles` needs at least one row and one column per group.", call. = FALSE)
  if (!is.null(colnames(profiles))) {
    check_names(colnames(profiles), "Profile column names")
    if (!setequal(colnames(profiles), groups))
      stop("Profile column names do not match the groups.", call. = FALSE)
    profiles <- profiles[, groups, drop = FALSE]
  }
  if (is.character(profiles)) {
    index <- match(profiles, options)
  } else if (is.numeric(profiles)) {
    index <- as.vector(profiles)
  } else stop("Use an option name or an option index in each profile.", call. = FALSE)
  if (any(!is.finite(index)) || any(index != round(index)) ||
      any(index < 1L | index > length(options)))
    stop("Every profile entry must be an option name or an option index.", call. = FALSE)
  grid <- matrix(as.integer(index), nrow(profiles), dimnames = list(NULL, groups))
  if (anyDuplicated(grid)) stop("The same profile occurs more than once.", call. = FALSE)
  grid
}

#' Static heterogeneity value relative to joint information value
#' @param x Result of voi_partition(..., differentiated = TRUE).
#' @param tol Denominator tolerance, default sqrt(.Machine$double.eps).
#' @return (B-A)/(C-A), or NA with a reason attribute for a zero/non-finite denominator.
#' @examples
#' voh_index(list(A = 3, B = 4.5, C = 3.625))
#' @export
voh_index <- function(x, tol = .Machine$double.eps^0.5) {
  if (!all(c("A", "B", "C") %in% names(x)))
    stop("Use voi_partition(..., differentiated = TRUE).", call. = FALSE)
  check_scalar(tol, "`tol`", 0)
  denominator <- x$C - x$A
  if (!is.finite(denominator) || abs(denominator) <= tol)
    return(structure(NA_real_, reason = if (!is.finite(denominator))
      "C - A is not finite" else "C == A: no information value"))
  (x$B - x$A) / denominator                # static value / joint EVPI; can be above one
}
