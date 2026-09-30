# Parcial 2 - Comunicaciones (Ingeniería Mecatrónica)

## Arranque (zero-touch)
```bash
git clone <URL_DEL_REPOSITORIO>
cd parcial-redes-comunicaciones
cp .env.example .env
docker compose up -d
```

## Acceso a los servicios (vía Nginx, puerto 80)
| Servicio | URL |
|---|---|
| Joomla (CMS) | http://localhost/ |
| Jupyter Lab | http://localhost/jupyter/ |
| Grafana | http://localhost/grafana/ (login: admin / admin123 o anónimo) |

## Primer uso (sin instalación manual)
Joomla se instala automáticamente por variables de entorno (`JOOMLA_ADMIN_*` en `.env`) — **no aparece ningún wizard**.

1. `http://localhost/` ya carga el sitio instalado. Backend: `http://localhost/administrator` con `admin` / `AdminJoomla2026!`. Prefijo de tablas fijo: `joom_` (valores por defecto de `.env.example`).
2. En `http://localhost/jupyter/`, abrir `work/analisis_datos.ipynb` y ejecutar todas las celdas.
3. En `http://localhost/grafana/`, el dashboard **"Actividad Joomla / PostgreSQL"** ya está cargado (datasource y paneles provisionados automáticamente; login anónimo habilitado, no requiere crear cuenta).

## Persistencia entre reinicios
```bash
docker compose stop     # apaga sin borrar nada
docker compose start    # vuelve a prender, todo sigue instalado y logueado donde aplique

docker compose down     # apaga y quita contenedores, PERO conserva los volúmenes (BD, Joomla, Grafana)
docker compose up -d    # todo sigue intacto, no vuelve a instalar nada

docker compose down -v  # ⚠️ SOLO usar esto si quieres borrar todo desde cero
```

## Redes
- `frontend_net`: nginx, joomla, jupyter, grafana.
- `backend_net`: joomla, database, jupyter, grafana (database sin salida a frontend/host).

Ver `INFORME.md` para el análisis técnico completo (topología y modelo OSI).
