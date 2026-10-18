# What's new in Minimo OS

Each version is split into **New features**, **Fixes** and **Optimizations**.
Shown in Settings › Updates. The Spanish file (CHANGELOG.md) is the reference.

## Next version

### New features
- Island: screenshots are shown large, with their real aspect ratio.
- Pet: hunger, boredom and sleepiness alerts in the island (one per need, no bursts) and a switch to turn it off in Settings.
- Settings: "Dynamic Island gestures" section with an illustration for each gesture.
- Island: emoji picker with categories, search and skin tone (one click copies it).
- Settings: "Updates" section with the installed version, a check for new versions and these notes.
- Fluent UI System Icons (Filled) in the shell and the login screen.

### Fixes
- Login screen: the password caret is always visible, also with an empty field.
- Island: a little more space from the top edge.

### Optimizations
- Pet: alerts use a single timer until the next change (no polling) and stop when the pet is off.

## 1.1.0 — 2026-10-16

### New features
- Language: Spanish or English interface, with a selector in Settings.
- Minimo login screen (greetd): transitions, Caps Lock, show password, power buttons with confirmation, session selector and GNOME Keyring unlock.
- Island: pinnable menu items (sliders, shortcuts and custom shortcuts), reorderable in Settings.
- Island: clipboard with history (Super+V), images and pinned items.
- Island: notes, month calendar (click the date) and browser and files buttons.
- Island: swipe down opens Minimo as a pet (food, mood and energy).
- Island: swipe to see system resources (battery, Wi-Fi with network list) and background apps (system tray with its menu).
- Island: notifications with its own server, queue and actions; screenshot alert with a thumbnail.
- Exposé-style window overview with Super+Tab.
- Settings: live wallpaper (video or GIF) that pauses under windows or when idle; delete your own wallpapers.
- Settings: Shortcuts section generated from the real configuration, with search.
- Dark mode and smart hiding for the island.
- Terminal: Minimo greets you in Ghostty; redesigned installer and Helium install.
- One-line installer with curl.

### Fixes
- Power: only one confirmation armed at a time, and the black confirmation state is back.
- Polkit: hyprpolkitagent as a user service (password dialogs are back).
- Live wallpaper: switching A → Remove → B no longer leaves stray processes.
- Settings: long texts in switch rows are no longer covered.
- Notifications: the right one is removed from the queue and duplicate replacements are ignored.
- Tray: relaunching apps with a safe fallback chain and menus with correct mnemonics.
- Spanish and English texts reviewed.

### Optimizations
- Animations pause while idle; the previous wallpaper is released.
- More efficient mouse tracking for the character.
- Deferred, event-driven window refresh (no polling).
- About queries versions only once.
- Surfaces without thin borders or transparency.

## 1.0.0 — 2026-10-11

### New features
- First version: Hyprland with the floating Quickshell island and Minimo, the character.
