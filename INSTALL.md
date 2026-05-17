# Installation

Ce document décrit deux installations supportées :

- **Debian/Ubuntu sous WSL** (Windows) — section principale ci-dessous
- **macOS** (Homebrew, Intel ou Apple Silicon) — voir [§ Installation macOS](#installation-macos)

## Pré-requis

Hypothèse visée :
- Windows 11 avec WSLg
- ou Windows 10/11 avec WSL2 et un serveur X déjà configuré

Le frontend est une interface GTK native. Sans affichage graphique côté WSL, `dune exec pascatho` compilera mais ne pourra pas ouvrir la fenêtre.

## 1. Installer les paquets système

Dans le shell Debian/Ubuntu sous WSL :

```bash
sudo apt update
sudo apt install -y \
  build-essential \
  pkg-config \
  git \
  curl \
  unzip \
  m4 \
  bubblewrap \
  libgtk-3-dev \
  libgdk-pixbuf2.0-dev \
  libcairo2-dev \
  libpango1.0-dev \
  libglib2.0-dev
```

## 2. Installer opam

```bash
sudo apt install -y opam
opam init --disable-sandboxing -y
eval "$(opam env)"
```

Si aucun switch OCaml n’existe encore :

```bash
opam switch create . 5.1.1 -y
eval "$(opam env)"
```

## 3. Installer les dépendances OCaml

Le projet utilise Dune, Cmdliner et Yojson.

```bash
opam install . --deps-only -y
eval "$(opam env)"
```

## 4. Compiler

Depuis la racine du dépôt :

```bash
dune build
```

## 5. Lancer les tests

```bash
dune runtest
```

## 6. Lancer l’application

Interface graphique :

```bash
dune exec pascatho
```

Exemples en ligne de commande :

```bash
dune exec pascatho -- translations
dune exec pascatho -- show-ref --translation bible_aelf --reference "Jn 1,1"
dune exec pascatho -- chapter-ref --translation bible_aelf --reference "Coran:1.3"
```

## Notes WSL

### WSLg

Sous Windows 11, WSLg suffit généralement. Vérifie simplement que les applications graphiques WSL s’ouvrent déjà.

### Si aucun affichage ne s’ouvre

Vérifie d’abord :

```bash
echo $DISPLAY
echo $WAYLAND_DISPLAY
```

Si `DISPLAY` et `WAYLAND_DISPLAY` sont vides, le problème est côté configuration graphique WSL, pas côté Dune.

## Installation macOS

Cette section couvre macOS avec [Homebrew](https://brew.sh) (testée sur Apple Silicon, `/opt/homebrew`). Pour Intel, remplace `/opt/homebrew` par `/usr/local` dans les chemins.

### 1. Installer les paquets système

```bash
brew install ocaml ocaml-findlib dune opam gtk+3 pkg-config
```

`gtk+3` fournit également les dépendances transitives (glib, gobject, cairo, pango, harfbuzz, gdk-pixbuf, atk).

### 2. Initialiser opam et créer un switch local

```bash
opam init --bare --auto-setup --disable-sandboxing -y
opam switch create . --packages=ocaml-system.5.4.0 --no-install -y
eval "$(opam env)"
```

L'option `ocaml-system` réutilise le compilateur OCaml installé par Homebrew (plus rapide qu'une recompilation). `--no-install` évite que la création du switch ne tente de builder le projet avant que les dépendances ne soient présentes.

### 3. Installer les dépendances OCaml

```bash
opam install cmdliner yojson dune -y
eval "$(opam env)"
```

### 4. Compiler et lancer

```bash
dune build
dune exec pascatho
```

Sur macOS, le linkage GTK passe par `pkg-config` : le fichier `bin/dune` inclut un sexp généré par `bin/gen_gtk_link_flags.sh`, qui interroge `pkg-config --libs gtk+-3.0 …` au moment du build. Aucune adaptation manuelle des chemins n'est nécessaire.

### 5. Construire le bundle `Pascatho.app`

`dune exec pascatho` lance le binaire brut (`pascatho.exe`). Pour obtenir une vraie application macOS — icône `logo.jpeg` dans le Dock, nom « Pascatho » dans Finder, double-clic depuis `/Applications` — utilise le script fourni :

```bash
dune build
bash macos/build_app.sh
open dist/Pascatho.app
```

Le script :
- convertit `logo.jpeg` en `Pascatho.icns` via `sips` + `iconutil` (outils macOS natifs) ;
- assemble `dist/Pascatho.app/` avec `Info.plist`, l'icône, et un lanceur `Contents/MacOS/Pascatho` qui définit `PASCATHO_ROOT` vers le checkout source avant d'exécuter le binaire.

Le bundle reste léger (~5 Mo) car il référence les fichiers `datas/`, `articles/`, `highlights/` du dépôt — déplacer ou supprimer le checkout casse l'application installée. Pour distribuer un `.app` autonome, copie ces dossiers dans `Contents/Resources/` et ajuste le launcher pour pointer `PASCATHO_ROOT` vers `"$DIR/../Resources"`.

Tu peux glisser `Pascatho.app` dans `/Applications` ; macOS suivra le lien vers le binaire et le repo source.

### Notes macOS

- Pense à ajouter `eval "$(opam env)"` à ton `~/.zshrc` (ou laisse `opam init --auto-setup` le faire) pour que `dune` trouve le switch automatiquement dans chaque nouveau shell.
- Si `pkg-config --libs gtk+-3.0` échoue, vérifie que `brew --prefix` est bien dans `PKG_CONFIG_PATH`. Homebrew expose en général tout dans `/opt/homebrew/lib/pkgconfig`.
- L'interface GTK s'ouvre nativement via XQuartz/Cocoa selon la configuration de Homebrew ; aucune variable `DISPLAY` n'est requise.

## Fichiers utiles

- [`README.md`](./README.md) : vue d’ensemble
- [`bibleTools.js`](./bibleTools.js) : logique historique des références
- [`sources.js`](./sources.js) : description des sources
- [`highlights`](./highlights) : regex de mise en évidence
