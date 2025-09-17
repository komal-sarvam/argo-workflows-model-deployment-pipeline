#!/bin/bash

# Script to trigger model deployment workflow with Harbor registry integration
# Usage: ./trigger-harbor-deployment.sh <model-name> <model-hf-path> [options]

set -e

# Default values
MODEL_TYPE="default-vllm"
NAMESPACE="staging-models"
IMAGE_NAME=""
MLFLOW_TRACKING_URI="http://mlflow-server:5000"
HARBOR_REGISTRY_URL=""
HARBOR_USERNAME=""
HARBOR_PASSWORD=""
HARBOR_PROJECT="ml-models"
GITHUB_TOKEN=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --model-name)
      MODEL_NAME="$2"
      shift 2
      ;;
    --model-hf-path)
      MODEL_HF_PATH="$2"
      shift 2
      ;;
    --model-type)
      MODEL_TYPE="$2"
      shift 2
      ;;
    --image-name)
      IMAGE_NAME="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --harbor-registry-url)
      HARBOR_REGISTRY_URL="$2"
      shift 2
      ;;
    --harbor-username)
      HARBOR_USERNAME="$2"
      shift 2
      ;;
    --harbor-password)
      HARBOR_PASSWORD="$2"
      shift 2
      ;;
    --harbor-project)
      HARBOR_PROJECT="$2"
      shift 2
      ;;
    --mlflow-tracking-uri)
      MLFLOW_TRACKING_URI="$2"
      shift 2
      ;;
    --github-token)
      GITHUB_TOKEN="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 --model-name <name> --model-hf-path <path> [options]"
      echo ""
      echo "Required Arguments:"
      echo "  --model-name <name>        Name of the model to deploy"
      echo "  --model-hf-path <path>     HuggingFace model path"
      echo "  --harbor-registry-url <url> Harbor registry URL"
      echo "  --harbor-username <user>   Harbor registry username"
      echo "  --harbor-password <pass>   Harbor registry password"
      echo ""
      echo "Optional Arguments:"
      echo "  --model-type <type>        Model type (default-vllm, trt, triton) [default: default-vllm]"
      echo "  --image-name <name>        Container image name [auto-generated if not provided]"
      echo "  --namespace <ns>           Target namespace [default: staging-models]"
      echo "  --harbor-project <proj>    Harbor project name [default: ml-models]"
      echo "  --mlflow-tracking-uri <uri> MLflow server URI [default: http://mlflow-server:5000]"
      echo "  --github-token <token>     GitHub token for repository access"
      echo ""
      echo "Examples:"
      echo "  $0 --model-name my-model --model-hf-path BAAI/bge-small-en-v1.5 \\"
      echo "      --harbor-registry-url harbor.company.com \\"
      echo "      --harbor-username admin --harbor-password Harbor123"
      echo ""
      echo "  $0 --model-name production-model --model-hf-path microsoft/DialoGPT-medium \\"
      echo "      --model-type trt --namespace production \\"
      echo "      --harbor-registry-url harbor.company.com \\"
      echo "      --harbor-username admin --harbor-password Harbor123 \\"
      echo "      --harbor-project production-models"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$MODEL_NAME" ]; then
    echo "❌ ERROR: --model-name is required"
    echo "Use --help for usage information"
    exit 1
fi

if [ -z "$MODEL_HF_PATH" ]; then
    echo "❌ ERROR: --model-hf-path is required"
    echo "Use --help for usage information"
    exit 1
fi

if [ -z "$HARBOR_REGISTRY_URL" ]; then
    echo "❌ ERROR: --harbor-registry-url is required"
    echo "Use --help for usage information"
    exit 1
fi

if [ -z "$HARBOR_USERNAME" ]; then
    echo "❌ ERROR: --harbor-username is required"
    echo "Use --help for usage information"
    exit 1
fi

if [ -z "$HARBOR_PASSWORD" ]; then
    echo "❌ ERROR: --harbor-password is required"
    echo "Use --help for usage information"
    exit 1
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

echo "🚀 Triggering Harbor-integrated model deployment workflow..."
echo "   Model Name: $MODEL_NAME"
echo "   Model HF Path: $MODEL_HF_PATH"
echo "   Model Type: $MODEL_TYPE"
echo "   Image Name: $IMAGE_NAME"
echo "   Namespace: $NAMESPACE"
echo "   Harbor Registry: $HARBOR_REGISTRY_URL"
echo "   Harbor Project: $HARBOR_PROJECT"
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
    harbor-registry: ${HARBOR_REGISTRY_URL}
spec:
  workflowTemplateRef:
    name: harbor-model-deployment-pipeline
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
      value: "${GITHUB_TOKEN}"
    - name: mlflow-tracking-uri
      value: "${MLFLOW_TRACKING_URI}"
    - name: harbor-registry-url
      value: "${HARBOR_REGISTRY_URL}"
    - name: harbor-username
      value: "${HARBOR_USERNAME}"
    - name: harbor-password
      value: "${HARBOR_PASSWORD}"
    - name: harbor-project
      value: "${HARBOR_PROJECT}"
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
echo "🏗️ Harbor Registry Integration:"
echo "   - Images will be pushed to: ${HARBOR_REGISTRY_URL}/${HARBOR_PROJECT}/"
echo "   - Image tags: latest, timestamp, model-name"
echo "   - Authentication: Configured automatically"
echo ""

# Clean up temporary file
rm -f /tmp/workflow-${WORKFLOW_NAME}.yaml

echo "✅ Harbor-integrated workflow triggered successfully!"
