#!/bin/sh

echo "Please enter a base image name for your zone"

read -p 'Base Image: ' container_name

if [ -z "${container_name}" ]; then
  echo "Error: No container name entered"
  exit 1
fi

set -e

# These don't often work well inside of a container
unsafe_dirs="dev tmp run proc sys lost+found media mnt"

clean_container_name=$( echo "${container_name}" | tr ':' '_' )

zone_image_dir='zone_images'
mkdir -p "${zone_image_dir}"

export_file="${zone_image_dir}/${clean_container_name}.tar"

if [ -f "${export_file}" ]; then
  echo "Found ${export_file}; remove the file to re-extract"
else
  id=$( podman run -id $container_name )
  podman export $id > "${export_file}"
  podman rm -f $id
fi

export_file=$( readlink -f "${export_file}" )

target_dirs=( $(tar -tf "${export_file}" | grep '^[[:alnum:]]\+/$' | tr -d '/') )

for dir in ${unsafe_dirs[@]}; do
  target_dirs=( "${target_dirs[@]/$dir}" )
done

zone_id="zone__${clean_container_name}"
container_volumes=()
for dir in ${target_dirs[@]}; do
  volume_name="${zone_id}_${dir}"

  set +e
  volume_info=$( podman volume inspect "${volume_name}" 2>/dev/null )

  if [ $? -ne 0 ]; then
    set -e
    podman volume create "${volume_name}"
    volume_info=$( podman volume inspect "${volume_name}" )
  fi

  set -e

  container_volumes+=("-v ${volume_name}:/${dir}:Z")

  (
    cd $( echo "${volume_info}" | jq -r '.[] | .Mountpoint' )
    tar --skip-old-files --strip-components=1 -xf "${export_file}" "${dir}/"
  )
done

echo "${container_name} volumes extracted and ready"

podman run --name "${zone_id}" $( IFS=$' '; echo "${container_volumes[*]}" ) --systemd=always -id $container_name /usr/sbin/init

service_file="${HOME}/.config/systemd/user/${zone_id}.service"
podman generate systemd "${zone_id}" > "${service_file}"

sed -i 's/^Restart=.*/Restart=always/' "${service_file}"

systemctl --user daemon-reload
systemctl --user enable "${zone_id}".service

podman stop "${zone_id}"
systemctl --user start "${zone_id}".service
