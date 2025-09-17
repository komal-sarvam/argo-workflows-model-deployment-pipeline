#!/bin/bash

# Setup script for Ingress and Linkerd integration
# This script installs and configures NGINX Ingress Controller and Linkerd service mesh

set -e

echo "🚀 Setting up Ingress and Linkerd for Model Deployment Pipeline"
echo "=============================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_success "Kubernetes cluster is accessible"

# Function to install NGINX Ingress Controller
install_nginx_ingress() {
    print_status "Installing NGINX Ingress Controller..."
    
    # Create namespace
    kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
    
    # Install NGINX Ingress Controller
    if kubectl apply -f ingress/nginx-ingress.yaml; then
        print_success "NGINX Ingress Controller installed successfully"
    else
        print_error "Failed to install NGINX Ingress Controller"
        return 1
    fi
    
    # Wait for ingress controller to be ready
    print_status "Waiting for NGINX Ingress Controller to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    print_success "NGINX Ingress Controller is ready"
}

# Function to install Linkerd
install_linkerd() {
    print_status "Installing Linkerd Service Mesh..."
    
    # Check if Linkerd CLI is available
    if ! command -v linkerd &> /dev/null; then
        print_warning "Linkerd CLI not found. Installing..."
        
        # Install Linkerd CLI
        curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
        export PATH=$PATH:$HOME/.linkerd2/bin
        
        if ! command -v linkerd &> /dev/null; then
            print_error "Failed to install Linkerd CLI"
            return 1
        fi
    fi
    
    # Check if Linkerd is already installed
    if kubectl get namespace linkerd &> /dev/null; then
        print_warning "Linkerd is already installed"
        return 0
    fi
    
    # Install Linkerd control plane
    print_status "Installing Linkerd control plane..."
    if linkerd install --crds | kubectl apply -f -; then
        print_success "Linkerd CRDs installed"
    else
        print_error "Failed to install Linkerd CRDs"
        return 1
    fi
    
    if linkerd install | kubectl apply -f -; then
        print_success "Linkerd control plane installed"
    else
        print_error "Failed to install Linkerd control plane"
        return 1
    fi
    
    # Wait for Linkerd to be ready
    print_status "Waiting for Linkerd to be ready..."
    linkerd check --wait=300s
    
    print_success "Linkerd is ready"
}

# Function to configure model services for Linkerd
configure_model_services() {
    print_status "Configuring model services for Linkerd..."
    
    # Apply service mesh configuration
    if kubectl apply -f linkerd/model-service-mesh.yaml; then
        print_success "Model service mesh configuration applied"
    else
        print_warning "Failed to apply service mesh configuration (Linkerd may not be installed)"
    fi
}

# Function to setup ingress for models
setup_model_ingress() {
    print_status "Setting up ingress for model services..."
    
    # Apply ingress configuration
    if kubectl apply -f ingress/model-ingress.yaml; then
        print_success "Model ingress configuration applied"
    else
        print_error "Failed to apply model ingress configuration"
        return 1
    fi
}

# Function to verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    # Check NGINX Ingress Controller
    if kubectl get pods -n ingress-nginx | grep -q "Running"; then
        print_success "NGINX Ingress Controller is running"
    else
        print_warning "NGINX Ingress Controller is not running"
    fi
    
    # Check Linkerd (if installed)
    if kubectl get namespace linkerd &> /dev/null; then
        if kubectl get pods -n linkerd | grep -q "Running"; then
            print_success "Linkerd is running"
        else
            print_warning "Linkerd is not running"
        fi
    else
        print_warning "Linkerd is not installed"
    fi
    
    # Check ingress resources
    if kubectl get ingress --all-namespaces | grep -q "model-ingress"; then
        print_success "Model ingress resources are created"
    else
        print_warning "Model ingress resources are not found"
    fi
}

# Function to show access information
show_access_info() {
    print_status "Access Information:"
    echo "======================"
    
    # Get ingress controller service
    INGRESS_IP=$(kubectl get service -n ingress-nginx ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
    INGRESS_PORT=$(kubectl get service -n ingress-nginx ingress-nginx -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "80")
    
    if [ "$INGRESS_IP" = "Pending" ] || [ -z "$INGRESS_IP" ]; then
        print_warning "Ingress controller is using NodePort or LoadBalancer is pending"
        NODEPORT=$(kubectl get service -n ingress-nginx ingress-nginx -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
        echo "NodePort: $NODEPORT"
    else
        echo "Ingress IP: $INGRESS_IP"
        echo "Ingress Port: $INGRESS_PORT"
    fi
    
    echo ""
    echo "Model Access URLs (add to /etc/hosts for local testing):"
    echo "  http://models.local/models/<model-name>"
    echo "  http://api.models.local/v1/models/<model-name>"
    echo "  http://mlflow.local"
    echo ""
    echo "Example /etc/hosts entry:"
    echo "  $INGRESS_IP models.local api.models.local mlflow.local"
    echo ""
    
    if kubectl get namespace linkerd &> /dev/null; then
        echo "Linkerd Dashboard:"
        echo "  linkerd dashboard"
        echo ""
    fi
}

# Main execution
main() {
    echo "Starting setup process..."
    echo ""
    
    # Parse command line arguments
    INSTALL_INGRESS=true
    INSTALL_LINKERD=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --ingress-only)
                INSTALL_INGRESS=true
                INSTALL_LINKERD=false
                shift
                ;;
            --linkerd-only)
                INSTALL_INGRESS=false
                INSTALL_LINKERD=true
                shift
                ;;
            --both)
                INSTALL_INGRESS=true
                INSTALL_LINKERD=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --ingress-only    Install only NGINX Ingress Controller"
                echo "  --linkerd-only    Install only Linkerd Service Mesh"
                echo "  --both           Install both Ingress and Linkerd (default)"
                echo "  --help           Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Install components based on options
    if [ "$INSTALL_INGRESS" = true ]; then
        install_nginx_ingress
        setup_model_ingress
    fi
    
    if [ "$INSTALL_LINKERD" = true ]; then
        install_linkerd
        configure_model_services
    fi
    
    # Verify installation
    verify_installation
    
    # Show access information
    show_access_info
    
    print_success "Setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Deploy your model using the Argo Workflows pipeline"
    echo "2. Access your models through the ingress URLs"
    echo "3. Monitor traffic using Linkerd dashboard (if installed)"
}

# Run main function
main "$@"
