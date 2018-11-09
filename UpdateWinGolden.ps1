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


#Update VM Parameters

	#Update VM Name
	$updateVM = "test_win2k12_180808_NGS"

	#Update VM Local Account to Run Script
	$updateVMUser = "OLA"
	$updateVMPass = ConvertTo-SecureString 'B3w@r30fPWN1nj@s' -AsPlainText -Force


#Copy VM Parameters

	#Enable Post Update Copy of OVF
	$copyVM = $true

	#Copy VM Name
	$copyVMSource = $updateVM
	$copyVMName = "$($copyTempSource)_copy"
	$copyVM = $logRoot
	$copyVMLocation = Get-Folder -Location "WindowsTemplates" "TestTemplates"
	$copyVMESXHost = "den06uesx35.svc.west.com"


