cat k8s-prepare-node.sh
#!/bin/bash

# This script prepares Ubuntu 22.04 nodes for Kubernetes deployment with kubeadm
# and containerd as the container runtime.

set -e

# Variables
SWAP_FILE="/swap.img"
CONTAINERD_VERSION="1.7.23"
KUBE_ADMIN_USER="kube-admin"
KUBE_ADMIN_PASSWORD="admin123"  # Change this to a secure password

# Define hosts entries as an array
HOSTS_ENTRIES=(
    "192.168.56.10 k8s-ctrl01"
    "192.168.56.11 k8s-wkr01"
    "192.168.56.12 k8s-wkr02"
)

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Check OS version
if ! lsb_release -d | grep -q "Ubuntu 22.04"; then
    echo "This script is designed for Ubuntu 22.04"
    exit 1
fi

echo "Starting Kubernetes node preparation..."

# 0. Create kube-admin user with sudo privileges
echo "Creating kube-admin user..."
if ! id "$KUBE_ADMIN_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$KUBE_ADMIN_USER"
    echo "$KUBE_ADMIN_USER:$KUBE_ADMIN_PASSWORD" | chpasswd
    echo "$KUBE_ADMIN_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/kube-admin
    chmod 0440 /etc/sudoers.d/kube-admin
    echo "User $KUBE_ADMIN_USER created with sudo privileges"
else
    echo "User $KUBE_ADMIN_USER already exists"
fi

# 0.1 Configure /etc/hosts
echo "Configuring /etc/hosts..."
# Backup existing hosts file
cp /etc/hosts /etc/hosts.bak
# Start with default localhost entries
cat <<EOF > /etc/hosts
127.0.0.1 localhost
127.0.1.1 $(hostname)

# The following lines are added by k8s-prepare-node.sh
EOF

# Add custom hosts entries
for entry in "${HOSTS_ENTRIES[@]}"; do
    echo "$entry" >> /etc/hosts
done

# 1. Disable swap
echo "Disabling swap..."
swapoff -a
sed -i '/[[:space:]]swap[[:space:]]/ s/^\(.*\)$/#\1/' /etc/fstab
if [ -f "$SWAP_FILE" ]; then
    rm -f "$SWAP_FILE"
fi

# 2. Load required kernel modules
echo "Loading kernel modules..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# 3. Set sysctl parameters
echo "Configuring sysctl parameters..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# 4. Install containerd
echo "Installing containerd..."
apt-get update
apt-get install -y curl gnupg lsb-release

# Install containerd
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y containerd.io=${CONTAINERD_VERSION}-1

# Configure containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# Enable SystemdCgroup
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sed -i 's|sandbox_image = "registry.k8s.io/pause:3.8"|sandbox_image = "registry.k8s.io/pause:3.9"|' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

# 5. Install Kubernetes tools
echo "Installing Kubernetes tools..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# 6. Enable kubelet
echo "Enabling kubelet..."
systemctl enable kubelet

# 7. Install additional utilities
echo "Installing additional utilities..."
apt-get install -y bash-completion
echo 'source <(kubectl completion bash)' >> /root/.bashrc
echo 'source <(kubectl completion bash)' >> /home/$KUBE_ADMIN_USER/.bashrc
chown $KUBE_ADMIN_USER:$KUBE_ADMIN_USER /home/$KUBE_ADMIN_USER/.bashrc

# 8. Clean up
echo "Cleaning up..."
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "Node preparation completed successfully!"
echo "Next steps:"
echo "- For control plane nodes, initialize the cluster with kubeadm init"
echo "- For worker nodes, join the cluster with kubeadm join"
echo "- Log in as $KUBE_ADMIN_USER (password: $KUBE_ADMIN_PASSWORD) for cluster management"
