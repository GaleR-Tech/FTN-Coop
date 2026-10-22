# FTN-Coop · Internet play still unverified

English · [Deutsch](playtest-checklist.md)

Version 0.6.3 · Demo build 25963876 · Updated 22 October 2026.
Local tests with real demo processes must be assessed separately from the
Internet verification below. No one has been contacted or invited automatically.

## First, two people

- [ ] Both use the same demo build and mod version. First verify Linux/Proton locally if either uses Linux.
- [ ] An older mod version is refused with installed/required versions and a download link; after both install 0.6.3 and restart, joining can be retried.
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

- [ ] F8 markers from every participant appear with the chosen type and matching name/avatar colors; replacement, expiry and departure removal work.
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
accounts, Internet operation remains unverified even though 0.6.3 uses the normal GitHub release label.

## Linux 0.6.3 verification

- [ ] Run the downloaded Linux installer on Ubuntu or Mint; check both languages and a folder with spaces.
- [ ] Test install, update from an existing version, and removal; verify unchanged saves, other mods and original game files.
- [ ] Start V66 through Steam Proton; verify F2, Steam overlay, invitations and world loading.
- [ ] Test Windows-host/Linux-guest, then Linux-host/Windows-guest, with matching 0.6.3 packages.
- [ ] Record distribution, Python version, Proton version and result. These Linux checks have not yet been completed.

## Guest controls and synchronization in 0.6.3

- [ ] Sprint with Shift until stamina is depleted; release and recover. Try a personal remapping.
- [ ] Open native B / Tab / T / Escape menus; movement stops, purchases debit the host once, and leaving cleans up the session.
- [ ] Buy a standard tool as either host or guest. Both select it immediately; drop, pick up and throw copies without changing the other's hands.
- [ ] Carry separate buckets, turn and move, then drop/throw; ownership and hand position remain correct.
- [ ] Finish a host quest; guest title and progress advance. Watch for repeated UI rebuilds and delayed actions.
- [ ] End hosting while a guest equips a shared tool; save and reload the host and verify the unlock remains.
- [ ] For a Linux host crash, record Proton/distribution versions and capture a local Proton log. Review it for private information before sharing.

## 0.6.3 regression checks

- [ ] Host and guest carry hay simultaneously with separate shovels/forks; drop and throw on each side without moving the other's load.
- [ ] Drop an empty tool; its copy stays on the ground and that player's hands remain empty until a deliberate new selection, including under Internet delay.
- [ ] Select a conveyor in the native guest catalog, choose the first point and observe the length preview, then finish and see the resulting belt.
- [ ] If the native loading screen reappears, record whether host/guest and the local FTN-Coop resynchronization/loading log messages; this issue is still unconfirmed.

- [ ] Immediately after joining and while walking around the pile, close straw detail follows the guest camera without a frozen patch.
- [ ] Right-click a loaded shovel/fork: only the contents leave; the tool stays equipped. Test F and Q separately, including several rapid presses without selecting the tool again.
- [ ] Compare the gate countdown on host and guest after joining and after host pause/resume. Check that the guest's own profile time was not overwritten.
- [ ] During recovery, old in-flight world events must not restart native loading. Copy a failure report and check its recovery cause before sharing.

## 0.6.3 send-buffer and native-render checks

- [ ] Keep the host moving while a guest joins; the guest reaches play without another ordinary loading screen.
- [ ] Repeat with a slow connection or about 500 ms latency; shared purchases and hay changes remain ordered.
- [ ] Compare the pile immediately after joining, after digging and after rejoining; no persistent straw layer remains above removed hay.
- [ ] In a four-player lobby, move all players; a slow guest must not freeze another guest's updates or hide one actor's movement stream.
- [ ] Restart/recreate the host lobby and verify that a fresh invitation works. An old closed lobby may report LOBBY_NOT_FOUND.
- [ ] Repeat on a Linux/Proton host and with separate Steam accounts over the Internet; record failures rather than assuming the local Windows checks establish these platforms.

## 0.6.3: performance, hotbar and tool loads

- [ ] With hidden locked tools, number keys select the displayed hotbar symbol, including belts and arms.
- [ ] Shovel and pitchfork loads show the confirmed count/capacity and Full indication; emptying clears the load. Held straw follows the local tool and released straw returns to the host's world position.
- [ ] Compare action delay and latency with an active factory and many loose strands. A smaller packet is not proof of low Internet latency.
- [ ] With no guest connected, compare arm hay pickup and belt output before/after starting a session, with F2 open/closed. Record power and the native arm fault text; verify that loaded arms retain their hay through delivery while hosting.
- [ ] All guests see conveyor, lift and hay-stair loads moving and disappearing when removed, without extra objects appearing beside the machine. Check again after rebuilding and rejoining.

## 0.6.3: populated worlds, hand-held hay and quests

- [ ] In the affected saved world, compare guest latency and action delay for at least a minute after joining, with the same players and running factory. Compare with a new world. A synthetic traffic benchmark is not an Internet latency result.
- [ ] Carry hay in the normal hand, turn and walk, then throw and drop it. Check hand, shovel, pitchfork and carried props for jumps when host data arrives. Confirm released objects have one authoritative owner and position.
- [ ] Complete the throw-hay quest, join and reconnect, then change worlds. Both guest quest displays must show the host's current lesson without changing shared rewards locally.
