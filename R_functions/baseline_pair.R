#' Compare two explicit reference conditions
#' @param model Function(reference) returning the already computed net benefits
#'   against that reference: a list of matrices or outcome arrays. It is called
#'   exactly twice. Matching row order must refer to the same simulation draws.
#' @param references Named list of exactly two reference specifications.
#' @param p Group shares; no default.
#' @param rules Named list of valuation functions(nb, p); no default.
#' @param units Optional reporting units to add to the outcomes table. These do
#'   not change the groups on which the valuation rules operate.
#' @return Class baseline_pair with outcomes (means, gain shares, mean differences,
#'   preferred options and flips), rules (choice, EVPI, p_ahead and flip per
#'   reference/rule/outcome), and reference/group/option/outcome labels.
#' @examples
#' model <- function(claim) list(a = cbind(sq = 0, x = c(8, 2) - claim))
#' baseline_pair(model, list(today = 0, claim = 6), 1, list(util = w_utilitarian()))
#' @export
baseline_pair <- function(model, references, p, rules, units = NULL) {
  if (!is.function(model)) stop("`model` must be a function of one reference.", call. = FALSE)
  if (missing(references)) stop_missing("references", "state two reference conditions.")
  if (missing(p)) stop_missing("p", "state the group shares.")
  if (missing(rules)) stop_missing("rules", "state the valuation rules.")
  if (!is.list(references) || length(references) != 2L || is.null(names(references)))
    stop("`references` must be a named list of two reference states.", call. = FALSE)
  check_names(names(references), "Reference names")
  check_rules(rules)
  data <- lapply(references, function(r) as_outcome_arrays(check_nb(model(r), multiple = TRUE)))
  same <- identical(names(data[[1L]]), names(data[[2L]])) &&
    identical(lapply(data[[1L]], dim), lapply(data[[2L]], dim)) &&
    identical(lapply(data[[1L]], dimnames), lapply(data[[2L]], dimnames))
  if (!same) stop("The model returned different groups, options, outcomes or draws.", call. = FALSE)
  p <- resolve_p(p, names(data[[1L]]))
  shown <- lapply(data, function(x) if (is.null(units)) x else c(x, reporting_units(x, units)))
  if (anyDuplicated(names(shown[[1L]])))
    stop("Unit names must differ from group names.", call. = FALSE)
  refs <- names(references)
  outcomes <- dimnames(data[[1L]][[1L]])[[3L]]
  options <- colnames(data[[1L]][[1L]])
  # Select one outcome k without ever summing across outcomes.
  slice <- function(x, k) lapply(x, function(a)
    matrix(a[, , k], nrow(a), dimnames = list(NULL, options)))
  outcome_rows <- rule_rows <- list()
  for (k in seq_along(outcomes)) {
    pair <- lapply(shown, slice, k = k)
    for (g in names(pair[[1L]])) {
      x <- pair[[1L]][[g]]
      y <- pair[[2L]][[g]]
      mean1 <- colMeans(x)
      mean2 <- colMeans(y)
      best1 <- options[which.max(mean1)]
      best2 <- options[which.max(mean2)]
      row <- data.frame(unit = g, outcome = outcomes[k], option = options,
        mean1, mean2, colMeans(x > 0), colMeans(y > 0),
        difference = mean2 - mean1, best1, best2, flip = best1 != best2, row.names = NULL)
      names(row)[4:7] <- c(paste0("mean_", refs), paste0("p_positive_", refs))
      names(row)[9:10] <- paste0("recommended_", refs)
      outcome_rows[[length(outcome_rows) + 1L]] <- row
    }
    pair <- lapply(data, slice, k = k)     # rules still use the original groups
    for (r in names(rules)) {
      parts <- lapply(pair, voi_partition, p = p, W = rules[[r]])
      best <- vapply(parts, function(x) x$d_star, character(1))
      rule_rows[[length(rule_rows) + 1L]] <- data.frame(rule = r, outcome = outcomes[k],
        reference = refs, option = best,
        p_ahead = vapply(parts, function(x) x$p_ahead, numeric(1)),
        EVPI = vapply(parts, function(x) x$EVPI, numeric(1)),
        flip = if (anyNA(best)) NA else best[1L] != best[2L], row.names = NULL)
    }
  }
  # Group-major order: all rows of one reporting unit together.
  table <- do.call(rbind, outcome_rows)
  table <- table[order(match(table$unit, names(shown[[1L]])),
                       match(table$outcome, outcomes), match(table$option, options)), ]
  rownames(table) <- NULL
  structure(list(outcomes = table, rules = do.call(rbind, rule_rows), references = refs,
    groups = names(data[[1L]]), units = names(shown[[1L]]), options = options,
    outcomes_measured = outcomes), class = c("baseline_pair", "list"))
}
