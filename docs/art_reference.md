# Biblioteca visual Codex

30 referencias SVG independientes, importables como Texture2D por Godot. Paleta apagada:
acero verdoso, madera marrón, latón y vidrio azul gris. Objetos con fondo transparente;
piso y tramos centrales opacos. Los prefabs de prueba referencian una selección de
estas bases; reasignarlas desde Inspector no cambia sus reglas de gameplay.

## Escala y nombres

`<objeto>_<uso>.svg`, snake_case. SVG fija tamaño de importación; para arte final se
puede exportar PNG a las mismas dimensiones y reasignar la textura en Inspector.
No hay pipeline ni dependencia adicional. El README es la lista completa de archivos.

Referencia actual: colisión de silla 36x51 unidades, arte del personaje ~54x54,
puerta 96x12 y ventana 96x16, muro ancho 16; cámara zoom 2.5.

- Items world 96x96: empezar con escala 0.25 (lienzo 24x24 unidades).
- Armas world 128x96: revólver escala 0.25, escopeta 0.4 (32/51 unidades de ancho).
- Inventory 64x64: encajar conservando aspecto en el TextureRect actual 40x44.
- Equipped slot 96x64: encajar conservando aspecto. Reload button 64x64: usar Button.icon.
- Character equipped 64x128: cañón UP. Escala 0.25 directamente bajo Player.
  Si se cuelga del arte escalado a 0.12, escala local aproximada 2.0833 y compensar
  su orientación DOWN con PI. Son armas aisladas, no reemplazos de la pose completa.
- Reload view 300x220: tamaño exacto de layouts actuales. Vista posterior de recámara
  abierta para hacer legibles los alojamientos. Poner detrás de Sockets, mouse_filter IGNORE.
  Revólver: (150,22), (79,66), (221,66), (79,150), (221,150), (150,194).
  Escopeta: (114,108), (186,108). Las marcas no son controles ni balas cargadas.

## Entorno modular

Piso 128x128 repetible en ambos ejes. El prefab de muro usa una sola wall_mid_tile
64x16 repetida por Line2D; wall_slice conserva sus dos bandas al variar Width.
La textura de muro no tiene juntas transversales: los UV de una polilínea con
esquinas las deformaban en diagonales y simulaban una perspectiva inclinada.
Ambos bordes tienen el mismo tono y grosor; el centro es plano y neutral.
Door2D usa una sola door_leaf 96x12 mediante NinePatchRect, manteniendo bisagra,
bordes y picaporte al variar leaf_size. Window2D usa una base 96x16 por estado
(intact/cracked/broken), también mediante NinePatchRect y pane_size. Los antiguos
mid/cap se retiraron porque las bases completas los reemplazan. La jamba independiente
se conserva como referencia opcional; los prefabs no requieren montaje manual de piezas.
Estas texturas no cambian colisiones ni key_id.
El icono de llave sirve a cualquier key_id; la identidad sigue en ItemDefinition.
El curativo es únicamente referencia artística, sin nueva regla de uso.

## Catálogo

| Archivo (.svg) | Tamaño | Uso |
| --- | --- | --- |
| environment/floors/floor_clinic_tile | 128x128 | Piso repetible XY; módulo 128, baldosas 64. |
| environment/walls/wall_mid_tile | 64x16 | Tramo repetible X; Line2D ancho 16. |
| environment/windows/window_intact | 96x16 | Base 9-slice de ventana intacta. |
| environment/windows/window_cracked | 96x16 | Base 9-slice de ventana dañada. |
| environment/windows/window_broken | 96x16 | Base 9-slice del marco roto. |
| environment/windows/window_shards | 96x40 | Restos visibles al romperse. |
| environment/doors/door_leaf | 96x12 | Hoja topdown 96x12; bisagra (0,6). |
| environment/doors/door_frame_jamb | 8x20 | Jamba independiente; duplicar/reflejar en ambos extremos. |
| items/revolver_ammo_inventory | 64x64 | revolver_ammo: inventory; mundo usar escala 0.25 (24 unidades), UI ajustar a 40x44. |
| items/revolver_ammo_world | 96x96 | revolver_ammo: world; mundo usar escala 0.25 (24 unidades), UI ajustar a 40x44. |
| items/shotgun_shell_inventory | 64x64 | shotgun_shell: inventory; mundo usar escala 0.25 (24 unidades), UI ajustar a 40x44. |
| items/shotgun_shell_world | 96x96 | shotgun_shell: world; mundo usar escala 0.25 (24 unidades), UI ajustar a 40x44. |
| items/healing_item_inventory | 64x64 | healing_item: inventory; mundo usar escala 0.25 (24 unidades), UI ajustar a 40x44. |
| items/healing_item_world | 96x96 | healing_item: world; mundo usar escala 0.25 (24 unidades), UI ajustar a 40x44. |
| items/key_inventory | 64x64 | key: inventory; mundo usar escala 0.25 (24 unidades), UI ajustar a 40x44. |
| items/key_world | 96x96 | key: world; mundo usar escala 0.25 (24 unidades), UI ajustar a 40x44. |
| items/generic_pickup_inventory | 64x64 | generic_pickup: inventory; mundo usar escala 0.25 (24 unidades), UI ajustar a 40x44. |
| items/generic_pickup_world | 96x96 | generic_pickup: world; mundo usar escala 0.25 (24 unidades), UI ajustar a 40x44. |
| weapons/world/revolver_world | 128x96 | revolver, world; cañón a la derecha. |
| weapons/inventory/revolver_inventory | 64x64 | revolver, inventory; cañón a la derecha. |
| weapons/equipped_slot/revolver_equipped_slot | 96x64 | revolver, equipped_slot; cañón a la derecha. |
| weapons/reload_button/revolver_reload_button | 64x64 | revolver, reload_button; cañón a la derecha. |
| weapons/character_equipped/revolver_character_equipped | 64x128 | UP local. Escala 0.25 fuera del CharacterVisual: 20 unidades de largo visible. |
| weapons/world/shotgun_world | 128x96 | shotgun, world; cañón a la derecha. |
| weapons/inventory/shotgun_inventory | 64x64 | shotgun, inventory; cañón a la derecha. |
| weapons/equipped_slot/shotgun_equipped_slot | 96x64 | shotgun, equipped_slot; cañón a la derecha. |
| weapons/reload_button/shotgun_reload_button | 64x64 | shotgun, reload_button; cañón a la derecha. |
| weapons/character_equipped/shotgun_character_equipped | 64x128 | UP local. Escala 0.25 fuera del CharacterVisual: 28 unidades de largo visible. |
| weapons/reload_view/revolver_reload_view | 300x220 | Tambor abierto posterior, centros exactos de los 6 Controls actuales; huecos guía decorativos. |
| weapons/reload_view/shotgun_reload_view | 300x220 | Recámara basculada posterior; centros (114,108), (186,108) coinciden con UI. |

## Galería

Abrir `res://scenes/art_reference/art_reference_gallery.tscn` en 2D.
Contiene bases canónicas, estados de ventana, rotaciones de referencia y muestras
repetidas/9-slice; no conserva piezas modulares reemplazadas. Es una escena estática
sin scripts; no es la escena principal. Lienzo 1600x1500: usar zoom del editor para verlo
completo. Las tarjetas reducen solo assets grandes para comparación, no son escala de mundo.

## Perspectiva y clasificación

El mundo es cenital ortográfico a 90°, no 3/4. Muro, hoja y marco son superficies
planas orientables; sus bordes son simétricos, sin iluminación direccional pintada.
El cristal y los shards se leen en planta. Piso repetible XY sin fuga de perspectiva.

- ACTIVE: bases de entorno completas, shards y las texturas referenciadas por
  ItemDefinitions/poses/layouts actuales. WorldItem permite World Sprite por instancia
  y usa definition.world_sprite o icon como fallback; los dibujos laterales de armas son símbolos de pickup, no
  una referencia de perspectiva del personaje.
- REFERENCE: jamba, curativo, variantes world/UI/equipped/reload del catálogo que
  todavía no consume gameplay. Sus dimensiones/propósitos difieren: no son duplicados.
- OBSOLETE (retirados): wall_cap, window_mid_tile/window_cap y
  door_mid_tile/door_hinge_cap/door_handle_cap, sustituidos por las bases completas.
- DUPLICATE: no se encontraron archivos de imagen idénticos por hash.
- UNUSED/UNCERTAIN: no se infiere obsolescencia de la ausencia en el playground.
  Se conservan referencias y arte manual; no se eliminan poses de animación.

Las vistas de recarga son diagramas de UI deliberadamente no cenitales. Los iconos
laterales son válidos para UI; antes del arte final, conviene dibujar pickups de
armas inequívocamente cenitales si se quieren representar objetos físicos en el suelo,
no símbolos. No se ha rediseñado el personaje ni cambiado su montaje.
