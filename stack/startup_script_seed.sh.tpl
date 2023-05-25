#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

cd /home/${user}
startup_script_done_file=.startup_script_done

cat >>.bashrc <<EOF

export PATH="/home/${user}/go/src/github.com/gardener/gardener/hack/tools/bin:\$PATH"
alias k=kubectl
alias g=git
EOF

cat >start-gardener-dev.sh <<EOF
#!/usr/bin/env bash
# guide the user when logging in
if ! [ -e $startup_script_done_file ] ; then
  until [ -e $startup_script_done_file ] ; do
    echo "Required development tools are being installed and configured. Waiting 5 more seconds..."
    sleep 5
  done
  echo "Please reconnect your SSH session to reload group membership (required for docker commands)"
  exit
fi
echo "All required development tools are installed and configured. Bringing you to the gardener/gardener directory."
cd ~/go/src/github.com/gardener/gardener
exec \$SHELL
EOF
chmod +x start-gardener-dev.sh

cat >create-k8s-dev.sh <<EOF
#!/usr/bin/env bash

INT=$(ip route show default | awk '{print $5}')
LOCAL_IPV6=$(ip a s $INT | awk '$1 == "inet6" {print $2}' |grep -v fe80 |cut -d"/" -f1)
LOCAL_IPV4=$(ip a s $INT | awk '$1 == "inet" {print $2}'|cut -d"/" -f1)
EXTERNAL_IPV4=$(curl -H "Metadata-Flavor:Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)

echo "nameserver 2001:4860:4860::8844" |sudo tee /var/lib/kubelet/resolv.conf
echo "KUBELET_EXTRA_ARGS=\"--node-ip=$LOCAL_IPV6\" --resolv-conf=/var/lib/kubelet/resolv.conf" |sudo tee /etc/default/kubelet
sudo systemctl restart kubelet

sudo kubeadm init \
    --apiserver-advertise-address "$LOCAL_IPV6" \
    --apiserver-cert-extra-sans "$LOCAL_IPV6,$EXTERNAL_IPV4" \
    --kubernetes-version "1.25.2" \
    --pod-network-cidr "fd00:10:1::/56" \
    --service-cidr "fd00:10:2::/112" \

# Copy kubeconfig
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Remove master taint
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-
# Apply local path provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml

kubectl annotate sc local-path storageclass.kubernetes.io/is-default-class="true"
EOF

sudo -u ${user} mkdir -p go/src/github.com/gardener/gardener
apt update
apt install -y make docker.io jq socat conntrack apache2-utils
# allow user to execute docker without sudo
gpasswd -a ${user} docker

### Seed requirements
## Fix 'too many open files' error
cat >/etc/security/limits.conf <<EOF
# /etc/security/limits.conf
#
*         hard    nofile       1048576
*         soft    nofile       1048576
root      hard    nofile       1048576
root      soft    nofile       1048576
# End of file
EOF

cat >/etc/sysctl.d/80-seed.conf <<EOF
fs.inotify.max_user_instances=250383
EOF
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.ipv6.conf.all.forwarding        = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl -q --system

### Configure Containerd
## Containerd default config

mkdir -p /etc/containerd
cat >/etc/containerd/config.toml <<EOF
version = 2
root = "/var/lib/containerd"
state = "/run/containerd"

[grpc]
address = "/run/containerd/containerd.sock"

[plugins."io.containerd.grpc.v1.cri".containerd]
default_runtime_name = "runc"

[plugins."io.containerd.grpc.v1.cri"]
sandbox_image = "registry.k8s.io/pause:3.6"

[plugins."io.containerd.grpc.v1.cri".registry]
[plugins."io.containerd.grpc.v1.cri".registry.configs]

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
SystemdCgroup = true

[plugins."io.containerd.grpc.v1.cri".cni]
bin_dir = "/opt/cni/bin"
conf_dir = "/etc/cni/net.d"
EOF
systemctl restart containerd

### Install kubernetes binaries
CNI_PLUGINS_VERSION="v1.3.0"
DEST="/opt/cni/bin"
DOWNLOAD_DIR="/usr/local/bin"
CRICTL_VERSION="v1.25.0"
RELEASE="v1.25.2"
RELEASE_VERSION="v0.15.1"
ARCH="amd64"

mkdir -p "$DEST"
mkdir -p "$DOWNLOAD_DIR"
curl -L "https://github.com/containernetworking/plugins/releases/download/$CNI_PLUGINS_VERSION/cni-plugins-linux-$ARCH-$CNI_PLUGINS_VERSION.tgz" | tar -C "$DEST" -xz
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/$CRICTL_VERSION/crictl-$CRICTL_VERSION-linux-$ARCH.tar.gz" | tar -C $DOWNLOAD_DIR -xz
curl -L --output-dir $DOWNLOAD_DIR --remote-name-all https://dl.k8s.io/release/$RELEASE/bin/linux/$ARCH/{kubeadm,kubelet,kubectl}
chmod +x "$DOWNLOAD_DIR"/{kubeadm,kubelet,kubectl}
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/$RELEASE_VERSION/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" | sed "s:/usr/bin:$DOWNLOAD_DIR:g" | tee /etc/systemd/system/kubelet.service
mkdir -p /etc/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/$RELEASE_VERSION/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:$DOWNLOAD_DIR:g" | tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
systemctl enable --now kubelet.service

# Install a recent version of go from https://go.dev/dl/ that is used in gardener projects.
# The golang package from the distribution lags behind significantly.
go_download_url='https://dl.google.com/go/go1.20.2.linux-amd64.tar.gz'
go_download_sha256='4eaea32f59cde4dc635fbc42161031d13e1c780b87097f4b4234cfce671f1768'
go_download_file=/tmp/go.tgz
wget -O $go_download_file "$go_download_url" --progress=dot:giga
echo "$go_download_sha256 $go_download_file" | sha256sum -c -
tar -C /usr/local -xzf $go_download_file
ln -s /usr/local/go/bin/go /usr/local/bin/go
rm $go_download_file

touch $startup_script_done_file
