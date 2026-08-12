# Edge Disable Global Media Controls

一个轻量的 PowerShell 脚本，用于让 Microsoft Edge 启动时使用：

```text
--disable-features=GlobalMediaControls
```

该参数用于禁用 Chromium/Edge 的 **Global Media Controls（全局媒体控制）** 功能。

## 特点

- 自动修改常用 Edge 快捷方式
- 处理 Edge 的启动项和协议关联
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

不会解析、合并或删除其它 Feature 参数。因此可以与 [MSCMonster/edge-no-rounded-corners](https://github.com/MSCMonster/edge-no-rounded-corners) 同时使用。

例如最终启动参数可以同时包含：

```text
--enable-features=msForceNoRoundedCornerAndMargin
--disable-features=msVisualRejuvRounding
--disable-features=GlobalMediaControls
```

撤销本项目时，也只会移除 `GlobalMediaControls`，不会影响圆角项目的参数。

## 注意事项

- 修改系统注册表和 Edge 启动项前建议关闭 Edge。
- 某些 Edge 更新可能重新生成快捷方式或启动项，此时重新运行脚本即可。
- 如果 Edge 已经存在后台进程，建议使用 `-RestartEdge`。
- `-Undo` 会撤销本脚本设置的 Startup Boost 策略；如果该策略原本由其它工具设置，请先确认后再使用。

## License

MIT License，详见 [LICENSE](LICENSE)。
