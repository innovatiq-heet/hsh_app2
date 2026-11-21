# Daily Alumni Connect contact management

Last updated: 2026-11-21

History shows the current WhatsApp number and manually maintained reachability status for each outreach row. The History tab keeps the Today progress card out of the way, places status filters above the list, and hides sent message text until expanded. Admins can tap a status to change it, tap the edit icon to open the mobile number sheet, or open number changes from the history icon. The number sheet explains that a changed number returns to Not Verified. Cancel closes it without saving. Leaders can view the status but cannot change it. A successful update reloads Today and History so later sends use the current number.

## Required `hsh_api` contract

The backend repository is separate and is not present in this workspace. Deploy these changes before enabling the app feature:

- Add a student-level `whatsapp_reachability` value with `reachable`, `not_reachable`, `not_verified`; default existing rows to `not_verified`. Return it as `whatsappReachability` on `GET /alumni/daily-outreach` and `GET /alumni/daily-outreach/history`. History rows must return the **current** student WhatsApp number and status, including repeated outreach records.
- Add admin-only `PATCH /alumni/daily-outreach/students/:studentId/contact` accepting `whatsappNumber` and/or `whatsappReachability`. Resolve `studentId` only as numeric `students.id`. Validate the number (10–15 digits after stripping display punctuation), reject empty updates and invalid status values, and use a database transaction.
- On a changed number, update the student's canonical WhatsApp field, force status to `not_verified`, and insert an audit row containing numeric student id, previous number, new number, UTC modification time, and authenticated admin id. A status-only update does not create a number-change entry. Return the saved contact. Do not accept an admin id from the client.
- Add an admin-only history endpoint, suggested `GET /alumni/daily-outreach/students/:studentId/contact-changes`, ordered newest first, returning the old/new numbers, timestamp and administrator name. Preserve the audit rows even if outreach history is pruned.
- Ensure all existing outreach send paths, including the WhatsApp gateway, read the canonical updated number. Keep reachability manual; a send attempt or gateway acceptance must not silently set `reachable`.

The app sends only changed fields. The server must enforce admin authorization, validation, the audit transaction, and the automatic status reset; UI checks are supplementary.
