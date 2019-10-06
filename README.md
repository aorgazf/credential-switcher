# Credential Switcher
A PowerShell script to easily switch between credentials to access a SMB network share.

### The problem

The number of **ransomware** attacks is on the rise as it is proving to be a very profitable activity. When a computer is infected with ransomware, it starts to encrypt all files in the local computer and on the network to cause as much damage as possible. 

In many personal and business environments users access information stored on shared network folders. These folders usually serve as repositories of files. The more data these folders contain, the more valuable they become. 

The best protection against ransomware is to ensure any valuable data is being backed up on a regular basis both locally and on the cloud. An **additional layer of protection** to minimise the damage that malware could cause if it were to gain access to a computer, we should apply the principle of **least privilege**, restricting the access rights of users to just those absolutely required. 

Most of the time users don't require full read and write permissions when accessing repositories; they only require writing permissions when they need to save file changes or when they need to reorganise the repository.

In the same way that it is best practice not to grant users with admin rights on their computer accounts for their daily tasks, it would be desirable to grant network users only with reading access to repositories and provide them with **separate credentials with writing permissions** for when they need to do so.

Unfortunately Windows does not provide a simple mechanism to implement this. When Windows connects to a network share using SMB protocol, it establishes a SMB session using the credentials saved or provided when the connection is established. But Windows implementation of the protocol does not allow multiple concurrent connections to the same resource with different credentials.

Attempting to establish a new connection with different credentials results in the following error:

![error 1219 w](https://raw.githubusercontent.com/aorgazf/credential-switcher/master/img/error%201219%20w.png)



Using the `net use` command renders the same results:

![error 1219](https://raw.githubusercontent.com/aorgazf/credential-switcher/master/img/error%201219.png)



The `get-smbconnection` cmdlet shows that there were already connections established under another username:

![get-smbconnection.png](https://raw.githubusercontent.com/aorgazf/credential-switcher/master/img/get-smbconnection_alvaro.png)



In order to establish a new connection with different credentials all current SMB connections need to be closed first, but Windows does not provide a simple mechanism to close those open connections and switch credentials.



### The solution

A simple PowerShell script that allows the user to temporarily switch to use different credentials with higher permissions to carry out specific tasks and reverts back to the original credentials automatically after some time or once the user confirms the task is completed.

Windows `net use` command can be used to connect to network folders, however `net use /delete` does not close the opened SMB connections. The following screenshot shows the results of  `Get-SmbConnection` cmdlet confirming that there are lingering connections after the use of `net use /delete`.

![.png](https://raw.githubusercontent.com/aorgazf/credential-switcher/master/img/.png)

After some research, the best method to ensure the connections are closed is to disable the network adapter through which they were created. This method works better than the alternative of restarting Windows Explorer process. The downside is that disabling and re-enabling a network adapter requires administrator privileges.

That on its own is not a problem, but the commands to connect to a network share and to store user's credentials need to be run in the context of the user.

For this reason the script is divided in two modules: Server and Client

#### Credential Switcher Server

The Server module is meant to be run under administrator privileges when the computer is turned on. Its main purpose is to reset (disable and re-enable) the network adapter in order to close any lingering SMB connections.


```powershell
# Action - Reset Network Adapter
$NetworkAdapter = 'Ethernet'
Function ResetNetworkAdapter {
    Disable-NetAdapter -Name $NetworkAdapter -Confirm:$false
    do {} while ((Get-NetAdapter $NetworkAdapter).Status -ne "Disabled")
    Enable-NetAdapter -Name $NetworkAdapter -Confirm:$false
    do {} while ((Get-NetAdapter $NetworkAdapter).Status -ne "Up")
    $NotifyIcon.ShowBalloonTip(30000,"Attention!","Network Adapter Reset",[system.windows.forms.ToolTipIcon]"Warning")
}
```



The module also provides a nice user interface to configure its settings and exit.

```powershell
# Notification Icon
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
```



The server launches a TCP Listener on a separate thread and waits for a client to issue instructions:

```powershell
# Launch TCP Listener and wait for commands
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
```



#### Credential Switcher Client

The Client on the other hand checks there are valid credentials saved, asks for a PIN that is used to decrypt the safely stored credentials before switching.



```powershell
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
} else {
    # Ask for Passcode, Decrypt and Mount
    $KeySS =  Read-Host "Please enter Passcode" -asSecureString
    if (($KeySS.Length -lt $MinimumPinSize) -or ($KeySS.Length -gt 16)) {
        Write-Host "Pin must be between $MinimumPinSize to 16 characters long"
        Exit
    }
    
    #Pad key up to 16 bytes long
    for ($i=$KeySS.Length; $i -lt 16; $i++) {
        $KeySS.AppendChar([char]32)
    }   

    ($EncryptedPrivileged, $EncryptedUnprivileged) = Get-Content -Path "$CredentialsFilePath"

    $PrivilegedPasswordSS = ConvertTo-SecureString -String $EncryptedPrivileged -SecureKey $KeySS
    $UnprivilegedPasswordSS = ConvertTo-SecureString -String $EncryptedUnprivileged -SecureKey $KeySS

    $PrivilegedCredentials = New-Object System.Management.Automation.PsCredential($PrivilegedCredentialsUsername, $PrivilegedPasswordSS)
    $UnprivilegedCredentials = New-Object System.Management.Automation.PsCredential($UnprivilegedCredentialsUsername, $UnprivilegedPasswordSS)
}
```



With the credentials in place, the script initiates the switching process:

```powershell
#Switch
net use /delete $NetworkShareDriveLetter /y
net use /delete $NetworkSharePath /y
cmdkey /delete:$NetworkHost
RequestServerReset
do{
    $Result = $null
    Start-Sleep -Milliseconds  500
    $Result= &{ net use $NetworkShareDriveLetter $NetworkSharePath /user:$($PrivilegedCredentials.UserName) "$($PrivilegedCredentials.GetNetworkCredential().Password)" } *>&1
} while (-not $Result.Contains('The command completed successfully.'))
```



After the predefined time has passed, inform the user that credentials are about to be switched back:

```powershell
do {
Start-Sleep -Milliseconds  ($SessionTimeOut * 60000)
    #$msgBoxInput = [Windows.Forms.MessageBox]::Show('Credentials are going to be switched back to unpriviledged. If you would like to continue working with admin credentials please press cancel','Credential Switching', [Windows.Forms.MessageBoxButtons]::OKCancel, [Windows.Forms.MessageBoxIcon]::Question)
    $msgBoxInput = Start-GCTimeoutDialog -Title "Credential Switcher" -Message "Credentials are going to be switched back to unpriviledged. If you would like to continue working with privileged credentials please press Cancel." -Seconds 10
} while ($msgBoxInput -eq 'Cancel')
```



Switch credentials back and save the credentials in Windows Credentials Vault so that they can be used next time the user restarts the connection.

```powershell
# SwitchCredentials Back
net use /delete $NetworkShareDriveLetter /y
net use /delete $NetworkSharePath /y
cmdkey /delete:$NetworkHost
RequestServerReset
do{
    $Result = $null
    Start-Sleep -Milliseconds  500
    $Result= &{ net use $NetworkShareDriveLetter $NetworkSharePath /user:$($UnprivilegedCredentials.UserName) "$($UnprivilegedCredentials.GetNetworkCredential().Password)" /persistent:yes} *>&1
} while (-not $Result.Contains('The command completed successfully.'))
cmdkey /add:$NetworkHost /user:$($UnprivilegedCredentials.UserName) /pass:"$($UnprivilegedCredentials.GetNetworkCredential().Password)"

```