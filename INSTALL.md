# Installation

Ce document décrit une installation depuis Debian ou Ubuntu exécuté dans WSL sur Windows.

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

## Fichiers utiles

- [`README.md`](./README.md) : vue d’ensemble
- [`bibleTools.js`](./bibleTools.js) : logique historique des références
- [`sources.js`](./sources.js) : description des sources
- [`highlights`](./highlights) : regex de mise en évidence
