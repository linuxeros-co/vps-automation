# Paso 1: Actualizar el sistema operativo

Script: [`01-update-system.sh`](../01-update-system.sh)

```bash
sudo bash 01-update-system.sh
```

## Qué hace

- Actualiza la lista de paquetes y aplica todas las actualizaciones
- Instala paquetes esenciales (sudo, ufw, fail2ban, unattended-upgrades, curl, wget, git, htop)
- Configura actualizaciones automáticas de seguridad
- Configura fail2ban para proteger SSH (ban tras 3 intentos fallidos)
- Verifica que la auditoría de sudo esté activa (ver más abajo)
- Limpia paquetes obsoletos

## Conceptos clave

### unattended-upgrades

Paquete de Ubuntu que instala parches de seguridad automáticamente en segundo plano sin intervención manual. Si se publica un fix crítico (kernel, OpenSSL, etc.), se aplica solo. Esencial en una VPS que no se monitorea 24/7.

### fail2ban

Servicio que monitorea los logs del servidor en tiempo real (`/var/log/auth.log`). Cuando detecta múltiples intentos fallidos de login desde una misma IP (3 intentos por defecto), la bloquea automáticamente usando el firewall. Primera línea de defensa contra ataques de fuerza bruta SSH.

### Auditoría de sudo

Ubuntu 26.04 usa `sudo-rs` (reescritura en Rust del sudo tradicional), que no soporta las directivas clásicas de logging avanzado (`logfile`, `log_input`, `log_output`, `iolog_dir`). No hace falta configurarlas: sudo ya registra cada comando ejecutado automáticamente en `/var/log/auth.log`, sin configuración adicional, con este formato:

```
sudo: usuario : PWD=/home/usuario ; USER=root ; COMMAND=/usr/bin/apt install nginx
```

Para revisar el historial de comandos sudo de cualquier usuario:

```bash
sudo grep sudo: /var/log/auth.log
```
