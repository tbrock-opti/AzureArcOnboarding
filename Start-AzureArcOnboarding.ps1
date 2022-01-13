# fail script if not running as administrator
#Requires -RunAsAdministrator

param (
    # object containing secrets from LastPass
    [PSCustomObject]
    $secrets
)

# enable verbose messages    
$VerbosePreference = Continue

# download arc agent install file
Write-Verbose 'Downloading Arc installer...'
$agentInstallfile = $($env:temp + '\AzureConnectedMachineAgent.msi')
Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile $agentInstallfile -UseBasicParsing
      
# Install the package
Write-Verbose -Message "Installing agent package"
$spParams = @{
    FilePath     = 'c:\windows\system32\msiexec.exe'
    ArgumentList = @("/i", "$agentInstallFile" , "/l*v", "installationlog.txt", "/qn")
    Wait         = $true
    Passthru     = $true
}
Start-Process @spParams

# parameters to connect agent to tenant
Write-Verbose 'Connecting Arc agent to tenant...'
$spParams = @{
    FilePath     = "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe"
    ArgumentList = @(
        'connect',
        '--service-principal-id', $secrets.servicePrincipalClientId, 
        '--service-principal-secret', $secrets.servicePrincipalSecret,
        '--resource-group', $secrets.resourceGroup,
        '--tenant-id', $secrets.tenantId,
        '--location', $secrets.location,
        '--subscription-id', $secrets.subscriptionId,
        '--cloud "AzureCloud"',
        '--correlation-id' + $secrets.correlationId
    )
    Wait         = $true
}

# Run connect command
Start-Process @spParams

if ($LastExitCode -eq 0) { 
    $message = 'To view your onboarded server(s), navigate to https://portal.azure.com/#blade/HubsExtension/Br' + `
        'owseResource/resourceType/Microsoft.HybridCompute%2Fmachines'
    Write-Verbose $message
}


###################################
# install log & analytics agent
###################################

# download agent setup file
Write-Verbose 'Download Log & Analytics agent setup file...'
$setupFile = $($env:temp + '\MMASetup-AMD64.exe')
Invoke-WebRequest 'https://go.microsoft.com/fwlink/?LinkId=828603' -OutFile $setupFile -UseBasicParsing

# create directory to extract setup files
Write-Verbose 'Creating temporary directory...'
$ticks = (Get-Date).ticks
$dirName = "$env:temp\MMASetup$ticks"
New-Item -ItemType Directory -Path $dirName

# parameters for extracting setup file archive
Write-Verbose 'Extracting agent to temp directory...'
$spParams = @{
    FilePath     = $setupFile
    ArgumentList = @(
        '/c',
        "/t:$dirName"

    )
    Wait         = $true
}

# extract install archive
Start-Process @spParams

# Pepare agent install parameters
$id = $secrets.workspaceId
$key = $secrets.workspaceKey

# parameters to connect agent to Arc
Write-Verbose 'Running Log & Analytics agent installer...'
$spParams = @{
    FilePath     = $($dirName + '\setup.exe')
    ArgumentList = @(
        '/qn',
        'NOAPM=1',
        'ADD_OPINSIGHTS_WORKSPACE=1',
        'OPINSIGHTS_WORKSPACE_AZURE_CLOUD_TYPE=0',
        "OPINSIGHTS_WORKSPACE_ID=""$id""",
        "OPINSIGHTS_WORKSPACE_KEY=""$key""",
        'AcceptEndUserLicenseAgreement=1'
    )
    Wait         = $true
}

# install the agent with prepared parameters
Start-Process @spParams

# delete setup files and temp folders
Write-Verbose 'Cleaning up setup & temporary files...'
@(
    $agentInstallfile,
    $setupFile,
    $dirName
) | foreach-Object {
    Remove-Item -Path $_ -Recurse -Force -Verbose
}
