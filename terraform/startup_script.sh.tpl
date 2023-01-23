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
apt install -y make docker.io golang jq
# allow user to execute docker without sudo
gpasswd -a ${user} docker

touch $startup_script_done_file
