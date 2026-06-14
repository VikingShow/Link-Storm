# HarmonyOS Native Roadmap

Date: 2026-06-15

## Current state

- `apps/harmony-link-storm/entry` builds successfully with `devecocli build --modules entry`
- `EntryAbility.onNewWant` now re-applies share-capture intents
- `Detail.ets` now exposes attachment and handwriting preview open actions

## Verified milestone

```text
feat(harmony): improve detail attachment and preview flow
```

Verification:

```text
node C:\Users\SowrJam\workspace\_tools\deveco-cli\dist\cli.js build --modules entry
```

Result:

```text
BUILD SUCCESSFUL
```

## Next milestones

1. Tighten attachment persistence and replacement behavior
2. Finish handwriting preview and saved asset flow
3. Move more of the local storage path toward native HarmonyOS APIs
4. Add export/import handling in the native app
5. Revisit remaining SDK compatibility warnings after feature parity improves

## Git workflow

- Keep each milestone small
- Verify with `devecocli` after each code change
- Commit only the files that belong to the current milestone
