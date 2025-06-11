#!/bin/bash


cd "$(dirname "$0")" || exit 1

LATEST_TAG=$(git tag --sort=-v:refname | head -n 1)
echo "[*] Existing tag: $LATEST_TAG"

read -rp "[*] Enter new tag: v" VERSION

echo "[*] Proposed version: $VERSION"

read -rp "[*] Tag and Release? (y/N) " yn
case $yn in
	y ) git tag v"$VERSION";
        git push --tags;
        exit 0;;
	n ) echo "[*] Exiting...";
		exit 0;;
	* ) echo "[*] Invalid response... Exiting";
        exit 1;;
esac
