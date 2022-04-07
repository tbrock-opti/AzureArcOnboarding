 
# fail script if not running as administrator
#Requires -RunAsAdministrator

param (
    # object containing secrets from LastPass
    [PSCustomObject]
    $secrets
)

# download arc agent install file
Write-Verbose 'Downloading Arc installer...' -Verbose
$agentInstallfile = $($env:temp + '\AzureConnectedMachineAgent.msi')
Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile $agentInstallfile -UseBasicParsing
      
# Install the package
Write-Verbose -Message "Installing agent package" -Verbose
$spParams = @{
    FilePath     = 'c:\windows\system32\msiexec.exe'
    ArgumentList = @("/i", "$agentInstallFile" , "/l*v", "installationlog.txt", "/qn")
    Wait         = $true
    Passthru     = $true
}
Start-Process @spParams

# parameters to connect agent to tenant
Write-Verbose 'Connecting Arc agent to tenant...' -Verbose
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
Write-Verbose 'Download Log & Analytics agent setup file...' -Verbose
$setupFile = $($env:temp + '\MMASetup-AMD64.exe')
Invoke-WebRequest 'https://go.microsoft.com/fwlink/?LinkId=828603' -OutFile $setupFile -UseBasicParsing

# create directory to extract setup files
Write-Verbose 'Creating temporary directory...' -Verbose
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
Write-Verbose 'Running Log & Analytics agent installer...' -Verbose
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
Write-Verbose 'Cleaning up setup & temporary files...' -Verbose
@(
    $agentInstallfile,
    $setupFile,
    $dirName
) | foreach-Object {
    Remove-Item -Path $_ -Recurse -Force -Verbose
}

# SIG # Begin signature block
# MIIJcQYJKoZIhvcNAQcCoIIJYjCCCV4CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU6m8S8ZhBeJccGeS7a8c7NlGB
# DoegggbfMIIG2zCCBcOgAwIBAgITXgAAAgVUlTZhfue45wACAAACBTANBgkqhkiG
# 9w0BAQsFADBEMRIwEAYKCZImiZPyLGQBGRYCc2UxEjAQBgoJkiaJk/IsZAEZFgJl
# cDEaMBgGA1UEAxMRRVBpU2VydmVyLWVwaWNhMDEwHhcNMjIwMzI0MTcyMTI5WhcN
# MjMwMzI0MTcyMTI5WjCBjTESMBAGCgmSJomT8ixkARkWAnNlMRIwEAYKCZImiZPy
# LGQBGRYCZXAxEjAQBgNVBAsTCUVQaVNlcnZlcjEWMBQGA1UECxMNTWFuYWdlZCBV
# c2VyczEfMB0GA1UECxMWSW5mb3JtYXRpb24gVGVjaG5vbG9neTEWMBQGA1UEAxMN
# VGltb3RoeSBCcm9jazCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMHa
# 1U92Wsl3UmHSEKzx/kOX3qfwFPzZ/T4a9VesRhT6f/nJ/DFqx7DN/IOzwf7pcgr4
# zECS1n6yRzt5+csYxY9S3fA6cowvJTA0c9dzLXMKOPSwR951DCqQH6yzOCM90nto
# JgeyPy7u2jWlMAdU/oPMzOMDLsZiJEWl83rZumCk+ciYj+6ZPWuQkS/gOHY28iLU
# lUSWCUqEMRhadf6TkWkeoBraOHvBtBfOfrMgbPD3YOwbsjCBZenkXjv+oShG8E24
# 4GP0U40Uf8rpXmPzxdSkNAuC5oh9bFMfKrY8GaILZX2bq+qCMYPyu3k2iFefYqqG
# AW3cr4G44rcRdw/2k40CAwEAAaOCA3owggN2MD0GCSsGAQQBgjcVBwQwMC4GJisG
# AQQBgjcVCIeRzDOG05x2hp2dCIGQuxKH2NZNbIPrszCCsPMuAgFkAgELMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMA4GA1UdDwEB/wQEAwIHgDAbBgkrBgEEAYI3FQoEDjAM
# MAoGCCsGAQUFBwMDMB0GA1UdDgQWBBQ9JOFh8ZepkdrjhE8hHhhlDPlktjBVBgNV
# HREETjBMgRx0aW1vdGh5LmJyb2NrQG9wdGltaXplbHkuY29toCwGCisGAQQBgjcU
# AgOgHgwcdGltb3RoeS5icm9ja0BvcHRpbWl6ZWx5LmNvbTAfBgNVHSMEGDAWgBTE
# //EWZJIHUdc9b+QzsASFE3Ol+TCCAT8GA1UdHwSCATYwggEyMIIBLqCCASqgggEm
# hoG0bGRhcDovLy9DTj1FUGlTZXJ2ZXItZXBpY2EwMSxDTj1lcGljYXJvb3QsQ049
# Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNv
# bmZpZ3VyYXRpb24sREM9ZXAsREM9c2U/Y2VydGlmaWNhdGVSZXZvY2F0aW9uTGlz
# dD9iYXNlP29iamVjdENsYXNzPWNSTERpc3RyaWJ1dGlvblBvaW50hjdodHRwOi8v
# ZXBpY2Fyb290LmVwLnNlL0NlcnRFbnJvbGwvRVBpU2VydmVyLWVwaWNhMDEuY3Js
# hjRodHRwOi8vbWFpbC5lcGlzZXJ2ZXIuY29tL2NybGQvRVBpU2VydmVyLWVwaWNh
# MDEuY3JsMIIBFwYIKwYBBQUHAQEEggEJMIIBBTCBqgYIKwYBBQUHMAKGgZ1sZGFw
# Oi8vL0NOPUVQaVNlcnZlci1lcGljYTAxLENOPUFJQSxDTj1QdWJsaWMlMjBLZXkl
# MjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPWVwLERD
# PXNlP2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0aWZpY2F0aW9u
# QXV0aG9yaXR5MFYGCCsGAQUFBzAChkpodHRwOi8vZXBpY2Fyb290LmVwLnNlL0Nl
# cnRFbnJvbGwvZXBpY2Fyb290LmVwLnNlX0VQaVNlcnZlci1lcGljYTAxKDIpLmNy
# dDANBgkqhkiG9w0BAQsFAAOCAQEAjnw+8xJ+D6UJfFdEha0MxcsyYOqH2R5BRRnU
# f9NKtf3IxucajuWeic7gqcG6zCJO5WnvVEoJw2Pc22IvJLDaxbILNlIbrjDqOUaR
# Wm3WuSHH+38Jpnk0RiTebsYVJM3J4H0Hj/WvgLcqQRncgwCUV0qQIsUd2gkT70TW
# ZmOsulYY8u6LyFPO2WgpquxaK0TGAP6Lkbj+7gdcfwq2kG21g9f6gqaJf4UoIZHi
# Lu0s7ByFjCW7OwFtcNvmRHGb0/DPyX01QoD0qrCB3oZTnPVNh9Hno0zY8PnXC8oT
# 2eg+VTWXFkOEtJXOYYUjZLbEXGH9kwk/NzZFqYqJSwZOGQZ2EDGCAfwwggH4AgEB
# MFswRDESMBAGCgmSJomT8ixkARkWAnNlMRIwEAYKCZImiZPyLGQBGRYCZXAxGjAY
# BgNVBAMTEUVQaVNlcnZlci1lcGljYTAxAhNeAAACBVSVNmF+57jnAAIAAAIFMAkG
# BSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJ
# AzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMG
# CSqGSIb3DQEJBDEWBBRNMgw89w0adX2lZc0VE4X7YrMazzANBgkqhkiG9w0BAQEF
# AASCAQBsoCRzt+J5B8V0izWavGrQuHFdIn3HXUleKAe/+ECJzBisyXDs/zJ0ImbW
# mMuIp+KHHU4RIqikXeOJorSbr9XD/+gtOawW32SuOJ+0lUbnJ+erfiFpK27QqM26
# 8YIwA/q18SGJKRCace1j4hJRU0FEcrigtFaUoyw58+1h1JuXacYn9kh1MZXQypgN
# mB30Feu4ZPJb/kj4sHceKLTMgCvKpsZqBI6R8D4rS/708JbfMAIXujUo4CkuHJ/5
# Ec1Pm+CS6L2topXfezPjmuPExulkXfpyLvYoe0vIBYOxejngTNq3veXgaFb3Kic6
# tHG0rlk7r8fzoMDDbcGyJjz+ajIz
# SIG # End signature block
