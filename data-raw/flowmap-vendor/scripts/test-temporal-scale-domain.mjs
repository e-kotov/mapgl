import assert from 'node:assert/strict';
import FlowmapSelectors from '@flowmap.gl/data/dist/FlowmapSelectors.js';

const day = (s) => new Date(s + 'T00:00:00Z');
const locations = [
  {id: 'a', lat: 0, lon: 0},
  {id: 'b', lat: 0, lon: 1},
  {id: 'c', lat: 0, lon: 2}
];
const flows = [
  {origin: 'a', dest: 'b', count: 5, time: day('2026-01-01')},
  {origin: 'b', dest: 'c', count: 100, time: day('2026-01-03')}
];
const data = {locations, flows};
const accessors = {
  getLocationId: (x) => x.id,
  getLocationLat: (x) => x.lat,
  getLocationLon: (x) => x.lon,
  getFlowOriginId: (x) => x.origin,
  getFlowDestId: (x) => x.dest,
  getFlowMagnitude: (x) => x.count,
  getFlowTime: (x) => x.time
};
const selectors = new FlowmapSelectors(accessors);
const state = (domain, filter, adaptiveScalesEnabled = false) => ({
  viewport: {longitude: 1, latitude: 0, zoom: 3, width: 1200, height: 800},
  settings: {
    clusteringEnabled: false,
    clusteringAuto: false,
    clusteringLevel: undefined,
    locationsEnabled: true,
    locationTotalsEnabled: false,
    locationLabelsEnabled: false,
    flowLinesRenderingMode: 'straight',
    darkMode: false,
    fadeEnabled: false,
    fadeOpacityEnabled: false,
    fadeAmount: 50,
    colorScheme: 'Teal',
    highlightColor: 'orange',
    adaptiveScalesEnabled,
    temporalScaleDomain: domain,
    maxTopFlowsDisplayNum: 100,
    flowEndpointsInViewportMode: 'any',
    flowLineThicknessScale: 1
  },
  filter
});
const early = {selectedTimeRange: [day('2026-01-01'), day('2026-01-02')]};
const selected = state('selected', early);
const all = state('all', early);
assert.deepEqual(selectors.getCurrentFlowMagnitudeExtent(selected, data), [5, 5]);
assert.deepEqual(selectors.getCurrentFlowMagnitudeExtent(all, data), [5, 100]);
assert.deepEqual(
  selectors.getSortedAggregatedFilteredFlows(all, data).map((x) => x.count),
  [5],
  'all-time scale domain must never change rendered flows'
);
for (const adaptive of [false, true]) {
  const selectedState = state('selected', early, adaptive);
  const allState = state('all', early, adaptive);
  assert.deepEqual(selectors.getCurrentFlowMagnitudeExtent(selectedState, data), [5, 5], 'selected domain, adaptive=' + adaptive);
  assert.deepEqual(selectors.getCurrentFlowMagnitudeExtent(allState, data), [5, 100], 'all domain, adaptive=' + adaptive);
}
const disjoint = state('selected', {
  selectedTimeRange: [day('2026-01-01'), day('2026-01-02')],
  selectedTimeRanges: [
    [day('2026-01-01'), day('2026-01-02')],
    [day('2026-01-03'), day('2026-01-04')]
  ]
});
assert.deepEqual(
  selectors.getSortedAggregatedFilteredFlows(disjoint, data).map((x) => x.count).sort((a, b) => a - b),
  [5, 100],
  'disjoint selectedTimeRanges override single selectedTimeRange'
);
console.log('PASS: selected/all temporal scales, adaptive/nonadaptive scales, and disjoint time ranges');
