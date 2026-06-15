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
- Deleting an idea now removes managed local attachment and preview files
- Import replacement now cleans up managed attachment files no longer referenced by imported ideas
- Cross-app share capture now accepts sendData/sendMultipleData intents and imports the first local shared file/image into managed idea attachment storage
- ZIP backup export/import temp directories now clean up recursively after compression or extraction
- ZIP backup import now validates backup idea data before restoring attachments and merging
- ZIP backup export now uses a single idea snapshot for manifest data and attachment collection
- Capture and detail editing now use named folder pickers with an explicit no-folder option
- AI organization results now have a native RDB table, import/export support, and editable detail-page placeholders that do not overwrite original ideas
- Detail page now exports the current attachment, handwriting preview PNG, and handwriting strokes JSON through the native document picker
- JSON and ZIP imports now replace ideas, folders, tags, and AI outputs inside one RDB transaction, with failed ZIP imports cleaning newly copied managed attachments
- Home backup export can now immediately share the generated ZIP package through the native ShareKit panel
- Home search now also covers folder names, manual context notes, and saved AI organization output content
- ZIP backup manifests now include source device metadata, and ZIP import shows package counts and source device before applying the import
- Home and detail deletion now let users remove only the record or remove the record together with managed local attachments
- Capture now offers an explicit clipboard read action that fills source links or document text and persists the native capture draft
- ZIP backup export now records attachment SHA-256 hashes, and ZIP import reuses matching managed attachments instead of duplicating files
- Folder management now supports two-level folders with parent-aware capture, filtering, batch move, detail editing, import, and export
- Detail AI preparation now supports separate editable result types for summary, action items, questions, transcription, OCR, and auto tags
- Conservative imports now mark skipped same-ID records as sync conflicts and show sync status on home cards and detail pages

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

```text
feat(harmony): cleanup deleted idea attachments
```

```text
feat(harmony): cleanup replaced import attachments
```

```text
feat(harmony): attach shared files to captured ideas
```

```text
feat(harmony): cleanup backup temp directories
```

```text
feat(harmony): validate backup idea payloads
```

```text
feat(harmony): snapshot backup ideas once
```

```text
feat(harmony): pick named folders in editors
```

```text
feat(harmony): persist editable ai outputs
```

```text
feat(harmony): export detail attachments
```

```text
feat(harmony): transaction-safe import payloads
```

```text
feat(harmony): share backup zip packages
```

```text
feat(harmony): search ai outputs and folders
```

```text
feat(harmony): preview backup zip imports
```

```text
feat(harmony): choose attachment cleanup on delete
```

```text
feat(harmony): capture from clipboard manually
```

```text
feat(harmony): hash backup attachments
```

```text
feat(harmony): support nested folders
```

```text
feat(harmony): edit typed ai preparation outputs
```

```text
feat(harmony): surface import conflict status
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
2. Validate share capture from browser, gallery, file manager, and chat apps on a physical HarmonyOS device
3. Continue scanning for remaining visible text and status feedback gaps on device
4. Continue splitting remaining draft/file helpers from the main RDB path
5. Validate backup export/import on a physical HarmonyOS device with large attachments
6. Validate audio capture and playback on a physical HarmonyOS device
7. Confirm whether the microphone static warning can be suppressed beyond the existing permission declaration

## Git workflow

- Keep each milestone small
- Verify with `devecocli` after each code change
- Commit only the files that belong to the current milestone
