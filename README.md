# WPS Office for Linux Repack

Repack WPS Office for Linux to include `zh_CN` localization and/or prefixing commands.

## PROPRIETARY WARNING

WPS Office is a proprietary software. Use at your own risk.

## Version

### `<numeric_ver>`

Raw Chinese version. Cloud features enabled.

Available localizations:

* `en_US`
* `mn_CN`
* `ru_RU`
* `ug_CN`
* `zh_CN`

### `<numeric_ver>.XA`

Raw International version. Cloud features disabled.

Available localizations:

* `en_US`
* `mn_CN`
* `ru_RU`
* `ug_CN`

### `+mui`

> It brings back `zh_CN` localization to the International version, with cloud features kept disabled.

Localizations (`/opt/kingsoft/wps-office/office6/mui`) and default templates (`/opt/kingsoft/wps-office/templates`) replaced by those from Chinese version. It is necessary to replace them instead of just copying `zh_CN` localization to activate `zh_CN` user interface.

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

### `+fcitx5xwayland`

Fcitx 5 on XWayland workaround applied. If you have set your environment according to [Using Fcitx 5 on Wayland](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland) and Fcitx 5 doesn't work in WPS Office, try this.

## Obsolete version suffixes

<details>

> The corresponding workarounds of these version suffixes are no longer needed in new versions.

### `+kdedark`

KDE dark theme workaround applied. If you find some texts are not readable and your KDE theme is dark, try this.

### `+bold`

Bold font workaround applied. If you find some bold texts messed up, try this.

</details>

## Official website

Chinese: [linux.wps.cn](https://linux.wps.cn)  
International: [www.wps.com/office/linux/](https://www.wps.com/office/linux/)

## Fonts

WPS Office for Linux used to be distributed with a set of fonts: [wps-fonts](https://github.com/Rongronggg9/wps-fonts)
