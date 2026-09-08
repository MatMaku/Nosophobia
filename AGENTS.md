Objetivo del proyecto

Este repositorio contiene un juego 2D top-down desarrollado con Godot.

El proyecto será mantenido manualmente y mediante herramientas de IA como Codex.

La prioridad es mantener una base de código:

simple;

legible;

modular;

fácil de modificar;

fácil de revisar;

con bajo acoplamiento;

y con la menor complejidad accidental posible.

No introducir arquitectura, abstracciones o sistemas pensando únicamente en posibles necesidades futuras.

Godot y lenguaje

Usar GDScript por defecto.

Respetar la versión estable de Godot utilizada por el proyecto.

Si todavía no se ha fijado una versión, usar Godot 4.7.x estable.

No usar APIs exclusivas de versiones dev, beta o preview sin autorización.

Preferir APIs oficiales de Godot antes que frameworks propios.

Principios arquitectónicos

Single Responsibility

Cada script, escena, componente o recurso debe tener una responsabilidad clara.

Ejemplos:

movimiento → controla movimiento;

armas → controla disparos;

salud → controla vida y daño;

animaciones → controla presentación visual;

UI → muestra información;

persistencia → guarda y carga datos.

Una responsabilidad NO implica automáticamente crear un script nuevo.

No dividir código trivial si la separación solamente agrega indirección.

Composición sobre herencia

Preferir:

escenas compuestas;

nodos hijos especializados;

Resources;

señales;

pequeñas APIs explícitas.

Evitar árboles profundos de herencia.

Usar herencia solamente cuando exista una relación real "es un" y la clase derivada pueda sustituir correctamente a la base.

Capas conceptuales

La arquitectura se divide conceptualmente en cuatro áreas.

Domain / Data

Contiene reglas y datos independientes del SceneTree cuando sea posible.

Preferir:

Resource;

RefCounted;

clases simples.

No debe depender de:

UI;

animaciones;

escenas concretas;

persistencia;

jerarquías de nodos.

Gameplay

Contiene comportamiento del juego conectado con Godot.

Ejemplos:

actores;

movimiento;

combate;

interacción;

enemigos;

mundo;

pickups.

Gameplay puede depender de Domain/Data.

Presentation

Contiene:

animaciones;

partículas;

audio;

HUD;

feedback visual;

menús.

Presentation puede observar Gameplay.

Gameplay no debe depender innecesariamente de Presentation.

Una AnimationPlayer o un HUD nunca debe convertirse en la fuente de verdad de una regla de gameplay.

Infrastructure

Contiene sistemas externos al gameplay.

Ejemplos:

save/load;

configuración;

integración con plataformas;

servicios externos.

Mantener estas responsabilidades separadas de las reglas del juego.

Comunicación entre sistemas

Preferir este orden:

llamada directa cuando un objeto posee explícitamente al otro;

señales para notificar eventos;

inyección de dependencias desde el nodo que compone el sistema.

Evitar:

cadenas de get_parent();

rutas absolutas del SceneTree;

buscar nodos repetidamente;

dependencias ocultas;

estado global usado como atajo.

Usar señales especialmente cuando el emisor no necesita conocer quién escucha.

Ejemplos:

signal died
signal health_changed(current_health: float)
signal weapon_fired

No crear un EventBus global salvo que exista una necesidad concreta.

Autoloads

Usar Autoload solamente para sistemas verdaderamente globales y persistentes.

Posibles ejemplos:

flujo global de escenas;

configuración del juego;

acceso persistente a partidas guardadas.

No convertir sistemas normales de gameplay en Autoloads.

Evitar clases globales llamadas GameManager, PlayerManager,
EnemyManager, etc. salvo que exista una responsabilidad global claramente justificada.

Diseño de actores

Preferir composición.

Ejemplo conceptual de Player:

Player
├── MovementComponent
├── WeaponComponent
├── HealthComponent
├── AnimationController
└── ...

El nodo raíz debe actuar principalmente como punto de composición/coordinación.

No crear todos los componentes posibles desde el principio.

Crear un componente solamente cuando exista una responsabilidad real que separar.

Movimiento

El sistema de movimiento debe ocuparse del movimiento.

No debe decidir qué tecla física presionó el jugador.

Por ejemplo:

movement.move(direction)

La traducción:

Input → intención → movimiento

debe realizarse fuera de la lógica interna del movimiento.

Si el manejo de input es pequeño, el controlador principal puede hacerlo.

Crear un InputComponent separado solamente cuando la complejidad lo justifique.

Organización del proyecto

Organizar primero por tipo de recurso y después por feature o dominio.

Las carpetas raíz deben usar nombres descriptivos en snake_case.

Dentro de cada carpeta raíz, agrupar los archivos relacionados mediante
subcarpetas como player, enemies, world o ui.

Estructura inicial recomendada:

res://

scripts/
    player/
    enemies/
    world/
    ui/

scenes/
    app/
    player/
    enemies/
    world/
    ui/

sprites/
    player/
    enemies/
    world/

resources/
    player/
    enemies/
    world/

addons/

docs/

La estructura anterior es orientativa. Crear solamente las carpetas y subcarpetas
que correspondan a archivos existentes; no crear directorios vacíos para features
futuras.

Mantener una correspondencia clara entre las subcarpetas de cada tipo de recurso.

Ejemplo:

scripts/
    player/
        player.gd
        movement_component.gd
        animation_controller.gd

scenes/
    player/
        player.tscn

sprites/
    player/
        player_sprite.png

No colocar todos los archivos directamente en scripts/, scenes/, sprites/ o
resources/. Usar subcarpetas por feature o dominio para evitar carpetas raíz
desordenadas.

No crear una carpeta nueva por cada extensión si el tipo de recurso ya tiene una
ubicación clara.

Usar addons/ para plugins y dependencias externas.

Usar una subcarpeta shared/ dentro del tipo de recurso correspondiente solamente
cuando algo sea realmente compartido.

Convenciones GDScript

Seguir la guía oficial de estilo de Godot.

Usar:

snake_case     → archivos, funciones, variables, signals
PascalCase     → clases y nombres de nodos
CONSTANT_CASE  → constantes

Preferir tipado estático.

Ejemplo:

var speed: float = 200.0

func move(direction: Vector2) -> void:
    ...

Usar := cuando el tipo sea evidente.

Ejemplo:

var direction := Vector2.ZERO

Preferir líneas menores a 100 caracteres.

Una instrucción por línea.

Usar _ para detalles privados cuando corresponda.

Usar @onready para referencias conocidas a nodos propios.

No usar class_name para cada script.

Usarlo cuando disponer de un tipo globalmente identificable aporte un beneficio concreto.

Complejidad del código

Mantener scripts pequeños y fáciles de leer.

Objetivo aproximado:

normalmente 50-150 líneas;

revisar la responsabilidad del script al superar aproximadamente 200 líneas;

funciones pequeñas con una finalidad clara.

Estos números son orientativos, no reglas rígidas.

No dividir un script cohesivo únicamente para reducir su cantidad de líneas.

No crear clases wrapper que solamente reenvían llamadas.

No crear abstracciones con una sola implementación sin una razón concreta.

Datos configurables

Preferir:

propiedades @export;

Resources;

configuración externa;

para valores que probablemente serán balanceados.

Evitar valores mágicos dentro del código cuando sean parámetros de diseño.

No construir un framework data-driven genérico antes de necesitarlo.

Performance

No realizar optimizaciones especulativas.

Evitar problemas evidentes como:

búsquedas repetidas del SceneTree;

carga repetida de Resources;

trabajo innecesario cada frame;

asignaciones innecesarias dentro de hot loops.

Preferir eventos y señales cuando un cálculo no necesita ejecutarse en _process().

Medir antes de introducir optimizaciones complejas.

Reglas para Codex

Antes de modificar archivos:

Leer este AGENTS.md.

Inspeccionar únicamente la parte relevante del proyecto.

Entender las responsabilidades existentes.

Identificar la solución más pequeña que resuelva la tarea.

Durante una tarea:

no refactorizar código no relacionado;

no renombrar APIs innecesariamente;

no introducir plugins sin autorización;

no implementar features no solicitadas;

no crear sistemas pensando únicamente en el futuro;

no duplicar abstracciones existentes;

mantener los cambios pequeños y localizados;

conservar el comportamiento fuera del alcance de la tarea.

Preferir siempre un diff pequeño frente a una reescritura completa.

Edición de escenas y Resources

Al modificar:

.tscn
.tres
.res

preservar todo contenido no relacionado.

No regenerar un archivo entero para realizar un cambio pequeño.

No reordenar nodos o Resources sin necesidad.

Verificar que las rutas res:// continúen siendo válidas.

No modificar código de terceros dentro de addons/ salvo que la tarea lo requiera explícitamente.

Git

Nunca realizar push automáticamente.

No crear ramas salvo que la tarea lo solicite.

No realizar commits salvo que el usuario lo solicite explícitamente.

Mantener los cambios preparados para poder ser revisados mediante git diff.

No modificar ni reformatear archivos que no formen parte de la tarea.

Validación

Después de realizar cambios:

comprobar errores de parseo de GDScript;

comprobar errores de tipos;

comprobar referencias res://;

comprobar referencias entre escenas/nodos;

ejecutar tests existentes si existen;

ejecutar validación headless de Godot cuando resulte práctico;

revisar el diff final.

No introducir un framework de testing únicamente para validar una modificación pequeña.

No afirmar que algo fue probado si no fue probado realmente.

Respuesta final de Codex

Al terminar una tarea indicar de forma breve:

qué se modificó;

qué archivos fueron modificados;

qué validaciones se realizaron;

qué pasos manuales quedan pendientes en Godot;

cualquier supuesto o riesgo importante.

Definition of Done

Una tarea está terminada cuando:

cumple el comportamiento solicitado;

mantiene responsabilidades claras;

mantiene dependencias explícitas;

evita acoplamiento innecesario;

no agrega abstracciones innecesarias;

no introduce refactors fuera del alcance;

respeta las convenciones de Godot/GDScript;

fue validada de forma razonable;

y el diff puede ser comprendido rápidamente por otro desarrollador.
