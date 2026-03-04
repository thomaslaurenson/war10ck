#!/bin/bash

set -euo pipefail

sudo apt-get update
sudo apt install openjdk-21-jdk -y
sudo update-alternatives --config java
