#! /bin/bash
#<Vars>
PACKAGES=( "base-devel" "git" )
declare -A USERPACKAGES=( ["yay"]="https://aur.archlinux.org/yay.git" )
YAYPACKAGES=( "1password" "cider" "discord" "vlc" "kubectl" "kubectx" "k9s" "micro" "firefox" "github-cli" "protonup-qt-bin" )
CLEANUP=()
SWAPGB=8
SWAPPINESS=1
#</Vars>

#<Functions>
installPkg() {
  local pkg="${1}"
  if pacman -Qs "${pkg}" &> /dev/null; then
    echoGreen "Package '${pkg}' is already installed"
  else
    echoYellow "Package '${pkg}' is missing and will now be installed"
    sudo pacman --noconfirm -S "${pkg}"
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
  if yay -Q "${pkg}" &> /dev/null; then
    echoGreen "Yay package '${pkg}' is already installed"
  else
    echoYellow "Yay package '${pkg}' is missing and will now be installed"
    yay --answerclean None --answerdiff None --cleanafter --removemake -Syu "${pkg}"
  fi
}
echoGreen() {
  echo -e "\033[32m${1}\033[m"
}
echoYellow() {
  echo -e "\033[33m${1}\033[m"
}
echoRed() {
  echo -e "\033[31m${1}\033[m"
}
bannerGreen() {
  msg="# ${1} #"
  echo -e "\033[1;32m"
  yes '#'| head -n "${#msg}" | tr -d '\n'
  echo -e "\n${msg}"
  yes '#'| head -n "${#msg}" | tr -d '\n'
  echo -e "\033[0m"
}
bannerYellow() {
  msg="# ${1} #"
  echo -e "\033[1;33m"
  yes '#'| head -n "${#msg}" | tr -d '\n'
  echo -e "\n${msg}"
  yes '#'| head -n "${#msg}" | tr -d '\n'
  echo -e "\033[0m"
}
bannerRed() {
  msg="# ${1} #"
  echo -e "\033[1;31m"
  yes '#'| head -n "${#msg}" | tr -d '\n'
  echo -e "\n${msg}"
  yes '#'| head -n "${#msg}" | tr -d '\n'
  echo -e "\033[0m"
}
mktmp() {
  local tmp=$(mktemp -d)
  CLEANUP+=( "${tmp}" )
  echo "${tmp}"
}
#</Functions>

# determine if a password is set for deck
bannerGreen "User Password"
pwd=($(passwd --status))
if [ ${pwd[1]} != "P" ]; then
  echoYellow "Password must be set for this account"
  passwd
else
  echoGreen "Password already set for this account"
fi

# determine if system is currently read only
bannerGreen "Read Only System"
if [ $(sudo steamos-readonly status) == "enabled" ]; then
  echoYellow "Making system writable"
  sudo steamos-readonly disable
else
  echoGreen "System is already writable"
fi

# increase swapfile size
bannerGreen "Swap File Size"
currentSwapBytes=$(ls -l /home/swapfile | awk '{print $5}')
swapBytes=$((SWAPGB * 1024 * 1024 * 1024))
if [ "${swapBytes}" != "${currentSwapBytes}" ]; then
  echoYellow "resizing swapfile"
  sudo swapoff -a
  sudo dd if=/dev/zero of=/home/swapfile bs=1G count=$SWAPGB status=none
  sudo chmod 0600 /home/swapfile
  sudo mkswap /home/swapfile
  sudo swapon /home/swapfile
else
  echoGreen "swapfile configured correctly"
fi

# decrease swappiness
bannerGreen "Swappiness"
currentswappiness=$(sysctl vm.swappiness | awk '{print $3}')
if [ "${SWAPPINESS}" != "${currentswappiness}" ]; then
  echoYellow "updating swappiness configuration"
  echo "vm.sappiness=$SWAPPINESS" | sudo tee /etc/sysctl.d/swappiness.conf
  sudo sysctl -w vm.swappiness=1
else
  echoGreen "swappiness configured correctly"
fi

# enable fstrim timer
bannerGreen "Fs Trim Timer"
systemctl list-timers | grep fstrim &>/dev/null
if [ "$?" == "1" ]; then
  echoYellow "enabling fs trim timer"
  sudo systemctl enable --now fstrim.timer &>/dev/null
else
  echoGreen "fs trim timer configured correctly"
fi

# run fstrim
bannerGreen "Running FsTrim"
sudo fstrim -v /

# enable sshd
bannerGreen "SSHD"
if [ $(sudo systemctl is-enabled sshd) != "enabled" ]; then
  echoYellow "sshd is disabled, enabling it now"
  sudo systemctl enable sshd
else
  echoGreen "sshd is already enabled"
fi

# init pacman keyring
bannerGreen "Pacman"
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
bannerGreen "Packages"
for pkg in "${PACKAGES[@]}"; do
  installPkg "${pkg}"
done

# install user packages
bannerGreen "User Packages"
for upkg in "${!USERPACKAGES[@]}"; do
  installUsrPkg "${upkg}" "${USERPACKAGES[$upkg]}"
done

# update yay packages
bannerGreen "Refreshing yay packages and updating out of date packages"
yay -Sua

# install yay packages
bannerGreen "Yay Packages"
for pkg in "${YAYPACKAGES[@]}"; do
  installYayPkg "${pkg}"
done

# clean up temp files
bannerGreen "Clean up"
for tmp in "${CLEANUP[@]}"; do
  echoGreen "Cleaning up '${tmp}'"
  rm -rf "${tmp}"
done

bannerGreen "Complete"