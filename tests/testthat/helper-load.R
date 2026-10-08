# Source every function file relative to the project root.
# testthat sets the working directory to tests/testthat/.
.proj_root <- normalizePath(file.path("..", ".."), mustWork = TRUE)
for (.f in list.files(file.path(.proj_root, "R"), pattern = "[.]R$",
                      full.names = TRUE)) source(.f)
fixture_path <- function(...) file.path(.proj_root, "tests", "testthat",
                                        "fixtures", ...)
raw_data_dir <- function() file.path(.proj_root, "data", "raw", "whitney2025",
                                     "data")

# Test-only wrapper. The library functions deliberately have NO defaults for
# p or W (FUNCTIONS.md, "Shared arguments"). The wrapper fixes the conventional choice so that
# tests which are *about* something else stay short. Tests about the choices
# themselves call the functions directly.
vp <- function(nb, p, W = w_utilitarian(), ...) voi_partition(nb, p, W, ...)
