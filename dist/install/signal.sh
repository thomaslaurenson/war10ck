#!/bin/bash


sudo wget -O- https://updates.signal.org/desktop/apt/keys.asc \
	| gpg --dearmor \
	| sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null

sudo wget -O- https://updates.signal.org/static/desktop/apt/signal-desktop.sources \
	| sudo tee /etc/apt/sources.list.d/signal-desktop.sources > /dev/null

sudo apt update
sudo apt install signal-desktop
