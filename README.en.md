# FTN-Coop · 0.1.4

English · [Deutsch](README.de.md)

An independent, unofficial co-op mod for **Find The Needle Demo on Windows**.
One host and up to three friends work in the same world. Money, research,
hay, buildings and needles belong to the shared session.

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

The easiest option is **FTN-Coop-0.1.4-Setup.exe**:

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

The host uses the normal game controls. Guests use **WASD**, the mouse,
**Space** to jump, **left click** for the selected tool, **E** to pick up,
**G** to put down, **R** to throw and **Delete** to dismantle. Guests can select
unlocked tools with **1–8** or in the F2 menu. That menu also provides purchases,
research, building selection, needle delivery and machine on/off controls.
Purchases require the usual proximity to the shop and enough shared money.
Deliver needles at the appropriate cabinet; machines and buildings must be
within reach.

All participants must use exactly the same mod version and demo build. An incompatible mod version is rejected before world loading. The F2 menu shows your installed version, the version required by the lobby and an **Open mod downloads** button. Everyone should install the same package, then restart the demo; this also applies if the host has an older version. Connections
are designed to use Steam relays; router port forwarding is not part of setup.

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
- Guests use the mod's own co-op controls. Not every native special function or
  decorative effect has been tested with friends.
- The demo disables its leaderboards when mods are loaded.
- Invitations, Steam data transfer over the Internet and four separate accounts
  remain unverified. The steps are in the
  [playtest checklist](docs/playtest-checklist.en.md).

Source code: `mods/ftn_coop/`. Full terms: [LICENSE](LICENSE), with an
[English translation](LICENSE.en.txt). Notices concerning the game and other
rights holders: [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt).
