'use strict';
/**
 * Column grid → inch boxes. Every block declares a `region` such as
 *   { "cols": [start, span] }                      full content height
 *   { "cols": [start, span], "rows": [r, span, n] } one of n stacked rows
 *   { "cols": [start, span], "y": 1.3, "h": 3.5 }   explicit vertical override
 */
function createGrid(theme) {
  const { page, grid } = theme;
  const innerW = page.w - 2 * grid.marginX;
  const colW = (innerW - (grid.cols - 1) * grid.gap) / grid.cols;

  function columns(cols = [0, grid.cols]) {
    const [start, span] = cols;
    if (start < 0 || span < 1 || start + span > grid.cols) {
      throw new Error(`Invalid cols [${cols}] for a ${grid.cols}-column grid`);
    }
    return { x: grid.marginX + start * (colW + grid.gap), w: span * colW + (span - 1) * grid.gap };
  }

  function bandBox() {
    return { x: grid.marginX, y: grid.band.bottom - grid.band.h, w: innerW, h: grid.band.h };
  }

  /** Vertical content zone for a slide on the CONTENT layout. */
  function contentArea({ hasBand, hasLead }) {
    const top = hasLead ? grid.contentTop : grid.contentTopNoLead;
    const bottom = hasBand ? bandBox().y - grid.band.gap : grid.contentBottomNoBand;
    return { top, bottom };
  }

  function region(spec = {}, area) {
    const { x, w } = columns(spec.cols);
    let y = area.top;
    let h = area.bottom - area.top;
    if (spec.rows) {
      const [start, span, total] = spec.rows;
      const rowH = (h - (total - 1) * grid.gap) / total;
      y += start * (rowH + grid.gap);
      h = span * rowH + (span - 1) * grid.gap;
    }
    if (spec.y !== undefined) y = spec.y;
    if (spec.h !== undefined) h = spec.h;
    return { x, y, w, h };
  }

  return { innerW, colW, gap: grid.gap, columns, bandBox, contentArea, region };
}

module.exports = { createGrid };
