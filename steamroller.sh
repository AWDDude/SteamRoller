#! /bin/bash
#<Vars>
PACKAGES=( base-devel kubectl k9s micro firefox git github-cli vlc )
declare -A USERPACKAGES=( ["yay"]="https://aur.archlinux.org/yay.git" )
#["1password"]="https://aur.archlinux.org/1password.git" ["cider"]="https://aur.archlinux.org/cider.git" )
YAYPACKAGES=( "1password" "cider" )
CLEANUP=()
#</Vars>

#<Functions>
installPkg() {
  local pkg="${1}"
  if pacman -Qs "${pkg}" &> /dev/null; then
    echoGreen "Package '${pkg}' is already installed"
  else
    echoYellow "Package '${pkg}' is missing and will now be installed"
    sudo pacman --needed -S "${pkg}"
  fi
}
installUsrPkg() {
  local pkg="${1}"
  local git="${2}"
  if pacman -Qs "${pkg}" &> /dev/null; then
    echoGreen "User package '${pkg}' is already installed"
  else
    echoYellow "User package '${pkg}' is missing and will now be installed"
    dir=$(mktmp)
    (
      cd "${dir}"
      git clone "${git}"
      cd "${pkg}"
      makepkg -si
    )
  fi
}
installYayPkg() {
  local pkg="${1}"
  if pacman -Qs "${pkg}" &> /dev/null; then
    echoGreen "Yay package '${pkg}' is already installed"
  else
    echoYellow "Yay package '${pkg}' is missing and will now be installed"
    yay --cleanafter --removemake -Syu "${pkg}"
  fi
}
echoGreen() {
  echo -e "\033[32m${1}\033[m"
}
echoYellow() {
  echo -e "\033[33m${1}\033[m"
}
mktmp() {
  local tmp=$(mktemp -d)
  CLEANUP+=( "${tmp}" )
  echo "${tmp}"
}
#</Functions>

# determine if a password is set for deck
pwd=($(passwd --status))
if [ ${pwd[1]} != "P" ]; then
  echoYellow "Password must be set for this account"
  passwd
else
  echoGreen "Password already set for this account"
fi

# determine if system is currently read only
if [ $(sudo steamos-readonly status) == "enabled" ]; then
  echoYellow "Making system writable"
  sudo steamos-readonly disable
else
  echoGreen "System is already writable"
fi

# enable sshd
if [ $(sudo systemctl is-enabled sshd) != "enabled" ]; then
  echoYellow "sshd is disabled, enabling it now"
  sudo systemctl enable sshd
else
  echoGreen "sshd is already enabled"
fi

# init pacman keyring
if [ -f "/etc/pacman.d/gnupg/gpg.conf" ]; then 
  echoGreen "Pacman keyring already initialized"
else
  echoYellow "Pacman keyring will now be initialized"
  sudo pacman-key --init
fi

# populate keyring with arch keys
if [ -f "/etc/pacman.d/gnupg/tofu.db" ]; then
  echoGreen "Pacman keyring already populated"
else
  echoYellow "Pacman keyring will now be populated"
  sudo pacman-key --populate archlinux
fi

# refresh package database and update out of date packages
echoGreen "Refreshing package database and updating out of date packages"
sudo pacman -Syu

# install packages
for pkg in "${PACKAGES[@]}"; do
  installPkg "${pkg}"
done

# install user packages
for upkg in "${!USERPACKAGES[@]}"; do
  installUsrPkg "${upkg}" "${USERPACKAGES[$upkg]}"
done

echoGreen "Refreshing yay packages and updating out of date packages"
yay -Sua

# install yay packages
for pkg in "${YAYPACKAGES[@]}"; do
  installYayPkg "${pkg}"
done

# clean up temp files
for tmp in "${CLEANUP[@]}"; do
  echoGreen "Cleaning up '${tmp}'"
  rm -rf "${tmp}"
done
