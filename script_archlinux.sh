#!/bin/bash
set -e

RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
NC='\033[0m'

CACHE="$HOME/.cache/script_arch"
PAMAC_RULE_PATH="/etc/polkit-1/rules.d/99-pamac.rules"
TEMPLATE_DIR=$(xdg-user-dir TEMPLATES)

OPT_NVIDIA=false
OPT_INTEL=false
OPT_UNDERVOLT_INTEL=false
OPT_LOW_RES=false
OPT_EDID=false

help() {
    echo -e "${BLUE}» Uso do script pós-instalação Arch Linux${NC}"
    echo
    echo "  -n,  --nvidia             Instala drivers proprietários NVIDIA"
    echo "  -i,  --intel              Aplica configurações para CPUs Intel"
    echo "  -uv, --undervolt-intel    Aplica undervolt em CPUs Intel"
    echo "  -lr, --low-res            Ajusta cursor e UI para telas menores"
    echo "  -e,  --edid               Aplica EDID customizado via cmdline do kernel"
    echo "  -h,  --help               Exibe esta ajuda"
    echo
    echo "  Exemplo: ./script.sh -n -i -lr -e"
    exit 0
}

if [ "$#" -eq 0 ]; then
    sleep 0.2
    clear

    echo -e "${BLUE}» Modo interativo${NC}"
    echo "  's' para sim, Enter para pular"
    echo

    read -p "  · Drivers proprietários NVIDIA? (s/N): " resp
    [[ "$resp" =~ ^[SsYy]$ ]] && OPT_NVIDIA=true

    read -p "  · Configurações para CPU Intel? (s/N): " resp
    [[ "$resp" =~ ^[SsYy]$ ]] && OPT_INTEL=true

    read -p "  · Undervolt para CPU Intel? (s/N): " resp
    [[ "$resp" =~ ^[SsYy]$ ]] && OPT_UNDERVOLT_INTEL=true

    read -p "  · Cursor e UI para telas menores? (s/N): " resp
    [[ "$resp" =~ ^[SsYy]$ ]] && OPT_LOW_RES=true

    read -p "  · Aplicar EDID customizado? (s/N): " resp
    [[ "$resp" =~ ^[SsYy]$ ]] && OPT_EDID=true

    echo
else
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -n|--nvidia) OPT_NVIDIA=true ;;
            -i|--intel) OPT_INTEL=true ;;
            -uv|--undervolt-intel) OPT_UNDERVOLT_INTEL=true ;;
            -lr|--low-res) OPT_LOW_RES=true ;;
            -e|--edid) OPT_EDID=true ;;
            -h|--help) help ;;
            *) echo -e "${RED}! Parâmetro desconhecido: $1${NC}"; exit 1 ;;
        esac
        shift
    done
fi

if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}! Execute como usuário comum.${NC}"
    exit 1
fi

sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
trap 'kill $(jobs -p)' EXIT

NVIDIA_PKGS=()
if [ "$OPT_NVIDIA" = true ]; then
    echo -e "\n${BLUE}» Driver NVIDIA${NC}"
    echo "  1) Atual   (nvidia-dkms)"
    echo "  2) Legado  (nvidia-580xx-dkms)"
    read -p "  · Versão (1/2): " nv_escolha

    case "$nv_escolha" in
        1) NVIDIA_PKGS=(nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings) ;;
        2) NVIDIA_PKGS=(nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils nvidia-580xx-settings) ;;
        *) echo "  · Opção inválida, pulando." ;;
    esac
fi

UV_VAL=""
if [ "$OPT_UNDERVOLT_INTEL" = true ]; then
    echo -e "\n${RED}» Aviso: undervolt${NC}"
    echo "  Valores muito altos causam travamento imediato e kernel panic."
    echo "  Faça por sua conta e risco. Teste antes."
    read -t 20 -p "  · Valor em mV (ex: -50), Enter para cancelar: " UV_VAL || UV_VAL=""

    if [[ ! "$UV_VAL" =~ ^-[0-9]+$ ]]; then
        echo "  · Valor inválido, undervolt desativado."
        UV_VAL=""
    fi
fi

EDID_SRC=""
if [ "$OPT_EDID" = true ]; then
    echo -e "\n${BLUE}» EDID customizado${NC}"
    read -p "  · Caminho do arquivo EDID: " EDID_SRC

    if [ ! -f "$EDID_SRC" ]; then
        echo -e "${RED}! Arquivo não encontrado, EDID desativado${NC}"
        EDID_SRC=""
    fi
fi

rm -rf "$CACHE"
mkdir -p "$CACHE"

PKGS_PACMAN=(
    base-devel dracut systemd-ukify pacman-contrib intel-media-driver adw-gtk-theme
    discord btop steam gamemode mangohud ryujinx resources
    android-tools scrcpy faugus-launcher snes9x dolphin-emu
    qbittorrent impression flatpak firefoxpwa firefox telegram-desktop
    lact gparted dconf-editor gdm-settings zed ghostty ufw linux-zen
    linux-zen-headers linux linux-headers noto-fonts-cjk noto-fonts-emoji paru zsh zsh-completions
    switcheroo-control zsh-syntax-highlighting zsh-autosuggestions
    npm ffmpegthumbnailer plymouth fastfetch zram-generator tuned tuned-ppd
    bibata-cursor-theme pamac bazaar fuse zen-browser chromium lsfg-vk eden-git
    extension-manager refine supertuxkart libgda6 geary github-cli
    ghostty-nautilus valent-git gnome-boxes amberol mangojuice fractal newsflash
    cups cups-pdf cups-filters rmg
)

PKGS_FLATPAK=(
    io.gitlab.theevilskeleton.Upscaler org.onlyoffice.desktopeditors
    org.gnome.gitlab.somas.Apostrophe org.vinegarhq.Sober
    io.mrarm.mcpelauncher com.dec05eba.gpu_screen_recorder
    it.mijorus.gearlever com.github.tchx84.Flatseal
    org.nickvision.tubeconverter io.github.vikdevelop.SaveDesktop
    io.missioncenter.MissionCenter net.donnybeelo.Convey
    io.github.diegopvlk.Cine io.github.amit9838.mousam
    com.pojtinger.felicitas.Sessions io.github.fabrialberio.pinapp
    com.cassidyjames.clairvoyant
)

PKGS_AUR=(
    gnome-shell-extension-valent-git cemu-bin morewaita-icon-theme-git mixtapes-git pcsx2-latest-bin
)

if [ ${#NVIDIA_PKGS[@]} -gt 0 ]; then
    PKGS_PACMAN+=("${NVIDIA_PKGS[@]}")
fi

if [ "$OPT_UNDERVOLT_INTEL" = true ]; then
    PKGS_PACMAN+=(intel-undervolt)
fi

echo -e "\n${BLUE}» Chaotic-AUR${NC}"
sudo pacman-key --recv-key 3056513887B78AEB
sudo pacman-key --lsign-key 3056513887B78AEB
sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf > /dev/null
fi

sudo pacman -Sy

echo -e "\n${BLUE}» Pacotes pacman${NC}"
sudo pacman -S --needed --noconfirm "${PKGS_PACMAN[@]}"

echo -e "\n${BLUE}» Pacotes Flatpak${NC}"
sudo flatpak install flathub "${PKGS_FLATPAK[@]}" -y

echo -e "\n${BLUE}» Pacotes AUR${NC}"
paru -S --needed --noconfirm "${PKGS_AUR[@]}"

echo -e "\n${BLUE}» Removendo aplicativos não utilizados${NC}"
INSTALLED=$(pacman -Qq decibels showtime gnome-music gnome-console epiphany gnome-software gnome-weather yelp gnome-user-docs gnome-tour htop 2>/dev/null || true)

if [ -n "$INSTALLED" ]; then
    echo "$INSTALLED" | sudo pacman -Rns - --noconfirm
else
    echo "  · Nada a remover."
fi

if [ -f "$HOME/.local/share/applications/org.gnome.Extensions.desktop" ]; then
    echo "  · Extensions já oculto."
elif [ -f "/usr/share/applications/org.gnome.Extensions.desktop" ]; then
    mkdir -p "$HOME/.local/share/applications/"
    cp /usr/share/applications/org.gnome.Extensions.desktop "$HOME/.local/share/applications/"
    echo "NoDisplay=true" >> "$HOME/.local/share/applications/org.gnome.Extensions.desktop"
else
    echo "  · Atalho do Extensions não encontrado, pulando."
fi

echo -e "\n${BLUE}» Ghostty${NC}"
mkdir -p "$HOME/.config/ghostty"
cat << 'EOF' > "$HOME/.config/ghostty/config"
theme = light:Adwaita,dark:Adwaita Dark
font-size = 11
window-padding-x = 8
window-height = 24
window-width = 70
gtk-titlebar-style = tabs
gtk-wide-tabs = false
gtk-custom-css = ~/.config/ghostty/styles.css
background-opacity = 1
alpha-blending = native
background-opacity = 0
EOF

cat << 'EOF' > "$HOME/.config/ghostty/styles.css"
/* Suporte ao tema tinted da extensão GNOME ChromaLeon */
@import url("/home/fabito02/.config/gtk-4.0/custom-accent.css");

window{
    background: @view_bg_color;
}

revealer.raised.top-bar {
    box-shadow: none;
    border: none;
}

scrolledwindow > widget > tabgrid,
toolbarview > overlay,
windowhandle {
    background-color: @view_bg_color;
}
EOF

echo -e "\n${BLUE}» ZSH${NC}"
sudo chsh -s "$(which zsh)" "$USER"
mkdir -p "$HOME/.zsh"
if [ ! -d "$HOME/.zsh/pure" ]; then
    git clone https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"
fi

cat << 'EOF' > "$HOME/.zshrc"
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt sharehistory
setopt hist_ignore_dups
setopt hist_ignore_space

fpath+=$HOME/.zsh/pure
autoload -U promptinit; promptinit
prompt pure

autoload -Uz compinit
compinit

source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
EOF

echo -e "\n${BLUE}» Arquivos modelo${NC}"
if [ -d "$TEMPLATE_DIR" ]; then
    touch "$TEMPLATE_DIR/Documento de Texto.txt"
    touch "$TEMPLATE_DIR/Documento Markdown.md"

    echo -e "#!/bin/bash\n\necho \"Hello, World!\"" > "$TEMPLATE_DIR/Script Bash.sh"
    chmod +x "$TEMPLATE_DIR/Script Bash.sh"

    echo -e "#!/usr/bin/env python3\n\nprint(\"Hello, World!\")" > "$TEMPLATE_DIR/Script Python.py"
    chmod +x "$TEMPLATE_DIR/Script Python.py"

    cat << 'EOF' > "$TEMPLATE_DIR/Atalho de Aplicativo.desktop"
[Desktop Entry]
Type=Application
Name=Nome do App
Exec=caminho_do_executavel
Icon=caminho_do_icone
Terminal=false
Categories=Utility;
EOF
    echo "  · Criados em $TEMPLATE_DIR"
else
    echo "  · Pasta XDG de modelos não encontrada, pulando."
fi

echo -e "\n${BLUE}» Interface e temas${NC}"
flatpak install org.gtk.Gtk3theme.adw-gtk3 org.gtk.Gtk3theme.adw-gtk3-dark -y
sudo flatpak override --filesystem=xdg-data/themes
sudo flatpak override --filesystem=xdg-config/gtk-3.0
sudo flatpak override --filesystem=xdg-config/gtk-4.0
flatpak override --user --filesystem=xdg-cache/thumbnails
sudo flatpak mask org.gtk.Gtk3theme.adw-gtk3
sudo flatpak mask org.gtk.Gtk3theme.adw-gtk3-dark

gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
gsettings set org.gnome.desktop.interface color-scheme 'default'
gsettings set org.gnome.shell disable-extension-version-validation true
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
gsettings set org.gnome.shell always-show-log-out true

if [ "$OPT_LOW_RES" = true ]; then
    gsettings set org.gnome.desktop.interface cursor-size 20
fi

cd "$CACHE"
git clone --depth 1 https://github.com/maximilionus/lucidglyph
cd lucidglyph && sudo ./lucidglyph.sh install
cd "$CACHE"

echo -e "\n${BLUE}» Plymouth${NC}"
paru -S --noconfirm plymouth-theme-arch-darwin
sudo plymouth-set-default-theme arch-darwin

echo -e "\n${BLUE}» NTSYNC${NC}"
echo "ntsync" | sudo tee /etc/modules-load.d/ntsync.conf > /dev/null

echo -e "\n${BLUE}» Gaze${NC}"
curl -fsSL https://gaze.gundulabs.com/install.sh | sh

echo -e "\n${BLUE}» Polkit para Pamac${NC}"
if grep -q '^wheel:' /etc/group; then USER_GROUP="wheel"; else USER_GROUP="sudo"; fi

sudo tee $PAMAC_RULE_PATH > /dev/null <<EOF
polkit.addRule(function(action, subject) {
    if ((action.id == "org.manjaro.pamac.commit" ||
         action.id == "org.manjaro.pamac.modify") &&
        subject.isInGroup("$USER_GROUP")) {
        return polkit.Result.YES;
    }
});
EOF

echo -e "\n${BLUE}» ZRAM${NC}"
echo -e "[zram0]\nzram-size = ram\ncompression-algorithm = zstd" | sudo tee /etc/systemd/zram-generator.conf > /dev/null

if [ -n "$UV_VAL" ]; then
    echo -e "\n${BLUE}» Undervolt${NC}"
    sudo cp /etc/intel-undervolt.conf /etc/intel-undervolt.conf.bak
    sudo sed -i "s/^undervolt 0.*/undervolt 0 'CPU' ${UV_VAL}/" /etc/intel-undervolt.conf
    sudo sed -i "s/^undervolt 2.*/undervolt 2 'CPU Cache' ${UV_VAL}/" /etc/intel-undervolt.conf
    sudo systemctl enable --now intel-undervolt.service
    sudo intel-undervolt apply
fi

echo -e "\n${BLUE}» TCP BBR${NC}"
echo "tcp_bbr" | sudo tee /etc/modules-load.d/bbr.conf > /dev/null
echo -e "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr" | sudo tee /etc/sysctl.d/bbr.conf > /dev/null

echo -e "\n${BLUE}» Segurança e serviços${NC}"
sudo systemctl enable --now ufw.service > /dev/null 2>&1
sudo ufw allow 1714:1764/udp > /dev/null 2>&1
sudo ufw allow 1714:1764/tcp > /dev/null 2>&1
sudo ufw --force enable > /dev/null 2>&1

sudo sed -i 's/.*SystemMaxUse=.*/SystemMaxUse=100M/' /etc/systemd/journald.conf
sudo systemctl restart systemd-journald

sudo systemctl enable --now switcheroo-control.service tuned fstrim.timer cups systemd-oomd.service paccache.timer > /dev/null 2>&1

cat << 'EOF' | sudo tee /etc/sysctl.d/99-kernel-tweaks.conf > /dev/null
kernel.nmi_watchdog=0
kernel.sysrq=1
EOF

if [ -n "$EDID_SRC" ]; then
    echo -e "\n${BLUE}» EDID customizado${NC}"
    sudo mkdir -p /usr/lib/firmware/edid
    sudo cp "$EDID_SRC" /usr/lib/firmware/edid/edid_custom.bin
    EDID_CMDLINE="drm.edid_firmware=eDP-1:edid/edid_custom.bin"
    EDID_ITEM=" /usr/lib/firmware/edid/edid_custom.bin "
    echo "  · Instalado em /usr/lib/firmware/edid/edid_custom.bin"
else
    EDID_CMDLINE=""
    EDID_ITEM=""
fi

echo -e "\n${BLUE}» Bootloader (migração para UKI e Dracut)${NC}"

if pacman -Qs mkinitcpio > /dev/null; then
    echo "  · Removendo mkinitcpio"
    sudo pacman -Rns --noconfirm mkinitcpio
fi

sudo mkdir -p /etc/kernel /etc/dracut.conf.d

CMDLINE="quiet splash"
[ "$OPT_INTEL" = true ] && CMDLINE="intel_pstate=passive $CMDLINE"
[ -n "$EDID_CMDLINE" ] && CMDLINE="$CMDLINE $EDID_CMDLINE"

# Dracut gera o UKI e lê a linha de comando via kernel_cmdline,
# não via /etc/kernel/cmdline.
echo "kernel_cmdline=\"$CMDLINE\"" | sudo tee /etc/dracut.conf.d/cmdline.conf > /dev/null

cat << 'EOF' | sudo tee /etc/kernel/install.conf > /dev/null
layout=uki
initrd_generator=dracut
uki_generator=dracut
EOF

DRIVERS=""
[ "$OPT_INTEL" = true ] && DRIVERS+=" i915"
[ "$OPT_NVIDIA" = true ] && DRIVERS+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm"

{
    echo 'uefi="yes"'
    echo 'hostonly="yes"'
    echo 'compress="zstd"'
    echo 'add_dracutmodules+=" plymouth "'
    [ -n "$DRIVERS" ] && echo "add_drivers+=\"${DRIVERS} \""
    [ -n "$EDID_ITEM" ] && echo "install_items+=\"${EDID_ITEM}\""
} | sudo tee /etc/dracut.conf.d/arch.conf > /dev/null

echo "  · Limpando artefatos legados de /boot"
sudo find /boot -maxdepth 1 -type f \
    \( -name 'vmlinuz-*' -o -name 'initramfs-*.img' \) \
    -delete 2>/dev/null || true

sudo find /boot/EFI/Linux -type f -name '*.efi' -delete 2>/dev/null || true
sync

KERNELS=$(ls /usr/lib/modules | wc -l)
REQUIRED_MB=$((KERNELS * 180))
AVAILABLE_MB=$(df -BM --output=avail /boot | tail -1 | tr -dc '0-9')

if [ "$AVAILABLE_MB" -lt "$REQUIRED_MB" ]; then
    echo -e "${RED}! /boot com ${AVAILABLE_MB}MB livres, ~${REQUIRED_MB}MB necessários${NC}"
    sudo du -sh /boot/* 2>/dev/null | sort -rh | head -5 | sed 's/^/    /'
    exit 1
fi

echo "  · Gerando UKIs para $KERNELS kernel(s)"
sudo kernel-install add-all 2>&1 | grep -vE "SBAT|Wrote unsigned|does not contain" || true

UKI_COUNT=$(sudo find /boot/EFI/Linux -maxdepth 1 -type f -name '*.efi' 2>/dev/null | wc -l)

if [ "$UKI_COUNT" -eq "$KERNELS" ]; then
    echo "  · Migração concluída ($UKI_COUNT UKIs)"
else
    echo -e "${RED}! Esperados $KERNELS UKIs, encontrados $UKI_COUNT${NC}"
    exit 1
fi

echo -e "\n${BLUE}» systemd-resolved${NC}"
sudo mkdir -p /etc/NetworkManager/conf.d
echo -e "[main]\ndns=systemd-resolved" | sudo tee /etc/NetworkManager/conf.d/dns.conf > /dev/null

sudo mkdir -p /etc/systemd/resolved.conf.d
cat << 'EOF' | sudo tee /etc/systemd/resolved.conf.d/dns_servers.conf > /dev/null
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com
FallbackDNS=8.8.8.8#dns.google 8.8.4.4#dns.google
Domains=~.
DNSOverTLS=yes
DNSSEC=allow-downgrade
Cache=yes
EOF

sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
sudo systemctl enable --now systemd-resolved.service > /dev/null 2>&1
sudo systemctl restart NetworkManager.service > /dev/null 2>&1

rm -rf "$CACHE"

echo
echo -e "${GREEN}✓ Instalação finalizada. Reinicie para aplicar todas as mudanças.${NC}"
read -p "  · Reiniciar agora? (s/N): " resposta

if [[ "$resposta" =~ ^[SsYy]$ ]]; then
    systemctl reboot
fi
