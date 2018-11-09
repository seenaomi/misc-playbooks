<#
 UpdateWinGolden.ps1
.SYNOPSIS  
  Script to update WestCloud's Window Golden Image VMs
    
 .DESCRIPTION
  Script to log into vcenter den06cvircen06 and power on template VM so ansible can reach it

  Tested with: Windows Server 2012 R2 
 
 .NOTES   
  Author   : Naomi (based on work: Justin Bennett)   
  Original file: https://raw.githubusercontent.com/cajeeper/PowerCLI/master/Install-Windows-Update-for-Template.ps1
  Date     : 2018-10-08
  Contact  : westcloudservicesengineering@regmail.west.com
  Revision : v1.0
  Changes  : v1.0 Original
#>


# Until we get valid SSL certs...
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope Session -Confirm:$false

# 
$FolderYear = Get-Date -UFormat "%Y"
$FolderMonth = (Get-Date -UFormat "%B").ToLower()

#Log Parameters and Write Log Function
$logRoot = "X:\$FolderYear\$FolderMonth"

$log = New-Object -TypeName "System.Text.StringBuilder" "";

# Prompt for vcenter credientials for now and connect to den06 vcenter
$creds = Get-Credential

$vconnect = Connect-VIServer -server den06cvircen06 -Credential $creds
	

#Show Progress
$showProgress = $true


#PowerOn VM Parameters

	#Update VM Name
	$updateVM = "test_win2k12_180808_NGS"

#---------------------
#Power on VM & Update VMware tools
#---------------------

try {
	#Get VM
	$winvm = Get-VM -Name $updateVM

	#Start VM
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Starting VM: $($updateTempName)" -PercentComplete 20 }
	[void]$log.appendline("Starting VM: $($updateTempName)")
	Get-VM $updateTempName | Start-VM -RunAsync:$RunAsync


	#Wait for VMware Tools to start
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Giving VM: $($updateTempName) 120 seconds to start VMwareTools" -PercentComplete 35 }
	[void]$log.appendline("Giving VM: $($updateTempName) 120 seconds to start VMwareTools")
    sleep 120

    #Update VMtools without reboot
    Get-VM $updateTempName -ErrorAction SilentlyContinue -ErrorVariable getVMError| where { $_.PowerState -eq "PoweredOn"} | Update-Tools �NoReboot -ErrorAction SilentlyContinue -ErrorVariable updateError
    if($updateError){
        Write-Host "Failed to Update $updateTempName"
    }
    if($getVMError){
        Write-Host "Failed to find VM $updateTempName"
    }
    if(-not $updateError -and -not $getVMError){
        write-host "Updated VM: $updateTempName"
    }
}
catch { 
	[void]$log.appendline("Error:")
	[void]$log.appendline($error)
	Throw $error
	#stops post-update copy of template
	$updateError = $true
	}
	