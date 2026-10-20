# FTN-Coop · 0.6.0

English · [Deutsch](README.de.md)

An independent, unofficial co-op mod for **Find The Needle Demo** (Windows; Linux installer for Steam Proton).
One host and up to three friends work in the same world. Money, research,
hay, buildings and needles belong to the shared session.

Version **0.6.0** checks Steam's real send result and waits for buffer space instead of losing world updates under load. Guest hay uses the complete native render scheduler with host-controlled simulation; unchanged baseline heights no longer rebuild the entire pile. Every participant must update and restart the demo. Linux/Proton crashes remain unconfirmed resolved.

**Development status: Internet play between different Steam accounts is still
unverified.** Local checks use real demo instances, but do not replace a test
with friends over Steam. Only demo build **25963876 (V66)** is currently
supported. The full game and later game updates require a new compatibility check.

**Download:** [Installer and ZIP on the Releases page](https://github.com/GaleR-Tech/FTN-Coop/releases).
You do not need to work with source code to play.

If you enjoy the mod, you can support its development with a coffee:

<a href="https://buymeacoffee.com/galertech"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me a Coffee – support GaleR Tech" width="217" height="60"></a>

**Terms of use:** The source code is publicly available for inspection, but is
not licensed as open source. Playing the unmodified mod for your own private,
non-commercial use is permitted free of charge. Modifying the mod code, reusing
it in other projects and further distribution require prior written permission,
except as permitted by the [LICENSE](LICENSE) or mandatory law. GitHub platform
rights, particularly viewing and forking, remain unaffected. An
[English translation](LICENSE.en.txt) is available; the German LICENSE takes
precedence in case of discrepancies.

## What do I need?

Every player needs Steam, the free **Find The Needle Demo** and the same FTN-Coop
package. You do not need the Godot editor, programming tools, additional Steam
libraries or PowerShell 7. The package uses the PowerShell included with Windows.
Steam must be running, and the Steam overlay must be available for invitations.

## Choose a language

New in 0.1.2: The setup EXE and the F2 co-op menu are available in **German and
English**. You can select the language in each. Unless you choose a language
manually, a German operating system language selects German; all other operating
system languages select English.
Your F2 menu language preference is saved for later game launches. The demo's own
content continues to use its own language settings.

## Installation

New in 0.1.3: The installer has a dark interface with gold accents. It shows the installed and package versions and selects the matching action. The progress indicator stays indeterminate while files are being processed; completion is only shown after the result is known. The **GitHub project** link opens the source repository in your browser.

The easiest option is **FTN-Coop-0.6.0-Setup.exe**:

1. Close the game and double-click the EXE.
2. Check the automatically detected demo folder, or select it using **Browse…**.
3. Click **Install** / **Update** and wait for the success message.
4. Start the demo normally through Steam and press **F2** to open the co-op menu.

The single EXE contains all mod files and requires no additional download during
installation. It uses existing Windows components (.NET Framework and Windows
PowerShell). The EXE is not digitally signed. To remove the mod, open the same EXE
again and choose **Remove mod**.

The ZIP package also remains available:

1. Close the game and fully extract the ZIP to its own folder.
2. Double-click **Install.cmd**. The installer searches your Steam libraries
   for the installed demo. If it cannot find it, enter the demo folder:
   Steam → Demo → Properties → Installed Files → Browse.
3. Start the demo **normally through Steam**. Do not add test launch options.
4. Press **F2** to open the co-op menu.

The German launcher names **Installieren.cmd** and **Entfernen.cmd** remain
available as aliases for **Install.cmd** and **Remove.cmd**.

Installation adds the mod's own files under `mods/ftn_coop` and an entry in
`override.cfg`. The original EXE/PCK files remain unchanged. Removal takes existing
settings and other mod files into account.

## Linux installation (Ubuntu / Mint)

New in **0.4.0**: download **FTN-Coop-0.6.0-Linux.run** from Releases.
This single file includes the installer and all mod files. It needs **Python 3.8
or later**, with **python3-tk** for the optional graphical window; no pip packages
are required. Close the demo before installing, updating or removing the mod.

1. Install the Windows demo through Steam and enable a Proton compatibility tool
   in the demo's Steam properties. This package does not contain a native Linux game.
2. In a terminal, change to the folder containing the downloaded file and run:

   ```sh
   python3 FTN-Coop-0.6.0-Linux.run
   ```

3. Check the detected demo folder, or select it using **Browse**. Click **Install**
   or **Update**. The same window offers **Remove mod**, language selection, GitHub
   and Buy me a Coffee links. Use your regular user account, without sudo.
4. Start the demo through Steam with Proton, then press **F2**.

If the graphical window is unavailable, use the terminal interface:

```sh
python3 FTN-Coop-0.6.0-Linux.run --cli
```

For a specific folder, use `--install --game-dir "/path/to/Find The Needle Demo"`;
use `--remove` instead of `--install` to uninstall, and `--language en` or
`--language de` to select a language. Steam libraries, additional library paths
and the standard Flatpak Steam folder are searched automatically. Flatpak must
already have access to the selected library.

Updates preserve the existing installation record and refuse to overwrite local
mod edits. Removal restores unchanged original configuration bytes or removes
only this mod's entry from a subsequently edited configuration. Original game
binaries, saves and unrelated mods are kept. The installer downloads nothing.

**Verification limit:** filesystem, package and GUI tests were run on the Windows
development computer. Execution on Ubuntu/Mint, the graphical desktop integration,
Proton gameplay and Windows/Linux multiplayer still require a real Linux test.
All participants must use **0.6.0** and demo build **25963876**. Internet play
between separate Steam accounts remains unverified.

## Play with friends

New in 0.1.4: A missing host response, missing initial world data or a stalled
final synchronization now ends with a clear timeout instead of an endless loading
screen. Steam errors explain closed/full lobbies, account restrictions and repeated
join attempts in both languages. The report preserves the specific error code.

When you join, the F2 menu shows the actual proportion of world data received,
followed by separate world construction and progress synchronization stages.
The percentage describes data reception. The session becomes playable only
after world construction and synchronization are complete.

A successful save displays a confirmation with the time. **Copy error report**
copies a short technical report to your clipboard. It includes the mod and demo
versions, engine version, session status, player count, loading stage and a known
error code. Player names, Steam IDs, paths, session identifiers and save files are
excluded. The report is not sent automatically; you can review it before sharing.

1. The **host** first loads or starts their normal save.
2. F2 → **Create session** → **Invite friends** opens the Steam invitation.
3. Friends start their demo through Steam and accept the invitation. A private
   session supports up to **four players including the host**.
4. Wait for loading to finish while the world is loading. Guest actions become
   available after that. F2 closes the menu and releases the mouse for gameplay.

Guests can use the native building catalog (**B**), research tree (**Tab / T**)
and pause menu (**Escape**). Movement and world actions stop for that player while
a menu is open. Research purchases and building actions are confirmed by the host;
guest save/load controls are disabled. F2 remains available for co-op controls.

Default guest controls: **WASD**, mouse, **Space** to jump, **Shift** to sprint
with native stamina, **left click** to use, **E** to pick up, **Q** to drop,
**F / right click** to throw, **X** to dismantle and **1–0** for the native hotbar.
These actions follow the game's personal input bindings. Purchased standard tools
are shared unlocks: everyone can select and use their own copy immediately.
Dropping or picking up a copy does not take the tool away from another player.
Containers such as buckets remain physical objects. F2 also offers shop purchases,
needle delivery and machine on/off controls.
Purchases require the usual proximity to the shop and enough shared money.
Deliver needles at the appropriate cabinet; machines and buildings must be
within reach.

All participants must use exactly the same mod version and demo build. An incompatible mod version is rejected before world loading. The F2 menu shows your installed version, the version required by the lobby and an **Open mod downloads** button. Everyone should install the same package, then restart the demo; this also applies if the host has an older version. Connections
are designed to use Steam relays; router port forwarding is not part of setup.

## Shared gameplay settings

New in **0.2.0**: F2 → **Shared gameplay settings** lets the host change the rules
for everyone in the session. Guests see the current values with **Set by the host**;
their controls are locked. Host changes are synchronized during play, and joining
guests receive the values before their world is constructed.

The shared values are loose/conveyor object limits and automatic removal,
automatic cleanup and its interval, building-grid snapping, and the host's
automatic-saving switch and interval. Only the host saves the shared world.

Guests' original gameplay values are restored on leave, cancellation or host loss.
Graphics, audio, language and controls remain personal. Changes to personal options
made as a guest are saved when leaving or closing the demo normally; forced
termination may lose those latest personal changes. Temporary host values are not
written into the guest's personal settings file.

## Markers, player status and rejoining

New in **0.3.0**: press **F3** during play to mark the surface under your
crosshair, up to 50 meters away. In F2, choose **Point**, **Build here**,
**Needle here** or **Help**. Each player has one marker, which lasts 20 seconds;
placing another replaces it. Markers, player names and avatars use matching
player colors. F3 does not place markers while a menu, text input or world
loading is active.

The F2 player list shows loading/synchronization/play status and measured
round-trip delay in milliseconds. A missing measurement is shown as unavailable;
the local host is labeled **Host**. Measurements include game processing time.

After an unexpected disconnect, **Rejoin last session** offers a fresh join once
the old guest world has closed. The host must still have the same session open.
Voluntary leaving forgets that target, as does closing the demo. Rejoining loads
the host's current world and does not guarantee your previous position.

## Gameplay presets and update checking

The host can save, apply and delete named presets under F2 → **Shared gameplay
settings**. Up to 20 presets store only the nine shared gameplay values, locally
on that computer. Applying a preset updates all guests; personal graphics,
audio and controls remain individual.

**Check for updates** contacts the public GitHub Releases service only when you
click it. It offers the project's download page when a newer normal release is
available. It does not download or install anything. Checks are limited to once
per minute; an offline/rate-limit error leaves play available. No player name,
Steam ID, lobby identifier, local path, report or save data is included.

Version 0.6.0 is published as a normal GitHub release. Internet play between
separate Steam accounts remains unverified.

## Save and leave

The shared progress is stored **by the host**. The host can save in the F2 menu;
ending the host session also saves progress. Before the mod saves, an existing
slot is backed up as `.ftn-coop-last-good`. Write failures are reported, and the
last valid save is restored.

Guests load a temporary world under `user://ftn_coop/sessions/`. Their own
single-player saves are not used as co-op saves. **Leave session** returns to the
main menu and removes that guest's temporary session directory. Canceling while
loading may wait until the native loading process has safely completed and the
temporary world has been closed. A new invitation can then be accepted. When the
host leaves, the session ends for everyone; there is no host migration.

## Remove or update

Close the game and choose **Remove mod** in the setup EXE, or run **Remove.cmd**
from the ZIP. Locally modified mod files are retained as a precaution, and later
configuration changes made by other software remain intact. Save files are not
deleted. To update, use **Install** / **Update** in the new EXE or **Install.cmd**
from the new ZIP package. Back up locally modified mod files first; otherwise,
the update refuses to overwrite them.

If you receive an error, first close the game and check that you selected the
demo folder. “Unsupported version” means that the installed game build has not
yet been approved for the mod. After a game update, remove the mod and wait for
a verified version.

## Known limitations and test status

- Custom player characters and the guest display of loose resources are simplified.
- Four real demo instances on this computer passed shared world synchronization,
  including conveyor construction, needle delivery, tools, cancel/rejoin and
  save/reload. Local test suites also cover session behavior, world
  synchronization, saving and installation.
- Native guest building/research/pause menus are integrated; other special
  functions and decorative effects still need testing with friends.
- Mixed Windows/Linux joining has been reported, together with Linux host crashes.
  The Proton crash cause is still unconfirmed; 0.6.0 does not establish a crash fix.
- If guest movement is blocked immediately after joining, switching away with
  Alt+Tab and back has helped in a reported session. An automatic focus fix is unverified.
- The demo disables its leaderboards when mods are loaded.
- Invitations, Steam data transfer over the Internet and four separate accounts
  remain unverified. The steps are in the
  [playtest checklist](docs/playtest-checklist.en.md).

Source code: `mods/ftn_coop/`. Full terms: [LICENSE](LICENSE), with an
[English translation](LICENSE.en.txt). Notices concerning the game and other
rights holders: [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt).
