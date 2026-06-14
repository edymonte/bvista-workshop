---
description: >
  Escalation and incident management playbook for Farmácia Boa Vista N2 Support.
  Use this skill when the user mentions: incidente, downtime, alerta, SLA, escalação,
  incident, outage, degradação, fora do ar.
applyTo: "**"
---

# Skill: Escalation — Suporte N2 Farmácia Boa Vista

## When to activate

Activate this skill whenever the user's message contains any of the following keywords
(case-insensitive, Portuguese or English):

`incidente` · `downtime` · `alerta` · `SLA` · `escalação` · `incident` · `outage` · `degradação` · `fora do ar`

---

## Incident classification

### P1 — Production down (SLA: 1 hour)

**Criteria:** The production environment is completely unavailable or a critical business flow
(checkout, payment, stock) is fully broken for all users.

**Immediate actions (execute in order):**

1. Open a **war-room** on Microsoft Teams in the channel `#incidentes-producao`.
2. Notify the on-call **Tech Lead** by direct message and phone.
   - If no response within **10 minutes**, escalate to the **CTO**.
   - If no response within **20 minutes**, escalate to the **Diretor de TI**.
3. Create a GitHub Issue in this repository with labels `incident` + `p1` + `production`.
   Title format: `[P1] <short description> — <date YYYY-MM-DD HH:MM>`
4. Update the **status page** every **15 minutes** with current impact, actions taken,
   and estimated time to resolution (ETR).
5. Perform a post-mortem within **48 hours** of resolution and attach it to the GitHub Issue.

**Contacts:** see [.github/knowledge/contacts.md](../knowledge/contacts.md)

---

### P2 — Severe degradation (SLA: 4 hours)

**Criteria:** Production is partially available but a significant portion of users or a key
feature is impacted (e.g., slow response > 5 s, partial payment failures, intermittent errors).

**Actions:**

1. Create a GitHub Issue in this repository with labels `incident` + `p2`.
   Title format: `[P2] <short description> — <date YYYY-MM-DD HH:MM>`
2. Notify the on-call **Tech Lead** by direct message.
3. Update the GitHub Issue with progress notes at least every **1 hour**.
4. Update the status page once at incident open and once at resolution.
5. Link any relevant alerts, logs, or APM traces in the issue body.

**Contacts:** see [.github/knowledge/contacts.md](../knowledge/contacts.md)

---

### P3 — Limited impact (SLA: 24 hours)

**Criteria:** Small subset of users affected, workaround available, no revenue impact.

**Actions:**

1. Register the incident as a **backlog item** (GitHub Issue with labels `incident` + `p3` + `backlog`).
2. Add it to the **next sprint** during sprint planning.
3. No immediate notification required — mention during the next daily stand-up.

---

## Escalation matrix

| Priority | First contact | Escalate after | Second contact | Escalate after | Third contact |
|---|---|---|---|---|---|
| P1 | Tech Lead | 10 min | CTO | 20 min | Diretor de TI |
| P2 | Tech Lead | 1 h | CTO | — | — |
| P3 | Team (backlog) | — | — | — | — |

Full contact details (phone, Teams handle, e-mail): [.github/knowledge/contacts.md](../knowledge/contacts.md)

---

## GitHub Issue template (quick reference)

```
### Incident summary
<!-- One sentence describing what is broken -->

### Impact
- Affected users / percentage:
- Affected features:
- Revenue impact (estimated):

### Timeline
| Time (UTC-3) | Event |
|---|---|
| HH:MM | Incident detected |
| HH:MM | N2 engaged |
| HH:MM | ... |

### Root cause (fill after resolution)

### Actions taken

### Resolution

### Follow-up tasks
- [ ] Post-mortem scheduled
- [ ] Fix deployed to production
- [ ] Status page updated to "operational"
```

---

## Status page update cadence

| Priority | First update | Subsequent updates | Resolution update |
|---|---|---|---|
| P1 | Within 5 min of detection | Every 15 min | Immediately on resolution |
| P2 | Within 15 min | Every 1 h | Immediately on resolution |
| P3 | Not required | — | Not required |

---

## Definition of done for an incident

An incident is considered **resolved** when all of the following are true:

- [ ] All affected services are back to normal operation.
- [ ] Status page shows "Operational".
- [ ] GitHub Issue is closed with a resolution comment.
- [ ] Post-mortem scheduled (P1) or root cause noted (P2).
