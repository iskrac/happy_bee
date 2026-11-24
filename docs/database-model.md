# Modelo de Datos – Cloud Firestore

- **`users/{userId}`:** `email`, `nombre`, `createdAt`.
- **`children/{childId}`:** `nombre`, `edad`, `apoderadoUid`, `createdAt`.
- **`brushing_sessions/{sessionId}`:** `childId`, `apoderadoUid`, `duracionSegundos`, `completada`, `evidencia`, `fecha`.
- **Reglas de Seguridad:** Lectura y escritura restringidas a `request.auth != null` verificando coincidencia con `request.auth.uid`.