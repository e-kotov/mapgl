# Flowmap Modularization Plan v2.0 (Strict Decoupling)

## Objective
Extract all flowmap logic out of `inst/htmlwidgets/mapboxgl.js` and `inst/htmlwidgets/maplibregl.js` into a dedicated plugin system (`flowmap.js` and `flowmap.css`). The core JS files will be restored to their original `main` branch state, acting only as the map engine, and will delegate any flowmap operations via strict, event-driven hooks.

## Key Files & Context
- `inst/htmlwidgets/mapboxgl.js` & `maplibregl.js` (Restoring to clean state)
- `inst/htmlwidgets/mapboxgl.yaml` & `maplibregl.yaml` (Updating dependencies)
- `inst/htmlwidgets/flowmap.js` (New)
- `inst/htmlwidgets/flowmap.css` (New)

## 1. Plugin Architecture (`flowmap.js`)
We will create a global interface `window.MapGLFlowmapPlugin` with a strict contract:
- `init(map, x, el, HTMLWidgets)`: Called once during map initialization. Parses `x.flowmaps`, handles standalone vs interleaved Deck.gl creation, sets up the layers, and internally attaches any needed map event listeners (e.g., `map.on('move')`).
- `syncVisibility(map, layerIds, targetVisibility)`: A boolean-returning hook called when a user toggles a layer in the `layers_control`. 
  - *Returns `true`* if the layer is a flowmap (and handles hiding/showing it via deck.gl).
  - *Returns `false`* if it's a standard map layer (telling the core widget to handle it normally via `map.setLayoutProperty`).
- `handleStyleChange(map, x)`: Called when the underlying map style is hot-swapped (e.g., via `set_style`). Re-adds or re-renders the flowmap layers so they aren't lost.

## 2. Extraction & Restoration Phase
1. **Backup**: Copy the currently merged `mapboxgl.js` and `maplibregl.js` to a safe `private/backups/` location.
2. **Extract JS & CSS**: Move all flowmap-specific CSS (`.flowmap-dark-mode`, `.flowmap-tooltip`, `#deck-container`) into `flowmap.css`. Move the massive `x.flowmaps` processing blocks into `flowmap.js` under the new interface.
3. **Restore `main`**: Run `git checkout origin/main -- inst/htmlwidgets/mapboxgl.js inst/htmlwidgets/maplibregl.js` to obliterate the ~600 lines of flowmap spaghetti.

## 3. Surgical Core Hooks
In the freshly restored `mapboxgl.js` and `maplibregl.js`, we insert exactly three lightweight hooks:

**Hook 1: Initialization** (At the end of `renderValue`)
```javascript
if (x.flowmaps && x.flowmaps.length > 0) {
    if (window.MapGLFlowmapPlugin) {
        window.MapGLFlowmapPlugin.init(map, x, el, HTMLWidgets);
    } else {
        console.error("MapGLFlowmapPlugin is not loaded.");
    }
}
```

**Hook 2: Layer Toggling** (Inside `layers_control` onclick)
```javascript
// Wrap standard Mapbox/Maplibre visibility toggle
const targetVis = visibility === "visible" ? "none" : "visible";
let handled = false;
if (window.MapGLFlowmapPlugin) {
    handled = window.MapGLFlowmapPlugin.syncVisibility(map, layerIds, targetVis);
}
if (!handled) {
    // ... do the normal map.setLayoutProperty(layerId, "visibility", targetVis) ...
}
```

**Hook 3: Style Preservation** (Inside `map.once("style.load")`)
```javascript
if (window.MapGLFlowmapPlugin) {
    window.MapGLFlowmapPlugin.handleStyleChange(map, x);
}
```

## 4. HTMLWidgets Dependency Updates
In `mapboxgl.yaml` and `maplibregl.yaml`, register `flowmap.js` and `flowmap.css` under the existing `flowmap-gl` or `flowmap-settings` component array. Because the widget architecture relies on YAML to load these assets, this ensures the plugin is immediately available when `add_flowmap` is invoked from R.

## 5. Verification
1. R commands (`mapgl::mapboxgl()`) run cleanly without console errors.
2. Layer controls accurately toggle flowmaps (via the plugin) and base layers (via the core).
3. The CSS "screen" blend mode correctly initializes the standalone `<canvas>` without muddying the Mapbox WebGL context.