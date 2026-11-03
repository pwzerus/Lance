param(
    [Parameter(Mandatory)][string]$Executable,
    [string]$Arguments = '',
    [ValidateRange(0,600)][int]$TimeoutSeconds = 60,
    [string]$MemoryLog = '',
    [switch]$InspectOnly,
    [switch]$MemoryMap
)
$ErrorActionPreference = 'Stop'
$target = (Resolve-Path -LiteralPath $Executable).Path
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

    static void Check(bool success) {
        if (!success) throw new Win32Exception(Marshal.GetLastWin32Error());
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
    public static int Run(string app, string arguments, int seconds, string log, bool memoryMap) {
        MemoryStatus memory = new MemoryStatus();
        memory.Length = (uint)Marshal.SizeOf(typeof(MemoryStatus));
        Check(GlobalMemoryStatusEx(ref memory));
        if (memory.AvailablePhysical < 4UL*1024*1024*1024)
            throw new InvalidOperationException("Less than 4 GiB RAM available; launch refused to preserve workspace memory.");
        using (var single = new System.Threading.Mutex(false, @"Local\GALUMU.MemoryBound")) {
        if (!single.WaitOne(0)) throw new InvalidOperationException("Another GALUMU game/test is running. Close it before starting another.");
        try {
        IntPtr job = CreateJobObject(IntPtr.Zero, IntPtr.Zero);
        Check(job != IntPtr.Zero);
        Child child = new Child();
        bool assigned = false;
        try {
            Limits limits = new Limits();
            // JOB_OBJECT_LIMIT_JOB_MEMORY | JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
            limits.Basic.Flags = 0x2200;
            limits.JobMemory = new UIntPtr(1024u * 1024u * 1024u);
            Check(SetInformationJobObject(job, 9, ref limits, Marshal.SizeOf(typeof(Limits))));
            CpuLimit cpu = new CpuLimit { Flags = 5, Rate = 2500 };
            Check(SetInformationJobObject(job, 15, ref cpu, Marshal.SizeOf(typeof(CpuLimit))));
            Startup startup = new Startup();
            startup.Size = Marshal.SizeOf(typeof(Startup));
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
            uint wait = 258;
            var clock = System.Diagnostics.Stopwatch.StartNew();
            double nextMap = 5;
            using (var observed = System.Diagnostics.Process.GetProcessById((int)child.ProcessId)) {
                while (seconds == 0 || clock.Elapsed.TotalSeconds < seconds) {
                    wait = WaitForSingleObject(child.Process, 1000);
                    if (wait != 258) break;
                    observed.Refresh();
                    string line = String.Format("MEM seconds={0:F0} privateMiB={1:F1} workingMiB={2:F1}", clock.Elapsed.TotalSeconds, observed.PrivateMemorySize64/1048576.0, observed.WorkingSet64/1048576.0);
                    Console.WriteLine(line);
                    if (!String.IsNullOrEmpty(log)) System.IO.File.AppendAllText(log, line + Environment.NewLine);
                    if (memoryMap && (clock.Elapsed.TotalSeconds>=nextMap || observed.PrivateMemorySize64>850L*1024L*1024L)) {
                        string map = Map(child.Process);
                        Console.WriteLine(map);
                        if (!String.IsNullOrEmpty(log)) System.IO.File.AppendAllText(log, map + Environment.NewLine);
                        nextMap=clock.Elapsed.TotalSeconds+30;
                    }
                    // End a runaway before allocation failures can flood logs or spin.
                    Check(GlobalMemoryStatusEx(ref memory));
                    if (observed.PrivateMemorySize64 > 900L*1024L*1024L || memory.AvailablePhysical < 2UL*1024*1024*1024) {
                        string reason = "STOP memory budget exceeded or system reserve below 2 GiB";
                        Console.WriteLine(reason);
                        if (!String.IsNullOrEmpty(log)) System.IO.File.AppendAllText(log, reason + Environment.NewLine);
                        return 125;
                    }
                }
            }
            if (wait == 258) return 124;
            Check(wait == 0);
            uint code;
            Check(GetExitCodeProcess(child.Process, out code));
            return unchecked((int)code);
        } finally {
            if (!assigned && child.Process != IntPtr.Zero) TerminateProcess(child.Process, 1);
            CloseHandle(job);
            if (child.Thread != IntPtr.Zero) CloseHandle(child.Thread);
            if (child.Process != IntPtr.Zero) CloseHandle(child.Process);
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
exit [MemoryBound]::Run($target, $Arguments, $TimeoutSeconds, $MemoryLog, $MemoryMap)
