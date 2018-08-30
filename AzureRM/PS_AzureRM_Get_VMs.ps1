#Login to AZURE from PowerShell
#Below works in MAC/Linux PowerShell 6.0.1+ and Windows WMF 4.0+
#pwsh on MAC OS or powershell_ise.exe on Windows
#Connect-AzureRmAccount (Login-AzureRMAcount and Add-AzureRMAccount are the older Azure cmdlets)
# Goto URL https://microsoft.com/devicelogin and the password it provides example Q9KZ3HGN2
#  You may need to select-azurermsubscription -subscriptionid $SubscriptionID #Define $SubscriptionID = 'replace with your actual subscription  xxx-xxxx-xxx'

#Example location using the . way of running a script or just cut and paste to PowerShell
#Example location using the . way of running a script
#MAC PWSH syntax
#. ~/Documents/Evolve/Scripts/AzureRM/PS_AzureRM_Get_VMs.ps1
#Windows PowerShell.exe/PowerShell_ISE.exe syntax
#. $env:userprofile\Scripts\AzureRM\PS_AzureRM_Get_VMs.ps1

$Project="EMR"
$clientFilePrefix="AzureRM"
$clientFileCampaign="VMs"

#Get Date Time
$Date = ([DateTime]::Now).ToString("yyyyMMdd")
$Time = ([DateTime]::Now).ToString("HHmmss")
$DateStart=get-date

#Change to Windows Path if running in Windows $env:USERPROFILE
If ($($env:USERPROFILE)) {
  $fldrRoot="$($env:USERPROFILE)\"
  $fldrPathseparator='\'
} Else {
  $fldrRoot="~/"
  $fldrPathseparator='/'
}

# Make Directory if not exist
$fldrPath=$fldrRoot+"Documents"+$fldrPathseparator+$Project+$fldrPathseparator+$clientFilePrefix+$fldrPathseparator+$clientFileCampaign
New-Item -ErrorAction Ignore -ItemType directory -Path $fldrPath

#Make Imports Folder
$fldrPathimports=$fldrPath+$fldrPathseparator+"Imports"
New-Item -ErrorAction Ignore -ItemType directory -Path $fldrPathimports

#Make Exports Folder Directory
$fldrPathexports=$fldrPath+$fldrPathseparator+"Exports"
New-Item -ErrorAction Ignore -ItemType directory -Path $fldrPathexports

#Assign the variable to the export file Prefix
$VMInfo_Export=$fldrPathexports+$fldrPathseparator+$clientFilePrefix+"_"+$Project+"_"+$clientFileCampaign+"_"+$Date+"_"+$Time+".csv"

#Create a Table to use for filtering the results
$VMInfo = New-Object System.Data.DataTable
#Now Add some columns for use later
$VMInfo.Columns.Add((New-Object System.Data.DataColumn 'ResourceGroup',([String])))
$VMInfo.Columns.Add((New-Object System.Data.DataColumn 'VM',([String])))
$VMInfo.Columns.Add((New-Object System.Data.DataColumn 'Location',([String])))
$VMInfo.Columns.Add((New-Object System.Data.DataColumn 'VM_ID',([String])))
$VMInfo.Columns.Add((New-Object System.Data.DataColumn 'VM_NIC',([String])))
$VMInfo.Columns.Add((New-Object System.Data.DataColumn 'IP',([String])))
$VMInfo.Columns.Add((New-Object System.Data.DataColumn 'Public_IP_Name',([String])))
$VMInfo.Columns.Add((New-Object System.Data.DataColumn 'Public_IP',([String])))
$VMInfo.Columns.Add((New-Object System.Data.DataColumn 'IP_MAC',([String])))
$VMInfo.Columns.Add((New-Object System.Data.DataColumn 'Priv_Dyn',([String])))
$VMInfo.Columns.Add((New-Object System.Data.DataColumn 'Status',([String])))
$VMInfo.Columns.Add((New-Object System.Data.DataColumn 'Date_Time',([String])))
$VMInfo_Array_Count=($VMInfo | Measure-Object | Select Count).Count

#List the Array to show it='s empty
Write-Host "Created Array VMInfo with $VMInfo_Array_Count objects"

$Date_Time=([DateTime]::Now).ToString("yyyy/MM/dd")+" "+([DateTime]::Now).ToString("HH:mm:ss")
#Check the OS type
If ($($ENV:OS)) {$OSTYPE="WINDOWS";Write-Host "The OS is"$OSTYPE" Based"} Else {$OSTYPE="LINUX";Write-Host "The OS is"$OSTYPE" Based"}
#Get the VM's
$VMs = Get-AzureRmVM
$VMstatus = Get-AzureRmVM -Status
#Get the NIC and their properties for matching against the VMs
$NICs = get-azurermnetworkinterface | where VirtualMachine -NE $null #skip NICs with no VM
#Get the Public IPs for matching against the VMs
#Public IPs work only if the naming convention starts with the VM Name used in Azure
$PublicIPs=Get-AzureRmPublicIpAddress | Select-Object Name,ResourceGroupName,IpAddress

#Now Loop through the NICs in Azure and match against the VMs and the Public IPs
ForEach ($nic in $NICs)
{
    #Get the VM Info
    $VM = $VMs | where-object -Property Id -EQ $nic.VirtualMachine.id
    $VM_Name = $($VM.name)
    $VM_Location = $($VM.Location)
    $VM_Resourcegroup = $($VM.ResourceGroupName)
    $VM_ID = $($VM.VMid)
    $VM_NIC = $nic.Name -Join ';'
    $VM_Status = (($VMstatus | Where {$_.ResourceGroupName -eq $VM_Resourcegroup -and $_.Name -eq $VM_Name}).PowerState).Replace('VM ', '')
    $VM_IP =  ($nic.IpConfigurations | select-object -ExpandProperty PrivateIpAddress) -Join ';'
    $VM_PIPName = ($nic.IpConfigurations.PublicIpAddress.Id -Split '/')[-1]
    $VM_PublicIP =  ($PublicIPs | Where-Object {$_.ResourcegroupName -eq $VM_Resourcegroup -and $_.Name -like "$VM_PIPName"} | Select IpAddress).IpAddress
    $VM_IP_MAC =  (($nic | Select MacAddress).MacAddress) -Join ';'
    $VM_Alloc =  $nic.IpConfigurations | select-object -ExpandProperty PrivateIpAllocationMethod

    #Uncomment this to check the values before going into the Array $VMINFO
    #Write-Output "$($VM.ResourceGroupName), $($VM.Name), $($VM.VMid), $($VM.Location), $VM_IP, $VM_PublicIP, $VM_IP_MAC, $VM_Alloc"

    #Now populate the $VMInfo array
    $row = $VMInfo.NewRow()
	$row.'ResourceGroup'=$VM_Resourcegroup
    $row.'VM'=$VM_Name
    $row.'VM_ID'=$VM_ID
    $row.'VM_NIC'=$VM_NIC
	$row.'Location'=$VM_Location
	$row.'IP'=$VM_IP
    $row.'Public_IP_Name'=$VM_PIPName
	$row.'Public_IP'=$VM_PublicIP
    $row.'IP_MAC'=$VM_IP_MAC
    $row.'Priv_Dyn'=$VM_Alloc
    $row.'Status'=$VM_Status
    $row.'Date_Time'=$Date_Time
    $VMInfo.Rows.Add($row)
}
cls
$TotalTime=(NEW-TIMESPAN –Start $DateStart –End $(GET-DATE))
Write-Host "Script Ran in $($TotalTime.Hours) hours and $($TotalTime.Minutes) minutes and $($TotalTime.Seconds) seconds"

#Export the Info
Write-Host "Exporting VMINFO Report to `n`t$($VMInfo_Export)"
$VMInfo | Export-CSV -NoTypeInformation -Path $VMInfo_Export

#Depending on OS run the Open/Start command for the CSV Export
If ($OSTYPE -eq "LINUX") {open $VMInfo_Export} `
ElseIf ($OSTYPE -eq "WINDOWS") {start $VMInfo_Export} `
Else {Write-Host "Unknown OS"}

break

#####     ######     #####
#######     ######     #####
##     Extra Tasks to Filter the Exports
#####     ######     #####
#######     ######     #####

#Get the Array Size
$VMInfo_Array_Count=($VMInfo | Measure-Object | Select Count).Count

#ECHO the Array size
Write-Host "`n`n*****     *****"
Write-Host "Array VMInfo has $VMInfo_Array_Count objects"
Write-Host "*****     *****"

break
#Shows Configured Resource Group Names
$VMInfo_ResourceGroupNames=($vminfo | Select ResourceGroup -Unique).ResourceGroup

#ECHO Configured Resource Group Names
Write-Host "`n`n*****     *****"
Write-Host "*****     List of Groups*****"
Write-Host "*****     *****"
$($VMInfo_ResourceGroupNames)

break
#Get DC's from resource Group Name
$VM_Environment="dtdaily"
$VMInfo_GetDCs=$vminfo | where {$_.ResourceGroup -eq $VM_Environment -and $_.VM -like "*dc*"}

#ECHO DC's from resource Group Name
Write-Host "`n`n*****     *****"
Write-Host "*****     List of DC's"
Write-Host "*****     *****"
$($VMInfo_GetDCs)

break
#Get Public IP VMs
$VMInfo_PublicIPs=$vminfo | Where {$_.Public_IP -like "*.*"}

#ECHO Public IP VMs
Write-Host "`n`n*****     *****"
Write-Host "*****     *****"
Write-Host "*****     List of Public IP VMs"
Write-Host "*****     *****"
$($VMInfo_PublicIPs)

break
#ECHO All VMs
$VMInfo

Break
