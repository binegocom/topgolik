# Release gates

This repository is NOT production-ready until the following are verified.

- [ ] Acquire or verify rights to re-distribute current match data, crests, news, and player imagery.
- [ ] Confirm coverage, rate limits, availability and provider change policy for the intended countries and leagues.
- [ ] Replace unbounded polling with monitored ingestion controls and provider SLAs where needed.
- [ ] CI backend + Android checks green; run iOS builds and App Store validation on macOS.
- [ ] Build and ship signed Android App Bundle and iOS IPA via protected signing secrets.
- [ ] Validate database backups, restore drill, queue health, clock skew and disaster recovery.
- [ ] Add production HTTPS, network policies, admin access controls, metrics, alerts and log redaction.
- [ ] Decide whether account sync, followed-team notifications, deep links, analytics and content moderation are required.
- [ ] Verify platform privacy labels, privacy policy, data processing agreements, and store review compliance.
- [ ] Run load tests and security tests against a staging deployment, with provider access disabled for synthetic workloads.

## Data principles

Never fabricate an event, score, club, logo, lineup or status in the running application. All match data has traceable provider keys and ingestion timestamps. External payloads must be validated, allow-listed and stored using stable identifiers. A source failure never clears successful data; stale results remain explicitly timestamped.
