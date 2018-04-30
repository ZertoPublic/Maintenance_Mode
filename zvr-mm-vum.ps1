<#

Legal Disclaimer:
 
----------------------
This script is an example script and is not supported under any Zerto support program or service.
The author and Zerto further disclaim all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose.
 
In no event shall Zerto, its authors or anyone else involved in the creation, production or delivery of the scripts be liable for any damages whatsoever (including, without 
limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or the inability 
to use the sample scripts or documentation, even if the author or Zerto has been advised of the possibility of such damages.  The entire risk arising out of the use or 
performance of the sample scripts and documentation remains with you.”
-----------------------

Here is what it does:
Connects to the vCenter cluster, puts one host at a time in Maintenance Mode (MM), and shuts down only the VRA on the host going into MM.
Scans the host with a VUM baseline and then remediates it.
Reboots the host
Takes the host out of MM and restarts the VRA
Moves on to to the next host in the cluster and will do every host in the cluster.
Notes: It has no intelligence on the VUM Scan and Remediation. It just scans and patches, regardless of compliance. 
-----------------------

#zvr-mm-vum.ps1 
Supply the hostname/FQDN for the vcenter server and the name of the cluster
Script reboots each ESXi server in the cluster one at a time, shuts down the VRA, Scans and Patches the host

====NOTE=====
- Requires the $baseline variable to be set to a baseline already existing in VUM. See VMware VUM PowerCLI for how to
create a baseline from PowerCLI
- Requires VUM 5.5 PowerCLI snapin 


Args
Check to make sure an argument was passed
#>
if ($args.count -ne 2) {
Write-Host "Usage: reboot-vmcluster.ps1 <vCenter> <Cluster Name>"
exit
}
 
# Set vCenter and Cluster name from Arg
$vCenterServer = $args[0]
$ClusterName = $args[1]
 
<#
## Connect to vCenter and Cluster
#>
Connect-VIServer -Server $vCenterServer | Out-Null
 
<#
Get Server Objects from the cluster
Get VMware Server Object based on name passed as arg
#>
$ESXiServers = @(get-cluster $ClusterName | get-vmhost)
 
<#
Reboot ESXi Server Function
Shuts down the Zerto VRA on the host
Puts an ESXI server in maintenance mode, reboots the server and the puts it back online
Requires fully automated DRS and enough HA capacity to take a host off line
#>
Function RebootESXiServer ($CurrentServer) {

# Get Server name
$ServerName = $CurrentServer.Name
 
# Put server in maintenance mode
Write-Host "==== Entering Maintenance Mode on $ServerName ===="
Write-Host "Shutting down Zerto VRA"
Get-VMHost $CurrentServer |Get-VM -Name "Z-VRA*" |Shutdown-VMGuest -Confirm:$false
Write-Host "Entering Maintenance Mode"
Set-VMhost $CurrentServer -State maintenance -Evacuate | Out-Null

<#
Scanning and Patching the Host
Be sure that the $newbaseline variable matches a baseline that you see in VUM
Requires the baseline name you have already. See VMWare VUM PowerCLI examples to create a baseline from PowerCLI
#>
$newbaseline = Get-Baseline *newbaseline*
Write-Host "==== Attaching $newbaseline to $ServerName ====" 
Attach-Baseline -Baseline $newbaseline -Entity $CurrentServer
Scan-Inventory -Entity $CurrentServer
Get-compliance -Entity $CurrentServer
$compliance = get-compliance -Entity $CurrentServer -detailed
Write-Host "==== Getting Compliance for $ServerName ===="
$compliance.NotCompliantPatches
$base = get-baseline -entity $CurrentServer
Remediate-Inventory -Entity $CurrentServer -Baseline $base -HostFailureAction Retry -HostNumberOfRetries 2 -HostDisableMediaDevices $true -Confirm:$false
Write-Host "==== Remediating $ServerName ===="

# Reboot Host
Write-Host "Rebooting"
Restart-VMHost $CurrentServer -confirm:$false | Out-Null
 
# Wait for Server to show as down
do {
sleep 15
$ServerState = (get-vmhost $ServerName).ConnectionState
}
while ($ServerState -ne "NotResponding")
Write-Host "$ServerName is Down"
 
# Wait for server to reboot
do {
sleep 60
$ServerState = (get-vmhost $ServerName).ConnectionState
Write-Host "Waiting for Reboot ..."
}
while ($ServerState -ne "Maintenance")
Write-Host "$ServerName is back up"
 
# Exit maintenance mode
Write-Host "Exiting Maintenance mode"
Set-VMhost $CurrentServer -State Connected | Out-Null
Write-Host "Starting Zerto VRA"
Get-VMHost $CurrentServer |Get-VM -Name "Z-VRA*" | Start-VM -Confirm:$false
Write-Host "==== Reboot Complete==="
Write-Host ""
}
 
<#
Reboot Host
#>
foreach ($ESXiServer in $ESXiServers) {
RebootESXiServer ($ESXiServer)
}
<#
Disconnect from vCenter
#>
# Close vCenter connection
Disconnect-VIServer -Server $vCenterServer -Confirm:$false


