$ModuleDescription = Get-ChildItem -Path $PSScriptRoot -Filter '*.psd1' | Select-Object -First 1
$ModuleDescription | Select-Object -ExpandProperty FullName | ForEach-Object {Import-Module $_ -Force}
# Set the most constrained mode
Set-StrictMode -Version Latest
# Set the error preference
$ErrorActionPreference = 'Stop'
# Set the verbose preference in order to get some insights
# $VerbosePreference = 'Continue'
$DebugStart = Get-Date
Write-Host '------------------- Starting script -------------------' -ForegroundColor Yellow
############################
# Test your functions here #
############################

# $PSURoleSplat = Get-PSURoleSplatFromFile -Path 'C:\ProgramData\PowerShellUniversal\CustomAssets\Role.xml'
# Get-PSURoleFromFile -Path 'C:\ProgramData\PowerShellUniversal\CustomAssets\Role.json'
$Result = Publish-PSUServer -path 'C:\ProgramData\UniversalAutomation\Repository\DynamicServer\Main.xml' -Verbose -ErrorAction Stop 
$Result
##################################
# End of the tests show metrics #
##################################

Write-Host '------------------- Ending script -------------------' -ForegroundColor Yellow
$TimeSpentInDebugScript = New-TimeSpan -Start $DebugStart -Verbose:$False -ErrorAction SilentlyContinue
$TimeUnits = [ordered]@{TotalDays = "$($TimeSpentInDebugScript.TotalDays) D.";TotalHours = "$($TimeSpentInDebugScript.TotalHours) h.";TotalMinutes = "$($TimeSpentInDebugScript.TotalMinutes) min.";TotalSeconds = "$($TimeSpentInDebugScript.TotalSeconds) s.";TotalMilliseconds = "$($TimeSpentInDebugScript.TotalMilliseconds) ms."}
foreach ($Unit in $TimeUnits.GetEnumerator()) {if ($TimeSpentInDebugScript.$($Unit.Key) -gt 1) {$TimeSpentString = $Unit.Value;break}}
if (-not $TimeSpentString) {$TimeSpentString = "$($TimeSpentInDebugScript.Ticks) Ticks"}
Write-Host 'Ending : ' -ForegroundColor Yellow -NoNewLine
Write-Host $($MyInvocation.MyCommand) -ForegroundColor Magenta -NoNewLine
Write-Host ' - TimeSpent : ' -ForegroundColor Yellow -NoNewLine
Write-Host $TimeSpentString -ForegroundColor Magenta