# ClipDeck

### ⬇️ [Download page: theleb.github.io/ClipDeck-Release](https://theleb.github.io/ClipDeck-Release/)

**Save your best gaming moments with one key.** ClipDeck keeps the last 30 seconds of your screen and
sound ready at all times. Press **Alt+F10** and they're saved as a clip. That's it.

## Install

1. Download **`ClipDeck-win-Setup.exe`** from the
   [latest release](https://github.com/TheLeb/ClipDeck-Release/releases/latest) (under "Assets").
2. Run it.
3. Windows will probably show a blue box: **"Windows protected your PC"**. That's SmartScreen being
   careful with apps that aren't signed with a paid certificate. Click **More info**
   (*Weitere Informationen*), then **Run anyway** (*Trotzdem ausführen*).
4. ClipDeck installs in a few seconds (no admin rights needed) and opens. From now on it starts with
   Windows and waits quietly in the tray (the icon next to the clock).

## Use it

| Key | What it does |
|-----|--------------|
| **Alt+F10** | Save the last 30 seconds as a clip (you hear a short sound) |
| **Alt+F9** | Start / stop a normal recording |

- Clips are saved in **Videos\ClipDeck**.
- Click the tray icon to open ClipDeck. On **Clips** you can watch, trim, rename or delete your clips,
  or click **Copy** and paste a clip into Discord with **Ctrl+V**.
- **Settings** lets you change the keys, the clip length (15 s to 2 min), quality, frame rate, sound
  (game sound, microphone) and the color theme.
- Games in **borderless or windowed** mode work best.
- Keep your **graphics driver up to date**. For NVIDIA, driver 610 or newer lets ClipDeck record on the
  graphics card; with an older one it falls back to a slower way.

## Updates

Automatic. ClipDeck checks for new versions in the background and installs them the next time it starts,
or right away with **Settings → About → Restart to update**.

## Uninstall

Windows **Settings → Apps → Installed apps → ClipDeck → Uninstall**. Your clips stay in Videos\ClipDeck.

## Privacy

Everything stays on your PC. ClipDeck uploads nothing, unless you send a clip to Discord yourself. It only
goes online to check for updates.

## Requirements

Windows 10 (version 1903 or newer) or Windows 11, 64-bit, and about 350 MB of disk space.

## Something's wrong?

Send the newest log file from **Settings → About → Logs** to the person who shared ClipDeck with you.

---

ClipDeck uses [FFmpeg](https://ffmpeg.org) for video (GPL license: `ffmpeg\LICENSE.txt` in the install
folder; source code: [FFmpeg n9.0.2](https://github.com/FFmpeg/FFmpeg/tree/n9.0.2), built by
[BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds)).
