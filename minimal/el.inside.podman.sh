#!/bin/sh

OS_VERSION=${OS_VERSION:=''}
FLAVOR=${FLAVOR:=minimal}

if [ -z "${OS_VERSION}" ]; then
  echo "Please enter one of the following to build:"

  for x in Dockerfile.*; do
    echo "  * $( echo "${x}" | cut -f2 -d'.' )"
  done

  read -p 'OS Version: ' os_version

  OS_VERSION="${os_version}"
fi

dockerfile="Dockerfile.${OS_VERSION}"
if [ ! -f "${dockerfile}" ]; then
  echo "Error: Could not find '${os_version}'"
  exit 1
fi

buildah_image=${OS_VERSION}_buildah
output_image=${OS_VERSION}_${FLAVOR}

(
  cd `dirname $0`

  if ! ( buildah images -q $buildah_image >& /dev/null ); then
    echo 'Building base build container image'

    buildah bud -t $buildah_image -f "${dockerfile}" .
  fi

  need_exec=1

  status=`podman ps -a --format "{{.ID}} {{.Image}} {{.Status}}" | grep "/$buildah_image:"`

  if [ $? -eq 0 ]; then
    container_id=`echo "${status}" | cut -f1 -d' '`
    if ( echo "${status}" | grep -i ' up '); then
      echo "Using existing container '${container_id}'"
      echo "Run 'podman rm -f ${container_id}' and run again if you wish to rebuild the container"
    else
      echo "Removing EXITED '${OS_VERSION}_buildah' container"

      podman rm -f `echo "${status}" | cut -f1 -d' '` >& /dev/null

      echo -n "Creating '${buildah_image}' container => "

      need_exec=0
    fi
  else
    need_exec=0
  fi

  mkdir -p tmp/volumes

  if [ $need_exec -eq 0 ]; then
    # Pulled from:
    # https://developers.redhat.com/blog/2019/04/04/build-and-run-buildah-inside-a-podman-container/
    podman run --detach --name=${buildah_image} --net=host --security-opt label=disable \
      --security-opt seccomp=unconfined --device /dev/fuse:rw \
      -v $PWD/tmp/volumes:/var/lib/containers/storage/overlay:Z \
      ${buildah_image} sh -c 'while true; do sleep 10; wait; done'
  fi

  for x in *.sh; do
    podman cp $x ${buildah_image}:/tmp
  done

  mkdir -p 'images'

  podman exec -t ${buildah_image} sh -c "sh /tmp/el.minimal.sh"
  podman exec -t ${buildah_image} sh -c "buildah push ${output_image}:latest oci-archive:${output_image}.tar:${output_image}"
  podman cp ${buildah_image}:${output_image}.tar images/

  podman pull oci-archive:images/${output_image}.tar

  podman rm -f "${buildah_image}"
)
