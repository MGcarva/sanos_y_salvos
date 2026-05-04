#!/bin/bash
# ============================================
# EC2 Instance Setup Script
# Run this ONCE on a fresh Amazon Linux 2023 / Ubuntu EC2
# Usage: chmod +x setup-ec2.sh && sudo ./setup-ec2.sh
# ============================================

set -e

echo "=========================================="
echo "  Sanos y Salvos - EC2 Setup"
echo "=========================================="

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
fi

echo "[1/6] Updating system packages..."
if [ "$OS" = "amzn" ] || [ "$OS" = "rhel" ]; then
    yum update -y
elif [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    apt-get update -y && apt-get upgrade -y
fi

echo "[2/6] Installing Docker..."
if [ "$OS" = "amzn" ]; then
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user
elif [ "$OS" = "ubuntu" ]; then
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    usermod -aG docker ubuntu
fi

echo "[3/6] Installing Docker Compose..."
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "[4/6] Installing AWS CLI..."
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
fi

echo "[5/6] Installing Git..."
if [ "$OS" = "amzn" ]; then
    yum install -y git
elif [ "$OS" = "ubuntu" ]; then
    apt-get install -y git
fi

echo "[6/6] Creating project directory..."
mkdir -p /home/ec2-user/sanos-y-salvos
chown -R ec2-user:ec2-user /home/ec2-user/sanos-y-salvos 2>/dev/null || \
chown -R ubuntu:ubuntu /home/ec2-user/sanos-y-salvos 2>/dev/null || true

echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Log out and back in (for docker group)"
echo "  2. Configure AWS CLI: aws configure"
echo "  3. Clone your repo to /home/ec2-user/sanos-y-salvos"
echo "  4. Copy .env.production to .env"
echo "  5. Run: ./scripts/deploy.sh"
echo ""
