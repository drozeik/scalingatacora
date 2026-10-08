#' Read group and option matrices directly from a Monte Carlo result
#'
#' This selects columns; it never combines or values outcomes.
#' @param mc mcSimulation result, or a data frame/matrix of its output columns.
#' @param pattern Column template containing {group} and {option}, e.g.
#'   "NB_{group}_{option}_V1". Add {attribute} only when attributes is supplied.
#' @param groups Character group codes. Optional names label the result.
#' @param options Character option codes, in the desired order. Optional names label columns.
#' @param attributes NULL for one outcome; otherwise named character outcome codes.
#' @return Named list of draws x options matrices; with attributes, draws x
#'   options x outcomes arrays. Missing/duplicated columns cause an error.
#' @examples
#' y <- data.frame(NB_a_x = c(3, 4), NB_a_y = c(1, 2))
#' nb_from_mc(y, "NB_{group}_{option}", groups = "a", options = c("x", "y"))
#' @export
nb_from_mc <- function(mc, pattern, groups, options, attributes = NULL) {
  if (missing(pattern)) stop_missing("pattern", "state the column template.")
  if (missing(groups)) stop_missing("groups", "state the group codes.")
  if (missing(options)) stop_missing("options", "state the option codes.")
  y <- if (is.data.frame(mc) || is.matrix(mc)) mc else if (is.list(mc)) mc$y
  if (!(is.data.frame(y) || is.matrix(y)) || is.null(colnames(y)))
    stop("`mc` must have element `y` or be an output table with column names.", call. = FALSE)
  check_names(colnames(y), "Output column names")
  if (!is.character(pattern) || length(pattern) != 1L || is.na(pattern))
    stop("`pattern` must be a single string.", call. = FALSE)
  for (placeholder in c("{group}", "{option}"))
    if (!grepl(placeholder, pattern, fixed = TRUE))
      stop("Missing placeholder ", placeholder, ".", call. = FALSE)
  if (grepl("{attribute}", pattern, fixed = TRUE) && is.null(attributes))
    stop("Pattern contains {attribute}, but `attributes` is NULL.", call. = FALSE)
  if (!grepl("{attribute}", pattern, fixed = TRUE) && !is.null(attributes))
    stop("`attributes` is given, but the pattern has no placeholder {attribute}.", call. = FALSE)
  groups <- code_names(groups, "groups")
  options <- code_names(options, "options")
  if (!is.null(attributes)) attributes <- code_names(attributes, "attributes")
  column_names <- function(g, a = NULL) {
    template <- gsub("{group}", g, pattern, fixed = TRUE)
    if (!is.null(a)) template <- gsub("{attribute}", a, template, fixed = TRUE)
    vapply(options, function(o) gsub("{option}", o, template, fixed = TRUE), character(1))
  }
  outcome_codes <- if (is.null(attributes)) list(NULL) else as.list(attributes)
  wanted <- unlist(lapply(groups, function(g) lapply(outcome_codes, function(a) column_names(g, a))))
  if (anyDuplicated(wanted)) stop("The pattern generates the same column name more than once.", call. = FALSE)
  missing <- setdiff(wanted, colnames(y))
  if (length(missing)) stop("Columns not found: ", paste(missing, collapse = ", "), call. = FALSE)
  numeric <- vapply(wanted, function(k) is.numeric(y[, k]), logical(1))
  if (!all(numeric)) stop("Columns not numeric: ", paste(wanted[!numeric], collapse = ", "), call. = FALSE)
  block <- function(g, a = NULL) {
    x <- as.matrix(y[, column_names(g, a), drop = FALSE])
    dimnames(x) <- list(NULL, names(options))
    x
  }
  out <- lapply(groups, function(g) {
    if (is.null(attributes)) return(block(g))
    nb_array(lapply(attributes, function(a) block(g, a)))
  })
  check_nb(out, multiple = !is.null(attributes))
}
