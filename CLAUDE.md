# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project overview

SexyLoot is a World of Warcraft addon (pure Lua, no build step) for **World of Warcraft: Forever** (Interface `16001`, Classic-based client, see the sibling repo SexyInterrupter's CLAUDE.md). It replaces the loot window and the group-loot roll frames, shows roll results per player on the item, keeps a group loot feed, and lists the player's recent loot. All frames are positioned and configured through Edit Mode via the embedded EditModeExpanded-1.0 library.

There is no compiler, linter or test suite. Deploy by copying or symlinking this folder as `SexyLoot` into `Interface/AddOns/`, then `/reload`. `/sexyloot test` fills every window with sample data.

## Packaging / CI

- [.github/workflows/release.yml](.github/workflows/release.yml) runs on every push to `master`: bumps the patch number of `## Version:` in [SexyLoot.toc](SexyLoot.toc), commits and tags it (as `github-actions[bot]`, which does not retrigger the workflow), then runs `BigWigsMods/packager@v2` in the same job (tags pushed with `GITHUB_TOKEN` cannot start another workflow, so bump and package must share a job).
- [.pkgmeta](.pkgmeta) packages the folder as `SexyLoot`, uses `CHANGELOG.md` as the changelog and leaves out `CLAUDE.md`, both READMEs and `.github`.
- GitHub releases work out of the box. CurseForge needs `## X-Curse-Project-ID:` in the TOC plus the `CF_API_KEY` secret. WoWInterface needs `## X-WoWI-ID:` plus `WOWI_API_TOKEN`. Without them the packager skips that site.
- Keep the CHANGELOG entry for a release in `CHANGELOG.md` before pushing; the bump commit does not write to it.

## Forever client constraints (learned in SexyInterrupter)

- `## Interface: 120100, 16001` in one unified `.toc`; do not add per-flavor TOCs.
- **No `UIDropDownMenuTemplate`** frames from addons (blocked). Never use `RegisterDropdown`, `type = "select"` dropdown widgets or the native drop-down templates. Use checkboxes, sliders and buttons.
- **`COMBAT_LOG_EVENT_UNFILTERED` registration is blocked** on the beta; this addon does not use it. Loot and roll information comes from `CHAT_MSG_LOOT`, `START_LOOT_ROLL`, `CANCEL_LOOT_ROLL` and the `LOOT_*` events.
- `GetAddOnMetadata` / `C_AddOns.GetAddOnMetadata` are unreliable; do not call them at file-load time.
- XML `<Binding>` elements are rejected; no keybindings.

## Architecture

Load order (see [SexyLoot.toc](SexyLoot.toc)): LibStub, EditModeExpanded-1.0, then `Locale.lua`, `Core.lua`, `RollFrames.lua`, `LootWindow.lua`, `Feed.lua`, `Winner.lua`, `MyLoot.lua`, `EditMode.lua`.

- **Locale.lua** provides `ns.T`. German is the source language: the key is the German text and comes back unchanged on deDE; every other client gets the English table in that file. Use `T["text"]` or `T("text %s", value)` for every user-visible string (Edit Mode labels included) and add the English text to `Locale.lua`. Prefer Blizzard globals (`NEED`, `GREED`, `PASS`, `LOOT`, `ITEM_BIND_ON_PICKUP`) where they exist, they are already localized.
- **Core.lua** defines `ns.defaults`, creates one invisible anchor frame per window (`ns.frames.roll/winner/loot/feed/mine`), and on `ADDON_LOADED` builds `ns.cfg`, calls every module's `Init()`, then `ns.SetupEditMode()`, then `ns.Refresh(key)` for each window. `ns.Apply[key](cfg)` is how a module applies its settings.
- **RollFrames.lua** hides Blizzard's group loot frames (`UIParent:UnregisterEvent("START_LOOT_ROLL")` etc.), builds one row per roll and parses roll chat messages. Patterns are compiled from the `LOOT_ROLL_*` global strings (handles positional `%1$s` formats), so they work in every locale.
- **LootWindow.lua** unregisters `LootFrame` events and draws its own slot list. `GetLootSlotInfo` returns different argument orders on classic vs retail clients; the code detects which.
- **Feed.lua** owns `ns.ParseLoot` (loot chat messages). Self loot is forwarded to `ns.MyLoot:Add`. Roll winners are noted with `Feed:NoteWin` so the following "receives loot" line is not shown twice.
- **Winner.lua** shows the roll winner large mid-screen (`Winner:Display`, called from `RollFrames:Finish` and from the "won" chat branch without a row). Preview is sticky in Edit Mode.
- **MyLoot.lua** stacks by item ID unless `noStack`, shows sell value via `GetItemInfo`.
- **EditMode.lua** registers the five anchors with EME. Every option here must also exist in `ns.defaults` (Core.lua).

## EditModeExpanded rules (from the library source)

- Checkbox `onUnchecked` runs once on load, so **checkboxes default to off**. Name active options negatively ("... ausblenden").
- Slider `onChanged` runs on load only with a saved value, so **defaults live in `ns.defaults`**.
- `RegisterToggleInCombat` requires `RegisterHideable` first.
- Each frame needs a pre-existing table in `SexyLootDB.frames[key]` before `RegisterFrame`.
- The library must be credited (README) as required by its license.

## Edit Mode preview data

`ns.HookEditMode()` (Core.lua) hooks `EditModeManagerFrame:EnterEditMode/ExitEditMode` (same approach as SexyInterrupter) and calls `m:Preview(active)` on every module. Each module shows sample content while editing and removes it afterwards (entries carry a `preview` flag, roll rows are tracked in `previewRows`, the loot window sets `LW.preview`). Preview rows must never match real rolls (`itemID`/`rollID` stay nil). A new window needs a `Preview` function too.

## EME pitfalls (from SexyInterrupter)

- Seed `SexyLootDB.frames[key].x/.y` (BOTTOMLEFT screen coordinates) before `RegisterFrame`; with an empty table the library can `ClearAllPoints()` without a following `SetPoint`, leaving the window invisible even in Edit Mode. `ns.CreateFrames` does this.
- EME re-runs checkbox/slider callbacks per Edit Mode layout using that layout's own table. SexyLoot has no second settings store, so `ns.cfg` always follows the EME state of the active layout. Do not add an AceDB copy without resyncing on `EnterEditMode`.
- Do not call `ClearAllPoints()`/`SetPoint()` on an anchor while it is being dragged.

When adding an option: add the default in `Core.lua`, register it in `EditMode.lua`, read `ns.cfg[key].<opt>` in the module's `ns.Apply[key]`, and document it in the README table.
