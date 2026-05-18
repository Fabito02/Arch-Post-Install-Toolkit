#!/bin/bash

set -e

sudo -v

if [ "$EUID" -eq 0 ]; then
  echo "Execute o script como usuário comum."
  exit 1
fi

VERDE='\033[0;32m'
NC='\033[0m'
MK_CONF="/etc/mkinitcpio.conf"
LOADER_DIR="/boot/loader/entries"
CACHE="$HOME/.cache/script_arch"
PAMAC_RULE_PATH="/etc/polkit-1/rules.d/99-pamac.rules"
TEMPLATE_DIR=$(xdg-user-dir TEMPLATES)


rm -rf "$CACHE"
mkdir -p "$CACHE"

PKGS_PACMAN=(
    base-devel adw-gtk-theme discord btop steam gamemode mangohud ryujinx 
    android-tools scrcpy faugus-launcher pcsx2 snes9x dolphin-emu 
    cemu drawing telegram-desktop qbittorrent impression flatpak
    lact gparted dconf-editor gdm-settings zed ghostty ufw
    nvidia-580xx-utils nvidia-580xx-dkms lib32-nvidia-580xx-utils 
    nvidia-580xx-settings linux-zen-headers firefoxpwa
    noto-fonts-cjk noto-fonts-emoji paru zsh zsh-completions 
    switcheroo-control zsh-syntax-highlighting zsh-autosuggestions 
    npm ffmpegthumbnailer plymouth fastfetch 
    bibata-cursor-theme pamac bazaar fuse zen-browser chromium lsfg-vk eden-git 
    extension-manager refine supertuxkart libgda6 geary github-cli endeavour
    ghostty-nautilus valent-git gnome-boxes amberol mangojuice
)

PKGS_FLATPAK=(
    io.gitlab.theevilskeleton.Upscaler org.onlyoffice.desktopeditors 
    org.gnome.gitlab.somas.Apostrophe org.vinegarhq.Sober 
    io.mrarm.mcpelauncher com.dec05eba.gpu_screen_recorder 
    com.cassidyjames.clairvoyant io.github.jeffshee.Hidamari 
    com.vysp3r.ProtonPlus it.mijorus.gearlever com.github.tchx84.Flatseal 
    org.nickvision.tubeconverter io.github.vikdevelop.SaveDesktop 
    net.sourceforge.wxEDID io.missioncenter.MissionCenter 
    io.github.diegopvlk.Cine io.github.amit9838.mousam 
    io.github.tobagin.karere com.pojtinger.felicitas.Sessions
    io.github.nozwock.Packet io.github.fabrialberio.pinapp
)

PKGS_AUR=(
    gnome-shell-extension-valent-git
)

echo -e "${VERDE}Configurando Chaotic-AUR...${NC}"
sudo pacman -S git --noconfirm

if ! pacman -Qi chaotic-keyring &> /dev/null; then
    cd "$CACHE"
    git clone https://github.com/SharafatKarim/chaotic-AUR-installer.git
    cd chaotic-AUR-installer && chmod +x install.bash && sudo ./install.bash
    cd "$CACHE"
fi

echo -e "${VERDE}Atualizando sistema e instalando pacotes pacman e aur...${NC}"
sudo pacman -Syu --needed --noconfirm "${PKGS_PACMAN[@]}"

echo -e "${VERDE}Instalando pacotes Flatpak...${NC}"
flatpak install flathub "${PKGS_FLATPAK[@]}" -y

echo -e "${VERDE}Instalando pacotes AUR...${NC}"
paru -S --needed --noconfirm "${PKGS_AUR[@]}"

echo -e "${VERDE}Removendo aplicativos não utilizados...${NC}"
APPS_INSTALADOS=$(pacman -Qq decibels showtime gnome-music gnome-console epiphany gnome-software gnome-weather yelp gnome-user-docs gnome-tour htop 2>/dev/null || true)

if [ -n "$APPS_INSTALADOS" ]; then
    echo "$APPS_INSTALADOS" | sudo pacman -Rns - --noconfirm
else
    echo " -> Nenhum dos aplicativos alvos está instalado. Pulando remoção."
fi

if [ -f "$HOME/.local/share/applications/org.gnome.Extensions.desktop" ]; then
    echo "O Gnome Extensions já está oculto."
else
    mkdir -p "$HOME/.local/share/applications/"
    cp /usr/share/applications/org.gnome.Extensions.desktop "$HOME/.local/share/applications/"
    echo "NoDisplay=true" >> "$HOME/.local/share/applications/org.gnome.Extensions.desktop"
fi

echo -e "${VERDE}Configurando Ghostty...${NC}"
mkdir -p "$HOME/.config/ghostty"
cat << 'EOF' > "$HOME/.config/ghostty/config"
theme = light:Adwaita,dark:Adwaita Dark
font-size = 11
window-padding-x = 8
window-height = 24
window-width = 70
gtk-titlebar-style = tabs
gtk-wide-tabs = false
gtk-custom-css = ./styles.css
background-opacity = 1
alpha-blending = native
EOF

cat << 'EOF' > "$HOME/.config/ghostty/styles.css"
revealer.raised.top-bar { 
    background: alpha(@view_bg_color, 1); 
    box-shadow: none; 
}
EOF

echo -e "${VERDE}Configurando ZSH (Pure, History, Plugins)...${NC}"
sudo chsh -s "$(which zsh)" "$USER"
mkdir -p "$HOME/.zsh"
if [ ! -d "$HOME/.zsh/pure" ]; then
    git clone https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"
fi

cat << 'EOF' > "$HOME/.zshrc"
# Histórico
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt sharehistory
setopt hist_ignore_dups
setopt hist_ignore_space

# Pure Prompt
fpath+=$HOME/.zsh/pure
autoload -U promptinit; promptinit
prompt pure

# Autocomplete (ZSH completions)
autoload -Uz compinit
compinit

# Plugins
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
EOF

echo -e "${VERDE}Habilitando serviços...${NC}"
sudo systemctl enable --now switcheroo-control.service

echo -e "${VERDE}Configurando temas Flatpak e overrides...${NC}"
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

echo -e "${VERDE}Instalando Lucidglyph...${NC}"
cd "$CACHE"
git clone --depth 1 https://github.com/maximilionus/lucidglyph
cd lucidglyph && sudo ./lucidglyph.sh install
cd "$CACHE"

echo -e "${VERDE}Configurando UFW e KDE Connect...${NC}"
sudo systemctl enable --now ufw.service

sudo ufw allow 1714:1764/udp
sudo ufw allow 1714:1764/tcp

sudo ufw --force enable

echo -e "${VERDE}Configurando tamanho do cursor e tema Bibata Modern Classic${NC}"
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
gsettings set org.gnome.desktop.interface cursor-size 20

echo -e "${VERDE}Instalando Plymouth e configurando intel_pstate${NC}"
sudo sed -Ei '/^HOOKS=/ { /plymouth/! s/(udev)/\1 plymouth/ }' "$MK_CONF"

if [ -d "$LOADER_DIR" ]; then
    for conf in "$LOADER_DIR"/*.conf; do
        [ -f "$conf" ] && grep -q "^options" "$conf" || continue

        grep -q "intel_pstate=passive" "$conf"  || sudo sed -i '/^options/ s/$/ intel_pstate=passive/' "$conf"
        grep -q "quiet" "$conf"  || sudo sed -i '/^options/ s/$/ quiet/' "$conf"
        grep -q "splash" "$conf" || sudo sed -i '/^options/ s/$/ splash/' "$conf"
        
        echo " -> Configurado: $(basename "$conf")"
    done
else
    echo "Diretório $LOADER_DIR não encontrado. Pulando bootloader."
fi

echo -e "${VERDE}Instalando o tema Plymouth${NC}"
paru -S --noconfirm plymouth-theme-arch-darwin
sudo plymouth-set-default-theme -R arch-darwin

echo -e "${VERDE}Habilitando NTSYNC (Para jogos Windows via Proton/Wine)${NC}"
echo "ntsync" | sudo tee /etc/modules-load.d/ntsync.conf

echo -e "${VERDE}Configurando Polkit rule para Pamac${NC}"
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


echo -e "${VERDE}Criando arquivos modelo...${NC}"

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

    echo " -> Modelos criados com sucesso em: $TEMPLATE_DIR"
else
    echo "Aviso: Pasta de modelos não encontrada pelo XDG. Pulando."
fi

echo -e "${VERDE}Limpando arquivos temporários...${NC}"
rm -rf "$CACHE"

echo -e "${VERDE}------------------------------------------${NC}"
echo "Instalação finalizada."
read -p "Deseja reiniciar o sistema? (s/n): " resposta

if [[ "$resposta" =~ ^[Ss]$ ]]; then
    systemctl reboot
fi
