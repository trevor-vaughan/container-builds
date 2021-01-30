#!/bin/sh

while true; do
  echo "Please enter the zone you wish to destroy:"

  read -p 'Zone: ' zone_name

  case $zone_name in
    zone__*)
      break;;
    *)
      zone_name="zone__${zone_name}"
      break;;
  esac
done

svc_file=$( systemctl --user cat ${zone_name} 2>/dev/null | head -1 | cut -f2- -d' ' )

if [ $? -eq 0 ] && [ -f "${svc_file}" ]; then
  echo "Disable systemd service?"
  select yn in "Yes" "No"; do
    case $yn in
      Yes )
        systemctl --user stop "${zone_name}.service"
        systemctl --user disable "${zone_name}.service"
        rm -f "${svc_file}"
        systemctl --user daemon-reload
        break;;
      No )
        break;;
    esac
  done
else
  echo "No systemd service found for ${zone_name}"
fi

if $( podman inspect "${zone_name}" >&/dev/null ); then
  echo "Remove container ${zone_name}?"
  select yn in "Yes" "No"; do
    case $yn in
      Yes )
        echo -n "Removed "
        podman rm -f "${zone_name}" ||:
        break;;
      No )
        break;;
    esac
  done
else
  echo "No container found for ${zone_name}"
fi

volumes=$( podman volume list -q | grep "${zone_name}_" )

if [ $? -eq 0 ]; then
  echo "Remove volumes for ${zone_name}?"
  select yn in "Yes" "No"; do
    case $yn in
      Yes )
        for vol in $volumes; do
          echo -n "Removed "
          podman volume rm -f "${vol}"
        done
        break;;
      No )
        break;;
    esac
  done
else
  echo "No volumes found for ${zone_name}"
fi
