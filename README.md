# iTerm2 — accessibility fork

This is an independent fork of [the official iTerm2 project](https://github.com/gnachman/iTerm2), a terminal emulator for macOS.

The goal is to add practical accessibility and usability improvements, particularly for **portrait displays** and **monochrome monitors**. This fork is experimental and is not an official iTerm2 release.

## Available now: multi-row bottom tabs

There is currently **one custom native feature**: a bottom tab bar that wraps onto multiple rows. It makes large collections of tabs easier to read when horizontal space is limited.

- Rows occupy their own space below the terminal instead of covering its contents.
- Choose automatic sizing based on minimum tab width, or a fixed number of tabs per row, such as six.
- The bar is limited to 40% of the window height; additional tabs remain accessible through the overflow menu.
- The feature is disabled by default.

### Enable it

1. Open **Settings → Appearance → General** and set **Tab bar location** to **Bottom**.
2. Open **Settings → Advanced**. In the search field inside the Advanced panel, search for **Wrap bottom tabs** and enable **Wrap bottom tabs onto multiple rows**.
3. Search for **Number of tabs per row**:
   - **0** selects automatic sizing (the default).
   - **1–100** sets a fixed count; **6** gives six tabs per row.
4. In automatic mode, adjust **Minimum width of tabs in a wrapping bottom tab bar** if desired (default: 160 points). Fixed columns override this minimum.

The implementation and current testing notes are available in [the draft pull request within this fork](https://github.com/dejafait/iTerm2/pull/1). It is not an upstream submission. Broader manual testing, including dragging, tab groups and fullscreen, is still needed.

## What comes next

More accessibility improvements are planned, with particular attention to portrait layouts and readable, high-contrast interfaces on monochrome displays.

**A dedicated monochrome mode is not implemented yet.** Future ideas are not included in the current feature list.

## Trying this fork

This fork currently targets development builds. No packaged public release or Homebrew tap is provided yet.

For the original project's build instructions and general documentation, see:

- [Official iTerm2 README](https://github.com/gnachman/iTerm2/blob/master/README.md)
- [Official documentation](https://iterm2.com/documentation.html)
- [Official downloads](https://iterm2.com/downloads.html) — these contain the official application, without this fork's additions.

## Project structure

Feature PRs are stacked: `main` → `feature/multirow-tab-bar` → `feature/palette-tab-style` → `feature/top-and-bottom-tab-bars`. Each README describes the features available at that point. `release` tracks the top of the stack and is the default branch. `main` preserves the official baseline; there is no personal integration branch.

## Credits and license

All credit for the original iTerm2 application belongs to its authors and contributors. This fork builds on their work and preserves the project's existing license files and notices. See [LICENSE](LICENSE), [COPYING](COPYING), and [README.license](README.license).
