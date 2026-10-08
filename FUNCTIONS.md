# Valuation functions for decisionSupport

Deutsche Fassung: [FUNCTIONS.de.md](FUNCTIONS.de.md)

These 16 functions show how the result of a decision analysis depends on choices that data cannot settle: which effects count, what outcomes are compared with, for whom a number is reported, how groups are weighed against each other, and whose decision new information would serve.
All they need is the result of a Monte Carlo simulation, for example from `decisionSupport::mcSimulation()`, with one output column per group and option.
What you get are small tables: which option is ahead under the chosen valuation, who loses, and what further information would be worth.

<span id="questions"></span>
## Which function answers which question?

| Question | Function | What you get |
|---|---|---|
| How do I get from the simulation to groups and options? | [`nb_from_mc()`](#ref-nb-from-mc) | one table per group: draws × options |
| What does each option bring each group, and how often does a group lose? | [`nb_summary()`](#ref-nb-summary) | mean, shares of gains and losses, the group's own best option |
| How do I report for a household, or for all women together? | [`reporting_units()`](#ref-reporting-units) | new reporting units built from groups |
| How do I keep money and hours apart? | [`nb_array()`](#ref-nb-array) | one object with separate outcomes |
| May one group's gains offset another group's losses? | [`w_utilitarian()`](#ref-w-utilitarian) | rule: weighted mean |
| Should only the worst-off group count? | [`w_maximin()`](#ref-w-maximin) | rule: smallest group value |
| Should losses count more than gains? | [`w_prioritarian()`](#ref-w-prioritarian) | rule with a chosen weight on losses |
| How much should inequality between groups count? | [`w_atkinson()`](#ref-w-atkinson) | rule with a chosen inequality aversion |
| May a group fall below a limit? | [`w_constrained()`](#ref-w-constrained) | rule that excludes such options |
| What does the rule give in each single draw? | [`welfare_draws()`](#ref-welfare-draws) | rule values: draws × options |
| Which option is best on average, and what would information be worth? | [`voi_partition()`](#ref-voi-partition) | best option, EVPI, value of differentiated decisions |
| Do differentiated decisions bring more than information? | [`voh_index()`](#ref-voh-index) | a ratio |
| Who loses although the overall result is positive? | [`marginalisation_count()`](#ref-marginalisation-count) | share of hidden losses, overall and per group |
| Does the best option change if I weigh differently? | [`fairness_screen()`](#ref-fairness-screen) | one row per rule |
| Does the result change if I compare with something else? | [`baseline_pair()`](#ref-baseline-pair) | both references side by side |
| How much of the effect has to arrive? | [`fidelity_threshold()`](#ref-fidelity-threshold) | smallest sufficient share per option |

The functions show how a result depends on a choice.
They do not say which rule is right.

<span id="glossary"></span>
## Words used here

| Word | Meaning |
|---|---|
| Draw | one possible world from the simulation; one row in the code. |
| Option | one of the courses of action; one column in the code. |
| Group | whose outcome is kept separate, for example women or households. |
| Net benefit | the outcome with the option minus the outcome in the reference. |
| Reference condition | what outcomes are compared with, for example today's situation. |
| System boundary | which effects and whose accounts count. |
| Group shares | how strongly each group enters a joint judgement; `p` in the code. |
| Rule (fairness criterion) | how the group values of one draw become one number; `W` in the code. |
| Rule value | that one number for one draw and one option. |
| Expected value | the mean over all draws. |
| Value of information, EVPI | what it would bring on average to know, before deciding, which draw will occur. |
| Differentiated decisions, profile | each group may receive a different option; a profile is one such assignment. |
| Actor-differentiated value of information | whose decision new information serves: EVPI per group or for differentiated decisions. |
| Reporting unit | for whom a number is reported: a person, a household, all women together. |
| Hidden loss | the joint number is positive, but a group loses. |
| Floor | a value below which no group may fall. |
| Fidelity | which share of the planned effect actually arrives. |

<span id="functions"></span>
## Function reference

Each entry follows the layout of the decisionSupport help pages: description, usage, arguments, value.
The functions work after the simulation: they sort and value net benefits that the model has already computed.
Which accounts, units and reference apply is therefore set by the model.

<span id="shared-arguments"></span>
### Shared arguments

The items inside the brackets of a call are called arguments in R.
Four of them come up again and again:

| Argument | What you pass | What to watch |
|---|---|---|
| `nb_list`, `nb` in the example | a named list with one matrix per group: draws in rows, options in columns | All groups need the same options and the same draws in the same order. One call values one outcome. |
| `p` | the group shares, preferably named by group | The functions match named shares to groups and divide by their sum. |
| `W` | a rule, for example `w_utilitarian()` | The rule turns the group values of one draw into one number. |
| `rules` | a named list of rules | Each rule is evaluated on its own. |

`p`, `W` and `rules` have no default: this choice is always made by whoever runs the analysis.
If a call shows `= value`, the argument has a default and can be left out.
A call such as `w_utilitarian()` only creates a rule; the analysis function applies it.

<span id="ref-nb-from-mc"></span>
### nb_from_mc(): take over the simulation columns

```r
nb_from_mc(mc, pattern, groups, options, attributes = NULL)
```

**Description.** Sorts the output columns of an `mcSimulation()` result by group and option; nothing is valued here.
This is the entry point right after the model run.

**Arguments.** `mc`: the simulation result with `$y`, or its output table directly.
`pattern`: the naming pattern of the columns, for example `"NB_{group}_{option}_V1"`.
`groups`, `options`: the codes of the groups and options; if they carry names, these become the labels of the result.
`attributes`: only for several outcomes; the pattern then also needs `{attribute}`.

**Value.** One matrix per group, or with `attributes` an array with a third dimension for the outcomes.
The order of `options` decides exact ties.

<span id="ref-nb-summary"></span>
### nb_summary(): summarise the results per group

```r
nb_summary(nb_list)
```

**Description.** Shows for each group what each option brings on average, how often the group gains or loses, and which option it would choose for itself.
No joint rule is involved.

**Arguments.** Only `nb_list`.

**Value.** A table with `unit`, `option`, `mean`, `p_gain`, `p_loss`, `preferred` and `EVPI`.
`preferred` and `EVPI` belong to a group's whole decision and are therefore repeated in each of its rows; do not add them up across rows.

<span id="ref-reporting-units"></span>
### reporting_units(): form a reporting unit

```r
reporting_units(nb_list, units)
```

**Description.** Combines groups into a reporting unit, for example a household or all women.
The coefficients stay visible in the call, so that a mean per person is not mistaken for a sum per household.

**Arguments.** `nb_list`: group matrices or group arrays.
`units`: a named list of coefficient vectors named by group, for example `list(total = c(women = 1, men = 1))`; they are not normalised.

**Value.** A list of the same shape, named after the new units, for example for `nb_summary()`.
Different outcomes stay separate.

<span id="ref-nb-array"></span>
### nb_array(): keep outcomes apart

```r
nb_array(...)
```

**Description.** Keeps several outcomes of one group, for example money and hours, apart within one object.
It does not convert between them and weights nothing.

**Arguments.** Any number of named matrices with the same draws and options, for example `nb_array(money = money_matrix, hours = hours_matrix)`, or a named list of them.

**Value.** An array: draw × option × outcome, for example for `baseline_pair()` and `reporting_units()`.
To value an outcome, select it as a matrix.

<span id="ref-w-utilitarian"></span>
### w_utilitarian(): weighted mean of the group values

```r
w_utilitarian()
```

**Description.** The rule multiplies each group value by the group share and adds them up.
One group's gains can thus offset another group's losses; a loss check such as `marginalisation_count()` therefore belongs with it.

**Arguments.** None; the group shares follow in the analysis call, for example in `voi_partition(nb, p, W)`.

**Value.** A rule `W(nb, p)`: a function that returns one number for one draw and one option.

<span id="ref-w-maximin"></span>
### w_maximin(): look at the worst-off group

```r
w_maximin()
```

**Description.** The rule takes the smallest group value in each draw.
Whether changes or levels are compared is decided by the inputs.

**Arguments.** None; the rule accepts `p` but does not use it.
A group with a share of zero still counts for the minimum.

**Value.** A rule; the analysis then averages the minima of the draws, not the other way round.

<span id="ref-w-prioritarian"></span>
### w_prioritarian(): let losses count more

```r
w_prioritarian(u)
```

**Description.** The rule first transforms each group value with a chosen function `u` and then takes the weighted mean.
This allows, for example, losses to count twice; the function does not decide which weighting is appropriate.

**Arguments.** `u`: a function that increases with the group value, for example `function(z) ifelse(z < 0, 2 * z, z)`.
To give priority to worse outcomes, it is concave.

**Value.** A rule with a transformed valuation; its values of information are therefore not readily comparable as amounts of money.

<span id="ref-w-atkinson"></span>
### w_atkinson(): weigh inequality explicitly

```r
w_atkinson(eps, offset = 0)
```

**Description.** The rule forms Atkinson's equally distributed equivalent: the amount that, given equally to all groups, would be valued just as highly.
`eps` sets how much inequality counts.

**Arguments.** `eps`: the inequality aversion, zero or larger; always state it.
`offset`: a number added to each group value before the valuation and subtracted again afterwards; every group value plus offset must be above zero.
The offset is part of the valuation choice; `eps = 1` and `offset = 10` in the example are not a default for other models.

**Value.** A rule: with the geometric mean for `eps = 1`, otherwise with the power mean.
If a shifted value is not above zero, it warns and returns `NA`.

<span id="ref-w-constrained"></span>
### w_constrained(): set a floor for every group

```r
w_constrained(min_group_nb = 0)
```

**Description.** Before the utilitarian valuation, the rule checks whether every group reaches a limit, for example "no group below its status quo".
It protects groups even when the joint number would be positive.

**Arguments.** `min_group_nb`: the floor for all groups, default 0; a group with a share of zero is checked too.

**Value.** A rule: the weighted mean if the floor holds, otherwise `-Inf` as a mark for "excluded".
`-Inf` is not an amount of money; read the floor separately from monetary values of information.

<span id="ref-welfare-draws"></span>
### welfare_draws(): rule values per draw

```r
welfare_draws(nb_list, p, W)
```

**Description.** Applies a rule to the group values of every draw and option.
This is the shared computational core of all analysis functions.

**Arguments.** As under [Shared arguments](#shared-arguments).

**Value.** A matrix with draws in rows and options in columns: the groups are already valued jointly, the draws are not yet averaged.

<span id="ref-voi-partition"></span>
### voi_partition(): value the decision, information and differentiated decisions

```r
voi_partition(nb_list, p, W, differentiated = FALSE,
              profiles = NULL, max_profiles = 1e5)
```

**Description.** Finds the option with the highest expected value and the expected value of perfect information (EVPI).
With `differentiated = TRUE` it also checks what differentiated decisions would bring the groups.

**Arguments.** `differentiated = FALSE`: one option for all groups; `TRUE`: each group may receive its own option.
`profiles`: if only some assignments are possible, they are given as a matrix, one row per allowed profile and one column per group; `NULL` allows all.
`max_profiles` limits the number of profiles checked and can usually stay as it is.

**Value.** A list with the best joint option `d_star`, the expected values `criterion`, the share of draws won `p_ahead`, `A`, `C` and `EVPI = C - A`.
With `differentiated = TRUE`, `B`, `D`, their differences and the best fixed profile `planner_profile` are added; "Preferred option" in the printout remains the joint option.

<span id="ref-voh-index"></span>
### voh_index(): relate differentiated decisions to information

```r
voh_index(x, tol = .Machine$double.eps^0.5)
```

**Description.** Relates the value of differentiated decisions under today's knowledge to the EVPI of a joint decision.
It puts the result of `voi_partition()` in context; it computes nothing new.

**Arguments.** `x`: the result of `voi_partition(..., differentiated = TRUE)`; `tol` is a technical tolerance that is normally left out.

**Value.** The number `(B - A) / (C - A)`, a ratio and not a probability.
If the denominator is zero or not finite, it returns `NA` with a reason in the attribute `reason`.

<span id="ref-marginalisation-count"></span>
### marginalisation_count(): count hidden losses

```r
marginalisation_count(nb_list, p, W, d_star = NULL)
```

**Description.** Counts the draws in which the joint number is positive but at least one group loses.
This shows what a positive overall judgement hides.

**Arguments.** `d_star`: the option to check, as a name or a column number; `NULL` checks the option the rule prefers.

**Value.** A list with the share of all draws `share`, the shares per group `by_group` and the checked option `d_star`.
The count is strict, with `> 0` and `< 0` and no rounding tolerance.

<span id="ref-fairness-screen"></span>
### fairness_screen(): compare rules side by side

```r
fairness_screen(nb_list, p, rules)
```

**Description.** Repeats the decision, the value of information and the loss check for every chosen rule.
This makes visible how the result depends on the valuation; the function does not rank the rules.

**Arguments.** `rules`: a named list of the rules to compare.

**Value.** A list with the table `table` (one row per rule), the expected values of all options under all rules `scores`, the intermediate results `partitions` and the smallest pairwise Spearman rank correlation `rank_correlation`.
The loss shares in `table` refer to the option that each rule prefers.

<span id="ref-baseline-pair"></span>
### baseline_pair(): compare two references

```r
baseline_pair(model, references, p, rules, units = NULL)
```

**Description.** Compares net benefits under two explicitly stated references, for example two valuations of the same freed hour.
The function shows whether numbers or recommendations change; it does not invent reference values.

**Arguments.** `model`: a small function that returns, for one reference, the net benefits already computed against it.
`references`: a named list of exactly two reference specifications.
`units`: optional extra reporting units as in `reporting_units()`; the rules still value the groups.

**Value.** A list with `outcomes` (means, shares of gains and differences) and `rules` (recommendation, EVPI and change `flip` per rule and reference).
The model function is called exactly twice; both results need the same draws and the same shape.

<span id="ref-fidelity-threshold"></span>
### fidelity_threshold(): find the smallest sufficient share

```r
fidelity_threshold(nb_list, p, W, tol = 1e-9)
```

**Description.** Finds the smallest share of an option's net effect that has to arrive for it to reach the best unchanged alternative.
It scales the whole net effect, not a single component of a measure.

**Arguments.** `tol`: the precision of the share; normally left out.
The floor is not suitable here; the condition of the search is given in [Step 9](#step-9).

**Value.** A table with the option, its value at full effect `value`, the best alternative value `best_other`, the flag `recommended` and the lower bound `f_star`.
`NA` means that no share between zero and one is enough.

<span id="printing"></span>
### Printing results

The results of `voi_partition()`, `fairness_screen()`, `baseline_pair()`, `marginalisation_count()` and `fidelity_threshold()` each have a `print()` method:

```r
print(x, digits = 4, ...)
```

`digits` is the number of decimal places shown; `print()` computes nothing new and changes no stored number.
The other helpers in `R/`, such as the input checks in `R/utils.R`, are not called directly.
`mcSimulation()` and `multi_EVPI()` belong to decisionSupport, not to these 16 functions.

<span id="step-by-step"></span>
## Step by step

One invented example runs through all functions.
Think of `dX` and `dY` as two measures in a village and of `d0` as "change nothing"; women and men are two groups.
The numbers are invented, not Atacora data, given in money units and checkable by hand.

To follow along, load the functions once in the project folder:

```r
source("load.R")
```

[`examples/step_by_step.R`](examples/step_by_step.R) contains all eleven steps as a script to run.
The excerpts from `R/` show the lines that carry a function; internal names in them such as `nb_list` or `rule_by_draw` are not called directly.

<span id="example-data"></span>
### The three things you need to know

```r
nb <- list(women = cbind(d0 = 0, dX = c(10, 8, 6, 0), dY = c(1, 2, 1, 2)),
           men   = cbind(d0 = 0, dX = c(2, 0, -4, 2), dY = c(4, 2, 3, 3)))
p <- c(women = 0.5, men = 0.5)
W <- w_utilitarian()
```

`nb` holds the net benefits: `nb$men[3, "dX"]` is the men's value in draw 3 under `dX`, namely −4 money units; `p` holds the group shares.
`W` is a rule: it receives the group values of one draw and one option and returns exactly one number.
That is why every analysis function works with every rule.

| Symbol in the equations | In R |
|---|---|
| Draw $s$ | one row |
| Option $d$ | one column |
| Group $g$ | one element of the list |
| $NB_g(d,\theta_s)$ | `nb[[g]][s, d]` |
| $W(NB(d,\theta_s);p)$ | `W(groups[s, ], p)` |
| $\mathbb{E}_\theta$, the expected value | `mean()` or `colMeans()` |
| $\mathbf{1}[\ldots]$, the indicator function | a logical expression; R counts `TRUE` as 1 and `FALSE` as 0 |
| $\arg\max$ | `which.max()`; in an exact tie the first entry wins |

$\theta_s$ stands for the uncertain inputs of draw $s$.
The rows must be the same draws in the same order in all groups; equal matrix dimensions do not prove this.
The functions draw no random numbers, shuffle no rows and remove no missing values.

<span id="step-1"></span>
### Step 1: Read the inputs

**Question.** What is in the data, and how do you read it in R? **In:** `nb`, `p` and `W`. **Out:** the values of single draws.

1. `c(10, 8, 6, 0)` strings four numbers together, one per draw. A row is not a year: it already holds the net benefit over the whole period considered.
2. `cbind()` puts such sequences side by side as columns. `d0 = 0` repeats the zero in all four rows: "change nothing" has a net benefit of zero against itself.
3. `list(women = ..., men = ...)` keeps the two matrices apart. The group names are freely chosen; the functions know no group by name.
4. `p` gives each group the weight 0.5. These are not probabilities of the draws; the four draws count equally when averaged.
5. `W <- w_utilitarian()` creates a function, not yet a result. Only `W(c(6, -4), p)` applies it to two group values and returns 1.

| Draw | women: d0 | women: dX | women: dY | men: d0 | men: dX | men: dY |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 0 | 10 | 1 | 0 | 2 | 4 |
| 2 | 0 | 8 | 2 | 0 | 0 | 2 |
| 3 | 0 | 6 | 1 | 0 | −4 | 3 |
| 4 | 0 | 0 | 2 | 0 | 2 | 3 |
| Mean | 0 | 6 | 1.5 | 0 | 0 | 3 |

Three ways of access are enough for reading:

```r
nb$men                 # The complete matrix for men.
nb[["men"]][3, "dX"]   # Row 3, column dX: -4.
nb$men[, "dX"]         # All rows of dX: 2, 0, -4, 2.
```

Before the comma comes the row, after it the column; an empty place means "all".
`nb[["men"]]` and `nb$men` select the same element; if the group name is stored in a variable `g`, write `nb[[g]]`.
The group values must suit the joint valuation, for example money per person over the same period.
Different units do not become comparable just because they sit in one list.

<span id="core"></span>
## The computational core: value first, then average

`R/welfare_draws.R` contains the two lines that carry it:

<!-- from R/welfare_draws.R -->
```r
# Each column of 'groups' is NB_g(d, theta_1), ..., NB_g(d, theta_S).
groups <- do.call(cbind, lapply(nb_list, function(x) x[, d]))
# A row is the vector NB(d, theta_s); apply W BEFORE taking a mean.
value[, d] <- rule_by_draw(groups, p, W)
```

`lapply()` takes the same option column from every group matrix; `do.call(cbind, ...)` puts these columns side by side, one column per group and one row per draw.
`rule_by_draw()` then calls `W(groups[s, ], p)` for each row and requires exactly one number back.
The result `value` again has draws in rows and options in columns.

<!-- eq-value -->
**Equation A1 (`eq-value`).** In words: value every option in every draw with the chosen rule, then average over the draws; the preferred option has the highest average.

```math
V(d) = \mathbb{E}_\theta\, W\big(NB(d,\theta);\,p\big),
\qquad
d^{*} = \arg\max_{d \in D}\, V(d).
```

$V(d)$ is `colMeans(value)[d]`, $W$ is the rule `W` and $p$ the vector `p`.
The option with the largest value in `colMeans(value)` is called `d_star` in the result.

<span id="step-2"></span>
### Step 2: Follow one column through the core

**Question.** How do the women's gain and the men's loss become one number? **In:** the two columns of `dX`. **Out:** one rule value per draw, then their mean.

```r
groups_dX <- cbind(women = nb$women[, "dX"], men = nb$men[, "dX"])
groups_dX[3, ]                  # women = 6, men = -4
p * groups_dX[3, ]              # 3, -2
sum(p * groups_dX[3, ])         # 1
```

This is the utilitarian calculation for one draw: first weight the two group values, then add them.
The same calculation for every row:

```r
apply(groups_dX, 1, W, p = p)   # 6, 4, 1, 1
mean(c(6, 4, 1, 1))            # 3
```

`apply(..., 1, ...)` works row by row; the function itself uses `vapply()` for the same calculation, because there "one number per row" is checked explicitly.
For all options, `welfare_draws()` returns:

```r
value <- welfare_draws(nb, p, W)
colMeans(value)
# d0 = 0; dX = 3; dY = 2.25
```

| Draw | d0 | dX | dY |
|---|---:|---:|---:|
| 1 | 0 | 6 | 2.5 |
| 2 | 0 | 4 | 2 |
| 3 | 0 | 1 | 2 |
| 4 | 0 | 1 | 2.5 |
| Mean | 0 | 3 | 2.25 |

`value` holds the four rows; the row "Mean" only comes from `colMeans(value)`.
On average, `dX` thus brings 3 money units per person and `dY` 2.25.

Why the order matters shows in maximin for `dX`: the smallest group values per draw are 2, 0, −4 and 0; their mean is −0.5.
The minimum of the group means would instead be `min(6, 0) = 0`; that answers a different question, and the functions do not use it.

<span id="rules"></span>
## Rules: one small interface

The five rules in `R/welfare_functions.R` each return a function `(nb, p)`.

<!-- eq-rules -->
**Equation A2 (`eq-rules`).** In words: the utilitarian rule takes the weighted mean of the group values, maximin takes the smallest group value, and the prioritarian rule counts losses with the factor $\lambda$ before averaging.

```math
\begin{aligned}
W_{\text{util}}(NB) &= \sum_{g} p_g\, NB_g ,
\qquad
W_{\text{maximin}}(NB) = \min_{g}\, NB_g ,\\
W_{\text{prior}}(NB) &= \sum_{g} p_g\, \varphi_\lambda(NB_g),
\qquad
\varphi_\lambda(z) =
\begin{cases}
z & \text{if } z \ge 0,\\
\lambda z & \text{if } z < 0 .
\end{cases}
\end{aligned}
```

<!-- eq-rules-ext -->
**Equation A3 (`eq-rules-ext`).** In words: Atkinson shifts all group values by k, takes a power mean (the geometric mean for $\varepsilon = 1$) and subtracts k again.
The floor values like the utilitarian rule but sets minus infinity as soon as a group is below m.

```math
\begin{aligned}
W_{\text{Atk}}(NB) &=
\begin{cases}
\Big(\sum_{g} p_g\, x_g^{\,1-\varepsilon}\Big)^{1/(1-\varepsilon)} - k & \text{if } \varepsilon \ne 1,\\
\exp\Big(\sum_{g} p_g \ln x_g\Big) - k & \text{if } \varepsilon = 1,
\end{cases}
\qquad x_g = NB_g + k ,\\
W_{\text{floor}}(NB) &=
\begin{cases}
\sum_{g} p_g\, NB_g & \text{if } \min_g NB_g \ge m,\\
-\infty & \text{otherwise.}
\end{cases}
\end{aligned}
```

| Rule | In R | What you choose |
|---|---|---|
| Utilitarian | `sum(p * nb)` | the group shares $p$ in the analysis call |
| Maximin | `min(nb)` | only the rule; shares do not count |
| Prioritarian | `sum(p * u(nb))` | the function `u`; "losses count twice" means $\lambda = 2$ |
| Atkinson | `x <- nb + offset`, then power mean or geometric mean, minus `offset` | `eps` ($\varepsilon$) and `offset` ($k$) |
| Floor | `-Inf` if a group is below the floor, otherwise `sum(p * nb)` | the floor `min_group_nb` ($m$), default 0 |

For Atkinson every shifted value `nb + offset` must be above zero; otherwise there is a warning and `NA`, and the rule does not adjust the offset itself.
The offset makes negative net benefits computable but also changes the valuation; it is part of choosing the rule.
Calling a rule directly, for example `w_utilitarian()(c(10, -2), c(0.5, 0.5))`, requires normalised shares; the analysis functions normalise them themselves.
For maximin and the floor, a group with a share of zero still counts.

<span id="step-3"></span>
### Step 3: Value the same draw with different rules

**Question.** How much does the judgement on one draw depend on the rule? **In:** draw 3 of `dX`, women +6 and men −4. **Out:** five different rule values for the same data.

| Rule | Calculation for these two values | Result |
|---|---|---:|
| Utilitarian | `0.5 * 6 + 0.5 * (-4)` | 1 |
| Maximin | `min(6, -4)` | −4 |
| Prioritarian, losses count twice | `0.5 * 6 + 0.5 * (-8)` | −1 |
| Atkinson, $\varepsilon = 1$, offset 10 | `exp(0.5 * log(16) + 0.5 * log(6)) - 10` | about −0.202 |
| Floor 0 | the men are below 0 | $-\infty$, excluded |

```r
loss_twice <- function(z) ifelse(z < 0, 2 * z, z)
rules <- list(utilitarian = w_utilitarian(),
              maximin = w_maximin(),
              prioritarian = w_prioritarian(loss_twice))
rules$prioritarian(c(6, -4), p)  # -1
w_atkinson(eps = 1, offset = 10)(c(6, -4), p)  # About -0.202
w_constrained()(c(6, -4), p)     # -Inf
```

`function(z)` defines a small calculation; `ifelse()` doubles every negative value.
`w_prioritarian(loss_twice)` stores this calculation and returns the rule; `rules$prioritarian` is therefore a function, and the brackets after it run it.
A list of rules allows the same steps several times without repeating the analysis code.

Atkinson works in four steps: add 10 (giving 16 and 6), average the logarithms with the weights, transform back with `exp()` and subtract 10 again.
The floor checks every group; `-Inf` is a mark for "excluded", not a very large loss of money.
If an option carries this mark in a single draw, its mean is `-Inf` as well.
The Atacora screen therefore reports the floor as a separate admissibility check.

<span id="information"></span>
## Value of information: why the order of mean and maximum matters

`R/voi_partition.R` contains the lines that carry it:

<!-- from R/voi_partition.R -->
```r
criterion <- colMeans(value)            # V(d) = (1/S) sum_s U[s,d]
d <- best_option(criterion)             # d* = argmax_d V(d)
A <- max(criterion)                     # max AFTER averaging: today's choice
C <- mean(apply(value, 1L, max))         # max BEFORE averaging: perfect information
ahead <- apply(value, 1L, best_option)
EVPI <- C - A                          # information changes the order of max and mean
```

`A` picks the option with the highest mean: a fixed decision with today's knowledge.
`apply(value, 1L, max)` instead takes the best option in each draw.
Their mean is `C`, the value of decisions with perfect information; the difference is the EVPI.

<!-- eq-voi -->
**Equation A4 (`eq-voi`).** In words: A is the best expected value of one option for all, C the mean of the best option in each draw.
B and D are the same when each group may receive its own option.

```math
\begin{aligned}
A &= \max_{d}\; \mathbb{E}_\theta\, W\big(NB(d,\theta)\big),\\
B &= \max_{(d_1,\dots,d_G)}\; \mathbb{E}_\theta\, W\big(NB_1(d_1,\theta),\dots,NB_G(d_G,\theta)\big),\\
C &= \mathbb{E}_\theta\, \max_{d}\; W\big(NB(d,\theta)\big),\\
D &= \mathbb{E}_\theta\, W\Big(\max_{d} NB_1(d,\theta),\dots,\max_{d} NB_G(d,\theta)\Big).
\end{aligned}
```

`A`, `B`, `C` and `D` have the same names in the result of `voi_partition()`.
The maximum over means is `max(colMeans(value))`, the mean over maxima is `mean(apply(value, 1L, max))`.

If the floor excludes every option, `d_star` is `NA`: there is no recommendation, and the formal values $-\infty$ are no research budget in money.

<span id="step-4"></span>
### Step 4: Compute a joint decision and its EVPI

**Question.** Which option is best on average, and what would it bring to know beforehand which draw will occur? **In:** `nb`, `p` and `W`. **Out:** the best option, `A`, `C` and the EVPI.

```r
joint <- voi_partition(nb, p, W)
joint$criterion  # d0 = 0; dX = 3; dY = 2.25
joint$d_star     # "dX"
joint$EVPI       # 0.625
```

1. **Decide today.** The means are 0, 3 and 2.25. Their maximum is `A = 3`: whoever commits now chooses `dX`.
2. **Decide with perfect information.** In draws 1 and 2 `dX` wins, in 3 and 4 `dY` wins. The attainable values are 6, 4, 2 and 2.5; their mean is `C = 3.625`.
3. **Compute the difference.** `C - A = 0.625` money units per person: this is the EVPI, in the unit of the rule value. Check: whoever chooses `dX` today misses 0, 0, 1 and 1.5 per draw; their mean is also 0.625.
4. **Read the frequency separately.** `joint$p_ahead = 0.5`, because `dX` is ahead in two of four draws. An option can have the highest expected value without winning in most draws. In an exact tie the option named first counts; `p_ahead` is therefore not a probability of being strictly ahead.

<span id="step-5"></span>
### Step 5: Allow differentiated decisions

**Question.** What could be achieved if women and men could receive different options? **In:** the same data and `differentiated = TRUE`. **Out:** `B`, `D` and their relation to the EVPI.

```r
split <- voi_partition(nb, p, W, differentiated = TRUE)
split$B             # 4.5
split$D             # 4.75
voh_index(split)    # 2.4
```

"Differentiated" means that women and men may receive different options, not just that they are reported separately; this has to be possible in reality.
In the Atacora model, differentiated decisions therefore exist only for household types: a machine cannot be both present and absent for the same household.

With three options and two groups there are nine profiles.
Without new information, `women = dX, men = dY` is the best: its values are 7, 5, 4.5 and 1.5, so `B = 4.5`.
With perfect information the profile may change from draw to draw; in the fourth draw the woman then also receives `dY`, giving 7, 5, 4.5 and 2.5, so `D = 4.75`.

| Question | Calculation | Result |
|---|---|---:|
| What do differentiated decisions bring already today? | `B - A = 4.5 - 3` | 1.5 |
| What does information add once decisions are differentiated? | `D - B = 4.75 - 4.5` | 0.25 |
| What do differentiated decisions bring under perfect information? | `D - C = 4.75 - 3.625` | 1.125 |
| How large is the first value relative to the EVPI? | `(B - A) / (C - A)` | 2.4 |

2.4 is a ratio, 2.4 times, and not a probability.
For checking, `A + (B - A) + (D - B) = C + (D - C) = D` helps.

If only some profiles are possible, state them explicitly:

```r
allowed <- rbind(c("d0", "d0"), c("dX", "dX"), c("dY", "dY"),
                 c("dX", "d0"), c("d0", "dX"))
colnames(allowed) <- c("women", "men")
restricted <- voi_partition(nb, p, W, differentiated = TRUE, profiles = allowed)
```

Now `dX/dY` and `dY/dX`, among others, are missing.
With this smaller choice, `B = 3` and `D = 3.875`; in draw 3, `dX/d0` with the value 3 is then best.
The data stayed the same, the allowed decisions changed; the option set and the allowed profiles therefore belong to every value of information.

<!-- eq-voi-profiles -->
**Equation A5 (`eq-voi-profiles`).** In words: with restricted profiles, B and D are formed over the allowed profiles only, and in each draw the best allowed profile counts.

```math
B = \max_{r \in R}\; \mathbb{E}_\theta\, W\big(NB(r,\theta)\big),
\qquad
D = \mathbb{E}_\theta\, \max_{r \in R}\; W\big(NB(r,\theta)\big).
```

$r$ is one row of `profiles`, $R$ the whole matrix.
The function values every allowed profile in every draw; `pmax()` carries the best value per draw forward.

`voh_index()` returns `NA` with a reason if the denominator `C - A` is zero or not finite.
With restricted profiles, `B - A` and `D - C` are only sure to be zero or larger if every joint option remains allowed as a profile; negative differences are not set to zero.

**For rules of your own.** Without restricted profiles the function uses a shortcut: each group takes its own maximum.
This is correct if the following holds: if one group is better off and none is worse off, the joint number must not fall.
It holds for all five supplied rules.

<span id="hidden-losses"></span>
## Hidden losses and comparing rules

`marginalisation_count()` in `R/fairness_screen.R` counts with three lines:

<!-- from R/fairness_screen.R -->
```r
below <- do.call(cbind, lapply(nb_list, function(x) x[, d] < 0))
gain <- value[, d] > 0                   # W(NB(d, theta_s)) > 0
hidden <- gain & rowSums(below) > 0      # AND min_g NB_g(d, theta_s) < 0
```

`rowSums(below) > 0` means that at least one group loses in this draw.
`&` also requires a positive rule value.
The mean of these `TRUE`/`FALSE` values, `mean(hidden)`, is the share of such draws; `colMeans(gain & below)` gives it per group.

<!-- eq-marginalisation -->
**Equation A6 (`eq-marginalisation`).** In words: M is the share of draws in which the checked option is valued positively overall while at least one group loses.

```math
M = \frac{1}{S} \sum_{s=1}^{S}
\mathbf{1}\Big[\, W\big(NB(d^{*},\theta_s)\big) > 0 \;\wedge\; \min_{g}\, NB_g(d^{*},\theta_s) < 0 \,\Big].
```

$S$ is the number of draws.
The checked option is called `d_star` in the result, and the bracket with the 1 is the logical value `hidden`.

`fairness_screen(nb, p, rules)` repeats this check for every rule: `$table` reports for each rule the preferred option, its EVPI, its share of draws won and the loss shares; `$scores` contains all options under all rules.
`$rank_correlation` is the smallest pairwise Spearman rank correlation; if it cannot be computed, it is `NA`.
The loss shares refer to the option each rule prefers; for another option, state `d_star`.
There is no automatic selection of "all ethical rules" and no preset weighting.

<span id="step-6"></span>
### Step 6: Spot a hidden loss row by row

**Question.** Who loses although the overall result is positive? **In:** `nb`, `p`, `W` and the option `dX`. **Out:** the share of draws with a hidden loss, overall and per group.

```r
hidden <- marginalisation_count(nb, p, W, d_star = "dX")
```

| Draw | Rule value of dX | Women < 0? | Men < 0? | Positive and a loss? |
|---|---:|---|---|---|
| 1 | 6 | FALSE | FALSE | FALSE |
| 2 | 4 | FALSE | FALSE | FALSE |
| 3 | 1 | FALSE | TRUE | TRUE |
| 4 | 1 | FALSE | FALSE | FALSE |

Only in draw 3 does the joint result look positive although a group loses.
`mean(c(FALSE, FALSE, TRUE, FALSE))` is 0.25: a hidden loss in a quarter of all draws, not only of the positive ones.
Without the condition "positive" you get the loss shares of `nb_summary()`.

```r
screen <- fairness_screen(nb, p, rules)
screen$table
screen$scores
```

The utilitarian and the prioritarian rule choose `dX` here, maximin chooses `dY`.
The EVPIs are 0.625, 1.125 and 0.25, the hidden losses 25 %, 0 % and 0 %.
Under the prioritarian rule the man still loses in 25 % of the draws; there, however, the joint rule value is negative, so the loss is not hidden.
The result does not say which rule is right.

**For rules of your own.** The functions compare strictly with `< 0` and `> 0`.
A rounding remainder just below zero therefore counts as a loss.
Where the model actually delivers an exact zero, this needs explaining when reading the result.

<span id="units"></span>
## Reporting units

In `R/reporting_units.R` a reporting unit is a weighted sum of whole matrices:

<!-- from R/reporting_units.R -->
```r
terms <- Map(function(x, coefficient) coefficient * x,
              nb_list[names(coefficients)], coefficients)
Reduce(`+`, terms)
```

`Map()` multiplies each chosen group by its coefficient, `Reduce()` adds the matrices cell by cell.
The coefficients are not normalised: `(1, 1)` gives a sum, `(0.5, 0.5)` a mean.

<!-- eq-units -->
**Equation A7 (`eq-units`).** In words: the value of a reporting unit is the sum of the group values, each multiplied by a chosen coefficient.

```math
NB_k(d,\theta) = \sum_{g} c_{kg}\, NB_g(d,\theta).
```

$c_{kg}$ is the entry for group $g$ in the coefficient vector of unit $k$, for example `c(women = 1, men = 1)` for `total`.

`nb_summary(nb)` shows for each group the mean, the shares of gains and losses, its own best option and its own EVPI, without a joint rule.
The EVPI appears in every option row of a group but belongs to that group's whole decision; do not add it up across rows.

<span id="step-7"></span>
### Step 7: Form a reporting unit without mistaking it for a rule

**Question.** How do I report for a woman and a man together instead of per person? **In:** `nb` and the coefficients. **Out:** the new unit `total` and each group's own decision.

```r
units <- reporting_units(nb, list(total = c(women = 1, men = 1)))
units$total[, "dX"]                # 12, 8, 2, 2
mean(units$total[, "dX"])          # 6
nb_summary(nb)
```

1. The coefficient 1 takes over each group matrix unchanged.
2. The matrices are added cell by cell, so in draw 3 under `dX` this gives `6 + (-4) = 2`.
3. The mean of the four sums is 6 money units for a woman and a man together. The utilitarian valuation with the shares 0.5 and 0.5 gave 3 money units per person. A sum and a weighted mean have different scales, even when the ranking stays the same, as here.

`reporting_units()` answers: in which unit do I report? `W` answers: how do I value the groups jointly?
Under the utilitarian rule the two calculations look alike, but their meaning and normalisation differ.
In the Atacora model, for example, the number of hullers per household turns an amount per huller into a contribution per household.

The women's own decision is `dX` with an EVPI of 0.5, the men's is `dY` with an EVPI of 0.
These values must not be added unweighted to the joint EVPI of 0.625.
Their weighted mean, `0.5 * 0.5 + 0.5 * 0 = 0.25`, is exactly `D - B` from Step 5 under differentiated decisions and linear weighting.

`nb_array()` keeps several outcomes side by side:

```r
hours <- cbind(d0 = 0, dX = c(2, 3, 1, 0), dY = c(1, 1, 1, 1))
measured <- nb_array(money = nb$women, hours = hours)
measured[3, "dX", "money"]        # 6
measured[3, "dX", "hours"]        # 1
```

The hours are further invented values; the third index selects the outcome.
Neither `6 + 1` nor a money value of the hour is computed; to value an outcome, select it as a matrix.

<span id="references"></span>
## Comparing references

`baseline_pair()` in `R/baseline_pair.R` receives a small function that returns the matching net benefits for each reference, and calls it exactly twice.
It invents no reference value and does not subtract a reference a second time.

<!-- eq-reference -->
**Equation A8 (`eq-reference`).** In words: the net benefit is the outcome with the option minus the outcome without change, both under the same reference.

```math
NB_g(d,\theta;\,r) = Y_g(d,\theta;\,r) - Y_g(d_0,\theta;\,r),
```

$Y_g$ is the group's outcome in the model, $d_0$ the option "change nothing" and $r$ one of the two entries in `references`.
The model computes the difference; `baseline_pair()` receives it ready-made.

`$outcomes` shows both means, both shares of gains and their difference; `$rules` shows the recommendation and the EVPI per reference and rule.
`flip` is `TRUE` if the recommendation changes; if a recommendation is undefined, it is `NA`; several outcomes are valued separately.

<span id="step-8"></span>
### Step 8: Change exactly the reference you want to examine

**Question.** Does the recommendation change if you compare with something else? **In:** a model function and two reference specifications. **Out:** recommendation and EVPI under both references.

This demonstration changes only the already computed net benefits of the women under `dX`; it is not a model of reality:

```r
example_model <- function(adjustment) {
  result <- nb
  result$women[, "dX"] <- result$women[, "dX"] - adjustment
  result
}
pair <- baseline_pair(example_model,
  references = list(first = 0, second = 3), p = p,
  rules = list(utilitarian = W))
pair$rules
```

1. `baseline_pair()` passes first 0, then 3 to `example_model()`.
2. Under the first reference the expected value of `dX` stays at 3. Under the second it falls by `0.5 * 3 = 1.5` to 1.5.
3. `dY` stays at 2.25 in both cases. The recommendation therefore changes from `dX` to `dY`; `flip` is `TRUE`.
4. In `pair$outcomes` the women's mean for `dX` falls from 6 to 3, so `difference = -3`. This is a difference between outcomes, not a further deduction in the decision.

In the Atacora screen, `function(s) nb(c("G", "H"), s)` returns the columns the model has already computed for `V1` and `PREF`; the other valuation of time sits in these columns.
If `flip = FALSE` remains, this only means that the same option was chosen.
Means, values of information or losses can still change.

<span id="fidelity"></span>
## Fidelity: how much of the effect has to arrive

`fidelity_threshold()` in `R/fidelity_threshold.R` scales only the option being checked by a share f; the alternatives keep their full effect.
`mean(rule_by_draw(f * groups, p, W))` is the value of the option at share f.

<!-- eq-fidelity -->
**Equation A9 (`eq-fidelity`).** In words: multiply the option's net effect by f, value and average.
The answer is the smallest f between 0 and 1 at which the option reaches the best alternative at full effect.

```math
V_d(f) = \mathbb{E}_\theta\, W\big(f \cdot NB(d,\theta)\big),
\qquad
f^{*}_d = \min\Big\{ f \in [0,1] : V_d(f) \ge \max_{e \ne d} V_e(1) \Big\}.
```

$V_d(f)$ is the value of the option at share $f$.
The right-hand side of the inequality is the column `best_other`, and the smallest $f$ sought is the column `f_star`.

A tie is enough for the inequality, even if the selection lets an option named earlier win.
The search proceeds as follows:

1. If f = 0 already satisfies the inequality, `f_star` is zero.
2. If f = 1 satisfies it, an interval search halves the gap until the precision `tol` is reached.
3. Otherwise the function looks for an interior maximum. If even this does not reach the alternative, the result is `NA`; otherwise it looks for the first crossing between zero and this maximum.

A smaller share is not always worse: if one group gains and another loses, Atkinson can have an interior maximum.
Then `f_star` is only the start of a sufficient range, not a promise for all larger shares.
Even an option that is negative overall can just reach the status quo at f = 0.
Read `value`, `best_other` and `recommended` together with `f_star` for this reason.

<span id="step-9"></span>
### Step 9: Find a threshold by hand

**Question.** How much of the effect of `dX` has to arrive for `dX` to stay ahead? **In:** `nb`, `p` and `W`. **Out:** the smallest sufficient share per option.

```r
fidelity <- fidelity_threshold(nb, p, W)
fidelity
```

For `dX` the best other option is `dY` with the value 2.25.
Under the utilitarian rule the value of `dX` at share f is `3 * f`.
The search is therefore for `3 * f >= 2.25`, that is, f from 0.75.

| Share f | Value of dX | Best alternative | Satisfied? |
|---|---:|---:|---|
| 0 | 0 | 2.25 | no |
| 0.5 | 1.5 | 2.25 | no |
| 0.75 | 2.25 | 2.25 | yes |
| 1 | 3 | 2.25 | yes |

The search first checks the end points.
Because 0 is not enough and 1 is, it halves the interval: first 0.5, then 0.75, then further points until the required precision.
It needs no special formula such as `2.25 / 3`; that way it also works with the other rules.

For `dY`, by contrast, the full alternative `dX` with 3 is the benchmark.
Even at f = 1, `dY` only reaches 2.25.
The result is `NA`: no share between 0 and 1 is enough, and `NA` does not mean zero here.

For a harmful option `f_star = 0` can come out: if the whole effect is scaled to zero, the harm disappears too.
This is a statement about the inequality, not a recommendation to implement a measure without effect.
Likewise, an Atkinson threshold at an interior maximum does not promise that all larger shares are enough.

This function scales the whole net effect of an option.
Anyone who wants to vary single components of a measure separately needs a model run of their own, in the Atacora case in `atacora_DA_axes_full.R`.

**For rules of your own.** The search requires $V_d(f)$ to be finite, continuous and concave between 0 and 1.
This holds for the utilitarian rule, maximin, the prioritarian rule with a loss factor of at least 1, and Atkinson within its positive range.
For a transformation of your own you have to check this yourself; the floor with `-Inf` is not suitable.
`tol` is the absolute precision of f.

<span id="decisionsupport"></span>
## Connecting to decisionSupport

`nb_from_mc()` in `R/nb_from_mc.R` reads `mc$y` as `mcSimulation()` returns it.
A column pattern, the groups and the options are enough.
`decisionSupport::multi_EVPI()` measures a different value of information from `voi_partition()`; [Step 11](#step-11) shows the difference.

<span id="step-10"></span>
### Step 10: Connect the simulation

**Question.** How do the results of a real model get into this shape? **In:** the result of `mcSimulation()`. **Out:** the same list of group matrices as `nb`.

```r
people <- nb_from_mc(simulation_results, "NB_{group}_{option}_V1",
                     groups = c("G", "H"),
                     options = c("sq", "out", "up_std", "up_inc", "deep"))
```

1. The output table is in `simulation_results$y`. Groups and options give the column names, for example `NB_G_out_V1`.
2. The five columns of G become the first matrix, the five of H the second.
3. `people` has the same shape as `nb`; here each matrix has 10,000 rows and five columns.
4. After that, the same calls as above work. Group shares and rules are set explicitly for the case.

`options` also sets the order of the options and thus which option wins an exact tie.
`attributes` is not needed for a single outcome.

<span id="step-11"></span>
### Step 11: Keep the full and the partial value of information apart

**Question.** What exactly does a value of information measure? **In:** the same data with fewer options. **Out:** a different EVPI.

`voi_partition()` uses all options given.
It asks what perfect knowledge of the uncertain inputs would be worth for this decision.
`multi_EVPI()` instead forms the difference for one particular pair of options and estimates the value of information about single inputs; the two values must not be equated.

<!-- eq-evppi -->
**Equation A10 (`eq-evppi`).** In words: the partial value of information of an input j is what you would gain on average if, before choosing between two options, you knew only this one input.

```math
\mathrm{EVPI}_j = \mathbb{E}_{\theta_j}\Big[\max\big(\mathbb{E}(\Delta \mid \theta_j),\,0\big)\Big] - \max\big(\mathbb{E}\,\Delta,\,0\big).
```

$\Delta$ is the difference between the two options per draw, in `examples/partial_information.R` the column `comparison`.
$\theta_j$ is input $j$; `multi_EVPI()` computes this value for every input.

Our example shows how much the option set matters:

```r
only_X <- lapply(nb, function(x) x[, c("d0", "dX"), drop = FALSE])
voi_partition(only_X, p, W)$EVPI  # 0
voi_partition(nb, p, W)$EVPI      # 0.625
```

`dX` beats `d0` in every draw.
If only these two options are allowed, information never changes the decision.
Only `dY` creates draws in which you would want to decide differently.
An EVPI of zero for one pair of options is therefore compatible with a positive EVPI for all options.
Every value of information comes with its outcome, its option set and the scope of the information.

[`examples/partial_information.R`](examples/partial_information.R) connects the two: it forms an explicitly named pair of options, calls `multi_EVPI()` and reports how often an omitted option would be better.

<span id="full-run"></span>
## Complete run

This script applies all 16 functions to the four example draws.
It runs on its own from the project folder and is also in [`examples/complete_analysis.R`](examples/complete_analysis.R).
The six columns in `mc$y` rebuild the familiar table, and `nb_from_mc()` assigns them to groups and options; the hours at the end are separate invented values.

```r
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
```

The following blocks show what R prints for this script; the `print()` methods round to four decimal places.
Field names and output texts are the ones the functions return.

**Output 1: nb_summary(nb)**
```text
   unit option mean p_gain p_loss preferred EVPI
1 women     d0  0.0   0.00   0.00        dX  0.5
2 women     dX  6.0   0.75   0.00        dX  0.5
3 women     dY  1.5   1.00   0.00        dX  0.5
4   men     d0  0.0   0.00   0.00        dY  0.0
5   men     dX  0.0   0.50   0.25        dY  0.0
6   men     dY  3.0   1.00   0.00        dY  0.0
```

`mean` is the mean, `p_gain` and `p_loss` are the shares of draws with a gain and a loss, `preferred` and `EVPI` each group's own decision ([Step 7](#step-7)).
Women prefer `dX`, men `dY`; under `dX` the men lose in one of four draws although their mean is zero.

**Output 2: welfare_draws()**
```text
     d0 dX  dY
[1,]  0  6 2.5
[2,]  0  4 2.0
[3,]  0  1 2.0
[4,]  0  1 2.5
```

The rows are the four draws, the numbers utilitarian rule values ([Step 2](#step-2)).
In row 3 the value of `dX` is positive although the men receive −4 there.

**Output 3: reporting_units() and nb_summary()**
```text
   unit option mean p_gain p_loss preferred EVPI
1 total     d0  0.0      0      0        dX 1.25
2 total     dX  6.0      1      0        dX 1.25
3 total     dY  4.5      1      0        dX 1.25
```

With a coefficient of 1 for both groups, `total` is the sum: mean and EVPI are twice the utilitarian values with the shares 0.5 and 0.5 ([Step 7](#step-7)).
`p_loss = 0` for `dX` only means that the sum is never negative; the men's loss in draw 3 remains.

**Output 4: voi_partition()**
```text
Preferred option: dX 
    A     C  EVPI 
3.000 3.625 0.625 
```

`Preferred option` is the best joint option, `A` its value today, `C` the value with perfect information and `EVPI` the difference ([Step 4](#step-4)).
Further values such as `joint$criterion` and `joint$p_ahead` are stored in the object.

**Output 5: voi_partition(differentiated = TRUE)**
```text
Preferred option: dX 
         A          B          C          D       EVPI VoH_static   EVPI_sub    VoH_dyn 
     3.000      4.500      3.625      4.750      0.625      1.500      0.250      1.125 
women   men 
 "dX"  "dY" 
```

The first line still names the best joint option, the last the best differentiated profile: women `dX`, men `dY` ([Step 5](#step-5)).
`VoH_static`, `EVPI_sub` and `VoH_dyn` are `B - A`, `D - B` and `D - C`.

**Output 6: voh_index()**
```text
[1] 2.4
```

`[1]` only marks the first element.
2.4 means that differentiated decisions already bring 2.4 times the joint EVPI today ([Step 5](#step-5)); this is neither a percentage nor a probability.

**Output 7: marginalisation_count()**
```text
Hidden-loss share for dX : 0.25 
 group share
 women  0.00
   men  0.25
```

Without `d_star` the function checks the option the rule prefers, here `dX`.
In 25 % of all draws its joint value is positive while a group loses; only the men are affected ([Step 6](#step-6)).

**Output 8: fairness_screen()**
```text
         rule option p_ahead   EVPI p_group_loses p_hidden_loss
  utilitarian     dX    0.50 0.6250          0.25          0.25
      maximin     dY    0.75 0.2500          0.00          0.00
 prioritarian     dX    0.50 1.1250          0.25          0.00
   atkinson_1     dX    0.50 0.9240          0.25          0.00
   atkinson_2     dY    0.50 0.8843          0.00          0.00
```

Each row names a rule and its preferred option; `p_group_loses` counts every group loss under this option, `p_hidden_loss` only the hidden ones ([Step 6](#step-6)).
The prioritarian rule and Atkinson with $\varepsilon = 1$ stay with `dX`: the men still lose in 25 % of the draws, but there the loss is not hidden.
The Atkinson rows hold for the chosen offset of 10, and the EVPIs are measured in each rule's own terms, so they are not comparable amounts of money.

**Output 9: welfare_draws() with w_constrained()**
```text
     d0   dX  dY
[1,]  0    6 2.5
[2,]  0    4 2.0
[3,]  0 -Inf 2.0
[4,]  0    1 2.5
```

`-Inf` for `dX` in row 3 shows that the men fall below the floor of zero there ([Step 3](#step-3)).
The requirement that no group loses in any draw therefore excludes `dX`, while `d0` and `dY` meet it; the mark implies no amount of money and no research budget.

**Output 10: fidelity_threshold()**
```text
 option value best_other recommended f_star
     d0  0.00       3.00       FALSE     NA
     dX  3.00       2.25        TRUE   0.75
     dY  2.25       3.00       FALSE     NA
```

`value` is the value at full effect, `best_other` the best alternative at full effect ([Step 9](#step-9)).
`dX` needs 75 % of its effect to reach `dY`; for `d0` and `dY` no share is enough, hence `NA`.

**Output 11: baseline_pair()**
```text
        rule outcome reference option p_ahead  EVPI flip
 utilitarian      nb     first     dX     0.5 0.625 TRUE
 utilitarian      nb    second     dY     0.5 0.625 TRUE
```

Under the second reference, 3 money units are deducted from the women's values under `dX`; the recommendation changes from `dX` to `dY`, hence `flip = TRUE` ([Step 8](#step-8)).
The EVPI happens to stay the same here; a change of recommendation does not require a change of EVPI.
`outcome = nb` is the name of the only outcome; the means per group are in `references$outcomes`.

**Output 12: nb_array()**
```text
, , money

     d0 dX dY
[1,]  0 10  1
[2,]  0  8  2
[3,]  0  6  1
[4,]  0  0  2

, , hours

     d0 dX dY
[1,]  0  2  1
[2,]  0  3  1
[3,]  0  1  1
[4,]  0  0  1

```

`, , money` and `, , hours` are the two separate layers of the array ([Step 7](#step-7)).
In draw 3 under `dX` there are 6 money units and 1 hour, not the value 7.

This has used all 16 functions.
`mcSimulation()` and `multi_EVPI()` do not run here: the output table is given and has no uncertain inputs about which a partial analysis of information could say anything.

<span id="atacora"></span>
## From four draws to a real model: the Atacora screen

`atacora_DA_axes.R` applies the same functions to the Atacora model (`atacora_DA_model.R`).
For fonio processing in Atacora, northern Benin, the model compares five options: `sq` change nothing, `out` processing equipment, `up_std` and `up_inc` a national fonio plan with two rules for the operator margin, and `deep` a nutrition campaign.
There are accounts for the producer household (G), the women in it (Wg), paid hullers (H), the machine operator (O) and the commune (`comm`).
The screen reads the 10,000 saved draws that `atacora_DA_run.R` writes, has fewer than 100 lines and writes no files.
It gives no recommendation for Atacora: every result holds under the assumptions of the input table.

```r
source("atacora_DA_axes.R")
review$fairness                # which rule prefers which option
review$designs                 # up_std against up_inc, not against the status quo
review$references$outcomes     # every group under both reference conditions
review$floor                   # which options leave no group worse off in any draw
review$hidden$out              # aggregate gain while a group loses
review$heterogeneity           # differentiated decisions for household types
```

The whole script:

```r
# FIVE AXES + FIDELITY. Run from the project root; results are in 'review'.

# Uses the existing 10,000 draws (seed 20260927); no new simulation or file writes.
source("load.R", local = TRUE)
if (!file.exists("outputs/v9/simulation_results.rds"))
  stop("Run atacora_DA_run.R first (about 25 minutes); it writes outputs/v9/simulation_results.rds.", call. = FALSE)
simulation_results <- readRDS("outputs/v9/simulation_results.rds")
options <- c("sq", "out", "up_std", "up_inc", "deep")
nb <- function(groups, setting = "V1", prefix = "NB")
  nb_from_mc(simulation_results, paste0(prefix, "_{group}_{option}_", setting), groups, options)

# State the case's valuation choices once. K is fixed in the input table.

K <- unique(simulation_results$x$hullers_per_producer_hh)
stopifnot(length(K) == 1L, is.finite(K), K > 0)
p <- c(G = 1, H = K) / (1 + K)
p_women <- c(Wg = 1, H = K) / (1 + K)
status_quo_cash <- median(simulation_results$y$NPV_G_cash_sq)
largest_loss <- -min(unlist(lapply(c("V0", "V1", "PREF"), function(s) nb(c("G", "H"), s))))
offset <- if (largest_loss < status_quo_cash) status_quo_cash else
  ceiling((largest_loss + 1) / 1e5) * 1e5  # FCFA: status quo median, or next 100,000 above the largest loss
rules <- list(utilitarian = w_utilitarian(),
  prioritarian = w_prioritarian(function(z) ifelse(z < 0, 2 * z, z)),
  atkinson_0.5 = w_atkinson(0.5, offset), atkinson_1 = w_atkinson(1, offset),
  atkinson_2 = w_atkinson(2, offset), maximin = w_maximin())


# 1. SYSTEM BOUNDARY: totals per producer household; K converts H/person to H/HH.
# Operator O is already per household; it is not treated as another person.
boundary_units <- list(G = c(G = 1), GH = c(G = 1, H = K), GHO = c(G = 1, H = K, O = 1))
boundary <- lapply(c(V0 = "V0", V1 = "V1"), function(s)
  nb_summary(reporting_units(nb(c("G", "H", "O"), s), boundary_units)))

# 2. REFERENCE: both valuations come from the SAME simulated states of the world.
references <- baseline_pair(function(s) nb(c("G", "H"), s),
  references = list(behaviour = "V1", preference = "PREF"), p = p, rules = rules)

# 3. REPORTING UNIT: retain separate accounts alongside the pooled women's mean.
women <- nb(c("Wg", "H"))
units <- nb_summary(c(nb(c("G", "Wg", "H")),
  reporting_units(women, list(women_pooled = p_women))))
hidden <- lapply(options[-1L], function(d)
  marginalisation_count(women, p_women, w_utilitarian(), d_star = d))
names(hidden) <- options[-1L]

# 4. FAIRNESS: compare all options AND the two plan designs explicitly (H2).
people <- nb(c("G", "H"))
fairness <- fairness_screen(people, p, rules)
designs <- fairness_screen(lapply(people, function(x) x[, c("up_std", "up_inc")]), p, rules)
floor_by_group <- nb_summary(nb(c("G", "Wg", "H")))[, c("unit", "option", "p_loss")]
floor <- data.frame(option = options, admissible = vapply(options, function(d)
  all(floor_by_group$p_loss[floor_by_group$option == d] == 0), logical(1)))
# The floor is an admissibility check on EVERY group; no floor ranking or floor EVPI.

# 5. INFORMATION: each actor's own decision, and a common decision for the commune.
information <- lapply(c(V0 = "V0", V1 = "V1", PREF = "PREF"), function(s)
  unique(nb_summary(nb(c("Wg", "H", "G", "comm"), s))[, c("unit", "preferred", "EVPI")]))
# Different decisions are possible for household TYPES, not for household members.
types <- nb(c("self", "hire"), prefix = "NBc")
share_hire <- simulation_results$x$hiring_hh_share
types <- Map(function(x, share) share * x, types, list(1 - share_hire, share_hire))
allowed <- rbind(c("sq", "sq"), c("out", "sq"), c("sq", "out"), c("out", "out"),
  c("up_std", "up_std"), c("up_inc", "up_inc"), c("deep", "deep"))
colnames(allowed) <- c("self", "hire")
# Shares are already in each draw: sum contributions to get FCFA per household.
heterogeneity <- voi_partition(types, p = c(1, 1), W = function(nb, p) sum(nb),
  differentiated = TRUE, profiles = allowed)
heterogeneity_ratio <- voh_index(heterogeneity)

# ACROSS DIRECTIONS: scalar effect fidelity; component-specific delivery needs a rerun.
fidelity <- fidelity_threshold(nb("comm"), p = 1, W = w_utilitarian())
review <- list(settings = list(seed = 20260927, draws = nrow(simulation_results$y),
  K = K, p = p, atkinson_offset = offset, rules = names(rules)), boundary = boundary,
  references = references, units = units, hidden = hidden, fairness = fairness,
  designs = designs, floor_by_group = floor_by_group, floor = floor,
  information = information, heterogeneity = heterogeneity,
  heterogeneity_ratio = heterogeneity_ratio, fidelity = fidelity)
print(review$fairness)
```

**Settings.** `K` is the number of paid hullers per producer household; it is fixed in the input table.
`p` weighs one household and its `K` hullers as persons.
The Atkinson offset is the median status quo money of a household, unless a loss reaches that far; then it is the next 100,000 FCFA above the largest loss.

**1. System boundary.** Three boundaries: the household alone (G), with the hullers (G + K·H), and with the operator (G + K·H + O).
`reporting_units()` adds the accounts with these coefficients.
The system boundary is a modelling decision, not a function: what enters an account is set by Equations A11 and A12 in the model.

<!-- eq-money -->
**Equation A11 (`eq-money`).** In words: the net benefit of a producer household is its money plus the working time saved, valued at the hourly wage, plus the amount eaten at home, valued at the price.

```math
NB_G = y_G + \omega_W\, w_h\, t_G + \kappa\, p_f\, c_G ,
```

$y_G$ is the money, that is sales minus fees plus margin (`G_cash` in the model), $t_G$ the hours saved, $w_h$ the hourly wage (`wage_h`), $c_G$ the kilograms eaten at home and $p_f$ their price (`p` in the model).
$\omega_W$ and $\kappa$ are the weights of the settings V0, V1 and PREF; all components are already discounted, and `G_time` and `G_kg` already contain the wage and the price.

<!-- eq-boundary -->
**Equation A12 (`eq-boundary`).** In words: per producer household, the commune counts the household, its K paid hullers and the operator together.

```math
NB_{\text{comm}} = NB_G + K\, NB_H + NB_O ,
```

$NB_H$ holds per huller and becomes a contribution per household through $K$; the operator's $NB_O$ is already per household.
`boundary_units$GHO` in the screen is exactly this sum; Wg is part of G and is not added a second time.

**2. Reference condition.** `baseline_pair()` compares the behavioural reference (V1) with the preference-based reference (PREF).
Both come from the same draws; they differ in how the freed time is valued.

**3. Reporting unit.** The women in producer households (Wg) and the hullers (H) are reported once separately and once pooled as `women_pooled`.
`marginalisation_count()` looks for hidden losses in the pooled number for every option.

**4. Rule.** Six rules for all options and separately for the two designs of the plan.
Here the floor is an admissibility check: an option is admissible if no group loses in any draw.

**5. Value of information.** The EVPI is given per actor (Wg, H, G, commune) under V0, V1 and PREF.
Differentiated decisions exist only for household types (`self`, `hire`), not for members of one household; the allowed profiles are in `allowed`.
The contributions of the types are already weighted with their share in each draw; the sum rule therefore reports FCFA per producer household.

**Across all directions: fidelity.** `fidelity_threshold()` scales the whole net effect of each option for the commune.
Varying the components of a measure separately needs a new model run.
