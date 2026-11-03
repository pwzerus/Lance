Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class Probe { [DllImport("kernel32", SetLastError=true)] public static extern IntPtr VirtualAlloc(IntPtr p, UIntPtr n, uint t, uint f); }'
$count = 0
while ($count -lt 24) {
 $p = [Probe]::VirtualAlloc([IntPtr]::Zero, [UIntPtr](64MB), 0x3000, 4)
 if ($p -eq [IntPtr]::Zero) { Set-Content E:\GALUMU\docs\development\logs\inc059\limit-result.txt "LIMIT_DENIED afterMiB=$($count*64)"; exit 0 }
 $count++
}
exit 9
