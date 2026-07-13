# Direccion Artistica

3D elegante, premium, negro, dorado, crema y acero. La estructura base de la joyeria se construye en Godot con geometria simple y materiales editables; los modelos IA se reservan para props especiales.

## Inspiracion

- Boutiques de lujo.
- Talleres artesanales.
- Relojeria suiza.
- Vitrinas premium.
- Catalogos editoriales de producto.

## Reglas

- No usar marcas reales.
- No incluir textos generados dentro de imagenes IA.
- Evitar exceso de brillo barato o estetica casino.
- Priorizar materiales nobles, precision y calma visual.

## Pipeline Meshy / IA 3D

1. Generar modelos especiales en Meshy.
2. Guardar bruto en `assets/meshy/raw/`.
3. Limpiar escala, pivote, materiales y geometria en Blender si hace falta.
4. Guardar editado en `assets/meshy/edited/`.
5. Exportar GLB optimizado.
6. Guardar final en `assets/meshy/godot_ready/`.

## Prompts Base

### Prop De Joyería

```text
luxury jewelry boutique prop, elegant 3D game asset, premium black and gold style, clean PBR materials, optimized geometry, no text, no logos, no brand names, no people
```

### Puerta Premium

```text
luxury jewelry store entrance door, elegant 3D game asset, black metal frame, subtle gold trim, premium boutique style, PBR materials, optimized for game engine, no text, no logos, no brand names
```

### Vitrina

```text
luxury watch display case, elegant 3D game asset, glass and dark metal, subtle gold accents, premium boutique style, PBR materials, optimized for game engine, no text, no logos, no brand names
```
