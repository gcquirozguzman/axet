#!/bin/bash

set -e

REPO="codefensory/axet"
INSTALL_DIR="$HOME/.axet"
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/axet"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/axet"

echo "Instalando Axet CLI..."

# Verificar Node.js
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js no está instalado. Instálalo primero:"
    echo "   https://nodejs.org (recomendado: LTS)"
    exit 1
fi

NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "ERROR: Node.js 18+ requerido. Tienes: $(node --version)"
    exit 1
fi

echo "Node.js detectado: $(node --version)"

# Obtener última versión desde GitHub API
echo "Buscando última versión..."
LATEST_RELEASE=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null || echo "")

if [ -z "$LATEST_RELEASE" ]; then
    echo "ERROR: No se pudo obtener información del release"
    echo "   ¿El repo existe y tiene releases públicos?"
    exit 1
fi

VERSION=$(echo "$LATEST_RELEASE" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4 | sed 's/^v//')

if [ -z "$VERSION" ]; then
    echo "ERROR: No se encontró versión en el último release"
    exit 1
fi

echo "Versión encontrada: v${VERSION}"

# Crear directorios
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$CONFIG_DIR" "$DATA_DIR"

# Descargar tarball del release
echo "Descargando Axet v${VERSION}..."
cd "$INSTALL_DIR"

# Backup de config si existe
if [ -f "package.json" ]; then
    echo "Actualizando instalación existente..."
fi

# Limpiar instalación anterior
rm -rf ./*

# Descargar asset del release
ASSET_URL="https://github.com/${REPO}/releases/download/v${VERSION}/axet-${VERSION}.tar.gz"
if ! curl -fsSL "$ASSET_URL" | tar xz --strip-components=1; then
    echo "ERROR: Error descargando el release"
    echo "   URL: $ASSET_URL"
    exit 1
fi

# Detectar Windows (Git Bash / MSYS2)
IS_WINDOWS=false
if [[ "$(uname -s)" == *"MINGW"* ]] || [[ "$(uname -s)" == *"MSYS"* ]] || [[ "$OSTYPE" == "msys" ]]; then
    IS_WINDOWS=true
fi

if $IS_WINDOWS; then
    # En Windows, npm install -g crea el wrapper .cmd automaticamente
    echo "Detectado Windows - instalando via npm global..."
    cd "$INSTALL_DIR" && npm install -g . --quiet
else
    # Crear wrapper script (Linux / Mac)
    cat > "$BIN_DIR/axet" << 'WRAPPER'
#!/bin/bash
export AXET_HOME="$HOME/.axet"
cd "$AXET_HOME" && node index.production.js "$@"
WRAPPER

    chmod +x "$BIN_DIR/axet"

    # Agregar a PATH si no está
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        SHELL_CONFIG=""
        if [ -f "$HOME/.bashrc" ]; then
            SHELL_CONFIG="$HOME/.bashrc"
        elif [ -f "$HOME/.zshrc" ]; then
            SHELL_CONFIG="$HOME/.zshrc"
        fi

        if [ -n "$SHELL_CONFIG" ]; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_CONFIG"
            echo "AVISO: Agregado $BIN_DIR al PATH en $SHELL_CONFIG"
            echo "   Ejecuta: source $SHELL_CONFIG"
        else
            echo "AVISO: Agrega esto a tu shell config:"
            echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
    fi
fi

echo ""
echo "Axet v${VERSION} instalado correctamente."
echo "   Código: $INSTALL_DIR"
echo "   Config: $CONFIG_DIR"
echo "   Datos:  $DATA_DIR"
echo "   Comando: axet"
echo ""
echo "Primeros pasos:"
echo "   axet login      Iniciar sesion"
echo "   axet start      Iniciar proxy server"
echo "   axet --help     Ver ayuda"
echo "   axet update     Actualizar CLI"
echo ""
echo "Para desinstalar:"
echo "   rm -rf $INSTALL_DIR $BIN_DIR/axet $CONFIG_DIR $DATA_DIR"
