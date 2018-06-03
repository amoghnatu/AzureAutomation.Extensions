# AzureAutomation.Extensions
This repository consists of a powershell module that, currently, adds only one cmdlet.

The cmdlet is **Clone-AutomationAccount**

Clone-AutomationAccount basically does what the name suggests. It clones an automation account from one subscription to another. Currently, the plan is to provide switches to allow or Dis-allow Runbooks, Automation Variables, Modules from being copied. However, the default values of these switches is True. So if these are not provided as false explicitly, they are also cloned in the new automation account that gets created.

**Development Process**
All development is being done in the DEV branch which is merged after testing. Direct pushing to master branch is disabled.

 
 **IMPORTANT NOTE :**
  
**This is still a work in progress and is NOT COMPLETE. I will keep updating this as an when I push new changes.**


 ** Push Summary **
 *Watch below space for all the updates*

 [03-JUNE-2018] - Fixed issues with Runbook import functionality
				  Added code to copy vairables from source automation account to destination automation account.	
 
 [27-MAY-2018] - Added initial module files, base functions, basic code to create automation account in destination subscription. Also added code to copy runbooks from source automation account to destination automation account.
