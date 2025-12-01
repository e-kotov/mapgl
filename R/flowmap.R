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
#' @param color_scheme Color scheme for flows. Can be a preset name (e.g., "Teal", "Purple",
#'   "Blue") or a vector of color hex codes. Default is "Teal".
#' @param dark_mode Whether to use dark mode styling. Default is TRUE.
#' @param animation_enabled Whether to animate flow lines. Default is FALSE.
#' @param fade_enabled Whether to fade flow lines by magnitude. Default is TRUE.
#' @param fade_amount Fade amount (0-100). Default is 50.
#' @param fade_opacity_enabled Whether fade affects opacity. Default is FALSE.
#' @param locations_enabled Whether to show location circles. Default is TRUE.
#' @param location_totals_enabled Whether location circles scale by totals. Default is TRUE.
#' @param location_labels_enabled Whether to show location labels. Default is FALSE.
#' @param clustering_enabled Whether to enable location clustering. Default is TRUE.
#' @param clustering_auto Whether to auto-adjust clustering level. Default is TRUE.
#' @param clustering_level Manual clustering zoom level (0-20). Only used if clustering_auto is FALSE.
#' @param adaptive_scales_enabled Whether to use adaptive scaling. Default is TRUE.
#' @param highlight_color Color for highlighting on hover. Default is "orange".
#' @param max_top_flows Maximum number of top flows to display. Default is 5000.
#' @param opacity Overall opacity of the flowmap layer (0-1). Default is 1.0.
#' @param clustering_method Clustering algorithm to use. Either "HCA" (Hierarchical Cluster Analysis) or "H3" (H3 hexagonal hierarchical spatial index). Default is "HCA".
#' @param show_settings_menu Whether to display an interactive settings menu on the map for real-time customization. Useful for exploring different visual configurations. Default is FALSE.
#' @param popup A column name from locations or flows to display in a popup on click.
#' @param tooltip A column name from locations or flows to display in a tooltip on hover.
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
#'     color_scheme = "Teal",
#'     animation_enabled = FALSE
#'   )
#' }
add_flowmap <- function(
  map,
  id,
  locations,
  flows,
  color_scheme = "Teal",
  dark_mode = TRUE,
  animation_enabled = FALSE,
  fade_enabled = TRUE,
  fade_amount = 50,
  fade_opacity_enabled = FALSE,
  locations_enabled = TRUE,
  location_totals_enabled = TRUE,
  location_labels_enabled = FALSE,
  clustering_enabled = TRUE,
  clustering_auto = TRUE,
  clustering_level = NULL,
  adaptive_scales_enabled = TRUE,
  highlight_color = "orange",
  max_top_flows = 5000,
  opacity = 1.0,
  clustering_method = "HCA",
  show_settings_menu = FALSE,
  popup = NULL,
  tooltip = NULL
) {
  # Validate inputs
  if (!is.data.frame(locations) && !inherits(locations, "sf")) {
    stop("locations must be a data.frame or sf object")
  }

  if (!is.data.frame(flows)) {
    stop("flows must be a data.frame")
  }

  # Validate opacity
  if (!is.numeric(opacity) || opacity < 0 || opacity > 1) {
    stop("opacity must be a number between 0 and 1")
  }

  # Validate clustering_method
  if (!clustering_method %in% c("HCA", "H3")) {
    stop("clustering_method must be either 'HCA' or 'H3'")
  }

  # Validate color_scheme if string
  if (is.character(color_scheme) && length(color_scheme) == 1) {
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
    if (!color_scheme %in% valid_schemes) {
      warning(
        "Unknown color scheme '",
        color_scheme,
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

  # Add name column if not present
  if (!"name" %in% names(locations_df)) {
    locations_df$name <- locations_df$id
  }

  # Convert to list format for JavaScript
  locations_list <- lapply(1:nrow(locations_df), function(i) {
    loc <- as.list(locations_df[i, ])
    # Ensure id is character
    loc$id <- as.character(loc$id)
    # Convert name to character if it exists
    if (!is.null(loc$name)) {
      loc$name <- as.character(loc$name)
    }
    loc
  })

  flows_list <- lapply(1:nrow(flows), function(i) {
    flow <- as.list(flows[i, ])
    # Ensure origin and dest are characters
    flow$origin <- as.character(flow$origin)
    flow$dest <- as.character(flow$dest)
    # Ensure count is numeric
    flow$count <- as.numeric(flow$count)
    flow
  })

  # Create flowmap configuration
  flowmap_config <- list(
    id = id,
    data = list(
      locations = locations_list,
      flows = flows_list
    ),
    settings = list(
      colorScheme = color_scheme,
      darkMode = dark_mode,
      opacity = opacity,
      animationEnabled = animation_enabled,
      fadeEnabled = fade_enabled,
      fadeAmount = fade_amount,
      fadeOpacityEnabled = fade_opacity_enabled,
      locationsEnabled = locations_enabled,
      locationTotalsEnabled = location_totals_enabled,
      locationLabelsEnabled = location_labels_enabled,
      clusteringEnabled = clustering_enabled,
      clusteringAuto = clustering_auto,
      clusteringMethod = clustering_method,
      adaptiveScalesEnabled = adaptive_scales_enabled,
      highlightColor = highlight_color,
      maxTopFlowsDisplayNum = max_top_flows
    ),
    showSettingsMenu = show_settings_menu,
    popup = popup,
    tooltip = tooltip
  )

  # Add clustering level if specified
  if (!is.null(clustering_level)) {
    flowmap_config$settings$clusteringLevel <- clustering_level
  }

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
