# VMWare_VLAN_Changer

Takes an Input file and

+ Pulls Data for all machines in a given Citrix Delivery Group

+ For each machine in a given Delivery group, changes the Network Adapter of the VM in VMWare to match what's specified in the input file

>**Warning**
>The machines must be powered off before running the script

>**Note**
>The script accepts multiple values for the VLAN and VCenter parameters in the input file, if separated by commas

>**Note**
>The script will attempt to assign the first VLAN to the all machines located in the first Vcenter
>
>e.g. VLAN_Name1 to machines in VCenter1, etc, etc
