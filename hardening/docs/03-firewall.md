# Paso 3: Administrar el firewall

Script: [`03-firewall-manager.sh`](../03-firewall-manager.sh)

```bash
sudo bash 03-firewall-manager.sh
```

Menú interactivo:

| Opción | Acción |
|---|---|
| 1 | Ver estado del firewall |
| 2 | Habilitar UFW |
| 3 | Deshabilitar UFW |
| 4 | Abrir un puerto (TCP/UDP) |
| 5 | Cerrar un puerto |
| 6 | Permitir acceso desde una IP |
| 7 | Bloquear una IP |
| 8 | Ver reglas activas (numeradas) |
| 9 | Eliminar una regla |
| 10 | Aplicar perfil de seguridad base |
| 11 | Resetear firewall |

## Perfil de seguridad base (opción 10)

- Política: denegar entrada, permitir salida
- Abre puerto 22 (SSH), 80 (HTTP), 443 (HTTPS)
- Habilita logging

## Notas

- El firewall manager solo puede ejecutarlo `ubuntu` o `root` (usuarios creados con `02-create-user.sh` tienen sudo completo, así que también pueden administrarlo si es necesario)
- OVH puede tener reglas de firewall adicionales en su panel (Network > Firewall). Revisa ahí también si algo no conecta como esperas.
