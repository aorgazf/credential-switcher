
# Credential Switcher
# Alvaro Orgaz Fuertes
# GNU GPLv3
# Release 1.1
# - Remove saved credentials if found to have expired
# - Implement time outs in reading and connecting functions
# - 

# ToDo:
# - Provide a graphical representation of the current credential being used (user/admin) (green/safe, red/unsafe).
# 

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
if (Test-Path -Path $CredentialsFilePath) {if ((Get-Item $CredentialsFilePath).LastWriteTime.AddDays($CredentialsValidityPeriod) -gt $Today) {$ValidCredentials=$true} else {Remove-Item $CredentialsFilePath}}
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

$reader = $null
$writer = $null
$stream = $null
$client = $null

function RequestServerReset {
    $counter = 0

    while($true) {
        if ($writer -ne $null) {$writer.Dispose(); $writer = $null}
        if ($reader -ne $null) {$reader.Dispose(); $reader = $null}
        if ($stream -ne $null) {$stream.Dispose(); $stream = $null}
        if ($client -ne $null) {$client.Dispose(); $client = $null}

        $client = New-Object Net.Sockets.TcpClient
        $client.Connect($addr, $port)
        $client.ReceiveTimeout= 1000
        $stream = $client.GetStream()
        $reader = New-Object IO.StreamReader($stream)
        $writer = New-Object IO.StreamWriter($stream)
        $writer.AutoFlush = $true

        try{
            $PingResponse = $null
            $writer.WriteLine('PING')
            $PingResponse = $reader.ReadLine()
        } catch {}
        Start-Sleep -Seconds 1
        $counter += 1; 
        if ($PingResponse -eq 'PONG') {$writer.WriteLine('RESET'); break}        
        if ($counter -ge 15) {Write-Output "[CS Client] Unable to connect to CS Server"; break}
    }
}

function Start-GCTimeoutDialog {
  [CmdletBinding(HelpUri = 'https://github.com/grantcarthew/GCPowerShell')]
  [OutputType([String])]
  Param (
  [Parameter(Mandatory=$false)]
  [String]
  $Title = "Timeout",

  [Parameter(Mandatory=$false)]
  [String]
  $Message = "Timeout Message",

  [Parameter(Mandatory=$false)]
  [String]
  $Button1Text = "OK",

  [Parameter(Mandatory=$false)]
  [String]
  $Button2Text = "Cancel",

  [Parameter(Mandatory=$false)]
  [Int]
  $Seconds = 30
  )
  Write-Verbose -Message "Function initiated: $($MyInvocation.MyCommand)"

  Add-Type -AssemblyName PresentationCore
  Add-Type -AssemblyName PresentationFramework

  $window = $null
  $button1 = $null
  $button2 = $null
  $label = $null
  $timerTextBox = $null
  $timer = $null
  $timeLeft = New-TimeSpan -Seconds $Seconds
  $oneSec = New-TimeSpan -Seconds 1

  # Windows Form
  $window = New-Object -TypeName System.Windows.Window
  $window.Title = $Title
  $window.SizeToContent = "Height"
  $window.MinHeight = 160
  $window.Width = 310
  $window.WindowStartupLocation = "CenterScreen"
  $window.Topmost = $true
  $window.ShowInTaskbar = $false
  $window.ResizeMode = "NoResize"

  # Form Layout
  $grid = New-Object -TypeName System.Windows.Controls.Grid
  $topRow = New-Object -TypeName System.Windows.Controls.RowDefinition
  $topRow.Height = "Auto"
  $middleRow = New-Object -TypeName System.Windows.Controls.RowDefinition
  $middleRow.Height = "*"
  $bottomRow = New-Object -TypeName System.Windows.Controls.RowDefinition
  $bottomRow.Height = "Auto"
  $grid.RowDefinitions.Add($topRow)
  $grid.RowDefinitions.Add($middleRow)
  $grid.RowDefinitions.Add($bottomRow)
  $buttonStack = New-Object -TypeName System.Windows.Controls.StackPanel
  $buttonStack.Orientation = "Horizontal"
  $buttonStack.VerticalAlignment = "Bottom"
  $buttonStack.HorizontalAlignment = "Center"
  $buttonStack.Margin = "0,5,5,5"
  [System.Windows.Controls.Grid]::SetRow($buttonStack,2)
  $grid.AddChild($buttonStack)
  $window.AddChild($grid)

  # Button One
  $button1 = New-Object -TypeName System.Windows.Controls.Button
  $button1.MinHeight = 23
  $button1.MinWidth = 75
  $button1.VerticalAlignment = "Bottom"
  $button1.HorizontalAlignment = "Right"
  $button1.Margin = "0,0,0,0"
  $button1.Content = $Button1Text
  $button1.Add_Click({$window.Tag=$Button1Text;$window.Close()})
  $button1.IsDefault = $true
  $buttonStack.AddChild($button1)

  # Button Two
  $button2 = New-Object -TypeName System.Windows.Controls.Button
  $button2.MinHeight = 23
  $button2.MinWidth = 75
  $button2.VerticalAlignment = "Bottom"
  $button2.HorizontalAlignment = "Right"
  $button2.Margin = "8,0,0,0"
  $button2.Content = $Button2Text
  $button2.Add_Click({$window.Tag=$Button2Text;$window.Close()})
  $button2.IsCancel = $true
  $buttonStack.AddChild($button2)

  # Message Label
  $label = New-Object -TypeName System.Windows.Controls.TextBox
  $label.TextWrapping = "WrapWithOverflow"
  $label.BorderThickness = 0
  $label.Margin = "5,0,0,0"
  $label.Text = $Message
  [System.Windows.Controls.Grid]::SetRow($label,0)
  $grid.AddChild($label)

  # Count Down Textbox
  $timerTextBox = New-Object -TypeName System.Windows.Controls.TextBox
  $timerTextBox.Width = "150"
  $timerTextBox.Height = "20"
  $timerTextBox.Margin = "0,10,0,10"
  $timerTextBox.TextAlignment = "Center"
  $timerTextBox.IsReadOnly = $true
  $timerTextBox.Text = $timeLeft.ToString()
  [System.Windows.Controls.Grid]::SetRow($timerTextBox,1)
  $grid.AddChild($timerTextBox)

  # Windows Timer
  $timer = New-Object -TypeName System.Windows.Threading.DispatcherTimer

  $timer.Interval = New-TimeSpan -Seconds 1
  $timer.Tag = $timeLeft
  $timer.Add_Tick({
    $timer.Tag = $timer.Tag - $oneSec
    $timerTextBox.Text = $timer.Tag.ToString()
    if ($timer.Tag.TotalSeconds -lt 1) { $window.Tag = "TIMEOUT"; $window.Close() }
  })
  $timer.IsEnabled = $true
  $timer.Start()

  # Show
  $window.Activate() | Out-Null
  $window.ShowDialog() | Out-Null
  $window.Tag
  $timer.IsEnabled = $false
  $timer.Stop()
  $window = $null
  $button1 = $null
  $button2 = $null
  $label = $null
  $timerTextBox = $null
  $timer = $null
  $timeLeft = $null
  $oneSec = $null

  Write-Verbose -Message "Function completed: $($MyInvocation.MyCommand)"
}
Add-Type -AssemblyName System.Windows.Forms




#Switch
net use /delete $NetworkShareDriveLetter /y
net use /delete $NetworkSharePath /y
cmdkey /delete:$NetworkHost
RequestServerReset

$counter = 0
do{
    $Result = $null
    Start-Sleep -Milliseconds  500
    $Result= &{ net use $NetworkShareDriveLetter $NetworkSharePath /user:$($PrivilegedCredentials.UserName) "$($PrivilegedCredentials.GetNetworkCredential().Password)" } *>&1
    $counter += 1;       
    if ($counter -ge 15) {Write-Output "[CS Client] Unable to map network share with privileged credentials"; break}
} while (-not $Result.Contains('The command completed successfully.'))


do {
Start-Sleep -Milliseconds  ($SessionTimeOut * 60000)
    $msgBoxInput = Start-GCTimeoutDialog -Title "Credential Switcher" -Message "Credentials are going to be switched back to unpriviledged. If you would like to continue working with privileged credentials please press Cancel." -Seconds 10
} while ($msgBoxInput -eq 'Cancel')


# SwitchCredentials Back
net use /delete $NetworkShareDriveLetter /y
net use /delete $NetworkSharePath /y
cmdkey /delete:$NetworkHost
RequestServerReset

$counter = 0
do{
    $Result = $null
    Start-Sleep -Milliseconds  500
    $Result= &{ net use $NetworkShareDriveLetter $NetworkSharePath /user:$($UnprivilegedCredentials.UserName) "$($UnprivilegedCredentials.GetNetworkCredential().Password)" /persistent:yes} *>&1
    $counter += 1;       
    if ($counter -ge 15) {Write-Output "[CS Client] Unable to restore network share with unprivileged credentials"; break}
} while (-not $Result.Contains('The command completed successfully.'))
cmdkey /add:$NetworkHost /user:$($UnprivilegedCredentials.UserName) /pass:"$($UnprivilegedCredentials.GetNetworkCredential().Password)"
