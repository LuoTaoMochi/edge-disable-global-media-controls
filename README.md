# Edge Disable Global Media Controls

一个轻量的 PowerShell 脚本，用于让 Microsoft Edge 启动时使用：

```text
--disable-features=GlobalMediaControls
```

该参数用于禁用 Chromium/Edge 的 **Global Media Controls（全局媒体控制）** 功能。

## 特点

- 自动修改常用 Edge 快捷方式
- 处理 Edge Startup Boost 自启动项
- 处理 Edge 协议关联命令
- 禁用 Edge Startup Boost，避免后台常驻进程绕过启动参数
- 支持一键重启 Edge
- 支持撤销修改
- 支持中文、日文、英文输出
- **兼容 `MSCMonster/edge-no-rounded-corners`**
- 不会修改其它 `--disable-features` 参数

## 使用方法

建议使用**管理员 PowerShell**运行。

### 应用修改

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1
```

### 应用修改并重启 Edge

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1 -RestartEdge
```

### 撤销修改

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1 -Undo
```

### 同时关闭 Windows“重新启动应用”

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1 -RestartEdge -DisableRestartApps
```

## 与 Edge No Rounded Corners 兼容

本项目只管理：

```text
--disable-features=GlobalMediaControls
```

不会解析、合并、删除或重写其它 Feature 参数。因此可以与 [MSCMonster/edge-no-rounded-corners](https://github.com/MSCMonster/edge-no-rounded-corners) 同时使用。

例如最终启动参数可以同时包含：

```text
--enable-features=msForceNoRoundedCornerAndMargin
--disable-features=msVisualRejuvRounding
--disable-features=GlobalMediaControls
```

两个项目共享 Edge 的 `StartupBoostEnabled=0` 策略，因为它们都需要防止 Edge 先创建一个不带启动参数的后台主进程。执行本项目 `-Undo` 时，会检查圆角项目的相关参数是否仍存在；若仍在使用，则保留这个共享策略，不会主动破坏圆角项目。

> 注意：如果之后手动执行圆角项目自己的 `-Undo`，它会按照它自己的逻辑撤销共享的 `StartupBoostEnabled`。两个项目同时使用时，建议不要在另一个项目仍启用的情况下单独撤销原项目的 Startup Boost 设置。

## 注意事项

- 修改系统注册表和 Edge 启动项前建议关闭 Edge。
- 某些 Edge 更新可能重新生成快捷方式或启动项，此时重新运行脚本即可。
- 如果 Edge 已经存在后台进程，建议使用 `-RestartEdge`。
- `-DisableRestartApps` 会修改 Windows 的全局“重新启动应用”设置，请按需使用。

## License

MIT License，详见 [LICENSE](LICENSE)。
