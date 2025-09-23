#!/bin/zsh

echo "🔹 Uninstalling Firebase CLI (npm)..."
sudo npm uninstall -g firebase-tools 2>/dev/null || true

echo "🔹 Uninstalling Firebase CLI (brew)..."
brew uninstall firebase-cli 2>/dev/null || true

echo "🔹 Deactivating FlutterFire CLI..."
dart pub global deactivate flutterfire_cli 2>/dev/null || true

echo "🔹 Removing cached binaries and configs..."
rm -rf ~/.pub-cache/bin/flutterfire
rm -rf ~/.pub-cache/global_packages/flutterfire_cli
rm -rf ~/.cache/firebase
rm -rf ~/.config/configstore/firebase-tools.json
rm -rf ~/.config/configstore/@google-cloud

# remove PATH line from .zshrc and .bashrc if exists
echo "🔹 Removing PATH export lines from shell configs..."
sed -i '' '/export PATH="\$PATH:\$HOME\/.pub-cache\/bin"/d' ~/.zshrc 2>/dev/null || true
sed -i '' '/export PATH="\$PATH:\$HOME\/.pub-cache\/bin"/d' ~/.bashrc 2>/dev/null || true
sed -i '' '/export PATH="\$PATH:\$HOME\/.pub-cache\/bin"/d' ~/.bash_profile 2>/dev/null || true

# reload zsh config
if [ -f ~/.zshrc ]; then
  source ~/.zshrc
fi

echo "✅ All Firebase-related tools removed successfully."
echo "Check with: which firebase && which flutterfire"

