
# Credential Switcher
# Alvaro Orgaz Fuertes
# GNU GPLv3
#
# ToDo:
# - Credentials stored on the local drive are deleted after a set time. User is requested to provide again passwords which are encrypted witha new key and pin.
# - Provide a graphical representation of the current credential being used (user/admin) (green/safe, red/unsafe).
# - Display timer until timeout.
# - generate a random KeyBase



$CredentialsFolder = $env:USERPROFILE
$PrivilegedCredentialsUsername = "admin"
$UnprivilegedCredentialsUsername = "user"
$NetworkShareDriveLetter = "Q:"
$NetworkSharePath = "\\NAS\Network_Folder"
$SessionTimeOut = 1 #minutes
$KeyBase = "LhQd8omWH8DB" #change

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


# If credentials are not saved, encrypt and save privileged and unprivileged credentials to credentials folder
if (-not((Test-Path -Path "${CredentialsFolder}\NAS Privileged Credentials.txt") -and (Test-Path -Path "${CredentialsFolder}\NAS Unprivileged Credentials.txt"))) {
    
    $PrivilegedCredentials = $host.ui.PromptForCredential("NAS Privileged Credentials", "Please enter password", $PrivilegedCredentialsUsername, "")
    $UnprivilegedCredentials = $host.ui.PromptForCredential("NAS Unprivileged Credentials", "Please enter password", $UnprivilegedCredentialsUsername, "")

    # $KeyBase = -join ((65..90) + (97..122) | Get-Random -Count 12 | % {[char]$_}) Random for session-long credentials
    $KeySS =  Read-Host "Please enter PIN" -asSecureString

    for ($i=0; $i -lt 12; $i++) {
        $KeySS.AppendChar($KeyBase[$i])
    }

    if ($KeySS.Length -ne 16) {
        Write-Host "Pin must be 4 characters long!"
        Exit
    }

    $EncryptedPrivileged = ConvertFrom-SecureString -SecureString $PrivilegedCredentials.Password -SecureKey $KeySS
    $EncryptedUnprivileged = ConvertFrom-SecureString -SecureString $UnprivilegedCredentials.Password -SecureKey $KeySS

    Set-Content -Path "${CredentialsFolder}\NAS Privileged Credentials.txt" -Value $EncryptedPrivileged
    Set-Content -Path "${CredentialsFolder}\NAS Unprivileged Credentials.txt" -Value $EncryptedUnprivileged
}

#---------------------------------------------------------------------------------------------------------------------------------------------

Add-Type -AssemblyName System.Windows.Forms

# Ask for Pin, Decrypt and Mount
$KeySS =  Read-Host "Please enter PIN" -asSecureString

for ($i=0; $i -lt 12; $i++) {
    $KeySS.AppendChar($KeyBase[$i])
    }


if ($KeySS.Length -ne 16) {
    Write-Host "Pin must be 4 characters long!"
    Exit
}


$EncryptedPrivileged = Get-Content -Path "${CredentialsFolder}\NAS Privileged Credentials.txt" 
$EncryptedUnprivileged = Get-Content -Path "${CredentialsFolder}\NAS Unprivileged Credentials.txt"

$PrivilegedPasswordSS = ConvertTo-SecureString -String $EncryptedPrivileged -SecureKey $KeySS
$UnprivilegedPasswordSS = ConvertTo-SecureString -String $EncryptedUnprivileged -SecureKey $KeySS

$PrivilegedCredentials = New-Object System.Management.Automation.PsCredential($PrivilegedCredentialsUsername, $PrivilegedPasswordSS)
$UnprivilegedCredentials = New-Object System.Management.Automation.PsCredential($UnprivilegedCredentialsUsername, $UnprivilegedPasswordSS)




#$msgBoxInput =  [Windows.Forms.MessageBox]::Show('Switching to priviledged credentials requires restarting Explorer. Would you like to proceed? ','Credential Switching', [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Exclamation)

switch  ($msgBoxInput) {
  'Yes' {
    net use /delete $NetworkShareDriveLetter /y
    Start-Sleep -Milliseconds  200
    taskkill /f /IM explorer.exe
    Start-Sleep -Milliseconds  200
    $Result = &{net use $NetworkShareDriveLetter $NetworkSharePath /user:$($PrivilegedCredentials.UserName) $($PrivilegedCredentials.GetNetworkCredential().Password)} *>&1
    Start-Sleep -Milliseconds  200
    start explorer.exe
 <#
	if (-not $Result.Contains('The command completed successfully.')) {
        [Windows.Forms.MessageBox]::Show($Result,'Credential Switching', [Windows.Forms.MessageBoxButtons]::OK , [Windows.Forms.MessageBoxIcon]::Error)
        Exit
    }
#>
  }

  'No' {
    Exit
  }
}



do {
Start-Sleep -Milliseconds  ($SessionTimeOut * 60000)
    #$msgBoxInput = [Windows.Forms.MessageBox]::Show('Credentials are going to be switched back to unpriviledged. If you would like to continue working with admin credentials please press cancel','Credential Switching', [Windows.Forms.MessageBoxButtons]::OKCancel, [Windows.Forms.MessageBoxIcon]::Question)

$msgBoxInput = Start-GCTimeoutDialog -Title "Credential Switching" -Message "Credentials are going to be switched back to unpriviledged. If you would like to continue working with privileged credentials please press Cancel." -Seconds 10
} while ($msgBoxInput -eq 'Cancel')


# SwitchCredentials Back
net use /delete $NetworkShareDriveLetter /y
Start-Sleep -Milliseconds  200
taskkill /f /IM explorer.exe
Start-Sleep -Milliseconds  200
$Result = &{net use $NetworkShareDriveLetter $NetworkSharePath /user:$($UnprivilegedCredentials.UserName) $($UnprivilegedCredentials.GetNetworkCredential().Password)} *>&1
Start-Sleep -Milliseconds  200
start explorer.exe
<#
	if (-not $Result.Contains('The command completed successfully.')) {
        [Windows.Forms.MessageBox]::Show($Result,'Credential Switching', [Windows.Forms.MessageBoxButtons]::OK , [Windows.Forms.MessageBoxIcon]::Error)
        Exit
    }
#>


# Get-SmbConnection # requires Admin Privs
# Get-SmbConnection -ServerName NAS | Select-Object -Property *



#net use /delete Q: /y
#cmdkey /delete:NAS
#net use Q: \\NAS\Network_Folder /user:admin 'admin_password'



#net use /delete Q: /y
#cmdkey /add:NAS /user:user /pass:'user_password'
#net use Q: \\NAS\Network_Folder 

#  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# $PrivilegedCredentials.GetNetworkCredential().Password # Prints Password
# $UnprivilegedCredentials.GetNetworkCredential().Password # Prints Password



