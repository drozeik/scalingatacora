# Scaling as a valuation decision: the Atacora case model

Probabilistic decision model for the review article *Scaling as a valuation decision* (in preparation). The case is fonio (*Digitaria exilis*) in the Atacora, North Benin: three options from a local prioritisation workshop – processing equipment (**out**), advocacy for a national fonio plan with two rule designs (**up**), and public awareness (**deep**) – against the status quo. The model shows why the five valuation axes of the article and fidelity have to be examined before a scaling decision. It gives no recommendation for the Atacora; every statement holds under the priors of the input table.

The model is built with the R package [decisionSupport](https://CRAN.R-project.org/package=decisionSupport). The valuation functions in `R/` are generic, written in base R, and can be applied to the output of any decisionSupport model; [`FUNCTIONS.md`](FUNCTIONS.md) explains each of them line by line.

## Reproduce

From the root of the repository:

```sh
Rscript --vanilla atacora_DA_run.R
```

The script runs the tests first and writes nothing unless all pass. It then runs the model (10,000 draws, seed 20260927), the axis tests T0–T6, the key findings and the figures, about 30 minutes in total. Results are written to `outputs/v9/` and are not versioned. Package versions are recorded in `renv.lock`; `renv::restore()` installs them.

## Contents

| Path | Contents |
|---|---|
| `atacora_DA_run.R` | the one entry point: tests → model → axis tests → key findings → figures |
| `atacora_DA_model.R` | `make_variables()`, `decision_model()` with numbered sections, simulation, value of information, sensitivity |
| `atacora_DA_axes.R` | the axis tests T0–T6, applying the functions of `R/` directly to the simulation output |
| `atacora_DA_figures.R` | figures F1, F2 and the supplement |
| `R/` | the valuation functions, documented in [`FUNCTIONS.md`](FUNCTIONS.md) |
| `data/estimates/atacora_DA_inputs_v8.csv` | the model's one input table |
| `docs/review_checklist.md` | a reading path through the model, with line numbers (generated) |
| `docs/model_walkthrough.md` | every line of `decision_model()` at the medians of the inputs (generated) |
| `analysis/` | test runner, key findings, generators of the two documents in `docs/` |
| `tests/testthat/` | automated tests |

## Input table

One row per uncertain input: distribution, lower and upper bound, label, description, source (`source_key`, `source_anchor`), status, note, the model edge it acts on, and the method of derivation. Status codes: **L** literature, **W** workshop or published dataset, **T** transferred from another region (only for up and deep, with wider bounds), **B** open request to project partners (runs as a broad prior), **P** wide prior set deliberately. Raw data are not part of this repository; every row names its source.

## Author

Daniel Rozeik, University of Bonn. A licence will be added when the repository is made public.
