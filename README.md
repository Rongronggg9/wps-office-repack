# WPS Office for Linux Repack

Repack WPS Office for Linux to include `zh_CN` localization and/or prefixing commands.

## PROPRIETARY WARNING

WPS Office is a proprietary software. Use at your own risk.

## Version

### `<numeric_ver>`

Unmodified Chinese version.

### `<numeric_ver>.XA`

Unmodified International version.

### `+mui`

> It brings back `zh_CN` localization to International version.

Localizations (`/opt/kingsoft/wps-office/office6/mui`) and default templates (`/opt/kingsoft/wps-office/templates`) replaced by those from Chinese version.

Localizations from two versions are nearly the same, except for:

1. International version comes without `zh_CN` localization
2. International version comes without these components in its `en_US` localization: help files, EULA, and Privacy Policy. In Chinese version these `en_US` components are available, but untranslated (still in Chinese).

Default templates from two version are completely the same, except for their names:

1. Default templates from International version are named in English
2. Default templates from Chinese version are named in Chinese

### `+prefixed`

All commands are prefixed with `wps` to prevent conflicts (e.g. https://github.com/MisterTea/EternalTerminal/issues/316).

| Original | Prefixed |
|----------|----------|
| `et`     | `wpset`  |
| `wpp`    | `wpswpp` |
| `wps`    | `wps`    |
| `wpspdf` | `wpspdf` |

### `+kdedark`

KDE dark theme workaround applied. If you find some text is not readable and your KDE theme is dark, try this.

## Raw packages

Chinese: [linux.wps.cn](https://linux.wps.cn)  
International: [www.wps.com/office/linux/](https://www.wps.com/office/linux/)

## Fonts

WPS Office for Linux used to be distributed with a set of fonts: [wps-fonts](https://github.com/Rongronggg9/wps-fonts)
