# INFORME.md. Parcial 2. Despliegue Multi-contenedor

## Sección 1: Topología y Flujo de Información

### Diagrama de arquitectura
```
                Navegador del Usuario
                        │  HTTP :80
                        ▼
                 ┌────────────┐
                 │   nginx    │  
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
                 │  database  │  (sin salida al host)
                 │ PostgreSQL │
                 └────────────┘
```

### Mecanismo de recolección de métricas
Grafana no procesa archivos de registro en crudo. Su fuente de datos apunta directamente al servicio de base de datos por su nombre en el sistema de nombres de dominio interno. Al renderizar el tablero, Grafana ejecuta consultas directas contra las tablas nativas de Joomla, las cuales se actualizan en tiempo real cada vez que un usuario navega el portal a traves de Nginx. El flujo de un evento inicia con la interaccion del usuario, pasa por Nginx, llega a Joomla, realiza la escritura en PostgreSQL, continua con la lectura periodica de Grafana cada treinta segundos y finaliza en el panel actualizado.

---

## Sección 2: Análisis del Modelo OSI

### Capa 7 — Aplicación
Cabeceras HTTP de Nginx. La cabecera Host conserva el nombre virtual solicitado por el cliente para que Joomla genere direcciones correctas. La cabecera X Forwarded For transporta la direccion real del cliente, de lo contrario Joomla veria siempre la direccion interna de Nginx. La cabecera X Forwarded Proto informa si la conexion original fue HTTP o HTTPS, lo cual evita redirecciones incorrectas.

Modificacion de conexion HTTP en WebSockets. El nucleo de Jupyter usa un conector persistente bidireccional. El navegador envia las cabeceras requeridas y Nginx debe reenviar ambas cabeceras para que la conexion HTTP inicial cambie a un conector TCP crudo en lugar de cerrarse tras la respuesta.

Protocolo de PostgreSQL. Es un protocolo cliente servidor binario sobre TCP y no sobre HTTP. Joomla y Jupyter actuan como clientes que abren una sesion autenticada con un mensaje de inicio, autenticacion y posteriores mensajes de consulta o envio de datos.

Registros de Joomla. Se generan en formato de linea de texto en el contenedor. A nivel de aplicacion, Joomla tambien persiste actividad estructurada en tablas de la base de datos, lo cual aprovecha este proyecto para el tablero.

### Capa 4 — Transporte
Puertos TCP. Se utiliza el puerto 80 para Nginx como unico expuesto al equipo principal, el puerto 5432 para PostgreSQL solo en la red trasera, el puerto 8888 para Jupyter interno y el puerto 3000 para Grafana interno.

Conexiones concurrentes y persistentes. Nginx mantiene conexiones activas con el navegador, lo cual permite multiples peticiones HTTP en un mismo conector TCP. Hacia PostgreSQL, Joomla no abre una conexion nueva por peticion, sino que reutiliza un grupo interno de conexiones persistentes, reduciendo el costo de la negociacion inicial y de autenticacion en cada consulta.

### Capa 3 — Red
Direccionamiento y aislamiento. La red frontal y la red trasera son dos subredes distintas administradas por Docker. El servicio de base de datos solo tiene interfaz en la red trasera, por lo que no posee ruta hacia el equipo principal ni hacia Internet, siendo alcanzable unicamente por los contenedores conectados a esa misma red.

Sistema de nombres de dominio embebido. Cada contenedor recibe un resolvedor interno de Docker que traduce nombres de servicio a la direccion asignada dentro de la red correspondiente, evitando direcciones fijas y permitiendo que los contenedores se reinicien con direcciones distintas sin romper la configuracion.

Traduccion de direcciones de red. El nucleo del equipo principal traduce el trafico saliente de los contenedores hacia la interfaz fisica. El mapeo del puerto 80 implica una regla que redirige el trafico entrante hacia la direccion interna del contenedor Nginx.

### Capa 2 — Enlace de Datos
Interfaces virtuales y puentes. Por cada contenedor Docker crea un par de interfaces virtuales. Un extremo vive dentro del espacio de nombres de red del contenedor y el otro se conecta al puente virtual asociado a la red frontal o trasera, actuando el puente como un conmutador de Capa 2 por software.

Protocolo de resolucion de direcciones interno. Cuando Joomla necesita entregar datos a la base de datos dentro de la red trasera, resuelve la direccion fisica correspondiente a la direccion IP mediante una solicitud por difusion dentro del mismo segmento. El puente reenvia la respuesta solo al puerto correcto, igual que un conmutador fisico.

---

## Sección 3: Guía de Verificación y Demostración

1. **Joomla**: abrir `http://localhost/` y navegar para generar tráfico y nuevas filas en `joom_session`.
2. **Grafana**: abrir `http://localhost/grafana/` → dashboard **"Actividad Joomla / PostgreSQL"** ya cargado → confirmar que el panel de sesiones por hora y el de últimos accesos reflejan la navegación reciente.
3. **Jupyter**: abrir `http://localhost/jupyter/`, abrir `work/analisis_datos.ipynb`, ejecutar todas las celdas (`Run All`)
