using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

class Program {
    static void Extract(string res, string path) {
        using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream(res))
        using (var f = File.Create(path)) s.CopyTo(f);
    }
    static int Main() {
        Console.WriteLine("Dang cai dat cau hinh proxy cho Claude Code, vui long cho...");
        string tmp = Path.Combine(Path.GetTempPath(), "ClaudeProxy_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(tmp);
        try {
            string ps1 = Path.Combine(tmp, "Install-ClaudeProxy.ps1");
            string crt = Path.Combine(tmp, "ca_179.crt");
            Extract("Install-ClaudeProxy.ps1", ps1);
            Extract("ca_179.crt", crt);
            var psi = new ProcessStartInfo("powershell.exe",
                "-NoProfile -ExecutionPolicy Bypass -File \"" + ps1 + "\" -CertSource \"" + crt + "\"");
            psi.UseShellExecute = false;
            using (var p = Process.Start(psi)) { p.WaitForExit(); return p.ExitCode; }
        } finally {
            try { Directory.Delete(tmp, true); } catch { }
        }
    }
}
