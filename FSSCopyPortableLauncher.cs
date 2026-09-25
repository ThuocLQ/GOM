using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Windows.Forms;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        var folder = AppDomain.CurrentDomain.BaseDirectory;
        var script = Path.Combine(folder, "FSSCopyPortable.ps1");
        if (!File.Exists(script))
        {
            MessageBox.Show(
                "Khong tim thay FSSCopyPortable.ps1. Hay bam chuot phai file ZIP, chon Extract All / Giai nen tat ca, roi chay lai FSSCopyPortable.exe trong thu muc da giai nen.",
                "FSS Copy Portable", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        var info = new ProcessStartInfo
        {
            FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell\\v1.0\\powershell.exe"),
            Arguments = "-NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File \"" + script + "\"",
            WorkingDirectory = folder,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardError = true,
            RedirectStandardOutput = true,
        };

        try
        {
            using (var process = Process.Start(info))
            {
                if (process == null) throw new InvalidOperationException("Khong the khoi chay Windows PowerShell.");
                if (process.WaitForExit(1400) && process.ExitCode != 0)
                {
                    var error = process.StandardError.ReadToEnd();
                    var output = process.StandardOutput.ReadToEnd();
                    var detail = String.IsNullOrWhiteSpace(error) ? output : error;
                    var log = Path.Combine(folder, "FSSCopyPortable_startup_error.log");
                    File.WriteAllText(log, detail, new UTF8Encoding(true));
                    MessageBox.Show(
                        "Tool chua khoi dong duoc. File chi tiet loi da duoc tao: " + log + "\r\n\r\n" +
                        (String.IsNullOrWhiteSpace(detail) ? "Windows PowerShell da thoat ngay khi chay." : detail),
                        "FSS Copy Portable", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                "Khong the chay tool: " + ex.Message + "\r\n\r\nHay kiem tra Windows PowerShell co san tren may.",
                "FSS Copy Portable", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
