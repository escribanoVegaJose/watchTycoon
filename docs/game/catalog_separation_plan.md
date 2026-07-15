# Plan de Catálogos

## Objetivo

Separar con claridad los artículos que se comercian de los elementos que se construyen en la boutique. Un reloj o una joya nunca debe aparecer como elemento construible; una vitrina o un mostrador nunca debe formar parte del catálogo de relojería.

La partida solo guarda las unidades y construcciones que pertenecen al jugador. Las definiciones de catálogo son datos estáticos del proyecto.

## A. Catálogo de Comercio

**Propósito:** oferta de productos de relojería y joyería que pueden adquirirse, exponer y venderse.

**Ruta prevista:** `data/catalog/commerce/`

**Primer archivo:** `watches.json`

Cada definición contiene un `definition_id` estable, nombre, descripción, modelo 3D, valoración y los datos de su canal de adquisición. No contiene posición en la tienda, precio pagado por el jugador ni estado de venta.

### Relojes iniciales

| ID | Reloj | Tipo | Estimación | Salida | Incremento | Precio sugerido |
|---|---|---|---:|---:|---:|---:|
| `nexora_b` | Nexora-B | Campo · Funcional | 140–220 € | 80 € | 10 € | 190 € |
| `orvyn_timeless` | Orvyn Timeless | Clásico · Funcional | 190–250 € | 120 € | 10 € | 230 € |
| `vaudenne_cl1` | Vaudenne Cl1 | Contemporáneo · Premium | 2.800–4.000 € | 2.000 € | 100 € | 3.400 € |
| `aurevant_classic_moon` | Aurevant Classic Moon | Campo · Premium | 4.600–6.200 € | 3.300 € | 100 € | 5.300 € |
| `arctalon_chronoprec` | Arctalon ChronoPrec | Cronógrafo de campo · Premium | 3.600–5.100 € | 2.600 € | 100 € | 4.400 € |

Los cuatro se ofrecen a través del **Salón de Lotes**. Una adjudicación crea una unidad de inventario que referencia al `definition_id`; no altera el catálogo.

### Joyas y futuras categorías

Las joyas se definen en su propio catálogo de lotes (`data/jewelry/auction_lots.json`) con la categoría `jewelry`; no se crean dentro del archivo de relojes ni de construcción. El futuro `DataRegistry` migrará ambos catálogos a `data/catalog/commerce/` sin mezclar sus definiciones.

## B. Catálogo de Construcción

**Propósito:** objetos para colocar, mover o demoler en el taller/boutique.

**Datos actuales:**

- `data/facilities/counter_01.tres` — Punto de venta.
- `data/facilities/display_counter_01.tres` — Mostrador de exposición.
- `data/furniture/window_wood_01.tres` — Ventana de madera y cristal.

Estos Resources conservan su propio flujo de colocación 3D, huella, restricciones y reembolso. No se mezclarán con `data/catalog/commerce/` ni con las pantallas de compra/venta de relojería.

## C. Inventario de la Partida

**Propósito:** registrar únicamente activos que el jugador ya ha conseguido.

- Una unidad de reloj/joya guarda `instance_id`, `definition_id`, coste de adquisición, día, ubicación y precio de venta.
- Una instalación guarda `installation_id`, `item_id`, coste pagado y transformación 3D.
- El nombre, descripción, modelo y estimación se resuelven desde el catálogo mediante su ID; no se duplican en el guardado.

## Implementación por fases

1. Crear `DataRegistry` para cargar y consultar el catálogo comercial por `definition_id`.
2. Migrar los tres relojes actuales desde `data/watches/auction_lots.json` a `data/catalog/commerce/watches.json` sin cambiar sus precios ni modelos.
3. Hacer que `AuctionManager` consulte el registro en vez de abrir un JSON propio.
4. Convertir las unidades de reloj guardadas en referencias a catálogo, manteniendo una migración para partidas existentes.
5. Mantener los Resources de construcción y sus controladores fuera de este flujo; su integración con un registro común solo se considerará si aparece una necesidad real de búsqueda o filtrado global.

## Criterios de aceptación

- Añadir un reloj requiere una nueva definición en `watches.json`, sin tocar la UI de comercio ni la lógica de subasta.
- Añadir una joya requiere una nueva definición en `jewelry.json`, sin afectar a construcción.
- Añadir un mueble o instalación usa sus Resources de construcción y no aparece en el Salón de Lotes.
- Una partida guardada referencia productos por ID y conserva sus unidades aunque se guarde y cargue.
- Ningún producto comercial usa marcas reales de relojería.
