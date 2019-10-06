# Credential Switcher Service
# Alvaro Orgaz Fuertes
# GNU GPLv3
#

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


# Check for valid credentials
#------------------------------------------------------------------------------

$CredentialsFolderPath = "$env:USERPROFILE\AppData\Local\CredentialSwitcher"
$CredentialsFilePath = "$CredentialsFolderPath\Credentials.txt"
$PrivilegedCredentialsUsername = "admin"
$UnprivilegedCredentialsUsername = "Alvaro"
$NetworkShareDriveLetter = "Q:"
$NetworkHost="NAS" # host name or IP address
$NetworkSharePath = "\\$NetworkHost\Portal"
$SessionTimeOut = 0.2 #minutes
$MinimumPinSize = 4
$Today = Get-Date
$CredentialsValidityPeriod = 10 #days
$addr = [ipaddress]'127.0.0.1'
$port = 1234


# If credentials were not saved (or if they have expired), ask user for privileged and unprivileged credentials, encrypt them and save them
$ValidCredentials = $false
if (Test-Path -Path $CredentialsFilePath) {if ((Get-Item $CredentialsFilePath).LastWriteTime.AddDays($CredentialsValidityPeriod) -gt $Today) { $ValidCredentials=$true}}
if (-not($ValidCredentials)) {  
    #Ask user for credentials
    $PrivilegedCredentials = $host.ui.PromptForCredential("Privileged Credentials", "Please enter password", $PrivilegedCredentialsUsername, "")
    $UnprivilegedCredentials = $host.ui.PromptForCredential("Unprivileged Credentials", "Please enter password", $UnprivilegedCredentialsUsername, "")

    #Ask use to set a Passcode
    $KeySS =  Read-Host "Please set Passcode" -asSecureString
    if (($KeySS.Length -lt $MinimumPinSize) -or ($KeySS.Length -gt 16)) {
        Write-Host "Pin must be between $MinimumPinSize to 16 characters long"
        Exit
    }
    
    #Pad key up to 16 bytes long
    for ($i=$KeySS.Length; $i -lt 16; $i++) {
        $KeySS.AppendChar([char]32)
    }    

    $EncryptedPrivileged = ConvertFrom-SecureString -SecureString $PrivilegedCredentials.Password -SecureKey $KeySS
    $EncryptedUnprivileged = ConvertFrom-SecureString -SecureString $UnprivilegedCredentials.Password -SecureKey $KeySS

    Write-Host $EncryptedPrivileged.Length
    Write-Host $EncryptedUnprivileged.Length

    New-Item -Path $CredentialsFilePath -ItemType "file" -Value "$EncryptedPrivileged`r`n" -Force
    Add-Content -Path $CredentialsFilePath -Value $EncryptedUnprivileged -Force
    
    $PrivilegedCredentials = $null
    $UnprivilegedCredentials = $null
    $EncryptedPrivileged = $null
    $EncryptedUnprivileged = $null
    $KeySS = $null

    Write-Host "Credentials saved to $CredentialsFilePath"
}
#---------------------------------------------------------------------------------------------------------------------------------------------


# Launch TCP Listener and wait for commands
#---------------------------------------------------------------------------------------------------------------------------------------------
 $scriptblock = {
    param($addr, $port) 
    # $addr = [ipaddress]'127.0.0.1';$port = 1235
    $endpoint = New-Object Net.IPEndPoint ($addr, $port)
    $server = New-Object Net.Sockets.TcpListener $endpoint

    $exiting = $False
    while (-not $exiting){
        $server.Start()
        Write-Output "Listening"
        $client = $server.AcceptTcpClient()
        $client.ReceiveTimeout= 1000
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
$NetworkAdapter = 'Ethernet'
Function ResetNetworkAdapter {
    Disable-NetAdapter -Name $NetworkAdapter -Confirm:$false
    do {} while ((Get-NetAdapter $NetworkAdapter).Status -ne "Disabled")
    Enable-NetAdapter -Name $NetworkAdapter -Confirm:$false
    do {} while ((Get-NetAdapter $NetworkAdapter).Status -ne "Up")
    $NotifyIcon.ShowBalloonTip(30000,"Attention!","Network Adapter Reset",[system.windows.forms.ToolTipIcon]"Warning")
}
#---------------------------------------------------------------------------------------------------------------------------------------------






# Notification Icon
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
$TimerSessionTimeOut = New-Object System.Windows.Forms.Timer
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

$TimerSessionTimeOut.Interval = 3000 # ($SessionTimeOut * 60000)
$TimerSessionTimeOut.add_Tick({TimeOut})
#$TimerSessionTimeOut.start()

Function TimeOut {
    $TimerSessionTimeOut.stop()
    $TimerSessionTimeOut.start()
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


