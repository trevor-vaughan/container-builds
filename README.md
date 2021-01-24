# Various container build scripts

Scripts to build container images using
[buildah](https://github.com/projectatomic/buildah) nested inside of podman
itself.

# Usage

Each directory type contains scripts and/or Dockerfiles for creating different
types of containers suitable for different scenarios.

## Minimal Containers

To build the minimal containers, `cd` into `minimal` and run
`./el.inside.podman`.

Output will be placed into the `images` directory and containers matching the
dockerfile extension name with `_buildah` and `_minimal` will be added to your
local image list.

## Workstation Containers

To build a 'workstation' zone, `cd` into `workstation` and run
`./bulid.sh`.
