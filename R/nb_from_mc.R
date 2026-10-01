# From Monte Carlo output to an nb_list. Base R only -- see FUNCTIONS.md.
#
# mcSimulation() returns one column per output variable. Every layer-1
# function takes an nb_list: one draws x options matrix (or draws x options x
# attributes array) per group. nb_from_mc() is the bridge between the two. It
# selects and arranges columns and does nothing else: combining outcomes,
# splitting a shared quantity and applying a rule are valuations and belong in
# the model function, where they can be read.

#' Select net benefits from Monte Carlo output into an nb_list
#'
#' Builds the `nb_list` that [voi_partition()], [fairness_screen()],
#' [marginalisation_count()], [baseline_pair()] and [reporting_units()] take,
#' from the flat output of `decisionSupport::mcSimulation()`. Column names are
#' generated from `pattern` by replacing the placeholders `{group}`,
#' `{option}` and, for several outcomes per group, `{attribute}` with the codes
#' in `groups`, `options` and `attributes`. The function selects columns; it
#' values nothing.
#'
#' @param mc The value of `mcSimulation()`, whose element `y` holds the model
#'   outputs, or a data frame (or matrix with column names) of model outputs,
#'   one row per draw.
#' @param pattern A single string with the placeholders `{group}` and
#'   `{option}`, and `{attribute}` if and only if `attributes` is given, e.g.
#'   `"nb_{group}_{option}"` or `"{attribute}_{group}_{option}"`.
#' @param groups Character vector of the codes that replace `{group}`. Its
#'   names become the group names of the result; an unnamed code names itself.
#' @param options Character vector of the codes that replace `{option}`, named
#'   in the same way. Their order is the option order of the result.
#' @param attributes `NULL` (one outcome per group), or a character vector of
#'   the codes that replace `{attribute}`, named in the same way.
#' @return A named list with one element per group: an `S x D` numeric matrix
#'   (draws x options) or, with `attributes`, an `S x D x K` numeric array
#'   built with [nb_array()]. Column names are the option names.
#' @examples
#' y <- data.frame(nb_a_x = rnorm(4), nb_a_y = rnorm(4),
#'                 nb_b_x = rnorm(4), nb_b_y = rnorm(4))
#' nb <- nb_from_mc(y, "nb_{group}_{option}",
#'                  groups = c(first = "a", second = "b"), options = c("x", "y"))
#' str(nb)
#' @export
nb_from_mc <- function(mc, pattern, groups, options, attributes = NULL) {
  if (missing(pattern))
    stop_missing("pattern", 'a column-name template, e.g. "nb_{group}_{option}".')
  if (missing(groups))
    stop_missing("groups", "the codes that replace {group} in the column names.")
  if (missing(options))
    stop_missing("options", "the codes that replace {option} in the column names.")

  y <- if (is.data.frame(mc) || is.matrix(mc)) mc else if (is.list(mc)) mc$y
  if (is.null(y) || !(is.data.frame(y) || is.matrix(y)) || is.null(colnames(y)))
    stop("`mc` must be the value of mcSimulation() (with element `y`) or a ",
         "data frame of model outputs with column names.", call. = FALSE)

  if (!is.character(pattern) || length(pattern) != 1L || is.na(pattern))
    stop("`pattern` must be a single string.", call. = FALSE)
  has <- function(ph) grepl(ph, pattern, fixed = TRUE)
  for (ph in c("{group}", "{option}"))
    if (!has(ph))
      stop("`pattern` must contain the placeholder ", ph, ".", call. = FALSE)
  if (is.null(attributes) && has("{attribute}"))
    stop("`pattern` contains {attribute}, but `attributes` is NULL.",
         call. = FALSE)
  if (!is.null(attributes) && !has("{attribute}"))
    stop("`attributes` is given, but `pattern` has no placeholder {attribute}.",
         call. = FALSE)

  groups <- code_names(groups, "groups")
  options <- code_names(options, "options")
  if (!is.null(attributes)) attributes <- code_names(attributes, "attributes")

  fill <- function(g, o, a) {
    s <- gsub("{group}", g, pattern, fixed = TRUE)
    s <- gsub("{option}", o, s, fixed = TRUE)
    if (!is.null(a)) s <- gsub("{attribute}", a, s, fixed = TRUE)
    s
  }
  a_codes <- if (is.null(attributes)) list(NULL) else as.list(attributes)
  wanted <- unlist(lapply(a_codes, function(a)
    unlist(lapply(groups, function(g)
      vapply(options, function(o) fill(g, o, a), character(1))))))
  if (anyDuplicated(wanted))
    stop("`pattern` and the codes generate the same column name more than ",
         "once, e.g. ", wanted[duplicated(wanted)][1L], ".", call. = FALSE)
  missing_cols <- setdiff(wanted, colnames(y))
  if (length(missing_cols))
    stop(length(missing_cols), " column(s) not found in the model output, ",
         "e.g. ", paste(utils::head(missing_cols, 5L), collapse = ", "), ".",
         call. = FALSE)
  numeric_ok <- vapply(wanted, function(cl) is.numeric(y[, cl]), logical(1))
  if (!all(numeric_ok))
    stop("Column(s) not numeric: ",
         paste(utils::head(wanted[!numeric_ok], 5L), collapse = ", "), ".",
         call. = FALSE)

  block <- function(g, a) {
    cols <- vapply(options, function(o) fill(g, o, a), character(1))
    m <- matrix(as.numeric(as.matrix(y[, cols, drop = FALSE])),
                nrow = nrow(y), ncol = length(cols))
    dimnames(m) <- list(NULL, names(options))
    m
  }
  out <- lapply(groups, function(g) {
    if (is.null(attributes)) return(block(g, NULL))
    nb_array(stats::setNames(lapply(attributes, function(a) block(g, a)),
                             names(attributes)))
  })
  stats::setNames(out, names(groups))
}

# Codes as a named character vector: names are the labels in the result,
# values the strings in the column names. Unnamed codes name themselves.
code_names <- function(codes, what) {
  if (!is.character(codes) || length(codes) == 0L || anyNA(codes) ||
      any(!nzchar(codes)))
    stop("`", what, "` must be a non-empty character vector of codes.",
         call. = FALSE)
  nm <- names(codes)
  if (is.null(nm)) nm <- codes
  nm[is.na(nm) | !nzchar(nm)] <- codes[is.na(nm) | !nzchar(nm)]
  if (anyDuplicated(nm) || anyDuplicated(codes))
    stop("The codes in `", what, "` and their names must be unique.",
         call. = FALSE)
  stats::setNames(codes, nm)
}
