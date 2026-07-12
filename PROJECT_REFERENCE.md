# Watchmaker Tycoon

Juego 2D de gestion donde el jugador construye una marca de relojeria de lujo desde un taller pequeno hasta una maison internacional.

## Vision

El jugador no solo fabrica relojes: construye deseo, reputacion y una marca premium. Cada decision debe sentirse vinculada a artesania, precision, materiales, margen y posicionamiento en el mercado.

## Core Loop

1. Recibir pedido o detectar tendencia.
2. Disenar reloj.
3. Elegir piezas y materiales.
4. Producir unidades.
5. Vender o entregar pedido.
6. Ganar dinero y reputacion.
7. Desbloquear mejores piezas, empleados y mercados.

## Tono

Lujo, artesania, precision, marca, reputacion y deseo.

## MVP Inicial

- 1 taller.
- 10 piezas.
- 4 materiales.
- 3 empleados.
- 5 pedidos.
- 1 reputacion global.
- 1 boton pasar dia.
- 1 sistema de produccion.
- 1 sistema de entrega de pedidos.

## Fuera Del MVP

- 3D.
- Marcas reales.
- Subastas complejas.
- Arbol tecnologico grande.
- Multijugador.
- Economia global dinamica avanzada.

## Arquitectura Objetivo

- Autoloads para estado global, eventos, datos, tiempo y guardado.
- Managers de gameplay separados de la UI.
- Escenas UI desacopladas que reaccionan a eventos.
- Datos en `data/` para piezas, materiales, empleados, pedidos y segmentos.
- Guardado en `user://save_01.json`.
