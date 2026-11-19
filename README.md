# MODO

Aplicación móvil de tienda de ropa con catálogo, bolsa de compras, historial de compras y probador virtual.

## Funcionalidades

- **Inicio**: imagen editorial destacada y selección semanal de prendas.
- **Tienda**: catálogo de 40 prendas leído desde Cloud Firestore, con filtros por categoría y estados de carga, vacío y error.
- **Detalle de prenda**: imagen, precio, talles, color, material, calce, cuidados, reseñas y acción de agregar a la bolsa.
- **Probador IA**: capturas frontal y lateral desde cámara o galería, con vista previa y reemplazo. La generación del resultado con IA requiere integrar un servicio externo.
- **Bolsa y checkout de demostración**: cantidades, eliminación, totales calculados desde los precios cargados y persistencia por usuario. No procesa pagos reales.
- **Historial y comprobante**: pedidos de demostración con una boleta sin validez tributaria.
- **Cuenta y accesibilidad**: perfil, cambio de contraseña, texto grande, alto contraste y reducción de movimiento.
- **Tiendas cercanas**: permiso de ubicación en primer plano, distancias calculadas localmente e inventario leído desde Firestore.

## Stack

Flutter y Dart, Firebase Authentication, Cloud Firestore, Google Sign-In, `image_picker`, `camera`, `geolocator`, `permission_handler`, `shared_preferences` y `url_launcher`.

## Requisitos

- Flutter SDK `^3.13.5` (Dart 3).
- Android SDK o Xcode según la plataforma de destino.
- Proyecto de Firebase con Authentication y Cloud Firestore habilitados.

## Configuración

1. Clonar el repositorio y entrar en la carpeta del proyecto.
2. Instalar dependencias:

   ```bash
   flutter pub get
   ```

3. Colocar `android/app/google-services.json` con la configuración del proyecto de Firebase. **Este archivo está excluido de Git**: solicitarlo al equipo y no subirlo al repositorio.
4. Verificar que las colecciones `productos` y `tiendas` existan en Firestore y que las reglas de lectura permitan consultarlas. El proyecto no escribe en Firebase durante las pruebas locales.
5. Si se usa Google Sign-In, configurar los clientes OAuth en Firebase; la configuración de Android incluida no los contiene.

## Ejecutar

```bash
flutter run
```

## Compilar

```bash
flutter analyze
flutter build apk --release
```

El APK se genera en `build/app/outputs/flutter-apk/app-release.apk`.

## Pruebas

```bash
flutter test
```

Las pruebas usan repositorios falsos: no requieren credenciales ni escriben en Firebase. Las acciones de cámara y ubicación requieren un dispositivo físico para su verificación manual.

## Estructura

```
lib/
  main.dart                     pantallas, navegación y estado de la app
  data/                         repositorios de catálogo y tiendas
  models/                       modelos de datos
test/                           pruebas de widgets y repositorios
android/ ios/ web/ ...          configuración por plataforma
```

## Licencia

MIT. Ver [LICENSE](LICENSE).
