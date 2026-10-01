# "Keine Funktion kennt die Gruppen, die Optionen oder die Regeln."
# Two kinds of evidence: (1) the layer-1 source contains no case vocabulary,
# (2) results do not depend on what groups, options and attributes are called
# or in which order they arrive.

layer1_files <- function() {
  f <- list.files(file.path(.proj_root, "R"), pattern = "[.]R$", full.names = TRUE)
  f[!(basename(f) %in% layer2_files)]   # helper-model.R
}

code_lines <- function(path) {
  x <- readLines(path, warn = FALSE)
  x <- x[!grepl("^\\s*#", x)]          # roxygen and comment lines
  sub("#.*$", "", x)                    # trailing comments
}

test_that("layer-1 code names no group, option, attribute or case", {
  case_vocab <- paste0(
    "fonio|jute|crincrin|digitaria|atacora|benin|bouk|natitingou|",
    "\\bwomen\\b|\\bmen\\b|female|\\bmale\\b|gender|household|",
    "processing|training|advocacy|status_quo|",
    "income|labou?r|consumption|yield|price")
  # the scan is not vacuous: it sees code, and it would catch a planted name
  expect_gt(length(layer1_files()), 5L)
  expect_gt(sum(lengths(lapply(layer1_files(), code_lines))), 300L)
  expect_true(grepl(case_vocab, 'x <- nb[, , "Income"]', ignore.case = TRUE))
  expect_true(grepl(case_vocab, 'p[["women_bouk"]]', ignore.case = TRUE))
  expect_false(grepl(case_vocab, "u <- select_u(obj, sel)", ignore.case = TRUE))

  for (f in layer1_files()) {
    hits <- grep(case_vocab, code_lines(f), ignore.case = TRUE, value = TRUE)
    expect_identical(hits, character(0), info = basename(f))
  }
})

test_that("layer-1 code uses base R only", {
  pkgs <- "\\b(dplyr|tidyr|purrr|readr|tibble|magrittr|rlang)::|%>%|library\\(|require\\("
  for (f in layer1_files()) {
    hits <- grep(pkgs, code_lines(f), value = TRUE)
    expect_identical(hits, character(0), info = basename(f))
  }
})

# ---------------------------------------------------------------------------

mk_random <- function(G, D, S = 400, seed = 1) {
  set.seed(seed)
  groups <- paste0("grp", sample(100:999, G))
  options <- paste0("opt", sample(100:999, D))
  nb <- lapply(seq_len(G), function(g)
    matrix(stats::rnorm(S * D, mean = rep(stats::runif(D, -5, 10), each = S), sd = 15),
           nrow = S, dimnames = list(NULL, options)))
  names(nb) <- groups
  p <- stats::setNames(stats::runif(G, 0.5, 2), groups)
  list(nb = nb, p = p)
}

partition_numbers <- function(x) unlist(x[c("A", "B", "C", "D", "EVPI", "p_ahead")])

rules <- list(w_utilitarian(), w_maximin(),
              w_prioritarian(function(z) ifelse(z < 0, 2 * z, z)))

run <- function(case, W) voi_partition(case$nb, case$p, W, differentiated = TRUE)

test_that("results are invariant to the order of groups", {
  case <- mk_random(G = 4, D = 3)
  perm <- case; perm$nb <- case$nb[c(3, 1, 4, 2)]       # p stays named
  for (W in rules) {
    a <- run(case, W); b <- run(perm, W)
    expect_equal(partition_numbers(a), partition_numbers(b), tolerance = 1e-12)
    expect_identical(a$d_star, b$d_star)
    expect_identical(a$d_star_group[names(b$d_star_group)], b$d_star_group)
  }
})

test_that("results are invariant to the order of options", {
  case <- mk_random(G = 3, D = 4, seed = 2)
  perm <- case
  perm$nb <- lapply(case$nb, function(a) a[, c(2, 4, 1, 3), drop = FALSE])
  for (W in rules) {
    a <- run(case, W); b <- run(perm, W)
    expect_equal(partition_numbers(a), partition_numbers(b), tolerance = 1e-12)
    expect_identical(a$d_star, b$d_star)
  }
})

test_that("results are invariant to renaming groups and options", {
  case <- mk_random(G = 3, D = 3, seed = 4)
  ren <- case
  new_g <- c("x", "y", "z"); new_o <- c("o1", "o2", "o3")
  ren$nb <- lapply(case$nb, function(a) { colnames(a) <- new_o; a })
  names(ren$nb) <- new_g
  ren$p <- stats::setNames(unname(case$p), new_g)
  for (W in rules) {
    a <- run(case, W); b <- run(ren, W)
    expect_equal(unname(partition_numbers(a)), unname(partition_numbers(b)), tolerance = 1e-12)
    expect_identical(match(a$d_star, a$options), match(b$d_star, b$options))
  }
})

test_that("any number of groups, options and draws is accepted", {
  for (G in c(1, 2, 5)) for (D in c(1, 2, 5)) for (S in c(1, 60)) {
    case <- mk_random(G, D, S = S, seed = G * 100 + D * 10 + S)
    x <- voi_partition(case$nb, case$p, w_maximin(), differentiated = D^G <= 1e4)
    info <- sprintf("G=%d D=%d S=%d", G, D, S)
    expect_equal(x$EVPI, x$C - x$A, info = info)
    expect_identical(x$n_groups, as.integer(G), info = info)
    expect_identical(x$n_options, as.integer(D), info = info)
    if (D == 1) {
      # a single option leaves nothing to decide and nothing to learn
      expect_equal(x$EVPI, 0, info = info)
      if (isTRUE(x$differentiated)) expect_equal(x$VoH_static, 0, info = info)
    }
  }
})

test_that("unnamed inputs get neutral positional names", {
  set.seed(5)
  nb <- list(matrix(stats::rnorm(40), 20, 2), matrix(stats::rnorm(40), 20, 2))
  x <- voi_partition(nb, c(1, 1), w_utilitarian())
  expect_identical(x$groups, c("group_1", "group_2"))
  expect_identical(x$options, c("option_1", "option_2"))
})
