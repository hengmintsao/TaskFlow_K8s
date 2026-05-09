# TaskFlow 完整運行指南

## 🏗️ 您的項目架構

```
C:\TaskFlow_K8s_ToDoList_Backend\        ← 後端 repo
C:\TaskFlow_K8s_ToDoList_Frontend\my-app ← 前端 repo
C:\TaskFlow_K8s\                          ← 部署 repo (Kustomize + Helm)
```

### 服務配置

| 服務 | 端口 | 容器名 | 說明 |
|------|------|--------|------|
| **後端 API** | 8000 | taskflow-api | Python/FastAPI + uvicorn |
| **前端** | 3000 | 無指定 | Next.js |
| **數據庫** | 5432 | taskflow-db | PostgreSQL 15 (docker-compose 管理) |

---

## 🚀 完整運行流程（包含本地開發 + K8s 部署）

### **第 1 階段：本地開發 (docker-compose)**

#### 1.1 啟動後端 + 數據庫

```powershell
cd C:\TaskFlow_K8s_ToDoList_Backend\TaskFlow_K8s_ToDoList_Backend

# 檢查 docker-compose.yml
cat docker-compose.yml

# 啟動後端和 PostgreSQL
docker-compose up -d

# 檢查容器狀態
docker-compose ps
```

**預期輸出：**
```
NAME           IMAGE               COMMAND                 PORTS
taskflow-api   ...python:latest    "python -m uvicorn..." 0.0.0.0:8000->8000/tcp
taskflow-db    postgres:15         "docker-entrypoint..."  0.0.0.0:5432->5432/tcp
```

**驗證後端是否運行：**
```powershell
# 檢查 API 健康狀態
curl http://localhost:8000/docs

# 應該看到 Swagger UI 文檔頁面
```

**查看日誌：**
```powershell
# 即時日誌
docker-compose logs -f api

# 檢查數據庫連接
docker-compose logs db
```

---

#### 1.2 啟動前端

打開 **新的 PowerShell 終端** (重要，不要在同一個終端)

```powershell
cd C:\TaskFlow_K8s_ToDoList_Frontend\my-app

# 檢查 docker-compose.yml
cat docker-compose.yml

# 啟動前端
docker-compose up -d

# 檢查容器狀態
docker-compose ps
```

**預期輸出：**
```
NAME      IMAGE          COMMAND                PORTS
...app    my-app:latest  "docker-entrypoint..." 0.0.0.0:3000->3000/tcp
```

**驗證前端是否運行：**
```powershell
# 在瀏覽器打開
http://localhost:3000

# 應該看到 Next.js 應用
```

**查看日誌：**
```powershell
docker-compose logs -f app
```

---

#### 1.3 本地開發完整檢查清單

- [ ] 後端運行在 `http://localhost:8000`
- [ ] 數據庫運行在 `localhost:5432`
- [ ] 前端運行在 `http://localhost:3000`
- [ ] 前端能訪問後端 API
- [ ] 沒有連接錯誤

**測試前後端連通性：**
```powershell
# 從前端調用後端 API 測試
Invoke-WebRequest -Uri "http://localhost:8000/docs" -UseBasicParsing
```

---

### **第 2 階段：構建並推送 Docker 鏡像**

#### 2.1 後端鏡像（本地使用，不推送）

```powershell
cd C:\TaskFlow_K8s_ToDoList_Backend\TaskFlow_K8s_ToDoList_Backend

# 構建後端鏡像
docker build -t taskflow-backend:latest .

# 或指定版本
docker build -t taskflow-backend:v1.0.0 .

# 驗證鏡像
docker images | grep taskflow-backend
```

---

#### 2.2 前端鏡像（推送到 Docker Hub/Registry）

```powershell
cd C:\TaskFlow_K8s_ToDoList_Frontend\my-app

# 構建前端鏡像
docker build -t taskflow-frontend:latest .

# 或指定版本
docker build -t taskflow-frontend:v1.0.0 .

# 驗證鏡像
docker images | grep taskflow-frontend
```

**推送到 Docker Hub（如果需要）：**
```powershell
# 登錄 Docker Hub
docker login

# 標記鏡像（替換 YOUR_DOCKERHUB_USER）
docker tag taskflow-frontend:latest YOUR_DOCKERHUB_USER/taskflow-frontend:latest
docker tag taskflow-frontend:v1.0.0 YOUR_DOCKERHUB_USER/taskflow-frontend:v1.0.0

# 推送
docker push YOUR_DOCKERHUB_USER/taskflow-frontend:latest
docker push YOUR_DOCKERHUB_USER/taskflow-frontend:v1.0.0
```

---

### **第 3 階段：部署到 KIND Kubernetes 集群**

#### 3.1 準備 KIND 集群

```powershell
# 進入部署 repo
cd C:\TaskFlow_K8s

# 檢查是否有 KIND 集群
kind get clusters

# 如果沒有，建立新的
.\scripts\create-kind-cluster.ps1 -ClusterName taskflow -Workers 2
```

**驗證集群：**
```powershell
kubectl cluster-info
kubectl get nodes
```

---

#### 3.2 加載本地鏡像到 KIND 集群（重要！）

```powershell
# 對於後端（本地構建的鏡像）
kind load docker-image taskflow-backend:latest --name taskflow
kind load docker-image taskflow-backend:v1.0.0 --name taskflow

# 對於前端
kind load docker-image taskflow-frontend:latest --name taskflow
kind load docker-image taskflow-frontend:v1.0.0 --name taskflow

# 驗證鏡像已加載
kubectl describe nodes
```

或者，如果前端已推送到 Docker Hub，可以不需要加載，直接從 registry 拉取。

---

#### 3.3 更新 Helm values 文件

編輯 `C:\TaskFlow_K8s\values\kind.yaml`：

```yaml
frontend:
  enabled: true
  replicaCount: 1
  image:
    repository: taskflow-frontend
    tag: latest
    pullPolicy: IfNotPresent  # 或 Always，如果從 registry 拉取

backend:
  enabled: true
  replicaCount: 1
  image:
    repository: taskflow-backend
    tag: latest
    pullPolicy: IfNotPresent

postgres:
  enabled: true
  # ... 其他配置
```

---

#### 3.4 部署到 KIND

```powershell
cd C:\TaskFlow_K8s

# 方式 1: 完整部署腳本（推薦）
.\scripts\deploy-kind.ps1 -WaitForReady

# 方式 2: 手動 Helm 命令
helm install taskflow ./charts/taskflow \
  -f ./values/kind.yaml \
  --namespace default \
  --create-namespace

# 方式 3: 先 dry-run 檢查
helm install taskflow ./charts/taskflow \
  -f ./values/kind.yaml \
  --namespace default \
  --dry-run \
  --debug
```

**驗證部署：**
```powershell
# 檢查 pods
kubectl get pods -n default

# 檢查 services
kubectl get svc -n default

# 檢查 ingress
kubectl get ingress -n default

# 查看詳細信息
kubectl describe pod taskflow-frontend-... -n default
kubectl describe pod taskflow-backend-... -n default
```

---

#### 3.5 訪問已部署的應用

**前端訪問：**
```powershell
# 方式 1: Port Forward（推薦用於測試）
kubectl port-forward svc/taskflow-frontend 3000:3000

# 然後訪問 http://localhost:3000
```

**後端訪問：**
```powershell
# 方式 1: Port Forward
kubectl port-forward svc/taskflow-backend 8000:3001
# 注意：K8s 內部的服務端口是 3001（根據 backend values.yaml），
# 但容器內應用跑在 8000，所以需要檢查 Deployment 的 containerPort

# 方式 2: Ingress（需要配置 /etc/hosts）
# 編輯 C:\Windows\System32\drivers\etc\hosts
# 添加: 127.0.0.1  taskflow.local
# 然後訪問 http://taskflow.local
```

**數據庫訪問：**
```powershell
# Port Forward to PostgreSQL
kubectl port-forward svc/taskflow-postgres 5432:5432

# 然後用客戶端連接 localhost:5432
# 用戶名: postgres
# 密碼: postgres
# 數據庫: taskflow_db
```

---

#### 3.6 查看日誌和調試

```powershell
# 實時日誌（前端）
kubectl logs -f deployment/taskflow-frontend

# 實時日誌（後端）
kubectl logs -f deployment/taskflow-backend

# 查看 pod 事件（用於故障排除）
kubectl describe pod <pod-name>

# 進入容器調試
kubectl exec -it <pod-name> -- /bin/bash

# 查看所有資源
kubectl get all -n default

# 查看 secrets（敏感配置）
kubectl get secrets -n default
```

---

## 📋 完整命令速查表

### docker-compose 命令

```powershell
# ===== 後端 =====
cd C:\TaskFlow_K8s_ToDoList_Backend\TaskFlow_K8s_ToDoList_Backend

docker-compose up -d          # 啟動服務（後台）
docker-compose up             # 啟動服務（前台，看日誌）
docker-compose down           # 停止並刪除容器
docker-compose logs -f        # 查看實時日誌
docker-compose ps             # 查看容器狀態
docker-compose restart        # 重啟服務
docker-compose exec api bash  # 進入 API 容器

# ===== 前端 =====
cd C:\TaskFlow_K8s_ToDoList_Frontend\my-app

docker-compose up -d
docker-compose down
docker-compose logs -f app
# ... 同上
```

### Docker 鏡像命令

```powershell
# 構建
docker build -t taskflow-backend:latest .
docker build -t taskflow-frontend:v1.0.0 .

# 查看鏡像
docker images | grep taskflow

# 推送
docker login
docker tag taskflow-frontend:latest USERNAME/taskflow-frontend:latest
docker push USERNAME/taskflow-frontend:latest

# 刪除鏡像
docker rmi taskflow-backend:latest
```

### Kubernetes 命令

```powershell
cd C:\TaskFlow_K8s

# 集群管理
kind get clusters
kind create cluster --name taskflow
kind delete cluster --name taskflow
kind load docker-image taskflow-backend:latest --name taskflow

# Helm 部署
helm install taskflow ./charts/taskflow -f ./values/kind.yaml
helm upgrade taskflow ./charts/taskflow -f ./values/kind.yaml
helm list
helm uninstall taskflow

# 資源管理
kubectl get pods,svc,ingress -n default
kubectl describe pod <pod-name>
kubectl logs -f <pod-name>
kubectl exec -it <pod-name> -- bash
kubectl port-forward svc/taskflow-frontend 3000:3000

# 腳本（推薦）
.\scripts\deploy-all.ps1 -CreateCluster -WaitForReady
.\scripts\deploy-kind.ps1 -WaitForReady
.\scripts\uninstall.ps1
```

---

## 🔄 典型開發工作流

### 場景 1：本地開發迭代

```powershell
# 終端 1：後端
cd C:\TaskFlow_K8s_ToDoList_Backend\TaskFlow_K8s_ToDoList_Backend
docker-compose up api  # 前台運行，看日誌

# 終端 2：前端
cd C:\TaskFlow_K8s_ToDoList_Frontend\my-app
docker-compose up app  # 前台運行，看日誌

# 編輯代碼
# docker-compose 會自動重載（hot reload）

# 完成後停止
# Ctrl+C 在兩個終端
docker-compose down  # 在每個目錄下執行
```

### 場景 2：測試 Kubernetes 部署

```powershell
# 1. 停止本地 docker-compose
cd C:\TaskFlow_K8s_ToDoList_Backend\TaskFlow_K8s_ToDoList_Backend
docker-compose down

cd C:\TaskFlow_K8s_ToDoList_Frontend\my-app
docker-compose down

# 2. 構建鏡像
docker build -t taskflow-backend:v1.0.0 C:\TaskFlow_K8s_ToDoList_Backend\TaskFlow_K8s_ToDoList_Backend
docker build -t taskflow-frontend:v1.0.0 C:\TaskFlow_K8s_ToDoList_Frontend\my-app

# 3. 加載到 KIND
kind load docker-image taskflow-backend:v1.0.0 --name taskflow
kind load docker-image taskflow-frontend:v1.0.0 --name taskflow

# 4. 更新 values/kind.yaml 中的 tag: v1.0.0

# 5. 部署
cd C:\TaskFlow_K8s
.\scripts\deploy-kind.ps1 -WaitForReady

# 6. 檢查
kubectl port-forward svc/taskflow-frontend 3000:3000
# 訪問 http://localhost:3000
```

### 場景 3：推送到生產環境

```powershell
# 1. 構建前端鏡像（只有前端需要推送）
cd C:\TaskFlow_K8s_ToDoList_Frontend\my-app
docker build -t USERNAME/taskflow-frontend:v1.0.0 .

# 2. 推送
docker login
docker push USERNAME/taskflow-frontend:v1.0.0

# 3. 後端在生產環境單獨部署（不通過此 repo）

# 4. 更新 values/prod.yaml
frontend:
  image:
    repository: USERNAME/taskflow-frontend
    tag: v1.0.0

# 5. 部署到生產
cd C:\TaskFlow_K8s
helm install taskflow ./charts/taskflow -f ./values/prod.yaml -n production --create-namespace
```

---

## ⚙️ 環境變數配置

### 後端環境變數 (docker-compose.yml)

```yaml
environment:
  - ENV=development
  - DATABASE_URL=postgresql://taskflow:password@db:5432/taskflow
  # 添加更多環境變數...
```

### 前端環境變數 (docker-compose.yml)

```yaml
environment:
  - NODE_ENV=production
  - NEXT_PUBLIC_API_URL=http://localhost:8000  # 開發
  # 生產: - NEXT_PUBLIC_API_URL=https://api.prod.com
```

### Kubernetes 秘鑰管理

```powershell
# 查看秘鑰
kubectl get secrets

# 編輯秘鑰
kubectl edit secret taskflow-backend-secret

# 刪除秘鑰（會自動重建）
kubectl delete secret taskflow-backend-secret
```

---

## ❌ 常見問題

| 問題 | 解決方案 |
|------|--------|
| 前端連接不到後端 | 檢查 `NEXT_PUBLIC_API_URL` 環境變數，確認後端在運行 |
| 數據庫連接失敗 | 確認 PostgreSQL 容器在運行，檢查 `DATABASE_URL` 格式 |
| Port 已被占用 | `netstat -ano \| findstr :8000` 找到進程，終止或改端口 |
| K8s Pod 卡在 Pending | `kubectl describe pod` 查看事件，通常是鏡像拉取失敗或資源不足 |
| Ingress 無法訪問 | 檢查 ingress-nginx 是否安裝，更新 `/etc/hosts` |
| Hot reload 不工作 | 確認 volumes mount 正確，檢查 docker-compose.yml |

---

## 🎯 您現在需要做的

1. **立即測試本地開發**：
   ```powershell
   cd C:\TaskFlow_K8s_ToDoList_Backend\TaskFlow_K8s_ToDoList_Backend
   docker-compose up -d
   curl http://localhost:8000/docs
   ```

2. **啟動前端**：
   ```powershell
   cd C:\TaskFlow_K8s_ToDoList_Frontend\my-app
   docker-compose up -d
   # 訪問 http://localhost:3000
   ```

3. **構建鏡像**：
   ```powershell
   docker build -t taskflow-backend:latest C:\TaskFlow_K8s_ToDoList_Backend\TaskFlow_K8s_ToDoList_Backend
   docker build -t taskflow-frontend:latest C:\TaskFlow_K8s_ToDoList_Frontend\my-app
   ```

4. **部署到 KIND**：
   ```powershell
   cd C:\TaskFlow_K8s
   .\scripts\deploy-all.ps1 -CreateCluster -WaitForReady
   ```

---

## 💡 建議

- 💾 將此文檔保存在 `C:\TaskFlow_K8s\RUNNING_GUIDE.md`
- 🔐 別忘了在部署前修改敏感數據（數據庫密碼等）
- 📝 在 `.env` 文件中管理環境變數，不要硬編碼
- 🔄 設置 CI/CD 自動化構建和部署
- 🐳 使用 `docker-compose` 進行本地開發，使用 Helm 進行 K8s 部署
