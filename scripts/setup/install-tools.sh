#!/bin/bash
# Install Development Tools
# Installs all required tools for development

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_info "Installing development tools..."

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
else
    log_warning "Unsupported OS: $OSTYPE"
    exit 1
fi

# Install Homebrew (macOS)
if [ "$OS" == "macos" ]; then
    if ! command -v brew &> /dev/null; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        log_success "Homebrew installed"
    else
        log_success "Homebrew already installed"
    fi
fi

# Install Terraform
if ! command -v terraform &> /dev/null; then
    log_info "Installing Terraform..."
    if [ "$OS" == "macos" ]; then
        brew tap hashicorp/tap
        brew install hashicorp/tap/terraform
    else
        wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt update && sudo apt install terraform
    fi
    log_success "Terraform installed"
else
    log_success "Terraform already installed ($(terraform version | head -n1))"
fi

# Install Ansible
if ! command -v ansible &> /dev/null; then
    log_info "Installing Ansible..."
    if [ "$OS" == "macos" ]; then
        brew install ansible
    else
        sudo apt update && sudo apt install -y ansible
    fi
    log_success "Ansible installed"
else
    log_success "Ansible already installed ($(ansible --version | head -n1))"
fi

# Install ansible-lint
if ! command -v ansible-lint &> /dev/null; then
    log_info "Installing ansible-lint..."
    pip install ansible-lint
    log_success "ansible-lint installed"
else
    log_success "ansible-lint already installed"
fi

# Install AWS CLI
if ! command -v aws &> /dev/null; then
    log_info "Installing AWS CLI..."
    if [ "$OS" == "macos" ]; then
        brew install awscli
    else
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip awscliv2.zip
        sudo ./aws/install
        rm -rf aws awscliv2.zip
    fi
    log_success "AWS CLI installed"
else
    log_success "AWS CLI already installed ($(aws --version))"
fi

# Install jq
if ! command -v jq &> /dev/null; then
    log_info "Installing jq..."
    if [ "$OS" == "macos" ]; then
        brew install jq
    else
        sudo apt install -y jq
    fi
    log_success "jq installed"
else
    log_success "jq already installed"
fi

# Install pre-commit
if ! command -v pre-commit &> /dev/null; then
    log_info "Installing pre-commit..."
    pip install pre-commit
    log_success "pre-commit installed"
else
    log_success "pre-commit already installed"
fi

# Install tfsec
if ! command -v tfsec &> /dev/null; then
    log_info "Installing tfsec..."
    if [ "$OS" == "macos" ]; then
        brew install tfsec
    else
        curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
    fi
    log_success "tfsec installed"
else
    log_success "tfsec already installed"
fi

# Install checkov
if ! command -v checkov &> /dev/null; then
    log_info "Installing checkov..."
    pip install checkov
    log_success "checkov installed"
else
    log_success "checkov already installed"
fi

# Install detect-secrets
if ! command -v detect-secrets &> /dev/null; then
    log_info "Installing detect-secrets..."
    pip install detect-secrets
    log_success "detect-secrets installed"
else
    log_success "detect-secrets already installed"
fi

# Install yamllint
if ! command -v yamllint &> /dev/null; then
    log_info "Installing yamllint..."
    pip install yamllint
    log_success "yamllint installed"
else
    log_success "yamllint already installed"
fi

# Install shellcheck
if ! command -v shellcheck &> /dev/null; then
    log_info "Installing shellcheck..."
    if [ "$OS" == "macos" ]; then
        brew install shellcheck
    else
        sudo apt install -y shellcheck
    fi
    log_success "shellcheck installed"
else
    log_success "shellcheck already installed"
fi

# Install terraform-docs (optional)
if ! command -v terraform-docs &> /dev/null; then
    log_info "Installing terraform-docs..."
    if [ "$OS" == "macos" ]; then
        brew install terraform-docs
    else
        curl -sSLo ./terraform-docs.tar.gz https://terraform-docs.io/dl/v0.16.0/terraform-docs-v0.16.0-$(uname)-amd64.tar.gz
        tar -xzf terraform-docs.tar.gz
        sudo mv terraform-docs /usr/local/bin/
        rm terraform-docs.tar.gz
    fi
    log_success "terraform-docs installed"
else
    log_success "terraform-docs already installed"
fi

# Install infracost (optional)
if ! command -v infracost &> /dev/null; then
    log_info "Installing infracost..."
    if [ "$OS" == "macos" ]; then
        brew install infracost
    else
        curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh
    fi
    log_success "infracost installed"
    log_info "Run 'infracost auth login' to configure"
else
    log_success "infracost already installed"
fi

echo ""
log_success "All tools installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Configure AWS credentials: aws configure"
echo "  2. Install pre-commit hooks: make pre-commit-install"
echo "  3. Initialize Terraform: make tf-init"
echo ""
