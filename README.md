# Arch Post-Install Toolkit

O **Arch Post-Install Toolkit** é uma ferramenta de automação projetada para otimizar, configurar e preparar ambientes Arch Linux recém-instalados. O foco é reduzir o tempo de configuração inicial, aplicando ajustes de performance, segurança e personalização de interface de forma modular.

## Funcionalidades

* **Otimização de Hardware:** Aplicação de undervolt em processadores Intel e parâmetros de kernel.
* **Automação de Drivers:** Instalação modular de drivers proprietários NVIDIA ou otimizações específicas para hardware Intel.
* **Hardening & Segurança:** Configuração automática do UFW (Firewall) e permissões granulares via Polkit para administração do sistema.
* **Experiência de Usuário:** Setup completo de ZSH, Ghostty e adw-gtk3, modelos de aquivos, incluindo instalação de cursores Bibata e fontes.

## Requisitos

* Arch Linux
* Acesso à internet para instalação de pacotes

## Uso

```bash
git clone https://github.com/Fabito02/Arch-Post-Install-Toolkit
cd Arch-Post-Install-Toolkit
chmod +x script_archlinux.sh

```

Execute com as opções desejadas:

```bash
./script_archlinux.sh -n -i -lr      # Instala drivers Nvidia, otimiza Intel e aplica low-res
./script_archlinux.sh -uv            # Aplica undervolt (requer testes prévios)
./script_archlinux.sh -h             # Mostra todas as opções disponíveis

```

> [!NOTE]
> Este projeto está em estágio **funcional**. Embora as principais rotinas de automação estejam testadas, recomenda-se realizar um backup do sistema antes de aplicar configurações de hardware como undervolt ou alterações no bootloader. Não sou responsável por eventuais danos ao seu hardware ou software.
> 
> Algumas configurações e escolhas foram pensadas com foco em meu workflow pessoal. Recomenda-se que seja feita uma revisão, para evitar possíveis bloatwares ou ajustes indesejados ao seu sistema.
