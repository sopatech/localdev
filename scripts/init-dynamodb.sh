#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Configuration
LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:8000}"
AWS_REGION="${AWS_REGION:-us-east-1}"
TABLE_NAME="${TABLE_NAME:-raidhelper}"

# Function to check if LocalStack is ready
wait_for_localstack() {
    log_info "Waiting for LocalStack to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        # Test DynamoDB directly by trying to list tables
        if AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 \
           aws dynamodb list-tables --endpoint-url "$LOCALSTACK_ENDPOINT" >/dev/null 2>&1; then
            log_success "LocalStack DynamoDB service is ready!"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts: LocalStack not ready yet..."
        sleep 5
        ((attempt++))
    done
    
    log_error "LocalStack failed to become ready after $max_attempts attempts"
    return 1
}

# Function to check if table exists
table_exists() {
    aws dynamodb describe-table \
        --table-name "$TABLE_NAME" \
        --endpoint-url "$LOCALSTACK_ENDPOINT" \
        --region "$AWS_REGION" \
        >/dev/null 2>&1
}

# Function to create DynamoDB table
create_table() {
    log_info "Creating DynamoDB table: $TABLE_NAME"
    
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions \
            AttributeName=PK,AttributeType=S \
            AttributeName=SK,AttributeType=S \
            AttributeName=LSI1SK,AttributeType=S \
            AttributeName=LSI2SK,AttributeType=S \
            AttributeName=LSI3SK,AttributeType=S \
            AttributeName=LSI4SK,AttributeType=S \
            AttributeName=LSI5SK,AttributeType=S \
        --key-schema \
            AttributeName=PK,KeyType=HASH \
            AttributeName=SK,KeyType=RANGE \
        --endpoint-url "$LOCALSTACK_ENDPOINT" \
        --region "$AWS_REGION" \
        --provisioned-throughput ReadCapacityUnits=10,WriteCapacityUnits=10 \
        --local-secondary-indexes \
            '[{"IndexName": "LSI1","KeySchema":[{"AttributeName":"PK","KeyType":"HASH"},{"AttributeName":"LSI1SK","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}},{"IndexName": "LSI2","KeySchema":[{"AttributeName":"PK","KeyType":"HASH"},{"AttributeName":"LSI2SK","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}},{"IndexName": "LSI3","KeySchema":[{"AttributeName":"PK","KeyType":"HASH"},{"AttributeName":"LSI3SK","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}},{"IndexName": "LSI4","KeySchema":[{"AttributeName":"PK","KeyType":"HASH"},{"AttributeName":"LSI4SK","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}},{"IndexName": "LSI5","KeySchema":[{"AttributeName":"PK","KeyType":"HASH"},{"AttributeName":"LSI5SK","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]'
    
    log_success "DynamoDB table '$TABLE_NAME' created successfully!"
}

# Main function
main() {
    echo -e "${BLUE}🗄️  DynamoDB Table Initialization${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    # Set AWS credentials for LocalStack
    export AWS_ACCESS_KEY_ID=test
    export AWS_SECRET_ACCESS_KEY=test
    export AWS_DEFAULT_REGION="$AWS_REGION"
    
    # Wait for LocalStack to be ready
    wait_for_localstack
    
    # Check if table already exists
    if table_exists; then
        log_warn "Table '$TABLE_NAME' already exists, skipping creation"
    else
        create_table
    fi
    
    # Wait for table to be active
    log_info "Waiting for table to become active..."
    aws dynamodb wait table-exists \
        --table-name "$TABLE_NAME" \
        --endpoint-url "$LOCALSTACK_ENDPOINT" \
        --region "$AWS_REGION" \
        >/dev/null 2>&1
    
    log_success "DynamoDB table '$TABLE_NAME' is ready for use!"
    
    # Show table info
    log_info "Table information:"
    aws dynamodb describe-table \
        --table-name "$TABLE_NAME" \
        --endpoint-url "$LOCALSTACK_ENDPOINT" \
        --region "$AWS_REGION" \
        --query 'Table.{TableName:TableName,TableStatus:TableStatus,ItemCount:ItemCount}' \
        --output table
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  LOCALSTACK_ENDPOINT  LocalStack endpoint (default: http://localhost:8000)"
        echo "  AWS_REGION          AWS region (default: us-east-1)"
        echo "  TABLE_NAME          Table name (default: raidhelper)"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Use defaults"
        echo "  LOCALSTACK_ENDPOINT=http://localhost:8000 $0"
        ;;
    *)
        main "$@"
        ;;
esac
