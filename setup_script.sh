#!/bin/bash

# Update package lists
sudo apt-get update

# Install prerequisites
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    wget

# ------------ Docker Installation ------------
echo "Installing Docker..."

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up stable repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists again
sudo apt-get update

# Install Docker Engine
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Add current user to docker group
sudo usermod -aG docker $USER

# Install Docker Desktop dependencies
sudo apt-get install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils

# Download latest Docker Desktop .deb package
DOCKER_DESKTOP_URL=$(curl -s https://docs.docker.com/desktop/install/ubuntu/ | grep -o 'https://desktop.docker.com/linux/main/amd64/docker-desktop-[0-9.-]*-amd64.deb' | head -n 1)
wget "$DOCKER_DESKTOP_URL" -O docker-desktop.deb

# Install Docker Desktop
sudo apt-get install -y ./docker-desktop.deb

# Clean up Docker Desktop installer
rm docker-desktop.deb

# ------------ Miniconda Installation ------------
echo "Installing Miniconda..."

# Download Miniconda installer
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh

# Make the installer executable
chmod +x miniconda.sh

# Install Miniconda silently (-b flag) and in the user's home directory (-p flag)
./miniconda.sh -b -p $HOME/miniconda

# Clean up Miniconda installer
rm miniconda.sh

# Add Miniconda to PATH
MINICONDA_PATH="$HOME/miniconda/bin"
echo "export PATH=\$PATH:$MINICONDA_PATH" >> $HOME/.bashrc

# Initialize conda for bash
$HOME/miniconda/bin/conda init bash

echo "Installation complete!"
echo "Please log out and log back in for the following changes to take effect:"
echo "1. Docker group membership"
echo "2. Miniconda PATH updates"
echo "After logging back in, you can:"
echo "- Start Docker Desktop from the Applications menu"
echo "- Use conda commands in your terminal"