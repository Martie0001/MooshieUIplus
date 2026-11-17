using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("MooshieUIplus Module Manager")]
[assembly: AssemblyDescription("Windows entry point for the MooshieUIplus module manager")]
[assembly: AssemblyCompany("MooshieUIplus")]
[assembly: AssemblyProduct("MooshieUIplus Module Manager")]
[assembly: AssemblyVersion("0.2.1.0")]
[assembly: AssemblyFileVersion("0.2.1.0")]

internal static class ManagerLauncher
{
    [STAThread]
    private static int Main(string[] args)
    {
        string directory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        string managerScript = Path.Combine(directory, "模組管理器.ps1");
        string installerScript = Path.Combine(directory, "Install-MooshieUIplus.ps1");
        string updaterScript = Path.Combine(directory, "Release-Update.ps1");

        bool ready = File.Exists(managerScript) && File.Exists(installerScript) && File.Exists(updaterScript);
        // Used by package verification; does not open a window or modify files.
        if (args.Length == 1 && args[0] == "--check")
            return ready ? 0 : 2;

        if (!ready)
        {
            MessageBox.Show(
                "找不到模組管理器的必要檔案。請完整解壓縮 B Windows ZIP，不要只複製 EXE。\n\n"
                + "必要檔案：模組管理器.ps1、Install-MooshieUIplus.ps1、Release-Update.ps1",
                "MooshieUIplus 模組管理器", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 2;
        }

        string powershell = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.System),
            @"WindowsPowerShell\v1.0\powershell.exe");
        if (!File.Exists(powershell))
        {
            MessageBox.Show("找不到 Windows PowerShell 5.1，無法啟動模組管理器。",
                "MooshieUIplus 模組管理器", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 3;
        }

        try
        {
            var info = new ProcessStartInfo
            {
                FileName = powershell,
                Arguments = "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File \""
                            + managerScript + "\"",
                WorkingDirectory = directory,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            // Exit immediately so a running manager can update this launcher EXE.
            // The GUI remains alive in the independent PowerShell child process.
            using (Process child = Process.Start(info))
            {
                if (child == null) throw new InvalidOperationException("Windows PowerShell 啟動失敗。");
            }
            return 0;
        }
        catch (Exception ex)
        {
            MessageBox.Show("無法啟動模組管理器：\n" + ex.Message,
                "MooshieUIplus 模組管理器", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 4;
        }
    }
}
