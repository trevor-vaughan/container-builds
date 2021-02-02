## Various container build scripts

Scripts to build container images using
[buildah](https://github.com/projectatomic/buildah) nested inside of podman
itself.

<!-- vim-markdown-toc GFM -->

* [Description](#description)
* [Setup](#setup)
  * [Setup requirements](#setup-requirements)
* [Usage](#usage)
  * [Zones](#zones)
  * [Workstation Containers](#workstation-containers)
  * [Minimal Containers](#minimal-containers)
* [Reference](#reference)
  * [Additional setup requirements for EL7.7+](#additional-setup-requirements-for-el77)

<!-- vim-markdown-toc -->

## Description

* _Tired of the everyday grind?_
* _Ever dream of a life of romantic adventure?_
* _Want to get away from it all?_
* We offer you...
  * ~~[Escape]!~~
  * **[Podman] containers that act like ~~fancy chroots~~ [Solaris Zones].**

## Setup

### Setup requirements

* [Podman]
* [Buildah]
* (If running from EL7.7+):
  * [Additional setup requirements for EL7.7+](#additional-setup-requirements-for-el77)
  * Chutzpah and a steely resolve

## Usage

Each directory type contains scripts and/or Dockerfiles for creating different
types of containers suitable for different scenarios:

```
./
├── minimal/
│   ├── Dockerfile.el7
│   ├── Dockerfile.el8
│   ├── Dockerfile.f33
│   ├── el.inside.podman.sh
│   └── el.minimal.sh
├── workstation/
│   ├── Dockerfile.el7ws
│   ├── Dockerfile.el8ws
│   └── wsprep.sh
└── zones/
    ├── create_zone.sh
    └── destroy_zone.sh
```


### Zones

Zones are container runtimes with persistent storage that act more like
"regular systems" than traditional containers.

To run a zone, `cd` into `zones/` and run `create_zone.sh`.

### Workstation Containers

To build a 'workstation' zone, `cd` into `workstation/` and use `buildah` to
build the selected dockerfile.

**Example:** 

    buildah bud -t el8ws -f Dockerfile.el8ws .

You can instantiate the workstation images you build as zones from the `zones/`
directory.

**Example:** 

1. Build the `el8ws` workstation image from the Dockerfile as in the previous example
2. Change back into the `../zones/` directory
3. Run `./create_zone.sh`
4. Enter `el8ws` when prompted for the target.

### Minimal Containers

To build the minimal containers, `cd` into `minimal/` and run
`./el.inside.podman.sh`.

Output will be placed into an `images/` directory, and containers matching the
dockerfile extension name with `_buildah` and `_minimal` will be added to your
local image list.

## Reference

### Additional setup requirements for EL7.7+

The following steps were tested on CentOS 7.9 and adapted from [[0]] and [[1]]:

* Enable the `extras` repository
* Make sure you have `podman` and `buildah` installed:

  ```sh
  yum install -y podman buildah
  ```

* Make sure the `user.max_user_namespaces` sysctl is greater than zero:

  ```sh
  echo user.max_user_namespaces=10000 > /etc/sysctl.d/userns.conf
  sysctl --system
  ```

* If you created your user account prior to EL7.7, configure `/etc/subuid` and
  `/etc/subgid` mappings for your existing user (In EL7.7+, `useradd` will
  automatically set these up when creating new accounts):

  ```sh
  echo "$(cat /proc/self/loginuid):200000:65536" >> /etc/subuid
  echo "$(cat /proc/self/loginuid):200000:65536" >> /etc/subgid
  ```

* Test a podman command:

  ```sh
  podman unshare cat /proc/self/uidmap
  ```

  * If you get an error like `Error: could not get runtime: cannot write
    setgroups file: open /proc/8449/setgroups: permission denied` and `findmnt
    /proc` shows a `hidepid=` greater than `0`, see
    https://access.redhat.com/discussions/5468621 and use [`podman` >=
    v1.8.2](https://github.com/containers/podman/pull/5550)


[podman]: https://podman.io/
[buildah]: https://buildah.io/
[solaris zones]: https://www.eginnovations.com/documentation/Solaris-Virtual-Server/What-are-Solaris-Zones.htm
[escape]: https://archive.org/details/OTRR_Escape_Singles
[0]: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_atomic_host/7/html-single/managing_containers/index#set_up_for_rootless_containers
[1]: https://www.reddit.com/r/redhat/comments/cpxe65/question_enabling_rootless_user_namespaces_rhel_77/
