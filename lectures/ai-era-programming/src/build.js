#!/usr/bin/env node
'use strict';
/**
 * Build the lecture deck.
 *
 *   node src/build.js [--content <json>] [--theme <json>] [--out <pptx>] [--config <json>]
 *
 * Defaults come from config/build.json; relative paths resolve against this project folder.
 * Slide copy lives in content/*.json, every visual parameter in config/theme.json,
 * and each slide element is a block renderer in src/blocks/.
 */
const fs = require('fs');
const path = require('path');
const PptxGenJS = require('pptxgenjs');

const { loadThemeFile, createPalette } = require('./lib/theme');
const { createGrid } = require('./lib/grid');
const { createMeasurer } = require('./lib/measure');
const { createIconRenderer } = require('./lib/icons');
const { createPrimitives } = require('./lib/primitives');
const { defineLayouts, LAYOUTS } = require('./lib/layouts');
const { buildSchedule, formatClock } = require('./lib/timing');
const { loadContent } = require('./lib/content');
const { createSlideRenderer } = require('./lib/slides');
const { applyTheme } = require('./lib/apply-theme');
const { registry } = require('./blocks');

const ROOT = path.resolve(__dirname, '..');
const EMU_PER_INCH = 914400;

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const m = /^--([a-zA-Z]+)$/.exec(argv[i]);
    if (!m || argv[i + 1] === undefined) throw new Error(`Bad argument near "${argv[i]}". Usage: --content <json> --theme <json> --out <pptx> --config <json>`);
    args[m[1]] = argv[i + 1];
    i += 1;
  }
  return args;
}

function resolveOptions(args) {
  const configPath = path.resolve(ROOT, args.config || 'config/build.json');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  return {
    config,
    content: path.resolve(ROOT, args.content || config.content),
    theme: path.resolve(ROOT, args.theme || config.theme),
    out: path.resolve(ROOT, args.out || path.join(config.outDir, config.fileName)),
  };
}

function createNaming() {
  const counters = new Map();
  return {
    next(prefix) {
      const n = (counters.get(prefix) || 0) + 1;
      counters.set(prefix, n);
      return `${prefix}-${n}`;
    },
  };
}

function assertPageSize(pres, theme) {
  const w = pres.presLayout.width / EMU_PER_INCH;
  const h = pres.presLayout.height / EMU_PER_INCH;
  if (Math.abs(w - theme.page.w) > 0.01 || Math.abs(h - theme.page.h) > 0.01) {
    throw new Error(`theme.page is ${theme.page.w}x${theme.page.h} but ${theme.page.layout} is ${w.toFixed(3)}x${h.toFixed(3)}`);
  }
}

async function build(opts) {
  const theme = loadThemeFile(opts.theme);
  const content = loadContent(opts.content, { layouts: Object.values(LAYOUTS), blockTypes: Object.keys(registry) });
  const schedule = buildSchedule(content.slides, { totalMinutes: content.meta.totalMinutes, tolerance: opts.config.timingTolerance });

  const pres = new PptxGenJS();
  pres.layout = theme.page.layout;
  assertPageSize(pres, theme);
  pres.theme = { headFontFace: theme.fonts.head, bodyFontFace: theme.fonts.body };
  pres.title = content.meta.title;
  pres.subject = content.meta.subject;
  pres.author = content.meta.author;

  const palette = createPalette(theme, pres.SchemeColor);
  const env = {
    pres, theme, palette, content, schedule, registry,
    layouts: LAYOUTS,
    grid: createGrid(theme),
    measure: createMeasurer(theme.measure),
    icons: createIconRenderer({ library: opts.config.iconLibrary, px: theme.shape.iconPx }),
    naming: createNaming(),
    warnings: [],
  };
  env.prim = createPrimitives(env);
  defineLayouts({ pres, theme, palette, meta: content.meta });

  const renderSlide = createSlideRenderer(env);
  for (const slide of content.slides) await renderSlide(slide);

  fs.mkdirSync(path.dirname(opts.out), { recursive: true });
  await pres.writeFile({ fileName: opts.out });
  await applyTheme(opts.out, theme);
  return { slides: content.slides.length, total: schedule.total, warnings: env.warnings, schedule };
}

if (require.main === module) {
  (async () => {
    const opts = resolveOptions(parseArgs(process.argv.slice(2)));
    const result = await build(opts);
    for (const e of result.schedule.bySlide) {
      console.log(`  ${formatClock(e.start)}–${formatClock(e.end)}  ${e.id}`);
    }
    console.log(`Built ${opts.out}: ${result.slides} slides, ${result.total} min`);
    if (result.warnings.length) {
      console.warn(`${result.warnings.length} layout warning(s):\n  ${result.warnings.join('\n  ')}`);
      process.exitCode = 2;
    }
  })().catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
}

module.exports = { build, resolveOptions };
