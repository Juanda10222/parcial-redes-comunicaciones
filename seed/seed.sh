#!/bin/sh
# Inserta el módulo "Infografía Docker" directamente en la base de datos de Joomla.
# Se salta por completo el editor/filtro de contenido de Joomla (de ahí que
# los estilos inline sobrevivan sin tocar configuración manual alguna).
# Corre una vez por cada "docker compose up -d"; es idempotente (borra e inserta de nuevo).

set -e

PREFIX="${JOOMLA_DB_PREFIX:-joom_}"
TABLE_MODULES="${PREFIX}modules"
TABLE_MODULES_MENU="${PREFIX}modules_menu"

export PGPASSWORD="$POSTGRES_PASSWORD"

echo "[seed] Esperando a que Joomla termine su instalación..."
until psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1 FROM \"$TABLE_MODULES\" LIMIT 1" > /dev/null 2>&1; do
  sleep 3
  echo "[seed] Esperando tabla $TABLE_MODULES..."
done

echo "[seed] Joomla listo. Insertando módulo con la infografía..."

HTML_CONTENT=$(cat /seed/infografia.html)

psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<SQL
DELETE FROM "$TABLE_MODULES_MENU" WHERE moduleid NOT IN (SELECT id FROM "$TABLE_MODULES");
DELETE FROM "$TABLE_MODULES" WHERE title = 'Infografia Docker';

INSERT INTO "$TABLE_MODULES"
  (title, content, ordering, position, published, module, access, showtitle, params, client_id, language, asset_id)
VALUES
  ('Infografia Docker',
   \$html\$${HTML_CONTENT}\$html\$,
   1,
   'position-7',
   1,
   'mod_custom',
   1,
   0,
   '{"prepare_content":"0","layout":"_:default","moduleclass_sfx":"","cache":"1","cache_time":"900","cachemode":"static"}',
   0,
   '*',
   0);

INSERT INTO "$TABLE_MODULES_MENU" (moduleid, menuid)
  SELECT id, 0 FROM "$TABLE_MODULES" WHERE title = 'Infografia Docker';
SQL

echo "[seed] Módulo insertado y publicado en 'position-7' para todas las páginas."
