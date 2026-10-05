# HSH App Documentation (`docs/`)

Technical references for the larger features of **HSH App** (`hsh_app2`) and the parts of the backend (`hsh_api`) they depend on. Each document describes how the feature works today, its API and storage, how to test it, and its known limitations.

| Document | Area | Covers |
| :--- | :--- | :--- |
| [GEOFENCING_DOCS.md](GEOFENCING_DOCS.md) | **Campus geofence, curfew & student locations** | Curfew window and campus boundary, breach detection on the phone (exit / heartbeat / enter / fake GPS / location off), breach console and warden actions, gate passes, the all-day **Student Locations** list and the warden-set update interval. The geofence never locks phones. |
| [PARENT_CONTROL_DOCS.md](PARENT_CONTROL_DOCS.md) | **Parental control & screen time** | Remote lock, blocked apps, bedtime, daily limit, the near-real-time policy channel (long-poll + versioning), on-phone enforcement including apps already open, usage telemetry, and the warden dashboard. |
| [PHONEBOOK_DOCS.md](PHONEBOOK_DOCS.md) | **Student phonebook & caller ID** | Directory sync from the AVD VVN API, offline SQLite search, Android Call Screening popup and notification, iOS CallKit Call Directory, and the `hsh/caller_id` channel. |
| [../ios/CALLER_ID_SETUP.md](../ios/CALLER_ID_SETUP.md) | iOS caller ID: quick reference | Bundle IDs, App Group, Xcode signing steps, iPhone setting. |
| [../ios/CALLER_ID_HANDOFF.md](../ios/CALLER_ID_HANDOFF.md) | iOS caller ID: full guide | Extension architecture, files, switching Apple developer accounts, troubleshooting. |
| [../APP_THEME_AND_COLORS.md](../APP_THEME_AND_COLORS.md) | Design system | Theme, colours and typography. |

## Conventions

- Paths starting with `lib/`, `android/` or `ios/` are in this repo. Paths starting with `hsh_api/` are in the backend repo.
- Links are relative to the document, so they work in any checkout and on GitHub.
- "Supervisor" in the API tables means the operator console or a platform-admin staff account (`requireRole('operator')` on the backend).
- Each document records the date it was last checked against the code. Update the doc in the same change as the code it describes.
