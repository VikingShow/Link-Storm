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
- Detail and handwriting capture controls now use readable Chinese labels instead of mojibake placeholders
- Detail placeholders and floating-ball status feedback now use readable Chinese copy
- Repository fallback titles and import/export errors now use localized Chinese messages
- Home-page audio and handwriting status text now reflects the implemented native capture flow
- Audio recording, playback, and floating-ball service errors now surface localized Chinese messages
- Screenshot fallback and handwriting preview saves now guard cleanup failures
- Audio playback start and file-handle cleanup now have explicit error guards
- Handwriting preview save failures now surface directly in the capture panel
- Repository schema setup and import table replacement now use localized guarded RDB helpers
- Repository list and detail reads now use localized guarded RDB queries
- Repository idea, tag, and folder writes now use localized guarded RDB helpers
- Capture draft RDB save and load paths now use localized guarded repository helpers
- Repository initialization failures now surface as localized startup status feedback
- Page navigation now uses `UIContext.Router` instead of deprecated global router calls
- Document capture now auto-saves body edits into the native capture draft and shows word/line stats
- Repository import, backup, attachment copy, and RDB cursor reads now use localized guarded helpers
- Screenshot fallback and handwriting preview now use `UIContext` component snapshots and `ImagePacker.packToData`
- Selected or filtered ideas can now be shared/exported as plain text or Markdown through the native share sheet
- Selected or filtered ideas can now be saved as TXT or Markdown files through the native document picker
- Folder and tag management now supports named create/rename flows, and deleting a tag removes it from existing ideas
- Renaming a tag now synchronizes the tag name across existing ideas without creating duplicates

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

```text
fix(harmony): polish visible capture labels
```

```text
fix(harmony): localize detail status feedback
```

```text
fix(harmony): localize repository fallback messages
```

```text
fix(harmony): align home capture status copy
```

```text
fix(harmony): localize native service errors
```

```text
feat(harmony): guard capture preview cleanup
```

```text
feat(harmony): guard audio playback start
```

```text
feat(harmony): report handwriting preview failures
```

```text
feat(harmony): guard repository schema writes
```

```text
feat(harmony): guard repository read queries
```

```text
feat(harmony): guard repository write helpers
```

```text
feat(harmony): guard capture draft rdb access
```

```text
feat(harmony): report repository init failures
```

```text
feat(harmony): migrate page navigation to ui context router
```

```text
feat(harmony): autosave document capture body
```

```text
feat(harmony): guard repository file operations
```

```text
feat(harmony): modernize capture snapshot encoding
```

```text
feat(harmony): share ideas as markdown
```

```text
feat(harmony): export ideas as text files
```

```text
feat(harmony): manage named folders and tags
```

```text
feat(harmony): sync renamed idea tags
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

Remaining build warnings:

```text
AudioRecordService uses microphone recording APIs; module.json5 already declares ohos.permission.MICROPHONE.
Project signing remains intentionally unconfigured.
```

## Next milestones

1. Prepare real signing profile inputs for physical-device installation
2. Continue scanning for remaining visible text and status feedback gaps on device
3. Continue splitting remaining draft/file helpers from the main RDB path
4. Validate audio capture and playback on a physical HarmonyOS device
5. Confirm whether the microphone static warning can be suppressed beyond the existing permission declaration

## Git workflow

- Keep each milestone small
- Verify with `devecocli` after each code change
- Commit only the files that belong to the current milestone
