# TaskFlow - Deploy to KIND cluster
# Usage: .\deploy-kind.ps1 [-WaitForReady] [-DryRun]

param(
    [switch]$WaitForReady,
    [switch]$DryRun,
    [string]$ReleaseName = "taskflow",
    [string]$Namespace = "default"
)

# Source helper functions
$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not $scriptDir) {
    $scriptDir = "."
}
. (Join-Path $scriptDir "helpers.ps1")

function Deploy-ToKind {
    param(
        [string]$ReleaseName,
        [string]$Namespace,
        [switch]$DryRun
    )
    
    # Check prerequisites
    Write-Status "Checking prerequisites..."
    if (-not (Test-HelmInstalled)) {
        Write-Status "Helm is not installed" -Status "ERROR"
        throw "Please install Helm: https://helm.sh/docs/intro/install/"
    }
    if (-not (Test-KubectlInstalled)) {
        Write-Status "kubectl is not installed" -Status "ERROR"
        throw "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
    }
    
    Write-Status "Prerequisites OK" -Status "SUCCESS"
    
    # Get chart and values paths
    $chartPath = Get-ChartDirectory -RelativePath "taskflow" -ScriptDir $scriptDir
    $valuesPath = Get-ValuesFile -Environment "kind" -ScriptDir $scriptDir
    
    if (-not (Test-Path $chartPath)) {
        Write-Status "Chart not found at $chartPath" -Status "ERROR"
        throw "Chart directory does not exist"
    }
    if (-not (Test-Path $valuesPath)) {
        Write-Status "Values file not found at $valuesPath" -Status "ERROR"
        throw "Values file does not exist"
    }
    
    Write-Status "Chart: $chartPath"
    Write-Status "Values: $valuesPath"
    
    # Update dependencies
    Update-HelmDependencies $chartPath
    
    # Build helm command
    $helmCmd = @(
        "helm", "install",
        $ReleaseName,
        $chartPath,
        "-f", $valuesPath,
        "-n", $Namespace,
        "--create-namespace"
    )
    
    if ($DryRun) {
        $helmCmd += "--dry-run", "--debug"
    }
    
    # Deploy
    Write-Status "Deploying TaskFlow to KIND cluster..."
    & $helmCmd[0] @($helmCmd[1..($helmCmd.Length-1)])
    
    if ($LASTEXITCODE -ne 0) {
        Write-Status "Helm install failed" -Status "ERROR"
        throw "Helm deployment failed"
    }
    
    Write-Status "TaskFlow deployed successfully!" -Status "SUCCESS"
    
    # Wait for deployment if requested
    if ($WaitForReady) {
        Wait-ForDeployment -ReleaseName $ReleaseName -Namespace $Namespace
    }
    
    # Show deployment info
    Write-Status "`nDeployment Information:"
    kubectl get pods -n $Namespace
    kubectl get svc -n $Namespace
    kubectl get ingress -n $Namespace
    
    Write-Status "`nAccess TaskFlow at: http://taskflow.local" -Status "SUCCESS"
}

try {
    Deploy-ToKind -ReleaseName $ReleaseName -Namespace $Namespace -DryRun:$DryRun
}
catch {
    Write-Status $_.Exception.Message -Status "ERROR"
    exit 1
}
