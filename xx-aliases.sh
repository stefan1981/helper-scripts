#!/bin/bash

# general
alias vim="nvim"
alias watch='watch -n 1 -c '

# xx
alias xx-zshrc='nvim ~/.zshrc'
alias xx-source='source ~/.zshrc'
alias xx-zsh-refresh='source ~/.zshrc; echo "Info: zsh refreshed"'


# docker
alias xx-dp="docker ps"                                                                                              
alias xx-dp2='watch -n 1 "docker ps --format \"table {{.ID}}\t{{.Names}}\t{{.Ports}}\""'
alias xx-dcu="docker compose up -d"                         
alias xx-dcd="docker compose down"  

# kubernetes
alias k='kubectl "--context=${KUBECTL_CONTEXT:-$(kubectl config current-context)}"'
alias kshow='watch -n 1 /bin/bash ~/docs/script-hub/k8/show-ressources-from-current-namespace.sh'
alias kdesc='watch -n 1 /bin/bash ~/docs/script-hub/k8/show-pod-description.sh'
alias kresources='kubectl resource-capacity'

# cheat-cheat
xx-cheat() {
    clear; echo "----------------------------------------------"
    curl cht.sh/$1 | less
}

