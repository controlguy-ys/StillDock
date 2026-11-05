'use strict';
/** Block registry: content `"type"` → async render(ctx, box, data). Add new block types here. */
const basic = require('./basic');
const cards = require('./cards');
const flows = require('./flows');
const compare = require('./compare');
const diagrams = require('./diagrams');

const registry = Object.freeze({
  presenter: basic.presenter,
  code: basic.code,
  agenda: cards.agenda,
  profile: cards.profile,
  stats: cards.stats,
  cards: cards.cards,
  steps: flows.steps,
  itemList: flows.itemList,
  staircase: flows.staircase,
  quoteCard: compare.quoteCard,
  compareFlow: compare.compareFlow,
  compareStatements: compare.compareStatements,
  shiftTable: compare.shiftTable,
  statements: compare.statements,
  contact: compare.contact,
  chain: diagrams.chain,
  lanes: diagrams.lanes,
  columns: diagrams.columns,
  table: diagrams.table,
});

module.exports = { registry };
