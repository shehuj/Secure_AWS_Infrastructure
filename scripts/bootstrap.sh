#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_dependencies() {
    print_info "Checking dependencies..."
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_warn "jq is not installed. Proceeding without it (some output may be less formatted)."
    fi
    
    print_info "Dependencies check passed."
}

# Get AWS account information
get_aws_info() {
    print_info "Getting AWS account information..."
    
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    if [ $? -ne 0 ]; then
        print_error "Failed to get AWS account ID. Please ensure AWS credentials are configured."
        exit 1
    fi
    
    AWS_REGION=${AWS_DEFAULT_REGION:-us-east-1}
    
    print_info "AWS Account ID: $AWS_ACCOUNT_ID"
    print_info "AWS Region: $AWS_REGION"
}

# Parse command line arguments
parse_args() {
    BUCKET_NAME=""
    DYNAMODB_TABLE="terraform-locks"
    ENVIRONMENT="prod"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--bucket)
                BUCKET_NAME="$2"
                shift 2
                ;;
            -t|--table)
                DYNAMODB_TABLE="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -r|--region)
                AWS_REGION="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Bootstrap Terraform backend (S3 + DynamoDB)"
                echo ""
                echo "Options:"
                echo "  -b, --bucket NAME        S3 bucket name (required)"
                echo "  -t, --table NAME         DynamoDB table name (default: terraform-locks)"
                echo "  -e, --environment ENV    Environment name (default: prod)"
                echo "  -r, --region REGION      AWS region (default: us-east-1)"
                echo "  -h, --help               Show this help message"
                echo ""
                echo "Example:"
                echo "  $0 -b my-terraform-state-bucket -e prod -r us-east-1"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
    
    if [ -z "$BUCKET_NAME" ]; then
        print_error "Bucket name is required. Use -b or --bucket to specify."
        echo "Use -h or --help for usage information"
        exit 1
    fi
}

# Create S3 bucket for Terraform state
create_s3_bucket() {
    print_info "Creating S3 bucket: $BUCKET_NAME"
    
    # Check if bucket already exists
    if aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
        print_warn "S3 bucket $BUCKET_NAME already exists. Skipping creation."
    else
        # Create bucket
        if [ "$AWS_REGION" = "us-east-1" ]; then
            aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION"
        else
            aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" \
                --create-bucket-configuration LocationConstraint="$AWS_REGION"
        fi
        print_info "S3 bucket created successfully."
    fi
    
    # Enable versioning
    print_info "Enabling versioning on S3 bucket..."
    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    # Enable server-side encryption
    print_info "Enabling server-side encryption..."
    aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }]
        }'
    
    # Block public access
    print_info "Blocking public access..."
    aws s3api put-public-access-block --bucket "$BUCKET_NAME" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    # Add bucket policy
    print_info "Adding bucket policy..."
    aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [
            {
                \"Sid\": \"DenyUnencryptedObjectUploads\",
                \"Effect\": \"Deny\",
                \"Principal\": \"*\",
                \"Action\": \"s3:PutObject\",
                \"Resource\": \"arn:aws:s3:::$BUCKET_NAME/*\",
                \"Condition\": {
                    \"StringNotEquals\": {
                        \"s3:x-amz-server-side-encryption\": \"AES256\"
                    }
                }
            },
            {
                \"Sid\": \"DenyInsecureTransport\",
                \"Effect\": \"Deny\",
                \"Principal\": \"*\",
                \"Action\": \"s3:*\",
                \"Resource\": [
                    \"arn:aws:s3:::$BUCKET_NAME\",
                    \"arn:aws:s3:::$BUCKET_NAME/*\"
                ],
                \"Condition\": {
                    \"Bool\": {
                        \"aws:SecureTransport\": \"false\"
                    }
                }
            }
        ]
    }"
    
    # Add lifecycle policy
    print_info "Adding lifecycle policy for old versions..."
    aws s3api put-bucket-lifecycle-configuration --bucket "$BUCKET_NAME" \
        --lifecycle-configuration '{
            "Rules": [{
                "Id": "DeleteOldVersions",
                "Status": "Enabled",
                "NoncurrentVersionExpiration": {
                    "NoncurrentDays": 90
                }
            }]
        }'
    
    print_info "S3 bucket configuration completed."
}

# Create DynamoDB table for state locking
create_dynamodb_table() {
    print_info "Creating DynamoDB table: $DYNAMODB_TABLE"
    
    # Check if table already exists
    if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" 2>/dev/null; then
        print_warn "DynamoDB table $DYNAMODB_TABLE already exists. Skipping creation."
    else
        # Create table
        aws dynamodb create-table \
            --table-name "$DYNAMODB_TABLE" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST \
            --region "$AWS_REGION" \
            --tags Key=Name,Value="$DYNAMODB_TABLE" Key=Environment,Value="$ENVIRONMENT" Key=ManagedBy,Value=Terraform
        
        print_info "Waiting for DynamoDB table to be created..."
        aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"
        print_info "DynamoDB table created successfully."
    fi
    
    # Enable point-in-time recovery
    print_info "Enabling point-in-time recovery..."
    aws dynamodb update-continuous-backups \
        --table-name "$DYNAMODB_TABLE" \
        --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
        --region "$AWS_REGION"
    
    print_info "DynamoDB table configuration completed."
}

# Generate backend configuration
generate_backend_config() {
    print_info "Generating backend configuration..."
    
    cat > terraform/backend-config.hcl << BACKEND_CONFIG
bucket         = "$BUCKET_NAME"
key            = "$ENVIRONMENT/terraform.tfstate"
region         = "$AWS_REGION"
dynamodb_table = "$DYNAMODB_TABLE"
encrypt        = true
BACKEND_CONFIG
    
    print_info "Backend configuration saved to: terraform/backend-config.hcl"
    print_info ""
    print_info "To initialize Terraform with this backend, run:"
    print_info "  cd terraform"
    print_info "  terraform init -backend-config=backend-config.hcl"
}

# Main function
main() {
    echo "========================================="
    echo "  Terraform Backend Bootstrap Script"
    echo "========================================="
    echo ""
    
    parse_args "$@"
    check_dependencies
    get_aws_info
    
    echo ""
    echo "Configuration:"
    echo "  Bucket Name:     $BUCKET_NAME"
    echo "  DynamoDB Table:  $DYNAMODB_TABLE"
    echo "  Environment:     $ENVIRONMENT"
    echo "  Region:          $AWS_REGION"
    echo ""
    
    read -p "Do you want to proceed? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warn "Bootstrap cancelled."
        exit 0
    fi
    
    echo ""
    create_s3_bucket
    echo ""
    create_dynamodb_table
    echo ""
    generate_backend_config
    
    echo ""
    print_info "========================================="
    print_info "  Bootstrap completed successfully!"
    print_info "========================================="
    echo ""
    print_info "Next steps:"
    print_info "1. Update terraform/backend.tf with your bucket name:"
    print_info "   bucket = \"$BUCKET_NAME\""
    print_info ""
    print_info "2. Initialize Terraform:"
    print_info "   cd terraform && terraform init -backend-config=backend-config.hcl"
    print_info ""
    print_info "3. Update GitHub Secrets with:"
    print_info "   AWS_ROLE_ARN (from OIDC role output)"
}

# Run main function
main "$@"
