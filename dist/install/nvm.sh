#!/bin/bash


NVM_VERSION="0.40.3"
wget -qO- "https://raw.githubusercontent.com/nvm-sh/nvm/v$NVM_VERSION/install.sh" | bash

. "$HOME/.nvm/nvm.sh"
nvm install 18
nvm install 20
nvm use 20
nvm alias default 20

npm install -g npm@latest
npm install -g npm-check@latest

nvm --version
node --version
npm --version
