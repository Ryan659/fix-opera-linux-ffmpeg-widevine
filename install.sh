#!/bin/bash

if [[ $(id -u) -ne 0 ]]; then
  printf 'Try to run it with sudo\n'
  exit 1
fi

if [[ $(uname -m) != "x86_64" ]]; then
  printf 'This script is intended for 64-bit systems\n'
  exit 1
fi

for bin in unzip bsdtar curl jq; do
  if ! command -v "$bin" > /dev/null; then
    printf '\033[1m%s\033[0m package must be installed to run this script\n' "$bin"
    exit 1
  fi
done

# Paths
readonly SCRIPT_PATH="$(dirname "$(readlink -f "$0")")"
readonly INSTALL_PATH="/root/.scripts"
readonly USER_NAME="$(logname)"
readonly USER_HOME="$(sudo -u "$USER_NAME" sh -c 'echo $HOME')"

create_hook() {
  printf 'Choose your Linux distro:\n'
  printf '  1. Debian-based (Debian/Ubuntu/Mint/etc.)\n'
  printf '  2. Arch-based (Arch/Manjaro/etc.)\n'
  printf '  3. RedHat-based (RedHat/Fedora/etc.)\n'
  printf '  0. Other\n'

  while read -rp "Your choice: " DISTRIB; do
    case $DISTRIB in
      1)
        cp -f "$SCRIPT_PATH/scripts/99fix-opera" "$INSTALL_PATH"
        ln -sf "$INSTALL_PATH/99fix-opera" /etc/apt/apt.conf.d/
        printf 'Now the script will run automatically every time apt installs or updates Opera.\n'
        break
        ;;
      2)
        cp -f "$SCRIPT_PATH/scripts/fix-opera.hook" "$INSTALL_PATH"
        ln -sf "$INSTALL_PATH/fix-opera.hook" /usr/share/libalpm/hooks/
        printf 'Now the script will run automatically every time pacman installs or updates Opera.\n'
        break
        ;;
      3)
        dnf install -y python3-dnf-plugin-post-transaction-actions
        cp -f "$SCRIPT_PATH/scripts/fix-opera.action" "$INSTALL_PATH"
        ln -sf "$INSTALL_PATH/fix-opera.action" /etc/dnf/plugins/post-transaction-actions.d/
        printf 'Now the script will run automatically every time dnf installs or updates Opera.\n'
        break
        ;;
      0)
        printf 'Autostart for your distro is currently unsupported.\n'
        break
        ;;
      *) continue ;;
    esac
  done
}

printf 'Installing script to your system...\n'

printf 'Would you like to apply Widevine CDM fix? [y/n] '
while read FIX_WIDEVINE; do
  case $FIX_WIDEVINE in
    [yY])
      printf 'Enabling Widevine fix...\n'
      sed -i 's/^\(readonly FIX_WIDEVINE=\).*/\1true/' "$SCRIPT_PATH/scripts/fix-opera.sh"
      break
      ;;
    [nN])
      printf 'Disabling Widevine fix...\n'
      sed -i 's/^\(readonly FIX_WIDEVINE=\).*/\1false/' "$SCRIPT_PATH/scripts/fix-opera.sh"
      break
      ;;
    *) printf 'Would you like to apply Widevine CDM fix? [y/n] ' ;;
  esac
done

# Install the main script
mkdir -p "$INSTALL_PATH"
cp -f "$SCRIPT_PATH/scripts/fix-opera.sh" "$INSTALL_PATH"
chmod +x "$INSTALL_PATH/fix-opera.sh"

# Alias setup
printf "Would you like to create an alias for user $USER_NAME? [y/n] "
while read CREATE_ALIAS; do
  case $CREATE_ALIAS in
    [yY])
      echo "alias fix-opera='sudo ~root/.scripts/fix-opera.sh' # Opera fix HTML5 media" >> "$USER_HOME/.bashrc"
      printf 'Alias "fix-opera" will be available after your next login.\n'
      break
      ;;
    [nN]) break ;;
    *) printf "Would you like to create an alias for user $USER_NAME? [y/n] " ;;
  esac
done

# Hook setup
printf 'Would you like to run it automatically after each Opera update? [y/n] '
while read CREATE_HOOK; do
  case $CREATE_HOOK in
    [yY]) create_hook; break ;;
    [nN]) break ;;
    *) printf 'Would you like to run it automatically after each Opera update? [y/n] ' ;;
  esac
done

printf 'Would you like to run it now? [y/n] '
while read RUN_NOW; do
  case $RUN_NOW in
    [yY]) "$INSTALL_PATH/fix-opera.sh"; break ;;
    [nN]) break ;;
    *) printf 'Would you like to run it now? [y/n] ' ;;
  esac
done

