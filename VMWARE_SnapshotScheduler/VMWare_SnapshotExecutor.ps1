## Author: Your Name
## Last Edited: June 13th, 2023
## Script Name: VM Snapshot Executor
## Description: 
## - This script takes snapshots of virtual machines (VMs) according to instructions in job files.
## - It sets up logging, connects to the vCenter server, gracefully shuts down VMs, takes a snapshot, and powers the VMs back on.
## - The script processes all job files present in the "Jobs" directory, taking care of multiple job files and avoiding overlaps.
## - It handles errors gracefully, for example, when unable to connect to a vCenter, or when a VM fails to shutdown.
## - The script includes a progress tracking system for long-running tasks like waiting for a VM to shutdown.
## - Once the snapshots have been taken, it deletes the corresponding job file.
## - All actions are logged for review.
## Paths:
## - Script execution directory: $scriptDirectory
## - Log folder path: $LogFolderPath
## - Jobs folder path: $JobsFolderPath
## Job File Structure:
## - Each line of a job file should contain the following, separated by tabs:
##    - vCenter ServerName
##    - Snapshot taking time
##    - Snapshot Name
##    - Machine Name


# Capture the directory that the script executes from:
$scriptDirectory = $PSScriptRoot

# Define log folder path
$LogFolderPath = "$scriptDirectory\Logs"

# Define Jobs folder path
$JobsFolderPath = "$scriptDirectory\Jobs"

# VCenter connection variable
$vCenterConnection = "blank"

# Snapshot Taking Buffer time
$SnapshotBufferTime = New-TimeSpan -Minutes 15

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
    Add-Content -Path "$LogFolderPath\Executor.log" -Value $logMessage -Force
}

Function Sleep-Progress($Seconds) {
    $s = 0;
    Do {
        $p = [math]::Round(100 - (($Seconds - $s) / $seconds * 100));
        Write-Progress -Activity "Waiting..." -Status "$p% Complete:" -SecondsRemaining ($Seconds - $s) -PercentComplete $p;
        [System.Threading.Thread]::Sleep(1000)
        $s++;
    }
    While($s -lt $Seconds);
    
}

function ProcessJobFile([string]$jobFile) {
    debug "Processing job file $jobFile..."

    $content = (Get-Content -Path "$JobsFolderPath\$jobFile")

    if(!($content))
    {
        debug "Failed to load content. Exiting..."
        debug "--------------------------------------------------------------------------------------------------------------------------------------------"
        return
    }

    # Code to process a job file...
    debug "Content loaded. Initiating main loop..."

    :MainLoop foreach($line in $content)
    {
        $EntryArray = $line.Split("`t")

        $extractedvCenter = $EntryArray[0]

        $extractedSnapshotTime = $EntryArray[1]

        $extractedSnapshotName = $EntryArray[2]

        $extractedMachineName = $EntryArray[3]

        debug "Extracted Entry data:"

        debug "Extracted vCenter ServerName | Extracted Snapshot taking time | Extracted Snapshot Name | Extracted Machine Name"

        debug "$extractedvCenter | $extractedSnapshotTime | $extractedSnapshotName | $extractedMachineName"

        $EntryArray = $null

        debug "Checking the current time..."

        $currentTime = Get-Date

        debug "Converting $extractedSnapshotTime to a DateTime Object..."

        $provider = [System.Globalization.CultureInfo]::InvariantCulture

        $format = "MM/dd/yyyy HH:mm"

        $ConvertedSnapshotTime = [DateTime]::ParseExact($extractedSnapshotTime, $format, $provider)

        debug "$extractedSnapshotTime converted to $ConvertedSnapshotTime"

        $BufferTimeCheck = $ConvertedSnapshotTime - $currentTime

        if($BufferTimeCheck -gt $SnapshotBufferTime)
        {
            debug "As of $currentTime the desired Snapshot Capture time of $ConvertedSnapshotTime hasn't been reached."

            debug "Exiting loop and script..."

            debug "--------------------------------------------------------------------------------------------------------------------------------------------"

            exit 0
        }

        if(($vCenterConnection -eq $null) -or ($vCenterConnection -eq "blank"))
        {
            debug "Connecting to $extractedvCenter..."

            try
            {
                $connectionVC = Connect-VIServer -Server $extractedvCenter -ErrorAction Stop
            }
            catch
            {
                $errorMsg = $_.Exception.Message
                debug "Error trying to connect to $extractedvCenter : $errorMsg"
                debug "--------------------------------------------------------------------------------------------------------------------------------------------"
                exit 0
            }
        }

        debug "vCenter Connection to $extractedvCenter established or already present."

        debug "Checking if the VM is powered on..."

        $VMObject = Get-VM -Name $extractedMachineName

        if($VMObject -eq $null)
        {
            debug "Failed to retrieve the Object for VM $extractedMachineName. Proceeding to the next entry"

            continue MainLoop
        }

        $VMPWState = $VMObject.PowerState

        if("PoweredOn" -eq $VMPWState)
        {
            debug "Gracefully shutting down $extractedMachineName, before capturing the snapshot..."

            $ShutdownAttempt = Shutdown-VMGuest -VM $VMObject -Server $extractedvCenter -Confirm:$false

            if($null -eq $ShutdownAttempt)
            {
                debug "Failed to initiate a graceful shutdown. Executing a hard stop... "

                $HardStopCheck = Stop-VM -VM $VMObject -Confirm:$false

                if($null -eq $HardStopCheck)
                {
                    debug "Hard stop failed. Proceeding to the next VM..."

                    continue MainLoop
                }
            }

            debug "Shutdown attempt succesful. The OS will need some time to execute. Waiting for 60s..."

            Sleep-Progress -Seconds 60

            debug "Checking VM Power State..."

            $VMObject = Get-VM -Name $extractedMachineName

            $VMPWState = $VMObject.PowerState

            if("PoweredOn" -eq $VMPWState)
            {
                debug "VM Still hasn't shut down. Waiting an addition 180s..."

                Sleep-Progress -Seconds 180

                debug "Rechecking Power State..."

                $VMObject = Get-VM -Name $extractedMachineName

                $VMPWState = $VMObject.PowerState

                if("PoweredOn" -eq $VMPWState)
                {
                    debug "VM still hasn't shut down. Executing a hard stop..."

                    $HardStopCheck = Stop-VM -VM $VMObject -Confirm:$false

                    if($null -eq $HardStopCheck)
                    {
                        debug "Hard stop failed. Proceeding to the next VM..."

                        continue MainLoop
                    }
                }
            }
        }

        debug "Creating snapshot named $extractedSnapshotName for $extractedMachineName..."

        $SnapshotCreationCheck = New-Snapshot -VM $VMObject -Name $extractedSnapshotName -Server $extractedvCenter

        if($null -eq $SnapshotCreationCheck)
        {
            debug "Failed to create snapshot. Proceeding to the next VM..."

            continue MainLoop
        }

        debug "Snapshot Created. Powering the system back on..."
        
        $startupCheck = Start-VM -VM $VMObject -Confirm:$false -Server $extractedvCenter

        if($null -eq $startupCheck)
        {
            debug "Failed to power $extractedMachineName back on. Proceeding to next VM..."

            continue MainLoop
        }

        debug "Operations for $extractedMachineName complete. Proceeding to next VM..."

        continue MainLoop

    }

    debug "All items snapshotted. Deleting job file $jobFile..."

    Remove-Item -Path "$JobsFolderPath\$jobFile" -Force -confirm:$false

    debug "Job file $jobFile deleted. Process completed..."

    debug "--------------------------------------------------------------------------------------------------------------------------------------------"
}

debug "--------------------------------------------------------------------------------------------------------------------------------------------"
debug "Script started."

debug "Scanning for pending Job files at $JobsFolderPath..."

$JobFiles = Get-ChildItem -Path $JobsFolderPath -Filter "Job_*.txt" | Where-Object { $_.Name -match "Job_\d{4}_\d{2}_\d{2}__\d{2}_\d{2}.txt" }

if($JobFiles.Count -eq 0)
{
    debug "No Job files found. Script exiting..."
    debug "--------------------------------------------------------------------------------------------------------------------------------------------"
    exit 0
}
elseif($JobFiles.Count -gt 1)
{
    debug "Multiple Job files found. Please ensure there is only one Job file. Script exiting..."
    debug " "

    # Sort files based on date-time in the name and process each file

    $JobFiles | Sort-Object { [DateTime]::ParseExact($_.Name.Substring(4,19), 'yyyy_MM_dd__HH_mm', $null) } | ForEach-Object {
        ProcessJobFile $_.Name
    }

    debug "All job files processed. Script exiting..."

    debug "--------------------------------------------------------------------------------------------------------------------------------------------"

    exit 0
}
else
{
    debug "One Job file found:"
    debug " "

    foreach($file in $JobFiles)
    {
        $FoundFileName = $file.Name

        debug "$FoundFileName"
    }

    # Process the single job file
    ProcessJobFile $FoundFileName

    debug "All items snapshotted. Script exiting..."
    debug "--------------------------------------------------------------------------------------------------------------------------------------------"
    exit 0
}