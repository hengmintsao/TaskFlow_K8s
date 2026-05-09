# TaskFlow Helm Deployment - Helper Functions
# Common functions used across deployment scripts

$ErrorActionPreference = "Stop"

function Test-HelmInstalled {
    try {
        helm version > $null 2>&1
        return $true
    }
    catch {
        return $false
    }
}

function Test-KubectlInstalled {
    try {
        kubectl version --client > $null 2>&1
        return $true
    }
    catch {
        return $false
    }
}

function Test-KindInstalled {
    try {
        kind version > $null 2>&1
        return $true
    }
    catch {
        return $false
    }
}

function Get-ChartDirectory {
    param(
        [string]$RelativePath = ".",
        [string]$ScriptDir
    )
    $projectRoot = Split-Path -Parent $ScriptDir
    return Join-Path -Path $projectRoot -ChildPath (Join-Path "charts" $RelativePath)
}

function Get-ValuesFile {
    param(
        [string]$Environment,
        [string]$ScriptDir
    )
    $projectRoot = Split-Path -Parent $ScriptDir
    return Join-Path -Path $projectRoot -ChildPath (Join-Path "values" "$Environment.yaml")
}

function Write-Status {
    param(
        [string]$Message,
        [string]$Status = "INFO"
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    switch ($Status) {
        "SUCCESS" { Write-Host "[$timestamp] ✓ $Message" -ForegroundColor Green }
        "ERROR" { Write-Host "[$timestamp] ✗ $Message" -ForegroundColor Red }
        "WARNING" { Write-Host "[$timestamp] ⚠ $Message" -ForegroundColor Yellow }
        default { Write-Host "[$timestamp] ℹ $Message" -ForegroundColor Cyan }
    }
}

function Wait-ForDeployment {
    param(
        [string]$ReleaseName,
        [string]$Namespace = "default",
        [int]$TimeoutSeconds = 300
    )
    Write-Status "Waiting for deployment to be ready..."
    kubectl rollout status deployment -n $Namespace -l "app.kubernetes.io/instance=$ReleaseName" --timeout="${TimeoutSeconds}s"
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Deployment ready!" -Status "SUCCESS"
    }
    else {
        Write-Status "Deployment failed or timed out" -Status "ERROR"
        throw "Deployment did not become ready within $TimeoutSeconds seconds"
    }
}

function Update-HelmDependencies {
    param(
        [string]$ChartPath
    )
    Write-Status "Updating Helm dependencies..."
    helm dependency update $ChartPath
    Write-Status "Dependencies updated" -Status "SUCCESS"
}

# Export functions only if running as module
if ($MyInvocation.MyCommand.Name -match '\.psm1$') {
    Export-ModuleMember -Function @(
        'Test-HelmInstalled',
        'Test-KubectlInstalled',
        'Test-KindInstalled',
        'Get-ChartDirectory',
        'Get-ValuesFile',
        'Write-Status',
        'Wait-ForDeployment',
        'Update-HelmDependencies'
    )
}
