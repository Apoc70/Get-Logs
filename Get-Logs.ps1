<#
    .SYNOPSIS
    Copy IIS or transport protocol log files from Exchange 2013 Servers to a single location for better log file analysis.
   
   	Thomas Stensitzki
	
	THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE 
	RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
	
	Version 2.0, 2015-12-16

    Ideas, comments and suggestions to support@granikos.eu 
 
    .LINK  
    More information can be found at http://www.granikos.eu/en/scripts
	
    .DESCRIPTION
	This script copies IIS log or SMTP protocol logs files from all Exchange 2013 servers to a single target root folder creating subfolders for each server.
    
    The log files need to have the same root folder across all Exchange 2013 servers.

    The script is intended to run from within an active Exchange 2013 Management Shell session.

    Script has been previously released as Get-IisLogs.ps1

    .NOTES 
    Requirements 
    - Windows Server 2008 R2 SP1, Windows Server 2012 or Windows Server 2012 R2  
    - Exchange Server 2013 Management Shell
    - Utilizes global functions library

    Revision History 
    -------------------------------------------------------------------------------- 
    1.0     Initial community release 
    1.1     Support for SMTP logs Hub/Frontend added
    2.0     Renamed to Get-Logs.ps1
	
	.PARAMETER DaysToFetch
    Number of days IIS log files should be gatheredretained, default is 1 day

    .PARAMETER LogFileRoot
    Local IIS log file root to store copied log files, default E:\GatheredLogs

    .PARAMETER CleanFolder
    Switch to delete per Exchange Server subfolders and creating new folders

    .PARAMETER IIS
    Switch to gather IIS log files from all Exchange 2013 servers. Creates a subfolder named 'IIS'.

    .PARAMETER HubTransport
    Switch to gather Hub transport SMTP protocol logs from all Exchange 2013 servers. Creates a subfolder named 'Hub'.

    .PARAMETER FrontendTransport
    Switch to gather Frontend transport SMTP protocol logs from all Exchange 2013 servers. Creates a subfolder names 'Frontend'.

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

Param(
    [parameter(Mandatory=$false,ValueFromPipeline=$false,HelpMessage='Full path to local IIS logs file storage')]
        [string]$LogFileRoot = "E:\GatheredLogs",
    [parameter(Mandatory=$false,ValueFromPipeline=$false,HelpMessage='Number of days to fetch log files for (Default 1)')]
        [int]$DaysToFetch = 1,
    [parameter(Mandatory=$false,ValueFromPipeline=$false,HelpMessage='Switch to clean log file sub folders')]
        [switch]$CleanFolders,
    [parameter(Mandatory=$false,ValueFromPipeline=$false,HelpMessage='Switch to collect IIS log files from Exchange 2013 servers')]
        [switch]$IIS,
    [parameter(Mandatory=$false,ValueFromPipeline=$false,HelpMessage='Switch to collect Hub Transport log files from Exchange 2013 servers')]
        [switch]$HubTransport,
    [parameter(Mandatory=$false,ValueFromPipeline=$false,HelpMessage='Switch to collect Frontend Transport log files from Exchange 2013 servers')]
        [switch]$FrontendTransport

)

Set-StrictMode -Version Latest

# Variables section
# Administrative share and logfile soruce for IIS logs
# Modify the administrative shares and paths to match your environment
[string]$IisUncLogPath = "D$\IISLogs\W3SVC1"
[string]$HubTransportReceiveUncLogPath = "E$\Program Files\Microsoft\Exchange Server\V15\TransportRoles\Logs\Hub\ProtocolLog\SmtpReceive"
[string]$HubTransportSendUncLogPath = "E$\Program Files\Microsoft\Exchange Server\V15\TransportRoles\Logs\Hub\ProtocolLog\SmtpSend"
[string]$FrontentTransportReceiveUncLogPath = "E$\Program Files\Microsoft\Exchange Server\V15\TransportRoles\Logs\Frontend\ProtocolLog\SmtpReceive"
[string]$FrontendTransportSendUncLogPath = "E$\Program Files\Microsoft\Exchange Server\V15\TransportRoles\Logs\Frontend\ProtocolLog\SmtpSend"

# local variables
[string]$IisSubFolderName = "IIS"
[string]$HubTransportSubFolderName = "Hub"
[string]$FrontendTransportSubFolderName = "Frontend"

# 2015-06-18: Implementation of global module
Import-Module BDRFunctions
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
$ScriptName = $MyInvocation.MyCommand.Name
$logger = New-Logger -ScriptRoot $ScriptDir -ScriptName $ScriptName -LogFileRetention 14
$logger.Write("Script started")
$logger.Write("Gathering log files for $($DaysToFetch) days")

function Check-Folders {
    # Check, if we need to create new folders
    if(!(Test-Path $LogFileRoot)) {
        # Folder does not exist, lets create a new root folder
        New-Item -Path $LogFileRoot -ItemType Directory | Out-Null
        $logger.Write("Folder $($LogFileRoot) created")
    }

    $functionFolderPath = Join-Path $LogFileRoot -ChildPath $functionalFolder

    if(!(Test-Path $functionFolderPath)) {
        # Functional folder does not exist, lets create a new root folder
        New-Item -Path $functionFolderPath -ItemType Directory | Out-Null
        $logger.Write("Folder $($functionFolderPath) created")
    }
    
    If(Test-Path $LogFileRoot) {
        $folderPath = Join-Path -Path $functionFolderPath -ChildPath $E15Server
        If((Test-Path $folderPath) -and ($CleanFolders)) {
            # Folder exists and is requested to be deleted
            Remove-Item $folderPath -Recurse -Force -Confirm:$false | Out-Null            
            $logger.Write("Folder $($folderPath) deleted (cleaned)")
        }
        If(!(Test-Path $folderPath)) {
            # Folder does not exist, lets create a new sub folder
            New-Item -Path $folderPath -ItemType Directory | Out-Null
            $logger.Write("Folder $($folderPath) created")
        }
    }
}

function Gather-LogFiles {
    
    $functionFolderPath = Join-Path $LogFileRoot -ChildPath $functionalFolder

    $targetPath = Join-Path -Path $functionFolderPath -ChildPath $E15Server

    # Only try to delete files, if folder exists
    if (Test-Path $SourceServerFolder) {
        
        $Now = Get-Date
        $LastWrite = $Now.AddDays(-($DaysToFetch))

        # Select files to copy
        $Files = Get-ChildItem $SourceServerFolder -Include *.log -Recurse | Where {$_.LastWriteTime -ge "$LastWrite"}

        # Lets count the files that will be copied
        $fileCount = 0

        # Copy the files
        foreach ($File in $Files)
        {            
            Copy-Item -Path $File -Destination $targetPath -Force -Confirm:$false | Out-Null
            $fileCount++
        }
        $logger.Write("$($fileCount) files copied from $($SourceServerFolder)")
    }
}

# MAIN ####################################################
# Get a list of all Exchange 2013 servers
$Ex2013 = Get-ExchangeServer | Where {$_.IsE15OrLater -eq $true} | Sort-Object Name

if($IIS) {
    # Gather IIS logs
    $functionalFolder = $IisSubFolderName

    # Gather files for each Exchange 2013 Server
    foreach ($E15Server In $Ex2013) {
        $SourceServerFolder = "\\" + $E15Server + "\" + $IisUncLogPath
        
        Check-Folders
        Gather-LogFiles
    }
}
elseif($HubTransport) {
    # Gather Hub transport logs
    $functionalFolder = $HubTransportSubFolderName
   
    # Gather files for each Exchange 2013 Server
    foreach ($E15Server In $Ex2013) {

        $SourceServerFolder = "\\" + $E15Server + "\" + $HubTransportReceiveUncLogPath

        Check-Folders
        Gather-LogFiles

        $SourceServerFolder = "\\" + $E15Server + "\" + $HubTransportSendUncLogPath

        Gather-LogFiles

    }
}
elseif($FrontendTransport) {
    # Gather Frontend logs
    $functionalFolder = $FrontendTransportSubFolderName
   
    # Gather files for each Exchange 2013 Server
    foreach ($E15Server In $Ex2013) {

        $SourceServerFolder = "\\" + $E15Server + "\" + $FrontentTransportReceiveUncLogPath

        Check-Folders
        Gather-LogFiles

        $SourceServerFolder = "\\" + $E15Server + "\" + $FrontendTransportSendUncLogPath

        Gather-LogFiles

    }
}
else {
    Write-Host "No log file source type has been defined. Please check help section of the script."
}

$logger.Write("Script finished")
Write-Host "Script finished"