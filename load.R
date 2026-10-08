# Run from the project root. Loads the functions of R_functions/ into the calling environment;
# source("load.R", local = TRUE) keeps them out of the global environment.
for (.function_file in list.files("R_functions", pattern = "[.]R$", full.names = TRUE)) {
  sys.source(.function_file, envir = environment())
}
rm(.function_file)
