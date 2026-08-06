# Tests for coverage.R — the only thing in this directory that distinguishes a round that was
# SCORED from one that was IGNORED.
#
# Until 2026-08-06 the R here was gated by `parse()` and nothing else: a wrong reclassify, a wrong
# score or a wrong coverage fraction could not be caught by CI. That is a poor place to have no
# tests, because the failure it guards against is silent by construction — reclassify() drops ids
# it does not recognise without a word, and the round returns 200 with finite scores either way.
#
# Base R and `stopifnot`, deliberately: no testthat, no raster, no GDAL. coverage.R's arithmetic
# was split out of the raster read (esgame_coverage_stats) precisely so these can run anywhere R
# runs, which is what lets them live in a CI job that already has R and installs nothing.
#
#   Rscript calculation/test-coverage.R

here <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
if (is.na(here) || !nzchar(here)) here <- "calculation"
source(file.path(here, "coverage.R"))

failed <- 0
ran <- 0
ok <- function(label, expr) {
  ran <<- ran + 1
  result <- tryCatch(isTRUE(expr), error = function(e) structure(FALSE, msg = conditionMessage(e)))
  if (isTRUE(result)) {
    cat("  ok   ", label, "\n", sep = "")
  } else {
    cat("  FAIL ", label, if (!is.null(attr(result, "msg"))) paste0("  (", attr(result, "msg"), ")") else "", "\n", sep = "")
    failed <<- failed + 1
  }
}

cat("==> esgame_allocation_ids: the shapes jsonlite can hand us\n")
# The real one: jsonlite turns [{"id":1,"lulc":10},...] into a data.frame, id first.
ok("reads ids from a data.frame", identical(esgame_allocation_ids(
  data.frame(id = c(10, 20, 30), lulc = c(1, 2, 3))), c(10, 20, 30)))
ok("reads the FIRST column, not the lulc", identical(esgame_allocation_ids(
  data.frame(id = c(7, 8), lulc = c(99, 99))), c(7, 8)))
ok("reads ids from a matrix", identical(esgame_allocation_ids(
  matrix(c(1, 2, 3, 4), ncol = 2)), c(1, 2)))
ok("reads a bare numeric vector", identical(esgame_allocation_ids(c(5, 6)), c(5, 6)))
ok("reads numeric strings", identical(esgame_allocation_ids(c("5", "6")), c(5, 6)))
# Absence must be empty, never an error: this is a diagnostic and must not take a round down.
ok("NULL is no ids, not an error", identical(esgame_allocation_ids(NULL), numeric(0)))
ok("a zero-column frame is no ids", identical(esgame_allocation_ids(data.frame()), numeric(0)))
ok("unparseable ids become NA rather than throwing",
   all(is.na(esgame_allocation_ids(c("apple", "pear")))))

cat("==> esgame_coverage_stats: the number that says scored or ignored\n")
# The case this whole mechanism exists for. The raster committed to this repository numbers its
# hexagons 10-474; the board numbers its own 100-46500 in hundreds. Four ids in common out of 465.
board <- seq(100, 46500, by = 100)
raster_ids <- 10:474
s <- esgame_coverage_stats(board, raster_ids)
ok("the committed raster matches 4 of 465", s$allocated == 465 && s$matched == 4)
ok("...which is about 1%, not a rounding artefact", abs(s$fraction - 4 / 465) < 1e-12)
ok("...and is below the warn threshold", s$fraction < 0.5)

s <- esgame_coverage_stats(1:10, 1:10)
ok("a fully matching allocation is 1", s$fraction == 1 && s$matched == 10)
s <- esgame_coverage_stats(1:10, 100:110)
ok("a fully disjoint allocation is 0", s$fraction == 0 && s$matched == 0)
s <- esgame_coverage_stats(1:10, 6:15)
ok("a half-matching allocation is 0.5", s$matched == 5 && s$fraction == 0.5)

cat("==> and the edges that would produce a misleading number\n")
# Duplicates must not inflate either side, or a payload repeating one id looks like broad coverage.
s <- esgame_coverage_stats(c(1, 1, 1, 2), c(1, 1))
ok("duplicate ids are counted once", s$allocated == 2 && s$matched == 1 && s$fraction == 0.5)
# Division by zero here would give NaN, and NaN < 0.5 is FALSE — so an empty allocation would
# silently skip the warning it most deserves.
s <- esgame_coverage_stats(numeric(0), 1:10)
ok("an empty allocation is 0, not NaN", s$allocated == 0 && s$fraction == 0 && !is.nan(s$fraction))
s <- esgame_coverage_stats(1:10, numeric(0))
ok("an empty raster is 0 matched, not an error", s$matched == 0 && s$fraction == 0)
# NAs come from ids that did not parse; counting them would overstate the allocation.
s <- esgame_coverage_stats(c(1, NA, 2), c(1, 2, NA))
ok("NA ids are dropped from both sides", s$allocated == 2 && s$matched == 2)

cat("==> end to end, the way calculation.r uses it\n")
alloc <- data.frame(id = board, lulc = rep(10, length(board)))
s <- esgame_coverage_stats(esgame_allocation_ids(alloc), raster_ids)
ok("a real request shape gives the same 4 of 465", s$allocated == 465 && s$matched == 4)

cat("\n")
# Presence first: a rename that made every `ok` disappear would otherwise report success.
if (ran < 15) {
  cat("coverage.R tests: FAIL   only ", ran, " assertions ran; this file has more than that\n", sep = "")
  quit(status = 1)
}
if (failed == 0) {
  cat("coverage.R tests: PASS   ", ran, "/", ran, " assertions\n", sep = "")
} else {
  cat("coverage.R tests: FAIL   ", ran - failed, "/", ran, " assertions\n", sep = "")
  quit(status = 1)
}
