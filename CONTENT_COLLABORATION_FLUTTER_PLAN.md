# Content Collaboration System – Flutter Implementation Plan

## Overview

Implement the full collaboration system in Flutter matching the backend's unified polymorphic design. This includes:

1. A `CollaborationProvider` for API calls & state
2. A `Collaboration` data model
3. An "Invite Collaborator" section in the Create Shorts settings step
4. A dedicated Collaborations screen for managing sent/received invitations with accept/decline + offers UI
5. Collaborator display on shorts in the feed (showing both names for 1 collaborator, "+N others" for more, with a tap-to-expand modal)
6. The collaborative content creation flow linking to an accepted collaboration

Two creation paths: inline (simple `collaborator_ids[]` at upload) and invitation-first (create collab request → wait for acceptance → create content from accepted collab).

---

## Phase 1: Data Models

### 1. Create `lib/models/collaboration.dart`

Classes:

- **`Collaboration`** — maps the `content_collaborations` API response:
  - `id`, `title`, `description`, `contentType`, `contentId`, `challengeId`
  - `initiator` (map/user), `participants` (list of `CollaborationParticipant`)
  - `maxCollaborators`, `status`, `escrowStatus`
  - `acceptedCount`, `pendingCount`, `isReady`, `isExpired`, `timeRemainingHours`
  - `offerExpiresAt`, `createdAt`
  - `factory Collaboration.fromJson(Map<String, dynamic> json)` following the app's flexible response parsing pattern (try `response['data']`, `response['collaboration']`, etc.)

- **`CollaborationParticipant`** — individual participant data:
  - `id`, `user` (map with `id`, `username`, `name`, `image`)
  - `role` (`initiator`/`collaborator`), `status` (`pending`/`accepted`/`declined`)
  - `offerType`, `offerAmount`, `offerGift` (map), `message`, `timeRemainingHours`
  - Factory `fromJson`

- **`CollaboratorInfo`** — lightweight class for displaying in shorts feed:
  - `id`, `username`, `name`, `image`, `role`
  - Factory `fromJson`

---

## Phase 2: Collaboration Provider

### 2. Create `lib/providers/collaboration_provider.dart`

A `ChangeNotifier` that follows the `Shorts.fromPrevious()` pattern for state preservation.

**Constructor:** takes `authToken`

**State fields:**

- `_receivedCollaborations`, `_sentCollaborations`
- `_isLoading`, `_error`

**API methods** (using `http` + `Url.baakhapaaApi` + `Url.baakhapaaAuthHeaders`):

| Method                                                                                                         | HTTP | Endpoint                                              |
| -------------------------------------------------------------------------------------------------------------- | ---- | ----------------------------------------------------- |
| `createCollaboration({title, description, contentType, challengeId, List<Map> collaborators, expiresInHours})` | POST | `/api/collaborations/create`                          |
| `fetchReceived({status, page})`                                                                                | GET  | `/api/collaborations/received?status=X&page=N`        |
| `fetchSent({status, page})`                                                                                    | GET  | `/api/collaborations/sent?status=X&page=N`            |
| `respondToCollaboration(int id, String action)`                                                                | POST | `/api/collaborations/{id}/respond`                    |
| `cancelCollaboration(int id)`                                                                                  | POST | `/api/collaborations/{id}/cancel`                     |
| `searchUsers(String query)`                                                                                    | —    | Reuse `Auth.searchFollowers` + `Auth.searchFollowing` |

All methods follow: make HTTP call → decode → check `success` → update state → `notifyListeners()`

### 3. Register provider in `lib/main.dart` (~line 735, after `AffiliateProvider`)

- Add `ChangeNotifierProxyProvider<Auth, CollaborationProvider>` with `update` passing `auth.token` and preserving previous state
- Add import for the new provider

---

## Phase 3: Collaborator Selection UI

### 4. Create `lib/widgets/collaborator_selector.dart`

A full-screen selector (similar pattern to `CreatorContentSelector` and `AffiliateProductSelector`):

- Debounced search field that calls `Auth.searchFollowers` / `Auth.searchFollowing` to find users
- Display search results as user tiles (avatar, username, name) with tap-to-select
- Each selected user gets an inline offer configuration:
  - Dropdown for `offerType` (points / gift / none)
  - Text field for `offerAmount` if points
  - Product picker if gift
- Max 4 selections (total 5 including initiator)
- Optional `message` field per collaborator
- Returns `List<Map<String, dynamic>>` of selected collaborators with offers on "Done"

### 5. Modify `lib/screens/shorts/create/create_shorts_screen.dart`

- Add state field: `List<Map<String, dynamic>> _selectedCollaborators = []` (~line 50)
- In `_buildSettingsStep` (~line 1935, before the navigation buttons `Row`), add a new **"Invite Collaborators"** section:
  - Label "Invite Collaborators" (styled like "Linked Content" header at line 1772)
  - Sub-text: "Invite other creators to collaborate on this video"
  - Show selected collaborator chips (avatar + username + offer) with delete button, similar to the linked content `Wrap` pattern
  - A `_buildSecondaryButton` labeled "Select Collaborators" / "Change Collaborators" that navigates to the `CollaboratorSelector` screen and sets `_selectedCollaborators` on return
- In `_submitForm()` (~line 1170), add `_selectedCollaborators` to `previewArgs` in both the challenge and regular shorts paths

### 6. Modify `lib/screens/shorts/create/preview_shorts_screen.dart`

- In `_submitShorts()` (~line 190), read `collaborators` from `args` and add `collaborator_ids` to `formData`
- If `args['collaboration_id']` is present (invitation-first flow), add it to `formData` and call the collaborative endpoint instead

### 7. Modify `lib/providers/shorts.dart` `uploadShorts()` (~line 825)

- Add handling for `collaborator_ids` array in the multipart fields (same pattern as `affiliate_product_ids[]`)
- Add handling for `collaboration_id` if present (post to `/shorts/create-collaborative` instead of `/shorts/create`)

---

## Phase 4: Collaborations Management Screen

### 8. Create `lib/screens/collaboration/collaborations_screen.dart`

- Route: `static const routeName = '/collaborations-screen'`
- Two tabs: "Received" and "Sent"
- Each tab shows paginated list from `CollaborationProvider.fetchReceived/fetchSent`
- Each collaboration card shows:
  - Title, initiator/collaborators avatars, content type badge (short/season)
  - Offer details, status badge, time remaining
- **Received tab actions**: Accept / Decline buttons (calls `respondToCollaboration`)
- **Sent tab actions**: Cancel button (calls `cancelCollaboration`) + "Create Content" button if status is `active`
- Pull-to-refresh on each tab

### 9. Create `lib/screens/collaboration/collaboration_detail_screen.dart`

- Shows full details: all participants with status, individual offers, chat/message, timestamps
- Accept/Decline/Cancel actions depending on role and status
- "Create Collaborative Short" button when collaboration is active → navigates to `CreateShortsScreen` with `collaboration_id` pre-set

### 10. Register routes in `lib/main.dart` routes map (~line 920)

- `CollaborationsScreen.routeName: (ctx) => CollaborationsScreen()`
- `CollaborationDetailScreen.routeName: (ctx) => CollaborationDetailScreen()`
- Add imports for both screens

---

## Phase 5: Display Collaborators on Shorts

### 11. Modify `lib/widgets/shorts_detail.dart`

- Add a new optional parameter: `List<dynamic>? collaborators` to `ShortsDetail` constructor
- After the username `InkWell` (~line 267), add collaborator display widget:
  - If `collaborators` is null or empty → show nothing
  - If 1 collaborator (2 total): show `@username & @collaborator` inline text
  - If 2+ collaborators (3+ total): show `@username & N others` with `InkWell` tap handler
- On tap of "+N others", show a `showModalBottomSheet` listing all collaborators:
  - Each row: avatar, `@username`, name, role badge
  - Tapping a collaborator navigates to `CreatorStoryScreen`

### 12. Modify shorts feed screens to pass collaborator data

Where `ShortsDetail` is instantiated, pass `_shorts[index]['collaborators']` as the new parameter:

- `lib/screens/shorts/shorts_screen.dart` (~line 1292)
- `lib/screens/shorts/single_shorts_screen.dart`
- `lib/screens/shorts/challenges_screen.dart`

---

## Phase 6: Navigation Entry Points

### 13. Add collaboration access from the user profile/drawer

- Add a "Collaborations" menu item/button that navigates to `CollaborationsScreen`
- Show a badge count of pending received collaborations (from `CollaborationProvider`)

### 14. FCM notification handling

When a `collaboration_request` notification is received, navigate to `CollaborationsScreen` (update deep link handler if exists)

---

## Decisions

| Decision         | Choice                                                               |
| ---------------- | -------------------------------------------------------------------- |
| Creation flows   | Both: inline picker in Create Shorts AND invitation-first flow       |
| Collab access    | Dedicated Collaborations screen from profile/drawer                  |
| Offer types      | All three: points escrow, gift product, and none                     |
| Provider pattern | `ChangeNotifierProxyProvider<Auth, CollaborationProvider>`           |
| User search      | Reuses `Auth.searchFollowers` / `Auth.searchFollowing`               |
| Display logic    | 1 collab = `@A & @B`; 2+ collabs = `@A & 4 others` with modal on tap |

---

## Verification

- Run `flutter analyze` after each phase
- Test Create Shorts flow: select collaborators → preview → upload → verify `collaborator_ids[]` sent
- Test invitation flow: create → verify API call → check received list → accept → create content
- Test shorts feed display: load shorts with `collaborators` data → verify names/modal
- Build debug APK: `flutter build apk --debug`

---

## File Summary

### New files

| File                                                         | Purpose                                                          |
| ------------------------------------------------------------ | ---------------------------------------------------------------- |
| `lib/models/collaboration.dart`                              | Collaboration, CollaborationParticipant, CollaboratorInfo models |
| `lib/providers/collaboration_provider.dart`                  | API calls, state management for collaborations                   |
| `lib/widgets/collaborator_selector.dart`                     | Full-screen collaborator picker with offer config                |
| `lib/screens/collaboration/collaborations_screen.dart`       | Sent/Received tabs with actions                                  |
| `lib/screens/collaboration/collaboration_detail_screen.dart` | Full detail view + actions                                       |

### Modified files

| File                                                   | Changes                                                    |
| ------------------------------------------------------ | ---------------------------------------------------------- |
| `lib/main.dart`                                        | Register `CollaborationProvider` + routes + imports        |
| `lib/screens/shorts/create/create_shorts_screen.dart`  | Add "Invite Collaborators" section in settings step        |
| `lib/screens/shorts/create/preview_shorts_screen.dart` | Pass `collaborator_ids` / `collaboration_id` in formData   |
| `lib/providers/shorts.dart`                            | Handle `collaborator_ids[]` + `collaboration_id` in upload |
| `lib/widgets/shorts_detail.dart`                       | Display collaborator names with modal for 2+               |
| `lib/screens/shorts/shorts_screen.dart`                | Pass collaborators data to ShortsDetail                    |
| `lib/screens/shorts/single_shorts_screen.dart`         | Pass collaborators data to ShortsDetail                    |
| `lib/screens/shorts/challenges_screen.dart`            | Pass collaborators data to ShortsDetail                    |
