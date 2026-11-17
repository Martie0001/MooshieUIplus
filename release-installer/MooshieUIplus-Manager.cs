using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Windows.Forms;

[assembly: AssemblyTitle("MooshieUIplus Module Manager")]
[assembly: AssemblyDescription("Windows entry point for the MooshieUIplus module manager")]
[assembly: AssemblyCompany("MooshieUIplus")]
[assembly: AssemblyProduct("MooshieUIplus Module Manager")]
[assembly: AssemblyVersion("0.3.3.0")]
[assembly: AssemblyFileVersion("0.3.3.0")]

internal static class ManagerLauncher
{
    private const string Caption = "MooshieUIplus 模組管理器";

    private static void Error(string message)
    {
        MessageBox.Show(message, Caption, MessageBoxButtons.OK, MessageBoxIcon.Error);
    }

    [STAThread]
    private static int Main(string[] args)
    {
        string directory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        string managerScript = Path.Combine(directory, "模組管理器.ps1");
        string installerScript = Path.Combine(directory, "Install-MooshieUIplus.ps1");
        string updaterScript = Path.Combine(directory, "Release-Update.ps1");
        string powershell = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.System),
            @"WindowsPowerShell\v1.0\powershell.exe");

        bool scriptsReady = File.Exists(managerScript) && File.Exists(installerScript) && File.Exists(updaterScript);
        bool ready = scriptsReady && File.Exists(powershell);
        // Package check only: does not create files or attempt to display the UI.
        if (args.Length == 1 && args[0] == "--check")
            return ready ? 0 : 2;

        if (!scriptsReady)
        {
            Error("管理器檔案不完整。請完整解壓縮 B Windows ZIP，不要只複製 EXE。\n\n"
                  + "必須包含：模組管理器.ps1、Install-MooshieUIplus.ps1、Release-Update.ps1");
            return 2;
        }
        if (!File.Exists(powershell))
        {
            Error("找不到 Windows PowerShell 5.1。請確認使用受支援的 Windows 10／11，並由系統管理員檢查 PowerShell 元件。");
            return 3;
        }

        string logDirectory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "MooshieUIplus", "temp");
        string signalPath = "";
        string errorPath = "";
        try
        {
            Directory.CreateDirectory(logDirectory);
            string id = DateTime.Now.ToString("yyyyMMdd-HHmmss-fff") + "-" + Guid.NewGuid().ToString("N").Substring(0, 8);
            signalPath = Path.Combine(logDirectory, "manager-start-" + id + ".ready");
            errorPath = Path.Combine(logDirectory, "manager-start-" + id + ".log");

            var info = new ProcessStartInfo
            {
                FileName = powershell,
                Arguments = "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File \""
                            + managerScript + "\" -StartupSignal \"" + signalPath
                            + "\" -ErrorLog \"" + errorPath + "\"",
                WorkingDirectory = directory,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardError = true
            };
            using (Process child = Process.Start(info))
            {
                if (child == null) throw new InvalidOperationException("Windows PowerShell 啟動失敗。");
                // The child confirms that WPF actually rendered. Exit after confirmation,
                // allowing future manager updates to replace this EXE without a lock.
                for (int i = 0; i < 100; i++)
                {
                    if (File.Exists(signalPath))
                    {
                        try { File.Delete(signalPath); } catch { }
                        return 0;
                    }
                    if (child.HasExited)
                    {
                        string details = child.StandardError.ReadToEnd();
                        if (File.Exists(errorPath))
                            details = File.ReadAllText(errorPath, Encoding.UTF8) + Environment.NewLine + details;
                        if (String.IsNullOrWhiteSpace(details))
                            details = "PowerShell 在介面出現前結束，代碼：" + child.ExitCode;
                        try { File.WriteAllText(errorPath, details, Encoding.UTF8); } catch { }
                        Error("模組管理器未能開啟：\n" + details
                              + "\n\n診斷日誌：" + errorPath
                              + "\n\n請檢查 PowerShell 執行政策與 Windows .NET Framework／WPF。");
                        return 4;
                    }
                    Thread.Sleep(100);
                }
                Error("模組管理器尚未完成視窗啟動（10 秒內未收到 WPF 啟動訊號）。\n"
                      + "請查看是否有延遲出現的視窗，或檢查 Windows PowerShell／WPF 環境。\n"
                      + "診斷日誌（若有錯誤）：" + errorPath);
                return 5;
            }
        }
        catch (Exception ex)
        {
            Error("無法啟動模組管理器：\n" + ex.Message
                  + (errorPath.Length > 0 ? "\n\n診斷日誌：" + errorPath : ""));
            return 4;
        }
    }
}
