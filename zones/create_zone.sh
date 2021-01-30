#!/bin/sh

echo "Please enter a base image name for your zone"

read -p 'Base Image: ' container_name

if [ -z "${container_name}" ]; then
  echo "Error: No container name entered"
  exit 1
fi

set -e

# These don't work well inside of a container
unsafe_dirs="boot dev tmp run proc sys lost+found media mnt"

clean_container_name=$( echo "${container_name}" | tr ':' '_' )

zone_image_dir='zone_images'
mkdir -p "${zone_image_dir}"

export_file="${zone_image_dir}/${clean_container_name}.tar"

if [ -f "${export_file}" ]; then
  echo "Found ${export_file}, would you like to overwrite?"

  select yn in "Yes" "No"; do
    case $yn in
      Yes ) rm -f ${export_file}; break;;
      No ) echo "Using ${export_file}"; break;;
    esac
  done
fi

if [ ! -f "${export_file}" ]; then
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

systemctl --user stop "${zone_id}".service ||:

container_volumes=()
tmp_container_volumes=()
for dir in ${target_dirs[@]}; do
  volume_name="${zone_id}_${dir}"

  set +e
  volume_info=$( podman volume inspect "${volume_name}" 2>/dev/null )

  if [ $? -ne 0 ]; then
    podman volume create "${volume_name}"
  fi
  set -e

  container_volumes+=("-v ${volume_name}:/${dir}:suid,dev,Z")
  tmp_container_volumes+=("-v ${volume_name}:/${dir}_tmp:suid,dev,Z")
done

podman rm -f "${zone_id}_tmp" 2>/dev/null ||:
echo -n "Running temp image ${zone_id}_tmp "

podman run --name "${zone_id}_tmp" \
  --rm \
  $( IFS=$' '; echo "${tmp_container_volumes[*]}" ) \
  --systemd=always \
  -id $container_name \
  /bin/sh

podman cp "${export_file}" "${zone_id}_tmp:/root/$( basename ${export_file} )"

podman exec -it "${zone_id}_tmp" tar --version >& /dev/null || podman exec -it "${zone_id}_tmp" yum -y install tar

for dir in ${target_dirs[@]}; do
  volume_name="${zone_id}_${dir}"
  volume_info=$( podman volume inspect "${volume_name}" )

  set +e
  podman exec -it "${zone_id}_tmp" tar -C "${dir}_tmp" --strip-components=1 -xf "/root/$( basename ${export_file} )" "${dir}/"

  if [ $? -ne 0 ]; then
    echo "Warning: Issue extracting '${dir}' into '${zone_id}_tmp'"
  fi
  set -e
done

podman stop "${zone_id}_tmp" >& /dev/null

echo "${container_name} volumes extracted and ready"

echo -n "Running ${zone_id}: "

podman run --name "${zone_id}" \
  $( IFS=$' '; echo "${container_volumes[*]}" ) \
  --replace=true \
  --read-only=false \
  --read-only-tmpfs=true \
  --log-driver=journald \
  --network=private \
  --cap-add=NET_ADMIN,NET_RAW,AUDIT_WRITE \
  --systemd=always \
  --security-opt=proc-opts=hidepid=2 \
  --stop-timeout=30 \
  --umask=0077 \
  --ulimit=nofile=65535:65535 \
  -id $container_name \
  /usr/sbin/init

service_file="${HOME}/.config/systemd/user/${zone_id}.service"
podman generate systemd "${zone_id}" > "${service_file}"

sed -i 's/^Restart=.*/Restart=always/' "${service_file}"

systemctl --user daemon-reload
systemctl --user enable "${zone_id}".service

podman stop "${zone_id}"
systemctl --user start "${zone_id}".service
