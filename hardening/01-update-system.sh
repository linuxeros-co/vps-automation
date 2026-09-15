#!/bin/bash
###############################################################################
# 01-update-system.sh
# Actualización completa del sistema operativo Ubuntu (26.04+)
# Ejecutar como root: sudo bash 01-update-system.sh
###############################################################################

set -euo pipefail

LOG_DIR="/var/log/vps-hardening"
LOG_FILE="$LOG_DIR/update-system-$(date +%Y%m%d-%H%M%S).log"

GREEN='\033[0;32m'
YELLOW='\033[1;33m' 
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
warn()  { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN:${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"; }

if [[ $EUID -ne 0 ]]; then
    error "Este script debe ejecutarse como root (sudo bash $0)"
    exit 1
fi

mkdir -p "$LOG_DIR"

echo "============================================" | tee -a "$LOG_FILE"
echo " Actualización del Sistema - VPS Hardening"  | tee -a "$LOG_FILE"
echo " Fecha: $(date)"                             | tee -a "$LOG_FILE"
echo " OS: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"

# 1. Actualizar lista de paquetes
log "Actualizando lista de paquetes..."
apt-get update -y >> "$LOG_FILE" 2>&1

# 2. Actualizar paquetes instalados
log "Aplicando actualizaciones del sistema..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y >> "$LOG_FILE" 2>&1

# 3. Actualización de distribución
log "Aplicando actualizaciones de distribución..."
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y >> "$LOG_FILE" 2>&1

# 4. Instalar paquetes esenciales
log "Instalando paquetes esenciales..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    sudo \
    ufw \
    fail2ban \
    unattended-upgrades \
    apt-listchanges \
    curl \
    wget \
    git \
    htop \
    net-tools \
    logwatch \
    >> "$LOG_FILE" 2>&1

# 5. Configurar actualizaciones automáticas de seguridad
log "Configurando actualizaciones automáticas de seguridad..."

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF

cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'UEOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
UEOF

# 6. Configurar fail2ban básico
log "Configurando fail2ban..."
cat > /etc/fail2ban/jail.local << 'F2BEOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = /var/log/auth.log
maxretry = 3
F2BEOF

systemctl enable fail2ban >> "$LOG_FILE" 2>&1
systemctl restart fail2ban >> "$LOG_FILE" 2>&1

# 7. Verificar auditoría de sudo
# Ubuntu 26.04 usa sudo-rs (reescritura en Rust), que NO soporta las
# directivas clásicas de logging (logfile, log_input, log_output,
# iolog_dir). Sin embargo, sudo ya registra cada comando ejecutado
# de forma automática en el syslog / /var/log/auth.log, sin necesitar
# configuración adicional. Ejemplo de línea registrada:
#   sudo: usuario : PWD=/home/usuario ; USER=root ; COMMAND=/usr/bin/apt install nginx
log "Verificando auditoría de comandos sudo..."

if [[ -f /var/log/auth.log ]]; then
    log "Auditoría activa por defecto en: /var/log/auth.log"
    log "Revisar comandos sudo con: sudo grep sudo: /var/log/auth.log"
else
    warn "No se encontró /var/log/auth.log. Los comandos sudo se registran"
    warn "en journald. Revisar con: sudo journalctl -t sudo"
fi

# 8. Limpiar paquetes obsoletos
log "Limpiando paquetes obsoletos..."
apt-get autoremove -y >> "$LOG_FILE" 2>&1
apt-get autoclean -y >> "$LOG_FILE" 2>&1

log "Sistema actualizado correctamente."
log "Log completo en: $LOG_FILE"
echo ""
echo "Siguiente paso: sudo bash 02-create-user.sh <nombre_usuario>"
