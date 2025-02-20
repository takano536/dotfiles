#!/bin/bash
set -e

reload_profile () {
    current_shell=$(ps -p $$ | tail +2 | awk '{print $NF}')
    if [ $current_shell = 'bash' ]; then
        source ~/.bashrc
    elif [ $current_shell = 'zsh' ]; then
        source ~/.zshenv; source $ZDOTDIR/.zshrc
    fi
}

sudo apt update && sudo apt upgrade -y

# install apps
apps=(
    git
    curl
    zsh
    fish
    gpg
    build-essential
    gdb
    libssl-dev
    zlib1g-dev
    libbz2-dev
    libreadline-dev
    libsqlite3-dev
    libncursesw5-dev
    xz-utils
    tk-dev
    libxml2-dev
    libxmlsec1-dev
    libffi-dev
    liblzma-dev
    software-properties-common
)
for app in ${apps[@]}; do
    if ! type $app > /dev/null 2>&1; then sudo apt install -y $app; fi
done

# clone dotfiles
if [ ! -d ~/.config ]; then
    git clone https://github.com/takano536/dotfiles ~/.config
fi

# link profiles
profiles=(
    ~/.config/bash/.bashrc
    ~/.config/bash/.bash_profile
    ~/.config/bash/.bash_logout
    ~/.config/zsh/.zshenv
)
for profile in ${profiles[@]}; do
    ln -sf $profile ~/
done

# reload profile
reload_profile

# install asdf
if [ ! -d "$XDG_DATA_HOME/asdf" ]; then
    git clone https://github.com/asdf-vm/asdf.git $XDG_DATA_HOME/asdf
    reload_profile
fi

# install asdf plugins
plugins=(
    python
)
for plugin in ${plugins[@]}; do
    asdf plugin add $plugin
done

# install asdf python
vers=(
    3.11.4
    3.10.6
)
globalver=3.11.4
for ver in ${vers[@]}; do
    asdf install python $ver
done
asdf global python $globalver

# install eza
if ! type eza > /dev/null 2>&1; then
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt update
    sudo apt install -y eza
fi

# install neovim
if ! type nvim > /dev/null 2>&1; then
    curl -LOsS https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
    sudo rm -rf /opt/nvim
    sudo tar -C /opt -xzf nvim-linux64.tar.gz
    rm -f nvim-linux64.tar.gz
    git clone --depth 1 https://github.com/wbthomason/packer.nvim $XDG_DATA_HOME/nvim/site/pack/packer/start/packer.nvim
fi

# install starship
if ! type starship > /dev/null 2>&1; then
    curl -fsSL https://starship.rs/install.sh | sh
    reload_profile
fi

echo 'Done! Please enter [ chsh $USER -s $(which zsh) ] to change your shell to zsh. Then, restart your terminal.'
