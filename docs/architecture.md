# Arquitectura actual

Mapa técnico de los sistemas existentes. Las reglas de programación y organización
están en `AGENTS.md`.

Actualizar este documento en la misma tarea cuando cambien significativamente
responsabilidades, escenas principales, comunicación, ownership o dependencias.
Los cambios internos pequeños que no alteran la arquitectura no requieren actualizarlo.

## Project structure

```text
scenes/
  app/main.tscn
  player/player.tscn
  world/movement_test.tscn
  items/world_item.tscn
  ui/inventory_ui.tscn
  ui/inventory_slot.tscn
  ui/item_drag_preview.tscn
scripts/
  app/main.gd
  player/{wheelchair_body, wheelchair_input, wheelchair_debug, pickup_interactor}.gd
  world/movement_test.gd
  items/{item_definition, world_item}.gd
  inventory/{inventory, item_stack, equipment}.gd
  ui/{cursor_controller, inventory_ui, inventory_slot}.gd
resources/items/{test_item, test_ammo, test_weapon}.tres
Sprites/Cursor/{Cursor Default, Cursor Abierto, Cursor Agarrando}.png
docs/architecture.md
```

## Scene ownership

- **Main** compone MovementTest, CursorController y un CanvasLayer HUD con
  InventoryUI. Inyecta Inventory y Equipment de PickupInteractor en InventoryUI.
- **MovementTest** posee Player, seis obstáculos estáticos, cuatro bordes y tres
  WorldItem. Conecta sus señales pickup_requested al PickupInteractor del Player.
- **Player** tiene un RigidBody2D raíz, Sprite2D, CollisionShape2D, WheelchairInput,
  Camera2D, Debug y PickupInteractor. La cámara sigue su posición sin rotar.
  Debug recibe una referencia explícita a WheelchairInput.
  PickupInteractor posee Inventory y Equipment; la física no conoce esos estados.
- **WorldItem** es un Area2D con colisión clickeable, marcador y Sprite2D.
  Recibe ItemDefinition por Inspector; no necesita conocer al jugador ni la UI.
- **InventoryUI** es un Control de pantalla con botón Mochila, panel ocultable,
  GridContainer y un único WeaponSlot. Instancia InventorySlot según la capacidad.
  Los controles viven bajo HUD, independientes de la cámara.
- **InventorySlot** es un PanelContainer con icono, nombre y cantidad. Inicia y
  recibe drag & drop nativo; solicita operaciones a los modelos, sin almacenarlos.

## Script responsibilities

| Script | Responsabilidad | No hace |
| --- | --- | --- |
| main.gd | Componer UI, modelos y contexto semántico del cursor. | Reglas de pickup o almacenamiento. |
| wheelchair_body.gd | Fuerza longitudinal, torque, agarre lateral e impulso externo. | UI, pickup o reglas de inventario. |
| wheelchair_input.gd | Tracking local del mouse, drag dentro del radio y prioridad de clicks. | Aplicar fuerzas o recoger items. |
| wheelchair_debug.gd | Dibujar radio, cursor, inicio del gesto y frente. | Reglas físicas. |
| pickup_interactor.gd | Poseer Inventory/Equipment, validar distancia y recoger cantidades. | Dibujar UI o mover la silla. |
| item_definition.gd | Datos estáticos, máximo de stack y tipo de equipo. | Estado mutable por instancia. |
| item_stack.gd | Valor runtime inmutable: definición y cantidad. | UI o drag preview. |
| inventory.gd | Slots ordenados, stacks, inserción, merge, swap y consulta. | SceneTree, UI o posición del jugador. |
| equipment.gd | Un arma equipada y transferencias verificadas con Inventory. | Labels, iconos o nodos UI. |
| world_item.gd | Mostrar su definición y emitir una solicitud al recibir click. | Inventario o búsqueda de Player. |
| cursor_controller.gd | Aplicar cursor hardware según contexto semántico. | Reglas de WorldItem, UI o silla. |
| inventory_ui.gd | Observar modelos, refrescar slots y abrir/cerrar el panel. | Ser fuente de verdad de los items. |
| inventory_slot.gd | Mostrar stack e invocar APIs nativas de drag/drop. | Usar o poseer items. |
| movement_test.gd | Dibujar la pista a partir de sus colisiones estáticas. | Reglas de inventario. |

## Data models

- **ItemDefinition**: Resource con display_name, icon, max_stack_size y el enum
  EquipmentSlotType (NONE o WEAPON). Se trata como inmutable durante el juego.
  No tiene balas cargadas, durabilidad, efectos ni estado particular.
- **ItemStack**: RefCounted inmutable con ItemDefinition y quantity. Cada stack
  cumple 1 <= quantity <= max_stack_size.
- **Inventory**: RefCounted independiente del SceneTree, creado por cada
  PickupInteractor. Mantiene un array privado de referencias a definiciones
  (null significa slot vacío). La capacidad se fija al crearlo; el Inspector del
  PickupInteractor configura inventory_capacity para el siguiente inicio.
  try_add llena primero stacks compatibles y luego slots vacíos; devuelve las
  unidades insertadas. move realiza move, merge parcial/completo o swap.
  Ocultar o reconstruir la vista no modifica este estado.
- **Equipment**: RefCounted con un único ItemStack de arma. Es el estado lógico
  del equipamiento; valida compatibilidad y coordina intercambios con Inventory.

## Communication

```text
WorldItem --pickup_requested--> PickupInteractor
                                  |
                            valida distancia
                                  |
                         Inventory.try_add(quantity)
                                  |
          éxito total: WorldItem.queue_free; parcial: reduce quantity

Inventory --changed--> InventoryUI --> InventorySlot.refresh
Equipment --changed--> InventoryUI --> WeaponSlot + indicador
Main --------bind_inventory--------^

WheelchairInput --consume_motion--> WheelchairBody --> fuerzas/torque
        |
        +--> WheelchairDebug (lectura)
```

pickup_distance es independiente de interaction_radius. Un item lejano o sin
espacio permanece en el mundo. Se rechazan solicitudes de nodos ya pendientes de
eliminación para impedir recogidas duplicadas en el mismo frame.

## Input flow

1. La GUI consume los clicks sobre Mochila, el panel y los slots mediante
   mouse_filter STOP. El Control de pantalla y los elementos decorativos usan
   IGNORE para que el espacio libre siga disponible al gameplay.
2. WheelchairInput usa _unhandled_input para comenzar/acumular el drag.
   _input solo observa liberación del botón o salida del radio para finalizarlo.
3. El picking físico de Godot sucede después de _unhandled_input. Antes de iniciar
   un drag, WheelchairInput consulta un punto sobre la capa física **2**, reservada
   para items clickeables, y deja esos eventos sin consumir. WorldItem recibe el
   click mediante el _input_event estándar de Area2D y emite pickup_requested.
   La consulta no recoge items ni calcula distancias de pickup.
4. Player y obstáculos usan la capa física 1. WorldItem usa capa 2 y máscara 0:
   es clickeable pero no bloquea el movimiento del cuerpo.

Los slots usan _get_drag_data, _can_drop_data y _drop_data de Control. Iniciar o
cancelar drag no modifica modelos. Drop entre slots mueve a vacío, fusiona el mismo
item hasta max_stack_size o intercambia items diferentes. Drop inválido o fuera de
la UI conserva el origen. Abrir la mochila no pausa el juego.

## Cursor

CursorController es propiedad de Main y recibe contextos semánticos mediante
set_context(owner, available, active). GRABBING tiene prioridad sobre
INTERACTABLE y DEFAULT. Los contextos usan referencias débiles: borrar o salir de
un nodo no deja el cursor bloqueado.

```text
Main traduce hover de UI, WorldItem y WheelchairInput
                         |
                         v
                  CursorController
                         |
                         v
             Input.set_custom_mouse_cursor
```

Las tres texturas y hotspots se asignan al CursorController en
scenes/app/main.tscn desde el Inspector. Las texturas actuales están en
Sprites/Cursor/. El Button Mochila admite su propiedad icon nativa desde
InventoryUI.tscn. Paneles, tamaños, labels e icon presentation se editan desde
las escenas UI y su Inspector; los scripts no construyen la interfaz visual.

Los WorldItem mantienen el cursor DEFAULT incluso dentro de pickup_distance.
Solo los items recogibles interceptan el inicio del gesto mediante la validación
de PickupInteractor; un item fuera de rango no afecta el cursor ni el movimiento.
INTERACTABLE se usa para el gesto de movimiento y controles de UI.

## Current architectural boundaries

- **Data**: ItemDefinition, ItemStack, Inventory y Equipment no dependen de
  nodos ni presentación.
- **Gameplay**: cuerpo, tracking de intención, WorldItem y PickupInteractor.
  El interactor transforma solicitudes de pickup en cambios del modelo.
- **Presentation**: Debug, CursorController, dibujo de la pista e
  InventoryUI/InventorySlot.
  WorldItem posee su representación provisional junto con su área de interacción.
- **Composición**: Main y las conexiones de MovementTest suministran dependencias
  explícitas. No hay autoloads, managers ni bus global.

## Known extension points

La definición compartida está separada de sus representaciones de mundo y UI.
El estado individual futuro de un item no debe añadirse al Resource compartido.
Los slots son Control y usan las APIs nativas de drag & drop. El ItemDefinition
compartido permanece separado de ItemStack para que futuros estados individuales
no entren al Resource compartido. No hay división de stacks, uso, drop al mundo,
recargas ni sistema de armas activo.
