# Ejecutar el proyecto con Docker

- Requisitos:
  - Docker Desktop instalado y corriendo.

- Primeros pasos:
  - Copia `.env.example` a `.env` si aún no existe:
    - `copy .env.example .env`
  - Asegúrate de estas variables en `.env`:
    - `DB_CONNECTION=mysql`
    - `DB_HOST=mysql`
    - `DB_PORT=3306`
    - `DB_DATABASE=php_test`
    - `DB_USERNAME=root`
    - `DB_PASSWORD=` (vacío)

- Construir y levantar con Docker Compose:
  - `docker compose up -d --build`
  - Esto construye la imagen con el `Dockerfile`, levanta `laravel-app` y `mysql`.

- Inicialización de la aplicación:
  - Generar clave de aplicación (si no está definida):
    - `docker exec laravel-app php artisan key:generate`
  - Ejecutar migraciones:
    - `docker exec laravel-app php artisan migrate --force`

- Acceder a la aplicación:
  - URL: `http://localhost:8080`

- Logs y administración:
  - Ver logs de la app: `docker logs -f laravel-app`
  - Ver logs de MySQL: `docker logs -f mysql`
  - Reiniciar servicios: `docker compose restart`
  - Detener y eliminar servicios: `docker compose down`

- Notas:
  - Los assets se compilan durante el build con Vite y se copian a `public/build`.
  - El contenedor Apache sirve desde `public` y tiene `mod_rewrite` habilitado.
  - Los datos de MySQL persisten en el volumen `db_data`.

## Qué se configuró

- Dockerfile:
  - Imagen base `php:8.2-apache` con extensiones `pdo_mysql`, `pdo_sqlite`, `mbstring`, `bcmath`, `exif`, `gd`, `zip`.
  - Fix de `mbstring` instalando `libonig-dev`.
  - `DocumentRoot` apuntando a `public` y `AllowOverride All` para `public/.htaccess`.
  - Etapas para `composer` y `assets` (Vite) y `composer` disponible en el contenedor final.
- Docker Compose:
  - Servicio `app` construido desde el `Dockerfile`.
  - Servicio `mysql` con `MYSQL_DATABASE=php_test` y contraseña de root vacía permitida.
  - Healthcheck para MySQL y volumen `db_data` para persistencia.
- .env:
  - `DB_HOST` ajustado a `mysql` para conectar desde el contenedor.
- Volúmenes:
  - Montaje raíz del proyecto: `${PWD:-.}:/var/www/html` para ver cambios en caliente.

## Servicios

- `app`:
  - Puerto `8080` en host → `80` en contenedor (Apache).
  - Monta todo el proyecto en `/var/www/html` para reflejar cambios en tiempo real.
  - Composer disponible en el contenedor (`/usr/bin/composer`).
- `mysql`:
  - Imagen `mysql:8.0`, puerto `3306`.
  - Base de datos: `php_test`, usuario `root`, contraseña vacía (permitida).
  - Plugin `mysql_native_password` habilitado.

## Volúmenes y workflow

- Montaje raíz: `${PWD:-.}:/var/www/html`.
- Implicaciones:
  - El `vendor` y `public/build` del contenedor se reemplazan por los del host.
  - Si no tienes `vendor` en tu máquina, ejecuta dentro del contenedor:
    - `docker exec laravel-app composer install --no-dev --prefer-dist --no-interaction`
  - Si cambias CSS/JS y quieres HMR, añade un servicio separado para `vite` (`npm run dev`) o ejecuta en tu host.

## Comandos Artisan útiles

- Generar clave de la app:
  - `docker exec laravel-app php artisan key:generate`
- Migraciones:
  - Crear migración:
    - `docker exec laravel-app php artisan make:migration create_posts_table --create=posts`
  - Ejecutar migraciones:
    - `docker exec laravel-app php artisan migrate --force`
  - Revertir la última migración:
    - `docker exec laravel-app php artisan migrate:rollback --step=1`
  - Reiniciar base (cuidado, borra datos):
    - `docker exec laravel-app php artisan migrate:fresh --seed`
- Controladores:
  - Crear controlador simple:
    - `docker exec laravel-app php artisan make:controller PostController`
  - Crear controlador resource:
    - `docker exec laravel-app php artisan make:controller PostController --resource`
- Modelos:
  - Crear modelo con migración y controlador resource:
    - `docker exec laravel-app php artisan make:model Post -mcr`
- Seeders:
  - Crear seeder:
    - `docker exec laravel-app php artisan make:seeder PostSeeder`
  - Ejecutar seeders:
    - `docker exec laravel-app php artisan db:seed`
- Limpiezas de caché:
  - `docker exec laravel-app php artisan config:clear`
  - `docker exec laravel-app php artisan cache:clear`
  - `docker exec laravel-app php artisan route:clear`
  - `docker exec laravel-app php artisan view:clear`

## Procedimientos comunes

- Reconstruir imagen (cuando cambie el `Dockerfile` o dependencias):
  - `docker compose up -d --build`
- Reiniciar servicio para aplicar cambios de `docker-compose.yml`:
  - `docker compose restart app`
- Reinstalar dependencias dentro del contenedor (si `vendor` no existe en host):
  - `docker exec laravel-app composer install --no-dev --prefer-dist --no-interaction`
- Compilar assets (si cambiaste frontend y quieres rebuild en imagen):
  - En host: `npm run build` y sirve con Apache.
  - O reconstruye imagen: `docker compose up -d --build`.

## Resolución de problemas

- Error `SQLSTATE[HY000] [2002] Connection refused`:
  - Usa `DB_HOST=mysql` en `.env` dentro de contenedores.
  - Verifica que MySQL esté `healthy`: `docker ps` y `docker logs mysql`.
- Error de build `oniguruma` para `mbstring`:
  - Se resolvió instalando `libonig-dev` en el contenedor.
- `version` obsoleto en `docker-compose.yml`:
  - Compose moderno ignora `version: "3.8"`. Puede removerse.
- Permisos de `storage` y `bootstrap/cache`:
  - La imagen ajusta `chown` y `chmod`. Si montas desde host, asegúrate de no restringir permisos.
