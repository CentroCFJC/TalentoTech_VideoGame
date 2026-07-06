# 🏃‍♂️ Infinite Runner 2D - Godot 4

Un videojuego estilo plataforma de tipo **Infinite Runner procedural** desarrollado en **Godot 4.x**. El jugador corre automáticamente hacia la derecha mientras esquiva obstáculos (**Bugs** y **Servidores**), recolecta power-ups y habilidades, y trata de alcanzar la mayor distancia posible. La dificultad y la velocidad aumentan progresivamente a medida que avanza.

---

## 🕹️ Mecánicas del Juego

*   **Movimiento Automático (Auto-Run)**: El jugador corre hacia la derecha de forma constante.
    *   *Velocidad inicial*: `300 px/s`.
    *   *Incremento*: `+5 px/s` cada 500 metros recorridos.
    *   *Velocidad máxima*: `500 px/s`.
*   **Salto y Doble Salto**: El jugador puede realizar hasta dos saltos seguidos. El segundo salto es ligeramente más débil (`85%` de la fuerza del primero).
*   **Salto Variable**: Soltar el botón de salto en el aire reduce la velocidad vertical a la mitad, permitiendo controlar la altura del salto.
*   **Coyote Time**: Ventana de tolerancia de `0.12s` para saltar tras abandonar el borde de una plataforma.
*   **Jump Buffer**: Ventana de `0.1s` para registrar el botón de salto antes de tocar el suelo.
*   **Muerte**: Ocurre al caer al vacío (`Y > 1000`), chocar con un **Bug** o impactar con un **Servidor**.

---

## 🐛 Obstáculos

*   **Bugs**: Enemigos que aparecen sobre las plataformas. Matan al jugador por contacto. Si el jugador tiene la habilidad **Programación** (`code`) activa, el bug se elimina y cuenta como estadística.
*   **Bugs Voladores**: Variantesaérea que aparece a partir de cierta dificultad.
*   **Servidores**: Torres de racks que bloquean el camino. Si el jugador tiene la habilidad **Ciberseguridad** (`cpu`) activa, el servidor se neutraliza y se vuelve azul.
    *   Los servidores se desbloquean tras la primera llave/tutorial de CPU.
    *   Tienen un cooldown de `1000px` entre apariciones.

---

## ⚡ Sistema de Power-Ups

Los power-ups se generan en patrones de obstáculos y en tutoriales.

| Power-Up | Tipo | Efecto | Máx. cargas |
|----------|------|--------|-------------|
| **SkillUp: Programación** | `code` | Carga única que elimina un bug al chocar con él y suma a "Bugs eliminados". | 3 |
| **SkillUp: Ciberseguridad** | `cpu` | Carga única que neutraliza un servidor al chocar con él y suma a "Servidores asegurados". | 3 |
| **Llave de Video** | `key` | Recolecta una de las 6 llaves de la sesión y reproduce un video testimonial. | — |

El HUD muestra el progreso de habilidades en la esquina superior derecha y las llaves recolectadas en la parte superior central.

### Aros de habilidad

Cada habilidad activa muestra un aro alrededor del personaje usando sprites de `assets/barreras/`:

*   **Programación**: aro verde (green-1, green-2, green-3 según el nivel de carga).
*   **Ciberseguridad**: aro azul (blue-1, blue-2, blue-3 según el nivel de carga).
*   Cada aro se divide en mitad superior (detrás del personaje) y mitad inferior (delante), creando profundidad.
*   Los sprites se auto-centran horizontalmente por nivel para compensar diferencias en los PNG.

---

## 🎬 Sistema de Videos / Llaves

Durante una partida se pueden recolectar hasta **6 llaves**. Cada llave reproduce un video testimonial en pantalla completa. Tras 5 segundos, el jugador puede minimizar el video a **modo PiP** (picture-in-picture) para seguir jugando. Los videos vistos se marcan en el panel de llaves del HUD y desbloquean tarjetas de campistas en la pantalla de Game Over.

---

## 🗺️ Generación Procedural y Dificultad

El mundo se genera dinámicamente mediante **chunks** de `800px` de ancho. La dificultad escala cada `1000px` recorridos (hasta nivel 4 máximo), desbloqueando patrones más desafiantes:

1.  **Dificultad 0 – 1**: Suelo plano (`FLAT_GROUND`), pequeños vacíos (`GROUND_GAP_SMALL`), escalones hacia arriba (`STEP_UP`).
2.  **Dificultad 2**: Grandes vacíos (`GROUND_GAP_LARGE`), escalones hacia abajo (`STEP_DOWN`) y pasillos con obstáculos (`OBSTACLE_CORRIDOR`).
3.  **Dificultad 3**: Cadenas de plataformas flotantes (`FLOATING_CHAIN`) y combos de obstáculos al borde del vacío (`OBSTACLE_GAP_COMBO`).
4.  **Dificultad 4**: Múltiples grupos de obstáculos seguidos (`MULTI_OBSTACLE_FIELD`).

Los primeros chunks son tutoriales fijos (salto, doble salto, power-up de programación). La primera llave desbloquea el tutorial de ciberseguridad.

---

## 🏗️ Arquitectura Técnica

### Escenas (`scenes/`)
*   `Main.tscn`: Escena principal. Contiene el fondo parallax, el jugador, el spawner de plataformas, el HUD y el reproductor de música.
*   `Player.tscn`: El jugador (`CharacterBody2D`) con `AnimatedSprite2D`, colisionador y sonidos de salto.
*   `PowerUp.tscn`: Objeto recolectable para mejoras (`code`, `cpu`, `key`).

### Scripts (`scripts/`)
*   `Player.gd`: Físicas del personaje, auto-run, saltos, estados, animaciones y sistema de power-ups.
*   `PlatformSpawner.gd`: Generación procedural de plataformas, obstáculos (bugs/servers) y power-ups.
*   `GameManager.gd` *(Autoload)*: Estado global (`TITLE`, `PLAYING`, `DEAD`, `GAME_OVER`), puntuación, récord, llaves y guardado en `user://highscore.save`.
*   `HUD.gd`: Interfaz completa: título, HUD de partida, videos y pantalla de Game Over contextual.
*   `PowerUp.gd`: Lógica de los coleccionables y animación de recolección.
*   `SFXManager.gd` *(Autoload)*: Gestor centralizado de efectos de sonido con pool de reproductores.
*   `MusicPlayer.gd`: Música de fondo con estados para título, partida y game over.
*   `Background.gd`: Movimiento del fondo parallax.

### Capas de Colisión (Physics Layers)
*   **Capa 1**: Jugador (Player)
*   **Capa 2**: Escenario / Plataformas (Environment)
*   **Capa 5**: Obstáculos / Hazards (Bugs, Servidores)

### Renderer
El proyecto usa **OpenGL 3 (`gl_compatibility`)** como método de renderizado por defecto para máxima compatibilidad, incluida **Raspberry Pi 5**.

---

## 🚀 Cómo Empezar

### Requisitos
1.  **Godot Engine 4.x**.

### Configuración e Instalación

1.  Clona el repositorio en tu máquina local:
    ```bash
    git clone https://github.com/CentroCFJC/TalentoTech_VideoGame.git
    cd TalentoTech_VideoGame
    ```
2.  Abre **Godot Engine 4** e importa el proyecto seleccionando `project.godot`.
3.  Presiona **F5** para ejecutar la escena principal (`Main.tscn`).

---

## 🍓 Raspberry Pi 5

El proyecto está configurado para usar **OpenGL 3 (`gl_compatibility`)** por defecto, que es el renderer más estable en la Raspberry Pi 5. No es necesario pasar `--rendering-driver opengl3` al ejecutar el exportado.

Para forzar el modo de bajo rendimiento (menores efectos gráficos en el Game Over, paneles simplificados, etc.) puedes usar la variable de entorno:

```bash
INFINITE_RUNNER_RPI=1 ./Infinite\ Runner.arm64
```

---

## ⌨️ Controles

*   `ESPACIO` / **El Botón**:
    *   **Menú Principal**: Iniciar juego.
    *   **Durante el Juego**: Saltar / Doble salto.
    *   **Pantalla Game Over**: Reiniciar partida.
*   **Durante un video fullscreen**:
    *   Tras 5 segundos, `ESPACIO` / **El Botón** minimiza el video a PiP.

---

## 📄 Documentación Adicional

*   [`GDD.md`](GDD.md) - Documento de Diseño del Juego (Game Design Document).
