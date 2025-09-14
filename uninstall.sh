#!/bin/bash

readonly INSTALL_PATH="/root/.scripts"
readonly USER_NAME="$(logname)"
readonly USER_HOME="$(sudo -u "$USER_NAME" sh -c 'echo $HOME')"

printf 'Removing Opera fix scripts and aliases...\n'

# Remove package hooks safely
[[ -f /etc/apt/apt.conf.d/99fix-opera ]] && rm -f /etc/apt/apt.conf.d/99fix-opera
[[ -f /usr/share/libalpm/hooks/fix-opera.hook ]] && rm -f /usr/share/libalpm/hooks/fix-opera.hook
[[ -f /etc/dnf/plugins/post-transaction-actions.d/fix-opera.action ]] && rm -f /etc/dnf/plugins/post-transaction-actions.d/fix-opera.action

# Remove alias from user's bashrc
[[ -f "$USER_HOME/.bashrc" ]] && sed -i '/alias fix-opera/d' "$USER_HOME/.bashrc"

# Remove installed script directory
[[ -d "$INSTALL_PATH" ]] && rm -rf "$INSTALL_PATH"

printf 'Uninstallation complete.\n'

