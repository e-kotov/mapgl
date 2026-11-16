# FlowmapGL 9.5 public R controls and the standalone Deck canvas contract.

test_that("FlowmapGL 9.5 controls serialize with safe defaults and CSS colors", {
  locations <- data.frame(id = c("a", "b"), name = c("East", "West"),
                          lat = c(0, 0), lon = c(179, -179))
  flows <- data.frame(origin = "a", dest = "b", count = 3)
  map <- maplibre() |>
    add_flowmap(
      "international", locations, flows,
      flow_blending_mode = "non-accumulating",
      flow_wrap_longitude = TRUE,
      flow_location_labels_enabled = TRUE,
      flow_location_label_props = list(
        getSize = 12, getColor = "#ff0033",
        outlineColor = c(0, 20, 50), outlineWidth = 2,
        background = TRUE, backgroundColor = "#000000cc",
        backgroundPadding = c(2, 3, 2, 3),
        collisionEnabled = FALSE, fontFamily = "Arial"
      )
    )
  settings <- map$x$flowmaps[[1L]]$settings
  expect_true(settings$wrapLongitude)
  expect_identical(settings$blendingMode, "non-accumulating")
  expect_true(settings$locationLabelsEnabled)
  expect_equal(settings$locationLabelProps$getSize, 12)
  expect_equal(settings$locationLabelProps$getColor, c(255L, 0L, 51L, 255L))
  expect_equal(settings$locationLabelProps$outlineColor, c(0L, 20L, 50L, 255L))
  expect_equal(settings$locationLabelProps$backgroundColor, c(0L, 0L, 0L, 204L))
  expect_equal(settings$locationLabelProps$backgroundPadding, c(2, 3, 2, 3))
  expect_false(settings$locationLabelProps$collisionEnabled)
  deps <- stats::setNames(map$dependencies, vapply(
    map$dependencies, function(x) x$name, character(1)
  ))
  expect_equal(deps[["flowmap-gl"]]$version, "9.5.0")

  defaults <- maplibre() |> add_flowmap("default", locations, flows)
  expect_false(defaults$x$flowmaps[[1L]]$settings$wrapLongitude)
  expect_equal(defaults$x$flowmaps[[1L]]$settings$blendingMode, "normal")
  expect_null(defaults$x$flowmaps[[1L]]$settings$locationLabelProps)
})

test_that("FlowmapGL new controls validate and normalize dynamic settings", {
  locations <- data.frame(id = c("a", "b"), lat = c(0, 0), lon = c(179, -179))
  flows <- data.frame(origin = "a", dest = "b", count = 3)
  make <- function(...) add_flowmap(maplibre(), "a", locations, flows, ...)
  expect_error(make(flow_wrap_longitude = "true"), "flow_wrap_longitude")
  expect_error(make(flow_blending_mode = "screen"), "should be one of")
  expect_error(make(flow_location_label_props = 1), "named list")
  expect_error(make(flow_location_label_props = list(getText = "No")), "Unsupported")
  expect_error(make(flow_location_label_props = list(getSize = 0)), "positive")
  expect_error(make(flow_location_label_props = list(getColor = "notacolor")), "CSS color")
  expect_error(make(flow_location_label_props = list(getColor = c(256, 0, 0))), "RGB")
  expect_error(make(flow_location_label_props = list(background = "true")), "TRUE or FALSE")
  expect_error(make(flow_location_label_props = list(collisionEnabled = NA)), "TRUE or FALSE")
  expect_error(make(flow_location_label_props = list(backgroundPadding = 1)), "length 4")
  expect_error(make(flow_location_label_props = list(getPixelOffset = 1)), "length 2")
  expect_error(make(flow_location_label_props = list(wordBreak = "bad")), "one of")
  expect_error(make(flow_location_label_props = setNames(list(1, 2), c("getSize", "getSize"))),
               "unique non-empty")
  expect_warning(make(flow_blending_mode = "non-accumulating", flow_blend = FALSE),
                 "overridden")

  map <- make() |>
    set_flowmap_settings("a", "blending_mode", "non-accumulating") |>
    set_flowmap_settings("a", "wrap_longitude", TRUE) |>
    set_flowmap_settings("a", "location_label_props",
                         list(getColor = "red", getSize = 14))
  settings <- map$x$flowmaps[[1L]]$settings
  expect_equal(settings$blendingMode, "non-accumulating")
  expect_true(settings$wrapLongitude)
  expect_equal(settings$locationLabelProps$getColor, c(255L, 0L, 0L, 255L))
  expect_error(set_flowmap_settings(map, "a", "blendingMode", "multiply"), "one of")
  expect_error(set_flowmap_settings(map, "a", "wrapLongitude", "yes"), "TRUE or FALSE")
  expect_error(set_flowmap_settings(map, "a", "locationLabelProps", list(getText = 1)),
               "Unsupported")
  map <- set_flowmap_settings(map, "a", "locationLabelProps", NULL)
  expect_null(map$x$flowmaps[[1L]]$settings$locationLabelProps)
})

test_that("FlowmapGL standalone blending configures canvas clearing and supports live updates", {
  skip_on_cran()
  skip_if_not_installed("chromote")

  blank_style <- list(
    version = 8,
    sources = structure(list(), names = character(0)),
    layers = list(list(
      id = "bg", type = "background",
      paint = list(`background-color` = "#e5e5e5")
    ))
  )
  locations <- data.frame(
    id = c("a", "b"), name = c("East", "West"),
    lat = c(0, 0), lon = c(179, -179)
  )
  flows <- data.frame(origin = "a", dest = "b", count = 3)
  map <- maplibre(style = blank_style, center = c(179, 0), zoom = 3) |>
    add_flowmap(
      id = "flows", locations = locations, flows = flows,
      flow_blending_mode = "non-accumulating",
      flow_wrap_longitude = TRUE,
      flow_location_labels_enabled = TRUE,
      flow_location_label_props = list(
        getSize = 13, getColor = "#ff0000", collisionEnabled = TRUE
      ),
      flow_clustering_enabled = FALSE, tooltip = FALSE
    )

  dir <- tempfile("mapgl-flowmap-95-browser-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  path <- file.path(dir, "map.html")
  htmlwidgets::saveWidget(map, path, selfcontained = FALSE)

  b <- tryCatch(chromote::ChromoteSession$new(), error = function(e) NULL)
  if (is.null(b)) skip("chromote could not start a browser")
  on.exit(b$close(), add = TRUE)
  b$Emulation$setDeviceMetricsOverride(
    width = 1000, height = 700, deviceScaleFactor = 1, mobile = FALSE
  )
  js <- function(code) {
    out <- b$Runtime$evaluate(
      paste0("JSON.stringify((function() {", code, "})())"),
      returnByValue = TRUE
    )
    if (is.null(out$result$value) || identical(out$result$value, "null")) return(NULL)
    jsonlite::fromJSON(out$result$value, simplifyVector = TRUE)
  }
  wait_for <- function(code, timeout = 30) {
    until <- Sys.time() + timeout
    repeat {
      if (isTRUE(tryCatch(js(code), error = function(e) FALSE))) return(TRUE)
      if (Sys.time() > until) return(FALSE)
      Sys.sleep(0.25)
    }
  }
  b$Page$navigate(paste0("file://", path))
  expect_true(wait_for(
    "var m=document.querySelector('.html-widget')?.map;
     return !!(m && m._deckgl && m._mapglFlowmapLayers?.[0]?.state?.dataProvider);"
  ))
  initial <- js(
    "var m=document.querySelector('.html-widget').map;
     var p=m._mapglFlowmapLayers[0].props;
     return {
       blendingMode:p.blendingMode,
       wrapLongitude:p.wrapLongitude,
       size:p.locationLabelProps.getSize,
       getColor:p.locationLabelProps.getColor,
       collision:p.locationLabelProps.collisionEnabled,
       css:m._deckCanvas.style.mixBlendMode,
       effects:(m._deckgl.props.effects||[]).map(function(x){return x.id;})
     };"
  )
  expect_equal(initial$blendingMode, "non-accumulating")
  expect_true(initial$wrapLongitude)
  expect_equal(initial$size, 13)
  expect_equal(as.integer(initial$getColor), c(255L, 0L, 0L, 255L))
  expect_true(initial$collision)
  expect_equal(initial$css, "darken")
  expect_true("flowmap-canvas-clear" %in% initial$effects)

  js("var m=document.querySelector('.html-widget').map;
      return MapGLFlowmapPlugin.setSettings(m, 'flows', {blendingMode:'normal'});")
  expect_true(wait_for(
    "var m=document.querySelector('.html-widget').map;
     return m._deckCanvas.style.mixBlendMode === 'multiply' &&
       !(m._deckgl.props.effects||[]).some(function(x){return x.id==='flowmap-canvas-clear';});"
  ))
  js("var m=document.querySelector('.html-widget').map;
      return MapGLFlowmapPlugin.setSettings(m, 'flows', {
        blendingMode:'non-accumulating', wrapLongitude:false,
        locationLabelProps:{getSize:20,getColor:[1,2,3,255]}
      });")
  expect_true(wait_for(
    "var m=document.querySelector('.html-widget').map;
     var p=m._mapglFlowmapLayers[0].props;
     return m._deckCanvas.style.mixBlendMode === 'darken' &&
       p.wrapLongitude === false && p.locationLabelProps.getSize === 20 &&
       (m._deckgl.props.effects||[]).some(function(x){return x.id==='flowmap-canvas-clear';});"
  ))
})
