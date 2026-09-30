FROM jupyter/minimal-notebook:latest

# Dependencias instaladas en el build de la imagen, no en el notebook en runtime.
# Evita el conflicto entre el entorno conda base y paquetes pip instalados
# a mitad de una sesión de kernel (causa del AttributeError con SQLAlchemy).
# --upgrade es obligatorio: la imagen base ya trae una versión vieja de pandas
# (vía conda) incompatible con SQLAlchemy 2.x; sin --upgrade, pip la deja intacta.
RUN pip install --no-cache-dir --upgrade \
    "sqlalchemy>=2.0" \
    "pandas>=2.0" \
    psycopg2-binary \
    matplotlib
