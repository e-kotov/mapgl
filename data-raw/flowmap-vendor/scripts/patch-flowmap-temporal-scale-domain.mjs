// Reapply mapgl's temporal-scale-domain extension to the published FlowmapGL 9.5.0 ESM.
// Run after npm ci; assertions intentionally fail closed if upstream changes.
import {readFileSync, writeFileSync} from 'node:fs';
const root = new URL('../node_modules/', import.meta.url);
const path = (p) => new URL(p, root);
function patch(file, changes) {
  const url = path(file);
  let src = readFileSync(url, 'utf8');
  for (const [label, oldText, newText] of changes) {
    const count = src.split(oldText).length - 1;
    if (count !== 1) throw new Error(`${file}: expected exactly one "${label}" anchor, found ${count}`);
    src = src.replace(oldText, newText);
  }
  writeFileSync(url, src);
  console.log('Patched', file);
}

const data = '@flowmap.gl/data/dist/';
const layers = '@flowmap.gl/layers/dist/';

patch(data + 'FlowmapState.d.ts', [
  ['FilterState', '    selectedTimeRange?: [Date, Date];',
   '    selectedTimeRange?: [Date, Date];\n    selectedTimeRanges?: [Date, Date][];'],
  ['SettingsState', '    highlightColor: string | number[];',
   '    highlightColor: string | number[];\n    temporalScaleDomain: \'selected\' | \'all\';']
]);

patch(data + 'FlowmapSelectors.d.ts', [
  ['time-range selector',
   '    getSelectedTimeRange: (state: FlowmapState, props: FlowmapData<L, F>) => [Date, Date] | undefined;',
   '    getSelectedTimeRange: (state: FlowmapState, props: FlowmapData<L, F>) => [Date, Date] | undefined;\n    getSelectedTimeRanges: (state: FlowmapState, props: FlowmapData<L, F>) => [Date, Date][] | undefined;\n    getTemporalScaleDomain: Selector<L, F, \'selected\' | \'all\'>;'],
  ['unfiltered aggregated selector', '    getSortedAggregatedFilteredFlows:',
   '    getSortedAggregatedFlows: Selector<L, F, (F | AggregateFlow)[] | undefined>;\n    getFlowsForScaleDomain: Selector<L, F, (F | AggregateFlow)[] | undefined>;\n    getSortedAggregatedFilteredFlows:']
]);

const oldTime = `        this.getSortedFlowsForKnownLocationsFilteredByTime = createSelector(this.getSortedFlowsForKnownLocations, this.getTimeExtent, this.getSelectedTimeRange, (flows, timeExtent, timeRange) => {
            if (!flows)
                return undefined;
            if (!timeExtent ||
                !timeRange ||
                (timeExtent[0] === timeRange[0] && timeExtent[1] === timeRange[1])) {
                return flows;
            }
            return flows.filter((flow) => {
                const time = this.accessors.getFlowTime(flow);
                return time && timeRange[0] <= time && time < timeRange[1];
            });
        });`;
const newTime = `        this.getSortedFlowsForKnownLocationsFilteredByTime = createSelector(this.getSortedFlowsForKnownLocations, this.getTimeExtent, this.getSelectedTimeRange, this.getSelectedTimeRanges, (flows, timeExtent, timeRange, timeRanges) => {
            if (!flows)
                return undefined;
            const ranges = Array.isArray(timeRanges) && timeRanges.length > 0 ? timeRanges : timeRange ? [timeRange] : null;
            if (!timeExtent || !ranges) return flows;
            if (ranges.length === 1 && timeExtent[0] === ranges[0][0] && timeExtent[1] === ranges[0][1]) return flows;
            return flows.filter((flow) => {
                const time = this.accessors.getFlowTime(flow);
                return time && ranges.some((range) => range[0] <= time && time < range[1]);
            });
        });`;

patch(data + 'FlowmapSelectors.js', [
  ['selected time-range getters',
    '        this.getSelectedTimeRange = (state, props) => state.filter?.selectedTimeRange;',
    '        this.getSelectedTimeRange = (state, props) => state.filter?.selectedTimeRange;\n        this.getSelectedTimeRanges = (state, props) => state.filter?.selectedTimeRanges;\n        this.getTemporalScaleDomain = (state, props) => state.settings.temporalScaleDomain ?? \'selected\';'],
  ['multi-interval time filtering', oldTime, newTime],
  ['unfiltered aggregation',
   '        this.getSortedAggregatedFilteredFlows = createSelector(',
   `        this.getSortedAggregatedFlows = createSelector(this.getClusterIndex, this.getClusteringEnabled, this.getSortedFlowsForKnownLocations, this.getClusterZoom, (clusterTree, enabled, flows, zoom) => {
            if (!flows) return undefined;
            const aggregated = enabled && clusterTree && zoom != null
                ? clusterTree.aggregateFlows(flows, zoom, this.accessors.getFlowmapDataAccessors())
                : aggregateFlows(flows, this.accessors.getFlowmapDataAccessors());
            aggregated.sort((a,b) => descending(Math.abs(this.accessors.getFlowMagnitude(a)), Math.abs(this.accessors.getFlowMagnitude(b))));
            return aggregated;
        });
        this.getSortedAggregatedFilteredFlows = createSelector(`],
  ['domain selection',
   '        this.getExpandedSelectedLocationsSet = createSelector(',
   `        this.getFlowsForScaleDomain = createSelector(this.getTemporalScaleDomain, this.getSortedAggregatedFlows, this.getSortedAggregatedFilteredFlows, (domain, all, selected) => domain === 'all' ? all : selected);
        this.getExpandedSelectedLocationsSet = createSelector(`],
  ['global magnitude extent',
   '        this._getFlowMagnitudeExtent = createSelector(this.getSortedAggregatedFilteredFlows,',
   '        this._getFlowMagnitudeExtent = createSelector(this.getFlowsForScaleDomain,'],
  ['adaptive magnitude extent',
   `        this._getAdaptiveFlowMagnitudeExtent = createSelector(this.getFlowsForFlowmapLayer, (flows) => {
            if (!flows)
                return undefined;
            const rv = extent(flows, this.accessors.getFlowMagnitude);
            return rv[0] !== undefined && rv[1] !== undefined ? rv : undefined;
        });`,
   `        this._getAdaptiveFlowMagnitudeExtent = createSelector(this.getFlowsForScaleDomain, this.getLocationIdsInViewport, this.getSelectedLocationsSet, this.getLocationFilterMode, this.getMaxTopFlowsDisplayNum, this.getFlowEndpointsInViewportMode,
          (flows, locationIdsInViewport, selectedLocationsSet, locationFilterMode, maxTopFlowsDisplayNum, viewportMode) => {
            if (!flows || !locationIdsInViewport) return undefined;
            const picked = [];
            for (const flow of flows) {
              const origin = this.accessors.getFlowOriginId(flow);
              const dest = this.accessors.getFlowDestId(flow);
              const inView = viewportMode === 'both'
                ? locationIdsInViewport.has(origin) && locationIdsInViewport.has(dest)
                : locationIdsInViewport.has(origin) || locationIdsInViewport.has(dest);
              if (inView && origin !== dest && this.isFlowInSelection(flow, selectedLocationsSet, locationFilterMode)) picked.push(flow);
              if (picked.length > maxTopFlowsDisplayNum) break;
            }
            const rv = extent(picked, this.accessors.getFlowMagnitude);
            return rv[0] !== undefined && rv[1] !== undefined ? rv : undefined;
        });`]
]);

patch(layers + 'FlowmapLayer.d.ts', [
  ['temporal layer prop', '    highlightColor?: string | number[];',
   '    highlightColor?: string | number[];\n    temporalScaleDomain?: \'selected\' | \'all\';'],
  ['temporal layer default', '        adaptiveScalesEnabled: boolean;',
   '        adaptiveScalesEnabled: boolean;\n        temporalScaleDomain: string;']
]);

patch(layers + 'FlowmapLayer.js', [
  ['data-update settings',
   "    'highlightColor',",
   "    'highlightColor',\n    'temporalScaleDomain',"],
  ['destructure temporal setting',
   'colorScheme, highlightColor, maxTopFlowsDisplayNum,',
   'colorScheme, highlightColor, temporalScaleDomain, maxTopFlowsDisplayNum,'],
  ['forward settings',
   '            highlightColor: highlightColor ?? defaults.highlightColor,',
   '            highlightColor: highlightColor ?? defaults.highlightColor,\n            temporalScaleDomain: temporalScaleDomain ?? defaults.temporalScaleDomain,'],
  ['default temporal setting',
   '    adaptiveScalesEnabled: true,',
   "    adaptiveScalesEnabled: true,\n    temporalScaleDomain: 'selected',"]
]);
