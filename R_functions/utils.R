# Input checks only. The mathematical functions use ordinary lists of matrices;
# there is no second, internal model object and no selection-matrix machinery.

stop_missing <- function(name, hint) {
  stop("`", name, "` has no default: ", hint, call. = FALSE)
}

check_names <- function(x, what) {
  if (is.null(x) || anyNA(x) || any(!nzchar(x)) || anyDuplicated(x))
    stop(what, " must be non-empty and unique.", call. = FALSE)
}

check_rule <- function(W) {
  if (!is.function(W)) stop("`W` must be a valuation function(nb, p).", call. = FALSE)
}

check_rules <- function(rules) {
  if (!is.list(rules) || is.data.frame(rules) || !length(rules))
    stop("`rules` must be a non-empty list.", call. = FALSE)
  if (!all(vapply(rules, is.function, logical(1))))
    stop("Every element of `rules` must be a valuation function.", call. = FALSE)
  check_names(names(rules), "`rules` must be named; names")
}

check_scalar <- function(x, what, lower = -Inf) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < lower)
    stop(what, " must be a single finite number >= ", lower, ".", call. = FALSE)
}

# Keep input shape. Arrays are used only for explicitly requested multiple
# outcomes, never as an intermediate representation for a single outcome.
check_nb <- function(nb_list, multiple = FALSE) {
  if (!is.list(nb_list) || is.data.frame(nb_list) || !length(nb_list))
    stop("`nb_list` must be a non-empty list of numeric matrices.", call. = FALSE)
  valid <- vapply(nb_list, function(x)
    is.numeric(x) && is.array(x) && length(dim(x)) %in% c(2L, 3L) &&
      all(dim(x) > 0L), logical(1))
  if (!all(valid)) stop("Use numeric draws x options matrices or arrays.", call. = FALSE)
  if (any(vapply(nb_list, function(x) any(!is.finite(x)), logical(1))))
    stop("Net benefits must be finite; missing draws are not removed.", call. = FALSE)
  shape <- lapply(nb_list, function(x) if (is.matrix(x)) c(dim(x), 1L) else dim(x))
  if (!all(vapply(shape, identical, logical(1), shape[[1L]])))
    stop("All groups must have the same dimensions.", call. = FALSE)
  if (!multiple && shape[[1L]][3L] > 1L)
    stop("The functions value one outcome at a time.", call. = FALSE)
  groups <- names(nb_list)
  if (is.null(groups)) groups <- paste0("group_", seq_along(nb_list))
  check_names(groups, "Group names")
  common <- function(axis, fallback) {
    labels <- lapply(nb_list, function(x) if (axis <= length(dim(x))) dimnames(x)[[axis]])
    present <- Filter(Negate(is.null), labels)
    out <- if (length(present)) present[[1L]] else fallback
    if (!all(vapply(present, identical, logical(1), out)))
      stop(if (axis == 2L) "Column names (options) differ" else "Outcome names differ",
           " between groups.", call. = FALSE)
    check_names(out, "Dimension names")
    out
  }
  options <- common(2L, paste0("option_", seq_len(shape[[1L]][2L])))
  outcomes <- common(3L, if (shape[[1L]][3L] == 1L) "nb" else
    paste0("outcome_", seq_len(shape[[1L]][3L])))
  for (g in seq_along(nb_list)) {
    x <- nb_list[[g]]
    if (!multiple && !is.matrix(x)) x <- matrix(x, nrow = nrow(x))
    dimnames(x) <- if (is.matrix(x)) list(NULL, options) else list(NULL, options, outcomes)
    nb_list[[g]] <- x
  }
  stats::setNames(nb_list, groups)
}

resolve_p <- function(p, groups) {
  if (!is.numeric(p) || length(p) != length(groups))
    stop("`p` needs one share per group.", call. = FALSE)
  if (!is.null(names(p))) {
    check_names(names(p), "Names of `p`")
    if (!setequal(names(p), groups))
      stop("Names of `p` do not match the groups.", call. = FALSE)
    p <- p[groups]
  }
  if (any(!is.finite(p)) || any(p < 0))
    stop("`p` must be finite and non-negative.", call. = FALSE)
  if (!is.finite(sum(p)) || sum(p) <= 0)
    stop("`p` must have a finite positive sum.", call. = FALSE)
  stats::setNames(as.numeric(p) / sum(p), groups)
}

# Exact ties go to the first option.
# which.max is used directly here so the argmax in the equation is visible.
best_option <- function(value) {
  if (anyNA(value) || all(value == -Inf)) NA_integer_ else which.max(value)
}

code_names <- function(codes, what) {
  if (!is.character(codes) || !length(codes) || anyNA(codes) || any(!nzchar(codes)))
    stop("`", what, "` must be a non-empty character vector.", call. = FALSE)
  labels <- names(codes)
  if (is.null(labels)) labels <- codes
  empty <- is.na(labels) | !nzchar(labels)
  labels[empty] <- codes[empty]
  check_names(codes, paste(what, "codes"))
  check_names(labels, paste(what, "labels"))
  stats::setNames(codes, labels)
}
