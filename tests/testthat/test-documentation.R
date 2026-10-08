# FUNCTIONS.md (English) and FUNCTIONS.de.md (German) are one guide in two languages;
# FUNCTIONS.md is also the text of the appendix (docs/91-functions.qmd). These tests keep
# both versions alike where they must be, and in step with the code. Base R and testthat only.
guides <- file.path(.proj_root, c("FUNCTIONS.md", "FUNCTIONS.de.md"))
read_lines <- function(path) readLines(path, warn = FALSE, encoding = "UTF-8")

# Fenced blocks of the given types, in order of appearance, without the fences.
fenced_blocks <- function(lines, types = c("r", "text", "sh")) {
  starts <- which(lines %in% paste0("```", types))
  lapply(starts, function(s) {
    e <- s + which(lines[(s + 1):length(lines)] == "```")[1]
    if (e == s + 1) character(0) else lines[(s + 1):(e - 1)]
  })
}

# The math block after each <!-- eq-... --> mark, named by the mark.
equation_blocks <- function(lines) {
  marks <- grep("^<!-- eq-[a-z-]+ -->$", lines)
  out <- lapply(marks, function(m) fenced_blocks(lines[m:length(lines)], "math")[[1]])
  stats::setNames(out, sub("^<!-- (eq-[a-z-]+) -->$", "\\1", lines[marks]))
}

# Prose only: everything outside fenced blocks.
prose <- function(lines) {
  fence <- cumsum(grepl("^```", lines)) %% 2 == 1 | grepl("^```", lines)
  lines[!fence]
}

test_that("both guides show the twelve equations exactly as in the fixture, numbered A1 to A12", {
  fixture <- equation_blocks(read_lines(fixture_path("equations.md")))
  expect_length(fixture, 12)
  for (g in guides) {
    lines <- read_lines(g)
    equations <- equation_blocks(lines)
    expect_setequal(names(equations), names(fixture))
    expect_identical(equations[names(fixture)], fixture, info = basename(g))
    expect_equal(sum(lines == "```math"), 12, info = basename(g))
    labels <- regmatches(lines, regexpr("^\\*\\*(Equation|Gleichung) A[0-9]+ \\(`eq-[a-z-]+`\\)", lines))
    expect_identical(sub("^.* A([0-9]+) .*$", "\\1", labels), as.character(1:12), info = basename(g))
    expect_identical(sub("^.*`(eq-[a-z-]+)`.*$", "\\1", labels), names(equations), info = basename(g))
  }
})

test_that("code and output blocks are identical in both guides", {
  blocks <- lapply(guides, function(g) fenced_blocks(read_lines(g)))
  expect_gt(length(blocks[[1]]), 40)
  expect_identical(blocks[[1]], blocks[[2]])
})

test_that("the complete example is examples/complete_analysis.R and its twelve outputs are current", {
  script <- file.path(.proj_root, "examples", "complete_analysis.R")
  old_wd <- setwd(.proj_root)
  old_options <- options(width = 100, digits = 7)
  on.exit({ setwd(old_wd); options(old_options) }, add = TRUE)
  env <- new.env(parent = globalenv())
  outputs <- list()
  for (e in parse(script, keep.source = FALSE)) {
    printed <- utils::capture.output(eval(e, envir = env))
    if (is.call(e) && identical(e[[1L]], as.name("print"))) outputs[[length(outputs) + 1L]] <- printed
  }
  expect_length(outputs, 12)
  for (g in guides) {
    lines <- read_lines(g)
    expect_true(any(vapply(fenced_blocks(lines, "r"), identical, logical(1), read_lines(script))),
                info = basename(g))
    expect_identical(fenced_blocks(lines, "text"), outputs, info = basename(g))
  }
})

test_that("the embedded Atacora screen is atacora_DA_axes.R, in fewer than 100 lines", {
  screen <- read_lines(file.path(.proj_root, "atacora_DA_axes.R"))
  expect_lt(length(screen), 100)
  for (g in guides)
    expect_true(any(vapply(fenced_blocks(read_lines(g), "r"), identical, logical(1), screen)),
                info = basename(g))
})

test_that("every excerpt from R/ appears in its file as consecutive lines", {
  for (g in guides) {
    lines <- read_lines(g)
    marks <- grep("^<!-- from R/[A-Za-z_]+\\.R -->$", lines)
    expect_gt(length(marks), 3)
    for (m in marks) {
      path <- sub("^<!-- from (R/[A-Za-z_]+\\.R) -->$", "\\1", lines[m])
      expect_identical(lines[m + 1], "```r", info = path)
      excerpt <- trimws(fenced_blocks(lines[m:length(lines)], "r")[[1]])
      source_lines <- trimws(read_lines(file.path(.proj_root, path)))
      n <- length(excerpt)
      found <- vapply(seq_len(length(source_lines) - n + 1), function(i)
        identical(source_lines[i:(i + n - 1)], excerpt), logical(1))
      expect_true(any(found), info = paste(basename(g), path))
    }
  }
})

test_that("the complete example calls all 16 public functions, and their examples run", {
  files <- list.files(file.path(.proj_root, "R"), "[.]R$", full.names = TRUE)
  public <- unlist(lapply(files, function(f) {
    lines <- read_lines(f)
    defined <- sub(" <- function.*$", "", lines[grep("^#' @export", lines) + 1])
    defined[!startsWith(defined, "print.")]
  }))
  expect_length(public, 16)
  called <- all.names(parse(file.path(.proj_root, "examples", "complete_analysis.R")))
  expect_true(all(public %in% called), info = paste(setdiff(public, called), collapse = ", "))
  env <- new.env(parent = globalenv())
  for (f in files) sys.source(f, env)
  count <- 0L
  for (f in files) {
    lines <- read_lines(f)
    for (start in grep("^#' @examples", lines)) {
      end <- min(which(seq_along(lines) > start & lines == "#' @export"))
      example <- sub("^#' ?", "", lines[(start + 1L):(end - 1L)])
      expect_error(utils::capture.output(eval(parse(text = example), envir = env)), NA, info = basename(f))
      count <- count + 1L
    }
  }
  expect_equal(count, 16L)
})

test_that("both guides have the same anchors, and every link and named file exists", {
  anchors <- function(lines)
    regmatches(lines, regexpr('(?<=^<span id=")[^"]+(?="></span>$)', lines, perl = TRUE))
  ids <- lapply(guides, function(g) anchors(read_lines(g)))
  expect_gt(length(ids[[1]]), 20)
  expect_identical(ids[[1]], ids[[2]])
  expect_false(anyDuplicated(ids[[1]]) > 0)
  for (i in seq_along(guides)) {
    text <- paste(prose(read_lines(guides[i])), collapse = "\n")
    targets <- regmatches(text, gregexpr("(?<=\\]\\()[^)[:space:]]+(?=\\))", text, perl = TRUE))[[1]]
    internal <- sub("^#", "", targets[startsWith(targets, "#")])
    expect_true(all(internal %in% ids[[i]]), info = paste(setdiff(internal, ids[[i]]), collapse = ", "))
    named <- c(targets[!grepl("^(#|https?:|mailto:)", targets)],
               gsub("`", "", regmatches(text, gregexpr("`[A-Za-z0-9_./-]+[.](R|md|qmd|csv|png)`", text))[[1]]))
    named <- unique(sub("#.*$", "", named))
    present <- file.exists(file.path(.proj_root, named)) & !grepl("^outputs/", named)
    expect_true(all(present), info = paste(basename(guides[i]), paste(named[!present], collapse = ", ")))
  }
})
