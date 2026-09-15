# VPS Automation

Repositorio con scripts y guías para automatizar el aseguramiento y la administración de servidores VPS.

## Por qué este repo

Cada vez que se levanta una VPS nueva hay una serie de tareas repetitivas de seguridad y configuración (actualizar el sistema, crear usuarios, configurar el firewall, etc.). Este repo centraliza esos scripts para no reinventar el proceso cada vez y para que quede documentado cómo y por qué se hace cada cosa.

## Cómo usar este repo

1. Clona el repo en la máquina desde la que administras tus VPS
2. Entra a la carpeta de la automatización que necesites (ver índice abajo)
3. Sigue el `README.md` de esa carpeta, que a su vez enlaza a guías detalladas en su `docs/`
4. Los scripts se suben a la VPS por `scp` y se ejecutan ahí con `sudo bash <script>.sh`

## Índice de automatizaciones

| Automatización | Descripción | Estado |
|---|---|---|
| [`hardening/`](hardening/README.md) | Aseguramiento inicial de una VPS Ubuntu nueva: actualización del sistema, creación de usuarios con acceso solo por llave SSH, y administración del firewall (UFW) | Activo |

Más automatizaciones se irán agregando aquí a medida que se vayan necesitando (backups, monitoreo, despliegue de servicios, etc.).

## Convenciones del repo

- Cada automatización vive en su propia carpeta en la raíz, con su propio `README.md` como punto de entrada
- La documentación extensa de cada automatización va en una subcarpeta `docs/` dentro de esa carpeta
- Los scripts son en bash, pensados para Ubuntu Server, y deben poder ejecutarse de forma idempotente cuando sea posible
- Nunca se sube al repo ninguna llave privada, contraseña o secreto (ver `.gitignore`)
