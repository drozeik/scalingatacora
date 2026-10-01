# Valuation functions: annotated code

This file explains every function in the folder `R/`, line by line. It follows Appendix 1 of the article *Scaling as a valuation decision* and adds what the appendix only lists: the full code of the input checks and of the `print()` methods, and an index of the helper functions defined inside the scripts of the Atacora case.

**Contents.**
[Overview](#functions) ·
[Notation](#notation) ·
[Worked example](#example) ·
[How the code is organised](#code) ·
[The shared engine](#engine) ·
[Input checks](#checks) ·
[Valuation rules](#rules) ·
[Hidden losses](#marginalisation) ·
[Reporting unit](#units) ·
[Value of information](#voi) ·
[All rules at once](#screen) ·
[Reference condition](#reference) ·
[Fidelity](#fidelity) ·
[multi_EVPI()](#evpi) ·
[System boundary](#boundary) ·
[nb_from_mc()](#bridge) ·
[Printing results](#print) ·
[The Atacora analysis](#atacora) ·
[Tests](#tests) ·
[Extending the functions](#extend) ·
[References](#references)

<a id="functions"></a>

## Overview

A probabilistic decision model does not return one estimate of the future. It returns a large number of Monte Carlo draws, each representing one possible state of the world; together they span the range of what is considered possible. For every draw, the net benefit of every option for every group inside the model can be reported. The functions documented in this file are designed to make explicit how the net benefits become a recommendation and which valuation choices are made along the way. They allow these valuation choices to be varied and their outcomes to be reported side by side. Most functions correspond to one of the five design axes (Table 1). The system boundary (axis 1) is the exception: it is set as a deliberate choice before the model is built and therefore has no function ([System boundary](#boundary)). One function, `fidelity_threshold()`, lies across the three scaling directions, as fidelity does in the framework (H4). Another, `nb_from_mc()`, which sorts the columns of the simulation output by group and option without valuing them, provides that output for all subsequent analysis functions.

All results are computed after the model has run, to support the analysis of its results. The functions apply a valuation rule within each draw, and only then are the results averaged across draws (Eq. (2)). They implement five valuation rules: utilitarian, maximin, prioritarian, Atkinson, and a floor below which no group may fall.

Each section below first states what a function answers, gives its equation and applies it to one small worked example that can be recalculated by hand ([Worked example](#example)). A second part, *How the code works*, shows the R code of the function and explains it step by step, so that the code can be checked, reused and extended without the rest of the project. The code is reproduced as it stands in `R/`; only the documentation blocks (lines starting with `#'`) above each exported function in the source files are left out. The numbered markers `# (1)`, `# (2)`, … at the end of code lines are not part of the source: they refer to the notes directly below each code block. All functions are written in base R and can be applied to any model built with the *decisionSupport* package (Luedeling et al., 2025).

| Function | Axis | Question it answers |
|--------------------|----|------------------------------------|
| `nb_from_mc()` | – | Which columns of the simulation output belong to which group and option? |
| `w_utilitarian()`, `w_maximin()`, `w_prioritarian()`, `w_atkinson()`, `w_constrained()` | 4 | Under which fairness criterion are the net benefits of all groups in one draw combined into one number? |
| `marginalisation_count()` | 4 | In what share of draws does the aggregate gain while at least one group loses? |
| `reporting_units()`, `nb_array()` | 3 | Which groups are combined into which reporting units, with which coefficients, per outcome? |
| `voi_partition()`, `voh_index()` | 5 | What is perfect information worth jointly and for each group, and what is deciding per group worth? |
| `fairness_screen()` | 4, 5 | Do the recommendation, the value of information and hidden losses change between valuation rules? |
| `baseline_pair()` | 2 | Do the recommendation and each group's best option change between two reference conditions? |
| `fidelity_threshold()` | across the directions | What minimum share of an option's effect must arrive for it to stay ahead of every alternative? |
| `multi_EVPI()` (*decisionSupport*) | 5 | Which uncertain input is worth measuring for the decisive pair of options? |
| no function (set in the model) | 1 | Which accounts and outcomes enter the net benefit at all? |
| `print()` methods | – | How is a result shown on screen? |

*Table 1. Functions documented in this file. Axes are numbered as in the article: 1 system boundary, 2 reference condition, 3 reporting unit, 4 valuation rule, 5 actor-differentiated value of information.*


<a id="notation"></a>

## Notation

| Symbol | Meaning | In the code |
|---|---|---|
| $\theta_s$, $s = 1,\dots,S$ | one Monte Carlo draw of the uncertain inputs; all draws carry equal weight | a row |
| $d \in D$ | decision option; $d_0$ is the status quo, whose net benefit is zero by definition | a column |
| $g \in G$, $p_g$ | group and its share, with $\sum_g p_g = 1$ | an element of `nb_list`; `p` |
| $NB_g(d,\theta)$ | net benefit of option $d$ for group $g$ in draw $\theta$, measured against the reference condition | `nb_list$g[s, d]` |
| $NB(d,\theta)$ | vector of group net benefits, $\big(NB_1(d,\theta),\dots,NB_G(d,\theta)\big)$ | `nb` inside a rule |
| $W(NB;p)$ | valuation rule that turns the vector of group net benefits into a single number | `W`, `rules` |
| $\mathbb{E}_\theta$ | mean over all draws | `mean()`, `colMeans()` |
| $\lambda$, $\varepsilon$, $k$ | weight of a loss (prioritarian rule); inequality aversion and offset (Atkinson rule) | `u`, `eps`, `offset` |
| $f$ | share of an option's effect that arrives | `f` |

*Table 2. Notation.*

A group's net benefit is already a valuation whenever it combines several outcomes. In the Atacora model, the net benefit of a producer household adds its change in cash $y$, the hours its women save in hand hulling $t$, and the kilograms it eats at home $c$, each discounted over ten years:

```math
NB_G = y_G + \omega_W\, w_h\, t_G + \kappa\, p_f\, c_G , \qquad (1)
```

where $w_h$ is the hourly earning of hand hulling and $p_f$ the sale price of a kilogram of hulled fonio. The weights $\omega$ and $\kappa$ state what an hour and a kilogram are worth, as multiples of these two prices. Their weight follows from the model's settings, such as (i) money only ($\omega = \kappa = 0$); (ii) a behaviour-informed reference, in which a saved hour counts at replacement cost ($\omega_W = 1$), a paid huller's freed hour at a drawn fraction of the hulling wage, a kilogram at its market price ($\kappa = 1$); (iii) a preference-informed reference, in which every freed hour counts at the drawn value of an hour of off-farm work and a kilogram again at its market price.


<a id="example"></a>

## Worked example

One invented example runs through the following sections. It is kept small so that every number can be recalculated by hand. It has two groups, women and men, weighted equally ($p = \tfrac12, \tfrac12$). There are three options: the status quo $d_0$ and two alternatives, $d_X$ and $d_Y$. There are four equally likely draws. The figures are net benefits over the status quo (thousand USD).

| Draw | Women, $d_X$ | Women, $d_Y$ | Men, $d_X$ | Men, $d_Y$ |
|---|---:|---:|---:|---:|
| $\theta_1$ | 10 | 1 | 2 | 4 |
| $\theta_2$ | 8 | 2 | 0 | 2 |
| $\theta_3$ | 6 | 1 | −4 | 3 |
| $\theta_4$ | 0 | 2 | 2 | 3 |
| Mean | 6 | 1.5 | 0 | 3 |

*Table 3. Worked example: net benefits by draw, group and option (thousand USD).*

Option $d_X$ yields a large gain for women and is risky for men. Option $d_Y$ yields a small gain that is secure for both groups. Because group weights sum to one, every value reported below is on the scale of a group mean. With two groups of equal size, this is half the household total.

In R, the example is a named list with one matrix per group, draws in rows and options in columns, together with the vector of group shares. Every code example below uses these two objects:

```r
nb <- list(women = cbind(d0 = 0, dX = c(10, 8, 6, 0), dY = c(1, 2, 1, 2)),
           men   = cbind(d0 = 0, dX = c(2, 0, -4, 2), dY = c(4, 2, 3, 3)))
p  <- c(women = 0.5, men = 0.5)
```

`cbind()` binds columns side by side. The single `0` for `d0` is repeated down the column, so the status quo is zero in every draw. The functions call such a list an `nb_list`.


<a id="code"></a>

## How the code is organised

### Six design rules

The code follows six rules. Each one exists so that the functions stay transparent and can be used in other models than the Atacora model.

1. Functions are built generically, to be suited to different cases. No function is specifically designed for one specific crop, group, option or rule. Every variable arrives either through the data (the names of the list and of its columns) or through an argument. The functions run unchanged on any model whose output can be arranged as an `nb_list` ([Worked example](#example)).

2. Group shares `p`, the rule `W` or the list `rules`, the reference conditions and the reporting units have no preset value. Leaving one out stops the function with an error message that names the missing argument. A default such as `W = w_utilitarian()` would make exactly the silent choice that the article criticises. There are two deliberate exceptions from this rule: `voi_partition(differentiated = FALSE)` assumes one decision for all groups unless the user states that groups can be served separately, and `w_constrained(min_group_nb = 0)` sets the floor at "no group worse off than in the reference condition". 

3. No function adds outcomes of different kinds; each outcome is valued in a call of its own. Only `baseline_pair()` reports several outcomes side by side.

4. Every function applies the chosen valuation rule inside each draw first and averages afterwards (Eq. (2)). For a rule that is not a weighted sum, this gives a different number than applying the rule to averaged net benefits. 

5. The functions use only plain R language. They print nothing, write no files and draw no random numbers. They also add no package dependency.

6. Every function returns an ordinary R list or data frame with a class label, such as `voi_partition`. A separate `print()` method for each label (file `R/print_methods.R`) shows the result compactly on screen.


The functions are distributed over nine files in the folder `R/`:

| File | Contents |
|---|---|
| `utils.R` | the shared engine: input checks, the internal data structure, applying a rule |
| `welfare_functions.R` | the five valuation rules |
| `fairness_screen.R` | `fairness_screen()`, `marginalisation_count()` |
| `attributes.R` | `nb_array()`, `reporting_units()` |
| `voi_partition.R` | `voi_partition()`, `voh_index()`; internal: `partition_core()`, `resolve_profiles()` |
| `baseline_pair.R` | `baseline_pair()` |
| `fidelity_threshold.R` | `fidelity_threshold()` |
| `nb_from_mc.R` | `nb_from_mc()`; internal: `code_names()` |
| `print_methods.R` | the `print()` methods; internal: `round_df()` |

*Table 4. Files of the valuation functions.*

Loading all of them takes one line: `for (f in list.files("R", pattern = "[.]R$", full.names = TRUE)) source(f)`.


<a id="engine"></a>

## The shared engine

All functions rest on a few internal helpers in `R/utils.R`. Understanding them once makes every later function short to read.

**One internal object.** Every function starts by turning `nb_list` and `p` into one object, `obj`. Its core is a three-dimensional array `obj$u`: draws in rows, options in columns, and groups as layers, like a stack of equally sized spreadsheets, one per group. In the example, `obj$u` has the dimensions 4 × 3 × 2, and `obj$u[3, "dX", "men"]` is −4. (The letter `u` is only the name of this array in the code; the text writes $NB$.)

```r
prepare_nb <- function(nb_list, p) {
  st <- nb_structure(nb_list)  # (1)
  if (st$K > 1L)  # (2)
    stop("`nb_list` carries ", st$K, " outcomes (",  # (2)
         paste(st$outcomes, collapse = ", "), "). The functions value one ",  # (2)
         "outcome at a time: select it with nb_from_mc(), or use ",  # (2)
         "baseline_pair(), which reports every outcome.", call. = FALSE)  # (2)
  p <- resolve_p(p, st$groups)  # (3)
  u <- array(NA_real_, dim = c(st$S, st$D, st$G),  # (4)
             dimnames = list(NULL, st$options, st$groups))  # (4)
  for (g in seq_len(st$G)) u[, , g] <- st$arrs[[g]][, , 1L]  # (4)
  list(u = u, p = p, S = st$S, D = st$D, G = st$G,  # (5)
       groups = st$groups, options = st$options)  # (5)
}
```
1. `nb_structure()` checks the shape of the input: a named list of numeric matrices of equal size, with the same option names in the same order in every group (Table 6). It also accepts three-dimensional arrays with several outcomes and returns everything as arrays.
2. The valuation functions value one outcome per call (design rule 3). If the input carries several, the function stops and says which outcomes it found and how to select one.
3. `resolve_p()` checks the group shares and rescales them to sum to one (shown below).
4. An empty array of the right size is created first (`NA_real_` is R's missing number), then each group's matrix is copied into its layer. The notation `u[, , g]` means "all draws, all options, layer `g`".
5. The object carries the array, the shares, the three sizes `S`, `D`, `G` and the names of groups and options, so that later steps never have to recompute them.

**Selections.** One idea makes every quantity in this file the same computation. A *selection* states which option each group receives in each draw: a matrix with one row per draw and one column per group, filled with option numbers. One decision for all is a selection with the same option in every cell. Deciding per group gives each column its own option. Perfect information lets the option change from row to row. Once a selection is fixed, the rule is applied row by row and the results are averaged.

```r
const_sel <- function(obj, profile) {
  matrix(as.integer(profile), nrow = obj$S, ncol = obj$G, byrow = TRUE)  # (1)
}

# Each group's own best option in each draw (perfect information).
own_opt_sel <- function(obj) {
  matrix(vapply(seq_len(obj$G), function(g)  # (2)
    max.col(matrix(obj$u[, , g], nrow = obj$S), ties.method = "first"),  # (2)
    integer(obj$S)), nrow = obj$S, ncol = obj$G)  # (2)
}

select_u <- function(obj, sel) {
  idx <- cbind(rep(seq_len(obj$S), times = obj$G), as.vector(sel),  # (3)
               rep(seq_len(obj$G), each = obj$S))  # (3)
  matrix(obj$u[idx], nrow = obj$S, ncol = obj$G,  # (4)
         dimnames = list(NULL, obj$groups))  # (4)
}
```
1. `const_sel()` repeats one *profile* (one option per group) in every draw. `const_sel(obj, 2)` gives every group option 2 in every draw, because a single number is repeated for all groups; this is one decision for all. `const_sel(obj, c(2, 3))` gives women option 2 and men option 3 in every draw.
2. `own_opt_sel()` gives each group its own best option in each draw, which is what perfect information allows. For each group `g`, `max.col()` looks along each row of that group's layer and returns the column with the largest value; on ties it takes the first. `vapply()` repeats this for every group and collects the results as columns. In the example, women receive $d_X$ in the first three draws and $d_Y$ in the fourth, men $d_Y$ in every draw.
3. `select_u()` reads the net benefits that belong to a selection. It first builds an index table with three columns (draw, option, group) and one row per cell of the selection. For `const_sel(obj, 2)` in the example, the rows are (1, 2, 1), (2, 2, 1), (3, 2, 1), (4, 2, 1), (1, 2, 2), …, (4, 2, 2): `rep(..., times = G)` counts the draws once per group, `as.vector(sel)` reads the selection column by column, and `rep(..., each = S)` repeats each group number once per draw.
4. Indexing a three-dimensional array with such a table picks all the listed cells in one step. The result is reshaped into a matrix with one row per draw and one column per group: the net benefit each group receives under the selection.

**Applying a rule.** With a selection in hand, applying a rule is the same for every function.

```r
# W applied inside each draw: the S-vector of values of one selection.
welfare_post <- function(obj, W, sel) {
  us <- select_u(obj, sel)  # (1)
  vapply(seq_len(obj$S), function(s)  # (2)
    W(stats::setNames(us[s, ], obj$groups), obj$p), numeric(1))  # (2)
}

# The S x D matrix of W for one decision for all: column d gives every group d.
welfare_matrix <- function(obj, W) {
  w_sd <- matrix(NA_real_, nrow = obj$S, ncol = obj$D,  # (3)
                 dimnames = list(NULL, obj$options))
  for (d in seq_len(obj$D)) w_sd[, d] <- welfare_post(obj, W, const_sel(obj, d))  # (4)
  w_sd
}
```
1. The net benefits the groups receive under the selection, one row per draw.
2. The rule `W` is called once per draw, on that draw's row, together with the shares. The row is labelled with the group names, so that a rule may use them. `vapply(..., numeric(1))` insists that every call returns exactly one number; a rule that returns anything else stops the calculation with an error instead of producing a silent wrong result. The output is one value per draw: the vector inside $\mathbb{E}_\theta\, W(\cdot)$ in Eq. (2).
3. `welfare_matrix()` prepares a matrix with one row per draw and one column per option.
4. Column `d` is the rule's value, in each draw, of giving every group option `d`. This matrix is the basis of the recommendation, of the value of perfect information and of the share of draws in which an option leads.

For the example and the utilitarian rule, `welfare_matrix()` returns the following matrix. Its column means are the values of the options, and the mean of its row maxima is the value under perfect information ([Value of information](#voi)):

| Draw | $d_0$ | $d_X$ | $d_Y$ |
|---|---:|---:|---:|
| $\theta_1$ | 0 | 6 | 2.5 |
| $\theta_2$ | 0 | 4 | 2 |
| $\theta_3$ | 0 | 1 | 2 |
| $\theta_4$ | 0 | 1 | 2.5 |
| Mean | 0 | 3.00 | 2.25 |

*Table 5. Output of the internal helper `welfare_matrix()` for the worked example and the utilitarian rule.*

Two further helpers count losses and list profiles:

```r
# Per draw, does option d leave a group below zero, and does the aggregate
# (the rule itself) show a gain at the same time?
loss_shares <- function(obj, W, d, w_sd = NULL) {
  below <- matrix(obj$u[, d, ] < 0, nrow = obj$S, ncol = obj$G,  # (1)
                  dimnames = list(NULL, obj$groups))  # (1)
  gain <- if (is.null(w_sd)) welfare_post(obj, W, const_sel(obj, d)) > 0  # (2)
          else w_sd[, d] > 0  # (2)
  list(any_loss = mean(rowSums(below) > 0),  # (3)
       hidden_loss = mean(gain & rowSums(below) > 0),  # (4)
       hidden_loss_by_group = colMeans(gain & below))  # (5)
}
```
1. A table of `TRUE` and `FALSE`: is group `g` below zero under option `d` in draw `s`?
2. Does the rule show a gain for option `d` in each draw? If the matrix of rule values has been computed already, it is reused instead of recomputed.
3. The share of draws in which at least one group loses. `rowSums()` counts the losing groups per draw; the mean of a `TRUE`/`FALSE` vector is the share of `TRUE`.
4. The share of draws in which the rule shows a gain *and* at least one group loses: the hidden loss of [Hidden losses](#marginalisation).
5. The same share per group.

```r
profile_grid <- function(obj, max_profiles) {
  n_prof <- obj$D^obj$G  # (1)
  if (n_prof > max_profiles)  # (1)
    stop("A decision per group would enumerate ", n_prof, " profiles of ",  # (1)
         "options (limit `max_profiles` = ", format(max_profiles), ").",  # (1)
         call. = FALSE)  # (1)
  as.matrix(expand.grid(rep(list(seq_len(obj$D)), obj$G)))  # (2)
}

which_max1 <- function(x) {
  if (all(is.na(x))) return(NA_integer_)  # (3)
  which.max(x)[1L]  # (4)
}
```
1. With $D$ options and $G$ groups there are $D^G$ ways to give each group its own option. Five options and ten groups would already give nearly ten million; above a limit the function refuses instead of running for hours.
2. `expand.grid()` lists every combination, one row per profile and one column per group. With three options and two groups, it lists nine profiles, from (1, 1) to (3, 3).
3. `which_max1()` returns the position of the largest value. If every value is missing, it returns a missing position instead of failing.
4. On ties, the first position wins. Results therefore never depend on chance, and the order of the options decides between exact ties.

<a id="checks"></a>

### Input checks

Most lines of each function check its input. A wrong input stops the function with a message that names the problem, instead of producing a number that looks plausible but is wrong. The checks are collected in small helpers:

| Helper | What it checks |
|---|---|
| `stop_missing()` | writes the error message when an argument without default is missing |
| `check_rule()`, `check_rules()` | a rule is a function; `rules` is a non-empty list of functions with unique names, which label the output |
| `nb_structure()` | `nb_list` is a non-empty list of numeric matrices (draws × options) or arrays (draws × options × outcomes) of equal size, with unique group names; matrices are turned into arrays with one outcome |
| `common_names()` | option and outcome names are identical and in the same order in every group; unnamed options receive the names `option_1`, `option_2`, … |
| `resolve_p()` | one finite, non-negative share per group, not all zero; aligned by name if named; rescaled to sum to one |
| `resolve_profiles()` | the allowed profiles of `voi_partition()` ([Value of information](#voi)) |
| `code_names()` | the codes of `nb_from_mc()` ([nb_from_mc()](#bridge)) |

*Table 6. Input checks shared by the functions.*

`resolve_p()` does more than check, so it is shown here:

```r
resolve_p <- function(p, groups) {
  nG <- length(groups)
  if (!is.numeric(p) || length(p) != nG)  # (1)
    stop("`p` must be a numeric vector with one share per group (", nG,  # (1)
         " expected).", call. = FALSE)  # (1)
  if (!is.null(names(p)) && all(nzchar(names(p)))) {  # (2)
    if (!setequal(names(p), groups) || anyDuplicated(names(p)))  # (2)
      stop("The names of `p` do not match the groups in `nb_list`.",  # (2)
           call. = FALSE)  # (2)
    p <- p[groups]  # (2)
  }
  if (any(!is.finite(p)) || any(p < 0))  # (3)
    stop("`p` must be finite and non-negative.", call. = FALSE)  # (3)
  if (sum(p) <= 0) stop("`p` must not sum to zero.", call. = FALSE)  # (3)
  stats::setNames(as.numeric(p) / sum(p), groups)  # (4)
}
```
1. One share per group.
2. If the shares carry names, they are matched to the groups by name, not by position. `p = c(men = 1, women = 3)` therefore gives women 0.75 even though women come first in `nb_list`.
3. Shares must be finite and non-negative and must not all be zero.
4. The shares are divided by their sum. `p = c(1, 1)` and `p = c(0.5, 0.5)` therefore give the same result, the mean of the two groups, and `p = 1` for a single group leaves its net benefit unchanged. To report a sum instead of a mean, multiply the result by the number of groups, as the Atacora analysis does for household types ([Value of information](#voi)), or form a sum with `reporting_units()` ([Reporting unit](#units)).

The remaining checks are shown in full below, in the order in which a call meets them.

**Missing arguments and rules.**

```r
stop_missing <- function(name, hint) {
  stop("`", name, "` has no default and must be given explicitly: ", hint,  # (1)
       call. = FALSE)  # (2)
}
```
1. One message is built from the name of the missing argument and a hint that says why the argument is a choice. `w_prioritarian()` without a transform, for example, stops with the message: *u has no default and must be given explicitly: the transform is a valuation, e.g. a loss counting twice.*
2. `call. = FALSE` leaves the internal function call out of the message, so the user reads only the sentence. Every error message in `R/` is written this way.

```r
check_rule <- function(W, name = "W") {
  if (!is.function(W))  # (1)
    stop("`", name, "` must be a valuation rule: a function(nb, p) returning ",  # (1)
         "one number, e.g. w_utilitarian().", call. = FALSE)  # (1)
  invisible(W)  # (2)
}
```
1. The rule must be a function. Whether it returns exactly one number is checked later, in every draw, by `vapply(..., numeric(1))` in `welfare_post()` ([The shared engine](#engine)). A frequent slip passes this first check: `W = w_utilitarian` hands over the factory instead of the rule `w_utilitarian()`. The factory is a function too, so the error only appears at the first call, as "unused arguments".
2. The rule is returned unchanged and invisibly: the helper is called for its check, not for its value.

```r
check_rules <- function(rules) {
  if (!is.list(rules) || length(rules) == 0L)  # (1)
    stop("`rules` must be a non-empty list of valuation rules.", call. = FALSE)  # (1)
  if (!all(vapply(rules, is.function, logical(1))))  # (2)
    stop("Every element of `rules` must be a valuation function.", call. = FALSE)  # (2)
  if (is.null(names(rules)) || any(!nzchar(names(rules))) ||  # (3)
      anyDuplicated(names(rules)))  # (3)
    stop("`rules` must be named, uniquely: the names label the output.",  # (3)
         call. = FALSE)  # (3)
  invisible(rules)  # (4)
}
```
1. `rules` must be a list with at least one element. A single rule that is not wrapped in `list()` is refused, because a function is not a list.
2. Every element must be a function.
3. Every rule needs a name, and the names must be unique, because they label the rows of the output of `fairness_screen()` and `baseline_pair()`. `list(w_utilitarian())` is therefore refused; `list(utilitarian = w_utilitarian())` is accepted.
4. As in `check_rule()`, the list is returned invisibly.

**The shape of `nb_list`.** `nb_structure()` is called first by every function that takes an `nb_list`. It values nothing; it only checks the shape and brings every group into the same form.

```r
nb_structure <- function(nb_list) {
  if (!is.list(nb_list) || is.data.frame(nb_list) || length(nb_list) == 0L)  # (1)
    stop("`nb_list` must be a non-empty list of matrices or arrays.",  # (1)
         call. = FALSE)  # (1)
  shape_ok <- vapply(nb_list, function(m)  # (2)
    is.numeric(m) && is.array(m) && length(dim(m)) %in% c(2L, 3L), logical(1))  # (2)
  if (!all(shape_ok))  # (2)
    stop("Every element of `nb_list` must be a numeric draws x options matrix ",  # (2)
         "or a draws x options x outcomes array.", call. = FALSE)  # (2)

  was_matrix <- vapply(nb_list, is.matrix, logical(1))  # (3)
  arrs <- lapply(nb_list, function(m) {  # (3)
    if (is.matrix(m)) {  # (3)
      array(m, dim = c(dim(m), 1L), dimnames = list(NULL, colnames(m), NULL))  # (3)
    } else {  # (3)
      m  # (3)
    }  # (3)
  })  # (3)

  dims <- matrix(vapply(arrs, dim, integer(3)), nrow = 3L)  # (4)
  if (any(dims != dims[, 1L]))  # (4)
    stop("All elements of `nb_list` must have the same dimensions ",  # (4)
         "(draws x options x outcomes).", call. = FALSE)  # (4)
  nS <- dims[1L, 1L]; nD <- dims[2L, 1L]; nK <- dims[3L, 1L]  # (5)
  if (nS < 1L || nD < 1L || nK < 1L)  # (5)
    stop("`nb_list` needs at least one draw, one option and one outcome.",  # (5)
         call. = FALSE)  # (5)

  groups <- names(nb_list)  # (6)
  if (is.null(groups)) groups <- paste0("group_", seq_along(arrs))  # (6)
  if (any(is.na(groups)) || any(!nzchar(groups)) || anyDuplicated(groups))  # (6)
    stop("The names of `nb_list` (the groups) must be non-empty and unique.",  # (6)
         call. = FALSE)  # (6)

  options <- common_names(lapply(arrs, function(a) dimnames(a)[[2L]]),  # (7)
                          paste0("option_", seq_len(nD)),  # (7)
                          "Column names (options)")  # (7)
  outcomes <- common_names(lapply(arrs, function(a) dimnames(a)[[3L]]),  # (7)
                           if (nK == 1L) "nb" else paste0("outcome_", seq_len(nK)),  # (7)
                           "Outcome names")  # (7)

  list(arrs = arrs, S = nS, D = nD, G = length(arrs), K = nK, groups = groups,  # (8)
       options = options, outcomes = outcomes, was_matrix = all(was_matrix))  # (8)
}
```
1. `nb_list` must be a list with at least one element. A data frame is refused explicitly, because in R a data frame is also a list (of columns) and would otherwise slip through.
2. Every element must be numeric and have two dimensions (a matrix: draws × options) or three (an array: draws × options × outcomes). `vapply(..., logical(1))` collects one `TRUE` or `FALSE` per group.
3. Each matrix is turned into an array with a third dimension of length one, keeping its column names, so that all later steps can treat one outcome and several outcomes alike. `was_matrix` remembers which elements came as matrices.
4. `vapply(arrs, dim, integer(3))` collects the three sizes of every group as the columns of a 3 × G matrix. `dims != dims[, 1L]` compares every column with the first one: R repeats the first column down the matrix, so a group that differs in the number of draws, options or outcomes is found.
5. The three sizes are read once, and each must be at least one.
6. The group names are the names of the list. An unnamed list receives the names `group_1`, `group_2`, …; a list in which only some elements are named is refused, as are duplicated names.
7. The option names (columns) and outcome names (third dimension) are checked by `common_names()` (below). If no group carries names, options are called `option_1`, `option_2`, …; a single outcome is called `nb`, several outcomes `outcome_1`, `outcome_2`, ….
8. The result carries the arrays, the sizes `S`, `D`, `G`, `K`, the names, and `was_matrix`, which is `TRUE` only if every element came as a matrix. `reporting_units()` uses it to return matrices again ([Reporting unit](#units)).

```r
common_names <- function(name_list, default, what) {
  present <- Filter(Negate(is.null), name_list)  # (1)
  nm <- if (length(present)) present[[1L]] else default  # (2)
  for (x in present)  # (3)
    if (!identical(x, nm))  # (3)
      stop(what, " differ between groups; they must be identical and in the ",  # (3)
           "same order in every element of `nb_list`.", call. = FALSE)  # (3)
  if (any(!nzchar(nm)) || anyDuplicated(nm))  # (4)
    stop(what, " must be non-empty and unique.", call. = FALSE)  # (4)
  nm  # (5)
}
```
1. `Filter(Negate(is.null), ...)` keeps the name vectors that exist. A group whose matrix has no column names is skipped here; its columns are later read by position.
2. The reference is the first set of names found, or the default if no group has names.
3. Every group that carries names must carry exactly the same names in the same order. `identical()` is strict: `c("dX", "dY")` and `c("dY", "dX")` differ, so two groups with swapped columns stop the function instead of being compared option against wrong option.
4. Names must not be empty and must not repeat.
5. The common names are returned.

`resolve_p()` (above) follows next in every call. The two remaining checks belong to single functions.

**Allowed profiles for `voi_partition()`.**

```r
resolve_profiles <- function(profiles, obj, max_profiles) {
  if (is.data.frame(profiles)) profiles <- as.matrix(profiles)  # (1)
  if (!is.matrix(profiles) || !(is.character(profiles) || is.numeric(profiles)) ||  # (2)
      nrow(profiles) < 1L || ncol(profiles) != obj$G)  # (2)
    stop("`profiles` must be a matrix with at least one row and one column ",  # (2)
         "per group (", obj$G, " expected).", call. = FALSE)  # (2)
  cn <- colnames(profiles)  # (3)
  if (!is.null(cn)) {  # (3)
    if (anyDuplicated(cn) || !setequal(cn, obj$groups))  # (3)
      stop("The column names of `profiles` do not match the groups in ",  # (3)
           "`nb_list`.", call. = FALSE)  # (3)
    profiles <- profiles[, obj$groups, drop = FALSE]  # (3)
  }  # (3)
  if (nrow(profiles) > max_profiles)  # (4)
    stop("`profiles` lists ", nrow(profiles), " profiles (limit ",  # (4)
         "`max_profiles` = ", format(max_profiles), ").", call. = FALSE)  # (4)
  idx <- if (is.character(profiles)) match(profiles, obj$options) else {  # (5)
    v <- as.vector(profiles)  # (5)
    ifelse(is.finite(v) & v == round(v), v, NA_real_)  # (5)
  }  # (5)
  idx <- matrix(as.integer(idx), nrow = nrow(profiles), ncol = obj$G,  # (6)
                dimnames = list(NULL, obj$groups))  # (6)
  if (anyNA(idx) || any(idx < 1L) || any(idx > obj$D))  # (7)
    stop("Every entry of `profiles` must be an option name or an option ",  # (7)
         "index of `nb_list`.", call. = FALSE)  # (7)
  if (anyDuplicated(idx))  # (8)
    stop("`profiles` lists the same profile more than once.", call. = FALSE)  # (8)
  idx  # (9)
}
```
1. A data frame is turned into a matrix first.
2. `profiles` must be a matrix of option names or option numbers, with at least one row and exactly one column per group.
3. If the columns are named, the names must be exactly the groups. The columns are then put into the order of the groups, so `cbind(men = ..., women = ...)` works as well as the reverse. Without column names, the columns are read in the order of `nb_list`.
4. More profiles than `max_profiles` are refused, as in `profile_grid()`.
5. Option names are translated into option numbers with `match()`; an unknown name becomes `NA`. Numbers are kept only if they are finite whole numbers; 2.5, for example, becomes `NA`.
6. The result is an integer matrix with one row per profile and one column per group.
7. Any `NA` or any number outside 1 to $D$ stops the function, so a typing error in an option name is caught here.
8. `anyDuplicated()` applied to a matrix looks for repeated rows: the same profile may not be listed twice.
9. The checked matrix of option numbers is returned to `voi_partition()`.

**Codes for `nb_from_mc()`.**

```r
code_names <- function(codes, what) {
  if (!is.character(codes) || length(codes) == 0L || anyNA(codes) ||  # (1)
      any(!nzchar(codes)))  # (1)
    stop("`", what, "` must be a non-empty character vector of codes.",  # (1)
         call. = FALSE)  # (1)
  nm <- names(codes)  # (2)
  if (is.null(nm)) nm <- codes  # (2)
  nm[is.na(nm) | !nzchar(nm)] <- codes[is.na(nm) | !nzchar(nm)]  # (2)
  if (anyDuplicated(nm) || anyDuplicated(codes))  # (3)
    stop("The codes in `", what, "` and their names must be unique.",  # (3)
         call. = FALSE)  # (3)
  stats::setNames(codes, nm)  # (4)
}
```
1. The codes must be a non-empty character vector without missing or empty entries.
2. The labels are the names of the vector. A code without a name is its own label, also within a partly named vector: `c(households = "G", "H")` gives the labels `households` and `H`.
3. Labels and codes must both be unique.
4. The result is a named vector: the values are the strings searched for in the column names, the names are the labels used in the result.


<a id="rules"></a>

## Valuation rule (axis 4): `w_utilitarian()`, `w_maximin()`, `w_prioritarian()`, `w_atkinson()`, `w_constrained()`

The value of an option and the recommended option are

```math
V(d) = \mathbb{E}_\theta\, W\big(NB(d,\theta);\,p\big),
\qquad
d^{*} = \arg\max_{d \in D}\, V(d). \qquad (2)
```

A valuation rule turns the vector of group net benefits into one number. The three basic rules are

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
\end{aligned} \qquad (3)
```

Two further rules extend them:

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
\end{aligned} \qquad (4)
```

- **Utilitarian:** adds group net benefits, weighted by group size. This rule is generally implied whenever a single aggregate net present value is reported.
- **Maximin:** values an option by the group that is worse off in each draw. It ignores the weights $p$.
- **Prioritarian:** lies between the two. The parameter $\lambda$ states how much more a loss weighs than a gain of the same size; in the example, $\lambda = 2$. The parameter $\lambda$ is a context-specific model parameter that must be elicited together with experts and local groups. The function accepts any increasing transform $\varphi$; $\varphi_\lambda$ is the form used here.
- **Atkinson:** the equally distributed equivalent (Atkinson et al., 2009): the net benefit which, if every group received it, would be valued as highly as the actual unequal net benefits. The parameter $\varepsilon$ states inequality aversion. With $\varepsilon = 0$ the rule is utilitarian, and as $\varepsilon$ grows it approaches maximin. The index is defined only for positive quantities, while net benefits can be negative. The function therefore adds a constant $k$ (the offset) to every net benefit, evaluates the index and subtracts $k$ again. Subtracting $k$ keeps $\varepsilon = 0$ equal to the utilitarian value for any $k$, but $k$ changes how strongly the index bends, and with it the result.
- **Floor:** a side condition rather than a ranking. An option that leaves any group below $m$ in a draw is valued at $-\infty$ in that draw, so that averaged over the draws it is excluded as soon as one draw violates the floor. Otherwise the rule is utilitarian. With $m = 0$, no group may be worse off than in the reference condition.

| Rule | Function | $V(d_X)$ | $V(d_Y)$ | $d^{*}$ |
|----------|-----------|----:|----:|----|
| Utilitarian | `w_utilitarian()` | 3.00 | 2.25 | $d_X$ |
| Maximin | `w_maximin()` | −0.50 | 1.50 | $d_Y$ |
| Prioritarian, $\lambda = 2$ | `w_prioritarian()` | 2.50 | 2.25 | $d_X$ |
| Atkinson, $\varepsilon = 1$, $k = 10$ | `w_atkinson(1, offset = 10)` | 2.42 | 2.21 | $d_X$ |
| Atkinson, $\varepsilon = 2$, $k = 10$ | `w_atkinson(2, offset = 10)` | 1.87 | 2.18 | $d_Y$ |
| Floor, $m = 0$ | `w_constrained(0)` | $-\infty$ | 2.25 | $d_Y$ |

*Table 7. Value of each option under the five rules, worked example ($V(d_0) = 0$ throughout).*

Applying the rule within each draw keeps losses visible that a mean would hide. The mean net benefit of men under $d_X$ is zero, yet men lose 4 in draw $\theta_3$. Maximin applied to the means would value $d_X$ at $\min(6, 0) = 0$. Applied within each draw, it values $d_X$ at $-0.50$. The floor excludes $d_X$ for the same draw, while $d_Y$ passes because no group ever loses under it.

The two Atkinson rows show that the recommendation moves with $\varepsilon$. The offset matters as well: with $k = 5$ instead of 10, $\varepsilon = 1$ already recommends $d_Y$ (1.89 against 2.19). The offset is therefore a valuation choice and is reported with the results. In the Atacora analysis, $k$ is the median discounted money a producer household earns from fonio in the status quo; if the largest loss of any producer household or paid huller in any draw reaches that value, $k$ is raised to the next multiple of 100,000 FCFA above that loss.

Each rule function returns a function and not a single value. This allows the rule to be passed as an argument to every other function. The fairness criterion becomes a model input rather than a fixed feature of the analysis. Every rule must also be non-decreasing: raising one group's net benefit must never lower the value. The results on signs in [Value of information](#voi) rely on this condition. The five rules meet it, the floor in the weak sense (the value can jump from $-\infty$ to a finite number, but never falls), and the Atkinson rule wherever it is defined.

### How the code works

All five rules follow one contract, stated at the top of `R/welfare_functions.R`: a rule is a function of two arguments, the vector `nb` of the group net benefits in one draw and the vector `p` of shares, and it returns one number. Anyone can write a new rule that keeps this contract and pass it to every function in this file ([Extending the functions](#extend)).

```r
w_utilitarian <- function() {  # (1)
  function(nb, p) sum(p * nb)  # (2)
}

w_maximin <- function() {
  function(nb, p) min(nb)  # (3)
}

w_prioritarian <- function(u) {
  if (missing(u))  # (4)
    stop_missing("u", "the transform is a valuation, e.g. a loss counting twice.")  # (4)
  if (!is.function(u)) stop("`u` must be a function.", call. = FALSE)  # (4)
  force(u)  # (5)
  function(nb, p) sum(p * u(nb))  # (6)
}
```
1. `w_utilitarian()` is a *factory*: calling it returns the inner function, and that inner function is what the other functions receive as `W`. The empty brackets mean that this rule needs no parameter.
2. The rule itself. `p * nb` multiplies each group's net benefit by its share, element by element, and `sum()` adds the products. For draw $\theta_3$ and option $d_X$: $0.5 \times 6 + 0.5 \times (-4) = 1$.
3. Maximin takes the smallest group net benefit. It accepts `p` so that all rules have the same two arguments and can be exchanged freely, but it does not use it; that is the point of the rule.
4. The transform has no default, because it is a valuation. `missing(u)` tests whether it was given at all; `is.function(u)` tests that it is a function.
5. R evaluates an argument only when it is first used. `force(u)` evaluates it at once, when the rule is created. Without it, a rule could silently pick up a transform that was changed afterwards.
6. The transform is applied to every group's net benefit, then the results are weighted and added.

In the example, the prioritarian rule is created and used as follows (an illustration, not part of the source files):

```r
loss_twice <- function(z) ifelse(z < 0, 2 * z, z)  # a loss counts twice
W <- w_prioritarian(loss_twice)
W(c(6, -4), c(0.5, 0.5))                           # draw 3, option dX: returns -1
```

```r
w_atkinson <- function(eps, offset = 0) {
  if (missing(eps))  # (1)
    stop_missing("eps", "the inequality aversion is a valuation, e.g. eps = 1.")  # (1)
  if (!is.numeric(eps) || length(eps) != 1L || !is.finite(eps) || eps < 0)  # (1)
    stop("`eps` must be a single finite number >= 0.", call. = FALSE)  # (1)
  if (!is.numeric(offset) || length(offset) != 1L || !is.finite(offset))  # (1)
    stop("`offset` must be a single finite number.", call. = FALSE)  # (1)
  force(eps); force(offset)  # (2)
  function(nb, p) {
    x <- nb + offset  # (3)
    if (any(!is.finite(x)) || any(x <= 0)) {  # (4)
      warning("w_atkinson(): non-positive group value; returning NA. ",  # (4)
              "Supply an `offset` that moves all net benefits above zero.",  # (4)
              call. = FALSE)  # (4)
      return(NA_real_)  # (4)
    }
    if (isTRUE(all.equal(eps, 1))) {  # (5)
      exp(sum(p * log(x))) - offset  # (5)
    } else {
      sum(p * x^(1 - eps))^(1 / (1 - eps)) - offset  # (6)
    }
  }
}
```
1. The inequality aversion `eps` must be given and must be one finite number of at least zero; the offset must be one finite number.
2. Both parameters are fixed when the rule is created (see note 5 above).
3. Every net benefit is shifted by the offset.
4. If any shifted value is zero or negative, the index is undefined. The rule then warns and returns `NA`, R's missing value, instead of a number. The warning tells the user to choose a larger offset. With the example and no offset, $d_X$ in draw $\theta_3$ triggers it, because men's value is −4.
5. For $\varepsilon = 1$ the general formula would divide by zero; its limit is the weighted geometric mean, $\exp(\sum_g p_g \ln x_g)$. `isTRUE(all.equal(eps, 1))` also catches values that differ from 1 only by rounding. The offset is subtracted again.
6. The general formula of Eq. (4), shifted back by the offset.

```r
w_constrained <- function(min_group_nb = 0) {
  if (!is.numeric(min_group_nb) || length(min_group_nb) != 1L)  # (1)
    stop("`min_group_nb` must be a single number.", call. = FALSE)  # (1)
  force(min_group_nb)  # (2)
  function(nb, p) {
    if (any(nb < min_group_nb)) -Inf else sum(p * nb)  # (3)
  }
}
```
1. The floor must be one number. Its default, zero, is one of the two documented exceptions to design rule 2.
2. The floor is fixed when the rule is created.
3. If any group is below the floor in this draw, the value is minus infinity (`-Inf`); otherwise the utilitarian value. Because the mean of a set of numbers that contains `-Inf` is `-Inf`, a single violating draw excludes the option once the values are averaged.

The floor can be passed to `fairness_screen()` like any other rule, and the screen then also reports a value of perfect information for it (1.375 in the example). That number mixes a constraint with a ranking: with perfect information the floor is checked draw by draw, so an option excluded today can be chosen in the draws in which no group loses. The Atacora analysis therefore reports the floor only as admissibility, that is, which options pass it, never with a value or a value of information.


<a id="marginalisation"></a>

## Hidden losses (axis 4): `marginalisation_count()`

`marginalisation_count()` reports the share of draws in which the recommended option gains in aggregate while at least one group loses:

```math
M = \frac{1}{S} \sum_{s=1}^{S}
\mathbf{1}\Big[\, W\big(NB(d^{*},\theta_s)\big) > 0 \;\wedge\; \min_{g}\, NB_g(d^{*},\theta_s) < 0 \,\Big]. \qquad (5)
```

In the example with the utilitarian rule, $d^{*} = d_X$. In draw $\theta_3$ the aggregate is positive ($+1$) while men lose 4, so $M = 1/4 = 25\,\%$. For $d_Y$, $M = 0$. A mean over draws does not reveal this share. The function also reports $M$ per group: 25 % for men and 0 for women.

The share depends on the rule that forms the aggregate. Under the prioritarian rule with $\lambda = 2$, the aggregate of $d_X$ in draw $\theta_3$ is $0.5 \times 6 + 0.5 \times (-8) = -1$, which is not a gain, so $M = 0$: the rule has already counted the loss. Under maximin, $M$ is always zero, because the worst-off group cannot be below zero while the rule shows a gain. Instead of the recommended option, any option can be named with the argument `d_star`. The Atacora analysis does so for H1, to count how often the pooled account of women gains while paid hullers lose under each option.

### How the code works

```r
marginalisation_count <- function(nb_list, p, W, d_star = NULL) {
  if (missing(p))  # (1)
    stop_missing("p", "group shares are a choice of reporting unit.")  # (1)
  if (missing(W))  # (1)
    stop_missing("W", "the rule that forms the aggregate, e.g. w_utilitarian().")  # (1)
  check_rule(W)  # (1)
  obj <- prepare_nb(nb_list, p)  # (2)

  w_sd <- welfare_matrix(obj, W)  # (3)
  if (is.null(d_star)) {  # (4)
    crit <- colMeans(w_sd)  # (4)
    if (anyNA(crit))  # (4)
      stop("The value of some option is undefined (NA) under `W`; pass ",  # (4)
           "`d_star` explicitly or fix the rule.", call. = FALSE)  # (4)
    d_idx <- which_max1(crit)  # (4)
  } else {
    d_idx <- if (is.character(d_star)) match(d_star, obj$options)  # (5)
             else suppressWarnings(as.integer(d_star))  # (5)
    if (length(d_idx) != 1L || is.na(d_idx) || d_idx < 1L || d_idx > obj$D)  # (5)
      stop("`d_star` does not identify an option of `nb_list`.", call. = FALSE)  # (5)
  }

  ls <- loss_shares(obj, W, d_idx, w_sd)  # (6)
  out <- list(share = ls$hidden_loss,  # (7)
              by_group = data.frame(group = obj$groups,  # (7)
                                    share = as.numeric(ls$hidden_loss_by_group),  # (7)
                                    row.names = NULL, stringsAsFactors = FALSE),  # (7)
              d_star = obj$options[d_idx], n_draws = obj$S, p = obj$p)  # (7)
  class(out) <- c("marginalisation_count", "list")  # (7)
  out
}
```
1. Shares and rule must be given (design rule 2), and the rule must be a function.
2. The input is checked and turned into the internal object ([The shared engine](#engine)).
3. The rule's value for every draw and option (Table 5).
4. Without `d_star`, the option with the highest mean value under the rule is evaluated. If the rule is undefined for some option (an Atkinson rule without a sufficient offset), the function stops and asks for an explicit option.
5. With `d_star`, the option may be given by name (`"dX"`) or by column number (`2`); `match()` turns a name into its column number. Anything that does not identify exactly one option stops the function.
6. The counting itself is done by `loss_shares()` ([The shared engine](#engine)).
7. The result is a list with the overall share, a small table with the share per group, the evaluated option and the number of draws, labelled `marginalisation_count` for printing.


<a id="units"></a>

## Reporting unit (axis 3): `reporting_units()` and `nb_array()`

`reporting_units()` forms new reporting units $k$ as linear combinations of groups:

```math
NB_k(d,\theta) = \sum_{g} c_{kg}\, NB_g(d,\theta). \qquad (6)
```

The coefficients $c_{kg}$ are an argument without a default. A household formed as women plus men is a sum ($c = 1, 1$). Women from two communes reported together form a weighted mean ($c$ = population shares). Both are valuation choices. In the Atacora analysis, the pooled account of women in H1 is a weighted mean of the women in producer households and the paid hullers, with coefficients 0.8 and 0.2: one woman per producer household and 0.25 paid hullers.

In the example, the household unit gives $V(d_X) = 6.0$ and $V(d_Y) = 4.5$, and $d_X$ is recommended. This unit hides two facts: that $d_X$ harms men in one draw, and that the two groups favour different options.

Under the utilitarian rule, merging groups into fewer units leaves the aggregate unchanged. $A$ and $C$ in [Value of information](#voi) therefore stay the same, while $B$ and $D$ can only decrease. With a single unit, $B = A$ and $D = C$, so the value of allowing group-specific options is zero by construction. The reporting unit thus limits how much difference between groups can become visible at all.

`nb_array()` is a small helper for several outcomes. It stacks the matrices of one group, for example money, hours and kilograms, into a three-dimensional array (draws × options × outcomes). `reporting_units()` and `baseline_pair()` accept such arrays and treat each outcome separately; they never add different outcomes together.

### How the code works

```r
reporting_units <- function(nb_list, units) {
  st <- nb_structure(nb_list)  # (1)
  if (missing(units))  # (2)
    stop_missing("units", "a named list of named coefficient vectors.")  # (2)
  if (!is.list(units) || length(units) == 0L)  # (2)
    stop("`units` must be a non-empty named list.", call. = FALSE)  # (2)
  un <- names(units)  # (2)
  if (is.null(un) || any(!nzchar(un)) || anyDuplicated(un))  # (2)
    stop("`units` must be named, uniquely.", call. = FALSE)  # (2)

  out <- lapply(un, function(u) {  # (3)
    coef <- units[[u]]  # (4)
    if (!is.numeric(coef) || length(coef) == 0L || any(!is.finite(coef)))  # (4)
      stop("Unit '", u, "': coefficients must be finite numbers.", call. = FALSE)  # (4)
    cg <- names(coef)  # (4)
    if (is.null(cg) || any(!nzchar(cg)) || anyDuplicated(cg))  # (4)
      stop("Unit '", u, "': coefficients must be named by group, uniquely.",  # (4)
           call. = FALSE)  # (4)
    unknown <- setdiff(cg, st$groups)  # (4)
    if (length(unknown))  # (4)
      stop("Unit '", u, "' refers to unknown group(s): ",  # (4)
           paste(unknown, collapse = ", "), ".", call. = FALSE)  # (4)
    acc <- Reduce(`+`, Map(function(g, w) w * st$arrs[[g]], cg, coef))  # (5)
    dimnames(acc) <- list(NULL, st$options, st$outcomes)  # (6)
    if (st$was_matrix) {  # (6)
      matrix(acc[, , 1L], nrow = st$S, dimnames = list(NULL, st$options))  # (6)
    } else {  # (6)
      acc  # (6)
    }  # (6)
  })  # (6)
  stats::setNames(out, un)  # (6)
}
```
1. The input is checked; every group is held as an array, even if it came as a matrix.
2. `units` has no default. It must be a named list: each name is a new unit, each element a vector of coefficients named by group, for example `list(household = c(women = 1, men = 1))`.
3. `lapply()` builds the units one after another.
4. The coefficients of each unit must be finite numbers, named by existing groups. A typing error in a group name therefore stops the function instead of silently dropping that group.
5. The central line. `Map()` goes through the group names and coefficients in pairs and multiplies each group's array by its coefficient; `Reduce()` adds the results. For the household: $1 \times$ women $+ 1 \times$ men, draw by draw and option by option.
6. The new unit receives the option and outcome names. If every input was a matrix, the unit is returned as a matrix too, so the result can be passed on to every other function. The list of units is named after the units.

```r
nb_array <- function(...) {
  mats <- list(...)  # (1)
  if (length(mats) == 1L && is.list(mats[[1L]]) && !is.array(mats[[1L]]))  # (1)
    mats <- mats[[1L]]  # (1)
  if (length(mats) == 0L) stop("No matrices supplied.", call. = FALSE)  # (2)
  nm <- names(mats)  # (2)
  if (is.null(nm) || any(!nzchar(nm)) || anyDuplicated(nm))  # (2)
    stop("Every outcome matrix must be named, uniquely.", call. = FALSE)  # (2)
  if (!all(vapply(mats, function(m) is.matrix(m) && is.numeric(m), logical(1))))  # (2)
    stop("Every outcome must be a numeric draws x options matrix.",  # (2)
         call. = FALSE)  # (2)
  d1 <- dim(mats[[1L]])  # (2)
  if (!all(vapply(mats, function(m) identical(dim(m), d1), logical(1))))  # (2)
    stop("All outcome matrices must have the same dimensions.", call. = FALSE)  # (2)
  cn <- colnames(mats[[1L]])  # (2)
  if (!all(vapply(mats, function(m) identical(colnames(m), cn), logical(1))))  # (2)
    stop("All outcome matrices must have the same column names (options).",  # (2)
         call. = FALSE)  # (2)
  array(unlist(mats, use.names = FALSE), dim = c(d1, length(mats)),  # (3)
        dimnames = list(NULL, cn, nm))  # (3)
}
```
1. The matrices can be given one by one, `nb_array(money = m1, hours = m2)`, or as one named list.
2. The checks: every outcome is named, every element is a numeric matrix, and all have the same size and the same option names in the same order.
3. `unlist()` strings the matrices together into one long vector, column by column, and `array()` folds that vector back into draws × options × outcomes. This works because R stores matrices column by column.


<a id="voi"></a>

## Actor-differentiated value of information (axis 5): `voi_partition()` and `voh_index()`

`voi_partition()` compares two ways of improving a decision. The first is learning which state of the world occurs. The second is allowing each group its own option. By default, it computes the two values of one decision for all groups, $A$ and $C$. With the argument `differentiated = TRUE`, it adds the two values of a decision per group, $B$ and $D$:

| | One option for all groups | One option per group |
|---|---|---|
| **Current knowledge** | $A$ | $B$ |
| **Perfect information** | $C$ | $D$ |

*Table 8. The four values computed by `voi_partition()`.*

```math
\begin{aligned}
A &= \max_{d}\; \mathbb{E}_\theta\, W\big(NB(d,\theta)\big),\\
B &= \max_{(d_1,\dots,d_G)}\; \mathbb{E}_\theta\, W\big(NB_1(d_1,\theta),\dots,NB_G(d_G,\theta)\big),\\
C &= \mathbb{E}_\theta\, \max_{d}\; W\big(NB(d,\theta)\big),\\
D &= \mathbb{E}_\theta\, W\Big(\max_{d} NB_1(d,\theta),\dots,\max_{d} NB_G(d,\theta)\Big).
\end{aligned} \qquad (7)
```

$B$ is the best combination of group-specific options under $W$. For $D$, the best option of each group within a known draw is also the best under $W$, because $W$ is non-decreasing in every group's net benefit.

A decision per group is meaningful only where groups can actually receive different options, as communes, regions or household types that can be told apart can (see axis 5 in the article). Women and men within one household usually cannot; for them, the value of information is reported per group, by applying `voi_partition()` to each group on its own. In the example, perfect information is worth 0.5 to women and nothing to men, who prefer $d_Y$ in every draw, while it is worth 0.625 for the joint decision. To keep one example throughout, the rest of this section treats the two groups as if they could be served separately.

The differences between the four values carry the result:

| Quantity | Definition | Meaning | Utilitarian | Maximin |
|-----------|------|-----------------|-------:|-------:|
| $A$, $B$, $C$, $D$ | Eq. (7) | | 3.00, 4.50, 3.625, 4.75 | 1.50, 2.25, 1.75, 2.75 |
| Expected value of perfect information (EVPI) | $C - A$ | value of knowing the state of the world before choosing one option for all | 0.625 | 0.25 |
| Static value of heterogeneity | $B - A$ | value of allowing each group its own option; requires no new data | 1.50 | 0.75 |
| EVPI once each group has its own option | $D - B$ | value of knowing the state of the world when options already differ by group | 0.25 | 0.50 |
| Dynamic value of heterogeneity | $D - C$ | value of allowing each group its own option once the state is known | 1.125 | 1.00 |
| Ratio, `voh_index()` | $(B - A)/(C - A)$ | value of differentiating relative to the value of learning | 2.4 | 3.0 |

*Table 9. Value-of-information quantities, worked example. In the output of `voi_partition()` the four differences are called `EVPI`, `VoH_static`, `EVPI_sub` and `VoH_dyn`.*

In the example, allowing women to choose $d_X$ and men $d_Y$ is worth 2.4 times as much as perfect information for a joint decision. A conventional analysis reports only $A$, at most also $C - A$.

For any non-decreasing rule, $A \le B \le D$ and $A \le C \le D$. The joint decision is one of the possible group-specific combinations, and knowing the state of the world cannot make a choice worse. All four differences are therefore non-negative. Their size depends on the rule, as the maximin column shows: what information is worth depends on the fairness criterion. The letters follow the article; Espinoza et al. (2014) use the letters A–D for the differences between these values rather than for the values themselves.

**Restricted profiles.** Often only some options can differ between groups. Equipment can be supplied to one type of household, while a national plan or a public campaign reaches every household alike. The argument `profiles` lists the allowed combinations, one row per profile and one column per group. $B$ and $D$ are then the best allowed profile $r$ at current knowledge and, draw by draw, under perfect information:

```math
B = \max_{r \in R}\; \mathbb{E}_\theta\, W\big(NB(r,\theta)\big),
\qquad
D = \mathbb{E}_\theta\, \max_{r \in R}\; W\big(NB(r,\theta)\big). \qquad (8)
```

In the example, suppose $d_X$ could be given to one group alone, but $d_Y$ only to both. With the five allowed profiles ($d_0$, $d_0$), ($d_X$, $d_0$), ($d_0$, $d_X$), ($d_X$, $d_X$) and ($d_Y$, $d_Y$), $B$ falls from 4.50 to 3.00, which equals $A$: the static value of heterogeneity is zero, because the combination that made it large, $d_X$ for women and $d_Y$ for men, is no longer allowed. $D$ falls from 4.75 to 3.875. The planner is indifferent between giving $d_X$ to women alone and to both groups, because men's mean under $d_X$ is zero; the function reports the first of the tied profiles. In the Atacora analysis, the groups are the self-hulling and the hiring households, and only the equipment can be steered to one type ([nb_from_mc()](#bridge)).

### How the code works

`voi_partition()` itself only checks its input and hands over to `partition_core()`, which does the computation. The split lets `fairness_screen()` and `baseline_pair()` call the computation for many rules without checking the same data again.

```r
voi_partition <- function(nb_list, p, W, differentiated = FALSE,
                          profiles = NULL, max_profiles = 1e5) {
  if (missing(p))  # (1)
    stop_missing("p", "group shares are a choice of reporting unit.")  # (1)
  if (missing(W))  # (1)
    stop_missing("W", "the valuation rule, e.g. w_utilitarian().")  # (1)
  check_rule(W)  # (1)
  if (!is.logical(differentiated) || length(differentiated) != 1L ||  # (2)
      is.na(differentiated))  # (2)
    stop("`differentiated` must be TRUE or FALSE.", call. = FALSE)  # (2)
  if (!is.null(profiles) && !differentiated)  # (2)
    stop("`profiles` restricts the decision per group; it needs ",  # (2)
         "differentiated = TRUE.", call. = FALSE)  # (2)
  obj <- prepare_nb(nb_list, p)  # (3)
  if (!is.null(profiles)) profiles <- resolve_profiles(profiles, obj, max_profiles)  # (4)
  partition_core(obj, W, differentiated = differentiated, profiles = profiles,  # (5)
                 max_profiles = max_profiles)  # (5)
}
```
1. Shares and rule must be given, and the rule must be a function.
2. `differentiated` must be `TRUE` or `FALSE`, and `profiles` only makes sense together with `differentiated = TRUE`.
3. The input is checked and turned into the internal object ([The shared engine](#engine)).
4. Allowed profiles are translated into option numbers by `resolve_profiles()`. It accepts option names or numbers, matches the columns to the groups by name, and refuses unknown options, duplicated profiles and more profiles than `max_profiles`.
5. The computation.

```r
# The computation, on a prepared object. Kept separate so that fairness_screen()
# and baseline_pair() can run many rules without re-validating the data.
# `profiles` is NULL or an integer matrix from resolve_profiles().
partition_core <- function(obj, W, differentiated = FALSE, profiles = NULL,
                           max_profiles = 1e5, w_sd = welfare_matrix(obj, W)) {  # (1)
  crit <- colMeans(w_sd)  # (2)
  # An option whose value is undefined under W (NA) makes the choice undefined.
  d_star <- if (anyNA(crit)) NA_integer_ else which_max1(crit)  # (3)
  A <- if (is.na(d_star)) NA_real_ else crit[[d_star]]  # (3)
  C <- mean(apply(w_sd, 1L, max))  # (4)
  best_in_draw <- max.col(w_sd, ties.method = "first")  # (5)

  out <- list(  # (6)
    EVPI = C - A, A = A, C = C,  # (6)
    d_star = if (is.na(d_star)) NA_character_ else obj$options[d_star],  # (6)
    p_ahead = if (is.na(d_star)) NA_real_ else mean(best_in_draw == d_star),  # (6)
    criterion = stats::setNames(crit, obj$options),  # (6)
    differentiated = differentiated,  # (6)
    p = obj$p, n_draws = obj$S, n_options = obj$D, n_groups = obj$G,  # (6)
    groups = obj$groups, options = obj$options)  # (6)

  if (differentiated) {
    restricted <- !is.null(profiles)  # (7)
    grid <- if (restricted) profiles else profile_grid(obj, max_profiles)  # (7)
    # B: the planner's best allowed profile at today's information. With a
    # restriction, D is enumerated alongside: per draw, the best allowed profile.
    vals <- numeric(nrow(grid))  # (8)
    best_in_draw_r <- rep(-Inf, obj$S)  # (8)
    for (i in seq_len(nrow(grid))) {  # (8)
      w_i <- welfare_post(obj, W, const_sel(obj, grid[i, ]))  # (8)
      vals[i] <- mean(w_i)  # (8)
      if (restricted) best_in_draw_r <- pmax(best_in_draw_r, w_i)  # (8)
    }
    best <- if (anyNA(vals)) NA_integer_ else which_max1(vals)  # (9)
    B <- if (is.na(best)) NA_real_ else vals[[best]]  # (9)
    # D without restriction: per draw each group's own best option maximises
    # any rule that is non-decreasing in every group's value, so no
    # enumeration is needed.
    D <- if (restricted) mean(best_in_draw_r)  # (10)
         else mean(welfare_post(obj, W, own_opt_sel(obj)))  # (10)
    own_best <- apply(matrix(colMeans(obj$u), nrow = obj$D), 2L, which_max1)  # (11)
    out <- c(out, list(  # (12)
      B = B, D = D,  # (12)
      VoH_static = B - A, EVPI_sub = D - B, VoH_dyn = D - C,  # (12)
      planner_profile = if (is.na(best)) NULL else  # (12)
        stats::setNames(obj$options[grid[best, ]], obj$groups),  # (12)
      d_star_group = stats::setNames(obj$options[own_best], obj$groups),  # (12)
      restricted = restricted, n_profiles = nrow(grid)))  # (12)
  }  # (12)
  class(out) <- c("voi_partition", "list")  # (12)
  out
}
```
1. The matrix of rule values per draw and option (Table 5). It is computed here unless the caller supplies it; `fairness_screen()` supplies it, so that it is computed only once per rule.
2. The value of each option under the rule: the column means, $V(d)$ in Eq. (2).
3. The recommended option $d^*$ and its value $A$. If any option's value is undefined, no option is recommended; a missing value is returned instead of a choice that ignores that option.
4. $C$: `apply(w_sd, 1L, max)` takes the largest value in each row, that is, the value of the best option in each draw, and `mean()` averages over the draws. For the utilitarian rule and Table 5: $(6 + 4 + 2 + 2.5)/4 = 3.625$.
5. In each draw, the option with the highest value. The share of draws in which this is $d^*$ is reported as `p_ahead`, the share of draws in which the recommended option also leads.
6. The result of one decision for all: the EVPI $C - A$, $A$, $C$, the recommended option, `p_ahead`, the value of every option (`criterion`), the shares and the sizes.
7. With a decision per group, the profiles to compare are either the allowed ones or all $D^G$ combinations ([The shared engine](#engine)).
8. For each profile, the rule's value in each draw, `w_i`, and its mean. With a restriction, `pmax()` also keeps, draw by draw, the highest value any allowed profile has reached so far.
9. $B$: the best profile at current knowledge.
10. $D$ with a restriction: the mean of those per-draw maxima (Eq. (8)). Without a restriction, a shortcut: in each draw every group simply receives its own best option (`own_opt_sel()`). Because the rule is non-decreasing, no profile can do better, so the $D^G$ profiles need not be enumerated in every draw. The repository's tests confirm that the shortcut equals the full enumeration.
11. Each group's own best option by its mean, reported as `d_star_group` for information; it does not enter $B$ or $D$.
12. The four differences of Table 9, the best profile (`planner_profile`), whether a restriction applied and how many profiles were compared. The class label selects the `print()` method.

```r
voh_index <- function(x, tol = .Machine$double.eps^0.5) {
  if (!all(c("A", "B", "C") %in% names(x)))  # (1)
    stop("`x` must carry A, B and C: a voi_partition() computed with ",  # (1)
         "differentiated = TRUE.", call. = FALSE)  # (1)
  denom <- x$C - x$A  # (2)
  if (!is.finite(denom) || abs(denom) <= tol) {  # (2)
    out <- NA_real_  # (2)
    attr(out, "reason") <- if (!is.finite(denom))  # (2)
      "C - A is not finite" else "C == A: no information value"  # (2)
    return(out)  # (2)
  }
  (x$B - x$A) / denom  # (3)
}
```
1. The index needs $B$, so it only accepts a result computed with `differentiated = TRUE`.
2. If perfect information is worth nothing ($C = A$), the ratio has no meaning. The function then returns a missing value and attaches the reason, instead of dividing by zero.
3. The ratio $(B - A)/(C - A)$ of Table 9.


<a id="screen"></a>

## All rules at once (axes 4 and 5): `fairness_screen()`

`fairness_screen()` runs the same decision through a list of rules and returns one row per rule. Each row gives the recommended option, the share of draws in which that option has the highest value under the rule, the EVPI under the rule, the share of draws in which the option leaves at least one group below zero, and the share in which it does so while the rule's aggregate shows a gain ([Hidden losses](#marginalisation)). The function also returns the value of every option under every rule, and one summary number: the smallest rank correlation (Spearman) between the rules' rankings of the options. A value of 1 means that all rules rank the options alike.

| Rule | $d^{*}$ | Share of draws in which $d^{*}$ leads | EVPI ($C-A$) | Share of draws with a group below zero | Share with a hidden loss |
|-------------|---|-------:|------:|-------:|-------:|
| Utilitarian | $d_X$ | 50 % | 0.625 | 25 % | 25 % |
| Maximin | $d_Y$ | 75 % | 0.25 | 0 % | 0 % |
| Prioritarian, $\lambda = 2$ | $d_X$ | 50 % | 1.125 | 25 % | 0 % |
| Atkinson, $\varepsilon = 1$, $k = 10$ | $d_X$ | 50 % | 0.92 | 25 % | 0 % |
| Atkinson, $\varepsilon = 2$, $k = 10$ | $d_Y$ | 50 % | 0.88 | 0 % | 0 % |

*Table 10. Output of `fairness_screen()`, worked example. The smallest rank correlation between the five rules is −0.5, for example between the utilitarian and the maximin rule.*

In the example, the recommendation depends on the rule, and so does the value of perfect information. The static value of heterogeneity is not part of the screen, because it presupposes that groups can be served separately; it is computed with `voi_partition(differentiated = TRUE)` (Table 9).

### How the code works

```r
fairness_screen <- function(nb_list, p, rules) {
  if (missing(p))  # (1)
    stop_missing("p", "group shares are a choice of reporting unit.")  # (1)
  if (missing(rules))  # (1)
    stop_missing("rules", "a named list of valuation rules; the set is open.")  # (1)
  check_rules(rules)  # (1)

  obj <- prepare_nb(nb_list, p)  # (2)
  parts <- list()
  losses <- list()
  for (r in names(rules)) {  # (3)
    w_sd <- welfare_matrix(obj, rules[[r]])  # (4)
    parts[[r]] <- partition_core(obj, rules[[r]], w_sd = w_sd)  # (4)
    d <- match(parts[[r]]$d_star, obj$options)  # (5)
    losses[[r]] <- if (is.na(d)) list(any_loss = NA_real_, hidden_loss = NA_real_)  # (5)
                   else loss_shares(obj, rules[[r]], d, w_sd)  # (5)
  }

  num <- function(x, k) vapply(x, function(v) as.numeric(v[[k]]), numeric(1))  # (6)
  tab <- data.frame(  # (6)
    rule          = names(rules),  # (6)
    option        = vapply(parts, function(x) x$d_star, character(1)),  # (6)
    p_ahead       = num(parts, "p_ahead"),  # (6)
    EVPI          = num(parts, "EVPI"),  # (6)
    p_group_loses = num(losses, "any_loss"),  # (6)
    p_hidden_loss = num(losses, "hidden_loss"),  # (6)
    row.names = NULL, stringsAsFactors = FALSE)  # (6)

  scores <- matrix(vapply(parts, function(x) x$criterion, numeric(obj$D)),  # (7)
                   nrow = obj$D, dimnames = list(obj$options, names(rules)))  # (7)
  rc <- NA_real_  # (8)
  if (length(rules) > 1L && obj$D > 1L) {  # (8)
    # rank 1 = best; -Inf (ruled out by a floor) lands last, as it should  # (8)
    ranks <- apply(-scores, 2L, rank, ties.method = "min", na.last = "keep")  # (8)
    cm <- suppressWarnings(stats::cor(ranks, method = "spearman"))  # (8)
    rc <- min(cm[upper.tri(cm)], na.rm = FALSE)  # (8)
  }

  out <- list(table = tab, scores = scores, rank_correlation = rc,  # (9)
              partitions = parts, p = obj$p, options = obj$options,  # (9)
              groups = obj$groups)  # (9)
  class(out) <- c("fairness_screen", "list")  # (9)
  out
}
```
1. Shares and the list of rules must be given. `check_rules()` makes sure the list is not empty, contains only functions and has unique names, because the names label the rows of the output. There is no built-in menu of rules: which rules are defensible is left to the user.
2. The input is checked once for all rules.
3. The same steps are repeated for every rule in the list.
4. The matrix of rule values is computed once and passed to `partition_core()`, which returns the recommended option, `p_ahead` and the EVPI ([Value of information](#voi)).
5. For the recommended option, `loss_shares()` counts the draws with a group below zero and the draws with a hidden loss ([The shared engine](#engine)).
6. The table with one row per rule. The small helper `num()` pulls one number out of each rule's result.
7. `scores`: the value of every option under every rule, options in rows and rules in columns.
8. The rank correlation. `rank(-scores)` gives the best option rank 1 under each rule; ties share the lower rank, and an option excluded by a floor (`-Inf`) lands last. `cor(..., method = "spearman")` correlates these rankings for every pair of rules, and the smallest value above the diagonal is reported. With a single rule or a single option there is nothing to compare, and the value stays missing.
9. The result keeps the table, the scores, the rank correlation and the full `voi_partition` result of each rule.


<a id="reference"></a>

## Reference condition (axis 2): `baseline_pair()`

A net benefit is always a difference to a reference condition $r$:

```math
NB_g(d,\theta;\,r) = Y_g(d,\theta;\,r) - Y_g(d_0,\theta;\,r), \qquad (9)
```

where $Y_g$ is the outcome level of group $g$. `baseline_pair()` computes the same decision against two reference conditions, for example a behaviour-informed one and a preference-informed one. It returns two tables:

- for each group or reporting unit, outcome and option: the mean and the share of draws above zero under both references, the difference of the two means, the option with the highest mean under each reference, and whether these options differ;
- for each rule and outcome: the recommended option, the share of draws in which it leads and the EVPI under each reference, and whether the recommendation changes.

The reference condition does not enter the function as a number; it enters through the model. The argument `model` is a function that receives one reference and returns the net benefits against it. In the Atacora model, the two references differ in the value of an hour freed from fonio work (Eq. (1)): replacement cost for the women in producer households and a fraction of today's hulling wage for paid hullers under the behaviour-informed reference, the value of an hour of off-farm work under the preference-informed one. Both are computed in the same simulation, so `model` only has to select the matching outputs ([nb_from_mc()](#bridge)). A third, historical reference, the share of the harvest eaten at home in a survey from 2011 (Ballogou et al., 2014), is kept as a greyed-out alternative line in the model; the analysis re-runs the model with it on the same draws and compares the recommendations of the rules with `fairness_screen()`.

In the example, suppose women's gain from $d_X$ is measured against an entitlement 3 higher. Then $V_{\text{util}}(d_X)$ falls from 3.00 to 1.50, and $d_Y$ (2.25) is recommended. The recommendation changes, although no simulated state of the world has changed. Under maximin, $d_Y$ is recommended against both references. Reported as a household, the unit's preferred option changes from $d_X$ (6.0) to $d_Y$ (4.5). In R, the example reads (an illustration, not part of the source files):

```r
claim <- function(extra) {
  x <- nb
  x$women[, "dX"] <- x$women[, "dX"] - extra
  x
}
baseline_pair(claim, references = list(behavioural = 0, preference = 3), p = p,
              rules = list(utilitarian = w_utilitarian(), maximin = w_maximin()),
              units = list(household = c(women = 1, men = 1)))
```

### How the code works

```r
baseline_pair <- function(model, references, p, rules, units = NULL) {
  if (!is.function(model))  # (1)
    stop("`model` must be a function of one reference-state argument.",  # (1)
         call. = FALSE)  # (1)
  if (missing(references))  # (1)
    stop_missing("references", "a named list of the two reference states.")  # (1)
  if (!is.list(references) || length(references) != 2L ||  # (1)
      is.null(names(references)) || any(!nzchar(names(references))) ||  # (1)
      anyDuplicated(names(references)))  # (1)
    stop("`references` must be a named list of two reference states.",  # (1)
         call. = FALSE)  # (1)
  if (missing(p))  # (1)
    stop_missing("p", "group shares are a choice of reporting unit.")  # (1)
  if (missing(rules))  # (1)
    stop_missing("rules", "a named list of valuation rules; the set is open.")  # (1)
  check_rules(rules)  # (1)

  refs <- names(references)  # (2)
  nbs <- lapply(references, model)  # (2)
  st <- lapply(nbs, nb_structure)  # (3)
  if (!identical(st[[1]]$groups, st[[2]]$groups) ||  # (3)
      !identical(st[[1]]$options, st[[2]]$options) ||  # (3)
      !identical(st[[1]]$outcomes, st[[2]]$outcomes) ||  # (3)
      st[[1]]$S != st[[2]]$S)  # (3)
    stop("`model` returned different groups, options, outcomes or draws for ",  # (3)
         "the two reference states; the two runs must be comparable.",  # (3)
         call. = FALSE)  # (3)
  s1 <- st[[1]]  # (4)
  resolve_p(p, s1$groups)                                  # validate once  # (4)

  # the groups and units whose outcomes are reported
  shown <- lapply(nbs, function(nb) {  # (5)
    arrs <- nb_structure(nb)$arrs  # (5)
    if (is.null(units)) arrs else c(arrs, reporting_units(arrs, units))  # (5)
  })  # (5)
  who <- names(shown[[1]])  # (5)
  if (anyDuplicated(who))  # (5)
    stop("The names of `units` must differ from the group names.", call. = FALSE)  # (5)

  rows <- list()
  for (g in who) for (k in seq_len(s1$K)) {  # (6)
    m1 <- matrix(shown[[1]][[g]][, , k], nrow = s1$S)  # (6)
    m2 <- matrix(shown[[2]][[g]][, , k], nrow = s1$S)  # (6)
    mean1 <- colMeans(m1); mean2 <- colMeans(m2)  # (6)
    best1 <- s1$options[which_max1(mean1)]; best2 <- s1$options[which_max1(mean2)]  # (6)
    d <- data.frame(unit = g, outcome = s1$outcomes[k], option = s1$options,  # (7)
                    mean1, mean2, colMeans(m1 > 0), colMeans(m2 > 0),  # (7)
                    difference = mean2 - mean1, best1, best2,  # (7)
                    flip = !identical(best1, best2),  # (7)
                    row.names = NULL, stringsAsFactors = FALSE)  # (7)
    names(d)[4:7] <- c(paste0("mean_", refs), paste0("p_positive_", refs))  # (7)
    names(d)[9:10] <- paste0("recommended_", refs)  # (7)
    rows[[length(rows) + 1L]] <- d
  }
  outcomes <- do.call(rbind, rows)  # (8)

  rule_rows <- list()
  for (k in seq_len(s1$K)) {
    objs <- lapply(nbs, function(nb) prepare_nb(lapply(nb_structure(nb)$arrs, function(a)  # (9)
      matrix(a[, , k], nrow = s1$S, dimnames = list(NULL, s1$options))), p))  # (9)
    for (r in names(rules)) {  # (10)
      parts <- lapply(objs, partition_core, W = rules[[r]])  # (10)
      opt <- vapply(parts, function(x) x$d_star, character(1))  # (10)
      rule_rows[[length(rule_rows) + 1L]] <- data.frame(  # (10)
        rule = r, outcome = s1$outcomes[k], reference = refs, option = opt,  # (10)
        p_ahead = vapply(parts, function(x) x$p_ahead, numeric(1)),  # (10)
        EVPI = vapply(parts, function(x) x$EVPI, numeric(1)),  # (10)
        flip = !identical(opt[[1]], opt[[2]]),  # (10)
        row.names = NULL, stringsAsFactors = FALSE)  # (10)
    }
  }

  out <- list(outcomes = outcomes, rules = do.call(rbind, rule_rows),  # (11)
              references = refs, groups = s1$groups, units = who,  # (11)
              options = s1$options, outcomes_measured = s1$outcomes)  # (11)
  class(out) <- c("baseline_pair", "list")  # (11)
  out
}
```
1. `model` must be a function; `references` must be a named list of exactly two reference conditions, whose names label the output; shares and rules must be given.
2. The model is called once per reference. `lapply()` returns a list of two `nb_list`s, one for each reference.
3. The two runs must be comparable: the same groups, options, outcomes and number of draws. Otherwise the comparison would mix two different models, and the function stops.
4. The shares are checked once.
5. The units whose outcomes are reported: the groups, plus reporting units if `units` is given ([Reporting unit](#units)). A unit must not share its name with a group.
6. For each group or unit `g` and each outcome `k`, the net benefits under the two references are taken as the matrices `m1` and `m2`. Their column means are the values of the options, and `which_max1()` names the option with the highest mean under each reference.
7. One row per option: both means, the shares of draws above zero (`colMeans(m1 > 0)` is the share of `TRUE` per column), the difference (second minus first reference), both preferred options and `flip`. The columns are then renamed after the references, for example `mean_behavioural` and `mean_preference`.
8. `do.call(rbind, rows)` stacks the rows of all units and outcomes into one table.
9. For the rules, each outcome is valued separately (design rule 3): the `k`-th outcome of every group is taken out and prepared as an internal object, once for each reference.
10. Every rule is applied under both references with `partition_core()` ([Value of information](#voi)). The row records, for each reference, the recommended option, `p_ahead` and the EVPI, and `flip` if the two recommendations differ. The rules always work on the groups, never on the reporting units.
11. The result keeps both tables and the names of references, groups, units, options and outcomes.


<a id="fidelity"></a>

## Fidelity (across the scaling directions): `fidelity_threshold()`

Fidelity describes whether an innovation is used as intended (Fixsen et al., 2017). `fidelity_threshold()` asks how much of an option's effect must arrive for the option to stay recommended. It scales the effect of one option against the reference condition by a share $f$, leaves every other option unchanged, and applies the rule within each draw:

```math
V_d(f) = \mathbb{E}_\theta\, W\big(f \cdot NB(d,\theta)\big),
\qquad
f^{*}_d = \min\Big\{ f \in [0,1] : V_d(f) \ge \max_{e \ne d} V_e(1) \Big\}. \qquad (10)
```

The threshold $f^{*}$ is a switching value in the sense of *decisionSupport*, not a new uncertain input: the recommended option stays ahead as long as at least $f^{*}$ of its effect arrives. For another option, $f^{*}$ exists only if a share of at most one would put it ahead; otherwise the function returns a missing value. For rules with $W(f \cdot x) = f\, W(x)$, which include the utilitarian and maximin rules and the prioritarian rule of Eq. (3), the threshold is simply the ratio $f^{*}_d = \max_{e \ne d} V_e(1) / V_d(1)$. For other rules, such as Atkinson, the function searches for it.

In the example, $d_X$ stays recommended under the utilitarian rule as long as 75 % of its effect arrives ($2.25/3.00$). Under the prioritarian rule it needs 90 % ($2.25/2.50$), and under Atkinson with $\varepsilon = 1$ and $k = 10$ about 90 % (0.897, found by the search). Under maximin, $d_Y$ is recommended with $f^{*} = 0$: its best alternative is the status quo at zero, and a smaller share of $d_Y$'s effect never takes it below zero.

The function scales an option's effect as a whole. H4 asks what happens when the components of one option arrive to different degrees (hypothesis H4 of the article). Which component arrives changes relationships inside the model, so the Atacora analysis scales the two components of the national plan, machine delivery and the implementation of the inclusive rule, inside the model and re-runs it on the same draws; `fidelity_threshold()` reports the threshold for the whole effect alongside.

### How the code works

```r
fidelity_threshold <- function(nb_list, p, W, tol = 1e-9) {
  if (missing(p))  # (1)
    stop_missing("p", "group shares are a choice of reporting unit.")  # (1)
  if (missing(W))  # (1)
    stop_missing("W", "the valuation rule, e.g. w_utilitarian().")  # (1)
  check_rule(W)  # (1)
  if (!is.numeric(tol) || length(tol) != 1L || !(tol > 0))  # (1)
    stop("`tol` must be a single positive number.", call. = FALSE)  # (1)
  obj <- prepare_nb(nb_list, p)  # (1)

  value <- colMeans(welfare_matrix(obj, W))  # (2)
  if (anyNA(value))  # (2)
    stop("The value of some option is undefined (NA) under `W`.", call. = FALSE)  # (2)
  value_at <- function(d, f) {                   # V_d(f): option d's effect scaled by f  # (3)
    scaled <- obj  # (3)
    scaled$u[, d, ] <- f * obj$u[, d, ]  # (3)
    mean(welfare_post(scaled, W, const_sel(obj, d)))  # (3)
  }

  f_star <- vapply(seq_len(obj$D), function(d) {
    target <- if (obj$D > 1L) max(value[-d]) else -Inf  # (4)
    if (value[[d]] < target) return(NA_real_)    # not ahead even at full effect  # (5)
    if (value_at(d, 0) >= target) return(0)      # ahead whatever share arrives  # (6)
    lo <- 0; hi <- 1                             # V_d(lo) < target <= V_d(hi)  # (7)
    while (hi - lo > tol) {  # (7)
      mid <- (lo + hi) / 2  # (7)
      if (value_at(d, mid) >= target) hi <- mid else lo <- mid  # (7)
    }  # (7)
    hi  # (7)
  }, numeric(1))

  out <- data.frame(option = obj$options, value = as.numeric(value),  # (8)
                    best_other = vapply(seq_len(obj$D), function(d)  # (8)
                      if (obj$D > 1L) max(value[-d]) else NA_real_, numeric(1)),  # (8)
                    recommended = seq_len(obj$D) == which_max1(value),  # (8)
                    f_star = f_star, row.names = NULL, stringsAsFactors = FALSE)  # (8)
  class(out) <- c("fidelity_threshold", "data.frame")  # (8)
  out
}
```
1. Shares and rule must be given. `tol` sets how precisely the threshold is searched; its default of one billionth is a technical setting, not a valuation. The input is checked and prepared ([The shared engine](#engine)).
2. The value of every option at full effect, $V_d(1)$. If it is undefined for some option, the function stops.
3. `value_at(d, f)` computes $V_d(f)$. It copies the internal object, multiplies option `d`'s net benefits in every group and draw by `f`, gives every group option `d` and averages the rule's values. Because net benefits are measured against the reference condition, with zero meaning no change, $f \times NB$ means that the share $f$ of the change arrives. The copy leaves the original object untouched.
4. The target: the best value among the other options at full effect. `value[-d]` means all values except the `d`-th.
5. If the option is behind even at full effect, no share of at most one can put it ahead: missing value.
6. With no effect at all, an option is worth zero. If that already reaches the target, because the best alternative is worth zero or less, the threshold is zero.
7. Otherwise the threshold lies between 0 and 1 and is found by halving the interval, like guessing a number between 0 and 1 by asking "higher or lower?". At the start, the option is behind at the lower end and ahead at the upper end. The midpoint is tested: if the option reaches the target there, the threshold lies below and the upper end moves down; otherwise the lower end moves up. After about 30 halvings the interval is shorter than `tol`, and the upper end is returned: the smallest tested share at which the option is still ahead. The search assumes that an option, once ahead, stays ahead as more of its effect arrives. This holds for all five rules of this file, provided a loss weighs at least as much as a gain.
8. One row per option: its value at full effect, the best other value, whether it is recommended, and $f^{*}$.


<a id="evpi"></a>

## Which uncertainty is worth resolving: `multi_EVPI()`

`multi_EVPI()` from the *decisionSupport* package (Luedeling et al., 2025) computes, for each uncertain input $\theta_j$, the expected value of knowing that input exactly. It does so for a binary choice. We apply it to the difference in net benefit between the option ahead and its rival, usually the runner-up by mean, $\Delta = NB(d',\theta) - NB(d'',\theta)$:

```math
\mathrm{EVPI}_j = \mathbb{E}_{\theta_j}\Big[\max\big(\mathbb{E}(\Delta \mid \theta_j),\,0\big)\Big] - \max\big(\mathbb{E}\,\Delta,\,0\big). \qquad (11)
```

The package estimates $\mathbb{E}(\Delta \mid \theta_j)$ by local regression across the draws and weights it by a normal distribution fitted to $\theta_j$. For inputs with markedly non-normal priors, the estimate may therefore be biased. The value is computed per input: it is not the EVPI of all inputs together, and the values of several inputs do not add up to it. A choice among more than two options has to be reduced to its decisive pair first.

$\Delta$ can be computed for any reporting unit. Inputs that only shift net benefit between women and men have a value of zero for the household but not for either group. Which research is worth doing therefore depends on the reporting unit.

### How the code works

The Atacora model calls `multi_EVPI()` in the usual way of *decisionSupport* models, on a table of the drawn inputs with the decisive difference as its last column (from `atacora_DA_model.R`):

```r
mc_table <- data.frame(simulation_results$x, decisive("comm", "V1"))  # (1)
names(mc_table)[ncol(mc_table)] <- dec_main                           # (2)
evpi_main <- multi_EVPI(mc = mc_table, first_out_var = dec_main)      # (3)
plot_evpi(evpi_main, dec_main)                                        # (4)
```
1. `simulation_results$x` holds the drawn inputs, one column per input and one row per draw. The column added at the end is the decisive difference in each draw: the net benefit of the option ahead minus that of the runner-up, here for the commune under the behaviour-informed reference. `decisive()` is defined in the model file; an option that equals the one ahead in every draw counts as a tie, not as a runner-up.
2. The new column is named after the decisive pair.
3. `multi_EVPI()` treats every column before `first_out_var` as an input and computes, for each input, the EVPI of deciding on the sign of the difference.
4. The package's plot of the result.

The other tests of the Atacora analysis collect their decisive pairs and call `multi_EVPI()` for all of them in one step at the end of `atacora_DA_axes.R`, in the same way.


<a id="boundary"></a>

## System boundary (axis 1): deliberately no function

The system boundary decides which effects are counted at all, and it is set inside the model. The Atacora model computes, in every draw, the accounts of the producer household ($G$), of the women in producer households ($W_g$), of the paid hullers ($H$) and of the private operator of the equipment ($O$), and the commune as their sum:

```math
NB_{\text{comm}} = NB_G + K\, NB_H + NB_O , \qquad (12)
```

where $K$ is the number of paid hullers per producer household. A boundary is a choice of which accounts enter this sum: the producer household alone, with the paid hullers, or with the operator as well. A second delimitation decides which outcomes enter money at all: money only, saved time as well, or time and home consumption (Eq. (1)). A third concerns the valuation layer: H3 retains aims that are not converted into money. Programme costs for machines, the national plan and the campaign lie outside the community boundary and are not modelled.

The model always computes every component, and the boundary only determines which components are summed. A function that moved the boundary after the simulation would suggest that it could be changed without touching the model. No such function exists, because no function can add effects that the model never computed.


<a id="bridge"></a>

## From the simulation to the functions: `nb_from_mc()`

`mcSimulation()` from *decisionSupport* returns one column per model output. The functions of this file take an `nb_list`. `nb_from_mc()` is the bridge between the two: it selects the columns by a name pattern and arranges them. It values nothing: combining outcomes, dividing a shared quantity between groups and applying a rule are valuations and belong in the model or in the functions above, where they can be read.

The Atacora model names its outputs `NB_{account}_{option}_{setting}`, for example `NB_H_out_V1` for the paid hullers under the equipment option in the behaviour-informed setting. The call

```r
nb_from_mc(simulation_results, "NB_{group}_{option}_V1",
           groups  = c("G", "H"),
           options = c("sq", "out", "up_std", "up_inc", "deep"))
```

therefore returns an `nb_list` with the producer households and the paid hullers, each a matrix of 10,000 draws × 5 options. Codes can be given labels: `groups = c(households = "G")` reads the columns with `G` and calls the group `households` in the result.

### How the code works

```r
nb_from_mc <- function(mc, pattern, groups, options, attributes = NULL) {
  if (missing(pattern))  # (1)
    stop_missing("pattern", 'a column-name template, e.g. "nb_{group}_{option}".')  # (1)
  if (missing(groups))  # (1)
    stop_missing("groups", "the codes that replace {group} in the column names.")  # (1)
  if (missing(options))  # (1)
    stop_missing("options", "the codes that replace {option} in the column names.")  # (1)

  y <- if (is.data.frame(mc) || is.matrix(mc)) mc else if (is.list(mc)) mc$y  # (2)
  if (is.null(y) || !(is.data.frame(y) || is.matrix(y)) || is.null(colnames(y)))  # (2)
    stop("`mc` must be the value of mcSimulation() (with element `y`) or a ",  # (2)
         "data frame of model outputs with column names.", call. = FALSE)  # (2)

  if (!is.character(pattern) || length(pattern) != 1L || is.na(pattern))  # (3)
    stop("`pattern` must be a single string.", call. = FALSE)  # (3)
  has <- function(ph) grepl(ph, pattern, fixed = TRUE)  # (3)
  for (ph in c("{group}", "{option}"))  # (3)
    if (!has(ph))  # (3)
      stop("`pattern` must contain the placeholder ", ph, ".", call. = FALSE)  # (3)
  if (is.null(attributes) && has("{attribute}"))  # (3)
    stop("`pattern` contains {attribute}, but `attributes` is NULL.",  # (3)
         call. = FALSE)  # (3)
  if (!is.null(attributes) && !has("{attribute}"))  # (3)
    stop("`attributes` is given, but `pattern` has no placeholder {attribute}.",  # (3)
         call. = FALSE)  # (3)

  groups <- code_names(groups, "groups")  # (4)
  options <- code_names(options, "options")  # (4)
  if (!is.null(attributes)) attributes <- code_names(attributes, "attributes")  # (4)

  fill <- function(g, o, a) {  # (5)
    s <- gsub("{group}", g, pattern, fixed = TRUE)  # (5)
    s <- gsub("{option}", o, s, fixed = TRUE)  # (5)
    if (!is.null(a)) s <- gsub("{attribute}", a, s, fixed = TRUE)  # (5)
    s  # (5)
  }  # (5)
  a_codes <- if (is.null(attributes)) list(NULL) else as.list(attributes)  # (6)
  wanted <- unlist(lapply(a_codes, function(a)  # (6)
    unlist(lapply(groups, function(g)  # (6)
      vapply(options, function(o) fill(g, o, a), character(1))))))  # (6)
  if (anyDuplicated(wanted))  # (6)
    stop("`pattern` and the codes generate the same column name more than ",  # (6)
         "once, e.g. ", wanted[duplicated(wanted)][1L], ".", call. = FALSE)  # (6)
  missing_cols <- setdiff(wanted, colnames(y))  # (7)
  if (length(missing_cols))  # (7)
    stop(length(missing_cols), " column(s) not found in the model output, ",  # (7)
         "e.g. ", paste(utils::head(missing_cols, 5L), collapse = ", "), ".",  # (7)
         call. = FALSE)  # (7)
  numeric_ok <- vapply(wanted, function(cl) is.numeric(y[, cl]), logical(1))  # (7)
  if (!all(numeric_ok))  # (7)
    stop("Column(s) not numeric: ",  # (7)
         paste(utils::head(wanted[!numeric_ok], 5L), collapse = ", "), ".",  # (7)
         call. = FALSE)  # (7)

  block <- function(g, a) {  # (8)
    cols <- vapply(options, function(o) fill(g, o, a), character(1))  # (8)
    m <- matrix(as.numeric(as.matrix(y[, cols, drop = FALSE])),  # (8)
                nrow = nrow(y), ncol = length(cols))  # (8)
    dimnames(m) <- list(NULL, names(options))  # (8)
    m  # (8)
  }  # (8)
  out <- lapply(groups, function(g) {  # (9)
    if (is.null(attributes)) return(block(g, NULL))  # (9)
    nb_array(stats::setNames(lapply(attributes, function(a) block(g, a)),  # (9)
                             names(attributes)))  # (9)
  })  # (9)
  stats::setNames(out, names(groups))  # (9)
}
```
1. The pattern, the group codes and the option codes must be given.
2. The function accepts the result of `mcSimulation()`, whose outputs sit in its element `y`, or directly a table of outputs with column names.
3. The pattern must be one string containing the placeholders `{group}` and `{option}`, and `{attribute}` exactly when several outcomes are requested. `grepl(..., fixed = TRUE)` searches for the placeholder literally; without `fixed = TRUE`, braces would have a special meaning in a search pattern.
4. `code_names()` turns the codes into a named vector: the values are the strings in the column names, the names are the labels in the result. A code without a label keeps its code as label.
5. `fill()` builds one column name by replacing the placeholders with a group code, an option code and, if given, an outcome code.
6. Every column name that will be read is generated first. If two combinations of codes would produce the same name, the function stops, because one column would otherwise be read twice under different labels.
7. Columns that do not exist in the output are named in the error message (the first five), and every column must be numeric.
8. `block()` builds the matrix of one group: the columns of its options in the given order, turned into a plain numeric matrix with one row per draw. `drop = FALSE` keeps a table even when there is only one option. The columns are labelled with the option labels.
9. One element per group. With several outcomes, each outcome is read as its own matrix and the matrices are stacked with `nb_array()` ([Reporting unit](#units)). The list is named with the group labels.

<a id="print"></a>

## Printing results: `R/print_methods.R`

Every function above returns an ordinary list or data frame with a class label (design rule 6). Typing the name of a result, or calling `print()` on it, makes R look for a method named `print.<label>` and use it instead of printing the whole list. The methods are kept in their own file, so that the computing functions stay free of output. They only display; they change nothing, and every method returns its input unchanged and invisibly, so that `x <- print(x)` leaves `x` as it was. The full result is always available with `str(x)` or `unclass(x)`.

```r
round_df <- function(df, digits) {
  num <- vapply(df, is.numeric, logical(1))  # (1)
  df[num] <- lapply(df[num], round, digits)  # (2)
  df  # (3)
}
```
1. A helper for tables: which columns are numeric?
2. Only those columns are rounded; text columns such as `rule` or `option` stay as they are.
3. The rounded copy is returned; the result object itself is not changed.

```r
print.voi_partition <- function(x, digits = 4, ...) {  # (1)
  cat("Value of information\n")  # (2)
  cat(sprintf("  %d draws | %d options | %d groups\n",  # (2)
              x$n_draws, x$n_options, x$n_groups))  # (2)
  cat("  recommended option: ", x$d_star,  # (2)
      sprintf(" (best in %.1f %% of draws)\n", 100 * x$p_ahead), sep = "")  # (2)
  print(round(c(EVPI = x$EVPI, A = x$A, C = x$C), digits))  # (3)
  if (isTRUE(x$differentiated)) {  # (4)
    cat("\nDecision per group (planner",  # (4)
        if (isTRUE(x$restricted)) sprintf(", %d allowed profiles", x$n_profiles),  # (4)
        "):\n", sep = "")  # (4)
    print(round(c(B = x$B, D = x$D, VoH_static = x$VoH_static,  # (4)
                  EVPI_sub = x$EVPI_sub, VoH_dyn = x$VoH_dyn), digits))  # (4)
    if (!is.null(x$planner_profile))  # (5)
      cat("Planner profile: ",  # (5)
          paste(names(x$planner_profile), x$planner_profile, sep = " -> ",  # (5)
                collapse = " | "), "\n", sep = "")  # (5)
  }
  invisible(x)  # (6)
}
```
1. `digits` sets the rounding of the printed values (four by default); the dots `...` are required by R's `print()` convention and are not used.
2. A header with the number of draws, options and groups, then the recommended option and the share of draws in which it is also the best option (`p_ahead`, as a percentage). `%%` prints a literal per cent sign.
3. The value of perfect information for one decision for all, with $A$ and $C$.
4. Only for `differentiated = TRUE`: $B$, $D$ and the three further differences, with the number of allowed profiles if `profiles` restricted them.
5. The best profile, one `group -> option` pair per group. For the worked example: `Planner profile: women -> dX | men -> dY`.
6. The object is returned invisibly.

```r
print.fairness_screen <- function(x, digits = 4, ...) {
  cat("Fairness screen: ", nrow(x$table), " rules, ", length(x$options),  # (1)
      " options, ", length(x$groups), " groups\n\n", sep = "")  # (1)
  print(round_df(x$table, digits), row.names = FALSE)  # (2)
  cat("\nSmallest rank correlation between the rules (Spearman): ",  # (3)
      round(x$rank_correlation, 3), "\n", sep = "")  # (3)
  invisible(x)  # (4)
}
```
1. A header with the number of rules, options and groups.
2. The table with one row per rule ([All rules at once](#screen)), rounded, without row numbers.
3. The smallest rank correlation between the rules, to three digits.
4. The object is returned invisibly.

```r
print.marginalisation_count <- function(x, digits = 3, ...) {
  cat("Hidden loss under option '", x$d_star, "' (", x$n_draws, " draws): ",  # (1)
      round(x$share, digits), "\n", sep = "")  # (1)
  print(round_df(x$by_group, digits), row.names = FALSE)  # (2)
  invisible(x)
}
```
1. The evaluated option, the number of draws and the share of draws with a hidden loss.
2. The same share per group, as a small table. For the worked example: 0.25 for men, 0 for women.

```r
print.baseline_pair <- function(x, digits = 4, ...) {
  cat("Reference-state pair: ", paste(x$references, collapse = " vs "), "\n\n",  # (1)
      sep = "")  # (1)
  print(round_df(x$rules, digits), row.names = FALSE)  # (2)
  flips <- unique(x$outcomes[x$outcomes$flip, c("unit", "outcome")])  # (3)
  if (nrow(flips))  # (3)
    cat("\nHighest mean changes for: ",  # (3)
        paste(flips$unit, flips$outcome, sep = "/", collapse = ", "), "\n", sep = "")  # (3)
  invisible(x)
}
```
1. The names of the two reference conditions.
2. The table of rules: for each rule, outcome and reference, the recommended option, `p_ahead`, the EVPI and whether the recommendation changes (`flip`).
3. The groups or units, with their outcome, whose option with the highest mean changes between the two references. `unique()` lists each pair once, although the outcome table has one row per option. The line is left out when nothing changes. For the worked example: `household/nb`.

```r
print.fidelity_threshold <- function(x, digits = 3, ...) {
  cat("Fidelity threshold: the share f* of an option's effect that must arrive\n",  # (1)
      "for it to stay (or become) recommended; NA = not ahead at any f <= 1\n\n", sep = "")  # (1)
  print(round_df(as.data.frame(unclass(x), stringsAsFactors = FALSE), digits),  # (2)
        row.names = FALSE)  # (2)
  invisible(x)
}
```
1. Two lines that say how to read $f^{*}$, including that `NA` means the option is not ahead at any share up to one.
2. The table with one row per option. `unclass()` removes the class label first, so that the data frame is printed as an ordinary table and the method does not call itself.


<a id="atacora"></a>

## The Atacora analysis

The tests of the Atacora case in the article are in the file `atacora_DA_axes.R`, one numbered block per test (T0 to T6), and call the functions directly after the simulation. Two helpers at the top of the file shorten every call (shown with adjusted line breaks and without the end-of-line comments of the source):

```r
nb_of <- function(accounts, setting, pattern = "NB_{group}_{option}_",
                  sim = simulation_results)
  nb_from_mc(sim, paste0(pattern, setting), groups = accounts,
             options = OPTIONS)
one <- function(m) voi_partition(list(unit = m), p = 1, W = w_utilitarian())
```

`nb_of()` reads the accounts under one setting (`"V0"`, `"V1"` or `"PREF"`), for example `nb_of(c("G", "H"), "V1")`. `one()` values a single account on its own; with one group and `p = 1`, the utilitarian rule is the account's own expected net benefit. The settings that the tests share are defined once:

```r
K_H        <- 0.25
P_GH       <- c(G = 1, H = K_H) / (1 + K_H)
P_WH       <- c(Wg = 1, H = K_H) / (1 + K_H)
WOMEN      <- list(women = P_WH)
REFERENCES <- list(behaviour = "V1", preference = "PREF")
loss_twice <- function(z) ifelse(z < 0, 2 * z, z)
RULES <- list(utilitarian  = w_utilitarian(),
              prioritarian = w_prioritarian(loss_twice),
              atkinson_0.5 = w_atkinson(0.5, offset = ATKINSON_OFFSET),
              atkinson_1   = w_atkinson(1,   offset = ATKINSON_OFFSET),
              atkinson_2   = w_atkinson(2,   offset = ATKINSON_OFFSET),
              maximin      = w_maximin())
FLOOR      <- w_constrained(0)
```

There are 0.25 paid hullers per producer household. The shares `P_GH` compare one producer household with its 0.25 hullers (0.8 and 0.2 after rescaling), and `P_WH` does the same for one woman in a producer household. `WOMEN` is the pooled reporting unit of H1, and `REFERENCES` names the two reference conditions by their settings in the model. `ATKINSON_OFFSET` is computed above these lines as described in [Valuation rules](#rules).

| Paragraph of the Atacora case in the article | Block | Functions |
|---------|----|------------------|
| The conventional reading | T0 | `voi_partition()`, `multi_EVPI()` |
| H1 | T1 (a), T3 | `voi_partition()`, `reporting_units()`, `marginalisation_count()` |
| H2 | T4 | `fairness_screen()` with the six rules, `w_constrained()` for the floor, `voi_partition()` |
| H3 | T1 (b) | `voi_partition()` on kilograms; progress towards the stated aims is computed in the block itself |
| Reference conditions | T2 | `baseline_pair()`, `fairness_screen()` |
| Research priorities | T5 | `voi_partition()` with `differentiated` and `profiles`, `voh_index()`, `fairness_screen()` |
| H4 | T6 | `fidelity_threshold()`, `voi_partition()`; re-runs of the model with scaled components |

*Table 11. Where the functions are used in the Atacora analysis. `multi_EVPI()` is applied to the decisive pair of every block.*

Four calls from these blocks show the pattern (extracts; the comment lines are added here):

```r
# H1: how often the pooled women gain while one group loses, for option o
mc <- marginalisation_count(nb_of(c("Wg", "H"), V_MAIN), p = P_WH,
                            W = w_utilitarian(), d_star = o)
# reference conditions: the same decision against both references, every rule
model_ref <- function(accounts) function(setting) nb_of(accounts, setting)
bp_rules <- baseline_pair(model_ref(c("G", "H")), REFERENCES, p = P_GH,
                          rules = RULES)
# H2: every option under every rule
nb_GH <- nb_of(c("G", "H"), V_MAIN)
fs_T4 <- fairness_screen(nb_GH, p = P_GH, rules = RULES)
# research priorities: a decision per household type; only equipment is targeted
ALLOWED <- rbind(c("sq", "sq"), c("out", "sq"), c("sq", "out"), c("out", "out"),
                 c("up_std", "up_std"), c("up_inc", "up_inc"), c("deep", "deep"))
colnames(ALLOWED) <- c("self", "hire")
voi_partition(nb_types, p = c(1, 1), W = w_utilitarian(),
              differentiated = TRUE, profiles = ALLOWED)
```

`V_MAIN` is the behaviour-informed setting `"V1"`. In `model_ref()`, the function handed to `baseline_pair()` does not re-run the model; it selects the outputs of the requested setting. In the last call, the two groups are the self-hulling and the hiring households, each weighted with its share of households in the draw. Because `p = c(1, 1)` is rescaled to one half each, the analysis multiplies $A$, $B$, $C$ and $D$ by two to report them per producer household.

The whole analysis is reproduced from the root of this repository with `Rscript --vanilla atacora_DA_run.R`. The script runs the tests first and writes nothing unless all of them pass; it then runs the model (seed 20260927, 10,000 draws), the tests T0 to T6, the key findings and the figures.


### Helper functions inside the case scripts

The case scripts define further small functions. They name accounts, options and settings of the Atacora model and therefore stay outside `R/`. Each is commented line by line where it is defined; the index below says what each one does and where to find it (line numbers as of v9).

| Function | File, line | What it does |
|---|---|---|
| `make_variables()` | `atacora_DA_model.R`, 18 | Draws one row from the input table and makes every input a global variable, so that `decision_model()` can be stepped through line by line at one draw (a common idiom of *decisionSupport* models). |
| `decision_model()` | `atacora_DA_model.R`, 25 | The case model. Returns, for one draw, the net benefits of every account, option and valuation setting; `mcSimulation()` calls it once per draw. |
| `process_fonio()` | `atacora_DA_model.R`, 71 (inside `decision_model()`) | The processing chain of one option and household type: kilograms hulled by machine and by hand (paid or unpaid), grain recovered, eaten and sold, fees and wages. |
| `accounts()` | `atacora_DA_model.R`, 168 (inside) | One option against the status quo for one household type: the change in every quantity of every account. |
| `mix()` | `atacora_DA_model.R`, 190 (inside) | From households to the commune: mixes the self-hulling and the hiring household type with their shares. |
| `npv()` | `atacora_DA_model.R`, 219 (inside) | Discounted sum over the horizon with *decisionSupport*'s `discount()`. |
| `comp()` | `atacora_DA_model.R`, 220 (inside) | The discounted components of one option in FCFA: the money of each account, the hours valued at the hulling wage and the kilograms valued at the sale price. |
| `value()` | `atacora_DA_model.R`, 246 (inside) | The net benefit of every account for one option under one valuation setting (the weights $\omega$ and $\kappa$ of Eq. (1)). |
| `ahead()` | `atacora_DA_model.R`, 325 | The option ahead and the runner-up by mean, for one account and setting; an option equal to the one ahead in every draw counts as a tie, not as runner-up. |
| `decisive()` | `atacora_DA_model.R`, 331 | Per draw, the net benefit of the option ahead minus that of the runner-up: the input of `multi_EVPI()` and of the PLS sensitivity analysis ([multi_EVPI()](#evpi)). |
| `quiet()` | `atacora_DA_run.R`, 9 | Suppresses messages and the known warnings that *decisionSupport* gives when it fits distributions to the input table; every other warning passes. |
| `atkinson_offset()` | `atacora_DA_axes.R`, 31 | The offset $k$ of the Atkinson rule ([Valuation rules](#rules)). |
| `loss_twice()` | `atacora_DA_axes.R`, 38 | The prioritarian transform: a loss counts twice. |
| `nb_of()`, `one()` | `atacora_DA_axes.R`, 76, 78 | Shown above. |
| `comp()` | `atacora_DA_axes.R`, 79 | Draws × options matrix of one money component `C_{name}_{option}` of the model output (FCFA). |
| `unit_of()` | `atacora_DA_axes.R`, 80 | Draws × options matrix of one quantity in its natural unit (kilograms, hours). |
| `status()` | `atacora_DA_axes.R`, 81 | The status of an input row: L literature, W workshop or dataset, T transferred from another region, B open request to project partners, P wide prior set deliberately. |
| `describe()` | `atacora_DA_axes.R`, 82 | Mean and shares of draws with a gain and with a loss, per option. |
| `switch_point()` | `atacora_DA_axes.R`, 85 | For values that are linear in a weight $t$ (mean value $a + t\,b$), the interval of $t \ge 0$ in which a given option is ahead of all others. |
| `decisive_of()` | `atacora_DA_axes.R`, 93 | Per draw, the option ahead minus its rival: the runner-up by mean, or the option with the largest expected regret; ties are not rivals. |
| `rule_draws()` | `atacora_DA_axes.R`, 102 | A rule's value per draw and option. |
| `top_evpi()` | `atacora_DA_axes.R`, 104 | The leading rows of a `multi_EVPI()` table, with the status of each input. |
| `multi_evpi_of()` | `atacora_DA_axes.R`, 111 | `multi_EVPI()` in the `mc_table` form of [multi_EVPI()](#evpi), without screen output. |
| `evpi_job()` | `atacora_DA_axes.R`, 118 | Registers a decisive pair for the joint `multi_EVPI()` run at the end of the file; a pair that no draw reverses is recorded with a value of zero. |
| `rerun()` | `atacora_DA_axes.R`, 122 | Runs a variant of `decision_model()` on the same draws (same seed) and checks that no input changed. |
| `model_swapped()` | `atacora_DA_axes.R`, 130 | `decision_model()` with one greyed-out `##` line swapped in, as a reader would do by hand. |
| `boundary()` | `atacora_DA_axes.R`, 167 | The net benefit under the three system boundaries G, G + H and G + H + O for one setting. |
| `val_G()`, `val_comm()` | `atacora_DA_axes.R`, 185–186 | Net benefit of the producer household and of the commune at any weights $\omega$ and $\kappa$, recomputed from the components and checked against the model output. |
| `thr()` | `atacora_DA_axes.R`, 200 | The weight ($\omega^*$ or $\kappa^*$) at which an option overtakes the status quo and the best other option. |
| `aim_of()`, `acc_of()` | `atacora_DA_axes.R`, 243 | Split a key of the form `aim|account` into its two parts. |
| `ahead_strict()` | `atacora_DA_axes.R`, 257 | Share of draws in which an option is strictly ahead of every other option. |
| `dominates()` | `atacora_DA_axes.R`, 272 | Pareto dominance across the stated aims: at least as good in every aim and better in one. |
| `model_ref()` | `atacora_DA_axes.R`, 356 | Shown above. |
| `envelope()` | `atacora_DA_axes.R`, 375 | The preferred option along the value of an hour and the values at which it switches. |
| `addressed()` | `atacora_DA_axes.R`, 450 | The utilitarian value over the groups that a rule design of the national plan names (H2). |
| `ladder()` | `atacora_DA_axes.R`, 537 | The value of information of one setting at every reporting level, from the person to the commune. |
| `boot_voh()` | `atacora_DA_axes.R`, 580 | Monte Carlo standard error of the static value of heterogeneity, by resampling the draws and re-optimising the choices. |
| `decision_model_fidelity()` | `atacora_DA_axes.R`, 630 | `decision_model()` with the two components of the national plan scaled by delivery ratios (H4). |
| `composition_run()` | `atacora_DA_axes.R`, 635 | Runs the model for one composition of the two delivery ratios on the same draws. |
| `evpi_of_rows()` | `atacora_DA_axes.R`, 706 | The value of information of named input rows within one decisive pair (zero where no draw reverses the pair). |
| `k_fcfa()`, `save_fig()` | `atacora_DA_figures.R`, 47, 49 | Axis labels in thousand FCFA; saving a figure as SVG with editable text and as PNG at 300 dpi. |
| `fb_stats()`, `flying_bars()` | `atacora_DA_figures.R`, 56, 61 | Quantiles (1, 10, 50, 90, 99 %), mean and share above zero of a distribution, and the bar chart drawn from them. |
| `draw_F1()` | `atacora_DA_figures.R`, 143 | Figure F1, the structure of the model, in English or German. |
| `hv_e()` | `atacora_DA_figures.R`, 359 | The four values $A$ to $D$ of one profile restriction, for the value-of-heterogeneity panel of F2. |
| `cf_summary()` | `atacora_DA_figures.R`, 435 | Median and 25–75 % band of the cumulative discounted cash flow of the producer household, per option and year (supplement S2). |

*Table 12. Helper functions in the case scripts.* The scripts in `analysis/` (test runner, key findings, model walkthrough, review checklist) define further small local helpers for formatting; they are commented where they are defined.


<a id="tests"></a>

## How the functions are checked

The folder `tests/testthat/` contains automated tests written with the R package *testthat*. `analysis/00_run_tests.R` runs all of them and reports the number of checks; `atacora_DA_run.R` calls it first and writes no result unless every check passes. Among other things, the tests check that:

- the worked example of this file gives the values reported here for the utilitarian, maximin and prioritarian rules, the four values $A$ to $D$ and the fidelity threshold of 0.75;
- the code names no group, option or case and uses base R only, and results do not change when groups or options are renamed or reordered;
- every argument that encodes a valuation choice has no default, and leaving it out gives an error that names it;
- the EVPI agrees with an independent implementation, the R package *voi*, for the aggregate and for each group;
- $A \le B \le D$ and $A \le C \le D$ hold for every non-decreasing rule, the shortcut for $D$ equals the full enumeration of profiles, and a restriction of profiles can only lower $B$ and $D$;
- all five rules are non-decreasing, and maximin cannot hide a loss;
- `multi_EVPI()` equals the EVPI for a single normally distributed input, and it is a value per input, not the total.

The values for the Atkinson rule in this file were computed with the same functions.


<a id="extend"></a>

## Extending the functions

The functions are meant to be used beyond the Atacora model. Three kinds of extension need no change to the existing code.

**A new rule.** Any function of `(nb, p)` that returns one number, and that never falls when one group's net benefit rises, can be passed to every function above. Because the net benefits reach the rule labelled with the group names ([The shared engine](#engine)), a rule can also treat groups differently by name. For example, a utilitarian rule with additional weights per group (an illustration, not part of the source files):

```r
w_weighted <- function(weights) {
  force(weights)
  # non-decreasing as long as no weight is negative
  function(nb, p) sum(weights[names(nb)] * p * nb)
}
fairness_screen(nb, p,
                rules = list(weighted = w_weighted(c(women = 2, men = 1))))
```

**A new reporting unit or reference.** Units are coefficient vectors for `reporting_units()`; references are whatever the user's `model` function accepts in `baseline_pair()`.

**A new quantity.** New quantities can reuse the engine ([The shared engine](#engine)): `prepare_nb()` for the checks, a selection for which option each group receives, and `welfare_post()` for the rule within each draw.

New code should keep the design rules of [How the code is organised](#code): no names of a case, no default for a valuation choice, one outcome per call, the rule within each draw, base R, and a test for every new property. The functions follow the conventions of an R package (documentation blocks, input checks, no side effects, results with class labels), so that they can be moved into a package without changes.


<a id="references"></a>

## References

Atkinson, G., Dietz, S., Helgeson, J., Hepburn, C., & Sælen, H. (2009). Siblings, not triplets: Social preferences for risk, inequality and time in discounting climate change. *Economics*, 3. https://doi.org/10.5018/economics-ejournal.ja.2009-26

Ballogou, V. Y., Soumanou, M. M., Toukourou, F., & Hounhouigan, J. D. (2014). Indigenous knowledge on landraces and fonio-based food in Benin. *Ecology of Food and Nutrition*, 53, 390–409. https://doi.org/10.1080/03670244.2013.811388

Espinoza, M. A., Manca, A., Claxton, K., & Sculpher, M. J. (2014). The value of heterogeneity for cost-effectiveness subgroup analysis: Conceptual framework and application. *Medical Decision Making*, 34, 951–964. https://doi.org/10.1177/0272989X14538705

Fixsen, D. L., Blase, K. A., & Fixsen, A. A. M. (2017). Scaling effective innovations. *Criminology & Public Policy*, 16, 487–499. https://doi.org/10.1111/1745-9133.12288

Luedeling, E., Goehring, L., Schiffers, K., Whitney, C., & Fernandez, E. (2025). *decisionSupport: Quantitative support of decision making under uncertainty* [R package]. https://doi.org/10.32614/CRAN.package.decisionSupport
