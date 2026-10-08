# Executable companion to FUNCTIONS.md. Run from the project root.
# These are invented teaching data, not Atacora observations.
source("load.R")
nb <- list(women = cbind(d0 = 0, dX = c(10, 8, 6, 0), dY = c(1, 2, 1, 2)),
           men = cbind(d0 = 0, dX = c(2, 0, -4, 2), dY = c(4, 2, 3, 3)))
p <- c(women = 0.5, men = 0.5)
W <- w_utilitarian()

# 1-2. W acts within a draw; only then do we average across draws.
groups_dX <- cbind(women = nb$women[, "dX"], men = nb$men[, "dX"])
value <- welfare_draws(nb, p, W)
print(value)
print(colMeans(value))
stopifnot(nb$men[3, "dX"] == -4,
          identical(unname(value[, "dX"]), c(6, 4, 1, 1)),
          identical(unname(colMeans(value)), c(0, 3, 2.25)),
          mean(apply(groups_dX, 1, min)) == -0.5,
          min(colMeans(groups_dX)) == 0)

# 3. Valuation choices, kept separate from the data.
loss_twice <- function(z) ifelse(z < 0, 2 * z, z)
rules <- list(utilitarian = W, maximin = w_maximin(),
              prioritarian = w_prioritarian(loss_twice))
stopifnot(W(c(6, -4), p) == 1,
          rules$maximin(c(6, -4), p) == -4,
          rules$prioritarian(c(6, -4), p) == -1,
          abs(w_atkinson(1, 10)(c(6, -4), p) - (sqrt(96) - 10)) < 1e-12,
          w_constrained()(c(6, -4), p) == -Inf)

# 4-5. A/C permit one option for all; B/D permit an option per group.
joint <- voi_partition(nb, p, W)
split <- voi_partition(nb, p, W, differentiated = TRUE)
allowed <- rbind(c("d0", "d0"), c("dX", "dX"), c("dY", "dY"),
                 c("dX", "d0"), c("d0", "dX"))
colnames(allowed) <- names(nb)
restricted <- voi_partition(nb, p, W, differentiated = TRUE, profiles = allowed)
print(split)
stopifnot(joint$d_star == "dX", joint$p_ahead == 0.5,
          joint$A == 3, joint$C == 3.625, joint$EVPI == 0.625,
          split$B == 4.5, split$D == 4.75,
          split$VoH_static == 1.5, split$EVPI_sub == 0.25, split$VoH_dyn == 1.125,
          voh_index(split) == 2.4, restricted$B == 3, restricted$D == 3.875)

# 6. A loss is hidden only when W is positive in that same draw.
hidden <- marginalisation_count(nb, p, W, d_star = "dX")
screen <- fairness_screen(nb, p, rules)
print(screen$table)
stopifnot(hidden$share == 0.25,
          identical(hidden$by_group$share, c(0, 0.25)),
          identical(screen$table$option, c("dX", "dY", "dX")),
          identical(screen$table$EVPI, c(0.625, 0.25, 1.125)),
          identical(screen$table$p_hidden_loss, c(0.25, 0, 0)),
          identical(screen$table$p_group_loses, c(0.25, 0, 0.25)))

# 7. Coefficients are not normalised; hours and money are not added.
units <- reporting_units(nb, list(total = c(women = 1, men = 1)))
summary <- nb_summary(nb)
hours <- cbind(d0 = 0, dX = c(2, 3, 1, 0), dY = c(1, 1, 1, 1))
measured <- nb_array(money = nb$women, hours = hours)
print(summary)
stopifnot(mean(units$total[, "dX"]) == 6,
          all(summary$EVPI[summary$unit == "women"] == 0.5),
          all(summary$EVPI[summary$unit == "men"] == 0),
          measured[3, "dX", "money"] == 6, measured[3, "dX", "hours"] == 1)

# 8. Supply both already evaluated reference conditions explicitly.
example_model <- function(adjustment) {
  result <- nb
  result$women[, "dX"] <- result$women[, "dX"] - adjustment
  result
}
pair <- baseline_pair(example_model, list(first = 0, second = 3), p,
                      list(utilitarian = W))
print(pair$rules)
stopifnot(identical(pair$rules$option, c("dX", "dY")), all(pair$rules$flip))

# 9. Scale only the examined option; the rival keeps its full effect.
fidelity <- fidelity_threshold(nb, p, W)
print(fidelity)
stopifnot(abs(fidelity$f_star[fidelity$option == "dX"] - 0.75) < 1e-9,
          is.na(fidelity$f_star[fidelity$option == "dY"]))

# 10. Recreate a small mcSimulation-style output to check column selection.
y <- data.frame(NB_women_d0 = nb$women[, "d0"], NB_women_dX = nb$women[, "dX"],
                NB_women_dY = nb$women[, "dY"], NB_men_d0 = nb$men[, "d0"],
                NB_men_dX = nb$men[, "dX"], NB_men_dY = nb$men[, "dY"])
from_mc <- nb_from_mc(list(y = y), "NB_{group}_{option}",
                      groups = names(nb), options = colnames(nb$women))
stopifnot(identical(nb, from_mc))

# 11. The option set is part of an EVPI statement.
only_X <- lapply(nb, function(x) x[, c("d0", "dX"), drop = FALSE])
stopifnot(voi_partition(only_X, p, W)$EVPI == 0, joint$EVPI == 0.625)
cat("All worked-example checks passed.\n")
