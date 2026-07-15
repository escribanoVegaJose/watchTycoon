# Cliente clásico

El proyecto conserva un único nodo físico `Actors/Customer`. `VisitorNegotiationManager`
selecciona un perfil y llama a `CustomerVisitor.set_visitor_profile(profile)` antes de
iniciar o restaurar la visita. El `visual_id` validado por `DataRegistry` decide el set:

- `classic_medium` → `classic_customer`: `classic_customer_idle.glb` y
  `classic_customer_walk.glb`.
- `practical_low` y `premium_collector` → `standard_customer`: assets actuales
  `customer_idle.glb` y `customer_walk.glb`.

`classic_customer_run.glb` y `classic_customer_inspect.glb` están instanciados como
`ClassicRunVisual` y `ClassicInspectVisual` en `Customer.tscn`, ocultos y preparados
para estados futuros. La versión actual no crea estados nuevos ni altera la máquina de ventas:
las transiciones existentes sólo alternan idle/walk.
