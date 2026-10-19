import { test } from 'node:test';
import assert from 'node:assert/strict';
import { aggregateEligibility as assess } from '../lib/eligibility.mjs';
const rule = (result, current = true) => ({ mandatory: true, applicability: 'applicable', result, current });
test('complete current evidence passes; empty and incomplete evidence do not', () => {
 assert.equal(assess([rule('met')], true).outcome, 'No confirmed gaps');
 assert.equal(assess([], true).outcome, 'Review needed');
 assert.equal(assess([rule('met')], false).outcome, 'Review needed');
});
test('current gap survives a stale second lot, with review required', () => {
 assert.deepEqual(assess([rule('not_met'), rule('met', false)], true), { outcome: 'Gaps identified', reviewRequired: true, freshness: 'Outdated' });
});
test('historical gaps do not count until revalidated', () => {
 assert.equal(assess([rule('not_met', false), rule('met')], true).outcome, 'Review needed');
 assert.equal(assess([rule('not_met')], true).outcome, 'Gaps identified');
});
test('unknown applicability and missing evidence require review', () => {
 assert.equal(assess([rule('unknown')], true).outcome, 'Review needed');
 assert.equal(assess([{ ...rule('met'), applicability: 'unknown' }], true).outcome, 'Review needed');
});
