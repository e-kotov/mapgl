import {Deck} from '@deck.gl/core';
import {MapboxOverlay} from '@deck.gl/mapbox';
import {FlowmapLayer, getFlowmapCanvasEffects, getFlowmapCanvasStyle} from '@flowmap.gl/layers';

window.FlowmapGL = {
  Deck,
  FlowmapLayer,
  MapboxOverlay,
  getFlowmapCanvasEffects,
  getFlowmapCanvasStyle
};
