# Author: Dean Camenzuli
# Revision: v1.0
# Date: 30/03/2018
#
# Requirements: Access Dynatrace User Session Query endpoint.
# Convert incoming JSON to parsable flat CSV file.
# Endgoal: Be able to capture user session data and detailed timings (per browser) for each user action
# Script has been tested running on PowerShell v3
#

# ChangeLog
# 1.0 | 30/03/2018 | Dean Camenzuli | Initial creation
#

# Query used in API explorer
# SELECT userAction.Name, browserType, browserFamily,, browserMajorVersion, AVG(userAction.networkTime), AVG(userAction.serverTime), AVG(userAction.frontendTime), AVG(userAction.visuallyCompleteTime), COUNT(*) FROM usersession GROUP BY userAction.Name, browserType, browserFamily,, browserMajorVersion
# 

# helper function to turn PSCustomObject into a list of key/value pairs
function Get-ObjectMembers {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [AllowEmptyString()]
        [PSCustomObject]$obj
    )
    $obj | Get-Member -MemberType NoteProperty | ForEach-Object {
        $key = $_.Name
        [PSCustomObject]@{Key = $key; Value = $obj."$key"
        }
    }
}

$fileOut = "API Export.csv"
$fileOutput = @()

# Time variables to modify the request URL to run over the last 7 days instead of needing to generate a new request URL each run
$numOfDays = Read-Host -Prompt "Report run over last 'X' days. `nSpecify X"
$endTime = [Math]::Round(((Get-Date -Hour 0 -Minute 00 -second 00).ToFileTime() / 10000000 - 11644473600)*1000)
$startTime = [Math]::Round((((Get-Date -Hour 0 -Minute 00 -second 00).AddDays(-$numOfDays)).ToFileTime() / 10000000 - 11644473600)*1000)

"`nReport timeframe:"
"Start Time: " + (Get-Date -Hour 0 -Minute 00 -second 00).AddDays(-$numOfDays)
"End Time: " + (Get-Date -Hour 0 -Minute 00 -second 00)

# Grab the jsonRequestURL (generated through API explorer) and convert it into a PSCustomObject
$web_client = new-object System.Net.WebClient
$jsonRequestURL = "[API REQUEST URL - INCLUDE THE START AND END TIME HERE]"
$jsonContents = $web_client.DownloadString($jsonRequestURL) | ConvertFrom-Json

"`nAPI Call Completed and loaded into PSCustomObject"

# Convert the first part of the PSCustomObject into Key/Value Pairs
$jsonEntities = $jsonContents.values | Get-ObjectMembers

# Begin looping through all the items in the custom object to the correct variable names to print the rows later
foreach($i in $jsonEntities)
{
    $userActionName = $i.key
    $city = ""
    $userCount = ""

    $jsonInner01 = $i.value | Get-ObjectMembers

    foreach($a in $jsonInner01)
    {
        $browserType = $a.key

        $jsonInner02 = $a.value | Get-ObjectMembers

        foreach($b in $jsonInner02)
        {
            $browserFamily = $b.key

            $jsonInner03 = $b.value | Get-ObjectMembers

            foreach($c in $jsonInner03)
            {
                $browserMajorVersion = $c.key

                $networkTime = $c.value[0]
                $serverTime = $c.value[1]
                $frontendTime = $c.value[2]
                $visuallyCompleteTime = $c.value[3]
                $sessionCount = $c.value[4]

                # Assign the collected values to a row for export to excel
                $row = New-Object PSObject
                $row | Add-Member -MemberType NoteProperty -Name 'User Action Name' -Value $userActionName
                $row | Add-Member -MemberType NoteProperty -Name 'Browser Type' -Value $browserType
                $row | Add-Member -MemberType NoteProperty -Name 'Browser Family' -Value $browserFamily
                $row | Add-Member -MemberType NoteProperty -Name 'Browser Version' -Value $browserMajorVersion
                $row | Add-Member -MemberType NoteProperty -Name 'Network Time' -Value $networkTime
                $row | Add-Member -MemberType NoteProperty -Name 'Server Time' -Value $serverTime
                $row | Add-Member -MemberType NoteProperty -Name 'Frontend Time' -Value $frontendTime
                $row | Add-Member -MemberType NoteProperty -Name 'Visually Complete Time' -Value $visuallyCompleteTime
                $row | Add-Member -MemberType NoteProperty -Name 'User Session Count' -Value $sessionCount
                $fileOutput += $row
            }
        }
    }
}

# Export to csv
$fileOutput | Export-CSV $fileOut -NoTypeInformation
"`nLocation of export:"
(Get-Item -Path ".\").FullName
Read-Host -Prompt "`nExecution completed. Press enter to exit"
