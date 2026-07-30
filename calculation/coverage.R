# Does the allocation actually land on the base raster?
#
# raster::reclassify() ignores any id that is not present in the raster. It does not warn, it
# does not error, and the round that follows returns 200 with a full set of published coverages
# and finite-looking scores. If the ids belong to a different id space, those scores are a
# constant: the same numbers whatever the player does.
#
# This is not hypothetical. The copy of LU_and_NEW_hexa.tif committed under
# v2/src/assets/images numbers its hexagons 10-474; the board (New_hexagons.tif) numbers its own
# 100-46500 in hundreds. Four ids in common out of 465. Three different land-use patterns over
# those 465 ids returned byte-identical scores — and that constant was quoted in the docs as
# evidence of a working round for months.
#
# So: say how much of the allocation matched, every time, and warn loudly when it is a small
# fraction. Sourced by calculator.r; places' calculation.r carries the same function.

esgame_allocation_ids <- function(map_AG) {
  # The allocation arrives as a data.frame (id, lulc) via jsonlite, but tolerate a matrix or a
  # plain vector of ids rather than failing the round over a shape this only inspects.
  if (is.null(map_AG)) return(numeric(0))
  if (is.data.frame(map_AG) || is.matrix(map_AG)) {
    if (ncol(map_AG) < 1) return(numeric(0))
    return(suppressWarnings(as.numeric(map_AG[, 1])))
  }
  suppressWarnings(as.numeric(map_AG))
}

# Returns the stats invisibly so a caller can assert on them; logs as a side effect.
esgame_report_coverage <- function(LU_hexa, map_AG, warn_below = 0.5) {
  stats <- tryCatch({
    alloc <- unique(stats::na.omit(esgame_allocation_ids(map_AG)))
    present <- unique(stats::na.omit(raster::values(LU_hexa)))
    matched <- length(intersect(alloc, present))
    list(allocated = length(alloc),
         matched   = matched,
         fraction  = if (length(alloc)) matched / length(alloc) else 0)
  }, error = function(e) NULL)

  # Never let a diagnostic break a round.
  if (is.null(stats)) {
    logger::log_warn("Could not compute allocation coverage; continuing.")
    return(invisible(NULL))
  }

  logger::log_info(
    "Allocation coverage: {stats$matched} of {stats$allocated} ids exist in LU_and_NEW_hexa.tif ({round(100 * stats$fraction)}%).")

  if (stats$allocated == 0) {
    logger::log_warn("Allocation is empty; the round will score the base raster unchanged.")
  } else if (stats$fraction < warn_below) {
    logger::log_warn(paste(
      "Only {round(100 * stats$fraction)}% of the allocation matches the base raster, so most of it",
      "is being IGNORED. The scores below will barely depend on the allocation, and may be identical",
      "for every round. This usually means the allocation and /app/data/LU_and_NEW_hexa.tif are in",
      "different id spaces - check that /app/data holds the data-release raster and not the copy",
      "shipped in the frontend assets."))
  }
  invisible(stats)
}
