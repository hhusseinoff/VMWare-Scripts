function debug($message)
{
    write-host "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message" -BackgroundColor Black -ForegroundColor Green
    Add-Content -Path "$PSScriptRoot\AppropriateVLANs.log" -Value "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message" 
}

##Check if input file exists. If Not, script will not run
##---------------------------------------------------------------------------------------------------------------------------------

$InputExists = Test-Path -Path "$PSScriptRoot\VLANMapping_EU.txt" -PathType Leaf

if($false -eq $InputExists)
{
    debug "Script will not run. Input file not found!"

    Exit 1
}

debug "------VLAN appropriation script by Señor José Garcia initiated------"

debug "Loading input file..."

$InputData = (Get-Content -Path "$PSScriptRoot\VLANMapping_EU.txt")

if($null -eq $InputData)
{
    debug "Script will not run. Input file failed to load!"
}

##---------------------------------------------------------------------------------------------------------------------------------

debug "Input File loaded"

:MainLoop foreach($Entry in $InputData)
{
    if($Entry -like "*VLAN*")
    {
        debug "Skipping Header Line"
        
        continue MainLoop
    }

    debug "Working on $Entry"

    $FragmentedArray = $Entry.Split("`t")

    $ExtractedXD_DG = $FragmentedArray[0]
    $ExtractedXD_Controller = $FragmentedArray[1]
    $ExtractedVcenters = $FragmentedArray[2]
    $ExtractedVLANs = $FragmentedArray[3]

    $ExtractedVcentersList = $ExtractedVcenters

    $ExtractedVcentersList = $ExtractedVcentersList.Split(",")

    $ExtractedVLANsList = $ExtractedVLANs

    $ExtractedVLANsList = $ExtractedVLANsList.Split(",")



    debug "Working on delivery group $ExtractedXD_DG on controller $ExtractedXD_Controller"

    ##get XD Objects array for all desktops in the DG

    debug "Getting all machines from $ExtractedXD_DG..."

    $DG_Array = Get-BrokerMachine -DesktopGroupName $ExtractedXD_DG -AdminAddress $ExtractedXD_Controller


    :DesktopsLoop foreach($Desktop in $DG_Array)
    {
        $DesktopName = $Desktop.HostedMachineName
        
        $HypervisorName = $Desktop.HypervisorConnectionName

        debug "Working on $DesktopName in $ExtractedXD_DG..."

        $counterVar = 0

        debug "Counter set."

        debug "Looking for the VCenter that the machine is hosted on..."

        :FindVcenter foreach($VcenterEntry in $ExtractedVcentersList)
        {

            debug "HypervisorName is: $HypervisorName, VCenter being queried is: $VcenterEntry"

            if($VcenterEntry -match $HypervisorName)
            {
                debug "Match! Hypervisor: $HypervisorName Vcenter: $VcenterEntry"

                debug "Connecting to $VcenterEntry..."
                
                Connect-VIServer $VcenterEntry

                debug "Counter Value: $counterVar"

                $VLAN_Name = $ExtractedVLANsList[$counterVar]

                debug "Corresponding VLAN Name: $VLAN_Name"

                debug "Retrieving VM Data..."

                $VMData = Get-VM -Name $DesktopName

                debug "Setting the adapter to $VLAN_Name..."

                $VMData | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $VLAN_Name -StartConnected:$true -Confirm:$false

                debug "All set!"
            }

            debug "No matches found, incrementing counter..."

            $counterVar = $counterVar + 1
        }

    }


}