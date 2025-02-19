#!/usr/bin/env bash
# silent_wayland_keyscrambler.sh
# This program is a silent key scrambler for Wayland (or Xorg) using keyd.
# It works by building & installs keyd from source (if needed) on Debian/Ubuntu-like systems,
# scrambles the unshifted letters a-z, and then silently waits for the sequence "scramble"
# (typed one character at a time without pressing Enter) to revert the keyboard.
#
# IMPORTANT:
#   - Run this script as any user; if not root, it re-executes itself with sudo.
#   - The script runs silently (with minimal terminal output).
#   - The revert sequence is the literal word "scramble". (Because keyd remaps keys, you'll need
#     to learn which physical keys produce the letters of “scramble” in the scrambled layout.)
#
# Usage:
#   chmod +x silent_wayland_keyscrambler.sh
#   ./silent_wayland_keyscrambler.sh
#
# By:
#   Nicholas Brink
#


#1: Re-run as root if not already
if [ "$EUID" -ne 0 ]; then
  exec sudo bash "$0" "$@"
  exit 0
fi


#2: Check if apt-get is available (for Debian/Ubuntu-like systems)

if ! command -v apt-get &>/dev/null; then
  echo "apt-get not found. This script supports only Debian/Ubuntu-like systems." >&2
  exit 1
fi


#3: Install build dependencies silently

apt-get update -y &>/dev/null
DEPS=(git make gcc systemd)
for dep in "\${DEPS[@]}"; do
  if ! command -v "\$dep" &>/dev/null; then
    apt-get install -y "\$dep" &>/dev/null
  fi
done


#4: Build & install keyd from source if not already installed

if ! command -v keyd &>/dev/null; then
  cd /tmp || exit 1
  if [ ! -d keyd ]; then
    git clone https://github.com/rvaiya/keyd.git &>/dev/null
  fi
  cd keyd || exit 1
  make &>/dev/null
  make install &>/dev/null
  systemctl enable keyd &>/dev/null
  systemctl start keyd &>/dev/null
fi

if ! command -v keyd &>/dev/null; then
  echo "keyd installation failed. Exiting." >&2
  exit 1
fi


#5: Scramble letters a-z

letters=(a b c d e f g h i j k l m n o p q r s t u v w x y z)
shuffled=("\${letters[@]}")
n=\${#shuffled[@]}
for (( i=n-1; i>0; i-- )); do
  j=\$((RANDOM % (i+1)))
  temp=\${shuffled[i]}
  shuffled[i]=\${shuffled[j]}
  shuffled[j]=\$temp
done

conf_file="/etc/keyd/scrambled.conf"
backup_conf="/etc/keyd/scrambled.conf.bak"
if [ -f "\$conf_file" ]; then
  cp "\$conf_file" "\$backup_conf"
fi

cat << EOC > "\$conf_file"
[ids]
*

[main]
EOC

for i in "\${!letters[@]}"; do
  orig="\${letters[\$i]}"
  new="\${shuffled[\$i]}"
  echo "\$orig = \$new" >> "\$conf_file"
done

systemctl restart keyd


#6: Wait silently for the revert sequence ("scramble")
# The target sequence is "scramble"
target="scramble"
buffer=""

# Inform the user (once) in the terminal that the keyboard is scrambled.
# (left in to ensure it can be unscrambled)
echo "[*] Keyboard scrambled. To revert, type the sequence scramble: \$target"

# Read one character at a time (without echo) from /dev/tty
while true; do
  read -rsn1 char < /dev/tty
  buffer="\$buffer\$char"
  # If buffer length exceeds target, trim the beginning
  if [ \${#buffer} -gt \${#target} ]; then
    buffer=\${buffer: -\${#target}}
  fi
  if [ "\$buffer" = "\$target" ]; then
    break
  fi
done


#7: Revert to original keyd configuration

rm -f "\$conf_file"
if [ -f "\$backup_conf" ]; then
  mv "\$backup_conf" "\$conf_file"
fi
systemctl restart keyd
echo "[*] Keyboard mapping reverted. All done!"
exit 0
EOF

chmod +x silent_wayland_keyscrambler.sh
echo "silent_wayland_keyscrambler.sh created and made executable."