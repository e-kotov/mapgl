// MapGL Flowmap Plugin
// Handles deck.gl flowmap integration independently of core map engines

window.MapGLFlowmapPlugin = (function() {
    
    // Internal state tracking
    const state = {
        maps: {}
    };

    function init(map, x, el, HTMLWidgets) {
        console.log('[MapGL Flowmap Plugin] init called with', x.flowmaps ? x.flowmaps.length : 0, 'flowmaps');
        if (!x.flowmaps || x.flowmaps.length === 0) return;
        
        const mapId = el.id;
        if (!state.maps[mapId]) {
            state.maps[mapId] = { layers: [], visibility: {} };
        }
        
        if (!map._flowmapVisibility) map._flowmapVisibility = state.maps[mapId].visibility;
        if (!map._flowmapLayers) map._flowmapLayers = state.maps[mapId].layers;


            // Check if FlowmapGL is available
            if (typeof FlowmapGL === "undefined") {
              console.error("FlowmapGL library is not loaded. Cannot add flowmap layers.");
            } else {
              // Store GUI instances
              if (!map._flowmapGUIs) {
                map._flowmapGUIs = {};
              }

              // Check if any flowmap requires interleaved mode (for layer ordering via beforeId or slot)
              const needsInterleaved = x.flowmaps.some(fm => fm.interleaved && (fm.beforeId || fm.slot));





              // Initialize deck.gl: use MapboxOverlay for interleaved mode, standalone Deck otherwise
              if (!map._deckgl && !map._deckOverlay) {
                try {
                  if (needsInterleaved) {
                    // Use MapboxOverlay with interleaved: true for layer ordering support
                    const { MapboxOverlay } = FlowmapGL;

                    map._deckOverlay = new MapboxOverlay({
                      id: 'mapbox-overlay-' + mapId,
                      interleaved: true,
                      layers: []
                    });
                    map.addControl(map._deckOverlay);
                    map._deckIsInterleaved = true;

                    console.log('[MapGL] MapboxOverlay initialized with interleaved: true for layer ordering');
                  } else {
                    // Use standalone Deck for CSS blend mode support (renders on separate canvas)
                    const { Deck } = FlowmapGL;
                    const container = map.getContainer();

                    // Create a container div for deck.gl canvas
                    const deckContainer = document.createElement('div');
                    deckContainer.id = 'deck-container';
                    deckContainer.style.cssText = `
                    position: absolute;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    pointer-events: none;
                    z-index: 1000;
                  `;
                    container.appendChild(deckContainer);

                    // Explicitly create canvas for deck.gl v9 standalone
                    const deckCanvas = document.createElement('canvas');
                    deckCanvas.id = 'deck-canvas';
                    deckCanvas.style.cssText = 'width: 100%; height: 100%;';
                    deckContainer.appendChild(deckCanvas);

                    // Store reference for blend mode updates
                    map._deckContainer = deckContainer;
                    map._deckCanvas = deckCanvas;

                    // Get initial viewstate from map
                    const center = map.getCenter();
                    const initialViewState = {
                      longitude: center.lng,
                      latitude: center.lat,
                      zoom: map.getZoom(),
                      pitch: map.getPitch(),
                      bearing: map.getBearing()
                    };

                    // Create standalone Deck instance
                    map._deckgl = new Deck({
                      canvas: deckCanvas,
                      controller: false, // Map controls the viewstate
                      _useDevicePixels: true, // Recommended for v9
                      initialViewState: initialViewState,
                      layers: [],
                      getTooltip: null,
                      pickingRadius: 5,
                      onWebGLInitialized: (gl) => {
                        // Ensure transparent canvas
                        gl.enable(gl.BLEND);
                        console.log('[MapGL Deck.gl] WebGL initialized with transparent canvas');
                      }
                    });

                    // Sync viewstate when map moves
                    // Sync viewstate when map moves
                    const syncViewState = () => {
                      const center = map.getCenter();
                      map._deckgl.setProps({
                        viewState: {
                          longitude: center.lng,
                          latitude: center.lat,
                          zoom: map.getZoom(),
                          pitch: map.getPitch(),
                          bearing: map.getBearing()
                        }
                      });
                    };

                    map.on('move', syncViewState);
                    map.on('moveend', syncViewState);
                    
                    // Call immediately to ensure correct initial positioning
                    syncViewState();

                    map._deckIsInterleaved = false;

                    console.log('[MapGL] Standalone Deck.gl initialized for CSS blend mode support');
                  }

                  // Forward mouse move to deck.gl for picking/tooltips
                  // (Required because deck container has pointer-events: none in standalone mode)
                  const onMapMouseMove = (e) => {
                    const deckInstance = map._deckgl || (map._deckOverlay && map._deckOverlay._deck);
                    if (!deckInstance) return;
                    const { x, y } = e.point;
                    const info = deckInstance.pickObject({ x, y, radius: 2 });

                    map.getCanvas().style.cursor = info ? 'pointer' : '';

                    if (info && info.layer && info.layer.props.onHover) {
                      info.layer.props.onHover(info);
                    } else {
                      // Hide all tooltips
                      const tooltips = document.querySelectorAll('.flowmap-tooltip');
                      tooltips.forEach(t => { t.style.display = 'none'; });
                    }
                  };

                  // Add listener only once
                  if (!map._hasDeckMoveListener) {
                    map.on('mousemove', onMapMouseMove);
                    map.on('mouseout', () => {
                      const tooltips = document.querySelectorAll('.flowmap-tooltip');
                      tooltips.forEach(t => { t.style.display = 'none'; });
                    });
                    map._hasDeckMoveListener = true;
                  }

                  // Cleanup function for when map is destroyed
                  map.on('remove', function () {
                    if (map._flowmapGUIs) {
                      Object.values(map._flowmapGUIs).forEach(function (guiInstance) {
                        if (typeof FlowmapSettings !== 'undefined') {
                          FlowmapSettings.destroyGUI(guiInstance);
                        }
                      });
                      map._flowmapGUIs = {};
                    }
                    if (map._deckgl) {
                      map._deckgl.finalize();
                      map._deckgl = null;
                    }
                    if (map._deckOverlay) {
                      map.removeControl(map._deckOverlay);
                      map._deckOverlay = null;
                    }
                    if (map._deckContainer) {
                      map._deckContainer.remove();
                      map._deckContainer = null;
                    }
                  });
                } catch (error) {
                  console.error('Failed to initialize deck.gl:', error);
                  return;
                }
              }

              // Collect all flowmap layers
              const flowmapLayers = [];

              x.flowmaps.forEach(function (flowmapConfig) {
                try {
                  const { FlowmapLayer } = FlowmapGL;

                  // Transform columnar data from R to row-oriented arrays for flowmap.gl
                  // R sends data as: {"id": ["A","B"], "lat": [10, 20]}
                  // flowmap.gl expects: [{"id":"A","lat":10}, {"id":"B","lat":20}]
                  let locations = flowmapConfig.data.locations;
                  if (locations && !Array.isArray(locations) && typeof locations === 'object') {
                    locations = HTMLWidgets.dataframeToD3(locations);
                  }

                  let flows = flowmapConfig.data.flows;
                  if (flows && !Array.isArray(flows) && typeof flows === 'object') {
                    flows = HTMLWidgets.dataframeToD3(flows);
                  }

                  // Update config with transformed data
                  flowmapConfig.data.locations = locations;
                  flowmapConfig.data.flows = flows;

                  console.log(`[MapGL Flowmap Plugin] Creating layer '${flowmapConfig.id}' with ${locations ? locations.length : 0} locations and ${flows ? flows.length : 0} flows`);
                  if (locations && locations.length > 0) console.log('[MapGL Flowmap Plugin] Sample location:', locations[0]);
                  if (flows && flows.length > 0) console.log('[MapGL Flowmap Plugin] Sample flow:', flows[0]);

                  // Defensive check: if beforeId is provided but doesn't exist, warn and null it
                  if (flowmapConfig.beforeId && !map.getLayer(flowmapConfig.beforeId)) {
                    console.warn(`[MapGL Flowmap Plugin] beforeId '${flowmapConfig.beforeId}' not found. Flowmap will be added on top.`);
                    flowmapConfig.beforeId = undefined;
                  }

                  // Common props function
                  const getLayerProps = (settings) => {
                    // Determine basic opacity
                    let opacity = settings.opacity !== undefined ? settings.opacity : 1.0;

                    const blendParameters = settings.webglBlendMode
                      ? {
                          blend: true,
                          blendColorOperation: 'add',
                          blendColorSrcFactor: 'src-alpha',
                          blendColorDstFactor: 'one-minus-dst',
                          blendAlphaOperation: 'add',
                          blendAlphaSrcFactor: 'one',
                          blendAlphaDstFactor: 'one-minus-src-alpha',
                          depthWriteEnabled: false,
                          depthCompare: 'always'
                        }
                      : {
                          blend: true,
                          blendColorOperation: 'add',
                          blendColorSrcFactor: 'src-alpha',
                          blendColorDstFactor: 'one-minus-src-alpha',
                          blendAlphaOperation: 'add',
                          blendAlphaSrcFactor: 'one',
                          blendAlphaDstFactor: 'one-minus-src-alpha',
                          depthWriteEnabled: false,
                          depthCompare: 'always'
                        };

                    return {
                      id: flowmapConfig.id,
                      // v9.3 expects { locations: [], flows: [] }
                      data: {
                        locations: flowmapConfig.data.locations,
                        flows: flowmapConfig.data.flows
                      },
                      // beforeId/slot for layer ordering in interleaved mode (MapboxOverlay)
                      beforeId: flowmapConfig.interleaved ? flowmapConfig.beforeId : undefined,
                      slot: flowmapConfig.interleaved ? flowmapConfig.slot : undefined,
                      pickable: true,
                      visible: flowmapConfig.visibility !== 'none',
                      opacity: opacity,
                      outlineWidth: settings.outlineWidth !== undefined ? settings.outlineWidth : 0,
                      // WebGL blend parameters
                      parameters: blendParameters,
                      // Data accessors with activity logging
                      getLocationId: (loc) => { 
                        if (!window._fm_loc_called) { console.log('[MapGL Flowmap Plugin] getLocationId called'); window._fm_loc_called = true; }
                        return loc.id; 
                      },
                      getLocationLat: (loc) => loc.lat,
                      getLocationLon: (loc) => loc.lon,
                      getLocationName: (loc) => loc.name,
                      getFlowOriginId: (flow) => { 
                        if (!window._fm_flow_called) { console.log('[MapGL Flowmap Plugin] getFlowOriginId called'); window._fm_flow_called = true; }
                        return flow.origin; 
                      },
                      getFlowDestId: (flow) => flow.dest,
                      getFlowMagnitude: (flow) => flow.count,
                      // Settings
                      colorScheme: settings.colorScheme,
                      darkMode: settings.darkMode,
                      flowLinesRenderingMode: settings.useCurvedArrows ? 'curved' : (settings.animationEnabled ? 'animated-straight' : 'straight'),
                      flowLineCurviness: settings.flowLineCurviness,
                      flowLineThicknessScale: settings.flowLineThicknessScale,
                      flowEndpointsInViewportMode: settings.flowEndpointsInViewportMode,
                      useCurvedArrows: settings.useCurvedArrows,
                      // Event handlers
                      onHover: (info) => {
                        // Create or get tooltip element
                        let tooltip = document.getElementById('flowmap-tooltip-' + flowmapConfig.id);

                        if (!info || !info.object) {
                          // Hide tooltip
                          if (tooltip) {
                            tooltip.style.display = 'none';
                          }
                          return;
                        }

                        // Create tooltip if it doesn't exist
                        if (!tooltip) {
                          tooltip = document.createElement('div');
                          tooltip.id = 'flowmap-tooltip-' + flowmapConfig.id;
                          tooltip.className = 'flowmap-tooltip';
                          document.body.appendChild(tooltip);
                        }

                        // Show and position tooltip
                        tooltip.style.display = 'block';
                        tooltip.style.left = info.x + 'px';
                        tooltip.style.top = info.y + 'px';

                        // Generate tooltip content based on object type
                        let content = '';

                        // Use string comparison for type checking instead of PickingType enum
                        switch (info.object.type) {
                          case 'location':
                            content = `
                            <div><strong>${info.object.name || info.object.id}</strong></div>
                            ${info.object.totals ? `
                              <div>Incoming: ${info.object.totals.incomingCount || 0}</div>
                              <div>Outgoing: ${info.object.totals.outgoingCount || 0}</div>
                              <div>Internal: ${info.object.totals.internalCount || 0}</div>
                            ` : ''}
                          `;
                            break;
                          case 'flow':
                            content = `
                            <div><strong>${info.object.origin.id} → ${info.object.dest.id}</strong></div>
                            <div>Count: ${info.object.count}</div>
                          `;
                            break;
                          default:
                            content = '<div>Unknown</div>';
                        }

                        tooltip.innerHTML = content;
                      },
                      onClick: (info) => {
                        if (flowmapConfig.popup && info && info.object) {
                          // TODO: Implement popup display
                          console.log("Flowmap click:", info.object);
                        }
                        // Send to Shiny if in Shiny mode
                        if (HTMLWidgets.shinyMode && info && info.object) {
                          Shiny.setInputValue(el.id + "_flowmap_click", {
                            id: flowmapConfig.id,
                            type: info.object.type,
                            data: info.object
                          });
                        }
                      }
                    };
                  };

                  // Create merged settings object for initial layer creation
                  const initialSettings = {
                    ...flowmapConfig.settings,
                    dimBasemap: flowmapConfig.dimBasemap,
                    cssBlendMode: flowmapConfig.cssBlendMode,
                    webglBlendMode: flowmapConfig.webglBlendMode
                  };

                  console.log(`[MapGL Flowmap Plugin] Creating layer '${flowmapConfig.id}' with ${locations ? locations.length : 0} locations and ${flows ? flows.length : 0} flows`);
                  console.log(`[MapGL Flowmap Plugin] Initial settings for '${flowmapConfig.id}':`, initialSettings);
                  const layerProps = getLayerProps(initialSettings);
                  console.log(`[MapGL Flowmap Plugin] Final layer props for '${flowmapConfig.id}':`, layerProps);

                  // Create FlowmapLayer instance
                  const flowmapLayer = new FlowmapLayer(layerProps);

                  flowmapLayers.push(flowmapLayer);
                  console.log("Flowmap layer '" + flowmapConfig.id + "' created successfully");

                  /*
                   * Helper to update container styling, basemap effects, and CSS blend modes
                   * With interleaved: false, deck.gl renders to a SEPARATE canvas, so CSS mix-blend-mode works!
                   * This matches the official flowmap.gl example: https://visgl.github.io/flowmap.gl/
                   */
                  /*
                   * Helper to update container styling, basemap effects, and CSS blend modes
                   * With standalone Deck.gl, we have full control over the canvas and container
                   */
                  const updateDeckEffects = (darkMode) => {
                    if (map._deckCanvas) {
                      map._deckCanvas.style.mixBlendMode = flowmapConfig.cssBlendMode
                        ? (darkMode ? 'screen' : 'darken')
                        : '';
                    }

                    const container = map.getContainer();
                    const mapCanvas = map.getCanvas();

                    // Update Container Background (provides the base color when map opacity is reduced)
                    if (darkMode) {
                      container.classList.add('flowmap-dark-mode');
                      container.classList.remove('flowmap-light-mode');
                      container.style.backgroundColor = '#000';
                    } else {
                      container.classList.add('flowmap-light-mode');
                      container.classList.remove('flowmap-dark-mode');
                      container.style.backgroundColor = '#fff';
                    }

                    // Handle Basemap Dimming via CSS Filters (matches flowmap.gl reference)
                    // If dimBasemap is OFF, reset filters
                    if (flowmapConfig.dimBasemap) {
                      if (darkMode) {
                        // Dark Mode Filters (from reference)
                        mapCanvas.style.filter = 'grayscale(0.1) invert(1) hue-rotate(-180deg) saturate(0.5) contrast(0.9)';
                        mapCanvas.style.opacity = '0.3';
                      } else {
                        // Light Mode Filters (from reference)
                        mapCanvas.style.filter = 'grayscale(0.85)';
                        mapCanvas.style.opacity = '0.5';
                      }
                    } else {
                      mapCanvas.style.filter = '';
                      mapCanvas.style.opacity = '';
                    }

                    // Cleanup old dimmer layer if it exists (migration cleanup)
                    const DIMMER_LAYER_ID = 'flowmap-dimmer-layer';
                    const DIMMER_SOURCE_ID = 'flowmap-dimmer-source';
                    if (map.getLayer(DIMMER_LAYER_ID)) map.removeLayer(DIMMER_LAYER_ID);
                    if (map.getSource(DIMMER_SOURCE_ID)) map.removeSource(DIMMER_SOURCE_ID);
                  };

                  // Initial call
                  updateDeckEffects(flowmapConfig.settings.darkMode);

                  // Create settings menu if requested
                  if (flowmapConfig.showSettingsMenu && typeof FlowmapSettings !== 'undefined') {
                    // Destroy existing GUI if any
                    if (map._flowmapGUIs[flowmapConfig.id]) {
                      FlowmapSettings.destroyGUI(map._flowmapGUIs[flowmapConfig.id]);
                    }

                    // Track previous state and version counter for smart updates
                    let previousState = {
                      ...flowmapConfig.settings,
                      cssBlendMode: flowmapConfig.cssBlendMode,
                      webglBlendMode: flowmapConfig.webglBlendMode
                    };
                    let layerVersion = 0;

                    let guiInstance;
                    guiInstance = FlowmapSettings.createGUI(
                      {
                        ...flowmapConfig.settings,
                        dimBasemap: flowmapConfig.dimBasemap,
                        cssBlendMode: flowmapConfig.cssBlendMode,
                        webglBlendMode: flowmapConfig.webglBlendMode
                      },
                      function () {
                        try {
                          // Callback when settings change
                          const newState = guiInstance.getState();
                          console.log('[MapGL Settings Change] Callback fired with state:', newState);

                          // DEBUG: Expose state globally
                          if (!window.flowmapDebug) window.flowmapDebug = {};
                          window.flowmapDebug.lastState = newState;
                          window.flowmapDebug.map = map;
                          window.flowmapDebug.config = flowmapConfig;

                          // Capture previous state BEFORE updating (for comparison)
                          const previousWebglBlendMode = previousState.webglBlendMode;

                          // Update global config with new settings
                          flowmapConfig.dimBasemap = newState.dimBasemap;
                          flowmapConfig.cssBlendMode = newState.cssBlendMode;
                          flowmapConfig.webglBlendMode = newState.webglBlendMode;

                          // Update CSS blending mode (no layer recreation needed)
                          try {
                            updateDeckEffects(newState.darkMode);
                          } catch (e) {
                            console.error("[MapGL] updateDeckEffects failed:", e);
                          }

                          // Determine if we need layer recreation (versioned ID) or just prop update
                          const needsRecreation =
                            previousState.clusteringEnabled !== newState.clusteringEnabled ||
                            previousState.clusteringMethod !== newState.clusteringMethod ||
                            previousState.clusteringAuto !== newState.clusteringAuto ||
                            (previousState.clusteringLevel !== newState.clusteringLevel && !newState.clusteringAuto) ||
                            previousState.darkMode !== newState.darkMode ||
                            previousWebglBlendMode !== newState.webglBlendMode;

                          console.log('[MapGL Settings Change] Needs recreation:', needsRecreation);

                          const layerProps = getLayerProps(newState);

                          if (newState.webglBlendMode) {
                            console.log("[MapGL] Glow mode active. Opacity:", layerProps.opacity);
                          }

                          let updatedLayer;

                          if (needsRecreation) {
                            layerVersion++;
                            const versionedId = `${flowmapConfig.id}-v${layerVersion}`;
                            layerProps.id = versionedId;

                            console.log('[MapGL Settings Change] Recreating layer:', versionedId);
                            updatedLayer = new FlowmapLayer(layerProps);

                            if ((map._deckgl || map._deckOverlay) && map._flowmapLayers) {
                              map._flowmapLayers = map._flowmapLayers.filter(l => !l.id.startsWith(flowmapConfig.id));
                              map._flowmapLayers.push(updatedLayer);
                              // Respect visibility from layer control
                              const visibleLayers = map._flowmapLayers.filter(layer => {
                                const baseId = layer.id.split('-v')[0];
                                return !map._flowmapVisibility || map._flowmapVisibility[baseId] !== false;
                              });
                              (map._deckgl || map._deckOverlay).setProps({ layers: visibleLayers });
                              console.log('[MapGL Settings Change] ✓ Layer recreated');
                            }
                          } else {
                            layerProps.id = flowmapConfig.id;
                            // Ensure updateTriggers are set explicitly
                            layerProps.updateTriggers = {
                              getFlowMagnitude: [newState.fadeEnabled, newState.fadeAmount, newState.fadeOpacityEnabled],
                              all: [
                                newState.darkMode,
                                newState.colorScheme,
                                newState.opacity,
                                newState.animationEnabled,
                                newState.fadeEnabled,
                                flowmapConfig.cssBlendMode,
                                flowmapConfig.webglBlendMode,
                                newState.adaptiveScalesEnabled,
                                newState.locationsEnabled,
                                newState.locationTotalsEnabled,
                                newState.locationLabelsEnabled,
                                newState.maxTopFlowsDisplayNum,
                                newState.flowLineCurviness,
                                newState.flowLineThicknessScale,
                                newState.flowEndpointsInViewportMode,
                                newState.useCurvedArrows ? 'curved' : (newState.animationEnabled ? 'animated-straight' : 'straight')
                              ]
                            };

                            console.log('[MapGL Settings Change] Updating props for:', layerProps.id);
                            updatedLayer = new FlowmapLayer(layerProps);

                            if ((map._deckgl || map._deckOverlay) && map._flowmapLayers) {
                              const index = map._flowmapLayers.findIndex(l =>
                                l.id === flowmapConfig.id || l.id.startsWith(flowmapConfig.id)
                              );
                              if (index !== -1) {
                                map._flowmapLayers[index] = updatedLayer;
                              } else {
                                map._flowmapLayers.push(updatedLayer);
                              }
                              // Respect visibility from layer control
                              const visibleLayers = map._flowmapLayers.filter(layer => {
                                const baseId = layer.id.split('-v')[0];
                                return !map._flowmapVisibility || map._flowmapVisibility[baseId] !== false;
                              });
                              (map._deckgl || map._deckOverlay).setProps({ layers: visibleLayers });
                              console.log('[MapGL Settings Change] ✓ Props updated');
                            }
                          }

                          // Update previous state
                          previousState = { ...newState };

                          // Trigger repaint
                          setTimeout(() => {
                            map.triggerRepaint();
                          }, 10);

                        } catch (err) {
                          console.error("[MapGL] Settings Callback Error:", err);
                        }
                      }
                    );

                    // Store GUI instance for cleanup
                    map._flowmapGUIs[flowmapConfig.id] = guiInstance;
                  }
                } catch (error) {
                  console.error("Failed to create flowmap layer '" + flowmapConfig.id + "':", error);
                }
              });


              // Update overlay with all flowmap layers
              if (flowmapLayers.length > 0 && (map._deckgl || map._deckOverlay)) {
                try {
                  // Initialize or update our local cache of layers
                  if (!map._flowmapLayers) {
                    map._flowmapLayers = [];
                  }

                  // Add new layers to our cache, replacing any with same ID
                  flowmapLayers.forEach(newLayer => {
                    const index = map._flowmapLayers.findIndex(l => l.id === newLayer.id);
                    if (index !== -1) {
                      map._flowmapLayers[index] = newLayer;
                    } else {
                      map._flowmapLayers.push(newLayer);
                    }
                  });

                  // Function to set layers on deck instance
                  const setDeckLayers = () => {
                    // Respect visibility from layer control
                    const visibleLayers = map._flowmapLayers.filter(layer => {
                      const baseId = layer.id.split('-v')[0];
                      return !map._flowmapVisibility || map._flowmapVisibility[baseId] !== false;
                    });

                    // DEBUG: Add a simple red circle to verify deck.gl is working
                    try {
                      const { ScatterplotLayer } = FlowmapGL;
                      const debugLayer = new ScatterplotLayer({
                        id: 'deckgl-debug-layer',
                        data: [{position: [map.getCenter().lng, map.getCenter().lat], size: 100}],
                        getPosition: d => d.position,
                        getRadius: d => d.size,
                        getFillColor: [255, 0, 0, 255],
                        radiusMinPixels: 20
                      });
                      visibleLayers.push(debugLayer);
                      console.log('[MapGL Flowmap Plugin] Added debug red circle at center');
                    } catch (e) {
                      console.error('[MapGL Flowmap Plugin] Failed to add debug layer:', e);
                    }

                    console.log(`[MapGL Flowmap Plugin] Setting ${visibleLayers.length} layers on deck instance:`, visibleLayers);

                    // Set layers on whichever deck instance is active
                    if (map._deckgl) {
                      map._deckgl.setProps({ layers: visibleLayers });
                      console.log("Flowmap layers added to Standalone Deck.gl:", flowmapLayers.length);
                    } else if (map._deckOverlay) {
                      map._deckOverlay.setProps({ layers: visibleLayers });
                      console.log("Flowmap layers added to MapboxOverlay (interleaved):", flowmapLayers.length);

                      /*
                      // POST-RENDER FIX: Disabled to prevent flickering on zoom. 
                      // deck.gl handles beforeId natively in Classic styles.
                      // Only re-enable if we find specific issues with Mapbox Standard slots.
                      setTimeout(() => {
                        // ... existing logic ...
                      }, 100);
                      */
                    }
                  };

                  // For interleaved mode, ensure style is loaded AND layers are processed before setting deck.gl layers
                  if (map._deckIsInterleaved) {
                    // Helper to set layers after verifying beforeId targets exist
                    const setDeckLayersDeferred = () => {
                      // Debug: Check if beforeId layers exist
                      const beforeIds = flowmapLayers
                        .map(l => l.props.beforeId)
                        .filter(id => id);

                      const missingLayers = beforeIds.filter(id => !map.getLayer(id));
                      if (missingLayers.length > 0) {
                        console.warn('[MapGL] beforeId target layers not found:', missingLayers);
                        console.log('[MapGL] Available layers:', map.getStyle().layers.map(l => l.id));
                      } else if (beforeIds.length > 0) {
                        console.log('[MapGL] All beforeId target layers found:', beforeIds);

                        // Warn about Mapbox Standard style if no style was provided (defaults to Standard)
                        // But ONLY if 'slot' is NOT provided (since slot is the fix)
                        if (!x.style && !flowmapConfig.slot) {
                          console.warn('[MapGL] Warning: You are using the default Mapbox Standard style with `before_id`. This style typically uses slots for layer positioning and may not support correct layer interleaving. If the flowmap renders on top of layers it should be behind, consider using a classic style (e.g., "mapbox://styles/mapbox/streets-v11") OR specify a `slot` (e.g. "middle") for your layers.');
                        }
                      }

                      setDeckLayers();
                    };

                    // Use setTimeout(0) to ensure all synchronous layer additions are processed
                    // This defers execution until after the current call stack completes
                    if (map.isStyleLoaded()) {
                      console.log('[MapGL] Style loaded, deferring flowmap layer setup until next tick');
                      setTimeout(() => {
                        console.log('[MapGL] Deferred: setting flowmap layers with beforeId');
                        setDeckLayersDeferred();
                      }, 0);
                    } else {
                      console.log('[MapGL] Waiting for style.load to set flowmap layers (interleaved mode)');
                      map.once('style.load', () => {
                        console.log('[MapGL] style.load fired, deferring flowmap layer setup');
                        setTimeout(() => {
                          console.log('[MapGL] Deferred after style.load: setting flowmap layers with beforeId');
                          setDeckLayersDeferred();
                        }, 0);
                      });
                    }
                  } else {
                    // For standalone deck, set layers immediately
                    setDeckLayers();
                  }
                } catch (error) {
                  console.error("Failed to set flowmap layers on overlay:", error);
                }
              }

            }
          
        
        if (map._deckgl) state.maps[mapId].deckgl = map._deckgl;
        if (map._deckOverlay) state.maps[mapId].deckOverlay = map._deckOverlay;
        if (map._deckContainer) state.maps[mapId].deckContainer = map._deckContainer;
    }

    function syncVisibility(map, layerIds, targetVisibility) {
        const mapId = map.getContainer().id;
        const mapState = state.maps[mapId];
        if (!mapState || !mapState.layers) return false;

        let handled = false;
        const isVisible = targetVisibility === 'visible';

        layerIds.forEach(layerId => {
            if (mapState.layers.some(l => {
                const baseId = l.id.split('-v')[0];
                return baseId === layerId || l.id.startsWith(layerId);
            })) {
                mapState.visibility[layerId] = isVisible;
                if (!map._flowmapVisibility) map._flowmapVisibility = {};
                map._flowmapVisibility[layerId] = isVisible;
                handled = true;
            }
        });

        if (handled) {
            const visibleLayers = mapState.layers.filter(layer => {
                const baseId = layer.id.split('-v')[0];
                return mapState.visibility[baseId] !== false;
            });

            if (mapState.deckgl) {
                mapState.deckgl.setProps({ layers: visibleLayers });
            } else if (mapState.deckOverlay) {
                mapState.deckOverlay.setProps({ layers: visibleLayers });
            }
            
            setTimeout(() => {
              if (map.triggerRepaint) map.triggerRepaint();
            }, 50);
        }

        return handled;
    }

    function handleStyleChange(map, x) {
        const mapId = map.getContainer().id;
        const mapState = state.maps[mapId];
        if (!mapState) return;

        if (mapState.deckOverlay && !map.hasControl(mapState.deckOverlay)) {
            map.addControl(mapState.deckOverlay);
        }

        if (x.flowmaps) {
            x.flowmaps.forEach(fm => {
                if (fm.dimBasemap) {
                    const darkMode = fm.settings && fm.settings.darkMode;
                    const filterVal = darkMode ? 'brightness(0.3) contrast(1.2)' : 'brightness(0.9) contrast(1.1)';
                    const mapCanvas = map.getCanvas();
                    if (mapCanvas) {
                        mapCanvas.style.setProperty('filter', filterVal, 'important');
                    }
                }
            });
        }
    }

    return {
        init,
        syncVisibility,
        handleStyleChange
    };

})();
