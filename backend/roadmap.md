# CTRC — Project Roadmap
**Crowdsourced Traffic and Road Condition Management System**
CSE-252 Database Management Systems (Sessional) — CUET

Backend: Spring Boot (Java) + **JDBC** (no JPA/Hibernate) + MySQL (Spatial Extensions)
Frontend: Flutter (Riverpod + go_router + Dio + fpdart)

---

## 0. Baseline — What Already Exists (verified, June 28 2026)

Before this roadmap, the repo (`Ctrc-app`, single `main` branch) contains:

**Frontend (`/lib`) — partially done:**
- Clean architecture skeleton: `domain` → `data` → `presentation`
- `UserModel` (matches ER `USER` table)
- Sign-in page, Sign-up page (UI + client-side validation done)
- Riverpod `AuthProvider` / `AuthNotifier` (state management done)
- `go_router` routes: `/sign-in`, `/sign-up`, `/home` (home is a stub)
- Dio datasource **already coded against an assumed backend contract**:
  - `POST /api/auth/login` → expects `{ token, user }`, HTTP 200
  - `POST /api/auth/signup` → expects `{ user }`, HTTP 201, body uses `imageUrl` (camelCase) not `image_url`
  - Base URL hardcoded to `http://192.168.3.105:8089` (will need to change to whoever runs the backend, or `10.0.2.2` for Android emulator / `localhost` for web/desktop)
- **Not implemented on frontend:** `getCurrentUser()`, `updateProfile()`, real `signOut()`/`resetPassword()` (all stubbed/fake)

**Backend (`/backend`) — does not exist yet.** No Java, SQL, `pom.xml`, or config files anywhere in the repo. This roadmap creates it from scratch.

**Locked design artifacts (cannot be changed):**
- ER Diagram: USER, REPORT, LOCATION, COMMENT, VOTE, INCIDENT GROUP, SUB-REPORT
- Relational Mapping: COMMENT and VOTE each have **both** `report_id` and `sub-report_id` as nullable FKs (dual-FK / "exactly one of two" pattern) — must be enforced via CHECK constraint + application logic, not via schema redesign.

---

## 1. Module Breakdown & Ownership

| # | Module | Owner | Backend Stack | Frontend Stack |
|---|--------|-------|---------------|-----------------|
| 1 | Project Setup & Shared Infrastructure | All 3 (joint) | Spring Boot skeleton, JDBC config, DB schema | Already exists, minor adjustments only |
| 2 | User Module (Auth & Profile) | Teammate A | JDBC DAO, REST controller, BCrypt, session/token | Already ~70% done — wire up to real backend |
| 3 | **Location & Grouping Module** | **You** | LOCATION table CRUD, REPORT core CRUD, Incident Group logic, 5km geospatial linking | Map picker, report creation flow, linking prompt UI |
| 4 | Voting & Comment Module | Teammate B | VOTE + COMMENT JDBC DAOs (dual-FK handling), count aggregation | Upvote/downvote buttons, comment threads |
| 5 | Newsfeed & Integration | All 3 (joint, final stage) | Feed assembly query, sorting/prioritization | Feed UI, nested sub-report display, end-to-end testing |

**Git rule for all modules:** Finish a full stage → test it locally → commit with a clear message → push to `main` (or a feature branch + PR if your team prefers that, see Section 4). Do **not** wait until an entire module is 100% done across all stages to push — push after each stage so your teammates can pull working increments.

---

## 2. MODULE 1 — Project Setup & Shared Infrastructure
*(Joint — do this together first, before splitting off into modules 2–4)*

### Stage 1.1 — Database Schema Creation
- Write the full `schema.sql` covering all 7 tables exactly as per the locked ER/relational mapping:
  - `user`, `location`, `report`, `sub_report`, `comment`, `vote`, `incident_group`
- Add `latitude`/`longitude` as `DECIMAL(9,6)` (sufficient precision for GPS coords)
- Add the dual-FK CHECK constraints on `comment` and `vote`:
  ```sql
  ALTER TABLE comment
    ADD CONSTRAINT chk_comment_target
    CHECK ((report_id IS NOT NULL AND sub_report_id IS NULL)
        OR (report_id IS NULL AND sub_report_id IS NOT NULL));

  ALTER TABLE vote
    ADD CONSTRAINT chk_vote_target
    CHECK ((report_id IS NOT NULL AND sub_report_id IS NULL)
        OR (report_id IS NULL AND sub_report_id IS NOT NULL));
  ```
- Add indexes: `report.location_id`, `report.user_id`, `sub_report.report_id`, `vote(user_id, report_id)`, `vote(user_id, sub_report_id)` (for fast duplicate-vote checks)
- Run schema against local MySQL, verify with sample `INSERT`s
- **Commit & push**: `git commit -m "Add full DB schema with dual-FK CHECK constraints"`

### Stage 1.2 — Spring Boot Skeleton + JDBC Config
- `cd backend` → generate Spring Boot project (Spring Initializr): dependencies = `Spring Web`, `JDBC API` (NOT Spring Data JPA), `MySQL Driver`, `Validation`, `Spring Security` (for BCrypt only, not full auth framework unless you want it)
- Folder structure (package by feature, not by layer-only):
  ```
  backend/src/main/java/com/ctrc/
    config/          → DataSourceConfig, CorsConfig
    common/           → ApiResponse wrapper, GlobalExceptionHandler, RowMappers
    user/             → UserController, UserService, UserDao, UserDaoImpl, User (record/POJO)
    location/         → LocationController, LocationService, LocationDao, LocationDaoImpl, Location
    report/           → ReportController, ReportService, ReportDao, ReportDaoImpl, Report
    subreport/        → SubReportController, SubReportService, SubReportDao, SubReportDaoImpl
    incidentgroup/    → IncidentGroupService, IncidentGroupDao
    vote/             → VoteController, VoteService, VoteDao
    comment/          → CommentController, CommentService, CommentDao
  ```
- `application.properties`: DB URL, username, password, `server.port=8089` (must match what frontend already expects)
- Configure `JdbcTemplate` bean (Spring's `JdbcTemplate`, which sits on top of raw JDBC — this is the standard, sanctioned way to use JDBC in Spring Boot without JPA; raw `java.sql.Connection` everywhere would be painful and isn't necessary to avoid JPA)
- Add a `CorsConfig` allowing the Flutter app's origin(s)
- Add a simple `GET /api/health` endpoint, confirm it returns 200 from Postman/curl
- **Commit & push**: `git commit -m "Spring Boot + JdbcTemplate skeleton with package-by-feature structure"`

### Stage 1.3 — Shared Conventions (lock these before anyone writes feature code)
- Agree on a standard JSON response wrapper, e.g.:
  ```json
  { "success": true, "data": { ... }, "message": null }
  { "success": false, "data": null, "message": "error description" }
  ```
- Agree on RowMapper pattern for converting `ResultSet` → Java object per table
- Agree on exception handling: custom `ResourceNotFoundException`, `ValidationException`, `ConflictException` + `@ControllerAdvice` global handler
- Write this convention down in `backend/CONVENTIONS.md` so all 3 of you follow the same pattern
- **Commit & push**: `git commit -m "Add shared API conventions and exception handling"`

---

## 3. MODULE 2 — User Module (Auth & Profile)
*(Teammate A — but documented here since it's the dependency everyone needs)*

### Stage 2.1 — User DAO + Signup
- `UserDao` (interface) + `UserDaoImpl` (JdbcTemplate): `insert`, `findByEmail`, `findById`, `update`
- Password hashing with BCrypt before storing
- `POST /api/auth/signup` — matches existing frontend contract: accepts `name, email, password, confirmPassword, address?, imageUrl?`, returns 201 + `{ user }` (exclude password from response)
- Validate: email uniqueness, password match, basic field validation server-side (don't trust client-side validation alone)
- **Commit & push**

### Stage 2.2 — Login + Session/Token
- `POST /api/auth/login` — matches existing contract: returns `{ token, user }`
- Decide token approach (simple opaque token stored in a `sessions` table, or JWT — your call, but document it since Flutter side needs to attach it to future requests)
- Add an auth filter/interceptor to validate the token on protected endpoints (everything except signup/login)
- **Commit & push**

### Stage 2.3 — Profile Endpoints
- `GET /api/users/me` (wire up frontend's currently-unimplemented `getCurrentUser()`)
- `PUT /api/users/me` (wire up `updateProfile()`)
- `POST /api/auth/logout` if using server-side sessions
- **Commit & push**

---

## 4. MODULE 3 — Location & Grouping Module ⭐ (Your Module)

This is the heart of the "Smart Grouping and Incident Linking" feature from your proposal. Three stages, each independently testable.

### Stage 3.1 — Location & Core Report CRUD
**Backend:**
- `LocationDao`: `insert`, `findById` — locations are created implicitly when a report is created (no separate "create location" user flow)
- `ReportDao`: `insert`, `findById`, `findAll` (for feed later), `update` (for vote counts), `delete`
- `ReportController`:
  - `POST /api/reports` → body: `{ title, description, category, latitude, longitude, address?, city? }` + authenticated user → creates `location` row, then `report` row referencing it
  - `GET /api/reports/{id}` → full report + its location joined
  - `GET /api/reports` → paginated list (used by Newsfeed module later, but build the base query now)
- Use a single SQL transaction for "create location + create report" (both succeed or both fail) — `JdbcTemplate` + `@Transactional` on the service method
- Write RowMapper for `Report` joining `location` so you don't N+1 query

**Frontend:**
- Map picker widget for pinning location (you'll need a maps package — `google_maps_flutter` or `flutter_map`; confirm with team which one, since this is a new dependency to add to `pubspec.yaml`)
- "Create Report" form: title, description, category dropdown, location pin
- `LocationModel`, `ReportModel` (Dart) matching the JSON contract above
- `ReportRemoteDataSource` (Dio) — `createReport()`, `getReport(id)`
- Basic report detail screen showing what was just created (placeholder UI is fine — Newsfeed module will polish this)

**Test before moving on:** Create a report end-to-end from the Flutter UI → confirm row appears correctly in both `location` and `report` tables in MySQL.

- **Commit & push**: `git commit -m "Location & Report core CRUD - Stage 3.1"`

### Stage 3.2 — Root Cause Selection + 5km Proximity Detection
This is the "Smart Proximity Discovery" logic from your blueprint (steps 3–5 of the workflow).

**Backend:**
- Add `root_cause` handling: when creating a report, `category` field doubles as root cause designation if it's one of the defined root-cause categories (Waterlogging, Major Accident, Construction, Broken-down Vehicle), OR add a separate boolean/flag column if your team decided category ≠ root cause designation — **clarify this with your team since it affects the schema interpretation** (the proposal text and your blueprint slightly differ on whether "root cause" is its own field or inferred from category)
- Geospatial query: given a new report's lat/lng, find active main reports within 5km that have a root cause set, ordered by distance
  - MySQL spatial: use `ST_Distance_Sphere(POINT(lng1, lat1), POINT(lng2, lat2))` (returns meters) — filter `< 5000`
  - This requires `longitude`/`latitude` columns or a generated `POINT` column with a spatial index for performance; for now a straightforward `ST_Distance_Sphere` filter in `WHERE` is fine at this project's scale, optimize later if needed
- `GET /api/reports/nearby-root-causes?lat=..&lng=..` → returns candidate parent reports within 5km, sorted nearest-first
- This endpoint is called by the frontend *before* final submission, when no root cause was selected

**Frontend:**
- After Stage 3.1's form: if user leaves root cause empty, call the nearby-root-causes endpoint on submit attempt
- If results returned → show the "Is this related to [incident] X km ahead?" prompt (modal/dialog) with Yes/No
- Wire "No" → proceed as independent main report (calls Stage 3.1's `createReport`)
- Wire "Yes" → defer to Stage 3.3 (creates a sub-report instead)

- **Commit & push**: `git commit -m "5km proximity detection and root cause linking prompt - Stage 3.2"`

### Stage 3.3 — Sub-Report Creation + Incident Group Nesting
**Backend:**
- `SubReportDao`: `insert`, `findByReportId` (get all sub-reports nested under a parent), `findById`
- `dist_from_parent` — calculate using the same `ST_Distance_Sphere` formula from 3.2 at insert time, store it (so feed display doesn't need to recompute)
- `IncidentGroupDao`: when a report is first designated as a root cause AND later receives its first linked sub-report, create an `incident_group` row referencing that `report_id` (per your ER diagram, `incident_group.report_id` is the FK — one group per root-cause report, decide: created lazily on first sub-report, or eagerly at root-cause report creation? **Lazy creation is cleaner** — avoids empty groups cluttering the table)
- `POST /api/sub-reports` → body includes `parent_report_id`, location, description → creates `location` row, then `sub_report` row, then ensures `incident_group` exists for that parent
- `GET /api/reports/{id}/sub-reports` → list all nested sub-reports for a given main report (feed module will use this for the "nested under parent" display)

**Frontend:**
- Wire "Yes" path from Stage 3.2 to call `POST /api/sub-reports` instead of the main report endpoint
- Basic nested display: on a report detail screen, show a "Related reports" section listing its sub-reports (full visual polish happens in the Newsfeed module)

**Test before moving on:** Create a root-cause report, then create a second report nearby without a root cause, confirm the linking prompt fires, confirm "Yes" creates a properly nested `sub_report` row with correct `dist_from_parent`, and an `incident_group` row is created.

- **Commit & push**: `git commit -m "Sub-report creation and incident group nesting - Stage 3.3 - Module 3 complete"`

---

## 5. MODULE 4 — Voting & Comment Module

### Stage 4.1 — Vote DAO + Dual-FK Logic
**Backend:**
- `VoteDao`: `insert`, `findByUserAndTarget` (checks both `report_id` and `sub_report_id` paths), `deleteByUserAndTarget` (for toggling a vote off)
- Application-layer XOR validation (exactly one of `report_id` / `sub_report_id` non-null) before any insert — don't rely on the DB CHECK constraint alone, surface a clean 400 error instead of a raw SQL exception
- `POST /api/votes` → body: `{ targetType: "REPORT" | "SUB_REPORT", targetId, voteType: "UP" | "DOWN" }`
- Prevent duplicate votes: if user already voted on this target, either reject or treat as a toggle/update (decide and document)
- After insert/delete, update the denormalized `upvote_count`/`downvote_count` on the parent `report` or `sub_report` row (since your schema stores these as columns, not computed live — keep them in sync transactionally)

**Frontend:**
- Upvote/downvote buttons on report cards and sub-report cards
- Optimistic UI update + rollback on failure

- **Commit & push**

### Stage 4.2 — Comment DAO + Dual-FK Logic
**Backend:**
- Same dual-FK XOR pattern as votes
- `POST /api/comments` → `{ targetType, targetId, content }`
- `GET /api/reports/{id}/comments`, `GET /api/sub-reports/{id}/comments`

**Frontend:**
- Comment thread UI, separate for report vs sub-report (per your blueprint — threads must not bleed into each other)

- **Commit & push — Module 4 complete**

---

## 6. MODULE 5 — Newsfeed & Final Integration
*(Joint — everyone's pieces come together here)*

### Stage 5.1 — Feed Assembly Query
- `GET /api/feed?lat=&lng=&radius=` → main reports only (sub-reports excluded from top-level feed per your blueprint), each with: vote counts, comment count, nested sub-report count/preview, sorted by a ranking formula combining recency + net votes (downvoted-heavy reports sink, per your proposal's moderation rule)
- This is the first endpoint that touches Modules 2, 3, and 4's tables together — good integration checkpoint

### Stage 5.2 — Frontend Feed Screen
- Replace the `/home` stub with the real newsfeed list
- Expandable cards showing nested sub-reports, vote buttons, comment counts
- Tap-through to detail view (map + full comment thread)

### Stage 5.3 — End-to-End Testing & Bug Fixing
- Full user journey test: signup → login → create root-cause report → second user creates nearby report → gets linked → votes → comments → feed reflects all of it correctly
- Fix issues found
- Final documentation pass

- **Commit & push — Project complete**

---

## 7. Suggested Timeline Mapping (against your proposal's 11-week plan)

| Weeks | Roadmap stage |
|-------|----------------|
| 3–4 (current, per proposal) | Module 1 (all stages) |
| 5 | Module 2 (Stages 2.1–2.3) in parallel with Module 3 Stage 3.1 |
| 6–7 | Module 3 (Stages 3.2–3.3) + Module 4 (both stages) in parallel |
| 8–9 | Module 5 Stages 5.1–5.2 (Frontend per proposal's "Building Flutter Web interface") |
| 10–11 | Module 5 Stage 5.3 — Testing & final docs |

---

## 8. Open Decisions to Confirm With Your Team
These came up while writing this roadmap — resolve them before/during Module 1 so nobody builds against a wrong assumption:

1. **Root cause field**: is it a dedicated column, or inferred from `category`? (Affects Stage 3.2.)
2. **Token strategy**: opaque DB-backed session token, or JWT? (Affects Module 2 and how every other module's controllers check auth.)
3. **Maps SDK**: `google_maps_flutter` (needs API key, billing) vs `flutter_map` (free, OpenStreetMap-based)? Affects your Stage 3.1 frontend work directly.
4. **Vote re-voting behavior**: does clicking downvote after upvote switch it, or does it require removing the upvote first? (Affects Stage 4.1.)