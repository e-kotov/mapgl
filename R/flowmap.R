#' Add a flowmap layer to visualize origin-destination flows
#'
#' Creates an interactive flowmap visualization using deck.gl's FlowmapLayer.
#' Flowmaps show movement between locations using curved lines with thickness
#' proportional to flow magnitude. Includes automatic clustering, animation,
#' and adaptive scaling.
#'
#' @param map A map object created by the `mapboxgl()` or `maplibre()` functions.
#' @param id A unique ID for the flowmap layer.
#' @param locations A data.frame or sf object containing location data. Must have columns:
#'   - id: unique location identifier
#'   - lat, lon: coordinates (or use sf geometry)
#'   - name: optional location name for labels
#' @param flows A data.frame containing flow data. Must have columns:
#'   - origin: origin location id (must match locations$id)
#'   - dest: destination location id (must match locations$id)
#'   - count: flow magnitude/weight
#' @param flow_color_scheme Color scheme for flows. Can be a preset name (e.g., "Teal", "Purple",
#'   "Blue") or a vector of color hex codes. Default is "Teal".
#' @param flow_dark_mode Whether to use dark mode styling. Default is TRUE.
#' @param flow_animation Whether to animate flow lines. Default is FALSE.
#' @param flow_fade Whether to fade flow lines by magnitude. Default is TRUE.
#' @param flow_fade_amount Fade amount (0-100). Default is 50.
#' @param flow_fade_opacity Whether fade affects opacity. Default is FALSE.
#' @param flow_locations Whether to show location circles. Default is TRUE.
#' @param flow_location_totals Whether location circles scale by totals. Default is TRUE.
#' @param flow_location_labels Whether to show location labels. Default is FALSE.
#' @param flow_clustering Whether to enable location clustering. Default is TRUE.
#' @param flow_clustering_auto Whether to auto-adjust clustering level. Default is TRUE.
#' @param flow_clustering_level Manual clustering zoom level (0-20). Only used if flow_clustering_auto is FALSE.
#' @param flow_clustering_method Clustering algorithm to use. Either "HCA" (Hierarchical Cluster Analysis) or "H3" (H3 hexagonal hierarchical spatial index). Default is "HCA".
#' @param flow_adaptive_scales Whether to use adaptive scaling. Default is TRUE.
#' @param flow_highlight_color Color for highlighting on hover. Default is "#ff9b29".
#' @param flow_max_flows Maximum number of top flows to display. Default is 5000.
#' @param flow_opacity Overall opacity of the flowmap layer (0-1). Default is 1.0.
#' @param flow_outline_width Width of the flow line outline in pixels. Default is 0.
#' @param flow_line_curviness Curviness of the flow lines (0 to 1). Default is 0.5.
#' @param flow_line_thickness_scale Global multiplier for flow line thickness. Default is 1.0.
#' @param flow_endpoints_in_viewport_mode How to handle flows when only one endpoint is in the viewport. Either "any" (show flows if any endpoint is visible) or "all" (show all flows). Default is "any".
#' @param flow_curved_arrows Whether to use the new curved arrows layer for flows. Default is FALSE.
#' @param flow_show_settings Whether to display an interactive settings menu on the map for real-time customization. Useful for exploring different visual configurations. Default is FALSE.
#' @param flow_dim_basemap Whether to apply CSS filters to dim the basemap and make the flowmap stand out. Default is FALSE, matching the upstream flowmap.gl demo.
#' @param flow_blend_mode Blending mode. One of "normal", "screen", or "glow". Default is "screen" for standalone flowmaps, matching the upstream flowmap.gl demo, and "normal" for interleaved flowmaps because CSS blending requires a separate canvas.
#'   - "normal": No special blending (default).
#'   - "screen": Applies CSS `mix-blend-mode` to the deck.gl canvas for a screen (dark mode) or darken (light mode) blending effect. Creates a subtle glow where flows overlap. **Only works when `before_id = NULL`** because CSS blending requires a separate deck.gl canvas.
#'   - "glow": Applies WebGL blend functions (`SRC_ALPHA, ONE_MINUS_DST_COLOR`) for a more pronounced glow/accumulation effect. Works best in dark mode. **Works with both `before_id = NULL` and when layer ordering is enabled.**
#' @param visibility Whether this layer is displayed.
#' @param slot An optional slot for layer order. Recommended for Mapbox Standard style (e.g., "bottom", "middle", "top").
#' @param min_zoom The minimum zoom level for the layer (not currently supported for flowmap layers).
#' @param max_zoom The maximum zoom level for the layer (not currently supported for flowmap layers).
#' @param before_id The ID of a map layer to insert this flowmap "before" (i.e., below). When set, the flowmap will respect the map's layer ordering and appear at the specified position in the layer stack. This uses deck.gl's `MapboxOverlay` with `interleaved: true` mode.
#'
#'   **Trade-off**: When `before_id` is set, CSS blend modes (`flow_blend_mode = "screen"`) are disabled because interleaved rendering shares the map's WebGL context. The "glow" WebGL blend mode still works.
#'
#'   When `before_id = NULL` (default), the flowmap renders on a separate canvas on top of all map layers, which enables CSS blend modes but ignores layer ordering.
#' @param popup A column name from locations or flows to display in a popup on click.
#' @param tooltip A column name from locations or flows to display in a tooltip on hover.
#' @param hover_options A named list of options for highlighting features in the layer on hover (not currently supported for flowmap layers).
#' @param filter An optional filter expression to subset features in the layer (not currently supported for flowmap layers).
#'
#' @return The modified map object with the flowmap layer added.
#' @export
#'
#' @examples
#' \dontrun{
#' library(mapgl)
#'
#' # Create sample location data
#' locations <- data.frame(
#'   id = c("NYC", "LA", "CHI", "HOU", "PHX"),
#'   name = c("New York", "Los Angeles", "Chicago", "Houston", "Phoenix"),
#'   lat = c(40.7128, 34.0522, 41.8781, 29.7604, 33.4484),
#'   lon = c(-74.0060, -118.2437, -87.6298, -95.3698, -112.0740)
#' )
#'
#' # Create sample flow data
#' flows <- data.frame(
#'   origin = c("NYC", "LA", "CHI", "NYC", "LA"),
#'   dest = c("LA", "CHI", "HOU", "PHX", "NYC"),
#'   count = c(1000, 750, 500, 300, 1200)
#' )
#'
#' # Create a map with flowmap layer
#' maplibre(
#'   center = c(-95, 37),
#'   zoom = 3
#' ) %>%
#'   add_flowmap(
#'     id = "flows",
#'     locations = locations,
#'     flows = flows,
#'     flow_color_scheme = "Teal",
#'     flow_animation = FALSE
#'   )
#' }
add_flowmap <- function(
  map,
  id,
  locations,
  flows,
  flow_color_scheme = "Teal",
  flow_dark_mode = TRUE,
  flow_animation = FALSE,
  flow_fade = TRUE,
  flow_fade_amount = 50,
  flow_fade_opacity = FALSE,
  flow_locations = TRUE,
  flow_location_totals = TRUE,
  flow_location_labels = FALSE,
  flow_clustering = TRUE,
  flow_clustering_auto = TRUE,
  flow_clustering_level = NULL,
  flow_clustering_method = "HCA",
  flow_adaptive_scales = TRUE,
  flow_highlight_color = "#ff9b29",
  flow_max_flows = 5000,
  flow_opacity = 1,
  flow_outline_width = 0,
  flow_line_curviness = 0.5,
  flow_line_thickness_scale = 1,
  flow_endpoints_in_viewport_mode = c("any", "all"),
  flow_curved_arrows = FALSE,
  flow_show_settings = FALSE,
  flow_dim_basemap = NULL,
  flow_blend_mode = NULL,
  visibility = "visible",
  slot = NULL,
  min_zoom = NULL,
  max_zoom = NULL,
  before_id = NULL,
  popup = NULL,
  tooltip = NULL,
  hover_options = NULL,
  filter = NULL
) {
  # Determine if interleaved mode is needed (for layer ordering)
  # When before_id or slot is set, we use MapboxOverlay with interleaved: true
  use_interleaved <- !is.null(before_id) || !is.null(slot)

  if (is.null(flow_blend_mode)) {
    flow_blend_mode <- if (use_interleaved) "normal" else "screen"
  } else {
    flow_blend_mode <- match.arg(flow_blend_mode, c("normal", "screen", "glow"))
  }

  # The upstream demo uses mix-blend-mode without dimming the basemap.
  if (is.null(flow_dim_basemap)) {
    flow_dim_basemap <- FALSE
  }

  # Map simplified mode to internal booleans
  css_blend_mode <- flow_blend_mode == "screen"
  webgl_blend_mode <- flow_blend_mode == "glow"

  # Warn about trade-offs
  if (use_interleaved && css_blend_mode) {
    warning(
      "flow_blend_mode = 'screen' (CSS blending) is disabled when before_id is set. ",
      "CSS blend modes require a separate canvas, which conflicts with layer ordering. ",
      "Consider using flow_blend_mode = 'glow' (WebGL blending) instead, which works with layer ordering."
    )
    css_blend_mode <- FALSE
  }

  if (webgl_blend_mode && !flow_dark_mode) {
    warning(
      "flow_blend_mode = 'glow' is intended for use with flow_dark_mode = TRUE. Colors may appear inverted or washed out on light backgrounds."
    )
  }

  if (
    use_interleaved &&
      !is.null(map$x$projection) &&
      !identical(map$x$projection, "mercator")
  ) {
    warning(
      "Interleaved flowmap layers are not supported with non-Mercator projections. ",
      "Setting projection = 'mercator' for this map."
    )
    map$x$projection <- "mercator"
  }

  # Validate inputs
  if (!is.data.frame(locations) && !inherits(locations, "sf")) {
    stop("locations must be a data.frame or sf object")
  }

  if (!is.data.frame(flows)) {
    stop("flows must be a data.frame")
  }

  # Validate opacity
  if (!is.numeric(flow_opacity) || flow_opacity < 0 || flow_opacity > 1) {
    stop("flow_opacity must be a number between 0 and 1")
  }

  # Validate clustering_method
  if (!flow_clustering_method %in% c("HCA", "H3")) {
    stop("flow_clustering_method must be either 'HCA' or 'H3'")
  }

  # Validate color_scheme if string
  if (is.character(flow_color_scheme) && length(flow_color_scheme) == 1) {
    valid_schemes <- c(
      "Blues",
      "BluGrn",
      "BluYl",
      "BrwnYl",
      "BuGn",
      "BuPu",
      "Burg",
      "BurgYl",
      "Cool",
      "DarkMint",
      "Emrld",
      "GnBu",
      "Grayish",
      "Greens",
      "Greys",
      "Inferno",
      "Magenta",
      "Magma",
      "Mint",
      "Oranges",
      "OrRd",
      "OrYel",
      "Peach",
      "Plasma",
      "PinkYl",
      "PuBu",
      "PuBuGn",
      "PuRd",
      "Purp",
      "Purples",
      "PurpOr",
      "RdPu",
      "RedOr",
      "Reds",
      "Sunset",
      "SunsetDark",
      "Teal",
      "TealGrn",
      "Viridis",
      "Warm",
      "YlGn",
      "YlGnBu",
      "YlOrBr",
      "YlOrRd"
    )
    if (!flow_color_scheme %in% valid_schemes) {
      warning(
        "Unknown color scheme '",
        flow_color_scheme,
        "'. ",
        "Valid schemes are: ",
        paste(valid_schemes, collapse = ", ")
      )
    }
  }

  # Process locations data
  if (inherits(locations, "sf")) {
    # Extract coordinates from sf geometry
    if (sf::st_crs(locations) != 4326) {
      locations <- sf::st_transform(locations, crs = 4326)
    }
    coords <- sf::st_coordinates(locations)
    locations_df <- as.data.frame(locations)
    locations_df$lon <- coords[, 1]
    locations_df$lat <- coords[, 2]
    # Remove geometry column
    locations_df <- sf::st_drop_geometry(locations_df)
  } else {
    locations_df <- locations
  }

  # Validate required columns for locations
  required_loc_cols <- c("id", "lat", "lon")
  missing_cols <- setdiff(required_loc_cols, names(locations_df))
  if (length(missing_cols) > 0) {
    stop(paste(
      "locations is missing required columns:",
      paste(missing_cols, collapse = ", ")
    ))
  }

  # Validate required columns for flows
  required_flow_cols <- c("origin", "dest", "count")
  missing_cols <- setdiff(required_flow_cols, names(flows))
  if (length(missing_cols) > 0) {
    stop(paste(
      "flows is missing required columns:",
      paste(missing_cols, collapse = ", ")
    ))
  }

  # Validate data types for locations
  if (!is.numeric(locations_df$lat)) {
    stop("locations$lat must be numeric")
  }
  if (!is.numeric(locations_df$lon)) {
    stop("locations$lon must be numeric")
  }

  # Validate data types for flows
  if (!is.numeric(flows$count)) {
    stop("flows$count must be numeric")
  }

  # Convert id columns to character (handle factors)
  locations_df$id <- as.character(locations_df$id)
  flows$origin <- as.character(flows$origin)
  flows$dest <- as.character(flows$dest)

  # Add name column if not present
  if (!"name" %in% names(locations_df)) {
    locations_df$name <- locations_df$id
  } else {
    locations_df$name <- as.character(locations_df$name)
  }

  # Check for NA values
  if (
    any(is.na(locations_df$id)) ||
      any(is.na(locations_df$lat)) ||
      any(is.na(locations_df$lon))
  ) {
    stop("locations contains NA values in required columns (id, lat, lon)")
  }
  if (
    any(is.na(flows$origin)) ||
      any(is.na(flows$dest)) ||
      any(is.na(flows$count))
  ) {
    stop("flows contains NA values in required columns (origin, dest, count)")
  }

  # Validate that flow origin/dest IDs exist in locations
  location_ids <- unique(locations_df$id)
  invalid_origins <- setdiff(unique(flows$origin), location_ids)
  invalid_dests <- setdiff(unique(flows$dest), location_ids)
  if (length(invalid_origins) > 0) {
    warning(paste(
      "Some flow origins not found in locations:",
      paste(head(invalid_origins, 5), collapse = ", "),
      if (length(invalid_origins) > 5) "..." else ""
    ))
  }
  if (length(invalid_dests) > 0) {
    warning(paste(
      "Some flow destinations not found in locations:",
      paste(head(invalid_dests, 5), collapse = ", "),
      if (length(invalid_dests) > 5) "..." else ""
    ))
  }

  # DATA SERIALIZATION OPTIMIZATION:
  # Pass data.frames directly in columnar format (R's native format).
  # htmlwidgets will serialize as: {"id": ["A","B"], "lat": [40.7, 34]}
  #
  # The JavaScript code uses HTMLWidgets.dataframeToD3() to efficiently convert
  # columnar format to the row-oriented array that flowmap.gl expects:
  # [{"id":"A","lat":40.7}, {"id":"B","lat":34}]

  # Select only required columns for locations
  locations_cols <- c("id", "lat", "lon", "name")
  # Include additional columns if they exist and might be used for popup/tooltip
  if (
    !is.null(popup) &&
      popup %in% names(locations_df) &&
      !popup %in% locations_cols
  ) {
    locations_cols <- c(locations_cols, popup)
  }
  if (
    !is.null(tooltip) &&
      tooltip %in% names(locations_df) &&
      !tooltip %in% locations_cols
  ) {
    locations_cols <- c(locations_cols, tooltip)
  }
  # Ensure clean data.frame (not sf or tibble)
  locations_subset <- as.data.frame(locations_df[,
    locations_cols,
    drop = FALSE
  ])

  # Select only required columns for flows
  flows_cols <- c("origin", "dest", "count")
  if (!is.null(popup) && popup %in% names(flows) && !popup %in% flows_cols) {
    flows_cols <- c(flows_cols, popup)
  }
  if (
    !is.null(tooltip) && tooltip %in% names(flows) && !tooltip %in% flows_cols
  ) {
    flows_cols <- c(flows_cols, tooltip)
  }
  # Ensure clean data.frame
  flows_subset <- as.data.frame(flows[, flows_cols, drop = FALSE])

  # Create flowmap configuration
  flowmap_config <- list(
    id = id,
    data = list(
      locations = locations_subset,
      flows = flows_subset
    ),
    settings = list(
      colorScheme = flow_color_scheme,
      darkMode = flow_dark_mode,
      opacity = flow_opacity,
      outlineWidth = flow_outline_width,
      animationEnabled = flow_animation,
      fadeEnabled = flow_fade,
      fadeAmount = flow_fade_amount,
      fadeOpacityEnabled = flow_fade_opacity,
      locationsEnabled = flow_locations,
      locationTotalsEnabled = flow_location_totals,
      locationLabelsEnabled = flow_location_labels,
      clusteringEnabled = flow_clustering,
      clusteringAuto = flow_clustering_auto,
      clusteringMethod = flow_clustering_method,
      clusteringLevel = flow_clustering_level,
      adaptiveScalesEnabled = flow_adaptive_scales,
      highlightColor = flow_highlight_color,
      maxTopFlowsDisplayNum = flow_max_flows,
      flowLineCurviness = flow_line_curviness,
      flowLineThicknessScale = flow_line_thickness_scale,
      flowEndpointsInViewportMode = match.arg(flow_endpoints_in_viewport_mode),
      useCurvedArrows = flow_curved_arrows
    ),

    showSettingsMenu = flow_show_settings,
    dimBasemap = flow_dim_basemap,
    cssBlendMode = css_blend_mode,
    webglBlendMode = webgl_blend_mode,
    interleaved = use_interleaved,
    beforeId = before_id,
    slot = slot,
    visibility = visibility,
    minZoom = min_zoom,
    maxZoom = max_zoom,
    popup = popup,
    tooltip = tooltip
  )

  # Add clustering level if specified
  if (!is.null(flow_clustering_level)) {
    flowmap_config$settings$clusteringLevel <- flow_clustering_level
  }

  # Add layer entry for layer control discovery
  layer_entry <- list(id = id, type = "flowmap")
  map$x$layers <- c(map$x$layers, list(layer_entry))

  # Initialize flowmaps list if it doesn't exist
  if (is.null(map$x$flowmaps)) {
    map$x$flowmaps <- list()
  }

  # Add flowmap to the map
  map$x$flowmaps <- c(
    map$x$flowmaps,
    list(flowmap_config)
  )

  return(map)
}
