# Guía de Instalación y Ejecución – HappyBee

## Requisitos Previos
- Flutter SDK instalado (versión compatible con Dart 3 y Android API 24–36).
- Dispositivo Android físico con depuración USB activada o emulador Android.
- Archivo de configuración `google-services.json` del proyecto Firebase (excluido del repositorio por seguridad).

## Pasos de Instalación desde el Código Fuente
1. Clonar el repositorio:
   `git clone <URL_DE_TU_REPOSITORIO_GITHUB>`
2. Ingresar a la carpeta del proyecto e instalar dependencias:
   `flutter pub get`
3. Ubicar el archivo `google-services.json` dentro de `android/app/`.
4. Ejecutar la aplicación en el dispositivo conectado:
   `flutter run`

## Instalación mediante APK Release
1. Descargar `app-release.apk` desde la sección **Releases** del repositorio en GitHub.
2. Transferir el archivo al dispositivo Android y autorizar la instalación de orígenes desconocidos.
3. Abrir **HappyBee** e iniciar sesión con una cuenta de apoderado