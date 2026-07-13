import { FieldType, toDataFrame } from '@grafana/data';

import { MAX_NUMBER_OF_TIME_SERIES, limitSeriesForDisplay } from './limitSeries';

function makeSeries(count: number) {
  return Array.from({ length: count }, (_, i) =>
    toDataFrame({
      name: `series-${i}`,
      fields: [
        { name: 'Time', type: FieldType.time, values: [1, 2] },
        { name: 'Value', type: FieldType.number, values: [i, i + 1] },
      ],
    })
  );
}

describe('limitSeriesForDisplay', () => {
  it('caps at MAX_NUMBER_OF_TIME_SERIES when not showing all', () => {
    expect(limitSeriesForDisplay(makeSeries(56), false)).toHaveLength(MAX_NUMBER_OF_TIME_SERIES);
  });

  it('returns every series when showAllSeries is true', () => {
    expect(limitSeriesForDisplay(makeSeries(56), true)).toHaveLength(56);
  });

  it('returns all series when there are fewer than the limit', () => {
    expect(limitSeriesForDisplay(makeSeries(5), false)).toHaveLength(5);
  });
});
