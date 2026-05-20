# 🏃‍♂️ Infinite Runner 2D - Godot 4

Un videojuego estilo plataforma de tipo **Infinite Runner procedural** desarrollado en **Godot 4.x**. El juego desafía al jugador a correr de forma automática hacia la derecha mientras esquiva obstaculos, con una dificultad progresiva e incremento de velocidad a medida que avanza.

---

## 🕹️ Mecánicas del Juego

*   **Movimiento Automático (Auto-Run)**: El jugador corre hacia la derecha de forma constante.
    *   *Velocidad inicial*: `300 px/s`.
    *   *Incremento*: `+5 px/s` cada 500 metros.
    *   *Velocidad máxima*: `500 px/s`.
*   **Salto y Doble Salto**: El jugador puede realizar hasta dos saltos seguidos. El segundo salto es ligeramente más débil (`85%` de la fuerza del primero).
*   **Salto Variable**: Soltar el botón de salto en el aire corta la velocidad vertical a la mitad, permitiendo controlar la altura del salto.
*   **Coyote Time**: Ventana de tolerancia de `0.12s` para saltar tras haber abandonado el borde de una plataforma.
*   **Jump Buffer**: Ventana de `0.1s` para registrar el botón de salto antes de tocar el suelo.
*   **Muerte**: Ocurre al caer al vacío (`Y > 1000`) o al chocar con espinas/obstáculos.

---

## 🗺️ Generación Procedural y Dificultad

El mundo se genera dinámicamente mediante **chunks** de `800px` de ancho. La dificultad escala cada `1000px` recorridos (hasta nivel 4 máximo), desbloqueando patrones de plataformas más desafiantes:

1.  **Dificultad 0 - 1**: Suelo plano (`FLAT_GROUND`), pequeños vacíos (`GROUND_GAP_SMALL`), escalones hacia arriba (`STEP_UP`).
2.  **Dificultad 2**: Grandes vacíos (`GROUND_GAP_LARGE`), escalones hacia abajo (`STEP_DOWN`), y pasillos de espinas en el suelo (`SPIKE_CORRIDOR`).
3.  **Dificultad 3**: Cadenas de plataformas flotantes (`FLOATING_CHAIN`) y combos de espinas al borde del vacío (`SPIKE_GAP_COMBO`).
4.  **Dificultad 4**: Múltiples zonas de espinas seguidas (`MULTI_SPIKE_FIELD`).

---

## 🏗️ Arquitectura Técnica

### Estructura de Escenas (`scenes/`)
*   `Main.tscn`: Escena principal que orquesta el juego (contiene el fondo, el HUD, el Spawner de plataformas y la KillZone).
*   `Player.tscn`: El jugador (`CharacterBody2D`) con su colisionador y sprite.
*   `Enemy.tscn`: Enemigo patrullero/perseguidor que puede ser derrotado al saltar sobre él.
*   `PowerUp.tscn`: Objeto recolectable para mejoras temporales.

### Scripts Clave (`scripts/`)
*   `Player.gd`: Controla las físicas del personaje, saltos, estados y animaciones de frames.
*   `PlatformSpawner.gd`: Lógica de generación dinámica de plataformas y colocación de obstáculos de forma segura (garantiza saltabilidad a velocidad mínima).
*   `GameManager.gd` *(Autoload)*: Administrador global de estado (`TITLE`, `PLAYING`, `DEAD`, `GAME_OVER`). Maneja los eventos de muerte, los puntajes y guarda la puntuación máxima localmente en `user://highscore.save`.
*   `HUD.gd`: Controla el parpadeo de interfaces y muestra la puntuación del juego en tiempo real.
*   `Enemy.gd`: Lógica de patrullaje de enemigos y persecución cuando el jugador entra en su rango.

### Capas de Colisión (Physics Layers)
*   **Capa 1**: Jugador (Player)
*   **Capa 2**: Escenario / Plataformas (Environment)
*   **Capa 5**: Obstáculos / Espinas (Hazards)

---

## 🚀 Cómo Empezar

### Requisitos
1.  **Godot Engine 4.x** (compatible con Forward+ / Mobile).

### Configuración e Instalación

1.  Clona el repositorio en tu máquina local:
    ```bash
    git clone https://github.com/CentroCFJC/TalentoTech_VideoGame.git
    cd TalentoTech_VideoGame
    ```
2.  Abre **Godot Engine 4** e importa este proyecto seleccionando el archivo `project.godot`.
3.  Presiona **F5** para ejecutar la escena principal (`Main.tscn`).

---

## ⌨️ Controles

*   `ESPACIO`:
    *   **Menú Principal**: Iniciar juego.
    *   **Durante el Juego**: Saltar / Doble salto.
    *   **Pantalla Game Over**: Reiniciar partida.
