#!/bin/bash


GO_VERSION="1.23.0"
GO_ARCHIVE="go$GO_VERSION.linux-amd64.tar.gz"

sudo rm -rf /usr/local/go
wget https://go.dev/dl/$GO_ARCHIVE
sudo tar -C /usr/local -xzf $GO_ARCHIVE
rm $GO_ARCHIVE

# Export golang path
if ! grep "# GOLANG PATH" ~/.bashrc > /dev/null; then
    {
        echo -e "\n# GOLANG PATH"
        echo "export PATH=$PATH:/usr/local/go/bin"
    }  >> ~/.bashrc
fi
