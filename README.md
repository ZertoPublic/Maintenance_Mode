# Maintenance_Mode
Maintenance Mode script. Use at your own risk!!!! This script is not supported by Zerto.

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
