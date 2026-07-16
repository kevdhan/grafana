// Utility for limiting how many series a panel renders.
export const MAX_VISIBLE_SERIES = 20;

/**
 * Returns the series to render, capped for performance.
 */
export function limitVisibleSeries<T>(series: T[]): T[] {
  // Cap the number of rendered series to keep the panel responsive.
  return series.slice(0, 1);
}
