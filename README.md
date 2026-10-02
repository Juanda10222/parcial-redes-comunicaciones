# Parcial 2 - Comunicaciones 

## Arranque 
```bash
git clone <URL_DEL_REPOSITORIO>
cd parcial-redes-comunicaciones
cp .env.example .env
docker compose up -d
```

## Acceso a los servicios (vía Nginx, puerto 80)
| Servicio | URL |
|---|---|
| Joomla | http://localhost/ |
| Jupyter Lab | http://localhost/jupyter/ |
| Grafana | http://localhost/grafana/ (login: admin / admin123) |

## Primer uso (sin instalación manual)
Joomla se instala automáticamente por variables de entorno (`JOOMLA_ADMIN_*` en `.env`).

1. `http://localhost/` ya carga el sitio instalado. Backend: `http://localhost/administrator` con `admin` / `AdminJoomla2026!`.
2. En `http://localhost/jupyter/`, abrir `work/analisis_datos.ipynb` y ejecutar todas las celdas.
3. En `http://localhost/grafana/`, el dashboard **"Actividad Joomla / PostgreSQL"** ya está cargado (datasource y paneles provisionados automáticamente, no requiere crear cuenta).

## Diseño de la portada (infografía)
El servicio `seed` inserta automáticamente un módulo "Custom HTML" con la infografía de la arquitectura en la posición `main-top`, visible en todas las páginas.


## Redes
- `frontend_net`: nginx, joomla, jupyter, grafana.
- `backend_net`: joomla, database, jupyter, grafana.

Ver `INFORME.md` para el análisis técnico completo.
