#' Add an interactive FlowmapGL legend
#'
#' Shows the current flow-width and location-circle scale, with an optional
#' button to lock or unlock both scales. Legend values refresh as the flowmap
#' updates. Requires a flowmap already added with [add_flowmap()].
#'
#' @param map A map object created with [maplibre()] or [mapboxgl()].
#' @param id ID of an existing flowmap layer (not the legend's ID).
#' @param placement One of `"top-left"`, `"top-right"`, `"bottom-left"`,
#'   `"bottom-right"`.
#' @param sections Which sections to show: `"flowThickness"` and/or
#'   `"locationCircles"`.
#' @param show_lock_control Whether to show the button for locking the scales.
#'
#' @return The modified map object.
#' @export
#'
#' @examples
#' maplibre(projection = "mercator") |>
#'   add_flowmap("trips", bixi_locations, bixi_flows) |>
#'   add_flowmap_legend("trips")
add_flowmap_legend <- function(
  map,
  id,
  placement = c("bottom-left", "bottom-right", "top-left", "top-right"),
  sections = c("flowThickness", "locationCircles"),
  show_lock_control = TRUE
) {
  if (!inherits(map, "mapboxgl") && !inherits(map, "maplibregl")) {
    rlang::abort("`map` must be a map created by `maplibre()` or `mapboxgl()`.")
  }
  id <- flowmap_validate_optional_string(id, "id")
  if (is.null(id) || !length(map$x$flowmaps) ||
      !any(vapply(map$x$flowmaps, function(layer) identical(layer$id, id), logical(1)))) {
    rlang::abort("`id` must identify a flowmap already added to `map`.")
  }
  placement <- match.arg(placement)
  choices <- c("flowThickness", "locationCircles")
  if (!is.character(sections) || !length(sections) || anyNA(sections) ||
      anyDuplicated(sections) || any(!sections %in% choices)) {
    rlang::abort("`sections` must contain unique values from `flowThickness` and `locationCircles`.")
  }
  flowmap_validate_logical(show_lock_control, "show_lock_control")
  entry <- list(
    id = id,
    placement = placement,
    sections = I(sections),
    showLockControl = show_lock_control
  )
  old <- map$x$flowmapLegends
  if (is.null(old)) old <- list()
  old <- Filter(function(legend) !identical(legend$id, id), old)
  map$x$flowmapLegends <- c(old, list(entry))
  map
}
