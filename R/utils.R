# Internal core. Base R only -- see FUNCTIONS.md, design rules.
#
# Nothing in this file (or anywhere in layer 1) names a group, an option, an
# outcome or a rule. Every such name arrives through the data or through an
# argument. tests/testthat/test-generality.R enforces this.
#
# Internal representation
# -----------------------
# prepare_nb() turns the user-facing `nb_list` into one object:
#
#   u     S x D x G   net benefit per draw, option and group (one outcome)
#   p     G           group shares, normalised to sum 1
#
# Every quantity is then a statement about a *selection*: an S x G matrix
# saying which option each group gets in each draw. One decision for all is
# the selection with the same option in every cell.
#
# Only ex post: a rule is applied inside every draw and then averaged,
# E_theta W(NB). Only the planner reading of decisions per group (B, D).
# Both are explained in FUNCTIONS.md (design rule 4; value of information).

# ---- argument checks -------------------------------------------------------

stop_missing <- function(name, hint) {
  stop("`", name, "` has no default and must be given explicitly: ", hint,
       call. = FALSE)
}

check_rule <- function(W, name = "W") {
  if (!is.function(W))
    stop("`", name, "` must be a valuation rule: a function(nb, p) returning ",
         "one number, e.g. w_utilitarian().", call. = FALSE)
  invisible(W)
}

check_rules <- function(rules) {
  if (!is.list(rules) || length(rules) == 0L)
    stop("`rules` must be a non-empty list of valuation rules.", call. = FALSE)
  if (!all(vapply(rules, is.function, logical(1))))
    stop("Every element of `rules` must be a valuation function.", call. = FALSE)
  if (is.null(names(rules)) || any(!nzchar(names(rules))) ||
      anyDuplicated(names(rules)))
    stop("`rules` must be named, uniquely: the names label the output.",
         call. = FALSE)
  invisible(rules)
}

#' Index of the maximum, first one wins, NA-safe
#' @keywords internal
which_max1 <- function(x) {
  if (all(is.na(x))) return(NA_integer_)
  which.max(x)[1L]
}

# ---- structure of nb_list --------------------------------------------------

#' Validate the shape of an nb_list without valuing anything
#'
#' Accepts a named list whose elements are `S x D` numeric matrices or
#' `S x D x K` numeric arrays (K outcomes, see [nb_array()]). Matrices are
#' promoted to arrays with one outcome.
#'
#' @return A list with the promoted arrays and the dimension names.
#' @keywords internal
nb_structure <- function(nb_list) {
  if (!is.list(nb_list) || is.data.frame(nb_list) || length(nb_list) == 0L)
    stop("`nb_list` must be a non-empty list of matrices or arrays.",
         call. = FALSE)
  shape_ok <- vapply(nb_list, function(m)
    is.numeric(m) && is.array(m) && length(dim(m)) %in% c(2L, 3L), logical(1))
  if (!all(shape_ok))
    stop("Every element of `nb_list` must be a numeric draws x options matrix ",
         "or a draws x options x outcomes array.", call. = FALSE)

  was_matrix <- vapply(nb_list, is.matrix, logical(1))
  arrs <- lapply(nb_list, function(m) {
    if (is.matrix(m)) {
      array(m, dim = c(dim(m), 1L), dimnames = list(NULL, colnames(m), NULL))
    } else {
      m
    }
  })

  dims <- matrix(vapply(arrs, dim, integer(3)), nrow = 3L)
  if (any(dims != dims[, 1L]))
    stop("All elements of `nb_list` must have the same dimensions ",
         "(draws x options x outcomes).", call. = FALSE)
  nS <- dims[1L, 1L]; nD <- dims[2L, 1L]; nK <- dims[3L, 1L]
  if (nS < 1L || nD < 1L || nK < 1L)
    stop("`nb_list` needs at least one draw, one option and one outcome.",
         call. = FALSE)

  groups <- names(nb_list)
  if (is.null(groups)) groups <- paste0("group_", seq_along(arrs))
  if (any(is.na(groups)) || any(!nzchar(groups)) || anyDuplicated(groups))
    stop("The names of `nb_list` (the groups) must be non-empty and unique.",
         call. = FALSE)

  options <- common_names(lapply(arrs, function(a) dimnames(a)[[2L]]),
                          paste0("option_", seq_len(nD)),
                          "Column names (options)")
  outcomes <- common_names(lapply(arrs, function(a) dimnames(a)[[3L]]),
                           if (nK == 1L) "nb" else paste0("outcome_", seq_len(nK)),
                           "Outcome names")

  list(arrs = arrs, S = nS, D = nD, G = length(arrs), K = nK, groups = groups,
       options = options, outcomes = outcomes, was_matrix = all(was_matrix))
}

common_names <- function(name_list, default, what) {
  present <- Filter(Negate(is.null), name_list)
  nm <- if (length(present)) present[[1L]] else default
  for (x in present)
    if (!identical(x, nm))
      stop(what, " differ between groups; they must be identical and in the ",
           "same order in every element of `nb_list`.", call. = FALSE)
  if (any(!nzchar(nm)) || anyDuplicated(nm))
    stop(what, " must be non-empty and unique.", call. = FALSE)
  nm
}

# ---- group shares -----------------------------------------------------------

resolve_p <- function(p, groups) {
  nG <- length(groups)
  if (!is.numeric(p) || length(p) != nG)
    stop("`p` must be a numeric vector with one share per group (", nG,
         " expected).", call. = FALSE)
  if (!is.null(names(p)) && all(nzchar(names(p)))) {
    if (!setequal(names(p), groups) || anyDuplicated(names(p)))
      stop("The names of `p` do not match the groups in `nb_list`.",
           call. = FALSE)
    p <- p[groups]
  }
  if (any(!is.finite(p)) || any(p < 0))
    stop("`p` must be finite and non-negative.", call. = FALSE)
  if (sum(p) <= 0) stop("`p` must not sum to zero.", call. = FALSE)
  stats::setNames(as.numeric(p) / sum(p), groups)
}

# ---- the prepared object ----------------------------------------------------

#' Validate and normalise the inputs shared by the layer-1 functions
#'
#' @param nb_list Named list of `S x D` matrices (or `S x D x 1` arrays): one
#'   outcome per call.
#' @param p Group shares; normalised, aligned by name if named.
#' @return An internal object; see the header of this file.
#' @keywords internal
prepare_nb <- function(nb_list, p) {
  st <- nb_structure(nb_list)
  if (st$K > 1L)
    stop("`nb_list` carries ", st$K, " outcomes (",
         paste(st$outcomes, collapse = ", "), "). The functions value one ",
         "outcome at a time: select it with nb_from_mc(), or use ",
         "baseline_pair(), which reports every outcome.", call. = FALSE)
  p <- resolve_p(p, st$groups)
  u <- array(NA_real_, dim = c(st$S, st$D, st$G),
             dimnames = list(NULL, st$options, st$groups))
  for (g in seq_len(st$G)) u[, , g] <- st$arrs[[g]][, , 1L]
  list(u = u, p = p, S = st$S, D = st$D, G = st$G,
       groups = st$groups, options = st$options)
}

# ---- selections --------------------------------------------------------------
# A selection is an S x G integer matrix: the option each group gets per draw.

const_sel <- function(obj, profile) {
  matrix(as.integer(profile), nrow = obj$S, ncol = obj$G, byrow = TRUE)
}

# Each group's own best option in each draw (perfect information).
own_opt_sel <- function(obj) {
  matrix(vapply(seq_len(obj$G), function(g)
    max.col(matrix(obj$u[, , g], nrow = obj$S), ties.method = "first"),
    integer(obj$S)), nrow = obj$S, ncol = obj$G)
}

select_u <- function(obj, sel) {
  idx <- cbind(rep(seq_len(obj$S), times = obj$G), as.vector(sel),
               rep(seq_len(obj$G), each = obj$S))
  matrix(obj$u[idx], nrow = obj$S, ncol = obj$G,
         dimnames = list(NULL, obj$groups))
}

# ---- evaluating a rule --------------------------------------------------------

# W applied inside each draw: the S-vector of values of one selection.
welfare_post <- function(obj, W, sel) {
  us <- select_u(obj, sel)
  vapply(seq_len(obj$S), function(s)
    W(stats::setNames(us[s, ], obj$groups), obj$p), numeric(1))
}

# The S x D matrix of W for one decision for all: column d gives every group d.
welfare_matrix <- function(obj, W) {
  w_sd <- matrix(NA_real_, nrow = obj$S, ncol = obj$D,
                 dimnames = list(NULL, obj$options))
  for (d in seq_len(obj$D)) w_sd[, d] <- welfare_post(obj, W, const_sel(obj, d))
  w_sd
}

# Per draw, does option d leave a group below zero, and does the aggregate
# (the rule itself) show a gain at the same time?
loss_shares <- function(obj, W, d, w_sd = NULL) {
  below <- matrix(obj$u[, d, ] < 0, nrow = obj$S, ncol = obj$G,
                  dimnames = list(NULL, obj$groups))
  gain <- if (is.null(w_sd)) welfare_post(obj, W, const_sel(obj, d)) > 0
          else w_sd[, d] > 0
  list(any_loss = mean(rowSums(below) > 0),
       hidden_loss = mean(gain & rowSums(below) > 0),
       hidden_loss_by_group = colMeans(gain & below))
}

profile_grid <- function(obj, max_profiles) {
  n_prof <- obj$D^obj$G
  if (n_prof > max_profiles)
    stop("A decision per group would enumerate ", n_prof, " profiles of ",
         "options (limit `max_profiles` = ", format(max_profiles), ").",
         call. = FALSE)
  as.matrix(expand.grid(rep(list(seq_len(obj$D)), obj$G)))
}
