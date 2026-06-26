#!/usr/bin/env python3
"""
Genera versiones ligeras de los videos para Raspberry Pi / ARM.

Godot decodifica Theora por software y en ARM no utiliza SIMD, por lo que
videos 1080p@30fps suelen producir macrobloques negros y caída de FPS en
Raspberry Pi 5. Este script crea copias con el sufijo *_rpi.ogv a 720p o 480p
(ajustable) para que el juego las cargue automáticamente en esas plataformas.

Requisitos:
    - FFmpeg con soporte libtheora/libvorbis.
    - En Windows se recomienda usar la build diaria de 32 bits según Godot:
      https://docs.godotengine.org/en/stable/tutorials/animation/playing_videos.html

Uso:
    python tools/build_rpi_videos.py
    # o con resolución personalizada:
    python tools/build_rpi_videos.py --height 480 --fps 24 --quality 4
"""
import argparse
import os
import subprocess
import sys
from pathlib import Path


VIDEO_DIR = Path(__file__).resolve().parent.parent / "assets" / "videos"
RPI_SUFFIX = "_rpi"


def find_ffmpeg() -> str | None:
    for name in ("ffmpeg", "ffmpeg.exe"):
        try:
            result = subprocess.run(
                [name, "-version"],
                capture_output=True,
                text=True,
                check=False,
            )
            if result.returncode == 0:
                return name
        except FileNotFoundError:
            continue
    return None


def has_rpi_version(source: Path) -> bool:
    rpi_name = source.stem + RPI_SUFFIX + source.suffix
    return (source.parent / rpi_name).exists()


def build_rpi_version(source: Path, height: int, fps: int, quality: int, gop: int) -> bool:
    rpi_name = source.stem + RPI_SUFFIX + source.suffix
    dest = source.parent / rpi_name

    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        str(source),
        "-vf",
        f"scale=-2:{height},fps={fps}",
        "-c:v",
        "libtheora",
        "-q:v",
        str(quality),
        "-g:v",
        str(gop),
        "-c:a",
        "libvorbis",
        "-q:a",
        "3",
        str(dest),
    ]

    print(f"\nGenerando: {dest.name}")
    print(" ".join(cmd))
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"ERROR al generar {dest.name}:")
        print(result.stderr)
        return False

    src_mb = source.stat().st_size / (1024 * 1024)
    dst_mb = dest.stat().st_size / (1024 * 1024)
    print(f"  {source.name}: {src_mb:.2f} MB -> {dest.name}: {dst_mb:.2f} MB")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Genera videos optimizados para Raspberry Pi / ARM."
    )
    parser.add_argument(
        "--height",
        type=int,
        default=720,
        help="Altura máxima de los videos RPI (por defecto 720).",
    )
    parser.add_argument(
        "--fps",
        type=int,
        default=24,
        help="FPS objetivo de los videos RPI (por defecto 24).",
    )
    parser.add_argument(
        "--quality",
        type=int,
        default=5,
        help="Calidad Theora 1-10 (por defecto 5).",
    )
    parser.add_argument(
        "--gop",
        type=int,
        default=64,
        help="Intervalo máximo entre keyframes (por defecto 64).",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Sobreescribe videos *_rpi.ogv existentes.",
    )
    args = parser.parse_args()

    ffmpeg = find_ffmpeg()
    if ffmpeg is None:
        print(
            "ERROR: no se encontró ffmpeg. Instálalo y asegúrate de que esté en el PATH.\n"
            "En Windows se recomienda la build diaria de 32 bits de ffmpeg.org\n"
            "porque las builds de 64 bits tienen problemas conocidos con Theora."
        )
        return 1

    if not VIDEO_DIR.exists():
        print(f"ERROR: no existe la carpeta de videos {VIDEO_DIR}")
        return 1

    sources = sorted(p for p in VIDEO_DIR.iterdir() if p.suffix.lower() == ".ogv")
    if not sources:
        print(f"No se encontraron videos .ogv en {VIDEO_DIR}")
        return 0

    print(f"FFmpeg encontrado: {ffmpeg}")
    print(f"Modo RPI: {args.height}p @ {args.fps} fps, calidad {args.quality}, GOP {args.gop}")

    success = 0
    skipped = 0
    for src in sources:
        if RPI_SUFFIX in src.stem:
            continue
        if not args.force and has_rpi_version(src):
            print(f"Saltando {src.name} (ya existe versión RPI)")
            skipped += 1
            continue
        if build_rpi_version(src, args.height, args.fps, args.quality, args.gop):
            success += 1
        else:
            return 1

    print(f"\nListo. {success} video(s) generado(s), {skipped} omitido(s).")
    print(
        "Recuerda exportar el proyecto de nuevo para incluir los nuevos *_rpi.ogv en el PCK."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
