# TaskFlow - Deploy All in One Script
# Usage: .\deploy-all.ps1 [-CreateCluster] [-WaitForReady] [-Namespace default]

param(
    [switch]$CreateCluster,
    [switch]$WaitForReady,
    [string]$Namespace = "default",
    [string]$ClusterName = "taskflow"
)

# Source helper functions
$scriptDir = Split-Path -Parent $MyInvocation.PSCommandPath
. (Join-Path $scriptDir "helpers.ps1")

function Deploy-All {
    param(
        [switch]$CreateCluster,
        [switch]$WaitForReady,
        [string]$Namespace,
        [string]$ClusterName
    )
    
    Write-Status "========================================" 
    Write-Status "TaskFlow Kubernetes Deployment"
    Write-Status "========================================"
    
    # Step 1: Create KIND cluster if requested
    if ($CreateCluster) {
        Write-Status "`n[Step 1/3] Creating KIND cluster..."
        & (Join-Path $scriptDir "create-kind-cluster.ps1") -ClusterName $ClusterName
    }
    else {
        Write-Status "`n[Step 1/3] KIND cluster creation skipped (use -CreateCluster to enable)"
    }
    
    # Step 2: Deploy TaskFlow
    Write-Status "`n[Step 2/3] Deploying TaskFlow..."
    $deployArgs = @(
        "-ReleaseName", "taskflow",
        "-Namespace", $Namespace
    )
    
    if ($WaitForReady) {
        $deployArgs += "-WaitForReady"
    }
    
    & (Join-Path $scriptDir "deploy-kind.ps1") @deployArgs
    
    # Step 3: Show status
    Write-Status "`n[Step 3/3] Deployment status..."
    kubectl get all -n $Namespace
    
    Write-Status "`n========================================" -Status "SUCCESS"
    Write-Status "TaskFlow deployed successfully!" -Status "SUCCESS"
    Write-Status "========================================"
    Write-Status "`nAccess points:"
    Write-Status "  - Frontend: http://taskflow.local"
    Write-Status "  - Backend:  http://taskflow-backend:3001 (internal)"
    Write-Status "  - Database: taskflow-postgres:5432 (internal)"
    Write-Status "`nNext steps:"
    Write-Status "  1. Update your /etc/hosts file:"
    Write-Status "     127.0.0.1  taskflow.local"
    Write-Status "  2. To uninstall: .\uninstall.ps1"
    Write-Status "  3. For logs: kubectl logs -f deployment/taskflow-frontend -n $Namespace"
}

try {
    Deploy-All -CreateCluster:$CreateCluster -WaitForReady:$WaitForReady -Namespace $Namespace -ClusterName $ClusterName
}
catch {
    Write-Status $_.Exception.Message -Status "ERROR"
    exit 1
}
