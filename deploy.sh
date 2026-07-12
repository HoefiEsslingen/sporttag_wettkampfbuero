#!/bin/bash
set -e

ZIEL_REPO="../sporttag"
ZIEL_REMOTE="https://github.com/HoefiEsslingen/sporttag.git"

# Sicherstellen, dass das Ziel-Repo existiert und auf die richtige Remote-URL zeigt
if [ -d "$ZIEL_REPO" ]; then
    cd "$ZIEL_REPO"
    AKTUELLE_URL=$(git remote get-url origin)
    if [ "$AKTUELLE_URL" != "$ZIEL_REMOTE" ]; then
        echo "⚠️  Remote-URL zeigt auf falsches Repo ($AKTUELLE_URL). Korrigiere..."
        git remote set-url origin "$ZIEL_REMOTE"
    fi

    echo "🔄 Synchronisiere lokalen Stand mit GitHub (sporttag)..."
    git fetch origin
    git reset --hard origin/main

    cd - > /dev/null
else
    echo "❌ Fehler: Ziel-Repo-Ordner '$ZIEL_REPO' existiert nicht."
    echo "Bitte zuerst 'git clone $ZIEL_REMOTE' im übergeordneten Ordner ausführen."
    exit 1
fi

echo "🔨 Baue Flutter Web App..."
flutter build web --base-href "/sporttag/"

if [ ! -f "build/web/index.html" ]; then
    echo "❌ Fehler: 'build/web/index.html' fehlt. Der Build scheint unvollständig zu sein."
    exit 1
fi

echo "✅ Build erfolgreich und vollständig."

echo "📂 Kopiere Build-Ergebnis in das Ziel-Repo..."
find "$ZIEL_REPO" -mindepth 1 -not -path "$ZIEL_REPO/.git*" -delete
cp -R build/web/. "$ZIEL_REPO"

echo "🚀 Committe und pushe ins Repo sporttag..."
cd "$ZIEL_REPO"
git add .

if git diff --cached --quiet; then
    echo "ℹ️  Keine Änderungen seit dem letzten Deploy – nichts zu committen."
else
    git commit -m "Deploy: $(date '+%Y-%m-%d %H:%M:%S')"
    git push origin main
    echo "✅ Fertig! App live unter: https://HoefiEsslingen.github.io/sporttag/"
fi