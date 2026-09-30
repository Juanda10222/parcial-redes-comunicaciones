# INFORME.md — Parcial 2: Despliegue Multi-contenedor

## Sección 1: Topología y Flujo de Información

### Diagrama de arquitectura
```
                Navegador del Usuario
                        │  HTTP :80
                        ▼
                 ┌────────────┐
                 │   nginx    │  (frontend_net)
                 └─────┬──────┘
        ┌──────────────┼──────────────┐
        │ /             │ /jupyter/     │ /grafana/
        ▼               ▼               ▼
   ┌─────────┐     ┌─────────┐     ┌─────────┐
   │ joomla  │     │ jupyter │     │ grafana │
   └────┬────┘     └────┬────┘     └────┬────┘
        │  TCP:5432      │ TCP:5432      │ TCP:5432
        └────────────────┴───────────────┘
                        ▼
                 ┌────────────┐
                 │  database  │  (backend_net, sin salida al host)
                 │ PostgreSQL │
                 └────────────┘
```

### Mecanismo de recolección de métricas
Grafana no procesa archivos de log en crudo: su datasource provisionado (`grafana/provisioning/datasources/datasource.yml`) apunta directamente al servicio `database` por su nombre DNS interno. Al renderizar el dashboard, Grafana ejecuta consultas SQL (`rawSql`) contra las tablas nativas de Joomla (`joom_session`, `joom_users` (prefijo fijado en JOOMLA_DB_PREFIX)), que se actualizan en tiempo real cada vez que un usuario navega el portal a través de Nginx. Así, el flujo de un evento es: **clic del usuario → Nginx → Joomla → escritura en PostgreSQL → lectura periódica de Grafana (cada 30 s) → panel actualizado**.

---

## Sección 2: Análisis del Modelo OSI

### Capa 7 — Aplicación
- **Cabeceras HTTP de Nginx**: `Host` conserva el nombre virtual solicitado por el cliente para que Joomla genere URLs correctas; `X-Forwarded-For` transporta la IP real del cliente (de lo contrario Joomla vería siempre la IP interna de Nginx); `X-Forwarded-Proto` informa si la conexión original fue HTTP o HTTPS, crítico para evitar redirecciones incorrectas.
- **HTTP Upgrade (WebSockets)**: el kernel de Jupyter usa un socket persistente bidireccional. El navegador envía `Connection: Upgrade` y `Upgrade: websocket`; Nginx debe reenviar ambas cabeceras (`proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade";`) para que la conexión HTTP inicial mute a un socket TCP crudo en lugar de cerrarse tras la respuesta.
- **Protocolo de PostgreSQL**: cliente/servidor binario sobre TCP (no HTTP); Joomla y Jupyter actúan como clientes que abren una sesión autenticada (`startup message`, autenticación MD5/SCRAM, luego mensajes `Query`/`RowDescription`/`DataRow`).
- **Logs de Joomla**: se generan en formato de línea de texto (Apache combined log en el contenedor) y, a nivel de aplicación, Joomla también persiste actividad estructurada en tablas SQL (`joom_session`, con prefijo fijo definido en JOOMLA_DB_PREFIX), que es lo que este proyecto explota para el dashboard.

### Capa 4 — Transporte
- **Puertos TCP**: 80 (Nginx, único expuesto al host), 5432 (PostgreSQL, solo en `backend_net`), 8888 (Jupyter, interno), 3000 (Grafana, interno).
- **Conexiones concurrentes/persistentes**: Nginx mantiene *keep-alive* con el navegador, permitiendo múltiples peticiones HTTP en un mismo socket TCP. Hacia PostgreSQL, Joomla no abre una conexión nueva por petición: reutiliza un pool interno de conexiones persistentes, reduciendo el costo del *3-way handshake* y del *SSL/auth handshake* en cada consulta.

### Capa 3 — Red
- **Direccionamiento y aislamiento**: `frontend_net` y `backend_net` son dos subredes bridge distintas administradas por Docker; `database` solo tiene interfaz en `backend_net`, por lo que no posee ruta hacia el host ni hacia Internet — solo es alcanzable por los contenedores conectados a esa misma red.
- **DNS embebido (127.0.0.11)**: cada contenedor recibe un resolver interno de Docker que traduce nombres de servicio (`database`, `joomla`, `jupyter`, `grafana`) a la IP actual asignada dentro de la red bridge correspondiente, evitando IPs fijas y permitiendo que los contenedores se reinicien con IP distinta sin romper la configuración.
- **NAT**: el kernel del host, mediante `iptables`/`netfilter` (reglas `MASQUERADE` que Docker inserta), traduce el tráfico saliente de los contenedores hacia la interfaz física del host, y el mapeo `80:80` implica una regla `DNAT` que redirige el tráfico entrante del host hacia la IP interna del contenedor `nginx`.

### Capa 2 — Enlace de Datos
- **veth y bridges**: por cada contenedor Docker crea un par de interfaces virtuales *veth*; un extremo vive dentro del namespace de red del contenedor (aparece como `eth0`) y el otro se conecta al puente virtual (`br-xxxx`) asociado a `frontend_net` o `backend_net`, actuando el bridge como un switch Capa 2 software.
- **ARP interno**: cuando `joomla` necesita entregar un frame a `database` dentro de `backend_net`, resuelve la MAC correspondiente a la IP de `database` mediante una solicitud ARP broadcast dentro del mismo segmento bridge; el bridge Linux reenvía la respuesta solo al puerto correcto, igual que un switch físico.

---

## Sección 3: Guía de Verificación y Demostración

1. **Joomla**: abrir `http://localhost/` (el sitio ya está instalado automáticamente) y navegar para generar tráfico y nuevas filas en `joom_session`.
2. **Grafana**: abrir `http://localhost/grafana/` → dashboard **"Actividad Joomla / PostgreSQL"** ya cargado → confirmar que el panel de sesiones por hora y el de últimos accesos reflejan la navegación reciente.
3. **Jupyter**: abrir `http://localhost/jupyter/`, abrir `work/analisis_datos.ipynb`, ejecutar todas las celdas (`Run All`) y verificar que la consulta `psycopg2`/`sqlalchemy` a PostgreSQL retorna datos y las gráficas se renderizan sin error.
