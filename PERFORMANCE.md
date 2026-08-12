# 60fps Performance Standards

This document defines the mandatory patterns for all features in this app.

---

## 1. State Management

**Rule:** Never call `setState` inside gesture callbacks (onLongPressMove, onPointerMove, etc.).

| ❌ Bad | ✅ Good |
|--------|---------|
| `onLongPressMoveUpdate: (d) => setState(() => x = ...)` | Use `GestureThrottle` + `setState` (≤30ms interval) |
| `onChanged: (v) => setState(() => query = v)` | Use `Debouncer` (200ms) + setState |

**Utilities:** `GestureThrottle` (lib/services/performance.dart), `Debouncer` (lib/services/performance.dart)

---

## 2. CustomPaint

**Rule:** Every `CustomPaint` MUST be wrapped in `RepaintBoundary`.

```dart
RepaintBoundary(
  child: CustomPaint(painter: MyPainter(...)),
)
```

**Rule:** `shouldRepaint` MUST compare every field that affects painting.

**Rule:** Expensive resources (gradients, paths, pictures) created inside `paint()` MUST be cached.

```dart
final _skyShader = CachedShader(LinearGradient(...));
// In paint():  paint.shader = _skyShader.shader(rect);
// NOT:          paint.shader = LinearGradient(...).createShader(rect);
```

**Utilities:** `CachedShader`, `PainterCache` (lib/services/performance.dart)

---

## 3. Network Calls

**Rule:** Never fire-and-forget an async save. Use `AsyncSaveQueue` for debounced saves.

```dart
final _saveQueue = AsyncSaveQueue(delay: Duration(seconds: 1), saveFn: _doSave);

// Instead of:   _doSave();  // fire-and-forget
// Use:          _saveQueue.schedule();
```

**Rule:** Parallel independent reads with `Future.wait`.

```dart
// Instead of sequential awaits:
final a = await readA();
final b = await readB();

// Use parallel:
final results = await Future.wait([readA(), readB()]);
```

**Rule:** Add `.timeout()` to every network call with a reasonable limit (10-30s).

---

## 4. Widget Builds

**Rule:** Keep `build()` methods lean. Extract sub-trees into `StatelessWidget` with `const` constructors.

**Rule:** Heavy or frequently-rebuilding widgets MUST be wrapped in `RepaintBoundary`.

| Widget | Why | Action |
|--------|-----|--------|
| `CustomPaint` | Full repaint on every rebuild | `RepaintBoundary` |
| Message list in chat | Rebuilds on each message | `RepaintBoundary` |
| Calendar grid cells | Rebuilds on month/selection change | `RepaintBoundary` |
| FCA item cards | Rebuilds on filter/search change | `RepaintBoundary` |
| PrayerBar | Timer rebuilds every 30s | `RepaintBoundary` |

---

## 5. Auto-Save / Debouncing

**Rule:** Every "save on change" must be debounced with at least 1s delay.

**Rule:** Every "search on type" must be debounced with at least 200ms delay.

---

## 6. Lists

**Rule:** Use `ListView.builder` (not `ListView(children: ...)`) for all dynamic lists.

**Rule:** Add `itemExtent` when all items have the same height to skip layout.

---

## 7. Images

**Rule:** Use `Image.network` with `cacheWidth`/`cacheHeight` to decode at display size.

**Rule:** Add `loadingBuilder` and `errorBuilder` to avoid layout shifts.

---

## 8. New Features Checklist

Every new feature MUST pass this checklist before merging:

- [ ] Does it use `setState` in gesture callbacks? → Use `GestureThrottle`
- [ ] Does it have a CustomPaint? → Wrap in `RepaintBoundary`, cache shaders
- [ ] Does it make network calls? → Add timeout, parallelize, debounce saves
- [ ] Does it have search/filter? → Debounce input
- [ ] Does it auto-save? → Use `AsyncSaveQueue`
- [ ] Does it rebuild frequently? → Add `RepaintBoundary`
- [ ] Does it use lists? → Use `ListView.builder`
- [ ] Does it load images? → Set cacheWidth/cacheHeight

---

## 9. Review Process

1. Run `flutter analyze` — zero issues required
2. Run on physical device (RMX3491, Android 13)
3. Test each interactive gesture feels smooth (no visible jank)
4. Profile with `flutter build apk --release` and verify no frame drops
