#!/bin/bash


GO_VERSION="1.24.4"
GO_ARCHIVE="go$GO_VERSION.linux-amd64.tar.gz"

sudo rm -rf /usr/local/go
wget https://go.dev/dl/$GO_ARCHIVE
sudo tar -C /usr/local -xzf $GO_ARCHIVE
rm $GO_ARCHIVE

sudo ln -sf /usr/local/go/bin/go /usr/local/bin/go
