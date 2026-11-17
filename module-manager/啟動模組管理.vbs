Option Explicit
Dim fso, shell, managerPath, command
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
managerPath = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "module-manager.ps1")
If Not fso.FileExists(managerPath) Then
    MsgBox "找不到模組管理程式：" & vbCrLf & managerPath, vbExclamation, "MooshieUIplus"
    WScript.Quit 1
End If
' Launch an independent hidden PowerShell host; only the WinForms window is visible.
command = "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File " & Chr(34) & managerPath & Chr(34)
shell.Run command, 0, False
