#!/bin/bash

# Script to trigger model deployment workflow
# Usage: ./trigger-deployment.sh <model-name> <model-hf-path> [model-type] [image-name] [namespace]

set -e

# Default values
MODEL_TYPE="default-vllm"
NAMESPACE="staging-models"
IMAGE_NAME=""
MLFLOW_TRACKING_URI="http://mlflow-server:5000"

# Parse arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <model-name> <model-hf-path> [model-type] [image-name] [namespace]"
    echo ""
    echo "Arguments:"
    echo "  model-name     : Name of the model to deploy (required)"
    echo "  model-hf-path  : HuggingFace model path (required)"
    echo "  model-type     : Model type (default-vllm, trt, triton) [default: default-vllm]"
    echo "  image-name     : Container image name (optional)"
    echo "  namespace      : Target namespace [default: staging-models]"
    echo ""
    echo "Examples:"
    echo "  $0 my-model BAAI/bge-small-en-v1.5"
    echo "  $0 my-model BAAI/bge-small-en-v1.5 default-vllm modelsync/vllm-server:latest"
    echo "  $0 my-model microsoft/DialoGPT-medium trt modelsync/trt-server:latest production"
    exit 1
fi

MODEL_NAME="$1"
MODEL_HF_PATH="$2"

if [ $# -ge 3 ]; then
    MODEL_TYPE="$3"
fi

if [ $# -ge 4 ]; then
    IMAGE_NAME="$4"
fi

if [ $# -ge 5 ]; then
    NAMESPACE="$5"
fi

# Validate model type
case "$MODEL_TYPE" in
    "default-vllm"|"trt"|"triton")
        echo "✅ Model type is valid: $MODEL_TYPE"
        ;;
    *)
        echo "❌ ERROR: model-type must be one of: default-vllm, trt, triton"
        exit 1
        ;;
esac

# Generate workflow name
WORKFLOW_NAME="deploy-${MODEL_NAME}-$(date +%Y%m%d-%H%M%S)"

echo "🚀 Triggering model deployment workflow..."
echo "   Model Name: $MODEL_NAME"
echo "   Model HF Path: $MODEL_HF_PATH"
echo "   Model Type: $MODEL_TYPE"
echo "   Image Name: $IMAGE_NAME"
echo "   Namespace: $NAMESPACE"
echo "   Workflow Name: $WORKFLOW_NAME"
echo ""

# Create workflow YAML
cat > /tmp/workflow-${WORKFLOW_NAME}.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: ${WORKFLOW_NAME}
  namespace: argo
  labels:
    model-name: ${MODEL_NAME}
    model-type: ${MODEL_TYPE}
    deployment-namespace: ${NAMESPACE}
spec:
  workflowTemplateRef:
    name: advanced-model-deployment-pipeline
  arguments:
    parameters:
    - name: model-name
      value: "${MODEL_NAME}"
    - name: image-name
      value: "${IMAGE_NAME}"
    - name: model-type
      value: "${MODEL_TYPE}"
    - name: model-hf-path
      value: "${MODEL_HF_PATH}"
    - name: namespace
      value: "${NAMESPACE}"
    - name: github-token
      value: ""
    - name: mlflow-tracking-uri
      value: "${MLFLOW_TRACKING_URI}"
    - name: registry-url
      value: "docker.io"
    - name: registry-username
      value: ""
    - name: registry-password
      value: ""
EOF

# Apply the workflow
echo "📝 Creating workflow..."
kubectl apply -f /tmp/workflow-${WORKFLOW_NAME}.yaml

# Wait for workflow to start
echo "⏳ Waiting for workflow to start..."
sleep 5

# Get workflow status
echo "📊 Workflow Status:"
kubectl get workflow ${WORKFLOW_NAME} -n argo

echo ""
echo "🔍 To monitor the workflow progress:"
echo "   kubectl get workflow ${WORKFLOW_NAME} -n argo -w"
echo ""
echo "📋 To view workflow logs:"
echo "   kubectl logs -f workflow/${WORKFLOW_NAME} -n argo"
echo ""
echo "🌐 To view in Argo Workflows UI:"
echo "   kubectl port-forward svc/argo-server -n argo 2746:2746"
echo "   Then open: https://localhost:2746"
echo ""

# Clean up temporary file
rm -f /tmp/workflow-${WORKFLOW_NAME}.yaml

echo "✅ Workflow triggered successfully!"
