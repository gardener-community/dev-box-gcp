# Development Box on Google Cloud

This repository contains a few helpers for setting up a development box on Google Cloud using [terraform](https://www.terraform.io/).
It provides a good basis for developing and testing gardener.

## Motivation

Generally, you can develop and test gardener on your local development machine without any paid cloud infrastructure, see [this document](https://github.com/gardener/gardener/blob/master/docs/deployment/getting_started_locally.md) or [this document](https://github.com/gardener/gardener/blob/master/docs/development/getting_started_locally.md).
However, there are certain scenarios in which it is desirable to use a cloud dev box instead.
For example:

- Developing and testing gardener's [IPv6 features](https://github.com/gardener/gardener/blob/master/docs/usage/ipv6.md) might be not be possible locally, if you are not using Linux or don't have IPv6 connectivity.
  - While the Docker daemon natively supports [IPv6 networking](https://docs.docker.com/config/daemon/ipv6/) on Linux machines, there is no support for IPv6 networking on macOS and Windows machines.
    There is no easy way to work around this due to the networking architecture of the Docker VM based on [vpnkit](https://github.com/moby/vpnkit) (no "real" network connectivity, vpnkit intercepts socket calls, etc.).
  - [Rancher Desktop](https://rancherdesktop.io/) provides an open source alternative to Docker Desktop, which uses a different networking architecture for connecting the virtual machine (qemu-integrated networking connection).
    Nevertheless, Rancher Desktop doesn't support IPv6 either, and it is not easy to work around (see https://github.com/rancher-sandbox/rancher-desktop/issues).
  - Using IPv6 single-stack networking in the local gardener setup requires that your machine has an IPv6 connection to the internet.
    This is very rare in office environments and also not offered by all ISPs by default.
- Running an entire gardener installation including multiple seed or shoot clusters on your local machine might require more compute resources than your development machine has (at least `10` CPUs and `16Gi` memory).
  - There is also a ["remote local setup"](https://github.com/gardener/gardener/blob/master/docs/deployment/getting_started_locally.md#remote-local-setup), which starts gardener's local setup inside a pod on a Kubernetes cluster.
    If you already have a development cluster available, this setup might be an interesting alternative to the more opinionated setup in this repository.
    However, as this requires a full Kubernetes cluster, it's more costly and less flexible regarding networking connectivity (no IPv6 support) in comparison to the dev box on Google Cloud.

If you face one of these problems, you can use this repository to set up a Google Cloud machine for development instead of your local machine.
Google Cloud offers simple IPv6 support and machine types that are large enough to host gardener installations.
If you don't have access to a paid Google Cloud project, you can use [free credits](https://cloud.google.com/free) for a new personal account.
Alternatively, you can use another cloud provider that you have access to.
The setup process should be similar on other cloud providers.
However, this repository only contains configuration files for Google Cloud.
Hence, you need to manually create matching configuration files for the cloud provider of your choice.

## Prerequisites

Install the `gcloud` CLI using [this guide](https://cloud.google.com/sdk/docs/install), if you haven't done so yet.
Ensure access to a Google Cloud project and configure `gcloud` accordingly:

```bash
gcloud auth login
gcloud config set project PROJECT_ID
```

## Prepare ServiceAccount Credentials

You need a ServiceAccount with `Compute Admin` and `Compute Network Admin` roles in your Google Cloud project for use with the provided terraform configuration.
If you already have a matching ServiceAccount, place its JSON key in `secrets/gardener-dev.json`. Don't worry, the `secrets` directory is ignored by git.

Alternatively, you can create a new ServiceAccount and key using the following `gcloud` commands:

```bash
PROJECT_ID="$(gcloud config get project)"
SA_NAME="$USER-gardener-dev"

gcloud iam service-accounts create "$SA_NAME" \
  --description="ServiceAccount for Gardener development setup on GCP for $USER"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/compute.admin"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/compute.networkAdmin"

gcloud iam service-accounts keys create secrets/gardener-dev.json \
    --iam-account="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"
```

## Create Cloud Resources

Create your dev box using `make box-up`:

```bash
$ export TF_VAR_project="$(gcloud config get project)"

# Optionally, overwrite any other terraform variable default values (see variables.tf):
# export TF_VAR_*=YOUR_VALUE
# Keep in mind, that the env var name must match the case of the terraform variable name.
# For example, overwrite the SSH key you want to use for logging into your dev box:
# export TF_VAR_ssh_key=~/.ssh/id_ed255.pub

$ make box-up
...
You can now connect to your dev box using:
  ssh -tl you 1.2.3.4 ./start-gardener-dev.sh
```

Once terraform has finished creating your cloud resources, you might need to wait a minute until the startup script has installed all necessary tools and configured your user.
Connect to the dev box using the provided `ssh` command.
You should be able to use the `docker` CLI to work with the machine's Docker daemon.

```bash
$ ssh -tl you 1.2.3.4 ./start-gardener-dev.sh
...
Required development tools are being installed and configured. Waiting 5 more seconds...
...
Please reconnect your SSH session to reload group membership (required for docker commands)

$ ssh -tl you 1.2.3.4 ./start-gardener-dev.sh
...
All required development tools are installed and configured. Bringing you to the gardener/gardener directory.
you@you-gardener-dev:~$ docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

## Stop Development Box

You can stop your cloud dev box at the end of the day for saving cost:

```bash
make box-down
```

Afterwards, you can start your cloud dev box again:

```bash
make box-up
```

## Clean up Cloud Resources

Clean up all cloud resources created for your dev box:

```bash
make box-clean
```

Note: this doesn't clean up the ServiceAccount you created earlier.
Use `gcloud` to delete it manually and its related resources.

## Restrict Incoming Traffic

By default, `make box-up` restricts incoming traffic to the dev box to the outgoing IPv4 address of the local device (determined via [ifconfig.me](https://ifconfig.me)).

If this default behavior doesn't fit your need, you can specify different allowed source ranges during `make box-up`, e.g.:

```bash
make box-up TF_VAR_source_ranges='["1.2.3.4/32","5.6.7.0/24"]'
```

Alternatively, you can disable incoming traffic restrictions entirely:

```bash
make box-up RESTRICT_SOURCE_RANGES=no
```

## Where to Go from Here?

When logging in to your dev box, the `ssh` session should take you straight to the `~/go/src/github.com/gardener/gardener` directory.
Now, it's time to get productive.

### Get the Gardener Sources

Cloning the gardener repository is the easiest way to get started with gardener on your dev box:

```bash
git clone https://github.com/gardener/gardener.git .
```

### Work on/with GCP Box

Besides working directly on the remote box, you could use VSCode or GoLand to run on or sync with it.

#### VS Code

VS Code has a plugin that allows you to work on a remote machine as you would on your local box.
Remote Development using SSH: https://code.visualstudio.com/docs/remote/ssh

#### GoLand

With GoLand there are two options:

- File Synchronization: https://www.jetbrains.com/help/go/configuring-synchronization-with-a-remote-host.html
  - be sure to use rsync instead of plain SFTP as it is a lot faster
- Remote Development: https://www.jetbrains.com/help/go/remote-development-starting-page.html

First one synchronizes your local working directory to the remote host and second starts a GoLand server on remote host.
Both have their advantages and disadvantages, choose what suits you best.

### Start Deploying or Developing Gardener

Congratulations, you are now ready to try or develop gardener on your cloud dev box! 🎉

- If you want to try or test gardener, you can follow [this guide](../deployment/getting_started_locally.md) for getting started.
- If you want to develop a new feature or fix for gardener, you can get started following [this guide](./getting_started_locally.md).
