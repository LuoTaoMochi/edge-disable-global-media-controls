# edge-disable-global-media-controls

一键禁用 Microsoft Edge / Chromium 的 **Global Media Controls（全局媒体控制）**。

One-click disabling of Microsoft Edge / Chromium **Global Media Controls**.

Microsoft Edge / Chromium の **Global Media Controls（グローバルメディアコントロール）** をワンクリックで無効化します。

[简体中文](#简体中文) | [日本語](#日本語) | [English](#english)
<p align="center">
  <img src="docs/icon.png" alt="Edge Global Media Controls" width="96">
</p>

---

## 简体中文

### 项目简介

这个项目通过向 Microsoft Edge 的启动命令注入以下 Chromium Feature Flag 来禁用 Global Media Controls：

```text
--disable-features=GlobalMediaControls
```

项目采用 PowerShell 实现，不修改 Edge 浏览器程序文件本身，而是修改 Edge 的常用启动入口，使该参数能够在正常启动 Edge 时被读取。

本项目的实现思路参考了 [MSCMonster/edge-no-rounded-corners](https://github.com/MSCMonster/edge-no-rounded-corners)，并针对 `GlobalMediaControls` 做了独立实现。

### 为什么不能只给 Edge 快捷方式加参数？

Chromium / Edge 的命令行参数是在**浏览器主进程启动时**读取的。如果系统中已经存在一个不带目标参数的 Edge 主进程，之后从快捷方式、协议链接等入口打开 Edge 时，通常只是让已有进程创建新的窗口，而不是重新创建一个带新参数的浏览器主进程。

Edge 的 **Startup Boost** 会提前启动后台进程，因此只修改桌面快捷方式并不能保证参数始终生效。

另外，Windows 的“重新启动应用”功能也可能在登录后自动恢复 Edge。如果恢复出来的实例没有携带这个参数，同样可能导致该 Feature 重新启用。

因此本项目和原项目一样采用两层思路：

1. 修改多个 Edge 启动入口，让正常冷启动能够获得目标参数。
2. 禁用 Edge Startup Boost，避免无参数后台主进程抢先启动。

### 脚本做了什么

`edge_disable_global_media_controls.ps1` 会处理以下入口：

| 启动入口 | 说明 |
|---|---|
| 用户桌面快捷方式 | 从当前用户桌面启动 Edge |
| 公共桌面快捷方式 | 从所有用户共享桌面启动 Edge |
| 任务栏固定快捷方式 | 从任务栏固定的 Edge 图标启动 |
| 用户开始菜单快捷方式 | 从开始菜单/搜索启动 |
| 公共开始菜单快捷方式 | 从公共开始菜单启动 |
| `MicrosoftEdgeAutoLaunch*` | Edge Startup Boost 的相关自启动入口，尽力处理 |
| `MSEdgeHTM` | Windows Edge 文件/URL 关联的启动命令 |
| `microsoft-edge` | `microsoft-edge:` 协议启动命令 |
| `microsoft-edge-holographic` | 存在时处理该 Edge 协议启动命令 |
| Startup Boost 策略 | 设置 `StartupBoostEnabled=0`，阻止无参数预启动进程 |

### 注入的参数

本项目只管理一个 Feature Flag：

```text
--disable-features=GlobalMediaControls
```

脚本不会解析、合并、删除或重写其它 Feature Flag。

例如你的 Edge 原本已经存在：

```text
--enable-features=ExampleFeature
--disable-features=AnotherFeature
```

本项目不会修改 `ExampleFeature` 或 `AnotherFeature`。

### 与 `edge-no-rounded-corners` 的兼容性

本项目专门设计为可以与 [MSCMonster/edge-no-rounded-corners](https://github.com/MSCMonster/edge-no-rounded-corners) 同时使用。

原项目目前使用：

```text
--enable-features=msForceNoRoundedCornerAndMargin
--disable-features=msVisualRejuvRounding
```

本项目使用：

```text
--disable-features=GlobalMediaControls
```

因此最终启动命令可以同时包含：

```text
--enable-features=msForceNoRoundedCornerAndMargin
--disable-features=msVisualRejuvRounding
--disable-features=GlobalMediaControls
```

本项目在清理参数时只匹配自己明确加入的：

```text
--disable-features=GlobalMediaControls
```

不会因为看到 `--disable-features=` 就重新整理整个 Feature 列表，也不会删除 `msVisualRejuvRounding` 等其它项目的参数。

#### 关于 StartupBoostEnabled

两个项目都需要处理 Edge Startup Boost，因为它会影响“第一个浏览器主进程”的命令行参数。

因此两者可能共同使用：

```text
HKLM\SOFTWARE\Policies\Microsoft\Edge
    StartupBoostEnabled = 0
```

这是一个 Edge 全局策略，而不是某个 Feature 专属的设置。

本项目在撤销时会注意这种共享场景：如果检测到圆角项目仍然在使用对应的启动参数，则不会因为撤销本项目而随意破坏共享的 Startup Boost 设置。

> 注意：原项目本身的 `-Undo` 行为仍由原项目维护。本项目无法控制第三方脚本的撤销逻辑。

### 使用方法

建议在**管理员 PowerShell**中执行，以便修改协议关联、公共位置和组策略。

#### 直接从 GitHub 下载并运行

```powershell
irm https://github.com/LuoTaoMochi/edge-disable-global-media-controls/releases/latest/download/edge_disable_global_media_controls.ps1 -OutFile "$env:TEMP\edge_disable_global_media_controls.ps1"
powershell -ExecutionPolicy Bypass -File "$env:TEMP\edge_disable_global_media_controls.ps1" -RestartEdge
```

如果仓库暂时没有 Release，也可以直接下载仓库中的脚本文件后运行。

#### 应用修改

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1
```

只应用修改，不主动重启 Edge。

#### 应用修改并立即重启 Edge

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1 -RestartEdge
```

脚本会尝试正常关闭 Edge，让 Chromium 保存当前会话；等待后台进程结束后，再用带参数的方式启动 Edge，并恢复上一会话。

#### 关闭 Windows“重新启动应用”

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1 -RestartEdge -DisableRestartApps
```

Windows 的“重新启动应用”会影响系统中的所有应用。脚本默认只检测并提示，不会主动关闭它。

只有明确指定 `-DisableRestartApps` 时，脚本才会将：

```text
HKCU\Software\Microsoft\Windows NT\CurrentVersion\Winlogon
    RestartApps = 0
```

写入当前用户配置。

#### 撤销修改

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1 -Undo
```

`-Undo` 会移除本项目自己注入的 `GlobalMediaControls` 参数，并处理本项目设置的 Startup Boost 策略。

它不会删除其它项目的 `--enable-features` / `--disable-features` 参数。

### 参数说明

| 参数 | 作用 |
|---|---|
| 无参数 | 应用修改 |
| `-RestartEdge` | 应用修改后立即重启 Edge |
| `-Undo` | 撤销本项目做出的修改 |
| `-DisableRestartApps` | 同时关闭 Windows“重新启动应用” |

参数可以组合，例如：

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1 -RestartEdge -DisableRestartApps
```

### 权限说明

不同修改所需要的权限不同：

| 项目 | 通常所需权限 |
|---|---|
| 用户桌面快捷方式 | 普通用户权限 |
| 用户开始菜单快捷方式 | 普通用户权限 |
| 用户 Startup Boost 注册表项 | 普通用户权限 |
| 公共桌面/公共开始菜单 | 可能需要管理员权限 |
| `HKCR` 协议关联 | 通常需要管理员权限 |
| `HKLM` Startup Boost 策略 | 管理员权限 |

因此推荐直接使用管理员 PowerShell，可以减少部分“修改失败/权限不足”的情况。

### 幂等性

脚本设计为可以重复运行。

第一次运行时会加入：

```text
--disable-features=GlobalMediaControls
```

再次运行时会先清理本项目自己的旧参数，再写入当前版本的参数，因此不会不断产生：

```text
--disable-features=GlobalMediaControls --disable-features=GlobalMediaControls
```

类似的重复参数。

### Edge 更新后的处理

Edge 大版本更新可能重新生成快捷方式、协议命令或调整启动入口。

如果更新后 Global Media Controls 恢复，可以重新运行脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1 -RestartEdge
```

脚本本身不会修改 Edge 安装目录中的二进制文件，因此不会阻止 Edge 正常更新。

### 注意事项

- 建议运行脚本前关闭 Edge，尤其是在首次安装或执行 `-Undo` 时。
- `-RestartEdge` 会关闭并重新启动 Edge，请先保存其它应用中的未保存内容。
- `StartupBoostEnabled=0` 是 Edge 的全局策略，关闭 Startup Boost 可能使 Edge 冷启动略慢。
- `-DisableRestartApps` 会影响 Windows 中所有应用，而不只是 Edge。
- 某些 Edge 更新可能重新生成快捷方式或协议注册，此时重新运行脚本即可。
- 如果 Microsoft 将来修改 `GlobalMediaControls` 的内部行为或 Feature 名称，本项目可能需要相应更新。
- 本项目不会修改 Edge 浏览器程序文件，也不会注入 DLL 或修改二进制文件。

### 故障排查

#### 参数已经写入，但功能仍然存在

先确认 Edge 是否还有后台进程：

```powershell
Get-Process msedge -ErrorAction SilentlyContinue
```

然后使用：

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1 -RestartEdge
```

脚本会关闭现有 Edge 进程并使用目标参数重新启动。

#### 脚本显示权限不足

请使用“以管理员身份运行”的 PowerShell。

#### Windows 重启后效果恢复

检查是否开启了 Windows“重新启动应用”。也可以使用：

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1 -RestartEdge -DisableRestartApps
```

#### 与其它 Edge 启动参数工具一起使用

推荐先确认两个工具分别管理哪些 Feature。只要其它工具不会主动覆盖整个 Edge 启动命令行，而是保留现有参数，就可以同时存在。

本项目会尽量只处理自己添加的：

```text
--disable-features=GlobalMediaControls
```

---

## 日本語

### 概要

このプロジェクトは Microsoft Edge / Chromium の **Global Media Controls（グローバルメディアコントロール）** を、次の Chromium Feature Flag により無効化します。

```text
--disable-features=GlobalMediaControls
```

Edge の実行ファイルそのものは変更せず、Edge の主要な起動エントリにコマンドライン引数を追加する PowerShell スクリプトです。

実装の考え方は [MSCMonster/edge-no-rounded-corners](https://github.com/MSCMonster/edge-no-rounded-corners) を参考にしています。

### なぜショートカットだけでは不十分なのか

Chromium / Edge がコマンドライン引数を読み取るのは、ブラウザーメインプロセスの起動時です。すでに引数なしの Edge プロセスが存在すると、その後のショートカットやプロトコル起動は既存プロセスに新しいウィンドウを開かせるだけになる場合があります。

Edge の Startup Boost はバックグラウンドプロセスを先行起動するため、ショートカットだけを書き換える方法では確実性がありません。

そのため本プロジェクトでは、起動エントリへのフラグ注入に加えて Startup Boost を無効化します。

### スクリプトが変更するもの

- ユーザー / 共通デスクトップの Edge ショートカット
- タスクバー固定ショートカット
- ユーザー / 共通スタートメニューのショートカット
- `MicrosoftEdgeAutoLaunch*` Startup Boost エントリ
- `MSEdgeHTM` / `microsoft-edge` / `microsoft-edge-holographic` プロトコル関連
- `StartupBoostEnabled=0` ポリシー

### 互換性

本プロジェクトが管理する Feature Flag は以下の一つだけです。

```text
--disable-features=GlobalMediaControls
```

`MSCMonster/edge-no-rounded-corners` が使用する次のフラグは変更しません。

```text
--enable-features=msForceNoRoundedCornerAndMargin
--disable-features=msVisualRejuvRounding
```

そのため、両方を同時に使用できます。

### 使い方

管理者権限の PowerShell で実行してください。

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1 -RestartEdge
```

主なオプション：

- `-RestartEdge`: 適用後に Edge を再起動
- `-Undo`: 本プロジェクトの変更を元に戻す
- `-DisableRestartApps`: Windows の「アプリの再起動」を無効化

### 注意事項

- Startup Boost を無効化すると Edge のコールドスタートが少し遅くなる可能性があります。
- `-DisableRestartApps` は Edge だけでなく Windows 全体のアプリに影響します。
- Edge のアップデート後に設定が戻った場合は、スクリプトを再実行してください。
- 本スクリプトは Edge のバイナリファイルを変更しません。

---

## English

### Overview

This project disables Microsoft Edge / Chromium **Global Media Controls** by applying the following Chromium Feature Flag at Edge startup:

```text
--disable-features=GlobalMediaControls
```

The script does not patch or replace Edge binaries. Instead, it adds the flag to Edge's common startup entry points so that a cold-started browser process can receive the parameter normally.

The implementation approach is based on the same general startup-entry strategy used by [MSCMonster/edge-no-rounded-corners](https://github.com/MSCMonster/edge-no-rounded-corners), but the feature handling is kept completely separate.

### Why modify more than one startup entry?

Chromium reads command-line feature switches when the browser's main process starts. If an Edge process is already running without the desired flag, launching another shortcut or URL may simply open a new window in the existing process instead of starting a new parameterized browser process.

Edge Startup Boost can create such a background process before the user explicitly launches the browser.

For this reason, the script uses two layers:

1. Inject the feature flag into common Edge startup entries.
2. Disable Startup Boost so an unparameterized background process does not take precedence.

Windows also has a system-level **restart apps after sign-in** feature. The script detects this by default and only disables it when `-DisableRestartApps` is explicitly supplied.

### What the script changes

| Startup entry | Purpose |
|---|---|
| User desktop shortcuts | Launch Edge from the user's desktop |
| Common desktop shortcuts | Launch Edge from the shared desktop |
| Taskbar pinned shortcut | Launch Edge from the taskbar |
| User Start Menu shortcuts | Launch Edge from Start/Search |
| Common Start Menu shortcuts | Launch Edge from the shared Start Menu |
| `MicrosoftEdgeAutoLaunch*` | Startup Boost related autorun entries |
| `MSEdgeHTM` | Edge URL/file association command |
| `microsoft-edge` | `microsoft-edge:` protocol command |
| `microsoft-edge-holographic` | Related Edge protocol command when present |
| Startup Boost policy | `StartupBoostEnabled=0` |

### Feature flag isolation

This project manages only:

```text
--disable-features=GlobalMediaControls
```

It does not parse, merge, rewrite, or remove other Feature flags.

For example, an existing command line such as:

```text
--enable-features=ExampleFeature
--disable-features=AnotherFeature
```

is preserved; this project only adds its own standalone flag.

### Compatibility with `edge-no-rounded-corners`

This project is designed to work alongside [MSCMonster/edge-no-rounded-corners](https://github.com/MSCMonster/edge-no-rounded-corners).

The rounded-corner project uses:

```text
--enable-features=msForceNoRoundedCornerAndMargin
--disable-features=msVisualRejuvRounding
```

This project uses:

```text
--disable-features=GlobalMediaControls
```

A combined Edge command line can therefore contain all three:

```text
--enable-features=msForceNoRoundedCornerAndMargin
--disable-features=msVisualRejuvRounding
--disable-features=GlobalMediaControls
```

The scripts intentionally manage different feature names, and this project removes only the exact `GlobalMediaControls` flag that it owns.

### Installation / Usage

Run PowerShell as Administrator.

Apply the changes:

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1
```

Apply and restart Edge:

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1 -RestartEdge
```

Undo this project's changes:

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1 -Undo
```

Also disable Windows restart-apps behavior:

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1 -RestartEdge -DisableRestartApps
```

### Command-line options

| Option | Description |
|---|---|
| none | Apply the configuration |
| `-RestartEdge` | Apply and immediately restart Edge |
| `-Undo` | Remove the changes made by this project |
| `-DisableRestartApps` | Disable Windows restart-apps-after-sign-in behavior |

### Idempotency

The script is designed to be safe to run repeatedly.

Before adding its flag, it removes its own exact existing occurrence so repeated execution does not create duplicate arguments such as:

```text
--disable-features=GlobalMediaControls --disable-features=GlobalMediaControls
```

Other Feature flags are left untouched.

### After Edge updates

Edge updates may recreate shortcuts or modify protocol registrations. If the feature becomes enabled again after an update, simply run the script again:

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1 -RestartEdge
```

The project does not modify Edge binaries, so it does not prevent normal browser updates.

### Troubleshooting

If the flag appears to have been applied but the behavior has not changed, first restart all Edge processes:

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1 -RestartEdge
```

You can also check for running Edge processes with:

```powershell
Get-Process msedge -ErrorAction SilentlyContinue
```

If the script reports permission errors, run PowerShell as Administrator.

If the configuration is lost after a Windows restart, check whether **restart apps after sign-in** is enabled and consider using `-DisableRestartApps`.

### Notes

- Disabling Startup Boost may slightly increase Edge cold-start time.
- `-DisableRestartApps` affects Windows applications globally, not only Edge.
- Some Edge updates may recreate startup entries; re-running the script is safe.
- If Microsoft changes or removes the `GlobalMediaControls` feature name or behavior, the script may require an update.

---

## License

MIT License. See [LICENSE](LICENSE).
