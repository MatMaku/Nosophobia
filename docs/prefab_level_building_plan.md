# Autoría de niveles: implementación completada

El pedido de implementación posterior sustituyó el orden conservador de la auditoría.
La arquitectura vigente y el catálogo están en [architecture.md](architecture.md).

## Bloques completados

- Catálogo: diez prefabs en actors, environment, items y effects. WorldItem base y
  LevelSession son escenas internas, no piezas adicionales de construcción.
- Composición: Player incluye LevelSession; descubre piezas del nivel una vez y
  mantiene registros por eventos. Sin rutas MovementTest/Player, arrays manuales
  ni conexiones de pickup guardadas en el playground. Admite items anidados y drops.
- Items: Generic/Key/Ammo/Weapon, preview @tool, escala visual independiente y arte
  de mundo separado del icono. Generic/Key editan una definición variante mediante
  proxies no serializados; Ammo/Weapon conservan identidad canónica compartida.
- Entorno: controles habituales en raíz, geometrías derivadas y Resources mutables
  aislados. Puertas conservan tolerancia física y comportamiento de llave existentes.
- Player: tuning principal Movement/Input/Aim/Camera/Debug en raíz.
- Luz: color/energía/radio/caracter en raíz, preview sin polling y registro automático.
- EnemyBase: sprite, escala, HP y collider configurables; no se agregó IA.
- Assets: una raíz assets/sprites por función/procedencia; catálogo visual movido a
  docs/art_reference.md. Se preservaron los assets y UIDs al migrar referencias.
- Playground: mismas posiciones, cantidades y overrides de luz/HP, usando categorías
  canónicas. Main solo instancia el nivel; también puede ejecutarse el nivel directamente.

## Validación y límites

tests/authoring_check.gd carga escenas/Resources y comprueba identidad, serialización,
instancias independientes, auto-integración y comportamiento básico. firearm_check.gd
conserva pruebas de gameplay; su comprobación de spread ahora usa final aim del disparo.
Preview/guardado @tool se comprobó también en contexto de editor.

Se requiere exactamente un Player por escena ejecutada. CameraDarkness conserva el
límite de 32 luces. Los insets de puerta siguen afectando hitscan en sus extremos.
World Sprite override del nodo es presentación de colocación: drops usan el arte de
la definición. Editar la definición canónica de Ammo/Weapon afecta a todo ese tipo.
La valoración estética final y comodidad de los handles quedan para revisión del usuario.

## Revisión de cierre — 26-10-2026

Se completaron las ayudas de Wall y la agrupación avanzada del Inspector de Door,
se retiraron únicamente las carpetas vacías de la migración y se corrigió la nota
del catálogo de arte sobre World Sprite. Las 57 imágenes migradas conservan su
contenido original (hash verificado); no quedan referencias runtime a rutas antiguas.
Comprobación de autoría repetida: 42 escenas/Resources cargados, 0 fallos.
git diff --check correcto. No quedan bloques funcionales del plan sin implementar.
