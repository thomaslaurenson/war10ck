#!/bin/bash


packagelist=(
    vim
    wget
    curl
    tree
    gh
    jq
)
sudo apt -y install "${packagelist[@]}"
