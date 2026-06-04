# 🏃‍♂️ Infinite Runner 2D - Godot 4

Un videojuego estilo plataforma de tipo **Infinite Runner procedural** desarrollado en **Godot 4.x**. El juego desafía al jugador a correr de forma automática hacia la derecha mientras esquiva obstáculos (**Bugs** y **Servidores**), recolecta power-ups y alcanza la mayor distancia posible, con una dificultad progresiva e incremento de velocidad a medida que avanza.

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
*   **Muerte**: Ocurre al caer al vacío (`Y > 1000`), chocar con un **Bug** o impactar con un **Servidor**.

---

## 🐛 Obstáculos

*   **Bugs**: Enemigos pequeños que aparecen sobre las plataformas. Matan al jugador por contacto. Pueden ser aplastados si el power-up **SkillUp: Programación** (`code`) está activo.
*   **Servidores**: Torres de racks de servidores (1–3 unidades de alto). Bloquean el camino del jugador. Pueden ser atravesados si el power-up **SkillUp: Hardware** (`cpu`) está activo (se vuelven azules al ser atravesados).
    *   Los servidores solo aparecen cuando el puntaje ≥ 150 y tienen un cooldown de 1000px entre apariciones.

---

## ⚡ Sistema de Power-Ups

Los power-ups aparecen cada ~18 segundos sobre la siguiente plataforma generada. Tipos disponibles:

| Power-Up | Tipo | Duración | Efecto |
|----------|------|----------|--------|
| **SkillUp: Programación** | `code` | 10s | Permite aplastar bugs al caer sobre ellos. Brillo verde. |
| **SkillUp: Hardware** | `cpu` | 10s | Permite atravesar servidores (se vuelven azules). Brillo azul. |

El HUD muestra una notificación con el ícono del power-up (animación de pulso), un temporizador (parpadea en rojo bajo 3s) y una descripción del efecto activo.

---

## 🗺️ Generación Procedural y Dificultad

El mundo se genera dinámicamente mediante **chunks** de `800px` de ancho. La dificultad escala cada `1000px` recorridos (hasta nivel 4 máximo), desbloqueando patrones de plataformas más desafiantes:

1.  **Dificultad 0 – 1**: Suelo plano (`FLAT_GROUND`), pequeños vacíos (`GROUND_GAP_SMALL`), escalones hacia arriba (`STEP_UP`).
2.  **Dificultad 2**: Grandes vacíos (`GROUND_GAP_LARGE`), escalones hacia abajo (`STEP_DOWN`), y pasillos con obstáculos (`OBSTACLE_CORRIDOR`).
3.  **Dificultad 3**: Cadenas de plataformas flotantes (`FLOATING_CHAIN`) y combos de obstáculos al borde del vacío (`OBSTACLE_GAP_COMBO`).
4.  **Dificultad 4**: Múltiples grupos de obstáculos seguidos (`MULTI_OBSTACLE_FIELD`).

---

## 🏗️ Arquitectura Técnica

### Estructura de Escenas (`scenes/`)
*   `Main.tscn`: Escena principal que orquesta el juego (contiene el fondo, el HUD, el Spawner de plataformas y la KillZone).
*   `Player.tscn`: El jugador (`CharacterBody2D`) con su colisionador y `AnimatedSprite2D`.
*   `Enemy.tscn`: Enemigo patrullero/perseguidor que puede ser derrotado al saltar sobre él.
*   `PowerUp.tscn`: Objeto recolectable para mejoras temporales (SkillUps).

### Scripts Clave (`scripts/`)
*   `Player.gd`: Controla las físicas del personaje, saltos, estados, animaciones y sistema de power-ups.
*   `PlatformSpawner.gd`: Lógica de generación dinámica de plataformas, colocación de obstáculos (Bugs y Servidores) y spawn de power-ups sobre plataformas.
*   `GameManager.gd` *(Autoload)*: Administrador global de estado (`TITLE`, `PLAYING`, `DEAD`, `GAME_OVER`). Maneja eventos de muerte (con causa: `"bug"`, `"server"`, `"fall"`), puntajes y guarda la puntuación máxima en `user://highscore.save`.
*   `HUD.gd`: Interfaz del juego: puntuación en tiempo real, pantalla de título, pantalla de Game Over contextual (muestra tips según la causa de muerte) y notificaciones de power-ups.
*   `PowerUp.gd`: Lógica del coleccionable: animación de flotación, aplicación de efecto al jugador y animación de recolección.
*   `Enemy.gd`: Lógica de patrullaje de enemigos y persecución cuando el jugador entra en su rango.
*   `Hazard.gd`: Área de daño genérica (zonas mortales).

### Capas de Colisión (Physics Layers)
*   **Capa 1**: Jugador (Player)
*   **Capa 2**: Escenario / Plataformas (Environment)
*   **Capa 3**: Enemigos (Enemies)
*   **Capa 4**: Coleccionables (PowerUps)
*   **Capa 5**: Obstáculos / Hazards (Bugs, Servidores)

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

*   `ESPACIO` / **El Botón**:
    *   **Menú Principal**: Iniciar juego.
    *   **Durante el Juego**: Saltar / Doble salto.
    *   **Pantalla Game Over**: Reiniciar partida.
