# Android / Play Store

Base inicial pensada para movil en horizontal.

## Decisiones iniciales

- Orientacion: landscape.
- Resolucion logica: 1280x720.
- Stretch: `canvas_items` + `expand` para adaptarse a moviles y tablets.
- Render: `mobile` para priorizar rendimiento.
- Interaccion: botones grandes de 64 px de alto para tactil.
- Build inicial: Android App Bundle `.aab`.

## Antes de publicar

1. Cambiar `package/unique_name` en `export_presets.cfg` si quieres otro identificador definitivo.
2. Configurar Android SDK desde Godot.
3. Crear keystore de release y asignarlo en el preset de exportacion.
4. Crear iconos reales en `assets/icons/`.
5. Probar en dispositivo real, no solo en editor.

## Nombre de paquete provisional

```text
com.watchmakertycoon.game
```

No usar marcas reales de relojeria en nombre, textos ni assets.
