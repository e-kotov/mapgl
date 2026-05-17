/*
 * Flowmap Settings Menu
 * Creates an interactive settings panel using lil-gui
 */

// This will be loaded as a standalone script, so lil-gui needs to be available globally
(function () {
  'use strict';

  window.FlowmapSettings = {
    /**
     * Initialize settings GUI for a flowmap layer
     * @param {Object} initialSettings - Initial settings from R
     * @param {Function} onSettingsChange - Callback when settings change
     * @returns {Object} GUI instance
     */
    createGUI: function (initialSettings, onSettingsChange) {
      // Check if lil-gui is available
      if (typeof lil === 'undefined' || !lil.GUI) {
        console.error('lil-gui library not loaded. Settings menu cannot be created.');
        return null;
      }

      const gui = new lil.GUI({ title: 'Flowmap Settings' });

      // Define available color schemes
      const COLOR_SCHEMES = [
        'Blues', 'BluGrn', 'BluYl', 'BrwnYl', 'BuGn', 'BuPu', 'Burg', 'BurgYl',
        'Cool', 'DarkMint', 'Emrld', 'GnBu', 'Grayish', 'Greens', 'Greys',
        'Inferno', 'Magenta', 'Magma', 'Mint', 'Oranges', 'OrRd', 'OrYel',
        'Peach', 'Plasma', 'PinkYl', 'PuBu', 'PuBuGn', 'PuRd', 'Purp',
        'Purples', 'PurpOr', 'RdPu', 'RedOr', 'Reds', 'Sunset', 'SunsetDark',
        'Teal', 'TealGrn', 'Viridis', 'Warm', 'YlGn', 'YlGnBu', 'YlOrBr', 'YlOrRd'
      ];

      // Create state object
      const state = {
        darkMode: initialSettings.darkMode !== undefined ? initialSettings.darkMode : true,
        colorScheme: initialSettings.colorScheme || 'Teal',
        highlightColor: initialSettings.highlightColor || '#ff9b29',
        dimBasemap: initialSettings.dimBasemap !== undefined ? initialSettings.dimBasemap : false,
        // Initial simplified mode based on booleans
        blendMode: initialSettings.webglBlendMode ? 'glow' : (initialSettings.cssBlendMode ? 'screen' : 'normal'),
        cssBlendMode: initialSettings.cssBlendMode !== undefined ? initialSettings.cssBlendMode : false, // Internal
        webglBlendMode: initialSettings.webglBlendMode !== undefined ? initialSettings.webglBlendMode : false, // Internal
        opacity: (initialSettings.opacity !== undefined && initialSettings.opacity !== null) ? initialSettings.opacity : 1.0,
        fadeEnabled: initialSettings.fadeEnabled !== undefined ? initialSettings.fadeEnabled : true,
        fadeOpacityEnabled: initialSettings.fadeOpacityEnabled !== undefined ? initialSettings.fadeOpacityEnabled : false,
        fadeAmount: (initialSettings.fadeAmount !== undefined && initialSettings.fadeAmount !== null) ? initialSettings.fadeAmount : 50,
        clusteringEnabled: initialSettings.clusteringEnabled !== undefined ? initialSettings.clusteringEnabled : true,
        clusteringAuto: initialSettings.clusteringAuto !== undefined ? initialSettings.clusteringAuto : true,
        clusteringLevel: (initialSettings.clusteringLevel !== undefined && initialSettings.clusteringLevel !== null) ? initialSettings.clusteringLevel : 5,
        clusteringMethod: initialSettings.clusteringMethod || 'HCA',
        animationEnabled: initialSettings.animationEnabled !== undefined ? initialSettings.animationEnabled : false,
        adaptiveScalesEnabled: initialSettings.adaptiveScalesEnabled !== undefined ? initialSettings.adaptiveScalesEnabled : true,
        locationsEnabled: initialSettings.locationsEnabled !== undefined ? initialSettings.locationsEnabled : true,
        locationTotalsEnabled: initialSettings.locationTotalsEnabled !== undefined ? initialSettings.locationTotalsEnabled : true,
        locationLabelsEnabled: initialSettings.locationLabelsEnabled !== undefined ? initialSettings.locationLabelsEnabled : false,
        maxTopFlowsDisplayNum: (initialSettings.maxTopFlowsDisplayNum !== undefined && initialSettings.maxTopFlowsDisplayNum !== null) ? initialSettings.maxTopFlowsDisplayNum : 5000,
        flowLineCurviness: initialSettings.flowLineCurviness !== undefined ? initialSettings.flowLineCurviness : 0.5,
        flowLineThicknessScale: initialSettings.flowLineThicknessScale !== undefined ? initialSettings.flowLineThicknessScale : 1.0,
        flowEndpointsInViewportMode: initialSettings.flowEndpointsInViewportMode || 'all',
        useCurvedArrows: initialSettings.useCurvedArrows !== undefined ? initialSettings.useCurvedArrows : false
      };

      // Add controls
      gui.add(state, 'darkMode').onChange(onSettingsChange);

      const effectFolder = gui.addFolder('Effects');
      effectFolder.add(state, 'dimBasemap').name('Dim Basemap').onChange(onSettingsChange);

      // Blend Mode Dropdown
      effectFolder.add(state, 'blendMode', ['normal', 'screen', 'glow'])
        .name('Blend Mode')
        .onChange(function (value) {
          // Update internal flags based on selection
          state.cssBlendMode = (value === 'screen' || value === 'glow');
          state.webglBlendMode = (value === 'glow');

          // Smart defaults: Auto-enable dimming for blending modes if not already on
          if (value !== 'normal' && !state.dimBasemap) {
            state.dimBasemap = true;
            // We need to update the checkbox UI manually if possible, or just accept it updates state
            // lil-gui controllers update automatically if they listen to object loop, but here we just set prop.
            // We need to find the controller for dimBasemap to update it visualy
            const controllers = effectFolder.controllers;
            const dimCtrl = controllers.find(c => c.property === 'dimBasemap');
            if (dimCtrl) dimCtrl.updateDisplay();
          }

          onSettingsChange();
        });
      gui.add(state, 'colorScheme', COLOR_SCHEMES).onChange(onSettingsChange);
      gui.addColor(state, 'highlightColor').onChange(onSettingsChange);
      gui.add(state, 'opacity', 0.0, 1.0).onChange(onSettingsChange);
      gui.add(state, 'animationEnabled').onChange(onSettingsChange);
      gui.add(state, 'adaptiveScalesEnabled').onChange(onSettingsChange);
      gui.add(state, 'locationsEnabled').onChange(onSettingsChange);
      gui.add(state, 'locationTotalsEnabled').onChange(onSettingsChange);
      gui.add(state, 'locationLabelsEnabled').onChange(onSettingsChange);

      gui.add(state, 'maxTopFlowsDisplayNum')
        .min(0)
        .max(10000)
        .step(10)
        .onChange(onSettingsChange);

      const visualFolder = gui.addFolder('Visuals');
      visualFolder.add(state, 'useCurvedArrows').name('Curved Arrows').onChange(onSettingsChange);
      visualFolder.add(state, 'flowLineCurviness', 0.0, 1.0).name('Curviness').onChange(onSettingsChange);
      visualFolder.add(state, 'flowLineThicknessScale', 0.1, 5.0).name('Thickness Scale').onChange(onSettingsChange);
      visualFolder.add(state, 'flowEndpointsInViewportMode', ['all', 'any']).name('Viewport Culling').onChange(onSettingsChange);

      // Fade folder
      const fading = gui.addFolder('Fade');
      const fadeEnabled = fading.add(state, 'fadeEnabled').onChange(function (value) {
        fadeAmount.enable(value);
        fadeOpacityEnabled.enable(value);
        onSettingsChange();
      });
      const fadeOpacityEnabled = fading.add(state, 'fadeOpacityEnabled')
        .enable(state.fadeEnabled)
        .onChange(onSettingsChange);
      const fadeAmount = fading.add(state, 'fadeAmount')
        .min(0)
        .max(100)
        .enable(state.fadeEnabled)
        .onChange(onSettingsChange);

      // Clustering folder
      const clustering = gui.addFolder('Clustering');
      const clusteringEnabled = clustering.add(state, 'clusteringEnabled').onChange(function (value) {
        clusteringAuto.enable(value);
        clusteringMethod.enable(value);
        clusteringLevel.enable(value && !state.clusteringAuto);
        onSettingsChange();
      });
      const clusteringMethod = clustering.add(state, 'clusteringMethod', ['HCA', 'H3'])
        .enable(state.clusteringEnabled)
        .onChange(onSettingsChange);
      const clusteringAuto = clustering.add(state, 'clusteringAuto')
        .enable(state.clusteringEnabled)
        .onChange(function (value) {
          clusteringLevel.enable(!value);
          onSettingsChange();
        });
      const clusteringLevel = clustering.add(state, 'clusteringLevel')
        .min(0)
        .max(20)
        .step(1)
        .enable(!state.clusteringAuto)
        .onChange(onSettingsChange);

      // Return both GUI and state getter
      return {
        gui: gui,
        getState: function () { return state; }
      };
    },

    /**
     * Destroy a GUI instance
     * @param {Object} guiInstance - The GUI instance to destroy
     */
    destroyGUI: function (guiInstance) {
      if (guiInstance && guiInstance.gui) {
        guiInstance.gui.destroy();
      }
    }
  };
})();
