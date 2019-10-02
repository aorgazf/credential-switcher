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


# Credentials
#------------------------------------------------------------------------------

$CredentialsFolderPath = "$env:USERPROFILE\AppData\Local\CredentialSwitcher"
$CredentialsFilePath = "$CredentialsFolderPath\Credentials.txt"
$PrivilegedCredentialsUsername = "admin"
$UnprivilegedCredentialsUsername = "user"
$NetworkShareDriveLetter = "N:"
$NetworkHost="NAS" # host name or IP address
$NetworkSharePath = "\\$NetworkHost\NetworkFolder"
$SessionTimeOut = 1 #minutes
$MinimumPinSize = 4
$Today = Get-Date
$CredentialsValidityPeriod = 10 #days



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


#---------------------------------------------------------------------------------------------------------------------------------------------
# Check for stored credentials
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
    
    Write-Host "Credentials saved to $CredentialsFilePath"
}
#---------------------------------------------------------------------------------------------------------------------------------------------

#---------------------------------------------------------------------------------------------------------------------------------------------
# Check Credentials Vault
#---------------------------------------------------------------------------------------------------------------------------------------------


# Network Adapter Reset
#---------------------------------------------------------------------------------------------------------------------------------------------
Function ResetNetworkAdapter {
Disable-NetAdapter -Name Ethernet -Confirm:$false
do {} while ((Get-NetAdapter Ethernet).Status -ne "Disabled")
Enable-NetAdapter -Name Ethernet -Confirm:$false
do {} while ((Get-NetAdapter Ethernet).Status -ne "Up")
$NotifyIcon.ShowBalloonTip(30000,"Attention!","Network Adapter Reset",[system.windows.forms.ToolTipIcon]"Warning")
}

$CSPipeServer = new-object System.IO.Pipes.NamedPipeServerStream('CredentialSwitcher', [System.IO.Pipes.PipeDirection]::InOut)

    




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


$TimerRoutine.Interval = 1000 # (0.5 min)
$TimerRoutine.add_Tick({Routine})
$TimerRoutine.start()

Function Routine{
    #Get-SmbConnection
    #Get-NetAdapter Ethernet | format-table
    #Get-NetAdapter Ethernet | Format-List -Property "Status"
    #(Get-NetAdapter Ethernet).Status
    [console]::beep(500,300)
}


$TimerSessionTimeOut.Interval = 3000 # ($SessionTimeOut * 60000)
$TimerSessionTimeOut.add_Tick({TimeOut})
$TimerSessionTimeOut.start()

Function TimeOut {
    $TimerSessionTimeOut.stop()
    $CSPipeServer.WaitForConnection()
    [console]::beep(900,800)
    
    $script:pipeReader = new-object System.IO.StreamReader($CSPipeServer)
    $script:pipeWriter = new-object System.IO.StreamWriter($CSPipeServer)
    $pipeWriter.AutoFlush = $true
    while ($CSPipeServer.IsConnected) {
        $command = $pipeReader.ReadLine()
        if ($command -eq 'RESET') {[console]::beep(1900,2000); ResetNetworkAdapter}
        Start-Sleep -Seconds 1
        [console]::beep(500,100)
    }
    $TimerSessionTimeOut.start()
}



# Make PowerShell Window Disappear
#$windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
#$asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
#$null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)


# Force garbage collection just to start slightly lower RAM usage.
[System.GC]::Collect()

# Instead of:
#   [void][System.Windows.Forms.Application]::Run($MainForm)
# Create an application context for it to all run within.
# This helps with responsiveness, especially when clicking Exit.
$appContext = New-Object System.Windows.Forms.ApplicationContext
[void][System.Windows.Forms.Application]::Run($appContext)

#------------------------------------------------------------------------------




#$args
#pause

