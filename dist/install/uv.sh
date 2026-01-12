#!/bin/bash


UV_VERSION="0.9.24"
curl -LsSf https://astral.sh/uv/$UV_VERSION/install.sh | sh
uv self version
