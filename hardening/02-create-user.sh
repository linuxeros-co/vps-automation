#!/bin/bash
###############################################################################
# 02-create-user.sh
# Creación de usuario con autenticación SOLO por llave SSH
# Compatible con VPS OVH Cloud - Ubuntu 26.04+
#
# NOTA: Este script NO toca el usuario 'ubuntu' de OVH.
#       La configuración de 'ubuntu' es manual (ver README.md)
#
# Todos los usuarios se crean con sudo completo (sin restricciones).
# En vez de bloquear comandos, todo lo que ejecuten con sudo queda
# registrado automáticamente en /var/log/auth.log (sudo lo hace por
# defecto, sin configuración extra). Así no hay fricción para instalar
# software, y si algo sale mal se revisa el log para ver qué se ejecutó.
#
# Ejecutar como root o ubuntu: sudo bash 02-create-user.sh <nombre_usuario>
###############################################################################

set -euo pipefail

LOG_DIR="/var/log/vps-hardening"
LOG_FILE="$LOG_DIR/create-user-$(date +%Y%m%d-%H%M%S).log"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
warn()  { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN:${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"; }
info()  { echo -e "${CYAN}$1${NC}"; }

# Crear el directorio de logs antes que nada, para que las funciones
# log/warn/error puedan escribir desde el primer momento.
mkdir -p "$LOG_DIR"

if [[ $EUID -ne 0 ]]; then
    error "Este script debe ejecutarse como root (sudo bash $0)"
    exit 1
fi

if [[ $# -lt 1 ]]; then
    echo ""
    echo "Uso: sudo bash $0 <nombre_usuario>"
    echo ""
    echo "Ejemplo: sudo bash $0 felipearciniegas"
    exit 1
fi

USERNAME="$1"

# IMPORTANTE: no se permiten puntos en el nombre de usuario.
# /etc/sudoers.d/ ignora por diseño cualquier archivo cuyo nombre
# contenga un punto (para descartar backups tipo .bak/.dpkg-old).
# Como el archivo sudoers se llama igual que el usuario, un nombre
# con punto (ej: felipe.arciniegas) hace que sudo directamente
# ignore ese archivo, cayendo a la regla de grupo %sudo (que sí
# pide password). Usar guion o sin separador: felipearciniegas
if [[ "$USERNAME" == *"."* ]]; then
    error "El nombre de usuario no puede contener puntos: '$USERNAME'"
    error "Motivo: /etc/sudoers.d/ ignora archivos con punto en el nombre,"
    error "lo que rompe el NOPASSWD y hace que sudo pida contraseña."
    echo ""
    echo "Usa guion medio o sin separador, por ejemplo:"
    echo "  felipe-arciniegas"
    echo "  felipearciniegas"
    exit 1
fi

USER_HOME="/home/$USERNAME"
SSH_DIR="$USER_HOME/.ssh"

# Llaves temporales en /home/ubuntu/ssh-keys (no en /root) para que el
# admin, que se conecta como usuario 'ubuntu', pueda descargarlas
# directo con scp sin necesitar sudo extra.
KEY_DIR="/home/ubuntu/ssh-keys"

mkdir -p "$KEY_DIR"
chown ubuntu:ubuntu "$KEY_DIR"
chmod 700 "$KEY_DIR"

###############################################################################
# ROLLBACK AUTOMÁTICO
# Si el script falla en cualquier punto, esta función limpia lo que se
# haya llegado a crear en ESTA ejecución, para no dejar residuos a medias.
# No debe tocar nada que ya existiera antes de correr el script.
###############################################################################
USER_CREATED_BY_THIS_RUN="no"
SUDOERS_CREATED_BY_THIS_RUN="no"

cleanup_on_failure() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        error "El script falló (exit code $exit_code). Revirtiendo cambios parciales..."

        if [[ "$USER_CREATED_BY_THIS_RUN" == "yes" ]] && id "$USERNAME" &>/dev/null; then
            warn "Eliminando usuario '$USERNAME' y su home (creado en esta ejecución)..."
            userdel -r "$USERNAME" >> "$LOG_FILE" 2>&1 || true
        fi

        if [[ "$SUDOERS_CREATED_BY_THIS_RUN" == "yes" && -f "/etc/sudoers.d/$USERNAME" ]]; then
            warn "Eliminando sudoers de '$USERNAME' (creado en esta ejecución)..."
            rm -f "/etc/sudoers.d/$USERNAME"
        fi

        error "Rollback completado."
        error "Revisa el log para más detalle: $LOG_FILE"
    fi
}
trap cleanup_on_failure EXIT

echo "============================================" | tee -a "$LOG_FILE"
echo " Creación de Usuario - VPS Hardening (OVH)" | tee -a "$LOG_FILE"
echo " Fecha: $(date)"                             | tee -a "$LOG_FILE"
echo " Usuario: $USERNAME"                          | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"

# Validar que el usuario no exista
if id "$USERNAME" &>/dev/null; then
    error "El usuario '$USERNAME' ya existe."
    exit 1
fi

###############################################################################
# PASO 1: Generar par de llaves SSH
###############################################################################
log "Generando par de llaves SSH para '$USERNAME'..."

KEY_FILE="$KEY_DIR/${USERNAME}_ed25519"

if [[ -f "$KEY_FILE" ]]; then
    warn "Ya existe una llave en $KEY_FILE. Se usará la existente."
else
    ssh-keygen -t ed25519 -C "${USERNAME}@vps-ovh" -f "$KEY_FILE" -N "" >> "$LOG_FILE" 2>&1

    # El script corre como root, así que las llaves generadas quedan
    # como root:root. Se le pasa el dueño a 'ubuntu' para que el admin
    # pueda leerlas y descargarlas por scp sin necesitar sudo.
    chown ubuntu:ubuntu "$KEY_FILE" "${KEY_FILE}.pub"
    chmod 600 "$KEY_FILE"
    chmod 644 "${KEY_FILE}.pub"

    log "Par de llaves generado:"
    log "  Privada (TEMPORAL): $KEY_FILE"
    log "  Pública: ${KEY_FILE}.pub"
fi

###############################################################################
# PASO 2: Crear usuario SIN contraseña
###############################################################################
log "Creando usuario '$USERNAME' sin contraseña..."

# Se usa useradd en vez de adduser porque adduser es más estricto con
# la validación de nombres (NAME_REGEX) y puede rechazar variantes válidas.
useradd --create-home --shell /bin/bash --comment "" "$USERNAME" >> "$LOG_FILE" 2>&1
USER_CREATED_BY_THIS_RUN="yes"

passwd -l "$USERNAME" >> "$LOG_FILE" 2>&1
log "Contraseña bloqueada. Solo acceso por llave SSH."

###############################################################################
# PASO 3: Agregar al grupo sudo (sudo completo, con auditoría)
###############################################################################
log "Agregando '$USERNAME' al grupo sudo..."
usermod -aG sudo "$USERNAME" >> "$LOG_FILE" 2>&1

SUDOERS_FILE="/etc/sudoers.d/$USERNAME"
cat > "$SUDOERS_FILE" << SUDEOF
# Sudoers para $USERNAME - VPS Hardening OVH
# Fecha: $(date)
# Sudo completo. Cada comando queda registrado automáticamente
# en /var/log/auth.log (comportamiento por defecto de sudo).

$USERNAME ALL=(ALL) NOPASSWD: ALL
SUDEOF
SUDOERS_CREATED_BY_THIS_RUN="yes"

chmod 0440 "$SUDOERS_FILE"
if ! visudo -cf "$SUDOERS_FILE" >> "$LOG_FILE" 2>&1; then
    error "Error de sintaxis en sudoers. Eliminando archivo..."
    rm -f "$SUDOERS_FILE"
    exit 1
fi
log "Sudo completo configurado. Archivo sudoers validado correctamente."

###############################################################################
# PASO 4: Configurar SSH del nuevo usuario
###############################################################################
log "Configurando SSH para '$USERNAME'..."

mkdir -p "$SSH_DIR"
cp "${KEY_FILE}.pub" "$SSH_DIR/authorized_keys"
chmod 700 "$SSH_DIR"
chmod 600 "$SSH_DIR/authorized_keys"
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

log "Llave pública instalada en $SSH_DIR/authorized_keys"

# Desactivar el trap de rollback: a partir de aquí el usuario quedó
# creado correctamente y no queremos revertir nada.
trap - EXIT

# Detectar IP pública del servidor para las instrucciones finales
SERVER_IP=$(curl -s -4 --max-time 3 ifconfig.me 2>/dev/null || curl -s -4 --max-time 3 icanhazip.com 2>/dev/null || echo "")
SERVER_IP=${SERVER_IP:-<ip_vps>}

###############################################################################
# RESUMEN
###############################################################################
echo "" | tee -a "$LOG_FILE"
info "============================================"
info " Usuario creado exitosamente"
info "============================================"
echo ""
echo " Usuario:        $USERNAME"
echo " Home:           $USER_HOME"
echo " Contraseña:     DESHABILITADA (sin password)"
echo " Auth SSH:       Solo llave ED25519"
echo " Sudo:           Completo (NOPASSWD, sin restricciones)"
echo " Auditoría:      Todos los comandos sudo se registran en"
echo "                 /var/log/auth.log automáticamente"
echo ""
echo " Llave privada (TEMPORAL): $KEY_FILE"
echo " Llave pública:            ${KEY_FILE}.pub"
echo " authorized_keys:          $SSH_DIR/authorized_keys"
echo ""
info "============================================"
info " PASO 1: TÚ descargas la llave privada"
info "============================================"
echo ""
echo " Desde TU máquina local (admin), ejecuta:"
echo ""
echo "   scp vps-ovh:$KEY_FILE ./${USERNAME}_ed25519"
echo ""
echo " Esto la descarga a tu carpeta actual. Envíasela al usuario"
echo " por un canal seguro (gestor de contraseñas, no email/chat plano)."
echo ""

info "============================================"
info " PASO 2: Instrucciones para ENVIAR al usuario"
info "============================================"
echo ""
echo "-------------------------------------------------------------"
echo " Si el usuario usa Linux o macOS:"
echo "-------------------------------------------------------------"
echo ""
echo " 1. Guardar el archivo recibido en ~/.ssh/"
echo "      mv ${USERNAME}_ed25519 ~/.ssh/"
echo "      chmod 600 ~/.ssh/${USERNAME}_ed25519"
echo ""
echo " 2. Conectarse:"
echo "      ssh -i ~/.ssh/${USERNAME}_ed25519 ${USERNAME}@${SERVER_IP}"
echo ""
echo " 3. (Opcional) Agregar a ~/.ssh/config para no escribir la ruta:"
echo "      Host vps-${USERNAME}"
echo "          HostName ${SERVER_IP}"
echo "          User ${USERNAME}"
echo "          IdentityFile ~/.ssh/${USERNAME}_ed25519"
echo "      Luego solo: ssh vps-${USERNAME}"
echo ""
echo "-------------------------------------------------------------"
echo " Si el usuario usa Windows:"
echo "-------------------------------------------------------------"
echo ""
echo " Opción A - PowerShell / Windows Terminal (OpenSSH, recomendado):"
echo "   Windows 10/11 ya trae OpenSSH. El archivo ${USERNAME}_ed25519"
echo "   funciona igual que en Linux, sin conversión."
echo ""
echo "   1. Guardar el archivo en, por ejemplo: C:\\Users\\<user>\\.ssh\\"
echo "   2. Conectarse desde PowerShell:"
echo "        ssh -i C:\\Users\\<user>\\.ssh\\${USERNAME}_ed25519 ${USERNAME}@${SERVER_IP}"
echo ""
echo " Opción B - PuTTY (requiere conversión a formato .ppk):"
echo "   PuTTY NO entiende el formato OpenSSH directamente."
echo "   El usuario debe convertir la llave con PuTTYgen:"
echo ""
echo "   1. Descargar PuTTYgen (viene con el instalador de PuTTY):"
echo "      https://www.putty.org/"
echo "   2. Abrir PuTTYgen -> Conversions -> Import key"
echo "      Seleccionar el archivo ${USERNAME}_ed25519 recibido"
echo "   3. Click en 'Save private key' -> genera ${USERNAME}_ed25519.ppk"
echo "   4. En PuTTY: Connection > SSH > Auth > Credentials"
echo "      Cargar el archivo .ppk generado"
echo "   5. En Session: Host Name = ${USERNAME}@${SERVER_IP}, Port 22"
echo ""
echo "-------------------------------------------------------------"

echo ""
info "============================================"
info " PASO 3: Limpieza"
info "============================================"
echo ""
echo " Una vez el usuario confirme que puede conectarse, elimina"
echo " la llave privada del servidor (ya no debe existir ahí):"
echo ""
echo "   rm -f $KEY_FILE"
echo ""

info "============================================"
info " Permisos otorgados"
info "============================================"
echo ""
echo " [PERMITIDO] Sudo completo (instalar, configurar, todo)"
echo " [AUDITADO]  Cada comando sudo se registra con usuario y fecha"
echo "             Revisar con: sudo grep sudo: /var/log/auth.log"
echo ""
echo "Siguiente paso: sudo bash 03-firewall-manager.sh"
