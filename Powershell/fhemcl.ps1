﻿<#
.SYNOPSIS	
    This Script is a FHEM Client for HTTP
.DESCRIPTION	
    FHEM commands could given over the Pipe, Arguments or File.
.EXAMPLE	
    fhemcl [http://<hostName>:]<portNummer> "FHEM command1" "FHEM command2"
    fhemcl [http://<hostName>:]<portNummer> filename
    echo "FHEM command"|fhemcl [http://<hostName>:]<portNummer>
.NOTES	
    put every FHEM command line in ""
#>
#region Params
param(
    [Parameter(Mandatory=$true,Position=0,HelpMessage="-first 'Portnumber or URL'")]
    [String]$first,#="http://raspib:8083",
    [Parameter(ValueFromPipeline=$true,ValueFromRemainingArguments=$true)]
    [String[]]$sec #= "D:\Users\Otto\OneDrive\Dokumente\Zeile.txt"
)
#endregion 

# Wenn nur ein Element, als Portnummer verwenden
# sonst als hosturl verwenden
$arr = $first -split ':'
if ($arr.Length -eq 1){
   if ($first -match '^\d+$') {$hosturl="http://localhost:$first"}
       else {
           write-output "is not a Portnumber"
           exit
            }
 } else {$hosturl=$first}
# url contains usernam@password?
if ($arr.Length -eq 4){
     $username = $($arr[1] -split'//')[1]
     $password = $($arr[2] -split '@')[0]
     $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$password)))
     $headers = @{
     Authorization=("Basic {0}" -f $base64AuthInfo)
     }
     
     # Nur zum Test noch pscredential
     $secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
     $credential = New-Object System.Management.Automation.PSCredential($username, $secpasswd)
     
     #hosturl vom Account befreien, stört ber ev. gar nicht
     $hosturl=$arr[0] + "://"+$($arr[2] -split '@')[1] +":" + $arr[3]
}
#Token holen
$token = Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri "$hosturl/fhem?XHR=1" | %{$_.Headers["X-FHEM-csrfToken"]}

# fhem cmd einlesen, entweder aus der Pipe, Datei oder zweiter Parameter 
# cmdarray leeren und Pipeline retten,
#$input contains all lines from pipeline, $sec contains the last line
$cmdarray=@()
foreach ($cmd2 in $input){$cmdarray += $cmd2}
if ($cmdarray.length -eq 0) {
     if((Test-Path $sec) -And ($sec.Length -eq 1)) {$cmdarray = Get-Content $sec} 
     else {foreach ($cmd2 in $sec){$cmdarray += $cmd2}}
}
#cmd abarbeiten
foreach ($cmd in $cmdarray){
# Fehler wenn mit Basic Auth und Befehle wie set Aktor01 ..  list geht.
   $web = Invoke-WebRequest -Uri "$hosturl/fhem?cmd=$cmd&fwcsrf=$token" -Headers $headers
   if ($web.content.IndexOf("<pre>") -ne -1) {$web.content.Substring($web.content.IndexOf("<pre>"),$web.content.IndexOf("</pre>")-$web.content.IndexOf("<pre>")) -replace '<[^>]+>',''}
}
