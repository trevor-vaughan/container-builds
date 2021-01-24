#!/bin/bash

set -e

# start new container from scratch
newcontainer=$(buildah from scratch)
scratchmnt=$(buildah mount ${newcontainer})

releasever=$(rpm --eval '%{rhel}')
os_version="el${releasever}"

if [ "${releasever}" == '%{rhel}' ]; then
  releasever=$(rpm --eval '%{fedora}')
  os_version="f${releasever}"
fi

# Reduce the language pack size
echo '%_install_langs C:en:en_US:en_US.UTF-8' > /etc/rpm/macros.image-language-conf

# Also in the target container permanently
mkdir -p ${scratchmnt}/etc/rpm
echo '%_install_langs C:en:en_US:en_US.UTF-8' > ${scratchmnt}/etc/rpm/macros.image-language-conf

yum_install="
  yum --installroot ${scratchmnt} \
    --noplugins \
    --releasever $releasever \
    --setopt=tsflags=nodocs \
    --setopt=override_install_langs=en_US.utf8 \
    --setopt=install_weak_deps=False \
    install -y"

# This needs to be first so that 'all-langpacks' is not pulled in (EL8+)
$yum_install 'glibc-langpack-en' ||:

# install the packages
pkgs=(
  'bash'
  'yum'
)

for pkg in "${pkgs[@]}"; do
  $yum_install $pkg
done

# Clean up yum cache
yum --installroot ${scratchmnt} clean all

if [ -d "${scratchmnt}"/var/cache/yum ]; then
  rm -rf "${scratchmnt}"/var/cache/yum
fi

# Clean up docs that ignore the yum settings

docdirs=$(rpm --eval '%{__docdir_path}' | sed 's/:\+/ /g')

for dir in $docdirs; do
  if [ -d ${scratchmnt}/$dir ]; then
    find ${scratchmnt}/$dir -type f -delete
  fi
done

# Ensure that the image stays minimal
yum_conf=<<HEREDOC
[main]
best=True
clean_requirements_on_remove=True
gpgcheck=1
install_weak_deps=False
installonly_limit=2
keepcache=False
multilib_policy=best
releasever=${releasever}
skip_if_unavailable=True
tsflags=nodocs
HEREDOC

echo $yum_conf > ${scratchmnt}/etc/yum.conf

# Services that run with private networking will not work inside of a container
for x in $( grep -l PrivateNetwork=yes ${scratcnmnt}/usr/lib/systemd/system/*.service ); do
  svcname=$( basename "${x}")
  override_dir="${scratchmnt}/etc/systemd/system/${svcname}.d"

  mkdir -p "${override_dir}"

  echo -e "[Service]\nPrivateNetwork=no" > "${override_dir}/private_network_override.conf"
done

# configure container label and entrypoint
buildah config --label name=${os_version}_minimal ${newcontainer}
buildah config --cmd /bin/bash ${newcontainer}

# commit the image
buildah unmount ${newcontainer}
buildah commit ${newcontainer} ${os_version}_minimal
