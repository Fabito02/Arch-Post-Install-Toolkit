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
OPT_AMD_CPU=false
OPT_INTEL=false
OPT_UNDERVOLT_INTEL=false
OPT_ACER=false
OPT_LOW_RES=false
OPT_EDID=false
OPT_SWAP=false
OPT_HIBERNATION=false

help() {
    echo -e "${BLUE}» Uso do script pós-instalação Arch Linux${NC}"
    echo
    echo "  -n,  --nvidia             Instala drivers proprietários NVIDIA"
    echo "  -am, --amd-cpu            Aplica configurações para CPUs AMD"
    echo "  -i,  --intel              Aplica configurações para CPUs Intel"
    echo "  -uv, --undervolt-intel    Aplica undervolt em CPUs Intel"
    echo "  -a,  --acer               Aplica configurações e instala dependências para dispositivos Acer"
    echo "  -lr, --low-res            Ajusta cursor e UI para telas menores"
    echo "  -e,  --edid               Aplica EDID customizado via cmdline do kernel"
    echo "  -s,  --swap               Configura arquivo de Swap"
    echo "  -hb, --hibernation        Ativa suporte a hibernação"
    echo "  -h,  --help               Exibe esta ajuda"
    echo
    echo "  Exemplo: ./script.sh -n -am -s -hb"
    exit 0
}

DETECTED_CPU=""
if grep -q "AuthenticAMD" /proc/cpuinfo; then
    DETECTED_CPU="amd"
elif grep -q "GenuineIntel" /proc/cpuinfo; then
    DETECTED_CPU="intel"
fi

if [ "$#" -eq 0 ]; then
    sleep 0.2
    clear

    echo -e "${BLUE}» Modo interativo${NC}"
    echo "  's' para sim, Enter para pular"
    echo

    read -p "  · Drivers proprietários NVIDIA? (s/N): " resp
    [[ "$resp" =~ ^[SsYy]$ ]] && OPT_NVIDIA=true

    if [ "$DETECTED_CPU" = "amd" ]; then
        read -p "  · Configurações para CPU AMD? (s/N): " resp
        [[ "$resp" =~ ^[SsYy]$ ]] && OPT_AMD_CPU=true
    elif [ "$DETECTED_CPU" = "intel" ]; then
        read -p "  · Configurações para CPU Intel? (s/N): " resp
        [[ "$resp" =~ ^[SsYy]$ ]] && OPT_INTEL=true

        read -p "  · Undervolt para CPU Intel? (s/N): " resp
        [[ "$resp" =~ ^[SsYy]$ ]] && OPT_UNDERVOLT_INTEL=true
    else
        read -p "  · Configurações para CPU AMD? (s/N): " resp
        [[ "$resp" =~ ^[SsYy]$ ]] && OPT_AMD_CPU=true

        read -p "  · Configurações para CPU Intel? (s/N): " resp
        [[ "$resp" =~ ^[SsYy]$ ]] && OPT_INTEL=true

        if [ "$OPT_INTEL" = true ]; then
            read -p "  · Undervolt para CPU Intel? (s/N): " resp
            [[ "$resp" =~ ^[SsYy]$ ]] && OPT_UNDERVOLT_INTEL=true
        fi
    fi

    read -p "  · Ajustes para dispositivos Acer? (s/N): " resp
    [[ "$resp" =~ ^[SsYy]$ ]] && OPT_ACER=true

    read -p "  · Cursor e UI para telas menores? (s/N): " resp
    [[ "$resp" =~ ^[SsYy]$ ]] && OPT_LOW_RES=true

    read -p "  · Aplicar EDID customizado? (s/N): " resp
    [[ "$resp" =~ ^[SsYy]$ ]] && OPT_EDID=true

    read -p "  · Configurar arquivo de Swap? (s/N): " resp
    [[ "$resp" =~ ^[SsYy]$ ]] && OPT_SWAP=true

    read -p "  · Ativar suporte a hibernação? (s/N): " resp
    [[ "$resp" =~ ^[SsYy]$ ]] && OPT_HIBERNATION=true

    echo
else
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -n|--nvidia) OPT_NVIDIA=true ;;
            -am|--amd-cpu) OPT_AMD_CPU=true ;;
            -i|--intel) OPT_INTEL=true ;;
            -uv|--undervolt-intel) OPT_UNDERVOLT_INTEL=true ;;
            -a|--acer) OPT_ACER=true ;;
            -lr|--low-res) OPT_LOW_RES=true ;;
            -e|--edid) OPT_EDID=true ;;
            -s|--swap) OPT_SWAP=true ;;
            -hb|--hibernation) OPT_HIBERNATION=true ;;
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
    echo "  1) Atual   (nvidia-open-dkms)"
    echo "  2) Legado  (nvidia-580xx-dkms)"
    read -p "  · Versão (1/2): " nv_escolha

    case "$nv_escolha" in
        1) NVIDIA_PKGS=(nvidia-open-dkms nvidia-utils lib32-nvidia-utils nvidia-settings nvidia-prime) ;;
        2) NVIDIA_PKGS=(nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils nvidia-580xx-settings nvidia-prime) ;;
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

SWAP_VAL=""
if [ "$OPT_SWAP" = true ]; then
    echo -e "\n${BLUE}» Swapfile${NC}"
    read -t 20 -p "  · Tamanho em GB (ex: 20), Enter para cancelar: " SWAP_VAL || SWAP_VAL=""

    if [[ ! "$SWAP_VAL" =~ ^[0-9]+$ ]]; then
        echo "  · Valor inválido, criação do arquivo de Swap cancelada."
        SWAP_VAL=""
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
    base-devel dracut systemd-ukify pacman-contrib adw-gtk-theme
    discord btop steam gamemode mangohud ryujinx resources
    android-tools scrcpy faugus-launcher snes9x dolphin-emu
    qbittorrent impression flatpak firefoxpwa firefox telegram-desktop
    lact gparted dconf-editor gdm-settings zed ghostty ufw linux-zen
    linux-zen-headers noto-fonts-cjk noto-fonts-emoji paru zsh zsh-completions
    switcheroo-control zsh-syntax-highlighting zsh-autosuggestions zram-generator
    npm ffmpegthumbnailer plymouth fastfetch tuned tuned-ppd
    bibata-cursor-theme pamac bazaar fuse zen-browser chromium lsfg-vk eden-git
    extension-manager refine supertuxkart libgda6 geary github-cli
    ghostty-nautilus gnome-boxes amberol mangojuice fractal newsflash
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
    gnome-shell-extension-valent-git cemu-bin morewaita-icon-theme-git pcsx2-latest-bin
    pacman-hook-kernel-install dmemcg-booster gnome-vram-booster
)

if [ ${#NVIDIA_PKGS[@]} -gt 0 ]; then
    PKGS_PACMAN+=("${NVIDIA_PKGS[@]}")
fi

if [ "$OPT_INTEL" = true ]; then
    PKGS_PACMAN+=(intel-media-driver)
fi

if [ "$OPT_UNDERVOLT_INTEL" = true ]; then
    PKGS_PACMAN+=(intel-undervolt)
fi

if [ "$OPT_ACER" = true ]; then
    PKGS_AUR+=(acer-wmi-battery-dkms linuwu-sense-dkms-git)
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
paru -Syu --needed --noconfirm "${PKGS_AUR[@]}"

echo -e "\n${BLUE}» Removendo aplicativos não utilizados${NC}"
INSTALLED=$(pacman -Qq decibels showtime gnome-music gnome-console epiphany gnome-software gnome-weather yelp gnome-system-monitor gnome-user-docs gnome-tour htop 2>/dev/null || true)

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
cat << 'EOF' > "$HOME/.config/ghostty/config.ghostty"
theme = light:Adwaita,dark:Adwaita Dark
font-size = 10.6
font-family = Adwaita Mono Regular
window-padding-x = 8
window-height = 28
window-width = 84
gtk-titlebar-style = tabs
gtk-wide-tabs = false
gtk-custom-css = ~/.config/ghostty/styles.css
background-opacity = 1
alpha-blending = native
background-opacity = 0
EOF

cat << 'EOF' > "$HOME/.config/ghostty/styles.css"
/* Suporte ao tema tinted da extensão GNOME ChromaLeon */
@import url("file://~/.config/gtk-4.0/custom-accent.css");

window {
    background: mix(@view_bg_color, transparent, 0.1);
    backdrop-filter: blur(20px);
}

revealer.raised.top-bar {
    box-shadow: none;
    border: none;
}

toolbarview > revealer,
windowhandle,
toolbarview,
toolbarview > overlay,
tabthumbnail > box > overlay > overlay {
    background-color: transparent;
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
cat << 'EOF' | sudo tee /etc/systemd/zram-generator.conf > /dev/null
[zram0]
zram-size = ram
compression-algorithm = zstd
swap-priority = 100
EOF

if [ -n "$SWAP_VAL" ]; then
    echo -e "\n${BLUE}» Configurando Swap${NC}"
    if grep -qw "/swapfile" /proc/swaps; then
        echo "  · /swapfile já está em uso pelo sistema. Ignorando criação."
    elif [ -f /swapfile ]; then
        echo "  · /swapfile já existe no disco. Ignorando criação."
    else
        echo "  · Criando /swapfile (${SWAP_VAL}GB, NoCoW)..."
        sudo swapoff /swapfile 2>/dev/null || true
        sudo rm -f /swapfile

        sudo touch /swapfile
        sudo chattr +C /swapfile 2>/dev/null || true
        sudo dd if=/dev/zero of=/swapfile bs=1M count=$((SWAP_VAL * 1024)) status=progress
        sudo chmod 600 /swapfile
        sudo mkswap -U clear /swapfile
    fi

    if ! grep -q "^/swapfile" /etc/fstab; then
        echo "  · Registrando /swapfile no /etc/fstab"
        echo "/swapfile none swap defaults,pri=10 0 0" | sudo tee -a /etc/fstab > /dev/null
    fi

    sudo swapon --all 2>/dev/null || true
fi

if [ "$OPT_HIBERNATION" = true ]; then
    echo -e "\n${BLUE}» Configuração da Hibernação${NC}"

    if [ ! -f /swapfile ]; then
        echo -e "  ${RED}✘ Erro: /swapfile não encontrado. Hibernação requer Swapfile.${NC}"
        exit 1
    fi

    echo "w /sys/power/image_size - - - - 0" | sudo tee /etc/tmpfiles.d/hibernation.conf > /dev/null
    sudo systemd-tmpfiles --create /etc/tmpfiles.d/hibernation.conf > /dev/null 2>&1 || true

    SWAP_UUID=$(findmnt -no UUID -T /swapfile 2>/dev/null || true)
    SWAP_OFFSET=$(sudo btrfs inspect-internal map-swapfile -r /swapfile 2>/dev/null || true)

    if [ -z "$SWAP_UUID" ] || [ -z "$SWAP_OFFSET" ]; then
        echo -e "  ${RED}✘ Erro: UUID ou Offset não puderam ser identificados.${NC}"
        exit 1
    fi
fi

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

echo "  · Configurando Otimização de VRAM (dmemcg-booster)"
sudo systemctl enable --now dmemcg-booster-system.service
systemctl --user enable --now dmemcg-booster-user.service
sudo systemctl enable --now gnome-vram-booster.service

if [ "$OPT_NVIDIA" = true ] || pacman -Qs nvidia > /dev/null 2>&1; then
    echo "  · Ativando serviços de preservação de memória da NVIDIA"
    sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service > /dev/null 2>&1

    sudo mkdir -p /etc/modprobe.d
    echo "options nvidia NVreg_PreserveVideoMemoryAllocations=1" | sudo tee /etc/modprobe.d/nvidia-power-management.conf > /dev/null
    echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
fi

sudo sed -i 's/.*SystemMaxUse=.*/SystemMaxUse=100M/' /etc/systemd/journald.conf
sudo systemctl restart systemd-journald

sudo systemctl enable --now switcheroo-control.service tuned bluetooth fstrim.timer cups systemd-oomd.service paccache.timer > /dev/null 2>&1

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

echo -e "\n${BLUE}» Bootloader${NC}"

if pacman -Qs mkinitcpio > /dev/null; then
    echo "  · Removendo mkinitcpio"
    sudo pacman -Rns --noconfirm mkinitcpio
fi

sudo mkdir -p /etc/pacman.d/hooks
sudo ln -sf /dev/null /etc/pacman.d/hooks/90-dracut-install.hook
sudo ln -sf /dev/null /etc/pacman.d/hooks/60-dracut-remove.hook

sudo mkdir -p /etc/kernel /etc/dracut.conf.d

CMDLINE="quiet splash"
[ "$OPT_INTEL" = true ] && CMDLINE="intel_pstate=passive $CMDLINE"
[ "$OPT_NVIDIA" = true ] && CMDLINE="$CMDLINE nvidia_drm.modeset=1"
[ -n "$EDID_CMDLINE" ] && CMDLINE="$CMDLINE $EDID_CMDLINE"

if [ "$OPT_HIBERNATION" = true ] && [ -n "$SWAP_UUID" ] && [ -n "$SWAP_OFFSET" ]; then
    CMDLINE="$CMDLINE resume=UUID=$SWAP_UUID resume_offset=$SWAP_OFFSET"
fi

echo "$CMDLINE" | sudo tee /etc/kernel/cmdline > /dev/null

cat << 'EOF' | sudo tee /etc/kernel/install.conf > /dev/null
layout=uki
initrd_generator=dracut
uki_generator=ukify
EOF

DRIVERS=""
[ "$OPT_INTEL" = true ] && DRIVERS+=" i915"
[ "$OPT_AMD_CPU" = true ] && DRIVERS+=" amdgpu"

{
    echo 'hostonly="yes"'
    echo 'compress="zstd"'
    if [ "$OPT_HIBERNATION" = true ]; then
        echo 'add_dracutmodules+=" plymouth resume "'
    else
        echo 'add_dracutmodules+=" plymouth "'
    fi
    [ -n "$DRIVERS" ] && echo "add_drivers+=\"${DRIVERS} \""
    if [ "$OPT_NVIDIA" = true ]; then
        echo 'omit_drivers+=" nvidia nvidia_drm nvidia_modeset nvidia_uvm "'
    fi
    [ -n "$EDID_ITEM" ] && echo "install_items+=\"${EDID_ITEM}\""
} | sudo tee /etc/dracut.conf.d/arch.conf > /dev/null

echo "  · Limpando artefatos legados de /boot"
sudo find /boot -maxdepth 1 -type f \
    \( -name 'vmlinuz-*' -o -name 'initramfs-*.img' \) \
    -delete 2>/dev/null || true

sudo find /boot/EFI/Linux -type f -name '*.efi' -delete 2>/dev/null || true
sync

KERNELS=$(ls /usr/lib/modules | wc -l)
REQUIRED_MB=$((KERNELS * 250))
AVAILABLE_MB=$(df -BM --output=avail /boot | tail -1 | tr -dc '0-9')

if [ "$AVAILABLE_MB" -lt "$REQUIRED_MB" ]; then
    echo -e "${RED}! /boot com ${AVAILABLE_MB}MB livres, ~${REQUIRED_MB}MB necessários${NC}"
    sudo du -sh /boot/* 2>/dev/null | sort -rh | head -5 | sed 's/^/    /'
    exit 1
fi

echo "  · Gerando imagens para $KERNELS kernel(s)"
sudo kernel-install add-all 2>&1 | grep -vE "SBAT|Wrote unsigned|does not contain" || true

UKI_COUNT=$(sudo find /boot/EFI/Linux -maxdepth 1 -type f -name '*.efi' 2>/dev/null | wc -l)

if [ "$UKI_COUNT" -ne "$KERNELS" ]; then
    echo -e "${RED}! Esperados $KERNELS, encontrados $UKI_COUNT${NC}"
    exit 1
fi

echo "  · Processo concluído ($UKI_COUNT gerados)"

FIRST_UKI=$(sudo find /boot/EFI/Linux -maxdepth 1 -type f -name '*.efi' 2>/dev/null | head -1)
if [ -n "$FIRST_UKI" ] && ! sudo objdump -s -j .cmdline "$FIRST_UKI" 2>/dev/null | grep -q "quiet"; then
    echo -e "${RED}! Aviso: cmdline pode não ter sido embutida corretamente${NC}"
fi

echo -e "\n${BLUE}» Systemd-boot Timeout${NC}"
sudo sh -c 'mkdir -p /boot/loader && touch /boot/loader/loader.conf && sed -i -E "/^#?\s*timeout/d" /boot/loader/loader.conf && echo "timeout 0" >> /boot/loader/loader.conf'
echo "  · Timeout definido para 0 em /boot/loader/loader.conf"

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
