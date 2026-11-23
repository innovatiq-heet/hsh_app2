# Prompt: removed tags still listed — backend (`HAMS_WEB`)

> Paste everything below the line into the backend chat (repo `HAMS_WEB`).

---

**Bug:** after a tag is added to or removed from a student, `GET /students` (and `?all=true` / `?status=`) can still return the old `tags` for up to 30 seconds. The admin app reopens the Assign Tag screen, or counts a tag's members for a broadcast, and still sees the removed student.

**Cause:** `GET /students` (`src/modules/students/students.routes.ts`) caches its result in `memoryCache` under `students:<status>:<leader>` for 30 s, with each student's `tags`. The groups and student-sync routes call `memoryCache.invalidate('students')` after a change, but **none of the tag routes do** (`src/modules/tags/tags.routes.ts`).

**Fix:** call `memoryCache.invalidate('students')` (import it as the groups routes do) after every successful change to `student_tag_assignments` or `student_tags`:

- `POST /tags/student/:student_id` (assign one or several)
- `DELETE /tags/student/:student_id/:tag_id` (remove)
- `POST /tags/assign-all`
- `PUT /tags/:id` (rename or recolour: the name and colour are embedded in each student's `tags`)
- `DELETE /tags/:id` (its assignments go too)
- `POST /tags` only if it also assigns students

Only invalidate after the database change succeeded.

**Also check:** `DELETE /tags/student/:student_id/:tag_id` returns success even when nothing was deleted. Keep that (it's idempotent), but make sure the ids are validated as positive integers like the other routes.

**Test:** an e2e test that gets `/students?all=true`, assigns a tag, gets again and sees it, removes it, gets again within the same second and **no longer** sees it.
