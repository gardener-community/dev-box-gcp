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
go_download_url='https://dl.google.com/go/go1.20.2.linux-amd64.tar.gz'
go_download_sha256='4eaea32f59cde4dc635fbc42161031d13e1c780b87097f4b4234cfce671f1768'
go_download_file=/tmp/go.tgz
wget -O $go_download_file "$go_download_url" --progress=dot:giga
echo "$go_download_sha256 $go_download_file" | sha256sum -c -
tar -C /usr/local -xzf $go_download_file
ln -s /usr/local/go/bin/go /usr/local/bin/go
rm $go_download_file

touch $startup_script_done_file
