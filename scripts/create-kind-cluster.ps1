# TaskFlow - Create KIND Cluster
# Usage: .\create-kind-cluster.ps1 [-ClusterName taskflow] [-NodeImage kindest/node:v1.27.0]

param(
    [string]$ClusterName = "taskflow",
    [string]$NodeImage = "kindest/node:v1.27.0",
    [int]$ControlPlanes = 1,
    [int]$Workers = 2
)

# Source helper functions
$scriptDir = Split-Path -Parent $MyInvocation.PSCommandPath
. (Join-Path $scriptDir "helpers.ps1")

function Create-KindCluster {
    param(
        [string]$ClusterName,
        [string]$NodeImage,
        [int]$ControlPlanes,
        [int]$Workers
    )
    
    # Check prerequisites
    Write-Status "Checking prerequisites..."
    if (-not (Test-KindInstalled)) {
        Write-Status "KIND is not installed" -Status "ERROR"
        throw "Please install KIND: https://kind.sigs.k8s.io/docs/user/quick-start"
    }
    if (-not (Test-KubectlInstalled)) {
        Write-Status "kubectl is not installed" -Status "ERROR"
        throw "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
    }
    
    Write-Status "Prerequisites OK" -Status "SUCCESS"
    
    # Check if cluster already exists
    $existingCluster = kind get clusters 2>$null | Where-Object { $_ -eq $ClusterName }
    if ($existingCluster) {
        Write-Status "Cluster '$ClusterName' already exists" -Status "WARNING"
        $response = Read-Host "Delete and recreate? (yes/no)"
        if ($response -eq "yes") {
            Write-Status "Deleting cluster '$ClusterName'..."
            kind delete cluster --name $ClusterName
        }
        else {
            Write-Status "Using existing cluster '$ClusterName'"
            return
        }
    }
    
    # Create KIND config file
    $kindConfig = @"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $ClusterName
nodes:
  # Control plane
  - role: control-plane
    image: $NodeImage
    ports:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
"@
    
    # Add worker nodes
    for ($i = 0; $i -lt $Workers; $i++) {
        $kindConfig += @"

  - role: worker
    image: $NodeImage
"@
    }
    
    # Create temporary config file
    $tempConfig = Join-Path $env:TEMP "kind-config-$([guid]::NewGuid().ToString()).yaml"
    $kindConfig | Out-File -FilePath $tempConfig -Encoding UTF8
    
    try {
        Write-Status "Creating KIND cluster '$ClusterName'..."
        Write-Status "Node Image: $NodeImage"
        Write-Status "Control Planes: $ControlPlanes"
        Write-Status "Workers: $Workers"
        
        kind create cluster --name $ClusterName --config $tempConfig
        
        if ($LASTEXITCODE -ne 0) {
            Write-Status "Failed to create KIND cluster" -Status "ERROR"
            throw "KIND cluster creation failed"
        }
        
        Write-Status "KIND cluster created successfully!" -Status "SUCCESS"
        
        # Install ingress-nginx
        Write-Status "Installing ingress-nginx controller..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
        
        if ($LASTEXITCODE -eq 0) {
            Write-Status "ingress-nginx installed" -Status "SUCCESS"
        }
        else {
            Write-Status "Failed to install ingress-nginx" -Status "WARNING"
        }
        
        Write-Status "`nCluster Information:"
        kubectl cluster-info
        Write-Status "`nNode Status:"
        kubectl get nodes
    }
    finally {
        # Clean up temp file
        Remove-Item -Path $tempConfig -Force -ErrorAction SilentlyContinue
    }
}

try {
    Create-KindCluster -ClusterName $ClusterName -NodeImage $NodeImage -ControlPlanes $ControlPlanes -Workers $Workers
}
catch {
    Write-Status $_.Exception.Message -Status "ERROR"
    exit 1
}
