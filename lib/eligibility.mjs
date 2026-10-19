// Stale findings remain historical and cannot establish a current gap.
export function aggregateEligibility(rules, coverageConfirmed = false) {
  const applicable = rules.filter(r => r.mandatory && r.applicability !== 'not_applicable');
  const gap = applicable.some(r => r.current && r.applicability === 'applicable' && r.result === 'not_met');
  const review = !coverageConfirmed || !applicable.length || applicable.some(r => !r.current || r.applicability !== 'applicable' || ['unknown', 'needs_review'].includes(r.result));
  return { outcome: gap ? 'Gaps identified' : review ? 'Review needed' : 'No confirmed gaps', reviewRequired: review, freshness: applicable.some(r => !r.current) ? 'Outdated' : 'Current' };
}
