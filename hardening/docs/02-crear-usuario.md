# Paso 2: Crear usuarios nuevos (automatizado)

Script: [`02-create-user.sh`](../02-create-user.sh)

```bash
sudo bash 02-create-user.sh <nombre_usuario>
```

Ejemplo:
```bash
sudo bash 02-create-user.sh felipearciniegas
```

> **Importante:** el nombre de usuario NO puede contener puntos (ej: `felipe.arciniegas`). El script lo rechaza automáticamente. Motivo: `/etc/sudoers.d/` ignora por diseño cualquier archivo cuyo nombre tenga un punto (para descartar backups tipo `.bak`/`.dpkg-old`), y el archivo sudoers se llama igual que el usuario. Con un punto, sudo ignora la regla `NOPASSWD` y termina pidiendo contraseña. Usa guion medio o sin separador: `felipe-arciniegas` o `felipearciniegas`.

## Qué hace el script

1. Genera par de llaves SSH ED25519 en `/home/ubuntu/ssh-keys/` (temporal, propiedad de `ubuntu` para no necesitar sudo al descargarla)
2. Crea el usuario SIN contraseña
3. Lo agrega al grupo sudo con permisos completos (NOPASSWD)
4. Copia la llave pública al `~/.ssh/authorized_keys` del usuario
5. Detecta la IP del servidor y muestra instrucciones de entrega (Linux/macOS/Windows)
6. Si algo falla a mitad de camino, revierte automáticamente lo que se haya creado (usuario, sudoers) para no dejar residuos a medias

Todos los comandos que el usuario ejecute con sudo quedan registrados automáticamente en `/var/log/auth.log` (comportamiento por defecto de sudo, sin configuración extra).

Al finalizar, el script imprime en pantalla las instrucciones completas de entrega (paso a paso, con la IP del servidor ya detectada). No hace falta memorizarlas, quedan también en el log.

## Cómo entregar el acceso a un tercero

**1. Tú (admin) descargas la llave privada:**

```bash
scp vps-ovh:/home/ubuntu/ssh-keys/felipearciniegas_ed25519 ./felipearciniegas_ed25519
```

**2. Envías ese archivo al usuario por un canal seguro** (gestor de contraseñas compartido, Bitwarden Send, etc. — nunca por email o chat en texto plano).

**3. Instrucciones para el usuario, según su sistema operativo:**

**Linux / macOS:**
```bash
mv felipearciniegas_ed25519 ~/.ssh/
chmod 600 ~/.ssh/felipearciniegas_ed25519
ssh -i ~/.ssh/felipearciniegas_ed25519 felipearciniegas@<ip_vps>
```

**Windows con OpenSSH (PowerShell/Terminal, viene incluido en Windows 10/11):**
```powershell
ssh -i C:\Users\<user>\.ssh\felipearciniegas_ed25519 felipearciniegas@<ip_vps>
```
No requiere conversión, el archivo funciona igual que en Linux.

**Windows con PuTTY (requiere conversión a .ppk):**
1. Descargar PuTTYgen (incluido con PuTTY): https://www.putty.org/
2. Abrir PuTTYgen → Conversions → Import key → seleccionar el archivo recibido
3. Click en "Save private key" → genera `felipearciniegas_ed25519.ppk`
4. En PuTTY: Connection → SSH → Auth → Credentials → cargar el `.ppk`
5. En Session: Host Name = `felipearciniegas@<ip_vps>`, Port 22

**4. Una vez el usuario confirma acceso, limpias la llave del servidor:**

```bash
rm -f /home/ubuntu/ssh-keys/felipearciniegas_ed25519
```

## Permisos del usuario creado

| Acción | Estado |
|---|---|
| Login SSH por contraseña | BLOQUEADO |
| Login SSH como root | BLOQUEADO |
| Sudo (instalar, configurar, todo) | PERMITIDO (auditado) |

Cada comando con sudo queda en el log. Para revisarlo:

```bash
sudo grep sudo: /var/log/auth.log
```

## Por qué sudo completo en vez de restricciones

En vez de bloquear comandos específicos por usuario (lo cual genera fricción al instalar software y es fácil de saltarse con `sudo bash`), todos los usuarios reciben sudo completo. A cambio, cada comando ejecutado con sudo queda registrado con usuario, fecha y comando exacto en `/var/log/auth.log`.

Esto es más simple de mantener y evita bloquear instalaciones legítimas de terceros. Si algo sale mal, se revisa el log para ver exactamente qué se ejecutó y quién lo hizo. La instancia es de ellos, así que el objetivo es trazabilidad, no restricción.
