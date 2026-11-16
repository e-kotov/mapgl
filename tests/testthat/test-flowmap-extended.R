test_that("FlowmapGL scale locks and disjoint time intervals serialize", {
  locations <- data.frame(
    id = c("a", "b"), lat = c(0, 0), lon = c(179, -179),
    name = c("A", "B"), label = c("Station A", "Station B")
  )
  flows <- data.frame(
    origin = c("a", "a"), dest = c("b", "b"), count = c(4, 40),
    time = as.Date(c("2026-11-09", "2026-11-16"))
  )
  map <- maplibre(projection = "mercator") |>
    add_flowmap(
      id = "commutes", locations = locations, flows = flows,
      flow_time_column = "time",
      flow_selected_time_ranges = list(
        c("2026-11-09", "2026-11-10"),
        c("2026-11-16", "2026-11-17")
      ),
      flow_scale_lock = TRUE,
      flow_scale_domains = list(flowMagnitude = c(0, 100), locationTotals = c(0, 50)),
      flow_location_label_column = "label"
    ) |>
    add_flowmap_legend("commutes", sections = "flowThickness", placement = "top-left")

  opts <- map$x$flowmaps[[1]]$settings
  expect_true(opts$scaleLock$enabled)
  expect_equal(opts$scaleLock$domains$flowMagnitude, c(0, 100))
  expect_equal(opts$scaleLock$domains$locationTotals, c(0, 50))
  expect_equal(opts$selectedTimeRanges[[1]], c("2026-11-09", "2026-11-10"))
  expect_equal(length(opts$selectedTimeRanges), 2)
  expect_equal(opts$locationLabelColumn, "label")
  expect_identical(opts$flowProjection, "map")
  expect_length(map$x$flowmapLegends, 1)
  expect_identical(map$x$flowmapLegends[[1]]$id, "commutes")
  expect_identical(map$x$flowmapLegends[[1]]$placement, "top-left")
  expect_identical(as.character(map$x$flowmapLegends[[1]]$sections), "flowThickness")
  expect_true(map$x$flowmapLegends[[1]]$showLockControl)

  # Updating a legend for the same layer replaces, rather than duplicates, it.
  map <- add_flowmap_legend(map, "commutes", placement = "bottom-right")
  expect_length(map$x$flowmapLegends, 1)
  expect_identical(map$x$flowmapLegends[[1]]$placement, "bottom-right")
})

test_that("FlowmapGL time range proxy API can switch between one and many windows", {
  locations <- data.frame(id = c("a", "b"), lat = c(0, 1), lon = c(0, 1))
  flows <- data.frame(origin = "a", dest = "b", count = 10,
                      day = as.Date("2026-11-09"))
  map <- maplibre(projection = "mercator") |>
    add_flowmap("flows", locations, flows, flow_time_column = "day")

  map <- set_flowmap_filter(map, "flows", selected_time_ranges = list(
    as.Date(c("2026-11-09", "2026-11-10")),
    as.Date(c("2026-11-16", "2026-11-17"))
  ))
  opts <- map$x$flowmaps[[1]]$settings
  expect_length(opts$selectedTimeRanges, 2)
  expect_equal(opts$selectedTimeRanges[[2]], c("2026-11-16", "2026-11-17"))
  expect_null(opts$selectedTimeRange)

  map <- set_flowmap_filter(map, "flows",
                            selected_time_range = as.Date(c("2026-11-10", "2026-11-12")))
  opts <- map$x$flowmaps[[1]]$settings
  expect_null(opts$selectedTimeRanges)
  expect_equal(opts$selectedTimeRange, as.Date(c("2026-11-10", "2026-11-12")))
  map <- set_flowmap_filter(map, "flows", selected_time_ranges = list())
  expect_length(map$x$flowmaps[[1]]$settings$selectedTimeRanges, 0)
  expect_null(map$x$flowmaps[[1]]$settings$selectedTimeRange)

  map <- set_flowmap_settings(map, "flows", "scale_lock", TRUE) |>
    set_flowmap_settings("flows", "location_label_column", "name")
  expect_true(map$x$flowmaps[[1]]$settings$scaleLock$enabled)
  expect_identical(map$x$flowmaps[[1]]$settings$locationLabelColumn, "name")
  expect_error(set_flowmap_settings(map, "flows", "selected_time_ranges", list()),
               "filter state")
})

test_that("FlowmapGL extended options fail on invalid configurations", {
  locations <- data.frame(id = c("a", "b"), lat = c(0, 1),
                          lon = c(0, 1), label = c("A", "B"))
  flows <- data.frame(origin = "a", dest = "b", count = 3, time = as.Date("2026-11-09"))
  make <- function(...) add_flowmap(maplibre(projection = "mercator"), "x",
                                     locations, flows, flow_time_column = "time", ...)
  expect_error(make(flow_scale_lock = "true"), "flow_scale_lock")
  expect_error(make(flow_scale_domains = list(flowMagnitude = c(1, 5))), "requires")
  expect_error(make(flow_scale_lock = TRUE,
                    flow_scale_domains = list(flowMagnitude = c(5, 1))), "min, max")
  expect_error(make(flow_scale_lock = TRUE, flow_scale_domains = list(bogus = c(0, 1))),
               "named list")
  expect_error(make(flow_selected_time_ranges = c("2026-11-09", "2026-11-10")),
               "list")
  expect_error(make(flow_selected_time_ranges = list(c("2026-11-10", "2026-11-09"))),
               "start before end")
  expect_error(make(flow_selected_time_ranges = list(c("invalid", "dates"))),
               "start before end")
  expect_error(make(flow_selected_time_ranges = list(c("2026-11-09", "2026-11-10")),
                    flow_selected_time_range = c("2026-11-09", "2026-11-10")),
               "only one")
  expect_error(make(flow_location_label_column = "missing"), "column")
  expect_error(make(flow_projection = "globe"), "requires a map")
  expect_error(make(flow_view_id = ""), "flow_view_id")

  map <- make()
  expect_error(add_flowmap_legend(map, "absent"), "already added")
  expect_error(add_flowmap_legend(map, "x", sections = "invalid"), "sections")
  expect_error(add_flowmap_legend(map, "x", show_lock_control = "false"), "TRUE or FALSE")
})

test_that("FlowmapGL globe and view binding are explicit opt-ins", {
  locations <- data.frame(id = c("a", "b"), lat = c(40, 41), lon = c(-74, -73))
  flows <- data.frame(origin = "a", dest = "b", count = 3)
  m <- maplibre(projection = "globe") |>
    add_flowmap("global", locations, flows, flow_projection = "globe",
                flow_view_id = "maplibre")
  opts <- m$x$flowmaps[[1]]$settings
  expect_identical(opts$flowProjection, "globe")
  expect_identical(opts$viewId, "maplibre")
})
