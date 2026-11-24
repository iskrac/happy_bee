# specs 001 - Autenticacion y Control de Acceso

-**Actor:** Apoderado.
-**Flujo:** Registro con correo/contraseña ("createUserWithEmailAndPassword"), inicio de sesion ("sigInWithEmailAndPassword") y cierre de sesion ("signOut").
-**Seguridad:** Proteccion de rutas mediante " authStateChanges()" y aislamiento de datos por 'uid' en Cloud Firestore.