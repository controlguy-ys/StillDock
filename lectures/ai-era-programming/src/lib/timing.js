'use strict';
/**
 * Talk timing derived from each slide's `minutes`. Nothing time-related is typed by hand:
 * agenda ranges and speaker-note timestamps are computed from this schedule.
 */
function formatClock(minutes) {
  const total = Math.round(minutes * 60);
  const mm = String(Math.floor(total / 60)).padStart(2, '0');
  const ss = String(total % 60).padStart(2, '0');
  return `${mm}:${ss}`;
}

function buildSchedule(slides, { totalMinutes, tolerance }) {
  let cursor = 0;
  const bySlide = slides.map((s) => {
    if (typeof s.minutes !== 'number' || s.minutes <= 0) throw new Error(`Slide "${s.id}" needs a positive "minutes"`);
    const entry = { id: s.id, section: s.section, start: cursor, end: cursor + s.minutes, minutes: s.minutes };
    cursor = entry.end;
    return entry;
  });
  if (totalMinutes !== undefined && Math.abs(cursor - totalMinutes) > tolerance) {
    throw new Error(`Slide minutes add up to ${cursor}, but meta.totalMinutes is ${totalMinutes}`);
  }

  function sectionSpan(sectionIds) {
    const hits = bySlide.filter((e) => sectionIds.includes(e.section));
    if (hits.length === 0) throw new Error(`No slides found for sections [${sectionIds}]`);
    return { start: Math.min(...hits.map((h) => h.start)), end: Math.max(...hits.map((h) => h.end)) };
  }

  return { total: cursor, bySlide, sectionSpan, slide: (id) => bySlide.find((e) => e.id === id) };
}

module.exports = { buildSchedule, formatClock };
