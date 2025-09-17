# Harbor Registry Integration - Deployment Guide

This guide explains how to deploy the Argo Workflows model deployment pipeline on your cluster with Harbor registry integration.

## 🏗️ **Harbor Registry Integration Points**

### **Stage 1: Container Build & Push (Primary Integration)**
- **When**: During the `build-and-push-container` step
- **What**: Builds Docker images and pushes to Harbor registry
- **Benefits**: 
  - Centralized image storage
  - Image versioning and tagging
  - Security scanning (if enabled)
  - Access control and permissions

### **Stage 2: MLflow Model Tracking**
- **When**: During the `register-mlflow` step
- **What**: Tracks Harbor image references in MLflow
- **Benefits**:
  - Links models to their container images
  - Tracks deployment history
  - Enables model rollback capabilities

### **Stage 3: Kubernetes Deployment**
- **When**: During the `generate-values` step
- **What**: Configures image pull secrets and image references
- **Benefits**:
  - Secure image pulling
  - Proper authentication
  - Image pull policies

## 📋 **Required Parameters**

### **Mandatory Parameters:**
```bash
MODEL_NAME="your-model-name"                    # e.g., "production-embedding-v1"
MODEL_HF_PATH="huggingface/model-path"          # e.g., "BAAI/bge-large-en-v1.5"
HARBOR_REGISTRY_URL="harbor.yourcompany.com"   # Your Harbor registry URL
HARBOR_USERNAME="harbor-username"               # Harbor login username
HARBOR_PASSWORD="harbor-password"               # Harbor login password
```

### **Optional Parameters (with defaults):**
```bash
MODEL_TYPE="default-vllm"                       # Options: default-vllm, trt, triton
NAMESPACE="staging-models"                      # Target Kubernetes namespace
HARBOR_PROJECT="ml-models"                      # Harbor project name
IMAGE_NAME=""                                   # Auto-generated if empty
MLFLOW_TRACKING_URI="http://mlflow-server:5000" # MLflow server URL
GITHUB_TOKEN=""                                 # For repository access
```

## 🚀 **Deployment Steps**

### **Step 1: Prerequisites Setup**

1. **Install Argo Workflows:**
```bash
kubectl create namespace argo
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.4/install.yaml
```

2. **Configure RBAC:**
```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argo-workflow-role
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["argoproj.io"]
  resources: ["workflows", "workflowtemplates", "cronworkflows"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["services", "namespaces"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argo-workflow-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argo-workflow-role
subjects:
- kind: ServiceAccount
  name: argo
  namespace: argo
EOF
```

3. **Deploy Harbor-integrated Workflow Template:**
```bash
kubectl apply -f workflows/harbor-integrated-deployment.yaml
```

### **Step 2: Create Harbor Project**

1. **Access Harbor UI:**
   - Navigate to `https://your-harbor-registry.com`
   - Login with admin credentials

2. **Create ML Models Project:**
   - Go to Projects → New Project
   - Project Name: `ml-models` (or your preferred name)
   - Access Level: Private (recommended)
   - Enable vulnerability scanning (optional)

### **Step 3: Configure Image Pull Secrets**

Create Kubernetes secrets for Harbor authentication:

```bash
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=harbor.yourcompany.com \
  --docker-username=your-username \
  --docker-password=your-password \
  --docker-email=your-email@company.com \
  --namespace=staging-models
```

### **Step 4: Deploy MLflow (Optional)**

If you don't have MLflow running:

```bash
kubectl create namespace mlflow
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mlflow-server
  namespace: mlflow
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mlflow-server
  template:
    metadata:
      labels:
        app: mlflow-server
    spec:
      containers:
      - name: mlflow
        image: python:3.9-slim
        command: ["sh", "-c"]
        args:
        - |
          pip install mlflow
          mlflow server --host 0.0.0.0 --port 5000
        ports:
        - containerPort: 5000
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
apiVersion: v1
kind: Service
metadata:
  name: mlflow-server
  namespace: mlflow
spec:
  selector:
    app: mlflow-server
  ports:
  - port: 5000
    targetPort: 5000
EOF
```

## 🎯 **Usage Examples**

### **Example 1: Basic Deployment**
```bash
./scripts/trigger-harbor-deployment.sh \
  --model-name "embedding-model-v1" \
  --model-hf-path "BAAI/bge-large-en-v1.5" \
  --harbor-registry-url "harbor.company.com" \
  --harbor-username "admin" \
  --harbor-password "Harbor12345"
```

### **Example 2: Production Deployment with Custom Settings**
```bash
./scripts/trigger-harbor-deployment.sh \
  --model-name "production-llm-model" \
  --model-hf-path "microsoft/DialoGPT-medium" \
  --model-type "trt" \
  --namespace "production-models" \
  --harbor-registry-url "harbor.company.com" \
  --harbor-username "mlops-user" \
  --harbor-password "SecurePassword123" \
  --harbor-project "production-models" \
  --mlflow-tracking-uri "http://mlflow.company.com:5000"
```

### **Example 3: Custom Image Name**
```bash
./scripts/trigger-harbor-deployment.sh \
  --model-name "custom-model" \
  --model-hf-path "sentence-transformers/all-MiniLM-L6-v2" \
  --image-name "custom-embedding-server" \
  --harbor-registry-url "harbor.company.com" \
  --harbor-username "admin" \
  --harbor-password "Harbor12345"
```

## 🔍 **Harbor Integration Benefits**

### **1. Image Management:**
- **Centralized Storage**: All model images stored in one location
- **Version Control**: Multiple tags (latest, timestamp, model-name)
- **Access Control**: Project-based permissions
- **Vulnerability Scanning**: Security scanning of images

### **2. Deployment Efficiency:**
- **Faster Pulls**: Local registry reduces download time
- **Reliability**: No dependency on external registries
- **Bandwidth Savings**: Reduced external traffic

### **3. Security:**
- **Private Registry**: Images not exposed publicly
- **Authentication**: Secure access with credentials
- **Scanning**: Vulnerability detection and reporting

## 📊 **Image Tagging Strategy**

The pipeline creates multiple tags for each image:

1. **Latest Tag**: `harbor.company.com/ml-models/vllm-server:latest`
2. **Timestamp Tag**: `harbor.company.com/ml-models/vllm-server:20250917-143022`
3. **Model Tag**: `harbor.company.com/ml-models/vllm-server:model-name`

## 🔧 **Troubleshooting**

### **Common Issues:**

1. **Harbor Authentication Failed:**
   ```bash
   # Check Harbor connectivity
   curl -k https://harbor.company.com/api/v2.0/projects
   
   # Verify credentials
   docker login harbor.company.com -u username -p password
   ```

2. **Image Pull Secrets:**
   ```bash
   # Verify secret exists
   kubectl get secret harbor-registry-secret -n target-namespace
   
   # Check secret content
   kubectl get secret harbor-registry-secret -n target-namespace -o yaml
   ```

3. **Workflow Permissions:**
   ```bash
   # Check RBAC configuration
   kubectl auth can-i create pods --as=system:serviceaccount:argo:argo
   kubectl auth can-i get applications --as=system:serviceaccount:argo:argo
   ```

## 📈 **Monitoring and Observability**

### **Harbor UI:**
- View pushed images in Harbor web interface
- Check vulnerability scan results
- Monitor project usage and quotas

### **Argo Workflows UI:**
```bash
kubectl port-forward svc/argo-server -n argo 2746:2746
# Open https://localhost:2746
```

### **MLflow UI:**
```bash
kubectl port-forward svc/mlflow-server -n mlflow 5000:5000
# Open http://localhost:5000
```

## 🚀 **Production Considerations**

1. **Harbor High Availability**: Deploy Harbor in HA mode
2. **Image Scanning**: Enable vulnerability scanning
3. **Backup Strategy**: Regular Harbor data backups
4. **Monitoring**: Set up alerts for registry health
5. **Security**: Use TLS certificates and strong passwords
6. **Quotas**: Set project quotas to prevent resource exhaustion

This Harbor integration provides a robust, secure, and efficient way to manage model container images in your Kubernetes environment!
