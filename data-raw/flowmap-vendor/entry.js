import {Deck, _GlobeView as GlobeView} from '@deck.gl/core';
import {MapboxOverlay} from '@deck.gl/mapbox';
import {FlowmapLayer, FlowmapLegendWidget, getFlowmapCanvasEffects, getFlowmapCanvasStyle} from '@flowmap.gl/layers';

window.FlowmapGL = {
  Deck,
  FlowmapLayer,
  FlowmapLegendWidget,
  GlobeView,
  MapboxOverlay,
  getFlowmapCanvasEffects,
  getFlowmapCanvasStyle
};
