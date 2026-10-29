# Arquitectura actual

Biblioteca visual de referencia en `assets/sprites/<función>/generated_ai/` (SVG, catálogo y escalas en
`docs/art_reference.md`). El playground utiliza sus bases de piso, muro,
puerta, ventana e iconos; la galería estática permanece como catálogo visual.

Mapa técnico de los sistemas existentes. Las reglas de programación y organización
están en `AGENTS.md`.

Actualizar este documento en la misma tarea cuando cambien significativamente
responsabilidades, escenas principales, comunicación, ownership o dependencias.
Los cambios internos pequeños que no alteran la arquitectura no requieren actualizarlo.

## Visual perspective

El juego usa perspectiva cenital ortográfica perfecta a 90°, nunca top-down 3/4.
Muros, puertas y ventanas deben seguir siendo válidos bajo cualquier rotación 2D:
no contienen caras verticales ni sombreado direccional para fingir una cámara inclinada.
El grosor de Line2D y su volumen LOS se extienden simétricamente a ambos lados del path.
La base canónica de muro es wall_mid_tile; puerta usa door_leaf y ventana usa
window_intact/cracked/broken, con shards aparte. La galería y docs/art_reference.md
documentan las referencias conservadas; las piezas mid/cap reemplazadas ya no existen.

### Resolución y nitidez

Base de diseño: 1920×1080; canvas_items + aspect expand, factor 1 y escalado fraccional
permitido. Se renderiza a la resolución de ventana, no a un viewport de baja resolución
reescalado. En aspectos distintos se amplía el área lógica sin deformar intencionadamente
los sprites. Camera2D conserva zoom 2.5: no se cambió el encuadre para corregir texto.

Los Labels de zonas/HP son world-space, escala 1 y fuente de 10–12 px; el zoom ampliaba
sus glifos rasterizados y producía borrosidad. La fuente predeterminada ahora usa MSDF
(gui/theme/default_font_multichannel_signed_distance_field), sin cambiar tamaños.
HUD/recarga siguen en CanvasLayer 3 y no heredan zoom. HDR 2D permanece desactivado;
filtro global lineal, excepción nearest del arte manual CharacterVisual y máscara LOS.
No se forzaron mipmaps ni escalado entero global: el proyecto mezcla arte suave y pixelado.

## Project structure

```text
scenes/
  app/main.tscn
  prefabs/actors/player.tscn
  prefabs/actors/enemies/enemy_base.tscn
  player/character_visual.tscn
  world/movement_test.tscn
  world/{basic_fog_2d, vision_blocker_2d}.tscn
  prefabs/effects/decorative_light_2d.tscn
  prefabs/environment/{level_boundary_2d, door_2d, window_2d}.tscn
  prefabs/items/{generic_item, key_item, ammo_item, weapon_item}.tscn
  internal/level_session.tscn
  internal/items/world_item.tscn
  ui/inventory_ui.tscn
  ui/inventory_slot.tscn
  ui/item_drag_preview.tscn
  ui/weapon_reload_ui.tscn
scripts/
  app/{level_session, level_connections}.gd
  player/{wheelchair_body, wheelchair_input, wheelchair_debug, pickup_interactor}.gd
  player/character_visual.gd
  enemies/enemy_base.gd
  combat/{health_component, firearm_definition}.gd
  world/{world_item_drops, decorative_light_2d, level_boundary_2d, door_2d, window_2d}.gd
  world/{basic_fog_2d, visibility_mask_2d, vision_blocker_2d, fog_appearance}.gd
  items/{item_definition, world_item}.gd
  inventory/{inventory, item_stack, equipment}.gd
  ui/{cursor_controller, inventory_ui, inventory_slot, world_drop_target}.gd
resources/items/{test_item, test_ammo, test_weapon, test_room_key, wrong_test_key}.tres
assets/sprites/ui/authored/cursors/{Cursor Default, Cursor Abierto, Cursor Agarrando}.png
docs/architecture.md
```

## Scene ownership

- **Main** solo instancia el playground guardado. También se puede ejecutar cualquier
  nivel Node2D con exactamente un Player, colocado a cualquier profundidad/nombre.
- **Player/LevelSession** posee HUD, cursor, VFX, fog y oscuridad. Es composición
  interna con transform top_level, no un prefab adicional ni un singleton.
- **LevelConnections** recorre una vez la escena ejecutada, registra por tipo
  items/puertas/luces/blockers y conecta señales. node_added/tree_exiting mantienen
  registros acotados al nivel; no hay búsquedas por frame ni listas manuales.
- **WorldItemDrops** usa ese registro para evitar solapar drops con items anidados.
  Solo crea drops runtime; el contenido permanente vive en .tscn.
- **MovementTest** es el playground sin script de composición particular. Conserva
  posiciones, cantidades, luces y HP de prueba, ahora configurados en raíces.
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
  recibe drag & drop nativo y notifica clicks de selección; solicita operaciones
  a los modelos, sin almacenarlos.
- **WorldDropTarget** es un Control fullscreen ubicado detrás de las UIs. Solo
  acepta drags nacidos en slots normales; los clicks comunes pasan sin consumirse.
- **DecorativeLight2D** compone un PointLight2D con sombra y genera su máscara
  irregular al iniciar. Es iluminación visual reutilizable sin reglas de visibilidad.

## Script responsibilities

| Script | Responsabilidad | No hace |
| --- | --- | --- |
| level_session.gd | Componer UI/modelos, cursor, input handoff, puertas y drop al mundo. | Reglas de pickup o almacenamiento. |
| wheelchair_body.gd | Fuerza longitudinal, torque, agarre lateral e impulso externo. | UI, pickup o reglas de inventario. |
| wheelchair_input.gd | Tracking local del mouse, drag dentro del radio y prioridad de clicks. | Aplicar fuerzas o recoger items. |
| wheelchair_debug.gd | Dibujar radio, cursor, inicio del gesto y frente. | Reglas físicas. |
| character_visual.gd | Seleccionar poses de brazos y desplazar texturas de ruedas. | Leer eventos de input o modificar gameplay. |
| weapon_aim_controller.gd | Target, seguimiento angular, sway y dirección final compartida. | Spread, recoil o sistema de salud. |
| weapon_aim_visual.gd | Orientar AimUpperBody/AimMuzzle y desplazar el torso por recoil. | Interpolar una segunda dirección de aim. |
| pickup_interactor.gd | Poseer Inventory/Equipment, validar distancia y recoger cantidades. | Dibujar UI o mover la silla. |
| item_definition.gd | Datos estáticos, máximo de stack, equipo y key_id opcional. | Estado mutable por instancia. |
| item_stack.gd | Definición/cantidad inmutables y FirearmState propio por arma. | UI o drag preview. |
| inventory.gd | Slots, stacks, inserción, merge, swap y extracción verificada. | SceneTree, UI o posición del jugador. |
| equipment.gd | Un arma equipada y transferencias verificadas con Inventory. | Labels, iconos o nodos UI. |
| world_item.gd | Mostrar el item, conservar stack runtime y solicitar pickup. | Inventario o búsqueda de Player. |
| cursor_controller.gd | Aplicar cursor hardware según contexto semántico. | Reglas de WorldItem, UI o silla. |
| inventory_ui.gd | Observar modelos, refrescar slots y abrir/cerrar el panel. | Ser fuente de verdad de los items. |
| inventory_slot.gd | Mostrar stack e invocar APIs nativas de drag/drop. | Usar o poseer items. |
| world_drop_target.gd | Solicitar un drop al mundo desde un drag válido. | Instanciar WorldItem o modificar Inventory. |
| decorative_light_2d.gd | Generar máscara irregular y variación temporal sutil. | Visibilidad del jugador o gameplay. |
| level_boundary_2d.gd | Sincronizar puntos de Line2D hacia colisión y oclusión. | Generar contenido del nivel. |
| door_2d.gd | Estados de latch/key lock, transición breve y hoja física con bisagra. | Buscar Inventory, UI o Player. |
| window_2d.gd | Durabilidad, estados visuales y separación entre barrera corporal e hitscan. | Oclusión de visión, shards físicos o paso de actores. |
| world_item_drops.gd | Spawn de drops runtime con registro de items anidados. | Generar la demo o dibujar muros. |
| basic_fog_2d.gd | LOS físico y malla exterior para gris. | IA, memoria explorada o excepciones de geometría. |
| visibility_mask_2d.gd | Rasterizar esa malla y recortar entidades por píxel. | Calcular otra LOS o cambiar física. |
| vision_blocker_2d.gd | Contornos físicos exclusivos de visión. | Colisión corporal o iluminación. |
| fog_appearance.gd | Elegir si los visuales de entorno reciben gris. | Modificar blockers o revelar entidades. |

## Data models

- **ItemDefinition**: Resource con display_name, icon, max_stack_size, key_id opcional,
  EquipmentSlotType (NONE o WEAPON), FirearmDefinition y escenas de pose/recarga.
  Se trata como inmutable durante el juego.
  No tiene balas cargadas, durabilidad, efectos ni estado particular.
- **ItemStack**: RefCounted con ItemDefinition y quantity inmutables. Cada stack
  cumple 1 <= quantity <= max_stack_size. Un arma posee además su propio FirearmState
  mutable: cámaras cargadas, nunca almacenadas en la definición compartida.
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
LevelSession --------bind_inventory--------^

InventorySlot --drag nativo--> WorldDropTarget --drop requested--> LevelSession
                                                               |
                                      WorldItemDrops.spawn_dropped_item
                                                               |
                                  spawn correcto -> Inventory.take
                                                               |
                                                           WorldItem

WheelchairInput --consume_motion--> WheelchairBody --> fuerzas/torque
        |
        +--> WheelchairDebug (lectura)

Door2D KEY_LOCKED --rattle/key_requested--> LevelSession --> InventoryUI.open_panel
InventorySlot --item_selected--> InventoryUI --> LevelSession
                                            | key_id compatible
                                            v
                           Door2D LATCHED --> opening --> OPEN
```

pickup_distance es independiente de interaction_radius. Un item lejano o sin
espacio permanece en el mundo. Se rechazan solicitudes de nodos ya pendientes de
eliminación para impedir recogidas duplicadas en el mismo frame.

## Ciclos de movimiento de la silla

WheelchairInput acumula eventos; WheelchairBody consume cada gesto una sola vez en
_physics_process y aplica fuerzas/torque y agarre lateral. No se usan fuerzas en
_process ni impulsos repetidos para sustituir fuerzas. Se conserva el integrador
normal de Godot, damping y CCD del prefab. Los impulsos externos siguen siendo puntuales.

Noclip recoge la intención WASD en el ciclo físico, despierta el cuerpo si hace falta
y escribe su velocidad mediante PhysicsDirectBodyState2D en _integrate_forces; allí
también detiene el viaje de teclado al soltar/salir y captura la inercia efectiva.
Los cambios de shape siguen diferidos. Animación, cámara shake y debug permanecen
en presentación; no se modificaron parámetros de conducción durante esta revisión.

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
5. LevelSession observa LMB/RMB presionados antes de GUI. Si el punto queda fuera del
   panel/botón abierto, lo cierra sin manejar ni recrear el InputEvent. Las señales
   actualizan los gates sincrónicamente y el mismo evento continúa una sola vez
   hacia GUI y gameplay _unhandled_input. Un press interior y el release de un drag
   no activan esta regla.

Los slots usan _get_drag_data, _can_drop_data y _drop_data de Control. Iniciar un
drag no modifica modelos. Drop entre slots mueve a vacío, fusiona el mismo item hasta
max_stack_size o intercambia items diferentes. WorldDropTarget recibe únicamente el
drop sobre mundo: LevelSession prepara primero el WorldItem y solo entonces usa Inventory.take.
Si falla el spawn o el slot cambió, revierte el nodo y conserva el item. Se transfiere
el stack completo, incluida la misma referencia y su estado runtime de arma.

WorldItemDrops limita el spawn a drop_distance desde Player, usa la dirección al mouse
o el frente local como fallback y prueba offsets pequeños contra paredes y WorldItems.
No aplica física ni permite tirar directamente a una posición lejana.

## Cursor

CursorController es propiedad de LevelSession y recibe contextos semánticos mediante
set_context(owner, available, active). GRABBING tiene prioridad sobre
INTERACTABLE y DEFAULT. Los contextos usan referencias débiles: borrar o salir de
un nodo no deja el cursor bloqueado.

```text
LevelSession traduce hover de UI, WorldItem y WheelchairInput
                         |
                         v
                  CursorController
                         |
                         v
             Input.set_custom_mouse_cursor
```

Las cuatro texturas (incluida AIMING) y hotspots se asignan al CursorController en
scenes/internal/level_session.tscn desde el Inspector. Las texturas actuales están en
assets/sprites/ui/authored/cursors/. El Button Mochila admite su propiedad icon nativa desde
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
- **Composición**: LevelSession y LevelConnections suministran dependencias
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
Este es el punto para conectar salud al sway posteriormente. Player, EnemyBase y
Window2D tienen HealthComponent; esta iteración no conecta vida y sway.

RMB empieza desde forward, con sway cero. Soltar RMB, bloquear input o cambiar equipo
reinicia los ángulos y cancela/restaura el recoil visual. El recoil sigue siendo un
offset de posición y no altera el seguimiento. Cursor inmediato, spread por pellet
y recoil físico permanecen independientes; todos los pellets comparten el mismo final.

## Decorative lighting

DecorativeLight2D utiliza PointLight2D con sombras y una textura radial irregular.
center_intensity, edge_hardness y noise_* controlan su apariencia por instancia.
Las luces y los visuales receptores utilizan máscara 2; los LightOccluder de paredes
y puertas conservan únicamente esa máscara. Las ventanas no ocluyen luz.

La iluminación del mundo se compone antes del gris de zonas sin LOS: una lámpara
no revela entidades ocultas. GrainOverlay y HUD se dibujan después, independientes.

### Oscuridad de cámara

LevelSession posee CameraDarkness (CanvasLayer 1), después del mundo/fog y antes de grain
y HUD. Su ColorRect negro aplica una caída smoothstep en píxeles de pantalla,
centrada en la proyección del Player. No consulta paredes ni altera su forma
por geometría. No hay PointLight de proximidad: AmbientDarkness vuelve a su
valor base, y la atmósfera oscura se aplica exclusivamente en esta capa.

LevelSession inyecta viewer y la lista de luces descubiertas por LevelConnections;
visibility_mask es una referencia interna de su escena.
Las lámparas habilitadas alivian la oscuridad alrededor de su posición proyectada,
aunque su centro quede fuera de la LOS o de pantalla: importa su área de influencia.
Ese alivio se recorta por píxel con la máscara LOS existente: solo actúa dentro
de la visión, nunca fuera. No se comprueba la visibilidad del centro de la lámpara.
El alivio radial aproxima su alcance usando textura, escala y energía; el color
y las sombras reales continúan a cargo de PointLight2D. No es una segunda máscara
LOS: nunca revela enemigos detrás de paredes. No genera otra máscara ni raycasts.
El halo base de cámara no se deforma por occluders; solo se recorta el alivio de luces.

Inspector LevelSession/CameraDarkness: clear_radius (0.18) y dark_radius (0.75), fracciones
de la altura de pantalla; darkness (0.98), lamp_relief (1) ; admite hasta 32 luces registradas.
Al cambiar zoom, el halo conserva tamaño de pantalla y las lámparas acompañan
su tamaño en mundo. Los transforms se sincronizan antes del render; sin raycasts
adicionales, nuevas luces ni SubViewports. Una nueva DecorativeLight2D se registra
automáticamente; no hay que asignarla a ningún array. Puertas excluidas del gris siguen recibiendo
esta oscuridad de cámara.

## Fog actual: escenario conocido y entidades recortadas

LevelSession posee BasicFog2D e inyecta Player y los VisionBlocker2D del nivel.
256 rayos fijos más esquinas/intersecciones ±epsilon producen una única LOS:
primer impacto contra el volumen completo de paredes/puertas, sin tolerancia.
Window2D no bloquea visión. No hay memoria explorada ni influencia de las luces.

```text
Player -> physics LOS + vision_radius -> polígono ordenado
    |-> malla exterior -> escenario gris (z=99)
    |-> misma malla -> VisibilityMask -> recorte por píxel de vision_subject
Escenario -> gris -> geometrías excluidas (z=100) -> Player (z=101) -> grain/HUD
```

El escenario siempre existe visualmente; unseen_environment desatura y oscurece
solo fuera de LOS. EnemyBase y WorldItem pertenecen al grupo vision_subject:
VisibilityMask aplica un único material compartido a sus CanvasItems (incluidos
labels y drops runtime). Cada píxel consulta la máscara binaria, no el centro
del objeto. No se cambia visible ni se añaden blur, dilatación o fades.
Los visuales actuales de este grupo no tienen otros shaders; un visual con shader
propio necesitará integrar el recorte, no sustituirlo silenciosamente.

La máscara vive en un SubViewport aislado, sin cámara adicional. Copia la malla
durante física y sincroniza resolución/canvas con el viewport principal antes del
render. Usa filtrado nearest. No calcula otra LOS ni interpola impactos.
LevelSession inyecta en WorldItem la consulta puntual para validar el mouse sobre la
fracción visible. Física, daño y reglas de inventario permanecen separados.

Inspector LevelSession/BasicFog2D: vision_radius (650), ray_count (256), unseen_brightness
(0.45), show_rays. last_update_usec mide CPU, no el coste GPU de la máscara.
El debug no redibuja mientras está desactivado; los buffers de la malla se
dimensionan una vez por actualización, sin arrays temporales por triángulo.

### Elección de geometrías afectadas por gris

Door2D, LevelBoundary2D y Window2D exponen affected_by_fog en su raíz y lo aplican
a su FogAppearance interno. Puertas: false por defecto;
paredes/ventanas: true. visuals son referencias explícitas a los dibujos afectados.
Para otra geometría, añadir un Node con scripts/world/fog_appearance.gd y asignar
sus visuales. No usarlo para enemigos/items, que pertenecen a vision_subject.

La exclusión dibuja esos visuales después del gris (z absoluto 100), conserva
material, textura y luz y restaura su orden original al reactivar el filtro.
Es una capa de entorno en primer plano: los visuales excluidos se superponen al
mundo normal donde coincidan. Player y HUD siguen encima. No cambia ni desactiva
VisionBlocker, colisiones, sombras decorativas o el polígono LOS; una puerta sin
gris continúa ocultando por píxel al enemigo que esté detrás.

## Player health and development UI

Player posee HealthComponent reutilizado, con max_health=100 editable en su raíz;
current_health es runtime por instancia. Player.take_damage(amount) es la entrada
para futuros impactos: ignora daño en god mode y delega el resto al componente.
Player.heal(amount) delega curación limitada al máximo, sin resucitar. HealthComponent
conserva damaged/died y añade changed(current, maximum) para daño, curación y cambios
de máximo. No hay invulnerabilidad genérica en HealthComponent.

Al llegar a 0, died se emite una vez, se anula velocidad, se congela el cuerpo y se
bloquean input de silla/aim y clicks de mundo. El Player permanece en escena; no hay
respawn/game over ni pantalla final. Activar god mode después no lo resucita.
El menú de debug sigue accesible. El HUD inferior central, propiedad de LevelSession/HUD,
se conecta explícitamente a health.changed, sin polling ni rutas al nivel.

```text
Player → HealthComponent → changed → LevelSession/HUD/PlayerHealthHUD

DebugMenu (CanvasLayer 4)
    ↓
DebugSettings (RefCounted, runtime de LevelSession/LevelDebug)
    ↓ changed
LevelDebug → Player / enemigos / fog / oscuridad
```

toggle_debug_menu usa F1 en InputMap. El juego continúa; abrirlo cancela el gesto/aim
y su Control fullscreen bloquea clicks debajo, sin interferir con la GUI del menú.
Orden: mundo/fog → oscuridad (layer 1) → grain (2) → HUD (3) → debug (4).
La UI solo edita flags; LevelDebug aplica adaptadores pequeños. LevelConnections
notifica piece_registered durante discovery inicial y altas posteriores, sin búsquedas
por frame. No Autoload, persistencia, consola ni herramientas de spawn/daño en el menú.

| Flag (default) | Receptor y efecto |
| --- | --- |
| Show Debug Visuals (OFF) | API set_debug_visuals_enabled en Player, EnemyBase/PatrolEnemy, noise y fog. Global AND flag local; no borra la configuración de Inspector. Los rays masivos del fog siguen opt-in mediante Show Rays. |
| Noclip (OFF) | Player guarda/restaura exactamente disabled de su única CollisionShape2D corporal mediante aplicación diferida, agrupando toggles rápidos. Conserva la inercia efectiva para permitir torque sin forma activa y restaura el valor original (incluido automático). WASD mediante InputMap mueve en ejes de pantalla, diagonal normalizada, a noclip_speed (240); mouse sigue girando. Al soltar WASD o salir del modo se detiene la traslación de teclado. Menú/UI y muerte bloquean también WASD. Layers/masks y pickups se conservan; al restaurar dentro de un sólido se aplica la resolución física normal. |
| God Mode (OFF) | Player.take_damage ignora daño; no cura ni revive. |
| Enemy Detection (ON) | Perception deja de consultar vista/ruido; PatrolEnemy cancela CHASE/memoria inmediatamente y continúa PATROL. |
| Fog (ON) | BasicFog2D oculta/muestra Shadow y VisibilityMask cambia mask_enabled del shader de entidades. LOS y viewport siguen actualizándose, sin reconstrucción ni cambios a IA/pickup/navegación. |
| Darkness (ON) | Oculta CameraDarkness; CanvasModulate pasa a blanco y luces decorativas se deshabilitan temporalmente. Al volver restaura color/enabled originales, sin destruir nodos ni modificar parámetros de luces. |

Las opciones locales de debug AI están activadas por defecto pero subordinadas al
switch global OFF. Etiquetas permanentes de zonas del playground no son overlays de
debug runtime. Fog y Darkness son independientes: apagar fog no cambia la LOS física
que CameraDarkness utiliza para limitar iluminación de lámparas.

## EnemyBase and damage

EnemyBase es un CharacterBody2D quieto: posee Visual (Sprite2D), CollisionShape2D,
HealthComponent y un Label de HP provisional desactivable con show_health_debug.
HealthComponent posee max_health y current_health por instancia; inicia lleno,
limita el daño a 0..max_health y emite damaged y died (una sola vez).
EnemyBase delega take_damage y escucha died para queue_free. No contiene IA.
PatrolEnemy hereda su escena y añade componentes sin introducir decisiones en la base.
EnemyBase tiene un NavigationObstacle2D circular pasivo para evasión de otros actores;
PatrolEnemy lo desactiva y utiliza su propio NavigationAgent2D con avoidance.

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
recibir luz decorativa. No controla visibilidad del mundo.

## Enemy navigation and perception

```text
PatrolEnemy (composición/Inspector, derivado de EnemyBase)
  ├── EnemyDefinition (Resource compartido, solo datos estáticos)
  ├── Movement + NavigationAgent2D → CharacterBody2D.move_and_slide
  ├── Perception → cono + LOS física / radio de escucha
  └── Behavior → PATROL / CHASE, waypoint, espera y última posición conocida

Player.linear_velocity · forward → PlayerNoiseEmitter → Perception
LevelSession/LevelConnections → inyección explícita de Player en PatrolEnemy
```

EnemyDefinition configura patrol_speed 44, chase_speed 80, acceleration 260,
deceleration 360, vision_distance 260, vision_angle_degrees 100, hearing_radius 220
y target_memory_seconds 3. damage=10 es únicamente un dato futuro: no hay ataques
ni daño al Player. Cada enemigo conserva su propio estado, nunca en ese Resource.
El Resource activo resources/enemies/patrol_enemy.tres conserva su tuning particular:
chase_speed 48 (antes tenía override manual 55), mayor que patrol_speed 44 (antes 55).
Los defaults de clase anteriores eran 55/95; no se cambió la fórmula de movimiento.

Colocar un LevelNavigation2D por nivel y dibujar su envolvente caminable mediante
los handles nativos de NavigationPolygon. Al cargar, realiza un único bake oficial
con NavigationMeshSourceGeometryData2D. Deriva obstrucciones desde points/width de
LevelBoundary2D (incluyendo uniones miter y perímetros cerrados huecos) y pane_size
de Window2D, incluso rota. No se editan copias de paredes ni se bakea por frame.
agent_clearance=22 debe cubrir el radio corporal del enemigo más grande del nivel.
rebuild() es explícito si cambia geometría estática durante runtime. Las geometrías
genéricas que no sean estos prefabs todavía no se incorporan automáticamente.

Las puertas dinámicas quedan fuera del bake: su colisión física detiene al enemigo
cuando bloquean el paso, y permite continuar al abrirse. No hay apertura/empuje
inteligente ni búsqueda de otra ruta por una puerta cerrada. Avoidance entre actores
no modifica el mapa ni garantiza salida de un pasillo completamente bloqueado.
Las ventanas, aun rotas, siguen excluidas del mapa y bloquean cuerpos (mask 5).

PatrolRoute2D es un Path2D nativo colocado en el nivel, fuera del enemigo móvil.
Asignarlo a Patrol Route y editar Curve: sus puntos son destinos, no trayectorias.
ROUTE recorre todos en loop, con wait_time_at_point; STATIONARY no patrulla pero
puede perseguir. Sin ruta/puntos se queda quieto. Un punto inaccesible no se salta
silenciosamente: debe corregirse en el editor. UP es forward inicial; Movement
orienta progresivamente el visual/forward hacia la velocidad real sin girar el collider.

Perception evalúa distancia + cono y una consulta física solo si pasan ambas.
AI Sight Blocker usa bit 16 (capa 5), independiente del fog: áreas propias en muros
y hojas de puertas, derivadas de su geometría completa. El muro comparte su Shape
física, no el estado del blocker visual; la puerta gira su área con DoorBody.
Window2D no participa. Punto de detección: centro físico del Player. Ninguna regla
de IA consulta visibilidad visual, iluminación, shaders ni píxeles.

PlayerNoiseEmitter lee la velocidad longitudinal física absoluta: <=20 es silencio,
>=120 produce radio 220, interpolación entre ambos. La inercia también suena; la
velocidad lateral no cuenta como rodadura. Escucha si distancia <= ambos radios
(emisor y enemigo), ignorando paredes en esta primera versión. El emisor expone
get_noise_radius(), sin sistema global ni otras fuentes de ruido implementadas.

Vista O escucha inicia CHASE. Se actualiza destino cada 0.2 s, nunca persiguiendo
la posición oculta después de perder percepción: solo la última conocida durante
la memoria. A 44 unidades se detiene; al expirar memoria vuelve a la patrulla.
Movement acelera/frena y usa navegación + evasión local oficial, sin decisiones.
Debug por enemigo: navegación nativa, waypoints/última posición, cono y radios de
escucha/ruido. PlayerNoiseEmitter también permite mostrar su radio independientemente.
El playground guarda LevelNavigation2D, EnemyPatrolRoute y un PatrolEnemy; los
EnemyBase anteriores permanecen como receptores de daño. No se genera el layout.

## Level prefabs

Piezas canónicas bajo scenes/prefabs/:

- actors/player.tscn y actors/enemies/enemy_base.tscn.
- actors/enemies/{patrol_enemy,patrol_route_2d}.tscn.
- environment/{level_boundary_2d,door_2d,window_2d}.tscn.
- environment/level_navigation_2d.tscn (envolvente de navegación del nivel).
- effects/decorative_light_2d.tscn.
- items/{generic_item,key_item,ammo_item,weapon_item}.tscn.

Las cuatro categorías heredan scenes/internal/items/world_item.tscn, también usado
para drops. Ningún componente de UI/poses/VFX internos está en el catálogo.

WorldItem es @tool: definition, quantity, world_sprite y world_visual_scale en raíz;
preview por setters/Resource.changed, sin polling. Escala visual no cambia interacción.
definition.world_sprite es opcional, con icon como fallback. El override world_sprite
del nodo es solo de colocación; los drops recuperan la presentación de la definición.
Generic/Key exponen proxies de display_name/inventory_icon y Key además key_id. Editar
estos detalles crea una variante de definición; los proxies no se serializan aparte.
Asignar la misma definición a varios pickups conserva su identidad para stacks.
Ammo/Weapon seleccionan una definición canónica: icono y estadísticas se editan dentro
del Resource compartido, conscientemente para todo ese tipo. No se duplican al colocar.
Quantity de arma debe ser 1; FirearmState sigue siendo individual por ItemStack.

Door expone leaf_texture, leaf_size, distancia, key_id/consumo, ángulos y física avanzada
en raíz. Window expone pane_size, durabilidad, tres texturas y shard_texture/dispersión.
EnemyBase expone sprite, visual_scale, max_health, collision_radius y debug; su shape
es propia por instancia. Player concentra Movement/Input/Aim/Camera/Debug habituales;
los hijos reciben estos valores al iniciar, no se editan para ese tuning.
DecorativeLight2D expone light_color/light_energy/light_radius y carácter en raíz;
genera preview en editor al cambiar parámetros, sin flicker/polling de editor. Su radio
equivale a la mitad de la textura escalada en unidades de mundo con Scale=1.

Crear un nivel Node2D, colocar exactamente un Player y arrastrar las demás piezas.
No hace falta editar Main, conectar pickups ni registrar puertas/luces. Componentes
internos conservan rutas relativas dentro de su propio prefab, nunca al layout del nivel.

### LevelBoundary2D

Prefab: scenes/prefabs/environment/level_boundary_2d.tscn. La raíz es un Line2D:
seleccionarla y usar los handles nativos de puntos en la barra del editor 2D.
No hay que activar Hijos editables ni editar las geometrías derivadas.

```text
LevelBoundary2D.points (única geometría editable)
    ├── Line2D raíz: visual de pared
    ├── Collision/Polygon: ConcavePolygonShape2D de segmentos, capa/máscara física 1
    ├── LightOccluder: máscara 2 (luz decorativa)
    └── VisionBlocker: contorno completo de points + width, capa física 4 (solo LOS)
```

El script @tool sincroniza al redibujar por una edición de puntos; al iniciar
runtime construye una vez, sin _process. Cada instancia posee su propio recurso
occluder para las sombras de las luces decorativas.
Width, Default Color, Texture y Texture Mode son propiedades nativas de Line2D;
Tile y Texture Repeat están configurados para textura repetible. Collision Enabled
y Occlusion Enabled controlan física y sombras decorativas; Blocks Vision controla
LOS independientemente. Width controla visual y volumen
LOS y colisión corporal/hitscan: ambos reciben los mismos contornos completos,
sin una barrera física adicional en el eje. Collision es el único cuerpo sólido;
VisionBlocker es un Area2D de capa 4 que solo consultan los rayos de visión.
Los contornos interior/exterior de un muro cerrado delimitan su espesor, no dos muros.
La habitación encerrada permanece hueca. LightOccluder sigue separado para luz decorativa.
El volumen LOS admite el estilo actual: ancho uniforme, Sharp con límite 2 y caps
None. El editor avisa si se eligen curvas de ancho/caps/joins distintos, que aún
no están soportados por esa derivación.
Mantener Scale (1, 1), editar Points para la forma y Width para el grosor; el editor
avisa si se escala el nodo. La textura canónica es uniforme a lo largo del tramo:
sin juntas transversales que los UV de Line2D puedan sesgar al unir esquinas.
Closed cierra último→primero;
desactivarlo crea un tramo abierto desde dos puntos. Admite concavidad y no genera
geometría dinámica durante gameplay. Los huecos se construyen terminando un tramo,
colocando Door2D/Window2D y continuando con otro tramo.
Las paredes llegan a ambos extremos de la puerta cerrada, sin rendijas visuales.
Door2D.collision_end_insets recorta solo la colisión sólida de la hoja: X en la
bisagra, Y en la punta (10 y 1 unidades por defecto, hoja 96×12 y giro ±100°).
La forma se desplaza para respetar ambos recortes, sin mover el pivote ni el sprite.
Visual, interacción y VisionBlocker mantienen la hoja completa; no se altera fog.
La tolerancia también afecta hitscan, que usa la colisión sólida: los extremos
recortados no reciben impactos. Revisar insets al cambiar grosor de muro o giro;
no hay excepciones que permitan a toda la puerta atravesar cualquier pared.

Los occluders derivados se utilizan únicamente para sombras decorativas.

### Door2D, Window2D and playground

Door2D es un prefab físico con HingeAnchor, DoorBody RigidBody2D, área clickeable,
LightOccluder y PinJoint2D. LevelSession valida distancia mediante las puertas
registradas automáticamente por LevelConnections. Sus estados locales son:

```text
LATCHED --click/tween corto--> OPEN --cierre físico lento--> LATCHED
KEY_LOCKED --click/rattle--> selección en Inventory --key_id igual-->
LATCHED --tween corto--> OPEN
```

La apertura inicial elige el signo opuesto al Player en coordenadas locales y,
al terminar, solo fuerzas/colisiones mueven la hoja. El relatch exige cercanía a
cero y baja velocidad angular. Solo la hoja abierta revisa relatch en cada tick;
trabada o durante la transición no ejecuta ese seguimiento.
Desbloquear con llave es permanente para esa instancia:
los cierres posteriores vuelven a LATCHED, nunca a KEY_LOCKED.
La hoja bloquea cuerpos, balas y luz según su transform real. Su VisionBlocker hijo
usa el tamaño completo de la hoja y acompaña toda apertura, sin estados de visibilidad.
Inspector expone interaction_distance, unlatched/max angle, opening_time, umbrales
de relatch, key_id, consume_key_on_unlock, rattle y leaf_size; masa y angular_damp
se configuran en raíz con leaf_mass/leaf_angular_damping; leaf_texture controla Visual.

`Door2D.key_id == ItemDefinition.key_id` autoriza el desbloqueo; vacío representa
una puerta o item sin llave. LevelSession conserva una referencia débil únicamente durante
la selección y solicita a Inventory quitar una unidad solo cuando la puerta configura
consume_key_on_unlock, activado por defecto. La puerta no inspecciona slots y la UI
no modifica su estado.
El prefab configurado de llave está en scenes/prefabs/items/key_item.tscn y
su definición de ejemplo en resources/items/test_room_key.tres.

Window2D reutiliza HealthComponent con max_durability en su raíz y tres bases 9-slice:
intacta, agrietada al 50% o menos y rota al llegar a cero. FirearmController entrega
el daño y la dirección del raycast que ya resolvió; cada pellet cuenta y no se realiza
otra consulta física. El impacto que agota la durabilidad se convierte al espacio local
de la ventana y los Shards preparados en escena se desplazan hacia el lado de salida
del proyectil, opuesto al tirador. Rota abandona la capa de hitscan, por lo que las
balas atraviesan. Conserva la capa 3 como barrera corporal: Player (máscara 1|3) no
puede pasar. No tiene LightOccluder, de modo que visión y luz atraviesan siempre.

Los visuales de entorno activos parten de una base por estado/categoría: Line2D repite
wall_mid_tile y su shader conserva las bandas del grosor; Door2D usa door_leaf en
NinePatchRect; Window2D usa un NinePatchRect con una textura completa por estado.
Width, leaf_size y pane_size redimensionan sin montaje manual de piezas.

scenes/world/movement_test.tscn es el único level playground y la escena que Main
instancia. Player incorpora LevelSession; ejecutar el playground directamente también funciona. Muros, puerta normal, puerta con llave, llaves de prueba, ventana,
tres luces configuradas por instancia, Player,
enemigos e items están guardados como nodos/instancias en ese `.tscn`; ningún script
crea contenido permanente de la demo.

Environment agrupa Walls, Doors, Windows y TestLabels. Sus transforms son identidad;
la organización no cambia ubicaciones ni geometría. Player, items, enemigos y luces
conservan sus posiciones. La composición y búsqueda de drops admiten jerarquías anidadas.
Las zonas físicas existentes se mantienen: objetos/combate abajo, puerta y vidrio en
la división central, muros/esquinas/diagonales arriba y a la derecha.

Todos los muros del playground heredan el mismo grosor 16 del prefab, sin escalas
por instancia. IrregularWall es un tramo abierto que conecta con el perímetro:
no duplica sus lados superior/derecho. La zona superior izquierda incluye muros
horizontales consecutivos, uno vertical y uno diagonal. El piso termina en el path
del perímetro, debajo de su espesor, sin una franja de baldosas exterior que simule
otra cara de pared. EnemyBehindThickWall y el item
VisionBehindWall permiten comprobar la ocultación de contenido detrás del muro.
La puerta existente permite recorrer continuamente cierre, apertura parcial y 90°.
