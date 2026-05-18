#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ssh='TERM=xterm-256color ssh'
alias sail='[ -f sail ] && bash sail || bash vendor/bin/sail'
alias restart_audio='systemctl restart --user pipewire'

PS1='[\u@\h \W]\$ '

export BIOME_CONFIG="$HOME/.config/biome/biome.json"
export PATH="$HOME/.cargo/bin:$PATH"
export EDITOR="nvim"

eval "$(starship init bash)"
fastfetch
HYPRSHOT_DIR="/home/YolkFinggers/screenshots"

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

function Hyprland() {
	start-hyprland -- "$@"
}

winboot(){
	sudo grub-reboot "Windows Boot Manager (on /dev/nvme0n1p5)" && sudo reboot
}

# Created by `pipx` on 2026-04-07 01:36:29
export PATH="$PATH:/home/YolkFinggers/.local/bin"
export PATH="$HOME/.npm-global/bin:$PATH"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"

# pnpm
export PNPM_HOME="/home/YolkFinggers/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
export PATH="$HOME/.local/bin:$PATH"
export PATH="/home/YolkFinggers/.config/herd-lite/bin:$PATH"
export PHP_INI_SCAN_DIR="/home/YolkFinggers/.config/herd-lite/bin:$PHP_INI_SCAN_DIR"

source /usr/share/nvm/init-nvm.sh
