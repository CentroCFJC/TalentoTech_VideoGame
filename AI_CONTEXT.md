# Project Context: Plataform-Test (Godot 4.x)

This document provides updated context for AI agents working on this project. It outlines the game mechanics, technical structure, and development restrictions.

## 🕹️ Game Overview
An infinite runner platformer where the player automatically runs to the right, jumping over gaps and spikes.

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
  - Triggered by hitting hazards (Spikes) or falling below `Y = 1000`.
  - Notifies `GameManager` and disables collisions.

### Procedural Generation (`scripts/PlatformSpawner.gd`)
- **Chunks**: The world is generated in chunks of `800px` width.
- **Difficulty**: Increases every `1000px` of distance, unlocking harder patterns (Max Difficulty: 4).
- **Patterns**:
  - `FLAT_GROUND`: Simple horizontal platforms.
  - `GAPS`: Small or large gaps (Large gaps may include a floating mid-platform).
  - `STEPS`: Platforms that go up or down.
  - `SPIKES`: Static hazards that kill the player on contact.
- **Constraints**:
  - Max Height Difference: `120.0` px.
  - Min Gap Width: `80.0` px.
  - Max Gap Width: `200.0` px.

## 🏗️ Technical Architecture

### Scene Structure
- **Player**: `CharacterBody2D` with a `Sprite2D` and `CollisionShape2D`.
- **Spawner**: `Node2D` that dynamically adds `StaticBody2D` (platforms) and `Area2D` (spikes).
- **Enemy**: `CharacterBody2D` that patrols or chases the player. Can be defeated via `die()` (squash animation).

### Collision Layers
- **Layer 1**: Player
- **Layer 2**: Environment (Platforms)
- **Layer 3 (Mask 4)**: Enemies
- **Layer 5 (Mask 16)**: Hazards (Spikes)

### Global Managers
- **`GameManager`**: Handles game states (`TITLE`, `PLAYING`, `DEAD`, `GAME_OVER`).
  - **Score**: Calculated as `int(player_x / 10.0)`.
  - **Persistence**: High score saved to `user://highscore.save`.

## ⚠️ Restrictions & Guidelines
- **Procedural Safety**: Any new platform pattern must ensure it is jumpable at the minimum speed (`300.0`).
- **Signal Usage**: Prefer using signals for cross-node communication (e.g., `GameManager.state_changed`).
- **Code Style**: Use typed GDScript (e.g., `var speed: float = 0.0`) for better performance and AI readability.
- **Animations**: The player uses a simple frame-based animation system on a single `Sprite2D`.

## 📂 Key Files
- `scripts/Player.gd`: Main player logic.
- `scripts/PlatformSpawner.gd`: World generation logic.
- `scripts/GameManager.gd`: (Autoload) Game state and score management.
- `scripts/Enemy.gd`: Patrol and chase behavior.
- `scenes/Player.tscn`: Player scene definition.
- `project.godot`: Project settings.
