using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Windows.Forms;

// The release launcher compiles the unchanged MemoryBound class extracted from
// Start-MemoryBound.ps1. Players do not need PowerShell, Codex or the Godot editor.
internal static class Launcher {
    internal static string Quote(string value) {
        if (value.Length > 0 && value.IndexOfAny(new char[] {' ', '\t', '\n', '\r', '"'}) < 0)
            return value;
        var result = new StringBuilder("\"");
        int slashes = 0;
        foreach (char c in value) {
            if (c == '\\') { slashes++; continue; }
            if (c == '"') {
                result.Append('\\', slashes * 2 + 1).Append(c);
            } else {
                result.Append('\\', slashes).Append(c);
            }
            slashes = 0;
        }
        return result.Append('\\', slashes * 2).Append('"').ToString();
    }

    internal static string FriendlyError(string message) {
        if (message.Contains("Insufficient launch budget"))
            return "目前可用内存不足，游戏尚未启动。\n请先关闭不需要的程序后重试。启动约需 1.74 GB 可用内存；运行时保留 500 MB 系统余量。";
        if (message.Contains("Another GALUMU"))
            return "已有一份《骑枪与桂冠》或后台测试正在运行。\n请先关闭它，再启动游戏。";
        return "游戏未能正常启动。请确认已完整解压，并有权写入自己的用户文件夹。\n\n" + message;
    }

    internal static string ExitMessage(int code) {
        // 125 is shared by the child's private-memory budget, system RAM
        // reserve and commit reserve. It does not prove other apps caused it.
        return code == 125
            ? "游戏触发内存保护，已停止运行。\n可能是游戏达到用量上限，或系统可用内存不足。请保留下面的记录以便排查。"
            : "游戏意外退出（代码 " + code + "）。\n请保留以下运行记录以便排查。";
    }

    static void RetainRecentLogs(string directory) {
        // Only our own bounded diagnostic files in the per-user log directory.
        var files = new DirectoryInfo(directory).GetFiles("session-*.log*");
        Array.Sort(files, delegate(FileInfo a, FileInfo b) { return b.LastWriteTimeUtc.CompareTo(a.LastWriteTimeUtc); });
        for (int i = 19; i < files.Length; i++) {
            try { files[i].Delete(); } catch (IOException) { } catch (UnauthorizedAccessException) { }
        }
    }

    [STAThread]
    static int Main(string[] args) {
        bool quiet = false, isolated = false, check = false;
        int timeout = 0;
        string log = null;
        var forwarded = new List<string>();
        try {
            // Any diagnostic flag suppresses dialogs even when other QA arguments
            // are malformed; unattended tests must never wait on the user's screen.
            foreach (string arg in args)
                if (arg.StartsWith("--launcher-", StringComparison.Ordinal)) quiet = true;
            foreach (string arg in args) {
                if (arg == "--launcher-isolated") isolated = true;
                else if (arg == "--launcher-check") check = true;
                else if (arg.StartsWith("--launcher-timeout=", StringComparison.Ordinal)) {
                    if (!Int32.TryParse(arg.Substring(19), out timeout) || timeout < 1 || timeout > 600)
                        throw new ArgumentException("QA timeout must be between 1 and 600 seconds.");
                } else if (arg.StartsWith("--launcher-log=", StringComparison.Ordinal)) {
                    log = Path.GetFullPath(arg.Substring(15));
                } else if (arg.StartsWith("--launcher-", StringComparison.Ordinal)) {
                    throw new ArgumentException("Unknown launcher diagnostic option.");
                } else forwarded.Add(arg);
            }
            int separator = forwarded.IndexOf("--");
            bool testProfile = separator >= 0 && forwarded.IndexOf("--test-profile", separator + 1) >= 0;
            if (quiet && !testProfile)
                throw new ArgumentException("Launcher diagnostics require -- --test-profile.");
            if (isolated && timeout == 0)
                throw new ArgumentException("Background QA requires a finite timeout.");

            string root = AppDomain.CurrentDomain.BaseDirectory;
            string executable = Path.Combine(root, "runtime", "LanceAndLaurel.exe");
            string pack = Path.ChangeExtension(executable, ".pck");
            if (log == null) {
                string logs = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "GALUMU", "LanceAndLaurel", "logs");
                Directory.CreateDirectory(logs);
                RetainRecentLogs(logs);
                log = Path.Combine(logs, "session-" + DateTime.UtcNow.ToString("yyyyMMdd-HHmmss-fff") + ".log");
            } else Directory.CreateDirectory(Path.GetDirectoryName(log));
            File.AppendAllText(log, "LAUNCHER utc=" + DateTime.UtcNow.ToString("o") + " root=" + root + Environment.NewLine + MemoryBound.Inspect() + Environment.NewLine);
            if (!File.Exists(executable) || !File.Exists(pack))
                throw new FileNotFoundException("缺少 runtime 文件夹中的游戏程序或资源包。请重新完整解压发布包，不要单独移动启动图标。");
            if (check) {
                File.AppendAllText(log, "PACKAGE_PRESENT (not an engine run)" + Environment.NewLine);
                return 0;
            }
            string commandLine = String.Join(" ", forwarded.ConvertAll(Quote).ToArray());
            int code = MemoryBound.Run(executable, commandLine, timeout, log, false, false, isolated, false, false);
            if (code != 0 && !quiet) {
                MessageBox.Show(ExitMessage(code) + "\n\n记录：" + log, "骑枪与桂冠", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
            return code;
        } catch (Exception error) {
            if (log != null) {
                try { File.AppendAllText(log, "LAUNCHER_ERROR " + error + Environment.NewLine); }
                catch (IOException) { } catch (UnauthorizedAccessException) { }
            }
            if (!quiet)
                MessageBox.Show(FriendlyError(error.Message) + (log == null ? "" : "\n\n记录：" + log), "骑枪与桂冠", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return 2;
        }
    }
}
