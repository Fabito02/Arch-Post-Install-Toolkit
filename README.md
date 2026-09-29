# Arch Post-Install Toolkit

O **Arch Post-Install Toolkit** é uma ferramenta de automação projetada para otimizar, configurar e preparar ambientes Arch Linux recém-instalados. O foco é reduzir o tempo de configuração inicial, aplicando ajustes de performance, segurança e personalização de interface de forma modular.

## Funcionalidades

* **Otimização de Hardware:** Aplicação de undervolt em processadores Intel e parâmetros de kernel.
* **Automação de Drivers:** Instalação modular de drivers proprietários NVIDIA ou otimizações específicas para hardware Intel.
* **Boot Unificado:** Migração para UKI (Unified Kernel Image) e Dracut (substituindo o `mkinitcpio`).
* **Segurança:** Configuração automática do UFW (Firewall).
* **Rede:** systemd-resolved com DNS-over-TLS e TCP BBR para desempenho.
* **Experiência de Usuário:** Setup completo de ZSH, Ghostty e adw-gtk3, modelos de arquivos, incluindo instalação de cursores Bibata e fontes.
* **EDID Customizado:** Injeção de configuração de monitor através de um EDID previamente configurado (overclock, para uma maior taxa de atualização da tela e outros ajustes avançados).

## Requisitos

* Arch Linux
* systemd-boot
* GNOME
* Acesso à internet para instalação de pacotes

## Uso

```bash
git clone https://github.com/Fabito02/Arch-Post-Install-Toolkit
cd Arch-Post-Install-Toolkit
chmod +x script_archlinux.sh
```

Execute com as opções desejadas:

```bash
./script_archlinux.sh -n -i -lr      # Instala drivers Nvidia, configura Intel e aplica low-res
./script_archlinux.sh -uv            # Aplica undervolt (requer testes prévios)
./script_archlinux.sh -e             # Aplica EDID customizado
./script_archlinux.sh -h             # Mostra todas as opções disponíveis
./script_archlinux.sh                # Instalação interativa
```

> [!NOTE]
> Este projeto está em estágio **funcional** e foi totalmente pensado para meu **uso pessoal**. Embora as principais automações tenham sido testadas, recomenda-se realizar um backup do sistema antes de aplicar configurações de hardware como undervolt ou alterações no bootloader. Não sou responsável por eventuais danos ao seu hardware ou software.
>
> Algumas configurações e escolhas foram pensadas com foco em meu workflow pessoal. Recomenda-se que seja feita uma revisão, para evitar possíveis bloatwares ou ajustes indesejados ao seu sistema.
>
> O script assume uma instalação com **systemd-boot** e **GNOME**. O bootloader será migrado para **UKI geradas pelo Dracut** durante a execução (o `mkinitcpio` é removido e a linha de comando do kernel passa a existir em `/etc/dracut.conf.d/cmdline.conf`).