# TaskFlow - Uninstall Helm Release
# Usage: .\uninstall.ps1 [-ReleaseName taskflow] [-Namespace default]

param(
    [string]$ReleaseName = "taskflow",
    [string]$Namespace = "default",
    [switch]$Force
)

# Source helper functions
$scriptDir = Split-Path -Parent $MyInvocation.PSCommandPath
. (Join-Path $scriptDir "helpers.ps1")

function Uninstall-Release {
    param(
        [string]$ReleaseName,
        [string]$Namespace,
        [switch]$Force
    )
    
    # Check prerequisites
    Write-Status "Checking prerequisites..."
    if (-not (Test-HelmInstalled)) {
        Write-Status "Helm is not installed" -Status "ERROR"
        throw "Please install Helm: https://helm.sh/docs/intro/install/"
    }
    
    # Check if release exists
    $releases = helm list -n $Namespace -o json | ConvertFrom-Json
    $releaseExists = $releases | Where-Object { $_.name -eq $ReleaseName }
    
    if (-not $releaseExists) {
        Write-Status "Release '$ReleaseName' not found in namespace '$Namespace'" -Status "WARNING"
        return
    }
    
    # Confirm uninstall
    if (-not $Force) {
        Write-Host "`nThis will delete all resources associated with release '$ReleaseName'" -ForegroundColor Yellow
        Write-Host "Including: deployments, services, statefulsets, secrets, ingresses" -ForegroundColor Yellow
        $response = Read-Host "Are you sure? (yes/no)"
        if ($response -ne "yes") {
            Write-Status "Uninstall cancelled" -Status "WARNING"
            return
        }
    }
    
    # Uninstall
    Write-Status "Uninstalling release '$ReleaseName'..."
    helm uninstall $ReleaseName -n $Namespace
    
    if ($LASTEXITCODE -ne 0) {
        Write-Status "Helm uninstall failed" -Status "ERROR"
        throw "Helm uninstall failed"
    }
    
    Write-Status "Release '$ReleaseName' uninstalled successfully!" -Status "SUCCESS"
    Write-Status "`nRemaining resources in namespace '$Namespace':"
    kubectl get all -n $Namespace
}

try {
    Uninstall-Release -ReleaseName $ReleaseName -Namespace $Namespace -Force:$Force
}
catch {
    Write-Status $_.Exception.Message -Status "ERROR"
    exit 1
}
