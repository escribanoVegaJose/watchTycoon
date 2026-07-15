# Economia

La economia inicial debe ser simple: coste de materiales + coste de produccion frente a recompensa del pedido o precio de venta.

## Variables Iniciales

- Dinero disponible.
- Coste de pieza.
- Coste de material.
- Dias de produccion.
- Recompensa del pedido.
- Bonificacion por calidad.

## Objetivo

El jugador debe entender rapidamente si un diseno es rentable y si mejora su reputacion.

## Cierre Mensual

Cada 30 días de juego se aplica un cierre obligatorio. Descuenta alquiler,
luz y agua, tributos y cuotas de actividad, y el coste mensual de cada
empleado activo. Los tributos son una abstracción de obligaciones de una
pequeña empresa española; no se simulan IVA, IRPF, Seguridad Social ni
declaraciones reales.

El cierre puede dejar la tesorería en negativo. Mientras el saldo sea menor
que cero se suspenden compras e inversiones, pero las ventas, entregas y
reembolsos siguen permitidos para recuperar liquidez.

Al pulsar el saldo se abre Tesorería, con el resultado del período
(ingresos menos gastos realizados), el beneficio total del último mes cerrado,
su desglose y la previsión detallada del próximo cierre. El beneficio no es el
saldo disponible: el saldo incluye el capital inicial y todos los movimientos
acumulados.
