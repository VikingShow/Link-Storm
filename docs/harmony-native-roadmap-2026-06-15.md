# HarmonyOS Native Roadmap

Date: 2026-06-15

## Current state

- `apps/harmony-link-storm/entry` builds successfully with `devecocli build --modules entry`
- `EntryAbility.onNewWant` now re-applies share-capture intents
- `Detail.ets` now exposes attachment and handwriting preview open actions
- `IdeaRepository` now uses native `relationalStore` for ideas, folders, and tags
- Capture draft state now persists through native `relationalStore` with legacy file migration fallback
- Attachment replacement now cleans up old managed files
- Handwriting preview state now persists through the capture draft and uses managed storage
- ZIP backup import now restores managed attachments and handwriting preview files
- Floating ball service now keeps state consistent and records graceful fallback errors
- Audio capture now exposes start, pause, resume, finish, and cancel controls with state recovery
- Audio playback now releases resources on failures and exposes detail-page playback feedback
- Audio recorder resource cleanup and microphone permission request failures are handled explicitly
- Repository result-set cleanup, temp backup cleanup, and managed file cleanup now use explicit guards
- DevEco CLI produces `entry-default-unsigned.hap`; project signing remains intentionally unconfigured
- Repository row parsing now uses explicit fallbacks for malformed RDB rows

## Verified milestone

```text
feat(harmony): improve detail attachment and preview flow
```

```text
feat(harmony): migrate capture draft persistence to relational store
```

```text
feat(harmony): polish managed attachment and handwriting preview flow
```

```text
feat(harmony): restore attachments from backup import
```

```text
feat(harmony): harden floating ball fallback state
```

```text
feat(harmony): harden audio capture state flow
```

```text
feat(harmony): harden audio playback lifecycle
```

```text
feat(harmony): guard audio recorder cleanup
```

```text
feat(harmony): guard repository resource cleanup
```

```text
docs(harmony): document unsigned hap build output
```

```text
feat(harmony): guard repository row parsing
```

Verification:

```text
node C:\Users\SowrJam\workspace\_tools\deveco-cli\dist\cli.js build --modules entry
```

Unsigned HAP output:

```text
apps/harmony-link-storm/entry/build/default/outputs/default/entry-default-unsigned.hap
```

Signing state:

```text
apps/harmony-link-storm/build-profile.json5 has an empty signingConfigs array.
```

Result:

```text
BUILD SUCCESSFUL
```

## Next milestones

1. Prepare real signing profile inputs for physical-device installation
2. Continue splitting remaining draft/file helpers from the main RDB path
3. Validate audio capture and playback on a physical HarmonyOS device
4. Revisit remaining SDK compatibility warnings after feature parity improves

## Git workflow

- Keep each milestone small
- Verify with `devecocli` after each code change
- Commit only the files that belong to the current milestone
