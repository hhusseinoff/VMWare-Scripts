# Connect to vCenter
$vcServer = "name.com"
Connect-VIServer -Server $vcServer

# Option to export results to CSV
$exportToCSV = $true
$csvPath = "C:\Temp\VMWare_VM_IPList_Nov9th.csv"

# Retrieve VM data
$vmData = Get-VM | ForEach-Object {
    $vm = $_
    $vm.Guest.Nics | ForEach-Object {
        $ipv4Addresses = ($_.IPAddress | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' }) -join ', '
        $ipv6Addresses = ($_.IPAddress | Where-Object { $_ -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' }) -join ', '
        [PSCustomObject]@{
            'VM Name'     = $vm.Name
            'IPv4 Address'= $ipv4Addresses
            'IPv6 Address'= $ipv6Addresses
            'MAC Address' = $_.MacAddress
        }
    }
}

# Display the data as a table
$vmData | Format-Table -AutoSize

# Export to CSV if required
if ($exportToCSV) {
    $vmData | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "Data exported to $csvPath"
}

# Disconnect from vCenter
Disconnect-VIServer -Server $vcServer -Confirm:$false
