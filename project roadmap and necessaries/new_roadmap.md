# 🗺️ CTRC System New Roadmap (Feature-by-Feature)

**DEVELOPMENT APPROACH:** Every feature must be implemented incrementally. Feature by feature, covering both backend and frontend.

---

## 🚀 Module 3: Map, Location, and Proximity Detection

### Phase 1: Proximity Detection (Backend & Frontend)
**Step 1 (Backend):** Implement MySQL Spatial Query logic. Update the `Location` entity and repository to calculate distances (e.g., using `ST_Distance_Sphere`). Create an endpoint to fetch reports within a 5km radius of a given coordinate.
**Step 2 (Frontend):** Implement Map UI. Allow users to view the map and drop a pin to select a location. Integrate the backend endpoint to fetch and display nearby reports (within 5km) when a location is selected.

---

## 🚀 Module 4: Report Creation and Incident Grouping

### Phase 1: Report Submission and Linking
**Step 1 (Backend):** Create the report submission endpoint. Implement logic to handle normal report creation vs. sub-report creation. Group related reports under an "Incident Group".
**Step 2 (Frontend):** Build the Report Create UI. When a user tries to submit a report, if there are existing incidents within 5km, show a prompt to "Link" the report to the existing incident (making it a sub-report) or create a completely new incident.

---

## 🚀 Module 5: Feed and Aggregation

### Phase 1: Aggregated Newsfeed
**Step 1 (Backend):** Develop the Newsfeed endpoint. All data operations, filtering, aggregations (total vote count, comment count) MUST be handled directly within MySQL (via optimized queries/views) to ensure a database-centric architecture. Return aggregated incident groups.
**Step 2 (Frontend):** Implement the Home Page Feed UI. Display report cards with aggregated statistics (votes, comments). Properly render nested sub-reports under their main incident group.

---

## 🚀 Module 6: Interactions (Voting & Comments)

### Phase 1: Voting System
**Step 1 (Backend):** Implement Upvote/Downvote endpoints. Use MySQL constraints/triggers to ensure votes correctly target specific reports or sub-reports (dual-FK logic).
**Step 2 (Frontend):** Add Upvote/Downvote buttons to the UI (on main reports and sub-reports) and integrate with the backend.

### Phase 2: Commenting System
**Step 1 (Backend):** Implement Comment endpoints. Similar to voting, use DB-level logic (dual-FK) to tie comments to the correct report/sub-report.
**Step 2 (Frontend):** Build the Comment section UI under posts and integrate with the comment endpoints.
