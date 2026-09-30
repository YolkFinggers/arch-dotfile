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
alias pdf4qt='nohup Pdf4QtLaunchPad > /dev/null 2>&1 & exit'
alias clear='clear && fastfetch'
alias swapoff='sudo swapoff -a && sudo swapon -a'

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

suspend() {
    if [ -z "$1" ]; then
        echo "Error: Please specify the number of minutes."
        echo "Usage: suspend <minutes>"
        return 1
    fi
    echo "System will suspend in $1 minute(s). Press Ctrl+C to cancel."
    sleep "${1}m" && systemctl suspend
}

zed() {
    GDK_BACKEND=x11 surf http://127.0.0.1:8765/ >/dev/null 2>&1 &
    disown
}

# Separate Surf window; intentionally does not shadow the multica CLI.
alias multica-ui='nohup env GDK_BACKEND=x11 surf -f http://localhost:3000/ >/dev/null 2>&1 &'

# Created by `pipx` on 2026-04-07 01:36:29
export PATH="$PATH:/home/YolkFinggers/.local/bin"
export PATH="$HOME/.npm-global/bin:$PATH"

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
export CONTEXT7_API_KEY="ctx7sk-46a5a083-91ee-41a0-b0a5-ce7a971e2396"

source /usr/share/nvm/init-nvm.sh

function netdata(){
	env GDK_BACKEND=x11 surf http://192.168.0.24:19999
}

# Composio CLI
export PATH="$HOME/.local/bin:$PATH"

# Codex GitHub MCP: derive the token from gh's credential store; never persist it.
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  export GITHUB_PAT_TOKEN="$(gh auth token 2>/dev/null)"
fi

