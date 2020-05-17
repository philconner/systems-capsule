Two scripts that together configure all zabbix hosts running on windows.

### Config-ZabbixAgent
This script is run through SCCM.

### Invoke-ConfigZabbixAgent
This script should be run from the commandline, and requires the following two Powershell modules:
* ConfigurationManager
    * Comes with the SCCM console installation, but can also be installed on its own.
* SimplySql
    * Can be installed with 'Install-Module SimplySql'.
