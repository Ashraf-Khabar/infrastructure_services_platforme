#!/bin/bash

GITHUB_REPO="origin"
GITLAB_REPO="gitlab"
CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")

check_connectivity() {
    echo "Vérification de la connectivité..."
    
    if ! ping -c 1 -W 2 github.com >/dev/null 2>&1; then
        echo "ERREUR: Impossible de joindre github.com"
        return 1
    fi
    
    if ! ping -c 1 -W 2 gitlab.com >/dev/null 2>&1; then
        echo "ERREUR: Impossible de joindre gitlab.com"
        return 1
    fi
    
    echo "Connectivité OK"
    return 0
}

push_with_retry() {
    local repo=$1
    local branch=$2
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        echo "Tentative $(($retry_count + 1))/$max_retries de push vers $repo..."
        git push $repo $branch
        if [ $? -eq 0 ]; then
            echo "Push vers $repo réussi!"
            return 0
        fi
        retry_count=$((retry_count + 1))
        echo "Échec, nouvelle tentative dans 5 secondes..."
        sleep 5
    done
    
    echo "ERREUR: Échec du push vers $repo après $max_retries tentatives"
    return 1
}

if ! check_connectivity; then
    echo "Problème de réseau détecté. Vérifiez votre connexion Internet."
    echo "Vous pouvez essayer:"
    echo "1. Redémarrer votre routeur"
    echo "2. Changer de réseau Wi-Fi"
    echo "3. Vérifier les paramètres DNS"
    exit 1
fi

echo "Pushing les changements vers GitHub..."
git add .

echo "Status actuel:"
git status --short

if git diff --cached --quiet; then
    echo "Aucun changement à committer."
else
    git commit -m "Ajout des nouveaux fichiers - $(date '+%Y-%m-%d %H:%M:%S')"
fi

if ! push_with_retry $GITHUB_REPO $CURRENT_BRANCH; then
    echo "ERREUR: Échec du push vers GitHub après plusieurs tentatives."
    echo "Vérifiez votre accès SSH/GitHub:"
    echo "ssh -T git@github.com"
    exit 1
fi

echo "Synchronisation de GitLab avec GitHub..."

echo "Sauvegarde de votre travail local..."
git stash

echo "Récupération depuis GitHub..."
git fetch $GITHUB_REPO

echo "Réinitialisation pour correspondre à GitHub..."
git reset --hard $GITHUB_REPO/$CURRENT_BRANCH

if ! push_with_retry $GITLAB_REPO $CURRENT_BRANCH; then
    echo "ERREUR: Échec du push vers GitLab après plusieurs tentatives."
    echo "Restauration des changements locaux..."
    git stash pop
    echo "Vérifiez votre configuration GitLab:"
    echo "git remote -v"
    exit 1
fi

echo "Restauration de votre travail local..."
git stash pop

echo "Synchronisation terminée! Les deux dépôts sont maintenant identiques."