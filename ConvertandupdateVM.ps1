<#  
 .SYNOPSIS  
  Script to update Template's Windows Updates
    
 .DESCRIPTION
  I use this script to convert my template to a VM, start the VM,
  apply any Windows Update, shutdown the VM, and convert it back
  to a template.
  Optionally, it can create a copy of the template to another site
  to maintain a duplicate copy of the template.
  Tested with: Windows Server 2012 R2 Datacenter, and Windows Server
  2016 Datacenter VMs.
 
 .NOTES   
  Author   : Dan Linder & Naomi (based on work: Justin Bennett)   
  Original file: https://raw.githubusercontent.com/cajeeper/PowerCLI/master/Install-Windows-Update-for-Template.ps1
  Date     : 2018-08-08
  Contact  : westcloudservicesengineering@regmail.west.com
  Revision : v1.0
  Changes  : v1.0 Original
#>

$VCenters = "den06cvircen06"

# Until we get valid SSL certs...
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope Session -Confirm:$false

$DateStamp = Get-Date -UFormat "%Y%m%d"

$creds = Get-Credential

foreach ($vcenter in $VCenters) {
	$vircen = Connect-VIServer -server $vcenter -Credential $creds
	if (!$?) {
		"An error occurred in the Connect-VIServer call."
		pause
	}
}


#Show Progress
$showProgress = $true


#Update Template Parameters

	#Update Template Name
	$updateTempName = "test_win2k12_180808_NGS"

	#Update Template Local Account to Run Script
	$updateTempUser = "OLA"
	$updateTempPass = ConvertTo-SecureString 'B3w@r30fPWN1nj@s' -AsPlainText -Force


#Copy Template Parameters

	#Enable Post Update Copy of Template
	$copyTemplate = $true

	#Copy Template Name
	$copyTempSource = $updateTempName
	$copyTempName = "$($copyTempSource)_copy"
	$copyTempDatastore = "templates"
	$copyTempLocation = Get-Folder -Location "WindowsTemplates" "TestTemplates"
	$copyTempESXHost = "den06uesx35.svc.west.com"


#Log Parameters and Write Log Function
$logRoot = "C:\Scripts\WindowsVM\logs"

$log = New-Object -TypeName "System.Text.StringBuilder" "";

function writeLog {
	$exist = Test-Path $logRoot\update-$updateTempName.log
	$logFile = New-Object System.IO.StreamWriter("$logRoot\update-$($updateTempName).log", $exist)
	$logFile.write($log)
	$logFile.close()
}

[void]$log.appendline((("[Start Batch - ")+(get-date)+("]")))
[void]$log.appendline($error)

#---------------------
#Update Template
#---------------------

try {
	#Get Template
	$template = Get-Template -Name $updateTempName

	#Convert Template to VM
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Converting Template: $($updateTempName) to VM" -PercentComplete 5 }
	[void]$log.appendline("Converting Template: $($updateTempName) to VM")
	$template | Set-Template -ToVM -Confirm:$false

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

	#VM Local Account Credentials for Script
	$cred = New-Object System.Management.Automation.PSCredential $updateTempUser, $updateTempPass

	#Script to run on VM
	$script = "Function WSUSUpdate {
		  param ( [switch]`$rebootIfNecessary,
				  [switch]`$forceReboot)  
		`$Criteria = ""IsInstalled=0 and Type='Software'""
		`$Searcher = New-Object -ComObject Microsoft.Update.Searcher
		try {
			`$SearchResult = `$Searcher.Search(`$Criteria).Updates
			if (`$SearchResult.Count -eq 0) {
				Write-Output ""There are no applicable updates.""
				exit
			} 
			else {
				`$Session = New-Object -ComObject Microsoft.Update.Session
				`$Downloader = `$Session.CreateUpdateDownloader()
				`$Downloader.Updates = `$SearchResult
				`$Downloader.Download()
				`$Installer = New-Object -ComObject Microsoft.Update.Installer
				`$Installer.Updates = `$SearchResult
				`$Result = `$Installer.Install()
			}
		}
		catch {
			Write-Output ""There are no applicable updates.""
		}
		If(`$rebootIfNecessary.IsPresent) { If (`$Result.rebootRequired) { Restart-Computer -Force} }
		If(`$forceReboot.IsPresent) { Restart-Computer -Force }
	}

	WSUSUpdate -rebootIfNecessary
	"
	
	#Running Script on Guest VM
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Running Script on Guest VM: $($updateTempName)" -PercentComplete 50 }
	[void]$log.appendline("Running Script on Guest VM: $($updateTempName)")
	Get-VM $updateTempName | Invoke-VMScript -ScriptText $script -GuestCredential $cred
	
	#Wait for Windows Updates to finish after reboot
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Giving VM: $($updateTempName) 600 seconds to finish rebooting after Windows Update" -PercentComplete 65 }
	[void]$log.appendline("Giving VM: $($updateTempName) 600 seconds to finish rebooting after Windows Update")
	sleep 600

	#Shutdown the VM
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Shutting Down VM: $($updateTempName)" -PercentComplete 80 }
	[void]$log.appendline("Shutting Down VM: $($updateTempName)")
	Get-VM $updateTempName | Stop-VMGuest -Confirm:$false

	#Wait for shutdown to finish
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Giving VM: $($updateTempName) 30 seconds to finish Shutting Down" -PercentComplete 90 }
	[void]$log.appendline("Giving VM: $($updateTempName) 30 seconds to finish Shutting Down")
	sleep 30
	
	#Convert VM back to Template
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Convert VM: $($updateTempName) back to template" -PercentComplete 100 }
	[void]$log.appendline("Convert VM: $($updateTempName) back to template")
	Get-VM $updateTempName | Set-VM -ToTemplate -Confirm:$false
}
catch { 
	[void]$log.appendline("Error:")
	[void]$log.appendline($error)
	Throw $error
	#stops post-update copy of template
	$updateError = $true
	}
#---------------------
#End of Update Template
#---------------------
	

#---------------------
#Copy Template
#---------------------

#Copy if copyTemplate true and either updateError false or no existing template
if($copyTemplate -and (!($updateError) -or ((Get-Template | ? {$_.Name -eq $copyTempName}).count -eq 0))) {
	try {
		#Remove Existing Template if exists
		Get-Template | ? {$_.Name -eq $copyTempName} | % {
			if($showProgress) { Write-Progress -Activity "Copy Template" -Status "Remove Existing Template: $($copyTempName)" -PercentComplete 30 }
			[void]$log.appendline("Remove Existing Template: $($copyTempName)")
			Get-Template $copyTempName | Remove-Template -DeletePermanently -Confirm:$false
		}

		#Copy Template
		if($showProgress) { Write-Progress -Activity "Copy Template" -Status "Create new VM (Template): Copy Template Source: $($copyTempSource) to New VM: $($copyTempName)" -PercentComplete 60 }
		[void]$log.appendline("Create new VM (Template): Copy Template Source: $($copyTempSource) to New VM: $($copyTempName)")
		New-VM -Name $copyTempName -Template $copyTempSource -VMHost $copyTempESXHost -Datastore $copyTempDatastore -Location $copyTempLocation

		#Change VM to Template
		if($showProgress) { Write-Progress -Activity "Copy Template" -Status "Change new VM to Template: $($copyTempName)" -PercentComplete 90 }
		[void]$log.appendline("Change new VM to Template: $($copyTempName)")
		Get-VM $copyTempName | Set-VM -ToTemplate -Confirm:$false
		
	} catch { 
		[void]$log.appendline("Error:")
		[void]$log.appendline($error)
		Throw $error
	}
}
#---------------------
#End of Copy Template
#---------------------

#Write Log
[void]$log.appendline((("[End Batch - ")+(get-date)+("]")))

writeLog