# Plan de autoría de niveles

Auditoría estática del 25-10-2026. Solo diagnóstico y plan; sin ejecutar Godot ni
modificar código, escenas, recursos o architecture.md. Se preservan los cambios
preexistentes. Fuentes: AGENTS.md, arquitectura y escenas/scripts directamente relacionados.

## 1. Current state

Hay ocho escenas canónicas en `scenes/prefabs/`. READY significa usable dentro de
la composición actual, no que funcione automáticamente en un nivel vacío.

| Prefab | Status | Current path bajo scenes/prefabs/ | Purpose |
| --- | --- | --- | --- |
| Player | NEEDS POLISH: integración | player/player.tscn | Actor, cámara y componentes; Main conecta HUD/equipo/armas. |
| EnemyBase | NEEDS POLISH | enemies/enemy_base.tscn | Visual, colisión, salud, daño/muerte; sin IA. |
| WorldItem | NEEDS POLISH | items/world_item.tscn | Pickup genérico con definition y quantity; sin definición inicial. |
| KeyWorldItem | NEEDS POLISH | items/key_world_item.tscn | Variante heredada con test_room_key.tres, no duplicado accidental. |
| LevelBoundary2D | READY; aclaraciones | world/level_boundary_2d.tscn | Puntos editables y geometrías derivadas. |
| Door2D | NEEDS POLISH | world/door_2d.tscn | Hoja física con latch y cerradura opcional. |
| Window2D | READY; polish menor | world/window_2d.tscn | Tamaño, durabilidad y estados visuales. |
| DecorativeLight2D | NEEDS POLISH | lighting/decorative_light_2d.tscn | Luz con máscara y variación generadas al iniciar. |

Munición y armas usan WorldItem + Resources, no escenas específicas:
`resources/items/{revolver_ammo,shotgun_shell,revolver_item,double_barrel_shotgun_item}.tres`.
También existen test_item, test_ammo, test_weapon, test_room_key y wrong_test_key;
no se demostró duplicación accidental que justifique eliminarlos.

NOT REALLY A PREFAB de nivel: escenas de `scenes/player/` (CharacterVisual/poses),
`scenes/ui/`, `scenes/combat/` y `scenes/world/{basic_fog_2d,camera_darkness,vision_blocker_2d}.tscn`.
Son composición interna. Main es aplicación; movement_test es playground;
art_reference_gallery es referencia. No incorporarlos como piezas del catálogo.

## 2. Target structure

Conservar organización por tipo de AGENTS, sin otra raíz prefabs/ ni wrappers:

```text
scenes/prefabs/
  actors/       player.tscn, enemy_base.tscn
  environment/  level_boundary_2d.tscn, door_2d.tscn,
                window_2d.tscn, decorative_light_2d.tscn
  items/        world_item.tscn, key_world_item.tscn
```

Scripts y Resources conservan sus ubicaciones. No crear subcarpetas por cada item
ni una escena por cada .tres. Presets heredados adicionales solo si facilitan un uso
frecuente demostrado, sin duplicar datos de definición.

## 3. Inspector contract

Contrato propuesto, no exports ya implementados:

| Prefab | Expose: configuración habitual | Hide/internal o avanzado |
| --- | --- | --- |
| WorldItem | definition, quantity; escala visual y preview del icono | Stack runtime, consulta de visibilidad, masks; click shape avanzado. No duplicar nombre/ID en raíz. |
| Key | Lo anterior; desplegar definición para nombre, icono y key_id | firearm/equipo/poses no son configuración normal de llave. |
| Ammo | Definición canónica, quantity, escala visual | max_stack_size en definición compartida; no duplicarla por caja. |
| Weapon pickup | Definición canónica, escala visual; cantidad 1 | FirearmState y recarga runtime; estadísticas en FirearmDefinition. |
| LevelBoundary2D | Points, Closed, Width, color, textura/Tile; collision_enabled y oclusión decorativa claramente nombrada | Contornos, material técnico y masks. Scale=1; ancho uniforme, Sharp límite 2, caps None. |
| Door2D | Visual: tamaño/textura. Interaction: distancia, key_id y consumo. Opening: ángulo inicial de destrabe y máximo | Physics avanzado: masa, damping, insets. Feedback avanzado: tiempos/rattle/relatch. Estado, joint, pivote y shapes internos. |
| Window2D | Tamaño, durabilidad, texturas intacta/agrietada/rota | Textura/dispersión de shards avanzadas; estado, HP actual, capas y shapes internos. |
| DecorativeLight2D | Color, intensidad, radio/alcance en raíz; carácter/ruido agrupado | Textura generada, fase/tiempo, masks. No mantener dos fuentes de verdad raíz/hijo. |
| EnemyBase | Visual/tamaño, max_health, show_health_debug | current_health, señales; collider avanzado y único por instancia. Sin IA nueva. |

Player está separado correctamente de sus poses/componentes. No exportar todo:
su principal pendiente es la integración reutilizable con un nivel.

### Items, llaves y Resources

Flujo real: ItemDefinition estática → WorldItem solicita pickup → PickupInteractor
valida → Inventory guarda ItemStack. UI no es fuente de verdad. FirearmState vive
por stack; conservar esa separación.

Workflow recomendado: elegir una definición existente para copias del mismo item.
Para una llave distinta, crear/guardar otra definición, configurar nombre/icon/key_id
y asignar ese ID a Door2D. Varias copias de esa llave comparten su definición.
No agregar key_id/display_name redundantes en WorldItem.

WorldItem copia definition.icon al Sprite2D solo en runtime: una textura editada en
el hijo se sobrescribe. No hay @tool/preview. Sprite tiene escala 0.5 y click radio 20;
escalar raíz también altera interacción. Proponer escala exclusivamente visual.
No separar icono UI/world hasta necesitarlo; si se hace, usar fallback explícito.

ItemDefinition/FirearmDefinition deben seguir compartidos; no activar local_to_scene
globalmente. Inventory compara identidad de definición para merge y compatible_ammo:
duplicar munición por instancia puede romper stacks/recarga aunque sus campos coincidan.
Editar un .tres compartido afecta todas sus referencias; asignar otra textura al nodo
no modifica el asset original. No guardar estado runtime en Resources estáticos.

Door/Window recrean shapes propias; Wall recrea shape/occluder; VisionBlocker genera
su shape. WallSlice ya es local_to_scene. Enemy/WorldItem tienen shapes sin esa marca:
hacerlas únicas antes de editar tamaño por instancia; aislarlas al exponer tamaño.
Texturas inmutables pueden compartirse; no duplicar todos los Resources por prevención.

### Entorno: capacidades existentes

- Wall: Points es el eje y Width se reparte simétricamente. Handles nativos; Closed
  cierra el path. @tool sincroniza sin polling permanente visual, colisión/LOS de volumen
  y occluder decorativo central. Esquinas miter; caps/curvas de ancho arbitrarias no
  soportados y advertidos. Huecos con tramos separados. collision_enabled no desactiva
  LOS; occlusion_enabled afecta solo luz decorativa.
- Door: key_id vacío inicia LATCHED; no vacío KEY_LOCKED. Llave correcta desbloquea
  permanentemente y puede consumirse. No agregar boolean locked redundante. No hay
  configuración de apertura inicial libre; no añadirla sin necesidad. Textura y
  masa/damping requieren Hijos editables. Insets (10,1) recortan colisión sólida y
  hitscan, no sprite/LOS; revisar tolerancia cuando cambia grosor/tamaño.
- Window: raíz concentra tamaño/durabilidad/texturas. Agrieta al 50%, rompe al llegar
  a cero; shards salen según impacto. Rota conserva barrera corporal y deja pasar
  balas. Siempre permite visión/luz. No necesita reconstrucción.
- Luz: color/energy/texture_scale en hijo PointLight2D, carácter en raíz. Textura
  generada solo en _ready y ausente en prefab: sin preview fiel de alcance en editor.
- Bases actuales del entorno son cenitales 90° y rotables. Mantener esa regla;
  esta auditoría no rediseña arte ni verifica visualmente nuevas rotaciones.

## 4. Problems found

### HIGH

1. Arrastrar no completa integración. Pickups tienen conexiones individuales en
   movement_test.tscn; Main recorre movement_test.doors; CameraDarkness referencia tres
   luces en main.tscn. Otra lámpara ilumina nativamente, pero no alivia esa oscuridad
   hasta registrarla. Main depende de rutas $MovementTest/Player/…; drops buscan otros
   WorldItems solo entre hijos directos. Falta contrato reutilizable de composición.
2. Items sin preview ni escala visual simple; riesgo de cambiar todas las llaves
   editando una definición compartida. key_id y matching ya existen: falta UX, no lógica.

### MEDIUM

- Door mezcla ajustes frecuentes/delicados y exige hijos editables para visual/física;
  tolerancia dependiente de geometría y con efecto hitscan documentado.
- Luz sin preview y controles repartidos. EnemyBase requiere hijos para HP/visual y
  cuidado con shapes compartidas; su estructura actual es suficiente antes de IA.
- Wall muestra propiedades nativas fuera del contrato soportado. Hay warnings, pero
  hace falta explicar mejor límites y diferencia entre oclusión decorativa y LOS.

### LOW

- Catálogo repartido entre player/enemies/world/lighting; moverlo no resuelve authoring.
- FogAppearance necesita hijos editables; considerar acceso claro a affected_by_fog
  sin cambiar LOS. Window requiere principalmente ayuda/etiquetas.

## 5. Proposed implementation phases / exact files expected to change

Una fase por sesión, rutas actuales. No tocar archivos de una fase cuyo cambio no
resulte necesario. Actualizar architecture al implementar, no durante esta auditoría.

1. **Items: preview e Inspector.** Preview de definition.icon, escala visual y aviso
   por definición ausente; explicar recurso compartido. Sin cambiar modelos/conexiones.
   Archivos: scripts/items/world_item.gd,
   scenes/prefabs/items/{world_item,key_world_item}.tscn, docs/architecture.md.
   Validar dos instancias, cambio de definición, pickup/drop y llave; no duplicar ammo.
2. **Composición de nivel.** Referencias explícitas a nivel/Player en vez de rutas
   rígidas; conectar items/puertas/luces una vez dentro del nivel por tipos/roles,
   desde composición, sin búsquedas por frame ni managers. Conservar drops runtime.
   Dividir pickups/puertas y luces en sesiones si hace falta.
   Archivos: scripts/app/main.gd, scripts/world/movement_test.gd,
   scenes/app/main.tscn, scenes/world/movement_test.tscn, docs/architecture.md.
   Posible scripts/world/level.gd solo si sustituye responsabilidad real del playground,
   no wrapper. CameraDarkness puede recibir lista sin modificar su shader.
   Validar piezas recién arrastradas, anidadas y drops, sin conexiones duplicadas.
3. **Entorno, un prefab por sesión.** Door: categorías/ayuda y acceso a textura/masa/
   damping sin cambiar defaults/física. Luz: controles y preview seguro. Wall/Window:
   aclaraciones puntuales. Archivos probables:
   scripts/world/{door_2d,decorative_light_2d,level_boundary_2d,window_2d}.gd;
   scenes/prefabs/world/{door_2d,level_boundary_2d,window_2d}.tscn;
   scenes/prefabs/lighting/decorative_light_2d.tscn; docs/architecture.md.
4. **EnemyBase autoría.** HP/visual/tamaño accesibles, shape aislada al editar tamaño;
   sin IA. Archivos: scripts/enemies/enemy_base.gd,
   scenes/prefabs/enemies/enemy_base.tscn, docs/architecture.md. Probar dos instancias.
5. **Catálogo final.** Mover seis escenas existentes a actors/environment según tabla;
   items permanecen. Referencias esperadas: scenes/world/movement_test.tscn,
   scenes/art_reference/art_reference_gallery.tscn, docs/architecture.md. Buscar todas
   las referencias res:// antes de mover; conservar UID/overrides y no crear copias.
   Validar import/headless, playground, drag y git diff --check.

No cambiar Inventory/Equipment/FirearmDefinition por ergonomía. No crear consumibles,
IA, presets masivos ni framework de configuración.

## 6. Risks

- Resources compartidos: preservar identidad de ammo/stacks; datos particulares no
  pertenecen a definición. No recomendar Make Unique para cada pickup indiscriminadamente.
- Movimientos: paths/UID, tests y overrides heredados; inventariar referencias antes
  y después, no regenerar escenas enteras.
- @tool: setters antes de _ready, recursos derivados compartidos y escenas ensuciadas;
  comprobar duplicar/cerrar/reabrir sin nodos acumulados.
- Exports nuevos que controlan hijos: migrar overrides explícitamente; no sobrescribir
  colores, energía, masa o tamaños del playground con defaults de raíz.
- Registro automático: evitar duplicar señales guardadas; delimitar nivel y drops.
  CameraDarkness admite 32 luces; no prometer iluminación ilimitada.
- Insets de puerta no equivalen a ignorar paredes; conservar limitación hitscan.
  Cambiarla sería otra tarea, no polish de Inspector.

## 7. Recommendation

Recommended first implementation task:
Fase 1: WorldItem con preview de definición y escala visual en Inspector, conservando
definition/quantity y conexiones. Beneficio inmediato, pocos archivos y bajo riesgo.
Después fase 2: elimina el verdadero bloqueo a «arrastrar, configurar, jugar».
Reorganizar carpetas puede esperar.
