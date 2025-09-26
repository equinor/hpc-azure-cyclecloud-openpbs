# Equinor CycleCloud OpenPBS project

<!-- TBD: Perhaps this should be included in mkdocs updates -->

Our [CycleCloud OpenPBS fork] is a for of [Azure/cyclecloud-pbspro](https://github.com/Azure/cyclecloud-pbspro), and is used in addition to our [main Azure CycleCloud repository](https://github.com/equinor/hpc-azure-cyclecloud-openpbs)

In CycleCloud we use this OpenPBS component (a.k.a project in CC terms) on top of our main CycleCloud repository in [hpc-azure-cyclecloud](https://github.com/equinor/hpc-azure-cyclecloud) where the *shared-equinor* project is maintained

**NOTE:** Never update the master branch. That will prevent us to merge in a safe and convenient way from the upstream Azure repository. The default/target branch to use for our fork is the *development* branch

## Features

Our changes and additions provide the following for OpenPBS:

- RHEL 9 support
- Skip package installs that are in our OS images
- Isolated compute node support / Prevent updates from stalling compute node startup
- No need for `/sched` being shared from scheduler service / master node
- Login nodes no longer waits for scheduler node completion
- Support AD join, i.e. pick up nodename changes correctly

## Implementation 

The below includes only the changes / enhancements done our Azure PBS for (this repo)

We also add a number of cluster scripts and PBS hooks -  not described here.

### RHEL 9 support

This comes in two parts:

1. [Building the RPMs](https://subops.equinor.com/mkdocs/implementation/openpbs/#building-openpbs-packages). The C-json changes are not compatible with CycleCloud, so must not be included

2. Uses `/etc/os-release` to find the OS major release, then add *el8* or *el9* to package names. 

### Isolated compute nodes

- PBS template uses *cloud-init* to disable all yum/dnf repos for compute node scalesets / CC node arrays. Our compute node images must be comåplete

- Master nodes and login nodes exclude just repositories that are explicitly included in our OS images

### Eliminate need for sharing `/sched/` from master

We use the cyclecloud template to define `pbspro.scheduler` for the master scheduler server name (which is calculated from the cluster name). This is picked up with no further code changes needed.

### Make login nodes start quicker

Login nodes need not wait for the scheduler node to complete. This caused error messages and installation retries, and is not needed. Login nodes are pure clients / no PBS daemons running. 

### AD join support

By default, the nodename was picked up from the `jetpack` config nodename. We use `hostname -s` (the host shortname) to look for / await then node definition being available from the server