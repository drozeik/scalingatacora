# Run from the project root. Four invented draws, not Atacora data.
source("load.R")
mc <- list(y = data.frame(
  NB_women_d0 = 0, NB_women_dX = c(10, 8, 6, 0), NB_women_dY = c(1, 2, 1, 2),
  NB_men_d0 = 0, NB_men_dX = c(2, 0, -4, 2), NB_men_dY = c(4, 2, 3, 3)))
nb <- nb_from_mc(mc, "NB_{group}_{option}",
                 groups = c("women", "men"), options = c("d0", "dX", "dY"))
p <- c(women = 0.5, men = 0.5)
rules <- list(utilitarian = w_utilitarian(), maximin = w_maximin(),
  prioritarian = w_prioritarian(function(z) ifelse(z < 0, 2 * z, z)),
  atkinson_1 = w_atkinson(eps = 1, offset = 10),
  atkinson_2 = w_atkinson(eps = 2, offset = 10))

print(nb_summary(nb))
print(welfare_draws(nb, p, W = rules$utilitarian))
units <- reporting_units(nb, units = list(total = c(women = 1, men = 1)))
print(nb_summary(units))
joint <- voi_partition(nb, p, W = rules$utilitarian)
print(joint)
split <- voi_partition(nb, p, W = rules$utilitarian, differentiated = TRUE)
print(split)
print(voh_index(split))
print(marginalisation_count(nb, p, W = rules$utilitarian))
print(fairness_screen(nb, p, rules))
print(welfare_draws(nb, p, W = w_constrained(min_group_nb = 0)))
print(fidelity_threshold(nb, p, W = rules$utilitarian))

reference_model <- function(adjustment) {
  result <- nb
  result$women[, "dX"] <- result$women[, "dX"] - adjustment
  result
}
references <- baseline_pair(reference_model,
  references = list(first = 0, second = 3), p = p,
  rules = list(utilitarian = rules$utilitarian))
print(references)
measured <- nb_array(money = nb$women,
  hours = cbind(d0 = 0, dX = c(2, 3, 1, 0), dY = c(1, 1, 1, 1)))
print(measured)
