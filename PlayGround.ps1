# TCP socket - client
$server = '127.0.0.1'
$port   = 1235


function Connect {
    do{
        if ($global:writer -ne $null) {$global:writer.Dispose(); $global:writer = $null}
        if ($global:reader -ne $null) {$global:reader.Dispose(); $global:reader = $null}
        if ($global:stream -ne $null) {$global:stream.Dispose(); $global:stream = $null}
        if ($global:client -ne $null) {$global:client.Dispose(); $global:client = $null}

        $global:client = New-Object Net.Sockets.TcpClient
        $global:client.Connect($server, $port)
        #$global:client.ReceiveTimeout= 1000
        $global:stream = $global:client.GetStream()
        $global:reader = New-Object IO.StreamReader($global:stream)
        $global:writer = New-Object IO.StreamWriter($global:stream)
        $global:writer.AutoFlush = $true

        try{
            write-output "Pinging..."
            $PingResponse = $null
            $global:writer.WriteLine('PING')
            $PingResponse = $reader.ReadLine()
            write-output $PingResponse
        } catch {}
        Start-Sleep -Seconds 1
    } until ($PingResponse -eq 'PONG')
    #ToDo: Implement TimeOut
}


$writer.WriteLine('RESET')





do{
    cls
    get-smbconnection
    #Get-NetAdapter Ethernet | format-table
    #Get-NetAdapter Ethernet | Format-List -Property "Status"
     (Get-NetAdapter Ethernet).Status
    Start-Sleep -Milliseconds  700
} while ($true)



$continue = $true
while($continue)
{

    if ([console]::KeyAvailable)
    {
        echo "Toggle with F12";
        $x = [System.Console]::ReadKey() 

        switch ( $x.key)
        {
            F12 { $continue = $false }
        }
    } 
    else
    {
        $wsh = New-Object -ComObject WScript.Shell
        $wsh.SendKeys('{CAPSLOCK}')
        sleep 1
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($wsh)| out-null
        Remove-Variable wsh
    }    
}









Param
 (
	[String]$Restart	
 )

If ($Restart -ne "") 
	{
		sleep 10
	} 

$Current_Folder = split-path $MyInvocation.MyCommand.Path




 
 
 # When Exit is clicked, close everything and kill the PowerShell process
$Menu_Restart_Tool.add_Click({
	$Restart = "Yes"
	start-process -WindowStyle hidden powershell.exe "C:\ProgramData\MySystrayTool\PS1_Systray_Tool.ps1 '$Restart'" 	

	$Main_Tool_Icon.Visible = $false
	$window.Close()
	Stop-Process $pid	
 })
 
 