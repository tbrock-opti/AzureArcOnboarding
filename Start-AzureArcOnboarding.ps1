
function Test-IsAzure() {
    [CmdletBinding()]
    param (
    )

    Write-Verbose "Checking if this is an Azure virtual machine"
    try {
        $iwrParams = @{
            Uri         = 'http://169.254.169.254/metadata/instance/compute?api-version=2019-06-01'
            Headers     = @{Metadata = "true" }
            TimeoutSec  = 1
            ErrorAction = 'SilentlyContinue'
        }
        $response = Invoke-WebRequest  @iwrParams
    }
    catch {
        Write-Verbose "Error $_ checking if we are in Azure"
        return $false
    }
    if ($null -ne $response -and $response.StatusCode -eq 200) {
        Write-Verbose "Azure check indicates that we are in Azure"
        return $true
    }
    return $false
}

Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi	
      
# Install the package
Write-Verbose -Message "Installing agent package" -Verbose
$spParams = @{
    FilePath     = 'msiexec.ese'
    ArgumentList = @("/i", "AzureConnectedMachineAgent.msi" , "/l*v", "installationlog.txt", "/qn")
    Wait         = $true
    Passthru     = $true
}
$exitCode = (Start-Process @spParams).ExitCode
if ($exitCode -ne 0) {
    $message = (net helpmsg $exitCode)        
    $errorcode = "AZCM0149"
    throw "Installation failed: $message See installationlog.txt for additional details."
}

$setupParams = 'connect --service-principal-id "' + $secrets.servicePrincipalClientId + '" `
                --service-principal-secret "' + $secrets.servicePrincipalSecret + '" `
                --resource-group "' + $secrets.resourceGroup + '" `
                --tenant-id "' + $secrets.tenantId + '" `
                --location "' + $secrets.location + '" `
                --subscription-id "' + $secrets.subscriptionId + '" `
                --cloud "AzureCloud" `
                --correlation-id "' + $secrets.correlationId + '"'

# Run connect command
& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" $setupParams 

if ($LastExitCode -eq 0) { 
    $message = 'To view your onboarded server(s), navigate to https://portal.azure.com/#blade/HubsExtension/Br' + `
    'owseResource/resourceType/Microsoft.HybridCompute%2Fmachines'
    Write-Host -ForegroundColor yellow  
}


###################################
# install log & analytics agent
###################################

# download agent setup file
$setupFile = $($env:temp + '\MMASetup-AMD64.exe')
Invoke-WebRequest https://go.microsoft.com/fwlink/?LinkId=828603 -OutFile $setupFile

# Pepare agent install parameters
$setupParams = '/qn NOAPM=1 ADD_OPINSIGHTS_WORKSPACE=1 OPINSIGHTS_WORKSPACE_AZURE_CLOUD_TYPE=0 ' + `
'OPINSIGHTS_WORKSPACE_ID="' + $secrets.workspaceId + '" OPINSIGHTS_WORKSPACE_KEY="' + $secrets.workspaceKey + `
'" AcceptEndUserLicenseAgreement=1'

# install the agent with prepared parameters
& $setupFile $setupParams
