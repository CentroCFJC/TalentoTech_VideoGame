# Project Context: Plataform-Test (Godot 4.x)

This document provides updated context for AI agents working on this project. It outlines the game mechanics, technical structure, and development restrictions.

## 🕹️ Game Overview
An infinite runner platformer where the player automatically runs to the right, jumping over gaps and obstacles (Bugs and Servers). The game features power-ups that grant temporary abilities and a progressive difficulty system.

## 🛠️ Core Mechanics

### Player Movement (`scripts/Player.gd`)
- **Auto-Run**: Moves right automatically.
  - Initial Speed: `300.0` px/s.
  - Speed Increment: `+5.0` every 500m.
  - Max Speed: `500.0` px/s.
- **Jumping**:
  - Velocity: `-520.0` (upwards).
  - **Double Jump**: Max 2 jumps. Second jump is slightly weaker (`0.85` multiplier).
  - **Variable Jump**: Releasing the jump button mid-air cuts vertical velocity by half.
  - **Coyote Time**: `0.12s` window to jump after leaving a platform.
  - **Jump Buffer**: `0.1s` window to register a jump input before hitting the ground.
- **Death**:
  - Triggered by hitting obstacles (Bugs or Servers) or falling below `Y = 1000`.
  - Notifies `GameManager` with a cause (`"bug"`, `"server"`, or `"fall"`) and disables collisions.
- **Animations**: Uses `AnimatedSprite2D` with programmatically created `SpriteFrames` (run, jump, double_jump, fall, death).

### Obstacles
- **Bugs**: Small enemies placed on platforms. Can be stomped when the "code" power-up is active.
- **Servers**: Vertical stacks (1–3 tall) of server racks. Can be passed through when the "cpu" power-up is active.
  - Servers only spawn when score ≥ 150 and have a 1000px cooldown between spawns.

### Power-Up System (`scripts/PowerUp.gd`)
- **Types**: `speed`, `jump`, `invulnerability`, `code`, `cpu`.
- **Spawning**: Every ~18s a power-up spawns on the next created platform (50/50 `code` or `cpu`).
- **Duration**: Default 10 seconds per power-up.
- **Key Power-Ups**:
  - `code` (SkillUp: Programación): Grants bug-stomping ability. Player glows green.
  - `cpu` (SkillUp: Hardware): Allows passing through servers (turns them blue). Player glows blue.
- **HUD Notification**: Shows icon, timer, and description. Timer flashes red under 3s.

### Procedural Generation (`scripts/PlatformSpawner.gd`)
- **Chunks**: The world is generated in chunks of `800px` width.
- **Difficulty**: Increases every `1000px` of distance, unlocking harder patterns (Max Difficulty: 4).
- **Patterns**:
  - `FLAT_GROUND`: Simple horizontal platforms (first 2 chunks include tutorial panels).
  - `GROUND_GAP_SMALL/LARGE`: Gaps in the ground (large gaps may include a floating mid-platform).
  - `STEP_UP/STEP_DOWN`: Platforms that go up or down.
  - `FLOATING_CHAIN`: Chains of floating platforms.
  - `OBSTACLE_CORRIDOR`: Ground with 2–3 bugs/servers and a floating escape platform.
  - `OBSTACLE_GAP_COMBO`: Obstacles placed near gap edges.
  - `MULTI_OBSTACLE_FIELD`: Multiple clusters of obstacles across the ground.
- **Constraints**:
  - Max Height Difference: `120.0` px.
  - Min Gap Width: `80.0` px.
  - Max Gap Width: `200.0` px.

### HUD (`scripts/HUD.gd`)
- Displays score and best score during gameplay.
- **Title Screen**: Shows best score and blinking prompt ("Presiona El Botón para jugar").
- **Game Over Screen**: Stylized semi-transparent card with contextual death cause:
  - `"bug"` death: Shows bug sprite + code power-up hint.
  - `"server"` death: Shows server sprite + cpu power-up hint.
  - `"fall"` death: Shows double-jump tip.
- **Power-Up Panel**: Left-side notification under score with icon (pulsing animation), timer, and description.

## 🏗️ Technical Architecture

### Scene Structure
- **Player**: `CharacterBody2D` with an `AnimatedSprite2D` and `CollisionShape2D`.
- **Spawner**: `Node2D` that dynamically adds `StaticBody2D` (platforms) and `Area2D` (bugs, servers).
- **Enemy**: `CharacterBody2D` that patrols or chases the player. Can be defeated via `die()` (squash animation).
- **PowerUp**: `Area2D` with `Sprite2D`, floating bob animation. Collected on player contact.

### Collision Layers
- **Layer 1 (Mask 1)**: Player
- **Layer 2 (Mask 2)**: Environment (Platforms)
- **Layer 3 (Mask 4)**: Enemies
- **Layer 4 (Mask 8)**: Collectibles (PowerUps)
- **Layer 5 (Mask 16)**: Hazards (Bugs, Servers)

### Global Managers
- **`GameManager`**: Handles game states (`TITLE`, `PLAYING`, `DEAD`, `GAME_OVER`).
  - **Score**: Calculated as `int(player_x / 10.0)`, plus bonus points from stomps and power-up pickups.
  - **Death Cause**: Stored in `death_cause` (`"bug"`, `"server"`, `"fall"`, or `""`).
  - **Persistence**: High score saved to `user://highscore.save`.

## ⚠️ Restrictions & Guidelines
- **Procedural Safety**: Any new platform pattern must ensure it is jumpable at the minimum speed (`300.0`).
- **Signal Usage**: Prefer using signals for cross-node communication (e.g., `GameManager.state_changed`, `Player.powerup_changed`).
- **Code Style**: Use typed GDScript (e.g., `var speed: float = 0.0`) for better performance and AI readability.
- **Animations**: The player uses `AnimatedSprite2D` with `SpriteFrames` built programmatically from `res://assets/rocket/` images.
- **Obstacles**:  Bugs and Servers 
- **Server Cooldown**: Minimum 1000px between server obstacle spawns.

## 📂 Key Files
- `scripts/Player.gd`: Main player logic, movement, jumping, power-up state, and animations.
- `scripts/PlatformSpawner.gd`: World generation, obstacle placement, and power-up spawning.
- `scripts/GameManager.gd`: (Autoload) Game state, score, death cause, and high-score persistence.
- `scripts/HUD.gd`: UI for score, title screen, game over (contextual), and power-up notifications.
- `scripts/PowerUp.gd`: Collectible logic, bob animation, and effect application.
- `scripts/Enemy.gd`: Patrol and chase behavior.
- `scripts/Hazard.gd`: Generic damage area (kill zones).
- `scenes/Player.tscn`: Player scene definition.
- `scenes/PowerUp.tscn`: Power-up scene definition.
- `project.godot`: Project settings.
