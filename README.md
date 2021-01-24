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

To build a 'workstation' zone, `cd` into `workstation` and use `buildah` to
build the selected dockerfile.

Example: `buildah bud -t el8ws -f Dockerfile.el8ws .`

## Zones

Zones are persistent container runtimes that act more like "regular systems"
than traditional containers.

To run a zone, `cd` into `zones` and run `create_zone.sh`.

Example: `./create_zone.sh`

* If you've bulid the workstation from the previous section, enter `el8ws` when
  prompted for the target.
