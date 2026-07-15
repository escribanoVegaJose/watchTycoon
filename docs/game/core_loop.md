# Core Loop

Disenar -> Producir -> Vender -> Mejorar reputacion -> Desbloquear mercado.

## Pasos

1. El jugador recibe un pedido o identifica una tendencia.
2. El jugador crea un diseno de reloj con piezas y materiales disponibles.
3. El juego calcula coste, calidad, precio sugerido y ajuste al pedido.
4. El jugador inicia produccion asignando empleados y dias.
5. Al pasar dias, se completa produccion.
6. El jugador entrega pedidos o vende unidades.
7. El jugador gana dinero, reputacion y acceso a mejores opciones.

## Reventa desde el Salón de Lotes

Al ganar un lote, el reloj entra en el inventario. Desde Inventario, el jugador
asigna un precio y pulsa **Colocar en vitrina**; después elige uno de los huecos
libres iluminados de una vitrina instalada. Cada vitrina tiene 3 huecos.
Un reloj expuesto queda disponible para el flujo normal de venta y libera su
hueco al venderse.

## Cierre Mensual

Cada 30 días de juego se cargan los costes operativos del taller: alquiler, luz y agua, tributos y cuotas (abstracción inspirada en obligaciones españolas) y la suma de costes mensuales del personal activo. Los cargos son obligatorios y pueden llevar la tesorería a negativo. En ese estado se suspenden compras e inversiones, pero las ventas y entregas siguen permitidas para recuperar liquidez. No se simulan IVA, IRPF ni declaraciones reales.

## Visitas A La Boutique

La boutique usa dos plazas físicas de visitante para conservar la lectura del
espacio y evitar colas complejas. Los perfiles iniciales son la **Compradora de
regalo** (presupuesto bajo), el **Profesional aspiracional** (presupuesto medio)
y el **Coleccionista exigente** (presupuesto alto).

- La compradora de regalo puede visitar siempre que exista una pieza funcional
  adecuada en vitrina.
- El profesional usa la segunda plaza cuando hay una pieza compatible.
- El coleccionista reemplaza al profesional sólo cada tres días de juego, desde
  reputación 12, con una pieza Premium de calidad 90 o superior y precio entre
  2.000 € y 6.500 €. Si no hay una pieza apta, entra el profesional.

Los estados visuales son: **inactivo**, **mirando**, **acuerdo**, **pago** y
**enfado**. La pieza se reserva durante la negociación; el pago acredita la
venta y el enfado la libera y registra la reseña correspondiente. Las pujas del
Salón de Lotes siguen siendo un canal separado: no usan estos visitantes físicos.

## Principio De Diseno

Cada accion debe tener feedback claro: coste, tiempo, margen, calidad y efecto en reputacion.

## Salón de Lotes

El Salón de Lotes es un canal pequeño de adquisición para la reventa, no un simulador de marketplace. La primera ronda incluye todos los relojes disponibles del catálogo (hasta cuatro); las siguientes los rotan con salida, incremento, estimación orientativa, valoración editorial y rivalidad variable. Las piezas de cuatro estrellas pueden volver de inmediato, las de cuatro y media descansan una ronda y las de cinco estrellas tardan tres rondas en regresar; nunca se deja el Salón vacío. Cada ronda conserva sus precios de salida, incrementos y topes de coleccionistas para que cargar una partida no los vuelva a sortear. La puja líder solo se cobra al ganar.

Cada lote permanece abierto 30 segundos a velocidad normal. Las velocidades x2 y x3 aceleran el contador, las respuestas de coleccionistas y el enfriamiento de la ronda en la misma proporción que el resto de la simulación. Pausar el tiempo también pausa la subasta.

El interés de cada pieza se calcula a partir de su calidad, mecanismo o artesanía, prestigio, estado, rareza y demanda. Ese interés determina cuántos coleccionistas pueden pujar: la mayoría opera con presupuestos modestos cercanos a la estimación baja y, solo en piezas con interés alto, puede aparecer un coleccionista con capacidad premium. Cada presupuesto se sortea al abrir el lote y se conserva al guardar la partida.

La valoración se expresa entre cuatro y cinco estrellas. Calidad relojera, mecanismo (o artesanía y engaste en joyería), prestigio de marca, estado, rareza, demanda y coherencia del precio solicitado afectan el resultado; un precio alto sin respaldo no mejora la valoración. Este atributo técnico se declara en cada lote como una puntuación de 0 a 100.

Las joyas declaran además un `jewelry_technique_id` estable, resuelto desde `data/jewelry/techniques.json`. Estas técnicas describen procesos genéricos de joyería y se guardan con la pieza adquirida; no representan marcas ni denominaciones comerciales.

Su interfaz debe ser editorial y propia, inspirada en la claridad de los mercados de lotes curados, sin copiar marcas, textos, identidad visual ni estructura de servicios de terceros.
