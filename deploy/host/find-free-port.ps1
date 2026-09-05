# Called by install.bat to pick a free TCP port for the bundled PostgreSQL instance, starting at
# 5432. Kept as its own file rather than an inline `for /f ... powershell -Command "..."` in the
# batch script: that nested quoting (batch -> for/f backquote -> -Command string -> C# try/catch)
# is exactly the kind of thing that silently breaks depending on how the calling process (here,
# NSIS's nsExec) invokes cmd.exe - a plain -File call has none of that nesting.
param(
    [int]$StartPort = 5432
)

$port = $StartPort
while ($true) {
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)
        $listener.Start()
        $listener.Stop()
        Write-Output $port
        break
    } catch {
        $port++
    }
}
