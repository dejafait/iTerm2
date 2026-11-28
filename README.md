# iTerm2 — accessibility fork

This is an independent fork of [the official iTerm2 project](https://github.com/gnachman/iTerm2), a terminal emulator for macOS.

The goal is to add practical accessibility and usability improvements, particularly for **portrait displays** and **monochrome monitors**. This fork is experimental and is not an official iTerm2 release.

## Available now: multi-row bottom tabs

The first custom native feature is a bottom tab bar that wraps onto multiple rows. It makes large collections of tabs easier to read when horizontal space is limited.

- Rows occupy their own space below the terminal instead of covering its contents.
- Choose automatic sizing based on minimum tab width, or a fixed number of tabs per row, such as six.
- The bar is limited to 40% of the window height; additional tabs remain accessible through the overflow menu.
- The feature is disabled by default.

![Native tabs wrapping into three rows](docs/screenshots/multirow-three-rows.png)

Native renderer fixture with sample titles; no personal terminal contents.

### Enable it

1. Open **Settings → Appearance → General** and set **Tab bar location** to **Bottom**.
2. Open **Settings → Advanced**. In the search field inside the Advanced panel, search for **Wrap bottom tabs** and enable **Wrap bottom tabs onto multiple rows**.
3. Search for **Number of tabs per row**:
   - **0** selects automatic sizing (the default).
   - **1–100** sets a fixed count; **6** gives six tabs per row.
4. In automatic mode, adjust **Minimum width of tabs in a wrapping bottom tab bar** if desired (default: 160 points). Fixed columns override this minimum.

The implementation and current testing notes are available in [the draft pull request within this fork](https://github.com/dejafait/iTerm2/pull/1). It is not an upstream submission. Broader manual testing, including dragging, tab groups and fullscreen, is still needed.

## Configurable palette-style tabs

![Palette buttons in three rows](docs/screenshots/palette-three-rows.png)

Native renderer fixture with sample titles and an active-window state; no private terminal content.

The second feature is an opt-in, high-contrast button style for wrapping horizontal tabs on macOS 26 or later (Tahoe renderer). Enable **Settings → Advanced → Palette tab bar style** after enabling wrapping bottom tabs. No default theme is changed.

Appearance can be edited without rebuilding or restarting. Create `tab-style.json` in the application’s Application Support directory: normally `~/Library/Application Support/iTerm2/`, or the explicit suite directory when launched with `-suite` (for example `iterm22-preview`). The file is checked twice per second; valid changes trigger the preferences/layout refresh. Invalid JSON or an unsupported version retains the last valid snapshot.

```json
{
  "version": 1,
  "height": 36,
  "rowGap": 6,
  "columnGap": 6,
  "cornerRadius": 7,
  "horizontalPadding": 8,
  "marginLeft": 6,
  "marginRight": 6,
  "barBackground": "#ffffff",
  "truncation": "middle",
  "indicators": {
    "activity": {
      "enabled": false,
      "position": "right"
    },
    "counter": {
      "enabled": false,
      "position": "right"
    },
    "progress": {
      "enabled": true,
      "position": "outline"
    },
    "status": {
      "enabled": false,
      "position": "right"
    },
    "graphic": {
      "enabled": false,
      "position": "right"
    },
    "pin": {
      "enabled": false,
      "position": "right"
    },
    "close": {
      "enabled": true,
      "position": "left"
    }
  },
  "states": {
    "activeUnselected": {
      "background": "#ffffff",
      "foreground": "#000000",
      "border": "#000000",
      "borderWidth": 2,
      "fontFamily": "",
      "fontSize": 17,
      "fontWeight": "medium",
      "italic": false
    },
    "activeSelected": {
      "background": "#eeeeee",
      "foreground": "#000000",
      "border": "#000000",
      "borderWidth": 2,
      "fontFamily": "",
      "fontSize": 17,
      "fontWeight": "medium",
      "italic": false
    },
    "inactiveUnselected": {
      "background": "#ffffff",
      "foreground": "#000000",
      "border": "#000000",
      "borderWidth": 2,
      "fontFamily": "",
      "fontSize": 17,
      "fontWeight": "medium",
      "italic": false
    },
    "inactiveSelected": {
      "background": "#eeeeee",
      "foreground": "#000000",
      "border": "#000000",
      "borderWidth": 2,
      "fontFamily": "",
      "fontSize": 17,
      "fontWeight": "medium",
      "italic": false
    }
  },
  "paddingTop": 0,
  "paddingBottom": 0,
  "columnGapColor": "#ffffff",
  "marginTopColor": "#ffffff",
  "marginBottomColor": "#ffffff",
  "marginLeftColor": "#ffffff",
  "marginRightColor": "#ffffff"
}
```

- `height` is the actual button height in points (16–240), independent of `rowGap`. Palette geometry excludes the legacy Tahoe container insets: a 36-point button with `rowGap: 6`, `columnGap: 6` and `marginLeft: 6` keeps those exact visible dimensions, including in real windows with nonzero theme insets. Together with `paddingTop` and `paddingBottom` they form row pitch. `columnGap`, `marginLeft`, `marginRight`, `horizontalPadding` and `cornerRadius` control spacing and shape.
- `barBackground` colors the space around buttons; `columnGapColor` and `marginTopColor`, `marginBottomColor`, `marginLeftColor`, `marginRightColor` can override each surrounding region. Colors accept #RRGGBB or #RRGGBBAA.
- The four independent states are selected/unselected × active/inactive window. Each accepts background, foreground, border, borderWidth, fontFamily (PostScript name; empty means system), fontSize, fontWeight (light/regular/medium/semibold/bold/heavy), and italic. The example keeps inactive-window contrast identical and uses a light gray selected background.
- `truncation`: `head` removes the beginning and preserves the suffix; `tail` preserves the beginning; `middle` keeps both ends; `clip` clips without an ellipsis. This applies consistently to the entire title and its existing emoji, without changing the actual tab name.
- Native activity, counter, status, graphic, pin and close decorations support enabled and left/right placement. Progress supports enabled and left/right/outline placement. The title’s own emoji remain part of the title; no emoji are synthesized by this renderer.
- Native profile settings still control terminal text fonts/colors. This file controls tab labels. Small heights intentionally clip oversized text; choose height appropriate to the selected font.

## Synchronized bars on opposite sides

![The same tabs above and below the terminal](docs/screenshots/opposite-bars.png)

Native rendering fixture with sample tabs and placeholder terminal content.

The third feature adds an optional second native navigation bar on the opposite edge. Open **Settings → Advanced**, search **Show tab bars on opposite sides**, and enable it. It is disabled by default and can be toggled without restarting. The stored key remains `ShowTopAndBottomTabBars` for compatibility.

- Top or Bottom in **Appearance → General → Tab bar location** gives top + bottom.
- Left or Right gives left + right. Mixed horizontal/vertical pairs are not offered.
- Both bars select and close the same tabs and follow titles, status and selection. Each reserves its own space. The mirrored bar is navigation-only for dragging: reorder on the primary bar.
- Hidden/flashing bars do not reserve a second strip; very small windows clamp the secondary strip to keep terminal content space.

## Portrait-friendly Settings

The fourth feature makes Settings resizable and readable on narrow portrait displays without scaling down text. Enable **Settings → Advanced → Use a resizable portrait-friendly Settings window**, then close and reopen Settings (the application and terminal sessions keep running). Disabled by default.

![Native Settings content at 800 points](docs/screenshots/portrait-settings-800.png)

Offscreen capture of the real Settings controls at 800 points, using the test app’s default profile. No personal terminal contents are included.

- At widths up to 900 points, controls flow into vertical rows, long labels wrap, and content scrolls vertically. The window supports an 800-point width and can be resized down to 640 points.
- The profile list and its actions move above the profile settings instead of consuming a permanent left column. The toolbar uses icons in narrow mode and returns to its previous presentation when widened.
- The original controls, values, actions and bindings are retained. Widening restores the desktop form geometry. Switching sections preserves the user’s narrow window width instead of forcing a wider window.
- Oversized custom Settings sheets, including smart-selection and trigger editors, become resizable vertical forms. Native macOS file pickers are left to the system.
- This changes Settings, not terminal text, running jobs or profile contents. On narrow screens the initial window is constrained to the available screen area.

## Live monochrome terminal rendering

The fifth feature overrides terminal text colors at rendering time, including ANSI 16/256-color, RGB, dual-mode and faint text. Unlike a theme, programs cannot bypass it by choosing gray text or their own backgrounds. It does not recolor tab bars or window controls.

Open **Settings → Advanced**, search **Monochrome terminal rendering**, and set:

- **0** — original profile colors (default).
- **1** — black text on an opaque white background.
- **2** — white text on an opaque black background.

Changes apply immediately to existing sessions and scrollback, without restarting the app or its jobs. Selection, search results and the cursor use inverted black/white contrast. Fonts, bold and italic remain unchanged. Dimming, faint alpha, background images and transparency cannot wash out terminal text while this mode is active. Turning it off restores the stored profile/application colors; it does not overwrite the palette or terminal cells. Inline images and color-font emoji keep their intrinsic artwork; this is a text-color mode, not a whole-window grayscale filter.

![Profile gray and colored text compared with monochrome text](docs/screenshots/monochrome-terminal.png)

Offscreen native text-color processing fixture with generic sample text; no personal terminal contents.

## What comes next

More accessibility improvements are planned, with particular attention to portrait layouts and readable, high-contrast interfaces on monochrome displays.

Future ideas are not included in the current feature list.

## Trying this fork

This fork currently targets development builds. No packaged public release or Homebrew tap is provided yet.

For the original project's build instructions and general documentation, see:

- [Official iTerm2 README](https://github.com/gnachman/iTerm2/blob/master/README.md)
- [Official documentation](https://iterm2.com/documentation.html)
- [Official downloads](https://iterm2.com/downloads.html) — these contain the official application, without this fork's additions.

## Project structure

`main` preserves the official baseline. Each feature PR targets the preceding feature branch and stays open for public review. `release` contains all features at the top of the stack and is the default branch. There is no personal integration branch.

## Credits and license

All credit for the original iTerm2 application belongs to its authors and contributors. This fork builds on their work and preserves the project's existing license files and notices. See [LICENSE](LICENSE), [COPYING](COPYING), and [README.license](README.license).
