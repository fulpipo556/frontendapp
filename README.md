# flutterloginmysql

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Verificación por correo

El registro deja la cuenta pendiente hasta que el usuario confirma un código de seis dígitos o pulsa el enlace enviado por correo. Ambos vencen después de 15 minutos. El backend necesita acceso a un servidor SMTP para enviar el mensaje.

Configura estas variables en `backend/.env` (puedes usar `.env.example` como referencia):

- `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER` y `SMTP_PASSWORD`: datos SMTP del proveedor de correo.
- `MAIL_FROM`: dirección que aparecerá como remitente.
- `API_PUBLIC_URL`: URL pública del backend usada en el enlace del correo. Para desarrollo local puede ser `http://localhost:3000`; en producción debe ser una URL HTTPS accesible desde el dispositivo que recibe el mensaje.

Reinicia el backend después de configurar estas variables. Sin configuración SMTP, el registro responde con un error y no crea una cuenta activa.

Para Gmail, usa `smtp.gmail.com`, puerto `587` y `SMTP_SECURE=false`. `SMTP_USER` y `MAIL_FROM` deben ser tu dirección Gmail. `SMTP_PASSWORD` debe ser una contraseña de aplicación de Google, no la contraseña habitual de tu cuenta. No la compartas en el chat ni la subas al repositorio.

## Publicar el backend para la APK

La APK no puede usar `localhost` ni `10.0.2.2`: esas direcciones solo sirven para desarrollo local. El backend incluido usa Node.js, MySQL y almacenamiento de archivos, por lo que se debe publicar como un servicio de contenedor (por ejemplo, Google Cloud Run) y conectarlo a una instancia MySQL administrada (por ejemplo, Cloud SQL).

En `backend/` se incluyen `Dockerfile`, `.dockerignore` y `.env.production.example`. Configura las variables de ese ejemplo en Cloud Run como secretos o variables protegidas. No subas `backend/.env` ni credenciales al repositorio. Si el backend ya fue ejecutado con credenciales SMTP compartidas, revoca esa contraseña de aplicación y genera una nueva.

Después de desplegar, comprueba `https://TU_URL/api/health`. La respuesta debe indicar que el servidor está activo. Usa la URL HTTPS completa terminada en `/api` al compilar la APK:

```powershell
flutter build apk --release --dart-define=API_URL=https://TU_URL/api
```

La misma variable se usa para todas las llamadas API y para los archivos cargados. La configuración Firebase de Android ya está incluida en `android/app/google-services.json`; Firebase no reemplaza al backend Node.js ni a MySQL.

## Roles

Las cuentas nuevas y las cuentas existentes se consideran docentes por defecto. Para dar acceso de administrador, agrega su correo en `ADMIN_EMAILS` en `backend/.env`; puedes indicar varios separados por comas. El rol no se elige en el formulario de registro. Después de cambiar esta lista, la persona debe iniciar sesión de nuevo. El panel de administración lista las cuentas y la API también protege ese endpoint por rol.

## Invitación de usuarios desde administración

La importación desde Word crea cuentas de docentes sin enviar correos. Si se vuelve a importar un correo existente, actualiza el nombre del docente cuando haya cambiado o lo reporta como ya registrado si no hay cambios; las cuentas de administrador no se modifican. El resultado indica cuántos son nuevos, actualizados, ya registrados o tuvieron errores. Después, se puede enviar la invitación a un docente desde su menú de opciones o enviar invitaciones individuales a todos los docentes que aún no configuraron su contraseña. Al agregar un usuario manualmente, el sistema sigue enviando su invitación automáticamente. Cada invitación contiene un enlace de un solo uso, válido por 24 horas, para crear una contraseña personal. El enlace abre la página de configuración del backend; por eso `API_PUBLIC_URL` debe ser accesible desde el dispositivo de cada usuario.

## Carga de agenda desde Word

En la pestaña **Subir**, la vista previa y la carga de una agenda DOCX reconocen las columnas **Fecha**, **Hora**, **Actividad**, **Responsable**, **Lugar** y **Modalidad**. Cada fila de la tabla se guarda como una actividad individual; las fechas combinadas de varias filas se aplican a cada actividad correspondiente. Responsable y lugar se conservan y aparecen junto a la actividad en las vistas de administración y docentes.

## Talleres y asignación de docentes

En la pestaña **Talleres** del panel de administración se crean los títulos y luego se asignan uno o varios docentes a cada taller. Un docente puede participar en varios talleres. Las asignaciones se pueden editar y se eliminan junto con el taller o la cuenta del docente relacionada.
