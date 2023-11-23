# Connect to vCenter
$vcServer = "Name.com"
Connect-VIServer -Server $vcServer

# Search for VM with specified IP address
$targetIP = "1.2.3.4"
$vmWithTargetIP = Get-VM | Where-Object {
    $_.Guest.IPAddress -contains $targetIP
}

# Display the VM name
if ($vmWithTargetIP) {
    Write-Host "The VM with IP address $targetIP is: $($vmWithTargetIP.Name)"
} else {
    Write-Host "No VM found with IP address $targetIP"
}

# Disconnect from vCenter
Disconnect-VIServer -Server $vcServer -Confirm:$false
