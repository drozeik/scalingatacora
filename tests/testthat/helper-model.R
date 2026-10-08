# The case model of atacora_DA_model.R without its SIMULATION part (v8).
# The model file is a script in the walnut style: sourcing it runs 10 000 draws, the EVPI and the
# PLS. The tests evaluate only the expressions before the SIMULATION block (library, make_variables(),
# decision_model()), in the global environment, as mcSimulation() and the template expect.
layer2_files <- "workshop_layer.R"                  # the case file of R/, outside the generality scan

model_file <- file.path(.proj_root, "atacora_DA_model.R")
axes_file  <- file.path(.proj_root, "atacora_DA_axes_full.R")
input_file <- file.path(.proj_root, "data", "estimates", "atacora_DA_inputs_v8.csv")

# the expressions of a script up to (not including) the first one whose text starts with `stop_at`
script_head <- function(path, stop_at) {
  ex <- parse(path, keep.source = FALSE)
  txt <- vapply(ex, function(e) paste(deparse(e), collapse = "\n"), character(1))
  cut <- which(startsWith(txt, stop_at))[1]
  if (is.na(cut)) stop("No expression starting with '", stop_at, "' in ", basename(path))
  ex[seq_len(cut - 1)]
}

# one named function definition from a script, e.g. decision_model_fidelity() from the axes file
script_function <- function(path, name) {
  ex <- parse(path, keep.source = FALSE)
  hit <- Filter(function(e) is.call(e) && identical(e[[1]], as.name("<-")) &&
                  identical(e[[2]], as.name(name)), as.list(ex))
  if (length(hit) != 1L) stop("Definition of ", name, " not found once in ", basename(path))
  hit[[1]]
}

local({
  old <- setwd(.proj_root); on.exit(setwd(old))
  invisible(utils::capture.output(suppressMessages(suppressWarnings(
    for (e in script_head(model_file, "SEED <-")) eval(e, envir = globalenv())))))
})

v8_estimate <- function() suppressWarnings(decisionSupport::estimate_read_csv(input_file))

# mcSimulation() of a model function on n draws with a seed, quietly (the 'fit' rows log their fitting)
run_mc <- function(n, seed = 1, model = decision_model) {
  est <- v8_estimate()
  set.seed(seed)
  invisible(utils::capture.output(res <- suppressMessages(suppressWarnings(decisionSupport::mcSimulation(
    estimate = est, model_function = model, numberOfModelRuns = n, functionSyntax = "plainNames")))))
  res
}

# the median of every input (from 20 000 draws), as a named list
input_medians <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      set.seed(20260927)
      invisible(utils::capture.output(x <- suppressMessages(suppressWarnings(
        decisionSupport::random(v8_estimate(), n = 20000)))))
      cache <<- as.list(apply(x, 2, stats::median))
    }
    cache
  }
})

# evaluate decision_model() on one draw of named inputs, as mcSimulation(plainNames) does, and keep
# every local object: the outputs are in $out, the internals (sq_self, out_hire, ...) in the environment
model_on <- function(values = input_medians(), seed = 1, model_body = body(decision_model)) {
  e <- list2env(as.list(values), parent = globalenv())
  set.seed(seed)
  e$.out <- eval(model_body, envir = e)
  e
}

with_inputs <- function(...) utils::modifyList(input_medians(), list(...))   # the medians with some inputs set
