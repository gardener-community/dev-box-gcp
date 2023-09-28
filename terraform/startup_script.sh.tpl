#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

cd /home/${user}
startup_script_done_file=.startup_script_done

cat >>.bashrc <<EOF

export PATH="/home/${user}/go/src/github.com/gardener/gardener/hack/tools/bin:\$PATH"
alias k=kubectl
EOF

cat >>start-gardener-dev.sh <<EOF
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

sudo -u ${user} mkdir -p go/src/github.com/gardener/gardener
apt update
apt install -y make docker.io jq
# allow user to execute docker without sudo
gpasswd -a ${user} docker

# Install a recent version of go from https://go.dev/dl/ that is used in gardener projects.
# The golang package from the distribution lags behind significantly.
go_download_url='https://dl.google.com/go/go1.21.1.linux-amd64.tar.gz'
go_download_sha256='b3075ae1ce5dab85f89bc7905d1632de23ca196bd8336afd93fa97434cfa55ae'
go_download_file=/tmp/go.tgz
wget -O $go_download_file "$go_download_url" --progress=dot:giga
echo "$go_download_sha256 $go_download_file" | sha256sum -c -
tar -C /usr/local -xzf $go_download_file
ln -s /usr/local/go/bin/go /usr/local/bin/go
rm $go_download_file

# Install a recent version of delve
(
  # HOME doesn't seem to be set in startup-script, populate it manually
  export HOME=/root;
  GOBIN=/usr/local/bin go install github.com/go-delve/delve/cmd/dlv@latest;
)

# Make dev box ready for IPv6 development
# see https://github.com/gardener/gardener/blob/master/docs/deployment/getting_started_locally.md#setting-up-ipv6-single-stack-networking-optional
echo "::1 localhost" | tee -a /etc/hosts
ip6tables -t nat -A POSTROUTING -o "$(ip route show default | awk '{print $5}')" -s fd00:10::/64 -j MASQUERADE

touch $startup_script_done_file
