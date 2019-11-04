# Credential Switcher Service
# Alvaro Orgaz Fuertes
# GNU GPLv3
# Release 1.1
# - Remove the default checking of credentials at startup

# ToDo:
# - Implement Context Menu Commands:
#   - Check Credentials
#   - Delete Credentials
#   - Switching notification icons
#   - schtasks /create /tn "my_mount" /tr "net use V: \\hostname\path /persistent:yes" /sc onstart


# Resetting Network Interfaces requires administrator privileges
#------------------------------------------------------------------------------
# Credits: Jayowend
# https://stackoverflow.com/questions/7690994/running-a-command-as-administrator-using-powershell/39838527#39838527
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { 
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" `"$args`"" -Verb RunAs
    exit 
}
#------------------------------------------------------------------------------

# Only one instance should be running at a time
#------------------------------------------------------------------------------
# Credits: Mr. Annoyed
# https://stackoverflow.com/questions/15969662/assure-only-1-instance-of-powershell-script-is-running-at-any-given-time
Function Test-IfAlreadyRunning {
    $PsScriptsRunning = get-wmiobject win32_process | where{$_.processname -eq 'powershell.exe'} | select-object commandline,ProcessId

    #Get name of current script
    #$ScriptName = $MyInvocation.MyCommand.Name #NO! This gets name of *THIS FUNCTION*

    #enumerate each element of array and compare
    ForEach ($PsCmdLine in $PsScriptsRunning){
        [Int32]$OtherPID = $PsCmdLine.ProcessId
        [String]$OtherCmdLine = $PsCmdLine.commandline
        #Are other instances of this script already running?
        If (($OtherCmdLine -match $ScriptName) -And ($OtherPID -ne $PID) ){
            Write-host "PID [$OtherPID] is already running this script [$ScriptName]"
            Write-host "Exiting this instance. (PID=[$PID])..."
            Start-Sleep -Second 7
            Exit
        }
    }
} #Function Test-IfAlreadyRunning


#Get name of current script
$ScriptName = $MyInvocation.MyCommand.Name 
Test-IfAlreadyRunning -ScriptName $ScriptName

#------------------------------------------------------------------------------



#------------------------------------------------------------------------------

$addr = [ipaddress]'127.0.0.1'
$port = 1234
$NetworkAdapter = 'Ethernet'


# Launch TCP Listener and wait for commands
#---------------------------------------------------------------------------------------------------------------------------------------------
 $scriptblock = {
    param($addr, $port) 
    # $addr = [ipaddress]'127.0.0.1';$port = 1234
    $endpoint = New-Object Net.IPEndPoint ($addr, $port)
    $server = New-Object Net.Sockets.TcpListener $endpoint

    $exiting = $False
    while (-not $exiting){
        $server.Start()
        Write-Output "Listening"
        $client = $server.AcceptTcpClient()
        $client.ReceiveTimeout= 1000
        $client.SendTimeout= 1000
        # [Console]::beep(1000,300)
        $stream = $client.GetStream()
        $reader = New-Object IO.StreamReader($stream)
        $writer = New-Object IO.StreamWriter($stream)
        $writer.AutoFlush = $true
        Write-Output "Client_Connected"
        $timeouts = 0
        $client_disconnected = $false
        while (-not $client_disconnected) {
            Try{
                $command = $reader.ReadLine()
                switch ($command) {
                'EXIT'  { $exiting = $True; break}
                'PING'  { $writer.WriteLine("PONG")}
                }
                if ($command -ne 'PING') {Write-Output $command}

            } Catch {$command = $null}
            if ($command -eq $null) {$timeouts = $timeouts +1;if ($timeouts -ge 3) {$client_disconnected = $true; break}} else {$timeouts = 0}
            Start-Sleep -Seconds 1
        }
        Write-Output "Client_Disconnected"
        $writer.Dispose(); $writer = $null
        $reader.Dispose(); $reader = $null
        $stream.Dispose(); $stream = $null
        $client.Dispose(); $client = $null
        Start-Sleep -Seconds 1
    }
    $server.stop()
}
$job = Start-Job -ScriptBlock $scriptblock -args $addr, $port
#---------------------------------------------------------------------------------------------------------------------------------------------



# Action - Reset Network Adapter
#---------------------------------------------------------------------------------------------------------------------------------------------

Function ResetNetworkAdapter {
    Disable-NetAdapter -Name $NetworkAdapter -Confirm:$false
    do {} while ((Get-NetAdapter $NetworkAdapter).Status -ne "Disabled")
    Enable-NetAdapter -Name $NetworkAdapter -Confirm:$false
    do {} while ((Get-NetAdapter $NetworkAdapter).Status -ne "Up")
    $NotifyIcon.ShowBalloonTip(30000,"Attention!","Network Adapter Reset",[system.windows.forms.ToolTipIcon]"Warning")
}
#---------------------------------------------------------------------------------------------------------------------------------------------






# User Interface
#------------------------------------------------------------------------------
# Credits: 
# Mr. Annoyed
# https://bytecookie.wordpress.com/2011/12/28/gui-creation-with-powershell-part-2-the-notify-icon-or-how-to-make-your-own-hdd-health-monitor/
# Damien Van Robaeys
# http://www.systanddeploy.com/2018/12/create-your-own-powershell.html



[void][System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")

$MainForm = New-Object System.Windows.Forms.form
$NotifyIcon= New-Object System.Windows.Forms.NotifyIcon
$ContextMenu = New-Object System.Windows.Forms.ContextMenu

$TimerRoutine = New-Object System.Windows.Forms.Timer
$iconWarn = New-Object System.Drawing.Icon("$PSScriptRoot\Warning.ico")



$MainForm.ShowInTaskbar = $false
$MainForm.WindowState = "minimized"


$NotifyIcon.Icon =  $iconWarn
$NotifyIcon.Text = ""
$NotifyIcon.ContextMenu = $ContextMenu
$NotifyIcon.Visible = $True

$Menu_ClearC = New-Object System.Windows.Forms.MenuItem
$Menu_ClearC.Text = "Clear Credentials & Exit"
$NotifyIcon.ContextMenu.MenuItems.AddRange($Menu_ClearC)

$Menu_Exit = New-Object System.Windows.Forms.MenuItem
$Menu_Exit.Text = "Exit"
$NotifyIcon.ContextMenu.MenuItems.AddRange($Menu_Exit)

$Menu_ShowWindow = New-Object System.Windows.Forms.MenuItem
$Menu_ShowWindow.Text = "Show"
$NotifyIcon.ContextMenu.MenuItems.AddRange($Menu_ShowWindow)


$Menu_ClearC.add_Click({
   Remove-Item -Path $CredentialsFilePath
   $TimerHDD.stop()
   $NotifyIcon.Visible = $False
   $MainForm.close()
   Stop-Process $pid
})

$Menu_Exit.add_Click({
   $TimerHDD.stop()
   $NotifyIcon.Visible = $False
   $MainForm.close()
   Stop-Process $pid
})

$NotifyIcon.Add_MouseDoubleClick({
    ResetNetworkAdapter
})


$Menu_ShowWindow.add_Click({
    $MainForm.WindowState = "normal"
    $MainForm.Show()
})



$TimerRoutine.Interval = 1000 # (0.5 min)
$TimerRoutine.add_Tick({Routine})
$TimerRoutine.start()

Function Routine{
    $command = Receive-Job $job
    switch ($command) {
    'RESET' {ResetNetworkAdapter}
    'EXIT'  {
       $TimerHDD.stop()
       $NotifyIcon.Visible = $False
       $MainForm.close()
       Stop-Process $pid
      }
    }
}


# Make PowerShell Window Disappear
$windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
$asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
$null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)


# Force garbage collection just to start slightly lower RAM usage.
[System.GC]::Collect()

# Instead of:
#   [void][System.Windows.Forms.Application]::Run($MainForm)
# Create an application context for it to all run within.
# This helps with responsiveness, especially when clicking Exit.
$appContext = New-Object System.Windows.Forms.ApplicationContext
[void][System.Windows.Forms.Application]::Run($appContext)


