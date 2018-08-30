
Param(
    [Parameter()][string]$rgName = 'dtdaily',
    [Parameter()][string]$SubscriptionID = 'edbc6ce9-c5ef-4c5e-bebc-cc2b06c2fa49' #Changeme for Default SubscriptionID,
    [Parameter()][string[]]$Startup_SKIP = @('skipMGTservers','skipZABBIXservers','skipBARRACUDAservers','skipSFTPservers')
)


#####     #####     #####
#######     #####     #####
#########     #####     #####
###########     #####     #####
###########     #####     #####
#########     #####     #####
#######     #####     #####
#####     #####     #####
#write code that automatically installs a runbook with a schedule and a script to start the environment,
#     then introduce an environment variable as a flag for whether to install/enable the runbook as part of the pipeline.
#       Script in confluence.

#Login to AZURE from PowerShell
#Below works in MAC/Linux PowerShell 6.0.1+ and Windows WMF 4.0+
#pwsh on MAC OS or powershell_ise.exe on Windows
#Connect-AzureRmAccount (Login-AzureRMAcount and Add-AzureRMAccount are the older Azure cmdlets)
# Goto URL https://microsoft.com/devicelogin and the password it provides example Q9KZ3HGN2
#  You may need to select-azurermsubscription -subscriptionid $SubscriptionID #Define $SubscriptionID = 'replace everything with your actual subscription id xxx-xxxx-xxx'

#Example location using the . way of running a script or just cut and paste to PowerShell
#Example location using the . way of running a script
#MAC PWSH syntax
#. ~/Documents/Scripts/AzureRM/PS_Automated_Startup.ps1 -rgName 'dtdaily' -SubscriptionID 'edbc6ce9-c5ef-4c5e-bebc-cc2b06c2fa49' -Startup_SKIP ('skipMGTservers','skipZABBIXservers','skipBARRACUDAservers','skipSFTPservers')
#. ~/Documents/Scripts/AzureRM/PS_Automated_Startup.ps1 -rgName 'dtstaging' -SubscriptionID 'edbc6ce9-c5ef-4c5e-bebc-cc2b06c2fa49' -Startup_SKIP ('skipMGTservers','skipZABBIXservers','skipBARRACUDAservers','skipSFTPservers')
#Windows PowerShell.exe/PowerShell_ISE.exe syntax
#. $env:userprofile\Scripts\AzureRM\PS_Automated_Startup.ps1 -rgName 'dtdaily' -SubscriptionID 'edbc6ce9-c5ef-4c5e-bebc-cc2b06c2fa49' -Startup_SKIP ('skipMGTservers','skipZABBIXservers','skipBARRACUDAservers','skipSFTPservers')
#. $env:userprofile\Scripts\AzureRM\PS_Automated_Startup.ps1 -rgName 'dtstaging' -SubscriptionID 'edbc6ce9-c5ef-4c5e-bebc-cc2b06c2fa49' -Startup_SKIP ('skipMGTservers','skipZABBIXservers','skipBARRACUDAservers','skipSFTPservers')
#####     #####     #####
#######     #####     #####
#########     #####     #####
###########     #####     #####
###########     #####     #####
#########     #####     #####
#######     #####     #####
#####     #####     #####

# Modify this section to target VMs for startup
#     If copying the RAW code by dropping it into a PowerShell session
#         Don't forget to run Connect-AzureRMConnect cmdlet
#Edit rgName as appropriate below
#$rgName = "dtstaging"
#Edit SubscriptionID as appropriate below
#$SubscriptionID = 'edbc6ce9-c5ef-4c5e-bebc-cc2b06c2fa49'#SubscriptionName
#Groups to skip @('skipMGTservers','skipZABBIXservers','skipBARRACUDAservers','skipSFTPservers')
#Edit Startup_SKIP as appropriate below
#$Startup_SKIP = @('skipMGTservers','skipZABBIXservers','skipBARRACUDAservers','skipSFTPservers')
# ------------------------------------------------------------

#####     #####     #####
#######     #####     #####
#########     #####     #####
###########     #####     #####
###########     #####     #####
#########     #####     #####
#######     #####     #####
#####     #####     #####

select-azurermsubscription -subscriptionid $SubscriptionID

Function StartVMsandWait {

    param(
        [Parameter(ValueFromPipeline)][Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine[]]$VMs
    )

    Process {
        ForEach ($VM in $VMs) {
            If (-not ((Get-AzureRmVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Status).Statuses.Code -contains 'PowerState/running')) {
                Write-Output "Starting $($VM.Name)..."
                Start-AzureRmVM -ResourceGroupName $VMs.ResourceGroupName -Name $VM.Name
            }
            Else {
                Write-Output "$($VM.Name) is already running."
            }
        }
    }

}

$dc_servers = Get-AzureRmVM -ResourceGroupName $rgName | ? {$_.Name -Like 'evDC*'}
$db_servers = Get-AzureRmVM -ResourceGroupName $rgName | ? {$_.Name -Like 'evDB*'}
$ic1_server = Get-AzureRmVM -ResourceGroupName $rgName | ? {$_.Name -Like 'evIC1*'}
$ic2_server = Get-AzureRmVM -ResourceGroupName $rgName | ? {$_.Name -Like 'evIC2*'}
$wfe_servers = Get-AzureRmVM -ResourceGroupName $rgName | ? {$_.Name -Like 'evWFE*'}
$is_servers = Get-AzureRmVM -ResourceGroupName $rgName | ? {$_.Name -Like 'evIS*'}
$all_other_servers_exclusions = @()

$barracuda_servers = Get-AzureRmVM -ResourceGroupName $rgName | ? {$_.Name -Like 'evBarracuda*'}
$mgt_servers = Get-AzureRmVM -ResourceGroupName $rgName | ? {$_.Name -Like 'evMGT*'}
$zab_servers = Get-AzureRmVM -ResourceGroupName $rgName | ? {$_.Name -Like 'evZAB*'}
$sftp_servers = Get-AzureRmVM -ResourceGroupName $rgName | ? {$_.Name -Like 'evSFTP*'}

If ($Startup_SKIP -contains 'skipMGTservers') {$all_other_servers_exclusions += $mgt_servers.Name }
If ($Startup_SKIP -contains 'skipZABBIXservers') {$all_other_servers_exclusions += $zab_servers.Name }
If ($Startup_SKIP -contains 'skipSFTPservers') {$all_other_servers_exclusions += $sftp_servers.Name }


$all_other_servers = Get-AzureRmVM -ResourceGroupName $rgName | ? {$_.Name -notin ($dc_servers.Name + $db_servers.Name + $ic1_server.Name + $ic2_server.Name + $is_servers.Name + $wfe_servers.Name + $barracuda_servers.Name + $all_other_servers_exclusions)}

If ($Startup_SKIP -notcontains 'skipBARRACUDAservers') {$barracuda_servers | StartVMsandWait}
$dc_servers | StartVMsandWait
$db_servers | StartVMsandWait
$ic1_server | StartVMsandWait
$is_servers | StartVMsandWait
$ic2_server | StartVMsandWait
$all_other_servers | StartVMsandWait
$wfe_servers | StartVMsandWait
