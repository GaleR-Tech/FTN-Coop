# FTN-Coop · Internet play still unverified

English · [Deutsch](playtest-checklist.md)

Version 0.4.0 · Demo build 25963876 · Updated 20 October 2026.
Local tests with real demo processes must be assessed separately from the
Internet verification below. No one has been contacted or invited automatically.

## First, two people

- [ ] Both use the same demo build and mod version. First verify Linux/Proton locally if either uses Linux.
- [ ] An older mod version is refused with installed/required versions and a download link; after both install 0.4.0 and restart, joining can be retried.
- [ ] Both start through Steam with different accounts on different computers
      and Internet connections; the Steam overlay is available.
- [ ] The host loads their own test save, creates a private session and sends an invitation.
- [ ] The guest accepts; the name, status and world appear correctly after loading.
- [ ] Both players' movement is visible; the guest digs, picks up resources and puts them down.
- [ ] Shared money/research, purchases, construction, machine input and needle delivery synchronize.
- [ ] Repeating a delivery attempt does not count the same needle item twice.
- [ ] The guest leaves and rejoins; current progress is present.
- [ ] The guest also cancels once during loading and returns to the menu.
- [ ] The host saves, exits and reloads; progress is retained.
- [ ] The guest's previous single-player save remains unchanged.
- [ ] The host closes the session; the guest receives an understandable message and returns to the menu.
- [ ] An expired invitation and a full lobby show the correct reason in German and English. Copy the error report and check that its error code matches the failure.

## Then, four people

- [ ] F3 markers from every participant appear with the chosen type and matching name/avatar colors; replacement, expiry and departure removal work.
- [ ] The F2 list shows the actual loading/play state and measured round-trip values; menus/text input do not place markers.
- [ ] The host saves a gameplay preset, changes values and reapplies it; all guests follow. Restarting retains the preset, deleting it removes it.
- [ ] After an unexpected guest disconnect, Rejoin last session waits for cleanup and loads the current host world once. Voluntary leaving hides the remembered target.
- [ ] Update checking starts only when requested, reports the published version, and leaves play available with no Internet connection. It never installs an update automatically.
- [ ] Guests begin with different personal gameplay settings. After joining, all nine F2 shared values match the host; guest controls are disabled.
- [ ] The host changes the object limit and cleanup interval in F2; all guests receive the new values without rejoining.
- [ ] Graphics, audio, language and controls remain personal. After normal leave or host loss, each guest's original gameplay values are restored and personal changes are saved.
- [ ] Cancel a join during loading and retry; shared settings apply again and the original personal values remain recoverable.

- [ ] Three guests join through Steam; all four players see the correct participants.
- [ ] Simultaneous work and machine production remain synchronized for several minutes.
- [ ] Two purchases with enough money for only one result in exactly one success.
- [ ] A fifth participant cannot join.
- [ ] A guest's disconnection removes only that guest's character; rejoining works.
- [ ] Check shared save/reload and unchanged guest saves again.

## Record the result

Record the date, demo build, mod version, participant count, Internet connections
and exact steps when an error occurs. Do not copy account credentials or complete
save files into a public report. Until this checklist has been passed with real
accounts, Internet operation remains unverified even though 0.4.0 uses the normal GitHub release label.

## Linux 0.4.0 verification

- [ ] Run the downloaded Linux installer on Ubuntu or Mint; check both languages and a folder with spaces.
- [ ] Test install, update from an existing version, and removal; verify unchanged saves, other mods and original game files.
- [ ] Start V66 through Steam Proton; verify F2, Steam overlay, invitations and world loading.
- [ ] Test Windows-host/Linux-guest, then Linux-host/Windows-guest, with matching 0.4.0 packages.
- [ ] Record distribution, Python version, Proton version and result. These Linux checks have not yet been completed.
