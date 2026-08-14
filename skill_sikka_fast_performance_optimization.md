# Skill Sikka — Fast Flutter Performance Optimization

## Objective

Optimize Skill Sikka for **speed, responsiveness, smooth scrolling, fast startup, and low unnecessary network/state work**.

The app's APIs appear to respond quickly, so **do not assume the backend/server is the bottleneck**. First investigate frontend/UI performance, state management, duplicate requests, image loading, and unnecessary rebuilds.

## Important Rules

- Do NOT rewrite the application architecture unnecessarily.
- Do NOT change business logic or API contracts unless required for performance.
- Do NOT blindly optimize every file.
- Profile/inspect first, then make targeted changes.
- Keep existing UI/UX and functionality intact.
- Prefer small, measurable changes.
- Avoid adding dependencies unless there is a clear benefit.
- Do not replace working state management just for optimization.
- Do not cache stale user-sensitive data incorrectly.
- Do not remove loading/error states.

---

# 1. Establish a Baseline

Before changing code:

- Run `flutter analyze`.
- Run the existing tests.
- Run the app in **profile mode**.
- Identify the slowest screens/actions.
- Check Flutter DevTools Performance for:
  - UI thread time
  - Raster thread time
  - frame rendering/jank
  - excessive rebuilds
  - memory growth
- Inspect the network/API calls and record:
  - duplicate requests
  - sequential requests that can safely run in parallel
  - requests triggered repeatedly by rebuilds/navigation

Create a short internal summary of the biggest bottlenecks before making major changes.

---

# 2. Highest Priority — Widget Rebuilds

Inspect:

`lib/providers/`
`lib/screens/`
`lib/widgets/`

Look for:

- Large screens watching broad/global providers.
- `setState()` on high-level widgets.
- Providers watched by entire pages when only a small widget needs them.
- Parent rebuilds causing unrelated children to rebuild.
- Missing `const` constructors/widgets where applicable.
- Expensive calculations inside `build()`.
- Creating controllers, objects, lists, or callbacks unnecessarily inside `build()`.
- `FutureBuilder`/`StreamBuilder` recreating expensive futures/streams on every build.
- `ref.watch()`/state listeners used at a scope larger than necessary.

### Target

A state change should rebuild the **smallest possible widget subtree**.

For example:

Bad:

`Chat message -> entire Home/Live screen rebuild`

Better:

`Chat message -> only chat list/message area rebuilds`

---

# 3. Provider Optimization

Inspect every important provider used by:

- Home
- Course listing
- Course details
- Learning/video screens
- Search
- Profile
- Notifications

Look for:

- API calls being triggered from provider initialization repeatedly.
- Providers being recreated unnecessarily.
- Broad provider dependencies.
- Unnecessary `notifyListeners()` calls.
- Large state objects causing unrelated widgets to rebuild.
- Fetching the same data multiple times.
- Missing caching for data that is safe to cache.
- Refresh operations that unnecessarily reload the whole page.

Prefer granular state.

Example:

Instead of one giant Home state:

`HomeProvider -> banner + categories + courses + recommendations + progress`

prefer independently managed state where practical:

`BannerState`
`CategoryState`
`CourseState`
`RecommendationState`
`ProgressState`

Do not split providers excessively if it makes the code more complex without measurable benefit.

---

# 4. API / Service Layer

Inspect:

`lib/services/`

The APIs are reported to be fast, so investigate **how they are called**.

Find:

- Duplicate API calls.
- Calls triggered from `build()`.
- Calls triggered every time a screen opens unnecessarily.
- Sequential independent requests.
- Repeated calls caused by provider/listener changes.
- Missing request deduplication.
- Unnecessary refetching after navigation.
- Large responses when only a small amount of data is required.

Where requests are independent, consider parallel execution.

Example:

```dart
final results = await Future.wait([
  fetchCategories(),
  fetchFeaturedCourses(),
  fetchRecommendations(),
]);
```

Only do this when the requests are genuinely independent and the backend can handle it.

Do not introduce parallelism where one request depends on another.

---

# 5. Screen Startup Performance

Focus especially on the initial screen/home screen.

Avoid doing everything before the first usable frame.

Separate:

### Critical
- Authentication/session state
- Essential user information
- First visible content

### Deferred
- Below-the-fold sections
- Recommendations
- Secondary statistics
- Non-critical animations
- Optional metadata

The user should see a usable screen as quickly as possible.

Use lazy loading where appropriate.

---

# 6. Lists and Scrolling

Inspect course lists, category lists, search results, notifications, etc.

Prefer lazy builders:

```dart
ListView.builder(...)
```

or appropriate sliver builders.

Avoid:

```dart
ListView(
  children: hugeList.map(...).toList(),
)
```

for large/dynamic datasets.

Check for:

- Nested scroll views.
- Excessive `shrinkWrap: true`.
- Large lists rendered all at once.
- Unnecessary `IntrinsicHeight` / `IntrinsicWidth`.
- Expensive layouts inside every list item.
- Unnecessary rebuilds of every list item.

Use pagination/infinite scrolling where the API supports it.

Do not load hundreds of courses if only the first visible batch is needed.

---

# 7. Image Performance

Inspect `assets/` and image usage in:

`lib/widgets/`
`lib/screens/`

Pay particular attention to:

- Course thumbnails.
- Instructor/profile images.
- Banners.
- Large remote images.

Check for:

- Images being downloaded repeatedly.
- Missing image caching.
- Huge source images being displayed as tiny thumbnails.
- Multiple copies of the same image.
- Images being decoded at unnecessarily high resolution.
- Large local assets.

Use appropriate caching and image sizing without changing the visual design.

Do not add an image package if Flutter's existing mechanisms are sufficient.

---

# 8. Expensive Work on the UI Isolate

Search for:

- Large JSON transformations.
- Sorting large collections.
- Filtering large datasets.
- Heavy mapping/conversion.
- Complex data processing.
- Image processing.
- Synchronous loops over large datasets.

Do not perform expensive work during `build()`.

If genuinely CPU-heavy work cannot be optimized algorithmically, consider moving it off the UI isolate.

Do not introduce isolates for trivial work.

---

# 9. Navigation and Lifecycle

Inspect:

`lib/navigation/`

Check whether screens are:

- Recreated unnecessarily.
- Refetching data every time they become visible.
- Losing state unnecessarily.
- Initializing expensive resources repeatedly.
- Keeping unnecessary controllers/listeners alive.

Dispose correctly:

- Animation controllers
- Scroll controllers
- Text controllers
- Stream subscriptions
- Timers
- Listeners

Avoid memory leaks.

---

# 10. Animations and Rendering

Inspect animations throughout the app.

Look for:

- Too many simultaneous animations.
- Infinite animations running when not visible.
- Heavy shadows/blur effects.
- Excessive opacity layers.
- Large animated widgets.
- Expensive effects inside scrolling lists.

Do not remove animations blindly.

Keep the intended UI experience while reducing unnecessary work.

---

# 11. Startup Optimization

Inspect:

`lib/main.dart`

Look for unnecessary work before `runApp()`.

Avoid initializing non-critical services synchronously before the app can render.

Review:

- Firebase initialization
- Local storage initialization
- Authentication checks
- Analytics
- Notification setup
- Configuration loading
- Large local data reads

Critical startup work should remain blocking only when required for correctness.

Defer non-critical initialization until after the first usable frame where appropriate.

---

# 12. Memory

Use DevTools to look for:

- Growing lists that never shrink.
- Cached objects that grow indefinitely.
- Stream subscriptions that aren't disposed.
- Controllers that aren't disposed.
- Duplicate image/data caches.
- Screens/providers remaining alive unnecessarily.

Do not introduce aggressive caching that increases memory significantly.

---

# 13. Backend Check — Only After Frontend Checks

Because API responses appear fast, backend optimization is secondary.

Still verify:

- API response time.
- Payload size.
- Number of requests per screen.
- Duplicate requests.
- Slow individual endpoints.

Do not rewrite backend APIs unless profiling shows that they are actually contributing to the perceived slowness.

---

# 14. Priority Order

Work in this order:

### P0 — Highest impact

1. Excessive widget rebuilds.
2. Duplicate API calls.
3. API calls triggered from `build()`.
4. Large providers causing whole-screen rebuilds.
5. Large lists rendered eagerly.
6. Heavy work inside `build()`.
7. Slow/large image loading.

### P1

8. Sequential independent API calls.
9. Screen lifecycle/refetch problems.
10. Startup initialization.
11. Excessive animations.
12. Memory leaks.

### P2

13. Minor widget optimizations.
14. Minor code cleanup.
15. Micro-optimizations.

Do not spend time on P2 work while P0/P1 issues remain.

---

# 15. Validation After Each Major Change

After optimization:

```bash
flutter analyze
flutter test
```

Then run the app in profile mode again.

Compare:

- Time to first usable screen.
- Screen transition responsiveness.
- Scroll smoothness.
- Frame rendering/jank.
- API request count.
- Duplicate request count.
- Memory usage.
- CPU usage.

The goal is **measurable improvement**, not just cleaner code.

---

# 16. What NOT To Do

Do NOT:

- Rewrite the entire project.
- Replace Riverpod/Provider/BLoC/etc. without evidence.
- Change API contracts unnecessarily.
- Remove features.
- Remove loading/error handling.
- Add random caching everywhere.
- Add dependencies just because they are popular.
- Convert every widget to `const` without understanding rebuild behavior.
- Move everything into isolates.
- Optimize code that isn't on a performance-critical path.
- Claim the app is optimized without profiling.

---

# 17. Deliverables

After the optimization pass, provide:

## Performance Findings

A short list of the actual bottlenecks found.

For each:

- File/path
- Problem
- Why it was slow
- Change made
- Expected/observed impact

## Before vs After

Report, where measurable:

- Startup time
- Number of API calls on key screens
- Duplicate API calls removed
- Frame/jank improvements
- Memory improvements
- Scroll performance

## Changed Files

List every file modified.

## Remaining Issues

Clearly state anything that still needs optimization.

---

# Final Instruction to Codex

**Do not blindly optimize the whole Skill Sikka codebase.**

Start by profiling and tracing the slow user experience:

`Screen → Provider/State → Service → API → Widget rendering`

Since APIs are already reported to be fast, prioritize:

**unnecessary rebuilds → duplicate requests → provider architecture → lists → images → startup → UI rendering.**

Make targeted changes, preserve the existing UI/UX and business logic, and validate every significant change.
