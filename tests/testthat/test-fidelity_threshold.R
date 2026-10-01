# fidelity_threshold() (handoff v7, 6): the share f* of an option's effect that must arrive for it
# to stay (or become) recommended. Checked on the worked example of the check battery (v5, 3.10a)
# and on the edge cases the handoff names: a dominant option, identical options.

worked <- list(women = cbind(sq = 0, A = c(10, 8, 6, 0), B = c(1, 2, 1, 2)),
               men   = cbind(sq = 0, A = c(2, 0, -4, 2), B = c(4, 2, 3, 3)))
p <- c(women = 0.5, men = 0.5)

test_that("the worked example: utilitarian A 3.0 against B 2.25, so f*(A) = 0.75", {
  ft <- fidelity_threshold(worked, p, w_utilitarian())
  expect_s3_class(ft, "fidelity_threshold")
  expect_identical(ft$option, c("sq", "A", "B"))
  expect_equal(ft$value, c(0, 3, 2.25))
  expect_identical(ft$recommended, c(FALSE, TRUE, FALSE))
  expect_equal(ft$f_star[ft$option == "A"], 0.75, tolerance = 1e-8)
  expect_true(all(is.na(ft$f_star[!ft$recommended])))           # B would need more than its full effect
  # at f* the scaled A ties with B: A = 0.75 x 3.0 = 2.25
  scaled <- worked; for (g in names(scaled)) scaled[[g]][, "A"] <- 0.75 * scaled[[g]][, "A"]
  sc <- fairness_screen(scaled, p, list(u = w_utilitarian()))$scores
  expect_equal(sc["A", "u"], sc["B", "u"])
})

test_that("maximin and prioritarian: the same definition, other values", {
  mm <- fidelity_threshold(worked, p, w_maximin())               # B 1.5 against sq 0 and A -0.5
  expect_identical(mm$option[mm$recommended], "B")
  expect_equal(mm$f_star[mm$option == "B"], 0)                   # the runner-up is the status quo
  pr <- fidelity_threshold(worked, p, w_prioritarian(function(z) ifelse(z < 0, 2 * z, z)))
  expect_equal(pr$f_star[pr$option == "A"], 2.25 / 2.5, tolerance = 1e-8)
})

test_that("a dominant option: f* is the best other value over its own", {
  dominant <- list(women = cbind(sq = 0, A = c(5, 6, 7, 8), B = c(1, 2, 1, 2)),
                   men   = cbind(sq = 0, A = c(4, 3, 5, 3), B = c(1, 0, 2, 1)))
  ft <- fidelity_threshold(dominant, p, w_utilitarian())
  expect_equal(ft$f_star[ft$option == "A"], 1.25 / 5.125, tolerance = 1e-8)
  expect_true(is.na(ft$f_star[ft$option == "B"]))
})

test_that("identical options: any loss of fidelity switches, f* = 1 for both", {
  same <- list(women = cbind(sq = 0, A = c(1, 2, 3, 4), B = c(1, 2, 3, 4)),
               men   = cbind(sq = 0, A = c(2, 2, 2, 2), B = c(2, 2, 2, 2)))
  ft <- fidelity_threshold(same, p, w_utilitarian())
  expect_equal(ft$f_star[ft$option %in% c("A", "B")], c(1, 1), tolerance = 1e-8)
  expect_identical(ft$option[ft$recommended], "A")               # the first one on ties
})

test_that("renaming and reordering changes nothing; one group and one option work", {
  perm <- lapply(worked[c("men", "women")], function(m) { m <- m[, c("B", "sq", "A")]; colnames(m) <- c("o2", "o0", "o1"); m })
  a <- fidelity_threshold(worked, p, w_utilitarian())
  b <- fidelity_threshold(perm, c(men = 0.5, women = 0.5), w_utilitarian())
  expect_equal(b$f_star[b$option == "o1"], a$f_star[a$option == "A"], tolerance = 1e-10)
  one <- fidelity_threshold(list(g = cbind(x = c(1, 2))), 1, w_utilitarian())
  expect_identical(one$f_star, 0)
  expect_error(fidelity_threshold(worked, p, w_utilitarian(), tol = 0), "tol")
})
