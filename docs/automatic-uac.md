# Automatic UAC Elevation

The script automatically checks whether it is running with administrator privileges.

If it is not elevated, it requests administrator access through the normal Windows UAC dialog and then starts itself again with the original options preserved.

You can therefore run the script normally:

```powershell
powershell -ExecutionPolicy Bypass -File .\edge_disable_global_media_controls.ps1 -RestartEdge
```

Windows will display the standard UAC confirmation dialog when elevation is required.

Supported options are preserved during elevation:

```text
-Undo
-RestartEdge
-DisableRestartApps
```

The script does not bypass UAC or silently obtain elevated privileges. The user must explicitly approve the Windows UAC prompt.

If the UAC prompt is cancelled, the script stops and reports that administrator permission is required.
