/**
 * Hydrate autonomous-enterprise-status.html from site/help/data/certification-status.json.
 * Static GitHub Pages mirror of .planning/enterprise-e2e/CERTIFICATION-STATUS.json.
 */
(function () {
  const DATA_URL = '../data/certification-status.json';

  const PROOF_CLASS = {
    live_e2e_proven: 'proof-proven',
    live_e2e_partial: 'proof-partial',
    shipped: 'proof-shipped',
    in_progress: 'proof-progress',
    planned: 'proof-planned',
  };

  const PROOF_LABEL = {
    live_e2e_proven: 'Live E2E (proven)',
    live_e2e_partial: 'Live E2E (partial)',
    shipped: 'Shipped',
    in_progress: 'In progress',
    planned: 'Planned',
  };

  function proofSpan(level) {
    const cls = PROOF_CLASS[level] || 'proof-planned';
    const label = PROOF_LABEL[level] || level;
    return `<span class="${cls}">${label}</span>`;
  }

  function hostRow(host) {
    const gaps = (host.evidence_gaps || []).join(', ') || 'none';
    const gates = host.gates_verdict && host.gates_verdict !== 'n/a' ? host.gates_verdict : 'n/a';
    const ledger = `${host.ledger_pass || '?'} (${host.ledger_reconcile || '?'})`;
    return `<tr data-host="${host.host}">
      <td>${host.host}</td>
      <td>${proofSpan(host.proof_level)}</td>
      <td>${ledger}; gates ${gates}; gaps: ${gaps}</td>
    </tr>`;
  }

  function apply(data) {
    const tbody = document.getElementById('cert-host-tbody');
    const meta = document.getElementById('cert-generated-meta');
    const claimNote = document.getElementById('cert-public-claim-note');
    if (!tbody || !data || !Array.isArray(data.hosts)) return;

    tbody.innerHTML = data.hosts.map(hostRow).join('');

    if (meta) {
      meta.textContent = `Generated: ${data.generated_at || '?'} @ ${data.sb_git_sha || '?'} — mirrors certification-status.json`;
    }

    if (claimNote && data.conservative_summary) {
      const ready = data.conservative_summary.public_autonomous_enterprise_claim_ready;
      claimNote.textContent = `public_autonomous_enterprise_claim_ready: ${ready} (${data.conservative_summary.tri_host_live_e2e_proven || 0}/3 hosts live_e2e_proven)`;
    }
  }

  fetch(DATA_URL, { cache: 'no-store' })
    .then((r) => (r.ok ? r.json() : Promise.reject(new Error(r.status))))
    .then(apply)
    .catch(() => {
      /* Static HTML fallback remains when fetch fails (local file preview). */
    });
})();
