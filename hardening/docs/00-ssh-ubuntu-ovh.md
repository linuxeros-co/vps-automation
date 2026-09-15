# Paso 0: Asegurar el usuario ubuntu de OVH (manual)

Antes de ejecutar cualquier script, hay que asegurar el usuario `ubuntu` que provee OVH para no perder acceso a la VPS. Este paso es manual y no está automatizado.

## 0.1 Generar llave SSH para ubuntu (desde tu máquina local)

```bash
# En tu máquina local, generar par de llaves
ssh-keygen -t ed25519 -C "ubuntu@vps-ovh" -f ~/.ssh/ubuntu_ovh_ed25519

# Ver la llave pública generada
cat ~/.ssh/ubuntu_ovh_ed25519.pub
```

## 0.2 Copiar la llave pública al servidor

```bash
# Opción 1: Con ssh-copy-id (si tienes acceso por password)
ssh-copy-id -i ~/.ssh/ubuntu_ovh_ed25519.pub ubuntu@<ip_vps>

# Opción 2: Manual
ssh ubuntu@<ip_vps>
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "PEGA_AQUI_TU_LLAVE_PUBLICA" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

## 0.3 Probar acceso con llave

```bash
# Desde tu máquina local
ssh -i ~/.ssh/ubuntu_ovh_ed25519 ubuntu@<ip_vps>
```

## 0.4 Bloquear contraseña del usuario ubuntu

Solo después de confirmar que la llave funciona:

```bash
# En el servidor, como ubuntu
sudo passwd -l ubuntu
```

## 0.5 Hardening SSH (deshabilitar passwords globalmente)

Solo después de confirmar acceso por llave para ubuntu:

```bash
# En el servidor
sudo tee /etc/ssh/sshd_config.d/hardening.conf << 'EOF'
# VPS Hardening - SSH (OVH Cloud Ubuntu 26.04)
# Solo autenticación por llave SSH

PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
PubkeyAuthentication yes
PermitRootLogin no
MaxAuthTries 3
MaxSessions 3
LoginGraceTime 30
PermitEmptyPasswords no
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
LogLevel VERBOSE
EOF

# Validar configuración
sudo sshd -t

# Si no hay errores, reiniciar SSH
sudo systemctl restart sshd
```

## 0.6 Configurar SSH config local (opcional, recomendado)

Para no escribir la ruta de la llave cada vez, en tu máquina local crea o edita `~/.ssh/config`:

```bash
touch ~/.ssh/config
chmod 600 ~/.ssh/config
```

Agrega:

```
Host vps-ovh
    HostName <ip_vps>
    User ubuntu
    IdentityFile ~/.ssh/ubuntu_ovh_ed25519
```

Después de esto, conectas solo con:

```bash
ssh vps-ovh
```

## 0.7 Verificación final

```bash
# Desde otra terminal (NO cierres la sesión actual)
ssh -i ~/.ssh/ubuntu_ovh_ed25519 ubuntu@<ip_vps>
# o, si configuraste el paso 0.6:
ssh vps-ovh

# Si funciona, la sesión anterior ya se puede cerrar
# Si NO funciona, usa la sesión abierta para corregir
```

Una vez confirmado el acceso por llave, continúa con la [actualización del sistema](../README.md#paso-1-actualizar-el-sistema-operativo).
