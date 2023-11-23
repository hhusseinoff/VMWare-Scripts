# Last Edited: June 13th, 2023

## This script connects to the vCenter server and checks if a specific snapshot exists for the VM that executes the script.
## It requires the vCenter server name and an account name with its associated encryption key.

## The account used must have sufficient permissions on the vCenter server.

## The encryption key for the account password is expected as a comma-separated string.
## It is transcribed into a byte array to convert the encrypted password back into a secure string.

## The encrypted password is loaded from a 'crypto.txt' file located in the same directory as the script.

## Logs are generated for each operation and are saved to a file at C:\Temp\VMWareSnapshotChecker\SnapshotChecker.log.

## The script checks for known non-VM machines and mismatches between in-OS machine names and VM names.
## These known non-VM machines and name mismatches should be entered into the $KnownNonVMs array and $machineNameMismatches hashtable, respectively.
## If the machine name is found in $KnownNonVMs, the script will log a message and exit.
## If the machine name is found in $machineNameMismatches, the script will replace the machine name with the corresponding VM name before continuing.

## Exit codes:
## 0: The script completed successfully and the snapshot exists.
## 1: The VMware.PowerCLI module was not found on the machine where the script is run.
## 2: Connection to the vCenter server could not be established.
## 3: The script failed to retrieve the VM Object.
## 4: No available snapshots exist, OR there was an error during snapshots retrieval.
## 5: A snapshot of the specified name doesn't exist on the machine.
## 6: The machine is a known non-VM.

## Notes:
## The script is to be run with an account that has sufficient permissions on the vCenter server.
## The script will create a log file at C:\Temp\VMWareSnapshotChecker\SnapshotChecker.log.
## The log file will contain detailed information about each operation that the script performs.
## All of the above information and processes are made explicit through the debug log outputs in the script.


param(
    [Parameter(Mandatory=$true)]
    [string]$vCenterServer,
    [Parameter(Mandatory=$true)]
    [string]$SnapshotName,
    [Parameter(Mandatory=$true)]
    [string]$AccountName,
    [Parameter(Mandatory=$true)]
    [string]$AccEncryptionKey
)

## Define a hashtable for the machines which are known to have a mismatch between the in-OS name and the VM Name
$machineNameMismatches = @{
    "DNSName1" = "ActualVMName1"
    "DNSName2" = "ActualVMName2"
}

## Define an array of names of machines that are known not to be Virtual machines.
$KnownNonVMs = @("Name1", "Name1", "Name2", "Name3", "Name4")

# Capture script directory
$ScriptDir = $PSScriptRoot

# Define log folder root
$LogFolderRoot = "C:\Temp"

# Create folders if they don't exist
if(!(Test-Path -Path $LogFolderRoot)) {
    New-Item -ItemType Directory -Force -Path $LogFolderRoot
}

# Define log folder path
$LogFolderPath = "C:\Temp\VMWareSnapshotChecker"

# Create folders if they don't exist
if(!(Test-Path -Path $LogFolderPath)) {
    New-Item -ItemType Directory -Force -Path $LogFolderPath
}

# Custom logging function
function debug($message) {
    $logMessage = "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message"
    Write-Host $logMessage
    Add-Content -Path "$LogFolderPath\SnapshotChecker.log" -Value $logMessage -Force
}

debug "------------------------------------------------------------------------------------------------------------------------------------------------"

# Check if the VMware.PowerCLI module is available
if (-not (Get-Module -Name VMware.PowerCLI -ListAvailable)) {
    
    debug "VMware.PowerCLI module was not found. Exiting with error code 1..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"
    
    exit 1
}

debug "Starting the SnapshotChecker script for vCenter server: $vCenterServer. VM: $VMName. Snapshot: $SnapshotName"

debug "Converting encryption key from a comma-separated string to an array of strings..."

$AccEncryptionKeyStringArray = $AccEncryptionKey.Split("#")

debug "Creating a byte array object..."

$byteArray = New-Object Byte[] 16

$count = 0

debug "Transcribing the encryption key to the byte array..."

foreach($element in $AccEncryptionKeyStringArray)
{
    $elementInByte = [byte]$element
    $byteArray[$count] = $elementInByte
    $count = $count + 1
}

debug "Loading encrypted password from $ScriptDir\crypto.txt..."

$encryptedPassword = (Get-Content -Path "$ScriptDir\crypto.txt")

debug "Converting encrypted password to a secure string..."

$securePassword = ConvertTo-SecureString -String $encryptedPassword -Key $byteArray

debug "Constructing a PSCredential object..."

$credential = [pscredential]::new($AccountName,$securePassword)

debug "Connecting to the vCenter server..."

$vCenterConnection = Connect-VIServer -Server servername.com -Credential $credential -ErrorAction SilentlyContinue

if($null -eq $vCenterConnection)
{
    debug "Connection establishment failed."

    debug "Error: $($Error[0]). Exiting with error code 2..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    exit 2
}

debug "Successfully connected to the vCenter server."

debug "Proceeding to get the machine name..."

# Get the machine's fully qualified domain name
$MachineName = $env:COMPUTERNAME

debug "Machine name: $MachineName."

debug "Checking if $MachineName is a known non-VM..."

$NonVMCheck = $KnownNonVMs.Contains($MachineName)

if($true -eq $NonVMCheck)
{
    debug "$MachineName is a known non-VM. Snapshot checking will not be performed."

    debug "Script exiting..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    exit 0
}

debug "Known non-VM Check passed."

debug "Checking if $MachineName is one of the known machines with a mismatch between the OS name and VM name..."

$NamesMismatchCheck = $machineNameMismatches.ContainsKey($MachineName)

if($true -eq $NamesMismatchCheck)
{
    debug "$MachineName is known to have a mismatch between the in-OS name and the VM Name."

    debug "Reconfiguring the MachineName used for VMWare queries..."

    $MachineName = $machineNameMismatches[$MachineName]

    debug "Name reconfigured: $MachineName"
}

debug "Retrieving VM object for $MachineName..."

$vmObject = Get-VM -Name $MachineName -ErrorAction SilentlyContinue

if($null -eq $vCenterConnection)
{
    debug "Failed to retrieve a VM object for $MachineName"

    debug "Error: $($Error[0]). Exiting with error code 3..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    exit 3
}

debug "VM Object retrieved successfully."

debug "Retrieving a snapshot object for available snapshots on $MachineName..."

$availableSnapshots = Get-Snapshot -VM $vmObject -ErrorAction SilentlyContinue

if($null -eq $availableSnapshots)
{
    debug "No available snapshots for $MachineName exist, OR there was an error during snapshots retrieval."

    debug "Error: $($Error[0]). Exiting with error code 4..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    exit 4
}

debug "Successfully retrieved info on available snapshots for $MachineName."

debug "Checking for snapshots on $MachineName named $SnapshotName..."

$hasSnapshot = $availableSnapshots.Name -contains "$SnapshotName"

if($false -eq $hasSnapshot)
{
    debug "Snapshot named $SnapshotName DOES NOT EXIST on $MachineName."

    debug "Script execution finished."

    debug "Exiting with error code 5..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    exit 5
}
else
{
    debug "Snapshot named $SnapshotName FOUND on $MachineName."

    debug "Script execution finished."

    debug "Exiting with error code 0..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    exit 0 
}