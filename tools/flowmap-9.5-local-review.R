# Standalone local review script for the experimental FlowmapGL 9.5 R interface.
# Install: pak::pak("e-kotov/mapgl@chore/flowmap-gl-9.5.0-vendor")
# Run: source("tools/flowmap-9.5-local-review.R", echo = TRUE)
# In RStudio, print(flat_map) / print(globe_map) in the Viewer.
library(mapgl)

locations <- data.frame(
  id = c("jp", "us", "eu"),
  name = c("Tokyo", "San Francisco", "Paris"),
  label = c("Tokyo (JP)", "San Francisco (US)", "Paris (FR)"),
  lat = c(35.68, 37.77, 48.86),
  lon = c(139.69, -122.42, 2.35)
)
flows <- data.frame(
  origin = c("jp", "us", "eu", "jp"),
  dest = c("us", "jp", "us", "eu"),
  count = c(20, 5, 14, 8),
  time = as.Date(c("2026-11-09", "2026-11-16", "2026-11-16", "2026-11-09"))
)

# Visual checklist: a legend in the corner with a functional Lock button,
# custom labels, multiple time periods, wrapped Tokyo–San Francisco routes,
# and non-accumulating blending in the standalone flow canvas.
flat_map <- maplibre(
  projection = "mercator", center = c(-170, 40), zoom = 2,
  style = openfreemap_style("bright")
) |>
  add_flowmap(
    id = "flights", locations = locations, flows = flows,
    flow_time_column = "time",
    flow_selected_time_ranges = list(
      c("2026-11-09", "2026-11-10"),
      c("2026-11-16", "2026-11-17")
    ),
    flow_temporal_scale_domain = "all",
    flow_scale_lock = TRUE,
    flow_scale_domains = list(flowMagnitude = c(0, 25), locationTotals = c(0, 50)),
    flow_wrap_longitude = TRUE,
    flow_lines_rendering_mode = "curved",
    flow_blending_mode = "non-accumulating",
    flow_location_labels_enabled = TRUE,
    flow_location_label_column = "label",
    flow_location_label_props = list(
      getSize = 14,
      getColor = "#ffffff",
      outlineWidth = 2,
      outlineColor = "#222222",
      collisionEnabled = TRUE
    )
  ) |>
  add_flowmap_legend("flights", placement = "bottom-left")

# Experimental: GlobeView alignment can vary across MapLibre/Mapbox versions.
# Compare circles/paths against the globe basemap at different zoom levels.
globe_map <- maplibre(
  projection = "globe", center = c(0, 25), zoom = 1.3,
  style = openfreemap_style("bright")
) |>
  add_flowmap(
    id = "globe-flights", locations = locations, flows = flows,
    flow_projection = "globe",
    flow_lines_rendering_mode = "curved",
    flow_location_labels_enabled = TRUE,
    flow_location_label_column = "label",
    flow_blend = FALSE
  ) |>
  add_flowmap_legend("globe-flights", placement = "top-left")

print(flat_map)
# In interactive R: print(globe_map)
