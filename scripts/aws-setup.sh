#!/bin/bash
# ============================================
# AWS Infrastructure Setup Script (using AWS CLI)
# This creates the minimum AWS resources needed
# Usage: ./scripts/aws-setup.sh
# Prerequisites: aws cli configured with admin access
# ============================================

set -e

REGION=${AWS_REGION:-us-east-1}
PROJECT="sanos-y-salvos"
KEY_NAME="${PROJECT}-key"
SG_NAME="${PROJECT}-sg"
INSTANCE_TYPE="t3.large"
AMI_ID="" # Will be auto-detected

echo "=========================================="
echo "  AWS Infrastructure Setup"
echo "  Region: $REGION"
echo "=========================================="

# 1. Get latest Amazon Linux 2023 AMI
echo "[1/6] Finding latest AMI..."
AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text \
    --region $REGION)
echo "  AMI: $AMI_ID"

# 2. Create Key Pair
echo "[2/6] Creating key pair..."
if ! aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION 2>/dev/null; then
    aws ec2 create-key-pair \
        --key-name $KEY_NAME \
        --query 'KeyMaterial' \
        --output text \
        --region $REGION > ${KEY_NAME}.pem
    chmod 400 ${KEY_NAME}.pem
    echo "  Key saved: ${KEY_NAME}.pem"
else
    echo "  Key pair already exists"
fi

# 3. Create Security Group
echo "[3/6] Creating security group..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text --region $REGION)

SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SG_NAME" --query 'SecurityGroups[0].GroupId' --output text --region $REGION 2>/dev/null || echo "None")

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
    SG_ID=$(aws ec2 create-security-group \
        --group-name $SG_NAME \
        --description "Sanos y Salvos Security Group" \
        --vpc-id $VPC_ID \
        --query 'GroupId' \
        --output text \
        --region $REGION)
    
    # SSH (restrict to your IP in production)
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION
    # HTTP
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION
    # HTTPS
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 --region $REGION
    # Frontend (dev)
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 3000 --cidr 0.0.0.0/0 --region $REGION
    # MinIO public (for pet photos)
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 9000 --cidr 0.0.0.0/0 --region $REGION
    
    echo "  Security Group: $SG_ID"
else
    echo "  Security Group already exists: $SG_ID"
fi

# 4. Launch EC2 Instance
echo "[4/6] Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":30,"VolumeType":"gp3"}}]' \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT}}]" \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region $REGION)
echo "  Instance: $INSTANCE_ID"

echo "  Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

# 5. Allocate Elastic IP
echo "[5/6] Allocating Elastic IP..."
ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text --region $REGION)
aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ALLOC_ID --region $REGION
PUBLIC_IP=$(aws ec2 describe-addresses --allocation-ids $ALLOC_ID --query 'Addresses[0].PublicIp' --output text --region $REGION)
echo "  Elastic IP: $PUBLIC_IP"

# 6. Create ECR Repositories
echo "[6/6] Creating ECR repositories..."
SERVICES=("auth-service" "ms-mascotas" "ms-geolocalizacion" "ms-coincidencias" "bff-service" "frontend")
for SVC in "${SERVICES[@]}"; do
    aws ecr describe-repositories --repository-names "${PROJECT}/${SVC}" --region $REGION 2>/dev/null || \
    aws ecr create-repository \
        --repository-name "${PROJECT}/${SVC}" \
        --image-scanning-configuration scanOnPush=true \
        --region $REGION > /dev/null
    echo "  ✓ ECR: ${PROJECT}/${SVC}"
done

echo ""
echo "=========================================="
echo "  Infrastructure Created!"
echo "=========================================="
echo ""
echo "Instance ID:  $INSTANCE_ID"
echo "Public IP:    $PUBLIC_IP"
echo "Key File:     ${KEY_NAME}.pem"
echo ""
echo "Connect: ssh -i ${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
echo ""
echo "Next steps:"
echo "  1. ssh -i ${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
echo "  2. sudo ./scripts/setup-ec2.sh"
echo "  3. git clone <your-repo> /home/ec2-user/sanos-y-salvos"
echo "  4. cp .env.production .env && edit .env"
echo "  5. ./scripts/deploy.sh build"
echo ""
