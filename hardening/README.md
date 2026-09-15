# Aseguramiento de VPS Ubuntu (OVH Cloud)

Kit de scripts para asegurar una VPS Ubuntu nueva en OVH Cloud.

## Estructura

```
vps-hardening/
├── README.md
├── 01-update-system.sh        # Actualización del sistema operativo
├── 02-create-user.sh          # Creación de usuario con sudo + SSH por llave
├── 03-firewall-manager.sh     # Automatización del firewall (UFW)
├── keys/                      # Llaves descargadas (no versionar)
└── docs/
    ├── 00-ssh-ubuntu-ovh.md      # Paso 0: asegurar usuario ubuntu (manual)
    ├── 01-actualizar-sistema.md  # Paso 1: actualización del sistema
    ├── 02-crear-usuario.md       # Paso 2: crear usuarios nuevos
    └── 03-firewall.md            # Paso 3: administrar el firewall
```

## Requisitos previos

- Acceso al usuario `ubuntu` de la VPS OVH (usuario inicial que provee OVH)
- Ubuntu 26.04 (compatible con 22.04 / 24.04)
- Conexión a internet

## Pasos

### Paso 0: Asegurar el usuario ubuntu de OVH (manual)

Antes de ejecutar cualquier script, hay que asegurar el usuario `ubuntu` que provee OVH para no perder acceso a la VPS: generar llave SSH, copiarla al servidor, bloquear password y aplicar hardening SSH.

Ver guía completa: [`docs/00-ssh-ubuntu-ovh.md`](docs/00-ssh-ubuntu-ovh.md)

### Paso 1: Actualizar el sistema operativo

```bash
sudo bash 01-update-system.sh
```

Actualiza el sistema, instala paquetes esenciales de seguridad (ufw, fail2ban, unattended-upgrades) y verifica la auditoría de sudo.

Ver guía completa: [`docs/01-actualizar-sistema.md`](docs/01-actualizar-sistema.md)

### Paso 2: Crear usuarios nuevos

```bash
sudo bash 02-create-user.sh <nombre_usuario>
```

Crea un usuario con acceso solo por llave SSH (sin contraseña) y sudo completo. Incluye instrucciones de entrega para Linux/macOS/Windows.

> El nombre de usuario NO puede tener puntos (ver por qué en la guía).

Ver guía completa: [`docs/02-crear-usuario.md`](docs/02-crear-usuario.md)

### Paso 3: Administrar el firewall

```bash
sudo bash 03-firewall-manager.sh
```

Menú interactivo para gestionar UFW: abrir/cerrar puertos, permitir o bloquear IPs, y aplicar un perfil de seguridad base.

Ver guía completa: [`docs/03-firewall.md`](docs/03-firewall.md)

## Orden de ejecución completo en VPS OVH nueva

```bash
# 0. Asegurar usuario ubuntu (MANUAL - ver docs/00-ssh-ubuntu-ovh.md)

# 1. Subir scripts al servidor
scp -r vps-hardening/ ubuntu@<ip_vps>:~/

# 2. Conectarse con llave SSH
ssh -i ~/.ssh/ubuntu_ovh_ed25519 ubuntu@<ip_vps>

# 3. Dar permisos
chmod +x ~/vps-hardening/*.sh

# 4. Actualizar sistema
sudo bash ~/vps-hardening/01-update-system.sh

# 5. Crear usuarios (sin puntos en el nombre)
sudo bash ~/vps-hardening/02-create-user.sh felipearciniegas

# 6. Descargar llave del nuevo usuario (desde máquina local)
scp ubuntu@<ip_vps>:/home/ubuntu/ssh-keys/felipearciniegas_ed25519 ~/.ssh/
chmod 600 ~/.ssh/felipearciniegas_ed25519

# 7. Probar acceso del nuevo usuario (desde otra terminal)
ssh -i ~/.ssh/felipearciniegas_ed25519 felipearciniegas@<ip_vps>

# 8. Configurar firewall
sudo bash ~/vps-hardening/03-firewall-manager.sh
# -> Seleccionar opción 10: Aplicar perfil de seguridad base

# 9. Limpiar llave privada del servidor
rm -f /home/ubuntu/ssh-keys/felipearciniegas_ed25519
```

## Notas de seguridad

- SIEMPRE probar acceso por llave ANTES de aplicar hardening SSH (Paso 0)
- SIEMPRE descargar la llave privada del nuevo usuario ANTES de limpiar el servidor
- El nombre de usuario NO puede tener puntos (ver [`docs/02-crear-usuario.md`](docs/02-crear-usuario.md))
- OVH puede tener reglas de firewall adicionales en su panel (Network > Firewall)
- Los scripts generan logs en `/var/log/vps-hardening/`

## Logs

```
/var/log/vps-hardening/
├── update-system-YYYYMMDD-HHMMSS.log
├── create-user-YYYYMMDD-HHMMSS.log
└── firewall-YYYYMMDD-HHMMSS.log
```
