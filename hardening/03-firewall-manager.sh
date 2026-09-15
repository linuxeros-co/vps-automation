#!/bin/bash
###############################################################################
# 03-firewall-manager.sh
# Automatización para administrar el firewall UFW (Ubuntu 26.04+)
# Ejecutar como root: sudo bash 03-firewall-manager.sh
###############################################################################

set -euo pipefail

LOG_DIR="/var/log/vps-hardening"
LOG_FILE="$LOG_DIR/firewall-$(date +%Y%m%d-%H%M%S).log"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
warn()  { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN:${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"; }
info()  { echo -e "${CYAN}$1${NC}"; }

if [[ $EUID -ne 0 ]]; then
    error "Este script debe ejecutarse como root (sudo bash $0)"
    exit 1
fi

mkdir -p "$LOG_DIR"

# Valida una IPv4, opcionalmente con notación CIDR (ej: 192.168.1.0/24)
is_valid_ip() {
    local ip="$1"
    local addr="${ip%%/*}"
    local cidr="${ip#*/}"

    # Debe tener el formato N.N.N.N
    if [[ ! "$addr" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
        return 1
    fi

    # Cada octeto debe estar entre 0 y 255
    local octet
    for octet in ${addr//./ }; do
        if (( octet < 0 || octet > 255 )); then
            return 1
        fi
    done

    # Si se especificó /CIDR, debe ser un número entre 0 y 32
    if [[ "$ip" == */* ]]; then
        if [[ ! "$cidr" =~ ^[0-9]{1,2}$ ]] || (( cidr < 0 || cidr > 32 )); then
            return 1
        fi
    fi

    return 0
}

# Valida que sea un número de puerto válido (1-65535)
is_valid_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]{1,5}$ ]] && (( port >= 1 && port <= 65535 ))
}

# Validar e instalar UFW si no está presente
check_ufw() {
    if ! command -v ufw &>/dev/null; then
        warn "UFW no está instalado. Instalando..."
        apt-get update -y >> "$LOG_FILE" 2>&1
        apt-get install -y ufw >> "$LOG_FILE" 2>&1
        log "UFW instalado correctamente."
    else
        log "UFW detectado: $(ufw version 2>/dev/null || echo 'instalado')"
    fi
}

# Ver estado del firewall
show_status() {
    echo ""
    info "=== Estado del Firewall ==="
    ufw status verbose
    echo ""
}

# Habilitar UFW
enable_ufw() {
    echo ""
    warn "Asegúrate de que el puerto SSH (22) esté abierto antes de habilitar."
    read -rp "¿Continuar habilitando UFW? (s/n): " CONFIRM
    if [[ "$CONFIRM" =~ ^[sS]$ ]]; then
        ufw --force enable >> "$LOG_FILE" 2>&1
        log "UFW habilitado."
    fi
}

# Deshabilitar UFW
disable_ufw() {
    echo ""
    read -rp "¿Estás seguro de deshabilitar UFW? (s/n): " CONFIRM
    if [[ "$CONFIRM" =~ ^[sS]$ ]]; then
        ufw disable >> "$LOG_FILE" 2>&1
        log "UFW deshabilitado."
    fi
}

# Abrir un puerto
open_port() {
    echo ""
    read -rp "Puerto a abrir: " PORT
    if ! is_valid_port "$PORT"; then
        error "Puerto inválido: '$PORT'. Debe ser un número entre 1 y 65535."
        return
    fi

    read -rp "Protocolo (tcp/udp/ambos) [tcp]: " PROTO
    PROTO=${PROTO:-tcp}
    if [[ "$PROTO" != "tcp" && "$PROTO" != "udp" && "$PROTO" != "ambos" ]]; then
        error "Protocolo inválido: '$PROTO'. Usa tcp, udp o ambos."
        return
    fi

    if [[ "$PROTO" == "ambos" ]]; then
        ufw allow "$PORT"/tcp >> "$LOG_FILE" 2>&1
        ufw allow "$PORT"/udp >> "$LOG_FILE" 2>&1
        log "Puerto $PORT abierto (TCP + UDP)."
    else
        ufw allow "$PORT"/"$PROTO" >> "$LOG_FILE" 2>&1
        log "Puerto $PORT/$PROTO abierto."
    fi
}

# Cerrar un puerto
close_port() {
    echo ""
    read -rp "Puerto a cerrar: " PORT
    if ! is_valid_port "$PORT"; then
        error "Puerto inválido: '$PORT'. Debe ser un número entre 1 y 65535."
        return
    fi

    read -rp "Protocolo (tcp/udp/ambos) [tcp]: " PROTO
    PROTO=${PROTO:-tcp}
    if [[ "$PROTO" != "tcp" && "$PROTO" != "udp" && "$PROTO" != "ambos" ]]; then
        error "Protocolo inválido: '$PROTO'. Usa tcp, udp o ambos."
        return
    fi

    if [[ "$PROTO" == "ambos" ]]; then
        ufw deny "$PORT"/tcp >> "$LOG_FILE" 2>&1
        ufw deny "$PORT"/udp >> "$LOG_FILE" 2>&1
        log "Puerto $PORT cerrado (TCP + UDP)."
    else
        ufw deny "$PORT"/"$PROTO" >> "$LOG_FILE" 2>&1
        log "Puerto $PORT/$PROTO cerrado."
    fi
}

# Permitir acceso desde una IP
allow_ip() {
    echo ""
    read -rp "IP a permitir (ej: 190.1.2.3 o 190.1.2.0/24): " IP
    if ! is_valid_ip "$IP"; then
        error "IP inválida: '$IP'. Usa el formato N.N.N.N o N.N.N.N/CIDR."
        return
    fi

    read -rp "¿Puerto específico? (dejar vacío para todos): " PORT
    if [[ -n "$PORT" ]] && ! is_valid_port "$PORT"; then
        error "Puerto inválido: '$PORT'. Debe ser un número entre 1 y 65535."
        return
    fi

    if [[ -z "$PORT" ]]; then
        ufw allow from "$IP" >> "$LOG_FILE" 2>&1
        log "Acceso permitido desde $IP (todos los puertos)."
    else
        ufw allow from "$IP" to any port "$PORT" >> "$LOG_FILE" 2>&1
        log "Acceso permitido desde $IP al puerto $PORT."
    fi
}

# Bloquear una IP
block_ip() {
    echo ""
    read -rp "IP a bloquear (ej: 190.1.2.3 o 190.1.2.0/24): " IP
    if ! is_valid_ip "$IP"; then
        error "IP inválida: '$IP'. Usa el formato N.N.N.N o N.N.N.N/CIDR."
        return
    fi

    ufw deny from "$IP" >> "$LOG_FILE" 2>&1
    log "IP $IP bloqueada."
}

# Ver reglas numeradas
show_rules() {
    echo ""
    info "=== Reglas Activas (numeradas) ==="
    ufw status numbered
    echo ""
}

# Eliminar regla por número
delete_rule() {
    show_rules
    read -rp "Número de regla a eliminar: " RULE_NUM
    ufw delete "$RULE_NUM"
    log "Regla #$RULE_NUM eliminada."
}

# Aplicar perfil de seguridad base
apply_base_profile() {
    echo ""
    info "=== Aplicando Perfil de Seguridad Base ==="
    log "Aplicando perfil base..."

    # Política por defecto
    ufw default deny incoming >> "$LOG_FILE" 2>&1
    ufw default allow outgoing >> "$LOG_FILE" 2>&1
    log "Política: denegar entrada, permitir salida."

    # SSH
    ufw allow 22/tcp comment 'SSH' >> "$LOG_FILE" 2>&1
    log "Puerto 22 (SSH) abierto."

    # HTTP
    ufw allow 80/tcp comment 'HTTP' >> "$LOG_FILE" 2>&1
    log "Puerto 80 (HTTP) abierto."

    # HTTPS
    ufw allow 443/tcp comment 'HTTPS' >> "$LOG_FILE" 2>&1
    log "Puerto 443 (HTTPS) abierto."

    # Logging
    ufw logging on >> "$LOG_FILE" 2>&1
    log "Logging habilitado."

    # Habilitar si no está activo
    if ! ufw status | grep -q "Status: active"; then
        ufw --force enable >> "$LOG_FILE" 2>&1
        log "UFW habilitado."
    fi

    log "Perfil base aplicado correctamente."
    show_status
}

# Reset completo
reset_firewall() {
    echo ""
    warn "Esto eliminará TODAS las reglas del firewall."
    read -rp "¿Estás seguro? (escribe RESET para confirmar): " CONFIRM
    if [[ "$CONFIRM" == "RESET" ]]; then
        ufw --force reset >> "$LOG_FILE" 2>&1
        log "Firewall reseteado. Todas las reglas eliminadas."
        warn "UFW está deshabilitado después del reset."
    else
        echo "Cancelado."
    fi
}

# Menú principal
show_menu() {
    echo ""
    info "============================================"
    info "   Firewall Manager - VPS Hardening"
    info "   UFW para Ubuntu 26.04"
    info "============================================"
    echo ""
    echo "  1) Ver estado del firewall"
    echo "  2) Habilitar UFW"
    echo "  3) Deshabilitar UFW"
    echo "  4) Abrir un puerto"
    echo "  5) Cerrar un puerto"
    echo "  6) Permitir acceso desde una IP"
    echo "  7) Bloquear una IP"
    echo "  8) Ver reglas activas (numeradas)"
    echo "  9) Eliminar una regla"
    echo " 10) Aplicar perfil de seguridad base"
    echo " 11) Resetear firewall (PELIGROSO)"
    echo "  0) Salir"
    echo ""
}

# Ejecución principal
check_ufw

log "Firewall Manager iniciado."

while true; do
    show_menu
    read -rp "Opción: " OPTION

    case $OPTION in
        1)  show_status ;;
        2)  enable_ufw ;;
        3)  disable_ufw ;;
        4)  open_port ;;
        5)  close_port ;;
        6)  allow_ip ;;
        7)  block_ip ;;
        8)  show_rules ;;
        9)  delete_rule ;;
        10) apply_base_profile ;;
        11) reset_firewall ;;
        0)  log "Saliendo..."; exit 0 ;;
        *)  error "Opción inválida." ;;
    esac
done
