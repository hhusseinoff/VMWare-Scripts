## Last Edited: June 12th, 2023

<#
.SYNOPSIS
This script is designed to schedule a job for creating VM snapshots. 

.DESCRIPTION
The script first presents a list of available vCenter Servers to the user. The user then selects 
a vCenter server and inputs various details such as snapshot name, time for the snapshot to be 
taken, and the list of VMs to be snapshotted. 

The script writes these details into a Job file that is used later when the script is run as a 
scheduled task to execute the snapshotting job. 

The script also contains a simple logging functionality that writes script actions and user inputs 
to a log file. 

#>

$vCentersList = @(
    "name1.com"
)

$chosenVcenterServer = "blank"

# Capture the directory that the script executes from:
$scriptDirectory = $PSScriptRoot

# Define log folder path
$LogFolderPath = "$scriptDirectory\Logs"

# Define Jobs folder path
$JobsFolderPath = "$scriptDirectory\Jobs"

if(!(Test-Path -Path $LogFolderPath)) {
    New-Item -ItemType Directory -Force -Path $LogFolderPath -Confirm:$false
}

if(!(Test-Path -Path $JobsFolderPath)) {
    New-Item -ItemType Directory -Force -Path $JobsFolderPath -Confirm:$false
}

# Custom logging function
function debug($message) {
    $logMessage = "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message"
    Write-Host $logMessage -ForegroundColor Green -BackgroundColor Black
    Add-Content -Path "$LogFolderPath\SchedulerLog.log" -Value $logMessage -Force
}

debug "--------------------------------------------------------------------------------------------------------------------------------------------"
debug "Script started."

$userInput = Read-Host -Prompt "Schedule a new job? (Y/N)"

if(($userInput -ne "N") -and ($userInput -ne "n") -and ($userInput -ne "Y") -and ($userInput -ne "y"))
{
    debug "Bad input, expected either Y, N, y or n. Script exiting..."
    debug "--------------------------------------------------------------------------------------------------------------------------------------------"
    exit 0
}

if(($userInput -eq "N") -or ($userInput -eq "n"))
{
    debug "User selected not to schedule a new job. Exiting..."
    debug "--------------------------------------------------------------------------------------------------------------------------------------------"
    exit 0
}

if(($userInput -eq "Y") -or ($userInput -eq "y"))
{
    debug "Beginning to schedule a new job."
    debug "List of all available vCenters:"
    debug " "
    debug "$vCentersList"
    debug " "
    debug "Prompting user for vCenter Server selection..."

    $userInput2 = Read-Host -Prompt "Please choose which vCenter Server hosts the VMs. 0 = item 1, 1 = item 2, etc..."
    $uservCenterChoice = [int]$userInput2
    $vCentersListSize = $vCentersList.Length

    if($uservCenterChoice -gt ($vCentersListSize - 1))
    {
        debug "Invalid input. Script exiting..."
        debug "--------------------------------------------------------------------------------------------------------------------------------------------"
        exit 0
    }

    $chosenVcenterServer = $vCentersList[$uservCenterChoice]
    debug "User selected $uservCenterChoice : $chosenVcenterServer"
    debug "Attempting to load the list of VMs..."

    try
    {
        $InputVMList = Get-Content -Path "$scriptDirectory\Input.txt" -Force -ErrorAction Stop
    }
    catch
    {
        $errorMsg = $_.Exception.Message
        debug "Error when trying to load the list of VMs: $errorMsg"
        debug "--------------------------------------------------------------------------------------------------------------------------------------------"
        exit 0
    }

    debug "Input VM List loaded:"
    debug "$InputVMList"
    debug "Prompting for the desired snapshotting time..."
    $userDateTimeInput = Read-Host -Prompt "Please enter a date and time for when the snapshots should taken !!! (MM/dd/yyyy HH:mm) !!!"

    try
    {
        $SnapshotDateTime = Get-Date -Format "MM/dd/yyyy HH:mm" -Date $userDateTimeInput -ErrorAction Stop
    }
    catch
    {
        $errorMsg = $_.Exception.Message
        debug "Error when entering desired snapshot taking time: $errorMsg"
        debug "--------------------------------------------------------------------------------------------------------------------------------------------"
        exit 0
    }

    debug "Prompting for desired snapshot Name..."
    $userSnapshotNameChoice = Read-Host -Prompt "Please enter a name for the VM Snapshots."
    debug "User chose this name for the snapshots: $userSnapshotNameChoice"
    debug "Creating the Job file at $scriptDirectory..."

    $JobCreationTime = Get-Date -Format yyyy_MM_dd__HH_mm

    foreach($machine in $InputVMList)
    {
        Add-Content -Path "$JobsFolderPath\Job_$JobCreationTime.txt" -Value "$chosenVcenterServer`t$SnapshotDateTime`t$userSnapshotNameChoice`t$machine" -Force -Confirm:$false
    }

    debug "Job scheduling and file creation complete. File path: $scriptDirectory\Job_$JobCreationTime.txt"
    debug "Script exiting..."
    debug "--------------------------------------------------------------------------------------------------------------------------------------------"
    exit 0
}

