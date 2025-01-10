#!/bin/bash


cd "$(dirname "$0")" || exit 1

echo "[*] Existing tag: $(git describe --tags --abbrev=0)"

read -rp "[*] Enter new tag: v" PUB_VERSION

echo "[*] Proposed version: $PUB_VERSION"

read -rp "[*] Tag and Release? (y/N) " yn
case $yn in
	y ) git tag v"$PUB_VERSION";
        git push --tags;
        exit 0;;
	n ) echo "[*] Exiting...";
		exit 0;;
	* ) echo "[*] Invalid response... Exiting";
        exit 1;;
esac
