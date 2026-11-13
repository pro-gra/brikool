# Brikool free-launch and product evolution plan

## Current release mode: FREE LAUNCH

The Flutter service layer uses `FirestoreService.freeLaunch` as the central switch. While true:
- Technician online availability has no wallet minimum.
- Technician acceptance does not require wallet funds.
- Technician and company commission rates are zero.
- Moving a technician en route does not debit the wallet.
- Starting a company project does not debit its wallet.

Payment and wallet screens remain in the repository for a later monetization phase. They are not the requirement for a technician to go online.

## Availability and trust

The existing account suspension and verification workflows should remain in place. Online status means the technician is available; customer discovery and request routing should continue to respect approved identity/specialty checks until the trust workflow is explicitly redesigned.

## Product roadmap — not yet implemented by this change

### Customer experience
- Live technician location and arrival estimate, with explicit location-sharing consent.
- Clear verified technician profiles, specialties, service areas, availability, ratings and completed-work portfolios.
- Before/after work gallery with customer privacy controls.
- Referral links, referral credits and abuse-resistant reward rules.
- Home Care plans with recurring maintenance reminders and service history.
- AI-assisted problem triage, photo diagnosis, category selection and budget guidance with clear limitations.

### Technician experience
- One-tap online/offline availability and clear availability state.
- Better job cards with distance, service, customer notes, budget and schedule.
- Work portfolio and before/after uploads.
- Transparent job history, ratings, earnings and performance insights.
- Location sharing only while en route/working and only with clear consent.

### Company experience
- Improved quote and project timeline, team assignment, milestones, customer approvals and document handling.

### Admin experience
- Trust and safety queue, verification audit trail, fraud/referral monitoring, service quality analytics and feature-flag controls.

## Release safeguards
- Keep admin verification, suspension and abuse controls.
- Do not expose exact technician or customer locations publicly.
- Re-enable commissions only after server-side enforcement, payment reconciliation, customer/technician terms and a full test pass.
- Audit deployed Firestore Security Rules and rotate any credentials that have ever been committed to source control.
- Run Flutter analyze/tests and Firebase emulator tests before merging or deploying.
