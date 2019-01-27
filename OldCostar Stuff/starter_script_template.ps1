<# 
.SYNOPSIS 
    **Tell the user what this script does**
	** Note: this help information does not work if you call the script from UNC path**
.SYNTAX
	**script-name [-SomeSwitch] <string> [-BooleanSwitch] **
.DESCRIPTION 
    **This script is used to perform XYZ operations on ABC**
.NOTES 
    File Name  : **name of this script file**
    Author     : **John Smith**
    Requires   : PowerShell V2 CTP3 
.LINK 
   **Optionally add a link to where this script lives**
.PARAMETER Comp
    The computer you want to ping - should be resolvable by DNS
.EXAMPLE 
    PSH [C:\foo]:  .\Get-PingStaus.ps1 blogger.com
    Computer to ping:       blogger.com
    Computer responded in:  127ms
.EXAMPLE
    PSH [C:\foo]: "blogger.com", "Localhost" | . 'C:\foo\to post\get-pingstatus.PS1'
    Computer to ping:       blogger.com
    Computer responded in:  127ms
    Computer to ping:       Localhost
    Computer responded in:  0ms
.EXAMPLE
    PSH [C:\foo]:  .\Get-PingStaus.ps1 
    Computer to ping:       localhost
    Computer responded in:  0ms
#> 

"hello"