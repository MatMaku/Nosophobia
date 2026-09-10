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
  prefabs/player/player.tscn
  prefabs/enemies/enemy_base.tscn
  player/character_visual.tscn
  player/player_vision.tscn
  world/movement_test.tscn
  prefabs/lighting/decorative_light_2d.tscn
  world/visibility_fog.tscn
  prefabs/items/world_item.tscn
  ui/inventory_ui.tscn
  ui/inventory_slot.tscn
  ui/item_drag_preview.tscn
  ui/weapon_reload_ui.tscn
scripts/
  app/main.gd
  player/{wheelchair_body, wheelchair_input, wheelchair_debug, pickup_interactor}.gd
  player/{character_visual, player_vision}.gd
  enemies/enemy_base.gd
  combat/{health_component, firearm_definition}.gd
  world/{movement_test, decorative_light_2d}.gd
  items/{item_definition, world_item}.gd
  inventory/{inventory, item_stack, equipment}.gd
  ui/{cursor_controller, inventory_ui, inventory_slot, world_drop_target}.gd
resources/items/{test_item, test_ammo, test_weapon}.tres
Sprites/Cursor/{Cursor Default, Cursor Abierto, Cursor Agarrando}.png
docs/architecture.md
```

## Scene ownership

- **Main** compone MovementTest, CursorController, fog/VFX y un CanvasLayer HUD con
  InventoryUI, WeaponReloadUI y WorldDropTarget. Inyecta los modelos y coordina
  handoff de input y transferencias de drop sin poseer reglas de inventario.
- **MovementTest** posee Player, obstáculos, bordes, luces y WorldItems de prueba.
  Conecta pickup_requested y crea WorldItems soltados cerca del Player.
- **Player** tiene un RigidBody2D raíz, CharacterVisual, CollisionShape2D, WheelchairInput,
  Camera2D, Debug y PickupInteractor. La cámara sigue su posición sin rotar.
  Debug recibe una referencia explícita a WheelchairInput.
  PickupInteractor posee Inventory y Equipment; la física no conoce esos estados.
  También posee WeaponAim, FirearmController y Muzzle. CharacterVisual recibe
  referencias explícitas al cuerpo y WheelchairInput, que utiliza solo para lectura.
- **WorldItem** es un Area2D con colisión clickeable, marcador y Sprite2D.
  Puede recibir ItemDefinition/cantidad por Inspector o un ItemStack runtime al
  ser soltado; no necesita conocer al jugador ni la UI.
- **InventoryUI** es un Control de pantalla con botón Mochila, panel ocultable,
  GridContainer y un único WeaponSlot. Instancia InventorySlot según la capacidad.
  Los controles viven bajo HUD, independientes de la cámara.
- **InventorySlot** es un PanelContainer con icono, nombre y cantidad. Inicia y
  recibe drag & drop nativo; solicita operaciones a los modelos, sin almacenarlos.
- **WorldDropTarget** es un Control fullscreen ubicado detrás de las UIs. Solo
  acepta drags nacidos en slots normales; los clicks comunes pasan sin consumirse.
- **DecorativeLight2D** compone un PointLight2D con sombra y genera su máscara
  irregular al iniciar. Es iluminación visual reutilizable y no altera PlayerVision.

## Script responsibilities

| Script | Responsabilidad | No hace |
| --- | --- | --- |
| main.gd | Componer UI/modelos, cursor, input handoff y drop al mundo. | Reglas de pickup o almacenamiento. |
| wheelchair_body.gd | Fuerza longitudinal, torque, agarre lateral e impulso externo. | UI, pickup o reglas de inventario. |
| wheelchair_input.gd | Tracking local del mouse, drag dentro del radio y prioridad de clicks. | Aplicar fuerzas o recoger items. |
| wheelchair_debug.gd | Dibujar radio, cursor, inicio del gesto y frente. | Reglas físicas. |
| character_visual.gd | Seleccionar poses de brazos y desplazar texturas de ruedas. | Leer eventos de input o modificar gameplay. |
| weapon_aim_controller.gd | Target, seguimiento angular, sway y dirección final compartida. | Spread, recoil o sistema de salud. |
| weapon_aim_visual.gd | Orientar AimUpperBody/AimMuzzle y desplazar el torso por recoil. | Interpolar una segunda dirección de aim. |
| pickup_interactor.gd | Poseer Inventory/Equipment, validar distancia y recoger cantidades. | Dibujar UI o mover la silla. |
| item_definition.gd | Datos estáticos, máximo de stack y tipo de equipo. | Estado mutable por instancia. |
| item_stack.gd | Valor runtime inmutable: definición y cantidad. | UI o drag preview. |
| inventory.gd | Slots ordenados, stacks, inserción, merge, swap y consulta. | SceneTree, UI o posición del jugador. |
| equipment.gd | Un arma equipada y transferencias verificadas con Inventory. | Labels, iconos o nodos UI. |
| world_item.gd | Mostrar el item, conservar stack runtime y solicitar pickup. | Inventario o búsqueda de Player. |
| cursor_controller.gd | Aplicar cursor hardware según contexto semántico. | Reglas de WorldItem, UI o silla. |
| inventory_ui.gd | Observar modelos, refrescar slots y abrir/cerrar el panel. | Ser fuente de verdad de los items. |
| inventory_slot.gd | Mostrar stack e invocar APIs nativas de drag/drop. | Usar o poseer items. |
| world_drop_target.gd | Solicitar un drop al mundo desde un drag válido. | Instanciar WorldItem o modificar Inventory. |
| decorative_light_2d.gd | Generar máscara irregular y variación temporal sutil. | Visibilidad del jugador o gameplay. |
| movement_test.gd | Dibujar la pista a partir de sus colisiones estáticas. | Reglas de inventario. |

## Data models

- **ItemDefinition**: Resource con display_name, icon, max_stack_size y el enum
  EquipmentSlotType (NONE o WEAPON). Se trata como inmutable durante el juego.
  No tiene balas cargadas, durabilidad, efectos ni estado particular.
- **ItemStack**: RefCounted inmutable con ItemDefinition y quantity. Cada stack
  cumple 1 <= quantity <= max_stack_size.
- **Inventory**: RefCounted independiente del SceneTree, creado por cada
  PickupInteractor. Mantiene un array privado de ItemStack
  (null significa slot vacío). La capacidad se fija al crearlo; el Inspector del
  PickupInteractor configura inventory_capacity para el siguiente inicio.
  try_add llena primero stacks compatibles y luego slots vacíos; devuelve las
  unidades insertadas. try_add_stack conserva el mismo valor runtime cuando entra
  completo y take extrae ese valor exacto. move realiza move, merge o swap.
  Ocultar o reconstruir la vista no modifica este estado.
- **Equipment**: RefCounted con un único ItemStack de arma. Es el estado lógico
  del equipamiento; valida compatibilidad y coordina intercambios con Inventory.

## Communication

```text
WorldItem --pickup_requested--> PickupInteractor
                                  |
                            valida distancia
                                  |
                    Inventory.try_add/try_add_stack
                                  |
          éxito total: WorldItem.queue_free; parcial: reduce quantity

Inventory --changed--> InventoryUI --> InventorySlot.refresh
Equipment --changed--> InventoryUI --> WeaponSlot + indicador
Main --------bind_inventory--------^

InventorySlot --drag nativo--> WorldDropTarget --drop requested--> Main
                                                               |
                                      MovementTest.spawn_dropped_item
                                                               |
                                  spawn correcto -> Inventory.take
                                                               |
                                                           WorldItem

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
5. Main observa LMB/RMB presionados antes de GUI. Si el punto queda fuera del
   panel/botón abierto, lo cierra sin manejar ni recrear el InputEvent. Las señales
   actualizan los gates sincrónicamente y el mismo evento continúa una sola vez
   hacia GUI y gameplay _unhandled_input. Un press interior y el release de un drag
   no activan esta regla.

Los slots usan _get_drag_data, _can_drop_data y _drop_data de Control. Iniciar un
drag no modifica modelos. Drop entre slots mueve a vacío, fusiona el mismo item hasta
max_stack_size o intercambia items diferentes. WorldDropTarget recibe únicamente el
drop sobre mundo: Main prepara primero el WorldItem y solo entonces usa Inventory.take.
Si falla el spawn o el slot cambió, revierte el nodo y conserva el item. Se transfiere
el stack completo, incluida la misma referencia y su estado runtime de arma.

MovementTest limita el spawn a drop_distance desde Player, usa la dirección al mouse
o el frente local como fallback y prueba offsets pequeños contra paredes y WorldItems.
No aplica física ni permite tirar directamente a una posición lejana.

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
no entren al Resource compartido. No hay división de stacks, uso ni lanzamiento físico.
Las armas existentes tienen FirearmDefinition y FirearmState por ItemStack;
WeaponAim/FirearmController realizan apuntado, hitscan y recoil, y WeaponReloadUI
presenta recarga manual. Esta presentación del personaje no depende de esos sistemas.

## Presentation / Character Animation

`scenes/player/character_visual.tscn` pertenece al Player y contiene, en orden de dibujo:

```text
CharacterVisual
  WheelVisuals
    RearLeft / RearRight / FrontLeft / FrontRight (rellenos repetibles)
    Outline (Ruedas.png)
  Chassis
  Body
  Head
  LeftArm (AnimatedSprite2D)
  RightArm (AnimatedSprite2D)
```

Un único script cohesivo, character_visual.gd, actualiza brazos y ruedas:

```text
WheelchairInput.drag_active + mouse_normalized_position (local)
    -> CharacterVisual -> LeftArm / RightArm
RigidBody2D.linear_velocity + orientación física
    -> CharacterVisual -> region_rect de los cuatro rellenos
```

No interpreta eventos ni consulta Input. No escribe tracking, transform del cuerpo,
velocidades o fuerzas; solo modifica la presentación.

### Forward convention

La física, WheelchairInput, debug, Muzzle y apuntado conservan **UP local** como
frente; RIGHT local es la derecha de la silla. El arte mira hacia **DOWN local**
cuando CharacterVisual tiene rotación cero. Su instancia dentro de Player lleva
un offset visual fijo de PI: DOWN del arte coincide con UP del cuerpo.
Player comienza con rotation = PI, por lo que ambos frentes miran DOWN mundial.
No cambiar únicamente uno de estos offsets ni invertir el tracking por el arte.
La cámara sigue la posición sin heredar la rotación.

### Arms

Cada brazo tiene idle (sprite sin número) y push (frames numerados atrás→adelante).
Sin drag se selecciona idle. Durante drag, con mouse local normalizado (x, y):

```text
forward = -y
left_progress  = clamp((forward + x + 1) / 2, 0, 1)
right_progress = clamp((forward - x + 1) / 2, 0, 1)
frame = round(progress * (N - 1))
```

N se consulta en el SpriteFrames de cada brazo. No hay reproducción a velocidad fija,
ni dependencia del número cuatro, ni smoothing añadido. El giro del cuerpo no altera
la interpretación porque la fuente ya expresa el mouse en coordenadas locales.

### Wheels

La proyección de linear_velocity sobre el frente mundial da la velocidad longitudinal.
Cada región acumula velocidad * delta * wheel_scroll_scale y se envuelve según la
altura de su textura. El desplazamiento lateral se ignora; inercia e impulsos externos
(incluido recoil) animan las ruedas sin drag. Rotación pura no anima las ruedas todavía.

Las texturas de 15×264 y 13×88 se repiten a tamaño nativo dentro de las cuatro ruedas;
Ruedas.png se dibuja encima como borde. Sprite2D usa región y repetición, sin shader.
Los lienzos de 448×448 están centrados y alineados. Cabeza.png es un recorte de
101×140: su posición (0, -89) alinea la base con el cuello. Toda la composición se
escala uniformemente a 0.12 en Player; la colisión existente permanece intacta.

### Editor customization

En character_visual.tscn se reemplazan las texturas de Chassis, Body, Head, Outline
y los cuatro rellenos. La jerarquía/z_index define el orden de dibujo. LeftArm y
RightArm tienen SpriteFrames independientes: agregar frames 5–8 al final de push
(atrás→adelante) no requiere código. Cambiar idle reemplaza la pose de reposo.
wheel_scroll_scale está en el Inspector de CharacterVisual; escala general y offset
visual están en su instancia dentro de player.tscn. No hay rutas de sprites en el script.

## Aim weight and sway

WeaponAim (weapon_aim_controller.gd), propiedad del Player, es la única fuente del aim:

```text
Mouse -> desired (direction_toward) -> arco -> target_aim_direction
    -> seguimiento exponencial -> current_aim_direction
    -> drift + tremor -> clamp al arco -> final_aim_direction / get_aim_direction()
        |-> CharacterVisual -> AimUpperBody -> AimMuzzle
        |-> debug: target azul, current verde, final amarillo
        `-> FirearmController -> spread del arma -> raycast
```

Desired es la intención inmediata; target la limita al cono. Current es lo alcanzado
por el arma; final añade inestabilidad humana. Los ángulos se guardan respecto a UP
local de la silla: el arco acompaña su rotación. El seguimiento usa lerp_angle con
1 - exp(-aim_follow_speed * delta); 10 por defecto alcanza 95% en unos 0.3 s.
Se actualiza en física con prioridad -10 antes del FirearmController (prioridad 0).
aim_updated sincroniza la pose; el proveedor de muzzle vuelve a aplicar esa misma
dirección al disparar antes de leer AimMuzzle.global_position. Ningún consumidor
reinterpreta el mouse ni interpola por separado. El offset visual del arte se conserva.

Drift y tremor mezclan dos senos de frecuencias diferentes, continuos y acotados.
Los valores del Inspector de WeaponAim están en grados y Hz: drift sano/crítico
0.4/2.0 a 0.35 Hz; tremor 0.06/0.25 a 3 Hz; blend inicial 0.15 s.
set_health_ratio(value) acepta 0..1 y parte de 1.0. Solo escala amplitudes: la Curve
opcional health_sway_curve recibe 1 - health_ratio; sin Curve usa lesión al cubo.
Este es el punto para conectar salud del Player posteriormente; HealthComponent
existe actualmente solo en EnemyBase, sin conexión al sway del jugador.

RMB empieza desde forward, con sway cero. Soltar RMB, bloquear input o cambiar equipo
reinicia los ángulos y cancela/restaura el recoil visual. El recoil sigue siendo un
offset de posición y no altera el seguimiento. Cursor inmediato, spread por pellet
y recoil físico permanecen independientes; todos los pellets comparten el mismo final.

## Decorative lighting and visibility

DecorativeLight2D continúa siendo PointLight2D con sombras. Su script crea una textura
128x128 una vez al iniciar: edge_hardness estrecha y escalona el borde; noise_amount y
noise_scale deforman ligeramente la máscara. noise_speed anima solo una oscilación muy
sutil de energía; cero la desactiva. Color, energy, escala y suavidad de sombra siguen
editándose en el PointLight2D hijo.

Las luces decorativas iluminan CanvasItems en la máscara visual 2 y sus occluders usan
esa misma máscara. PlayerVision renderiza su propia máscara de visibilidad en un
SubViewport separado usando copias de nodos occluder que comparten los mismos recursos
OccluderPolygon2D. VisibilityFog compone esa máscara sobre el mundo antes de Grain y HUD.
Por ello una lámpara nunca revela zonas que PlayerVision mantiene ocultas.

## EnemyBase and damage

EnemyBase es un CharacterBody2D quieto: posee Visual (Sprite2D), CollisionShape2D,
HealthComponent y un Label de HP provisional desactivable con show_health_debug.
HealthComponent posee max_health y current_health por instancia; inicia lleno,
limita el daño a 0..max_health y emite damaged y died (una sola vez).
EnemyBase delega take_damage y escucha died para queue_free. No contiene IA.
Futuros enemigos pueden heredar esta escena y añadir comportamiento mediante
componentes/controladores concretos, sin introducirlo en la base.

```text
FirearmController -> mismo hit del raycast -> collider.take_damage(damage)
                                              -> EnemyBase -> HealthComponent
                                                               | damaged -> HP debug
                                                               ` died -> queue_free
```

El receptor se reconoce por take_damage, no por la clase EnemyBase. Cada pellet
aplica FirearmDefinition.damage al collider real; ShotResult conserva ese mismo
hit para tracer/impact. Valores iniciales: revólver 25 por bala; escopeta 10 por
pellet (4 pellets existentes). No cambia aim, spread ni recoil.
EnemyBase usa capa/máscara física 1 como Player/mundo y máscara visual 2 para
recibir luz decorativa. VisibilityFog sigue recortando su presentación por píxel;
el enemigo no modifica ni amplía PlayerVision.

## Level prefabs

Un prefab es una escena canónica reutilizable y configurable desde Inspector.
Están reunidos en scenes/prefabs/: player/player.tscn, enemies/enemy_base.tscn,
items/world_item.tscn y lighting/decorative_light_2d.tscn. No son copias ni wrappers.
Las poses y otras escenas de soporte mantienen sus ubicaciones existentes.

Arrastrar una escena al nivel. Para editar hijos de una instancia activar
**Editable Children / Hijos editables**: HealthComponent.max_health controla HP;
Visual.texture/modulate el placeholder; PointLight2D expone color, energy,
texture_scale y sombras nativos. La raíz de la luz expone edge_hardness y noise_*.
Estas propiedades son por nodo/instancia; hacer recursos compartidos únicos antes
de modificar, por ejemplo, la geometría de una CollisionShape2D.
WorldItem expone definition y quantity en la raíz. Conectar pickup_requested al
PickupInteractor del Player desde la composición del nivel, como MovementTest.
Player mantiene las conexiones externas de Main; colocarlo no reemplaza esa
composición de HUD, Equipment, apuntado y fog. No hay búsquedas globales nuevas.
