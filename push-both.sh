#!/bin/bash

# Script de synchronisation pour deux dépôts distants

# 1. D'abord pousser les changements vers GitHub
echo "Pushing les changements vers GitHub..."
# Ajouter tous les nouveaux fichiers
git add .

# Vérifier ce qui va être commité
git status

# Committer
git commit -m "Ajout des nouveaux fichiers"

git push origin HEAD

# Configuration
GITHUB_REPO="origin"
GITLAB_REPO="gitlab"
CURRENT_BRANCH=$(git symbolic-ref --short HEAD)

echo "Démarrage de la synchronisation"

# Vérifier si le push a réussi
if [ $? -ne 0 ]; then
    echo "ERREUR: Échec du push vers GitHub. Abandon."
    exit 1
fi

# 2. Synchroniser GitLab avec GitHub
echo "Synchronisation de GitLab avec GitHub..."

# Sauvegarder votre travail local (au cas où)
echo "Sauvegarde de votre travail local..."
git stash

# Récupérer les derniers changements de GitHub
echo "Récupération depuis GitHub..."
git fetch $GITHUB_REPO

# Réinitialiser pour correspondre à GitHub
echo "Réinitialisation pour correspondre à GitHub..."
git reset --hard $GITHUB_REPO/$CURRENT_BRANCH

# Forcer le push vers GitLab
echo "Envoi forcé vers GitLab..."
git push --force $GITLAB_REPO $CURRENT_BRANCH

# Vérifier si le push vers GitLab a réussi
if [ $? -ne 0 ]; then
    echo "ERREUR: Échec du push vers GitLab."
    echo "Restauration des changements locaux..."
    git stash pop
    exit 1
fi

# Restaurer votre travail local
echo "Restauration de votre travail local..."
git stash pop

echo "Synchronisation terminée! Les deux dépôts sont maintenant identiques."