# Run from the project root. Loads the functions of R/ into the calling environment;
# source("load.R", local = TRUE) keeps them out of the global environment.
for (.review_file in list.files("R", pattern = "[.]R$", full.names = TRUE)) {
  sys.source(.review_file, envir = environment())
}
rm(.review_file)
