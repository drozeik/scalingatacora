#' Evaluate the same decision against two reference states
#'
#' Axis 2: a net benefit is a difference, and the difference is taken against
#' a reference state the analyst chooses -- what people do today, say, or where
#' they say they want to be. `baseline_pair()` runs the same decision against
#' two reference states and reports, side by side, what changes: every
#' outcome of every group (and reporting unit), and the option every rule
#' recommends.
#'
#' Neither reference state is known to this function: both arrive in
#' `references` and are handed to `model`, which is the caller's.
#'
#' @param model A function of one argument. It receives one element of
#'   `references` and returns an `nb_list`: one `S x D` matrix or, for several
#'   outcomes, one `S x D x K` array ([nb_array()]) per group. Groups, options
#'   and outcomes must be the same for both references.
#' @param references A named list of two reference-state specifications, e.g.
#'   `list(behavioural = ..., preference = ...)`. The names label the output.
#' @param p Group shares, as in [voi_partition()]. No default.
#' @param rules Named list of valuation rules, as in [fairness_screen()]. No
#'   default. Each rule is applied to each outcome separately.
#' @param units `NULL`, or reporting units to add to the groups in
#'   `$outcomes`, as in [reporting_units()] (e.g. a household as the sum of
#'   its members). The rules always work on the groups.
#' @return An object of class `baseline_pair`, a list with
#'   \itemize{
#'     \item `outcomes`: one row per group or unit x outcome x option, with the
#'       mean and the share of draws above 0 under each reference, the
#'       difference of the means (second minus first reference), the option
#'       with the highest mean under each reference and `flip` (that option
#'       differs);
#'     \item `rules`: one row per rule x outcome x reference, with the
#'       recommended option, `p_ahead`, `EVPI` and `flip` (the rule recommends
#'       another option under the other reference).
#'   }
#' @examples
#' set.seed(1)
#' base <- list(a = cbind(sq = 0, scale = rnorm(500, 8, 15)),
#'              b = cbind(sq = 0, scale = rnorm(500, -2, 15)))
#' mk <- function(claim) lapply(base, function(m) { m[, "scale"] <- m[, "scale"] - claim; m })
#' baseline_pair(mk, references = list(today = 0, entitled = 6),
#'               p = c(0.5, 0.5), rules = list(util = w_utilitarian()))
#' @export
baseline_pair <- function(model, references, p, rules, units = NULL) {
  if (!is.function(model))
    stop("`model` must be a function of one reference-state argument.",
         call. = FALSE)
  if (missing(references))
    stop_missing("references", "a named list of the two reference states.")
  if (!is.list(references) || length(references) != 2L ||
      is.null(names(references)) || any(!nzchar(names(references))) ||
      anyDuplicated(names(references)))
    stop("`references` must be a named list of two reference states.",
         call. = FALSE)
  if (missing(p))
    stop_missing("p", "group shares are a choice of reporting unit.")
  if (missing(rules))
    stop_missing("rules", "a named list of valuation rules; the set is open.")
  check_rules(rules)

  refs <- names(references)
  nbs <- lapply(references, model)
  st <- lapply(nbs, nb_structure)
  if (!identical(st[[1]]$groups, st[[2]]$groups) ||
      !identical(st[[1]]$options, st[[2]]$options) ||
      !identical(st[[1]]$outcomes, st[[2]]$outcomes) ||
      st[[1]]$S != st[[2]]$S)
    stop("`model` returned different groups, options, outcomes or draws for ",
         "the two reference states; the two runs must be comparable.",
         call. = FALSE)
  s1 <- st[[1]]
  resolve_p(p, s1$groups)                                  # validate once

  # the groups and units whose outcomes are reported
  shown <- lapply(nbs, function(nb) {
    arrs <- nb_structure(nb)$arrs
    if (is.null(units)) arrs else c(arrs, reporting_units(arrs, units))
  })
  who <- names(shown[[1]])
  if (anyDuplicated(who))
    stop("The names of `units` must differ from the group names.", call. = FALSE)

  rows <- list()
  for (g in who) for (k in seq_len(s1$K)) {
    m1 <- matrix(shown[[1]][[g]][, , k], nrow = s1$S)
    m2 <- matrix(shown[[2]][[g]][, , k], nrow = s1$S)
    mean1 <- colMeans(m1); mean2 <- colMeans(m2)
    best1 <- s1$options[which_max1(mean1)]; best2 <- s1$options[which_max1(mean2)]
    d <- data.frame(unit = g, outcome = s1$outcomes[k], option = s1$options,
                    mean1, mean2, colMeans(m1 > 0), colMeans(m2 > 0),
                    difference = mean2 - mean1, best1, best2,
                    flip = !identical(best1, best2),
                    row.names = NULL, stringsAsFactors = FALSE)
    names(d)[4:7] <- c(paste0("mean_", refs), paste0("p_positive_", refs))
    names(d)[9:10] <- paste0("recommended_", refs)
    rows[[length(rows) + 1L]] <- d
  }
  outcomes <- do.call(rbind, rows)

  rule_rows <- list()
  for (k in seq_len(s1$K)) {
    objs <- lapply(nbs, function(nb) prepare_nb(lapply(nb_structure(nb)$arrs, function(a)
      matrix(a[, , k], nrow = s1$S, dimnames = list(NULL, s1$options))), p))
    for (r in names(rules)) {
      parts <- lapply(objs, partition_core, W = rules[[r]])
      opt <- vapply(parts, function(x) x$d_star, character(1))
      rule_rows[[length(rule_rows) + 1L]] <- data.frame(
        rule = r, outcome = s1$outcomes[k], reference = refs, option = opt,
        p_ahead = vapply(parts, function(x) x$p_ahead, numeric(1)),
        EVPI = vapply(parts, function(x) x$EVPI, numeric(1)),
        flip = !identical(opt[[1]], opt[[2]]),
        row.names = NULL, stringsAsFactors = FALSE)
    }
  }

  out <- list(outcomes = outcomes, rules = do.call(rbind, rule_rows),
              references = refs, groups = s1$groups, units = who,
              options = s1$options, outcomes_measured = s1$outcomes)
  class(out) <- c("baseline_pair", "list")
  out
}
