# CLAUDE.md — flymoney

Guidance for Claude Code working in this repo. Read this first, every session.

flymoney is a minimalist expense tracker. **Clean Architecture + MVVM, SwiftUI, iOS 18+, Swift 6.2.**

---

## 1. Read context before doing anything

Planning context lives in an **Obsidian vault**, not in this repo:

```
/Users/jheisecke/Documents/RPGym/Obsidian/flymoney/
├── Roadmap.md                  ← stage tracker + status (start here)
├── Stages/                      ← per-stage scope + acceptance criteria
├── Plans/                       ← detailed implementation plans (Stage N - Plan.md)
└── Reference/
    ├── Architecture.md          ← layer rules, dependency direction
    ├── Coding Standards.md      ← binding Swift/SwiftUI rules
    └── flymoney.html            ← UI design reference (Claude Design export)
```

Also in this repo: `PLAN.md` (root) is the canonical architecture/decisions doc; `Reference/Architecture.md` mirrors it.

**Before implementing a stage:** read its `Stages/Stage N - …md` and `Plans/Stage N - Plan.md`. If no plan file exists yet, do not improvise — ask, or write the plan first and get sign-off.

**After completing work:** update the stage status in `Roadmap.md` and check off acceptance criteria in the stage/plan files.

---

## 2. Architecture — enforce strictly

Dependency rule:

```
Presentation → Domain ← Data
```

- **Domain** imports nothing app-specific: no SwiftUI, no SwiftData, no CoreBluetooth, no AVFoundation, no Foundation-heavy persistence. Pure Swift entities, repository protocols, service protocols, use cases.
- **Data** implements Domain protocols. SwiftData `@Model` types live here only. Maps Model ↔ Domain entity.
- **Presentation** depends only on Domain (use-case protocols). Never imports Data or persistence types.
- **App** is the composition root (`AppAssembly`) — the single place dependencies are wired. **No service locator, no DI framework.**

Folder layout: `App/`, `Domain/{Entities,Repositories,Services,UseCases}/`, `Data/{Persistence,Repositories,Services,Sharing}/`, `Presentation/{Common,Components,Add,History,Titles,Share}/`, `DesignSystem/`.

### Non-negotiable seams (keep these abstract)
- `Money` value type (Int minor units) — domain never sees raw Int/Decimal.
- `BudgetPeriod` enum — only `.calendarMonth` now; don't leak the period into use-case signatures.
- `CurrencyProvider` protocol — locale-detected default, swappable.
- `SharingTransport` protocol — QR+BLE is one impl; transport stays swappable.

### When implementing, verify
- ViewModels are `@Observable @MainActor`, depend on use-case **protocols**, hold no persistence types.
- Use cases depend on repository **protocols**, not concrete repos.
- New cross-layer type? Confirm it sits in the right layer and the dependency arrow still points the right way. If unsure, stop and ask.

---

## 3. Always run these skills

| When | Skill |
|---|---|
| Writing/refactoring/reviewing any Swift or SwiftUI code | `/swift-language-skill`, `/swiftui-skill` |
| Reviewing SwiftUI before considering it done | `/swiftui-pro` |
| Designing/adding a feature, ViewModel, UseCase, repository | `/architecture-skill` |
| Any user-facing string, or accessibility work | `/i18n-skill` |
| Concurrency work or Swift 6 concurrency errors | `/swift-concurrency-expert` |
| Writing tests (always, alongside production code) | `/swift-testing-skill` |
| SwiftData stack / queries / migrations | `/core-data-expert` |
| Build / run / debug on simulator | `/ios-debugger-skill` |

`Reference/Coding Standards.md` is the distilled rule set from the first three — conform to it in every change. Highlights: `Tab` API (not `.tabItem`), Dynamic Type (no fixed font sizes), `@Observable` (never `ObservableObject`), `foregroundStyle`, `clipShape(.rect(cornerRadius:))`, no GCD, no force-unwrap, English strings as localization keys + Spanish in `Localizable.xcstrings`.

Tests use **Swift Testing** (`@Test`/`#expect`), not XCTest.

---

## 4. Boundaries — respect these

- **Stay in scope.** Implement the current stage only. Don't pull work forward from later stages. Out-of-scope finds → flag, don't fix inline.
- **Decisions are locked** (see `PLAN.md` §1 / `Roadmap.md`): iOS 18+, SwiftData, `Money` as Int cents, monthly limits, manual DI, Swift Testing, QR+BLE sharing. Don't silently change these. To revisit, raise it explicitly.
- **No third-party dependencies** without asking first. (Sora font is the one approved bundled asset.)
- **No UIKit** unless a stage plan explicitly allows it (only sanctioned exception: AVFoundation QR scanner in Stage 7, wrapped).
- **Don't scaffold or create source files until the relevant plan is signed off.**
- **Don't edit Obsidian plan content to match shortcuts you took** — update status/checkboxes, but if reality diverges from the plan, surface the divergence.
- iOS **18** is the floor even though `/swiftui-pro` defaults to 26 — avoid 26-only APIs.

---

## 5. Project facts

- Xcode project uses **synced folder groups** (`PBXFileSystemSynchronizedRootGroup`). Files added under `flymoney/` auto-join the target — **no `project.pbxproj` editing needed for sources.**
- Bundle id: `com.jheisecke.flymoney`.
- Set/keep: `IPHONEOS_DEPLOYMENT_TARGET = 18.0`, `SWIFT_VERSION = 6.0`, strict concurrency `complete`.
- Verify builds on iOS 18 simulator before marking a stage done.

---

## 6. Workflow per stage

1. Read `Stages/Stage N` + `Plans/Stage N - Plan.md` + `Coding Standards.md`.
2. Run the required skills (§3) for the work type.
3. Implement within the stage's scope and the architecture boundaries.
4. Write Swift Testing coverage alongside.
5. Build + run on simulator (`/ios-debugger-skill`).
6. Check acceptance criteria; update `Roadmap.md` status.
