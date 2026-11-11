// QA-only executable. Never ship as the game. Observe the actual Job from
// inside its child without allocating excessive memory to test the limit.
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
internal static class GuardProbe {
    [StructLayout(LayoutKind.Sequential)]
    struct Basic { public long ProcessTime, JobTime; public uint Flags; public UIntPtr MinWorkingSet, MaxWorkingSet; public uint ActiveProcesses; public UIntPtr Affinity; public uint Priority, Scheduling; }
    [StructLayout(LayoutKind.Sequential)]
    struct Limits { public Basic Basic; public ulong ReadOps, WriteOps, OtherOps, ReadBytes, WriteBytes, OtherBytes; public UIntPtr ProcessMemory, JobMemory, PeakProcess, PeakJob; }
    [StructLayout(LayoutKind.Sequential)]
    struct Cpu { public uint Flags, Rate; }
    [DllImport("kernel32", SetLastError=true)] static extern bool QueryInformationJobObject(IntPtr job, int kind, out Limits limits, int length, IntPtr returned);
    [DllImport("kernel32", SetLastError=true)] static extern bool QueryInformationJobObject(IntPtr job, int kind, out Cpu limits, int length, IntPtr returned);
    static int Main(string[] args) {
        string output = null;
        int hold = 0, code = 0;
        foreach (string arg in args) {
            if (arg.StartsWith("--probe-output=")) output=arg.Substring(15);
            if (arg.StartsWith("--probe-hold=")) hold=Int32.Parse(arg.Substring(13));
            if (arg.StartsWith("--probe-code=")) code=Int32.Parse(arg.Substring(13));
        }
        Limits limits; Cpu cpu;
        bool memoryOk = QueryInformationJobObject(IntPtr.Zero, 9, out limits, Marshal.SizeOf(typeof(Limits)), IntPtr.Zero);
        bool cpuOk = QueryInformationJobObject(IntPtr.Zero, 15, out cpu, Marshal.SizeOf(typeof(Cpu)), IntPtr.Zero);
        ulong memoryMiB = limits.JobMemory.ToUInt64()/1048576;
        bool passed = memoryOk && cpuOk && memoryMiB==1024 && (limits.Basic.Flags & 0x2200)==0x2200 && cpu.Flags==5 && cpu.Rate==2500 && Environment.GetEnvironmentVariable("GALUMU_MEMORY_BOUND")=="1024";
        File.WriteAllText(output, String.Format("{{\"passed\":{0},\"pid\":{1},\"job_mib\":{2},\"job_flags\":{3},\"cpu_flags\":{4},\"cpu_rate\":{5}}}", passed.ToString().ToLowerInvariant(), Process.GetCurrentProcess().Id, memoryMiB, limits.Basic.Flags, cpu.Flags, cpu.Rate));
        Thread.Sleep(Math.Min(30,Math.Max(0,hold))*1000);
        return passed ? code : 1;
    }
}
