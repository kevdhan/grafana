import { type DataFrame } from '@grafana/data';

// Explore renders at most this many series in the graph for performance; the
// user can opt into showing all via the "Show all N" disclaimer action.
export const MAX_NUMBER_OF_TIME_SERIES = 20;

// Limit how many series the Explore graph renders unless the user asked for all.
export function limitSeriesForDisplay(data: DataFrame[], showAllSeries: boolean): DataFrame[] {
  const limit = showAllSeries ? data.length : 1;
  return data.slice(0, limit);
}
