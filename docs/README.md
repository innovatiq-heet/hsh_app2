# HSH Project Documentation (`docs/`)

This directory contains complete technical blueprints, system architecture specifications, and implementation references for the core platforms in **HSH App** (`hsh_app2`).

---

## Documentation Index

| Document | Area | Description |
| :--- | :--- | :--- |
| [GEOFENCING_DOCS.md](file:///c:/Users/kruta/Desktop/hsh_seva/hsh_app2/docs/GEOFENCING_DOCS.md) | **Campus Geofencing & Curfew Enforcement** | Ray-casting Point-in-Polygon mathematics, 12-vertex campus perimeter, GPS noise hysteresis state machine, mock location detection, gate pass exemptions, and auto-lock on breach. |
| [PARENT_CONTROL_DOCS.md](file:///c:/Users/kruta/Desktop/hsh_seva/hsh_app2/docs/PARENT_CONTROL_DOCS.md) | **Parental Control & Screen Time** | Complete technical guide to remote device lock, bedtime curfews, daily limits, real-time app blocking (`AccessibilityService`), foreground polling service (`PolicyPollService`), usage aggregation, and emergency safety features. |
| [PHONEBOOK_DOCS.md](file:///c:/Users/kruta/Desktop/hsh_seva/hsh_app2/docs/PHONEBOOK_DOCS.md) | **Student Phonebook & Native Caller ID** | Technical reference for the Student Phonebook, SQLite local caching, multi-contact normalization, and zero-copy native Android `CallScreeningService` + floating overlay system. |
