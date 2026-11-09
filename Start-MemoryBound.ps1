param(
    [Parameter(Mandatory)][string]$Executable,
    [string]$Arguments = '',
    [ValidateRange(0,600)][int]$TimeoutSeconds = 60,
    [string]$MemoryLog = '',
    [switch]$InspectOnly,
    [switch]$MemoryMap,
    [switch]$HeadlessDiagnostics,
    [switch]$GeometryDiagnostics,
    [switch]$RenderDiagnostics,
    [switch]$IsolatedDesktop
)
$ErrorActionPreference = 'Stop'
$target = (Resolve-Path -LiteralPath $Executable).Path
if (!$InspectOnly -and [string]::IsNullOrEmpty($MemoryLog)) {
    $diagnosticFolder = Join-Path $PSScriptRoot 'logs/runtime'
    New-Item -ItemType Directory -Path $diagnosticFolder -Force | Out-Null
    $MemoryLog = Join-Path $diagnosticFolder ('memory-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff') + '.log')
}
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

public static class MemoryBound {
    [StructLayout(LayoutKind.Sequential)]
    struct Region {
        public IntPtr Address, AllocationBase;
        public uint AllocationProtect;
        public UIntPtr Size;
        public uint State, Protect, Type;
    }
    [DllImport("kernel32", SetLastError=true)] static extern UIntPtr VirtualQueryEx(IntPtr process, IntPtr address, out Region region, UIntPtr length);
    static string Map(IntPtr process) {
        ulong address = 0, privateBytes = 0, mappedBytes = 0, imageBytes = 0, largest = 0;
        int regions = 0;
        for (int i=0; i<100000; i++) {
            Region region;
            if (VirtualQueryEx(process, new IntPtr((long)address), out region, new UIntPtr((uint)Marshal.SizeOf(typeof(Region)))) == UIntPtr.Zero) break;
            ulong size = region.Size.ToUInt64();
            if (size==0 || address+size<=address) break;
            if (region.State==0x1000) {
                regions++;
                if (region.Type==0x20000) { privateBytes+=size; largest=Math.Max(largest,size); }
                else if (region.Type==0x40000) mappedBytes+=size;
                else if (region.Type==0x1000000) imageBytes+=size;
            }
            address=(ulong)region.Address.ToInt64()+size;
            if (address>0x7fffffffffffUL) break;
        }
        return String.Format("MAP privateCommittedMiB={0:F1} mappedCommittedMiB={1:F1} imageCommittedMiB={2:F1} largestPrivateRegionMiB={3:F1} regions={4}", privateBytes/1048576.0,mappedBytes/1048576.0,imageBytes/1048576.0,largest/1048576.0,regions);
    }
    [StructLayout(LayoutKind.Sequential)]
    struct MemoryStatus {
        public uint Length, Load;
        public ulong TotalPhysical, AvailablePhysical, TotalPageFile, AvailablePageFile, TotalVirtual, AvailableVirtual, AvailableExtended;
    }
    [DllImport("kernel32", SetLastError=true)] static extern bool GlobalMemoryStatusEx(ref MemoryStatus status);
    [StructLayout(LayoutKind.Sequential)]
    struct CpuLimit { public uint Flags, Rate; }
    [StructLayout(LayoutKind.Sequential)]
    struct Basic {
        public long ProcessTime, JobTime;
        public uint Flags;
        public UIntPtr MinWorkingSet, MaxWorkingSet;
        public uint ActiveProcesses;
        public UIntPtr Affinity;
        public uint Priority, Scheduling;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct Limits {
        public Basic Basic;
        public ulong ReadOps, WriteOps, OtherOps, ReadBytes, WriteBytes, OtherBytes;
        public UIntPtr ProcessMemory, JobMemory, PeakProcess, PeakJob;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct Startup {
        public int Size;
        public IntPtr Reserved, Desktop, Title;
        public int X, Y, Width, Height, XChars, YChars, Fill, Flags;
        public short Show, ReservedSize;
        public IntPtr ReservedBytes, Input, Output, Error;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct Child {
        public IntPtr Process, Thread;
        public uint ProcessId, ThreadId;
    }
    [DllImport("kernel32", SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr attr, IntPtr name);
    [DllImport("kernel32", SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job, int kind, ref Limits limits, int length);
    [DllImport("kernel32", SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job, int kind, ref CpuLimit limits, int length);
    [DllImport("kernel32", SetLastError=true, CharSet=CharSet.Unicode)] static extern bool CreateProcess(string app, StringBuilder command, IntPtr processAttr, IntPtr threadAttr, bool inherit, uint flags, IntPtr environment, string directory, ref Startup startup, out Child child);
    [DllImport("kernel32", SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32", SetLastError=true)] static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32", SetLastError=true)] static extern uint WaitForSingleObject(IntPtr handle, uint timeout);
    [DllImport("kernel32", SetLastError=true)] static extern bool GetExitCodeProcess(IntPtr process, out uint code);
    [DllImport("kernel32")] static extern bool TerminateProcess(IntPtr process, uint code);
    [DllImport("kernel32")] static extern bool CloseHandle(IntPtr handle);
    [DllImport("user32", SetLastError=true, CharSet=CharSet.Unicode)] static extern IntPtr CreateDesktop(string name, IntPtr device, IntPtr mode, uint flags, uint access, IntPtr attributes);
    [DllImport("user32", SetLastError=true)] static extern bool CloseDesktop(IntPtr desktop);

    static void Check(bool success) {
        if (!success) throw new Win32Exception(Marshal.GetLastWin32Error());
    }
    static void Log(string path, string line) {
        if (String.IsNullOrEmpty(path)) return;
        // Bound automatic session diagnostics; never retain samples in RAM.
        if (System.IO.File.Exists(path) && new System.IO.FileInfo(path).Length > 2*1024*1024) {
            string previous = path + ".previous";
            if (System.IO.File.Exists(previous)) System.IO.File.Delete(previous);
            System.IO.File.Move(path, previous);
        }
        System.IO.File.AppendAllText(path, line + Environment.NewLine);
    }
    public static string Inspect() {
        MemoryStatus status = new MemoryStatus();
        status.Length = (uint)Marshal.SizeOf(typeof(MemoryStatus));
        Check(GlobalMemoryStatusEx(ref status));
        return String.Format("RAM totalMiB={0:F0} availableMiB={1:F0} commitLimitMiB={2:F0} availableCommitMiB={3:F0}", status.TotalPhysical/1048576.0, status.AvailablePhysical/1048576.0, status.TotalPageFile/1048576.0, status.AvailablePageFile/1048576.0);
    }
    public static string InspectSelfMap() {
        using (var current = System.Diagnostics.Process.GetCurrentProcess()) { return Map(current.Handle); }
    }
    public static int Run(string app, string arguments, int seconds, string log, bool memoryMap, bool headlessDiagnostics, bool isolatedDesktop, bool geometryDiagnostics, bool renderDiagnostics) {
        if ((headlessDiagnostics ? 1 : 0) + (geometryDiagnostics ? 1 : 0) + (renderDiagnostics ? 1 : 0) > 1)
            throw new ArgumentException("Choose only one diagnostic memory profile.");
        if (isolatedDesktop && (seconds <= 0 || !System.Text.RegularExpressions.Regex.IsMatch(arguments, @"(^|\s)--test-profile(\s|$)")))
            throw new ArgumentException("Isolated desktop is for finite QA runs with --test-profile only.");
        if (renderDiagnostics && (!isolatedDesktop || seconds <= 0 || !arguments.Contains("--script ") || arguments.Contains("--editor") || arguments.Contains("--export")))
            throw new ArgumentException("512 MiB render diagnostics require finite isolated-desktop script QA, not import/export or gameplay.");
        if (geometryDiagnostics) {
            if (seconds <= 0 || !System.Text.RegularExpressions.Regex.IsMatch(arguments, @"(^|\s)--headless(\s|$)") ||
                !System.Text.RegularExpressions.Regex.IsMatch(arguments, @"(^|\s)--script\s") ||
                !arguments.Contains("--test-profile") || arguments.Contains("--editor") || arguments.Contains("--export"))
                throw new ArgumentException("256 MiB geometry diagnostics require finite headless script QA; never use for import/export or gameplay.");
            headlessDiagnostics = true;
        }
        if (System.IO.Path.GetFileName(app).EndsWith("_console.exe", StringComparison.OrdinalIgnoreCase))
            throw new ArgumentException("Use the main Godot .exe, not its _console.exe launcher, so process memory telemetry observes the engine itself.");
        if (headlessDiagnostics && !System.Text.RegularExpressions.Regex.IsMatch(arguments, @"(^|\s)--headless(\s|$)"))
            throw new ArgumentException("The 512 MiB diagnostic profile requires --headless.");
        MemoryStatus memory = new MemoryStatus();
        memory.Length = (uint)Marshal.SizeOf(typeof(MemoryStatus));
        Check(GlobalMemoryStatusEx(ref memory));
        // User-authorized 1 GiB system reserve plus bounded child and 256 MiB
        // launch overhead. The old flat 4 GiB gate blocked even measured
        // 0.6-0.75 GiB runs; this does NOT increase the child's Job limit.
        const ulong mib = 1024UL*1024UL;
        ulong childMiB = geometryDiagnostics ? 256UL : ((headlessDiagnostics || renderDiagnostics) ? 512UL : 1024UL);
        const ulong systemReserveMiB = 1024UL;
        ulong startupReserve = (systemReserveMiB+childMiB+256UL)*mib;
        if (memory.AvailablePhysical < startupReserve || memory.AvailablePageFile < (childMiB+256UL)*mib)
            throw new InvalidOperationException(String.Format("Insufficient launch budget: need {0} MiB available RAM and {1} MiB available commit.", startupReserve/mib, childMiB+256UL));
        using (var single = new System.Threading.Mutex(false, @"Local\GALUMU.MemoryBound")) {
        if (!single.WaitOne(0)) throw new InvalidOperationException("Another GALUMU game/test is running. Close it before starting another.");
        try {
        IntPtr job = CreateJobObject(IntPtr.Zero, IntPtr.Zero);
        Check(job != IntPtr.Zero);
        Child child = new Child();
        bool assigned = false;
        IntPtr desktop = IntPtr.Zero, desktopName = IntPtr.Zero;
        try {
            Limits limits = new Limits();
            // JOB_OBJECT_LIMIT_JOB_MEMORY | JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
            limits.Basic.Flags = 0x2200;
            limits.JobMemory = new UIntPtr(childMiB*mib);
            Check(SetInformationJobObject(job, 9, ref limits, Marshal.SizeOf(typeof(Limits))));
            CpuLimit cpu = new CpuLimit { Flags = 5, Rate = 2500 };
            Check(SetInformationJobObject(job, 15, ref cpu, Marshal.SizeOf(typeof(CpuLimit))));
            Startup startup = new Startup();
            startup.Size = Marshal.SizeOf(typeof(Startup));
            if (isolatedDesktop) {
                // Own non-input desktop: never call SwitchDesktop or move the user's focus.
                string name = "GALUMU_QA_" + Guid.NewGuid().ToString("N");
                desktop = CreateDesktop(name, IntPtr.Zero, IntPtr.Zero, 0, 0x01FF, IntPtr.Zero);
                Check(desktop != IntPtr.Zero);
                desktopName = Marshal.StringToHGlobalUni(name);
                startup.Desktop = desktopName;
                Log(log, "QA_DESKTOP " + name + " (not switched to input desktop)");
            }
            string previous = Environment.GetEnvironmentVariable("GALUMU_MEMORY_BOUND");
            try {
                Environment.SetEnvironmentVariable("GALUMU_MEMORY_BOUND", "1024");
                Check(CreateProcess(app, new StringBuilder("\"" + app + "\" " + arguments),
                    IntPtr.Zero, IntPtr.Zero, false, 0x08004004, IntPtr.Zero,
                    System.IO.Path.GetDirectoryName(app), ref startup, out child));
            } finally { Environment.SetEnvironmentVariable("GALUMU_MEMORY_BOUND", previous); }
            Check(AssignProcessToJobObject(job, child.Process));
            assigned = true;
            Check(ResumeThread(child.Thread) != uint.MaxValue);
            Log(log, String.Format("START utc={0:o} pid={1} jobMiB={2} executable={3}", DateTime.UtcNow, child.ProcessId, childMiB, app));
            uint wait = 258;
            var clock = System.Diagnostics.Stopwatch.StartNew();
            double nextMap = 5;
            using (var observed = System.Diagnostics.Process.GetProcessById((int)child.ProcessId)) {
                while (seconds == 0 || clock.Elapsed.TotalSeconds < seconds) {
                    wait = WaitForSingleObject(child.Process, 1000);
                    if (wait != 258) break;
                    long privateBytes, workingBytes;
                    try {
                        observed.Refresh();
                        privateBytes = observed.PrivateMemorySize64;
                        workingBytes = observed.WorkingSet64;
                    } catch (InvalidOperationException) {
                        // The child can exit between the wait timeout and the
                        // Process property read. Only accept a signalled child;
                        // errors while it is still running must still surface.
                        wait = WaitForSingleObject(child.Process, 0);
                        if (wait == 0) break;
                        throw;
                    }
                    Check(GlobalMemoryStatusEx(ref memory));
                    string line = String.Format("MEM seconds={0:F0} privateMiB={1:F1} workingMiB={2:F1} availableRamMiB={3:F0} availableCommitMiB={4:F0}", clock.Elapsed.TotalSeconds, privateBytes/1048576.0, workingBytes/1048576.0, memory.AvailablePhysical/(double)mib, memory.AvailablePageFile/(double)mib);
                    Console.WriteLine(line);
                    Log(log, line);
                    if (memoryMap && (clock.Elapsed.TotalSeconds>=nextMap || privateBytes>850L*1024L*1024L)) {
                        string map = Map(child.Process);
                        Console.WriteLine(map);
                        Log(log, map);
                        nextMap=clock.Elapsed.TotalSeconds+30;
                    }
                    // End a runaway before allocation failures can flood logs or spin.
                    Check(GlobalMemoryStatusEx(ref memory));
                    if ((ulong)privateBytes > (geometryDiagnostics ? 224UL : ((headlessDiagnostics || renderDiagnostics) ? 448UL : 900UL))*mib || memory.AvailablePhysical < systemReserveMiB*mib || memory.AvailablePageFile < 512UL*mib) {
                        string reason = "STOP memory budget exceeded, RAM reserve below 1 GiB, or available commit below 512 MiB";
                        Console.WriteLine(reason);
                        Log(log, reason);
                        return 125;
                    }
                }
            }
            if (wait == 258) { Log(log, "TIMEOUT: terminating job"); return 124; }
            Check(wait == 0);
            uint code;
            Check(GetExitCodeProcess(child.Process, out code));
            Log(log, String.Format("EXIT code={0} seconds={1:F1}", code, clock.Elapsed.TotalSeconds));
            return unchecked((int)code);
        } finally {
            if (!assigned && child.Process != IntPtr.Zero) TerminateProcess(child.Process, 1);
            CloseHandle(job);
            if (desktop != IntPtr.Zero && child.Process != IntPtr.Zero) WaitForSingleObject(child.Process, 5000);
            if (child.Thread != IntPtr.Zero) CloseHandle(child.Thread);
            if (child.Process != IntPtr.Zero) CloseHandle(child.Process);
            if (desktopName != IntPtr.Zero) Marshal.FreeHGlobal(desktopName);
            if (desktop != IntPtr.Zero) Log(log, "QA_DESKTOP_CLOSED=" + CloseDesktop(desktop));
        }
        } finally { single.ReleaseMutex(); }
        }
    }
}
'@
if ($InspectOnly) {
    [MemoryBound]::Inspect()
    if ($MemoryMap) { [MemoryBound]::InspectSelfMap() }
    exit 0
}
exit [MemoryBound]::Run($target, $Arguments, $TimeoutSeconds, $MemoryLog, $MemoryMap, $HeadlessDiagnostics, $IsolatedDesktop, $GeometryDiagnostics, $RenderDiagnostics)
