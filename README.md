# AzureArcOnboarding

## How to use this script:
1. Create a secrets file in the following format, provide values for everything and run it at the powershell command line:
```console
$secrets = @{
    correlationId            = ''
    location                 = ''
    resourceGroup            = ''
    servicePrincipalSecret   = ''
    servicePrincipalClientId = ''
    subscriptionId           = ''
    tenantId                 = ''
    workspaceId              = ''
    workspaceKey             = ''
}
```
2. Clone the onboarding script:
```console
git clone https://github.com/tbrock-opti/AzureArcOnboarding.git
```
3. Execute the script
```console
.\AzureArcOnboarding\Start-AzureArcOnboarding.ps1 -secrets $secrets
```
