# Get-Logs.ps1

Copy IIS or transport protocol log files from Exchange 2013/2016/2019 Servers to a single location for better log file analysis.

## Description

This script copies IIS log or other selected Exchange log files from all Exchange servers to a single target root folder creating subfolders for each source server.

The log files need to have the same root folder across all Exchange 2013/2016/2019 servers.

The script is intended to run from within an active Exchange 2013/2016/2019 Management Shell session.

## Requirements

- Windows Server Windows Server 2012 R2+
- Exchange Server 2013/2016/2019 Management Shell
- Utilizes global functions library

## Parameters

### DaysToFetch

Number of days IIS log files should be gatheredretained, default is 1 day

### LogFileRoot

Local IIS log file root to store copied log files, default E:\GatheredLogs

### CleanFolder

Switch to delete per Exchange Server subfolders and creating new folders

### IIS

Switch to gather IIS log files from all Exchange 2013/2016/2019 servers. Creates a subfolder named 'IIS'.

### HubTransport

Switch to gather Hub transport SMTP protocol logs from all Exchange 2013/2016/2019 servers. Creates a subfolder named 'Hub'.

### FrontendTransport

Switch to gather Frontend transport SMTP protocol logs from all Exchange 2013/2016/2019 servers. Creates a subfolder names 'Frontend'.

### EWS

Switch to gather EWS protocol logs from all Exchange 2013/2016/2019 servers. Creates a subfolder names 'EWS'.

## Examples

``` PowerShell
.\Get-Logs.ps1 -IIS
```

Copy IIS Frontend and Backend W3SVC log files

``` PowerShell 
.\Get-Logs.ps1 -CleanFolders -IIS
```

Delete local subfolders and copy IIS log files

``` PowerShell 
.\Get-Logs.ps1 -CleanFolders -FrontendTransport -DaysToFetch 5
```

Delete local subfolders and copy frontend transport logs for the last 5 days

## Note

THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE
RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.

## Credits

Written by: Thomas Stensitzki

## Stay connected

- My Blog: [http://justcantgetenough.granikos.eu](http://justcantgetenough.granikos.eu)
- Twitter: [https://twitter.com/stensitzki](https://twitter.com/stensitzki)
- LinkedIn: [http://de.linkedin.com/in/thomasstensitzki](http://de.linkedin.com/in/thomasstensitzki)
- Github: [https://github.com/Apoc70](https://github.com/Apoc70)
- MVP Blog: [https://blogs.msmvps.com/thomastechtalk/](https://blogs.msmvps.com/thomastechtalk/)
- Tech Talk YouTube Channel (DE): [http://techtalk.granikos.eu](http://techtalk.granikos.eu)

For more Office 365, Cloud Security, and Exchange Server stuff checkout services provided by Granikos

- Blog: [http://blog.granikos.eu](http://blog.granikos.eu)
- Website: [https://www.granikos.eu/en/](https://www.granikos.eu/en/)
- Twitter: [https://twitter.com/granikos_de](https://twitter.com/granikos_de)