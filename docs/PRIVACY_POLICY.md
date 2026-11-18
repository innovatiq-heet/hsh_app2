# Privacy Policy — HSH Connect (Hari Saurabh Hostel)

**App Name:** HSH Connect  
**Package ID:** `com.avd_hsh.app`  
**Organization:** Hari Saurabh Hostel (AVD VVN), Vallabh Vidyanagar, Gujarat, India  
**Hosted Policy URL:** https://lightcoral-eel-306042.hostingersite.com/privacy-policy  
**Last Updated:** November 18, 2026

---

## 1. Overview & Scope
**HSH Connect** (`com.avd_hsh.app`) is the official institutional hostel management application operated for **Hari Saurabh Hostel (AVD VVN)**. It is intended exclusively for authorized hostel residents (students), student group leaders, alumni, wardens, hostel administrators, and support staff (complaint solvers and laundry staff).

This Privacy Policy explains what information HSH Connect collects, why specific Android and iOS permissions are requested, how your data is used and protected, and how you can request account or data deletion.

---

## 2. Information We Collect

### 2.1 Student, Family & Account Information
- **Identity & Hostel Profile:** Full name, student/bank code, email address, mobile and WhatsApp phone numbers, room number, wing/group name, admission status, date of birth, blood group, vehicle number, and masked Aadhar reference.
- **Residential & Family Details:** Permanent home address, city, district, state, PIN code, father's and mother's names, phone numbers (including India and international contacts), occupations, dates of birth, and parents' marriage anniversary (used for emergency communication and hostel community greetings).
- **Hostel Operations Data:** Attendance records, leave/gate-pass requests, fee payment records, laundry logs, maintenance complaints (including optional user-selected complaint photos), polls/forms responses, and announcement read receipts.

### 2.2 Device & Technical Information
- **Device Identifiers:** App-generated device UUID (used strictly to prevent duplicate/proxy attendance across multiple accounts on one device) and push notification tokens (FCM) to deliver hostel notices and alerts.
- **Diagnostics:** App version, platform (Android/iOS), and basic error telemetry required for reliability and security.

---

## 3. Sensitive Permissions & Prominent Disclosures

### 3.1 AccessibilityService API Disclosure (`BIND_ACCESSIBILITY_SERVICE`)
HSH Connect includes an institutional parental-control and study-hour enforcement service (`AppBlockerAccessibilityService`) enabled **only** for active hostel student devices under hostel admission policy.
- Reads only the active foreground application package name and window-state events to enforce warden-configured study/curfew app restrictions, daily app time limits, and prevent unauthorized stopping of the hostel policy service.
- **Never** reads keystrokes, passwords, private messages, banking/financial data, or screen text for advertising, profiling, or third-party sharing.

### 3.2 Location & Background Location Disclosure (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE_LOCATION`)
For active hostel residents, HSH Connect collects location data **even when the app is closed or not in use** via a persistent foreground service strictly to:
1. Verify campus curfew geofence compliance during hostel curfew hours.
2. Honor warden-issued temporary gate passes.
3. Alert hostel wardens for student safety if a resident is outside campus during curfew.

The curfew geofence **never locks a student's phone**, and location data is never used for advertising or shared with third-party marketers.

### 3.3 Complete Permissions Table

| Permission / API | Who Uses It | Purpose |
| :--- | :--- | :--- |
| `PACKAGE_USAGE_STATS` | Active Hostel Students | Summarizes daily app usage durations for hostel screen-time reporting and study-hour discipline. |
| `BIND_ACCESSIBILITY_SERVICE` | Active Hostel Students | Enforces hostel-configured app blocks, time limits, and app-install restrictions during residence. |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION` | Active Hostel Students | Curfew geofence monitoring (including in background when closed) and BLE attendance proximity. |
| `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE` | Students & Wardens | Short-range BLE proximity verification during hostel attendance sessions. |
| `CAMERA` & Android System Photo Picker | All Users | Only invoked when the user captures a complaint photo, uploads a receipt, or scans a QR code. Broad storage/media permissions (`READ_EXTERNAL_STORAGE`, `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_VISUAL_USER_SELECTED`) are explicitly removed (`tools:node="remove"`), using Android's native **System Photo Picker** in full compliance with Google Play's Photo & Video Permissions policy. |
| `READ_PHONE_STATE`, `READ_PHONE_NUMBERS` | Students & Staff | SIM-assisted sign-in verification and single-device binding to prevent proxy attendance. |
| `BIND_SCREENING_SERVICE`, `SYSTEM_ALERT_WINDOW` | Authorized Wardens & Admins Only | Hostel Phonebook Caller ID overlay identifying incoming calls from registered students/parents. Disabled for students and alumni. |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `RECEIVE_BOOT_COMPLETED`, `POST_NOTIFICATIONS` | Active Hostel Students & Staff | Keeps policy sync, geofence checks, and hostel notifications active across device restarts. |

---

## 4. Data Sharing & Third-Party Services
**We do NOT sell, rent, or trade personal data to advertisers, data brokers, or third parties.**

Data is processed solely within authorized hostel infrastructure:
- **Hostel Management Backend (HAMS):** Encrypted HTTPS/TLS backend for authentication, attendance, complaints, screen time, geofencing, forms, and broadcasts.
- **AVD VVN Institutional Student Directory:** Official hostel admission records synchronized for student and parent profiles.
- **Native Call / SMS / WhatsApp Intents:** Triggered only on explicit user action (calling or messaging from the directory) or official hostel birthday/anniversary greetings via the hostel WhatsApp gateway.

---

## 5. Data Security & Retention
- All data in transit is encrypted via HTTPS/TLS with JWT authentication and strict role-based access control (RBAC).
- Screen-time monitoring, app restrictions, and geofencing apply **only to active hostel residents** and stop automatically on logout or when a student becomes an alumni.
- Warden phonebook call-history logs are automatically purged after **12 months**.

---

## 6. Account & Data Deletion Requests
Students, parents, alumni, or staff may request access to, correction of, or deletion of their HSH Connect account and personal data at any time:
- **In Person:** Hari Saurabh Hostel Administration Office (provide your Student Code and registered mobile number).
- **By Email:** Email **krutarthsolanki9@gmail.com** with subject `Account / Data Deletion Request — HSH Connect`, including your full name, Student Code, and registered mobile number.

Verified requests are processed within **15 business days**. App authentication tokens, device bindings, location logs, and screen-time telemetry are permanently deleted (institutional fee/admission records are retained only where administratively or legally required).

---

## 7. Contact Us
**Hari Saurabh Hostel (HSH) — Administration & Privacy Contact**  
- **App:** HSH Connect (`com.avd_hsh.app`)  
- **Location:** Hari Saurabh Hostel (AVD VVN), Vallabh Vidyanagar, Gujarat, India  
- **Email:** krutarthsolanki9@gmail.com  
- **Live Privacy Policy URL:** https://lightcoral-eel-306042.hostingersite.com/privacy-policy
