# 📘 Game Design Document - Infinite Runner 2D

## 1. Resumen Ejecutivo

**Título:** Infinite Runner 2D  
**Género:** Infinite Runner / Plataforma 2D  
**Motor:** Godot 4.x  
**Renderer:** OpenGL 3 (`gl_compatibility`)  
**Plataformas objetivo:** PC (Windows/Linux), Raspberry Pi 5  
**Jugadores:** 1 (single-player)  
**Duración estimada por partida:** 1–5 minutos (altamente variable).

**Pilar de diseño:** Un runner accesible de un solo botón que combina mecánicas de plataforma clásicas (salto, doble salto) con una progresión temática de habilidades tecnológicas (Programación y Ciberseguridad) y contenido audiovisual de campistas.

---

## 2. Concepto y Temática

El jugador controla a un personaje que corre automáticamente por un mundo tecnológico abstracto. El objetivo es recorrer la mayor distancia posible mientras esquiva errores de software (**Bugs**) y servidores vulnerables. A lo largo de la partida recoge habilidades que representan disciplinas de tecnología:

*   **Programación** (`code`) → elimina bugs.
*   **Ciberseguridad** (`cpu`) → neutraliza servidores vulnerables.
*   **Llaves de video** (`key`) → desbloquean testimonios de campistas.

La estética mezcla pixel art / arte digital con una interfaz tipo terminal/HUD futurista.

---

## 3. Estados del Juego

Gestionados por `GameManager` (autoload):

| Estado | Descripción |
|--------|-------------|
| `TITLE` | Pantalla de inicio. Se muestra el splash/título y el prompt para iniciar. |
| `PLAYING` | Partida activa. El jugador corre, salta y esquiva obstáculos. |
| `DEAD` | El jugador ha muerto. Se reproduce animación/SFX correspondiente. |
| `GAME_OVER` | Pantalla final con puntuación, récord, tarjetas de campistas y tip según la causa de muerte. |

### Transiciones

*   `TITLE` → `PLAYING`: al presionar el botón de salto.
*   `PLAYING` → `DEAD`: al caer al vacío, tocar un bug o tocar un servidor.
*   `DEAD` → `GAME_OVER`: tras una espera (animación de muerte o caída).
*   `GAME_OVER` → `PLAYING`: al presionar el botón de salto (restart sin recargar escena).
*   `GAME_OVER` → `TITLE`: tras 60 segundos de inactividad se recarga la escena.

---

## 4. Controles

Un único botón de acción mapeado a `jump` (por defecto `ESPACIO`).

| Contexto | Acción |
|----------|--------|
| Título | Iniciar partida. |
| Partida | Saltar / Doble salto. |
| Video fullscreen (tras 5s) | Minimizar a PiP. |
| Game Over | Reiniciar partida. |

---

## 5. Mecánicas del Jugador

Implementadas en `Player.gd`.

### 5.1 Auto-run

*   El personaje corre hacia la derecha automáticamente.
*   `AUTO_RUN_SPEED = 300 px/s`
*   Cada `500px` recorridos: `+ SPEED_INCREMENT = +5 px/s`
*   Velocidad máxima: `MAX_SPEED = 500 px/s`

### 5.2 Salto

*   `JUMP_VELOCITY = -520 px/s`
*   `MAX_JUMPS = 2`
*   `DOUBLE_JUMP_MULTIPLIER = 0.85` (el segundo salto es un 15% más débil)

### 5.3 Coyote Time

*   `COYOTE_TIME = 0.12s`
*   Permite saltar un breve instante después de abandonar una plataforma.

### 5.4 Jump Buffer

*   `JUMP_BUFFER_TIME = 0.1s`
*   Registra la pulsación del botón justo antes de tocar el suelo.

### 5.5 Salto Variable

*   Soltar el botón mientras el jugador sube reduce `velocity.y` a la mitad, permitiendo saltos cortos.

### 5.6 Muerte

| Causa | Condición | Feedback |
|-------|-----------|----------|
| `fall` | Caer debajo de `Y > 1000` y luego salir de la cámara. | Sonido "fall down", la cámara se desprende del jugador. |
| `bug` | Contacto con un Area2D de bug sin carga de `code`. | Sonido "video-game-death", animación `death`, rebote. |
| `server` | Contacto con un Area2D de servidor sin carga de `cpu`. | Sonido "video-game-death", animación `death`, rebote. |

---

## 6. Obstáculos

Generados proceduralmente por `PlatformSpawner.gd`.

### 6.1 Bug Terrestre

*   Grupo: `bugs`
*   Aparición: desde el inicio.
*   Comportamiento: se mueve lentamente hacia el jugador (`BUG_MOVE_SPEED = 25 px/s`).
*   Colisión: `30x30 px` aproximadamente.
*   Animación: sprite animado con 5 frames.

### 6.2 Bug Volador

*   Grupo: `bugs_fly`
*   Aparición: a partir de dificultad 4 (`roll > 0.70`).
*   Comportamiento: se mueve hacia el jugador y oscila verticalmente con seno.

### 6.3 Servidor

*   Grupo dinámico: `server_cluster_<id>`
*   Aparición: tras desbloquear ciberseguridad (primera llave/tutorial).
*   Tamaño: `48x48 px` por unidad.
*   Cooldown: `1000 px` entre apariciones de servidores.
*   Puede aparecer en torres de 1–2 unidades de alto.

---

## 7. Sistema de Power-Ups

Implementado en `PowerUp.gd` y gestionado por `PlatformSpawner.gd`.

### 7.1 SkillUp: Programación (`code`)

*   Ícono: `res://assets/powerups/powerup_code.png`
*   Efecto: carga única. Al chocar con un bug, el bug es eliminado y se suma `+1` a **Bugs eliminados**.
*   SFX: `correct-game-show-alert-499485`
*   Spawn: al inicio de patrones de obstáculos.

### 7.2 SkillUp: Ciberseguridad (`cpu`)

*   Ícono: `res://assets/powerups/powerup_cpu.png`
*   Efecto: carga única. Al chocar con un servidor, el servidor se neutraliza (se vuelve azul) y se suma `+1` a **Servidores asegurados**.
*   SFX: `correct-game-show-alert-499485`
*   Desbloqueo: tras el tutorial de CPU (tras la primera llave).

### 7.3 Llave de Video (`key`)

*   Ícono: `res://assets/powerups/powerup_key.png`
*   Efecto: incrementa `keys_collected` y reproduce un video testimonial.
*   Máximo por sesión: `6` llaves.
*   Espaciado mínimo: `2500` puntos entre llaves.
*   Primera llave: alrededor de `600` puntos.

---

## 8. Sistema de Videos / Campistas

Implementado en `HUD.gd`.

### 8.1 Reproducción

*   Al recoger una llave, el juego elige aleatoriamente un video no visto.
*   El video se reproduce en pantalla completa.
*   `get_tree().paused = true` durante la reproducción fullscreen.

### 8.2 Minimización a PiP

*   Tras `5` segundos, el prompt "Presione el botón para minimizar" aparece.
*   Al presionar el botón, el video pasa a modo PiP (`320x180 px`) y el juego se reanuda.
*   El video sigue visible en la esquina inferior izquierda durante la partida.

### 8.3 Finalización

*   Cuando el video termina, se cierra automáticamente.
*   Al cerrarse, se reanuda el juego y se actualiza el panel de llaves.

### 8.4 Campistas Desbloqueados

*   Cada video pertenece a un campista.
*   Los campistas cuyos videos han sido vistos aparecen descubiertos en la pantalla de Game Over.
*   Los no descubiertos aparecen con la tarjeta atenuada y texto oculto.

---

## 9. Generación Procedural

Implementada en `PlatformSpawner.gd`.

### 9.1 Chunks

*   Ancho: `CHUNK_WIDTH = 800 px`
*   Generación por adelantado: `SPAWN_AHEAD = 3` chunks.
*   Destrucción por detrás: `DESTROY_BEHIND = 1200 px`.

### 9.2 Dificultad

*   Incremento cada `DIFFICULTY_INTERVAL = 1000 px`.
*   Máximo: `MAX_DIFFICULTY = 4`.

### 9.3 Patrones deChunks

| Patrón | Descripción | Desbloqueo |
|--------|-------------|------------|
| `FLAT_GROUND` | Suelo continuo. | Inicio. |
| `GROUND_GAP_SMALL` | Vacío pequeño. | Inicio. |
| `STEP_UP` | Escalones ascendentes. | Inicio. |
| `GROUND_GAP_LARGE` | Vacío grande con plataforma flotante. | Dificultad 2. |
| `STEP_DOWN` | Escalones descendentes. | Dificultad 2. |
| `OBSTACLE_CORRIDOR` | Pasillo con obstáculos y plataforma flotante. | Dificultad 2. |
| `FLOATING_CHAIN` | Cadena de plataformas flotantes. | Dificultad 3. |
| `OBSTACLE_GAP_COMBO` | Vacío con obstáculos a ambos lados. | Dificultad 3. |
| `MULTI_OBSTACLE_FIELD` | Múltiples grupos de obstáculos. | Dificultad 4. |
| `KEY_EASY` | Suelo plano con llave. | Evento de llave. |

### 9.4 Chunks Iniciales (Tutoriales)

1.  Chunk 0: suelo plano.
2.  Chunk 1: tutorial de salto (`Pulsa el botón para saltar`).
3.  Chunk 2: tutorial de doble salto (`Pulsa de nuevo para doble salto`).
4.  Chunk 3: tutorial de programación (`Programación te protege de bugs`).
5.  Chunk 5: suelo plano (descanso).

Después de la primera llave se genera el tutorial de ciberseguridad.

---

## 10. HUD e Interfaz

Implementado en `HUD.gd`.

### 10.1 Pantalla de Título

*   Imagen de splash a pantalla completa.
*   Prompt parpadeante: "PRESIONA EL BOTÓN PARA INICIAR".

### 10.2 HUD de Partida

*   **Panel de progreso** (esquina superior izquierda):
    *   Puntuación actual.
    *   Récord.
    *   Bugs eliminados.
    *   Servidores asegurados.
*   **Panel de llaves** (parte superior central): 6 slots con miniaturas atenuadas hasta ver el video.
*   **Panel de habilidades** (esquina superior derecha):
    *   Programación (verde).
    *   Ciberseguridad (morado).
    *   Se iluminan cuando la carga está activa.
*   **Logo** (esquina inferior izquierda).

### 10.3 Pantalla de Game Over

*   Fondo del panel (textura en PC, color plano en RPi).
*   Tarjetas de campistas (descubiertos / bloqueados).
*   Mensaje contextual según causa de muerte:
    *   `bug`: "¡Un bug te detuvo!"
    *   `fall`: "¡Caíste al vacío!"
    *   `server`: "¡Un servidor vulnerable bloqueó tu camino!"
*   Iconos de causa y solución.
*   Prompt parpadeante: "PRESIONA EL BOTÓN PARA REINICIAR".
*   Temporizador de 60s para volver automáticamente al título.

---

## 11. Sistema de Puntuación

*   La puntuación aumenta según la distancia recorrida: `score = int(player_x / 10)`.
*   El récord se guarda en `user://highscore.save` como un entero de 32 bits.
*   En la pantalla de Game Over se indica si se batió el récord.

---

## 12. Audio

### 12.1 Música

*   Música de título: `Golden Key Horizon.mp3`
*   Música de partida: `Pixel Dembow Run.mp3`
*   Se detiene en `DEAD` (bug/server) y `GAME_OVER`.
*   Se reduce/atenua durante la reproducción de videos.

### 12.2 Efectos de Sonido

Gestionados por `SFXManager.gd` (pool de 8 reproductores).

| Evento | SFX |
|--------|-----|
| Iniciar / reiniciar | `lolo_s-start-474092` |
| Salto | sonido del nodo `JumpSFX` |
| Doble salto | sonido del nodo `DoubleJumpSFX` |
| Recoger power-up / llave | `correct-game-show-alert-499485` |
| Caída al vacío | `fall down` |
| Muerte por bug/server | `video-game-death` |
| Eliminar bug con carga | `coin_*` (aleatorio) |
| Neutralizar servidor | `sfxs 80s sound effect` |
| Minimizar video a PiP | `game-collect-item-short-550419` |

---

## 13. Balanceo y Valores Clave

| Parámetro | Valor | Ubicación |
|-----------|-------|-----------|
| Velocidad inicial | `300 px/s` | `Player.gd` |
| Incremento de velocidad | `+5 px/s` cada 500px | `Player.gd` |
| Velocidad máxima | `500 px/s` | `Player.gd` |
| Fuerza de salto | `-520 px/s` | `Player.gd` |
| Multiplicador doble salto | `0.85` | `Player.gd` |
| Coyote time | `0.12s` | `Player.gd` |
| Jump buffer | `0.1s` | `Player.gd` |
| Chunk width | `800 px` | `PlatformSpawner.gd` |
| Dificultad interval | `1000 px` | `PlatformSpawner.gd` |
| Máximo llaves | `6` | `PlatformSpawner.gd` / `GameManager.gd` |
| Espaciado llaves | `2500` puntos | `PlatformSpawner.gd` |
| Primera llave | `~600` puntos | `PlatformSpawner.gd` |
| Cooldown servidores | `1000 px` | `PlatformSpawner.gd` |
| Tiempo Game Over auto-reset | `60s` | `HUD.gd` |

---

## 14. Consideraciones Técnicas

*   **No se recarga la escena** al reiniciar; se resetea el estado de `Player`, `PlatformSpawner` y `GameManager`.
*   **Renderer:** `gl_compatibility` para compatibilidad con Raspberry Pi 5.
*   **Modo RPi:** se detecta automáticamente en Linux ARM/aarch64 o se fuerza con `INFINITE_RUNNER_RPI=1`. En este modo se desactivan shaders de blur y se simplifica el panel de Game Over.
*   **Videos:** formato `.ogv` (Theora). En RPi se pueden usar versiones `_rpi.ogv` de menor calidad.

---

## 15. Futuras Mejoras Posibles

*   Añadir más animaciones y variaciones de obstáculos.
*   Implementar logros o desafíos diarios.
*   Soporte para mando/joystick.
*   Más videos y campistas.
*   Modo difícil con mayor velocidad máxima.
*   Leaderboards locales o en línea.
