#!/bin/bash


alias xx-zsh-refresh='source ~/.zshrc; echo "Info: zsh refreshed"'

alias xx-docker-ps='watch -n 1 "docker ps --format \"table {{.ID}}\t{{.Names}}\t{{.Ports}}\""'

alias xx-compose-get-urls="cat compose.yml | grep Host"
