function New-TempFolder{
	process{
		$newFolder= New-Item -Path ([System.IO.Path]::GetTempPath()) -Name ([System.Guid]::NewGuid()) -ItemType Directory -Force
		$newFolder.FullName
	}
}
function Switch-AzureContext {
	param(
		[Parameter(Mandatory=$true)]
		[string]$SubscriptionId
	)

	$null = Set-AzureRmContext -SubscriptionId $SubscriptionId
}
function Get-RunbookExtension {
	param(
		[parameter(Mandatory=$true)]
		[string]$RunbookType
	)
	$extension = ""
	switch ($RunbookType) {
		"GraphPowerShell" { $extension = ".graphrunbook" }
		"Python2" { $extension = ".py" }
		"PowerShell" { $extension = ".ps1" }
		"Script" { $extension = ".ps1" }
		"WorkFlow" { $extension = ".ps1" }
		"GraphPowerShellWorkflow" { $extension = ".graphrunbook" }
	}

    $extension
}
function Clone-AutomationAccount {
	param(
		[Parameter(Mandatory=$true)]
		[string]$SourceAutomationAccount,

		[Parameter(Mandatory=$true)]
		[string]$SourceAutomationAccountResourceGroup,

		[Parameter(Mandatory=$true)]
		[string]$DestinationAutomationAccount,

		[Parameter(Mandatory=$true)]
		[string]$DestinationAutomationAccountResourceGroup,

		[Parameter(Mandatory=$true)]
		[string]$SourceSubscriptionId,

		[Parameter(Mandatory=$false)]
		[string]$DestinationSubscriptionId,

		[Parameter(Mandatory=$false)]
		[bool]$Runbooks=$true,

		[Parameter(Mandatory=$false)]
		[bool]$Modules=$true,

		[Parameter(Mandatory=$false)]
		[bool]$Variables=$true
	)

	# If Destination Subscription ID is not provided, it is assumed that both the automation accounts
	# are in the same source subscription

	Switch-AzureContext -SubscriptionId $SourceSubscriptionId
	$SourceSubscriptionContext = Get-AzureRmContext
	$DestinationSubscriptionContext = $null
	if (!([string]::IsNullOrWhiteSpace($DestinationSubscriptionId)) -and ($SourceSubscriptionId -ne $DestinationSubscriptionId)) {
		Switch-AzureContext -SubscriptionId $DestinationSubscriptionId
		$DestinationSubscriptionContext = Get-AzureRmContext

		# Switching context back to source subscription
		Switch-AzureContext -SubscriptionId $SourceSubscriptionId
	}

	$SrcAA = Get-AzureRmAutomationAccount -ResourceGroupName $SourceAutomationAccountResourceGroup -Name $SourceAutomationAccount -AzureRmContext $SourceSubscriptionContext -ErrorAction SilentlyContinue
	if (-not $SrcAA)
	{
		throw "Source Automation Account doesn't exist. Aborting..."
	}

	#region Begin Copy Process

	#region Step-1 Create Automation Account

	$destAA = Get-AzureRmAutomationAccount -ResourceGroupName $DestinationAutomationAccountResourceGroup -Name $DestinationAutomationAccount -AzureRmContext $DestinationSubscriptionContext -ErrorAction SilentlyContinue
	if ($destAA) {
		Write-Warning "Provided Destination Automation Account is already available in Resource Group $DestinationAutomationAccountResourceGroup in subscription $DestinationSubscriptionId"
	}
    else {
	    $NewAA = New-AzureRmAutomationAccount -ResourceGroupName $DestinationAutomationAccountResourceGroup -Name $DestinationAutomationAccount -Location $SrcAA.Location -Plan $SrcAA.Plan -Tags $SrcAA.Tags -Verbose -ErrorAction Stop -AzureRmContext $DestinationSubscriptionContext

	    if (-not $NewAA) {
	    	throw "Failed to create automation account"
	    }
    }

	#endregion

	#region Step-2 Copy Runbooks if that option is selected
	if (!$Runbooks) {
		Write-Warning "Runbooks are not selected for copying. Skipping Runbooks"
	}
	else {
		Write-Output "Beginning copying of runbooks from $SourceAutomationAccount to $DestinationAutomationAccount"
		$WorkFolder = New-TempFolder
        $RunbooksInSourceAutomationAccount = Get-AzureRmAutomationRunbook -ResourceGroupName $SourceAutomationAccountResourceGroup -AutomationAccountName $SourceAutomationAccount
		if ($null -eq $RunbooksInSourceAutomationAccount) {
			Write-Warning "There are no runbooks in automation account $SourceAutomationAccount. Proceeding to next step."
		}
		else {
			$RunbooksInSourceAutomationAccount | ForEach-Object {
				Write-Output "Exporting runbook : $($_.Name) from Automation Account : $SourceAutomationAccount"
				$null = Export-AzureRmAutomationRunbook -Name $_.Name -ResourceGroupName $SourceAutomationAccountResourceGroup -AutomationAccountName $SourceAutomationAccount -OutputFolder $WorkFolder -Force -AzureRmContext $SourceSubscriptionContext
				$extension = Get-RunbookExtension -RunbookType $_.RunbookType
                
                # IF type is Python, set extension temporarily to .ps1 due to an open bug in Export cmdlet
                # https://github.com/Azure/azure-powershell/issues/6368
                if ($_.RunbookType -eq "Python2")
                {
                    $extension = ".ps1"
                }
				if (!(Test-Path -Path (Join-Path $WorkFolder ($($_.Name) + $extension)))) {
					Write-Warning "Failed to export runbook : $($_.Name) from Source Automation Account : $SourceAutomationAccount. Skipping importing this."
				}
				else {
                    # rename the extension to python if original runbook's type is python
                    if ($_.RunbookType -eq "Python2")
                    {
                        Rename-Item -Path (Join-Path $WorkFolder ($($_.Name) + $extension)) -NewName (Join-Path $WorkFolder ($($_.Name) + ".py")) -PassThru -Force

                        # Reset extension back to python
                        $extension = Get-RunbookExtension -RunbookType $_.RunbookType
                    }
					Write-Output "Importing runbook : $($_.Name) into Automation Account : $DestinationAutomationAccount"
                    $RunbookType = ""
                    if ($_.RunbookType -eq "GraphPowerShell")
                    {
                        $RunbookType="GraphicalPowerShell"
                    }
                    elseif ($_.RunbookType -eq "GraphPowerShellWorkflow")
                    {
                        $RunbookType = "GraphicalPowerShellWorkflow"
                    }
                    else
                    {
                        $RunbookType = $_.RunbookType
                    }
					$null = Import-AzureRmAutomationRunbook -Path (Join-Path $WorkFolder ($($_.Name) + $extension)) -Description $_.Description -Name $_.Name -Tags $_.Tags -Type $RunbookType -Published -ResourceGroupName $DestinationAutomationAccountResourceGroup -AutomationAccountName $DestinationAutomationAccount -Force
				}
				Write-Output "========================================================"
            }
		}
		Write-Output "Copying of runbooks completed."
	}
	#endregion

	#region Step-3 Copy Modules if that option is selected

	#endregion

	#endregion
}