<#
    .SYNOPSIS
    Copy IIS or transport protocol log files from Exchange 2013/2016/2019 Servers to a single location for better log file analysis.
   
    Thomas Stensitzki
	
    THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE 
    RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
	
    Version 2.3, 2018-11-10

    Ideas, comments and suggestions to support@granikos.eu 
 
    .LINK  
    http://scripts.granikos.eu
	
    .DESCRIPTION
    This script copies IIS log or other selected Exchange logs files from all Exchange servers to a single target root folder creating subfolders for each source server.
    
    The log files need to have the same root folder across all Exchange 2013/2016/2019 servers.

    The script is intended to run from within an active Exchange 2013/2016/2019 Management Shell session.

    Script has been previously released as Get-IisLogs.ps1

    .NOTES 
    Requirements 
    - Windows Server Windows Server 2012 R2+
    - Exchange Server 2013/2016/2019 Management Shell
    - Utilizes global functions library

    Revision History 
    -------------------------------------------------------------------------------- 
    1.0 Initial community release 
    1.1 Support for SMTP logs Hub/Frontend added
    2.0 Renamed to Get-Logs.ps1
    2.1 Support for pipeline tracing logs added
    2.2 Support for MAPI over HTTP logs added
    2.3 Changes to support IIS FE/BE W3SVC folders
	
    .PARAMETER DaysToFetch
    Number of days IIS log files should be gatheredretained, default is 1 day

    .PARAMETER LogFileRoot
    Local IIS log file root to store copied log files, default E:\GatheredLogs

    .PARAMETER CleanFolder
    Switch to delete per Exchange Server subfolders and creating new folders

    .PARAMETER IIS
    Switch to gather IIS log files from all Exchange 2013/2016/2019 servers. Creates a subfolder named 'IIS'.

    .PARAMETER HubTransport
    Switch to gather Hub transport SMTP protocol logs from all Exchange 2013/2016/2019 servers. Creates a subfolder named 'Hub'.

    .PARAMETER FrontendTransport
    Switch to gather Frontend transport SMTP protocol logs from all Exchange 2013/2016/2019 servers. Creates a subfolder names 'Frontend'.

    .PARAMETER EWS
    Switch to gather EWS protocol logs from all Exchange 2013/2016/2019 servers. Creates a subfolder names 'EWS'.

    .EXAMPLE
    Copy IIS log files 

    .\Get-Logs.ps1 -IIS

    .EXAMPLE
    Delete local subfolders and copy IIS log files

    .\Get-Logs.ps1 -CleanFolders -IIS

    .EXAMPLE
    Delete local subfolders and copy frontend transport logs for the last 5 days

    .\Get-Logs.ps1 -CleanFolders -FrontendTransport -DaysToFetch 5
#>

[CmdletBinding()]
Param(
  [string]$LogFileRoot = 'E:\GatheredLogs',
  [int]$DaysToFetch = 1,
  [switch]$CleanFolders,
  [switch]$IIS,
  [switch]$HubTransport,
  [switch]$FrontendTransport,
  [switch]$Pipelinetracing,
  [switch]$MAPI,
  [switch]$EWS
)


# Variables section
# Administrative share and logfile soruce for IIS logs
# Modify the administrative shares and paths to match your environment
[string]$IisUncLogPathFE = 'D$\IISLogs\W3SVC1'
[string]$IisUncLogPathBE = 'D$\IISLogs\W3SVC2'
[string]$HubTransportReceiveUncLogPath = 'E$\Program Files\Microsoft\Exchange Server\V15\TransportRoles\Logs\Hub\ProtocolLog\SmtpReceive'
[string]$HubTransportSendUncLogPath = 'E$\Program Files\Microsoft\Exchange Server\V15\TransportRoles\Logs\Hub\ProtocolLog\SmtpSend'
[string]$FrontentTransportReceiveUncLogPath = 'E$\Program Files\Microsoft\Exchange Server\V15\TransportRoles\Logs\Frontend\ProtocolLog\SmtpReceive'
[string]$FrontendTransportSendUncLogPath = 'E$\Program Files\Microsoft\Exchange Server\V15\TransportRoles\Logs\Frontend\ProtocolLog\SmtpSend'

# local variables
[string]$IisSubFolderName = 'IIS'
[string]$HubTransportSubFolderName = 'Hub'
[string]$FrontendTransportSubFolderName = 'Frontend'

# 2015-06-18: Implementation of global module
# Import GlobalFunctions
if($null -ne (Get-Module -Name GlobalFunctions -ListAvailable).Version) {
  Import-Module -Name GlobalFunctions
}
else {
  Write-Warning -Message 'Unable to load GlobalFunctions PowerShell module.'
  Write-Warning -Message 'Open an administrative PowerShell session and run Import-Module GlobalFunctions'
  Write-Warning -Message 'Please check http://bit.ly/GlobalFunctions for further instructions'
  exit
}
$ScriptDir = Split-Path -Path $script:MyInvocation.MyCommand.Path
$ScriptName = $MyInvocation.MyCommand.Name
$logger = New-Logger -ScriptRoot $ScriptDir -ScriptName $ScriptName -LogFileRetention 14
$logger.Write('Script started')
$logger.Write(('Gathering log files for {0} days' -f ($DaysToFetch)))

function Test-LogFolders {
  # Check, if we need to create new folders
  if(!(Test-Path -Path $LogFileRoot)) {
  
    # Folder does not exist, lets create a new root folder
    New-Item -Path $LogFileRoot -ItemType Directory | Out-Null
    $logger.Write(('Folder {0} created' -f $LogFileRoot)) 
  }

  $functionFolderPath = Join-Path -Path $LogFileRoot -ChildPath $functionalFolder

  if(!(Test-Path -Path $functionFolderPath)) {
  
    # Functional folder does not exist, lets create a new root folder
    New-Item -Path $functionFolderPath -ItemType Directory | Out-Null
    $logger.Write(('Folder {0} created' -f $functionFolderPath))
  }
    
  If(Test-Path -Path $LogFileRoot) {
    $folderPath = Join-Path -Path $functionFolderPath -ChildPath $E15Server
    If((Test-Path -Path $folderPath) -and ($CleanFolders)) {
      # Folder exists and is requested to be deleted
      Remove-Item -Path $folderPath -Recurse -Force -Confirm:$false | Out-Null            
      $logger.Write(('Folder {0} deleted (cleaned)' -f $folderPath))
    }
    If(!(Test-Path -Path $folderPath)) {
      # Folder does not exist, lets create a new sub folder
      New-Item -Path $folderPath -ItemType Directory | Out-Null
      $logger.Write(('Folder {0} created' -f $folderPath))
    }
  }
}

function Get-ExchangeServerLogFiles {
    
  $functionFolderPath = Join-Path -Path $LogFileRoot -ChildPath $functionalFolder

  $targetPath = Join-Path -Path $functionFolderPath -ChildPath $E15Server

  # Only try to delete files, if folder exists
  if (Test-Path -Path $SourceServerFolder) {
        
    $Now = Get-Date
    $LastWrite = $Now.AddDays(-($DaysToFetch))

    # Select files to copy
    $Files = Get-ChildItem -Path $SourceServerFolder -Include *.log -Recurse | Where-Object {$_.LastWriteTime -ge "$LastWrite"}

    # Lets count the files that will be copied
    $fileCount = 0

    # Copy the files
    foreach ($File in $Files)
    {            
      $null = Copy-Item -Path $File -Destination $targetPath -Force -Confirm:$false
      $fileCount++
    }
    $logger.Write(('{0} files copied from {1}' -f $fileCount, $SourceServerFolder))
  }
}

# MAIN ####################################################
# Get a list of all Exchange 2013/2016/2019 servers
$ExchangeServers = Get-ExchangeServer | Where-Object {$_.IsE15OrLater -eq $true} | Sort-Object -Property Name

if($IIS) {
  # Gather IIS logs
  $functionalFolder = $IisSubFolderName

  # Gather files for each Exchange 2013/2016/2019 Server
  foreach ($E15Server In $ExchangeServers) {
    
    # Fetch Frontend IIS Logs
    $SourceServerFolder = ('\\{0}\{1}' -f $E15Server, $IisUncLogPathFE)

    Test-LogFolders
    Get-ExchangeServerLogFiles
    
    # Fetch Backend IIS Logs
    $SourceServerFolder = ('\\{0}\{1}' -f $E15Server, $IisUncLogPathBE)

    Get-ExchangeServerLogFiles
  }
}
elseif($HubTransport) {
  # Gather Hub transport logs
  $functionalFolder = $HubTransportSubFolderName
   
  # Gather files for each Exchange 2013/2016/2019 Server
  foreach ($E15Server In $ExchangeServers) {

    # Fetch SmtpReceive Logs
    $SourceServerFolder = ('\\{0}\{1}' -f $E15Server, $HubTransportReceiveUncLogPath) 

    Test-LogFolders
    Get-ExchangeServerLogFiles

    # Fetch SmtpSend Logs
    $SourceServerFolder = ('\\{0}\{1}' -f $E15Server, $HubTransportSendUncLogPath) 

    Get-ExchangeServerLogFiles

  }
}
elseif($FrontendTransport) {
  # Gather Frontend transport logs
  $functionalFolder = $FrontendTransportSubFolderName
   
  # Gather files for each Exchange 2013/2016/2019 Server
  foreach ($E15Server In $ExchangeServers) {
    # Fetch SmtpReceive Logs
    $SourceServerFolder = "\\" + $E15Server + "\" + $FrontentTransportReceiveUncLogPath

    Test-LogFolders
    Get-ExchangeServerLogFiles

    # Fetch SmtpSend Logs
    $SourceServerFolder = "\\" + $E15Server + "\" + $FrontendTransportSendUncLogPath

    Get-ExchangeServerLogFiles

  }
}
else {
  Write-Host 'No log file source type has been defined. Please check help section of the script.'
}

$logger.Write('Script finished')
Write-Host 'Script finished'