# Optional research-priority analysis with decisionSupport::multi_EVPI().
# Run after source('atacora_DA_axes.R'); may take several minutes.
# This answers a BINARY comparison, not the full five-option EVPI.
.libPaths(c("renv/library/macos/R-4.6/aarch64-apple-darwin23", .libPaths()))
value <- welfare_draws(nb(c("G", "H")), p, rules$utilitarian)
ranking <- order(colMeans(value), decreasing = TRUE)
best <- ranking[1L]
# Skip exact draw-by-draw duplicates of the best option when choosing its rival.
different <- vapply(ranking, function(d) any(value[, d] != value[, best]), logical(1))
if (!any(different)) stop("All options are identical; no decisive pair exists.")
rival <- ranking[different][1L]
comparison <- value[, best] - value[, rival]
pair <- colnames(value)[c(best, rival)]
mc_table <- data.frame(simulation_results$x, comparison = comparison)
partial_information <- decisionSupport::multi_EVPI(mc_table, first_out_var = "comparison")
# Coverage: draws in which an omitted option strictly exceeds BOTH selected options.
outside_pair <- mean(apply(value, 1L, max) > pmax(value[, best], value[, rival]))
print(list(pair = pair, outside_pair = outside_pair, partial_information = partial_information))
