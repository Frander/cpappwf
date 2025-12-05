"""
Script para generar el ícono de la aplicación ClickPalm
Ícono: Árbol de palma con racimos en círculo verde
"""

from PIL import Image, ImageDraw
import os

def create_palm_tree_icon(size=1024, output_path="app_launcher_icon.png"):
    """
    Crea un ícono de árbol de palma con racimos
    """
    # Crear imagen con fondo transparente
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    center_x = size // 2
    center_y = size // 2

    # Colores
    bg_color = (0, 70, 41, 255)  # Verde oscuro #004629
    tree_color = (0, 168, 107, 255)  # Verde brillante #00a86b
    shadow_color = (0, 50, 30, 180)  # Sombra

    # Margen para el círculo
    margin = size * 0.05
    circle_radius = (size - margin * 2) // 2

    # Dibujar círculo de fondo con degradado simulado
    for i in range(10):
        alpha = 255 - (i * 15)
        current_radius = circle_radius - (i * 2)
        color_intensity = int(41 + (i * 3))
        draw.ellipse(
            [center_x - current_radius, center_y - current_radius,
             center_x + current_radius, center_y + current_radius],
            fill=(0, color_intensity, int(color_intensity * 0.6), alpha)
        )

    # Dibujar círculo principal
    draw.ellipse(
        [margin, margin, size - margin, size - margin],
        fill=bg_color
    )

    # Escala para el árbol
    tree_scale = size * 0.6
    tree_center_x = center_x
    tree_center_y = center_y + size * 0.05  # Mover ligeramente hacia abajo

    # Dibujar sombra del tronco
    trunk_width = tree_scale * 0.08
    trunk_height = tree_scale * 0.35
    shadow_offset = 3
    draw.rectangle(
        [tree_center_x - trunk_width/2 + shadow_offset,
         tree_center_y,
         tree_center_x + trunk_width/2 + shadow_offset,
         tree_center_y + trunk_height],
        fill=shadow_color
    )

    # Dibujar tronco
    draw.rectangle(
        [tree_center_x - trunk_width/2,
         tree_center_y,
         tree_center_x + trunk_width/2,
         tree_center_y + trunk_height],
        fill=tree_color
    )

    # Dibujar hojas (forma de palma) usando polígonos
    leaf_top = tree_center_y - tree_scale * 0.25

    # Hoja central superior
    draw.polygon([
        (tree_center_x, leaf_top - tree_scale * 0.25),
        (tree_center_x - tree_scale * 0.05, leaf_top),
        (tree_center_x + tree_scale * 0.05, leaf_top)
    ], fill=tree_color)

    # Hojas laterales superiores (izquierda y derecha)
    # Izquierda
    draw.polygon([
        (tree_center_x, leaf_top),
        (tree_center_x - tree_scale * 0.25, leaf_top - tree_scale * 0.15),
        (tree_center_x - tree_scale * 0.28, leaf_top - tree_scale * 0.12),
        (tree_center_x - tree_scale * 0.1, leaf_top + tree_scale * 0.05)
    ], fill=tree_color)

    # Derecha
    draw.polygon([
        (tree_center_x, leaf_top),
        (tree_center_x + tree_scale * 0.25, leaf_top - tree_scale * 0.15),
        (tree_center_x + tree_scale * 0.28, leaf_top - tree_scale * 0.12),
        (tree_center_x + tree_scale * 0.1, leaf_top + tree_scale * 0.05)
    ], fill=tree_color)

    # Hojas laterales medias
    leaf_mid = tree_center_y - tree_scale * 0.1

    # Izquierda media
    draw.polygon([
        (tree_center_x, leaf_mid),
        (tree_center_x - tree_scale * 0.3, leaf_mid - tree_scale * 0.05),
        (tree_center_x - tree_scale * 0.32, leaf_mid),
        (tree_center_x - tree_scale * 0.05, leaf_mid + tree_scale * 0.08)
    ], fill=tree_color)

    # Derecha media
    draw.polygon([
        (tree_center_x, leaf_mid),
        (tree_center_x + tree_scale * 0.3, leaf_mid - tree_scale * 0.05),
        (tree_center_x + tree_scale * 0.32, leaf_mid),
        (tree_center_x + tree_scale * 0.05, leaf_mid + tree_scale * 0.08)
    ], fill=tree_color)

    # Hojas laterales inferiores (más cortas)
    leaf_bottom = tree_center_y

    # Izquierda inferior
    draw.polygon([
        (tree_center_x, leaf_bottom),
        (tree_center_x - tree_scale * 0.22, leaf_bottom + tree_scale * 0.02),
        (tree_center_x - tree_scale * 0.23, leaf_bottom + tree_scale * 0.05),
        (tree_center_x - tree_scale * 0.02, leaf_bottom + tree_scale * 0.1)
    ], fill=tree_color)

    # Derecha inferior
    draw.polygon([
        (tree_center_x, leaf_bottom),
        (tree_center_x + tree_scale * 0.22, leaf_bottom + tree_scale * 0.02),
        (tree_center_x + tree_scale * 0.23, leaf_bottom + tree_scale * 0.05),
        (tree_center_x + tree_scale * 0.02, leaf_bottom + tree_scale * 0.1)
    ], fill=tree_color)

    # Dibujar racimos (grupos de círculos pequeños)
    racimo_radius = tree_scale * 0.018

    # Racimo central
    racimo_positions_center = [
        (tree_center_x, leaf_top + tree_scale * 0.05),
        (tree_center_x - racimo_radius * 2, leaf_top + tree_scale * 0.07),
        (tree_center_x + racimo_radius * 2, leaf_top + tree_scale * 0.07),
        (tree_center_x - racimo_radius, leaf_top + tree_scale * 0.09),
        (tree_center_x + racimo_radius, leaf_top + tree_scale * 0.09),
        (tree_center_x, leaf_top + tree_scale * 0.11),
    ]

    for pos in racimo_positions_center:
        draw.ellipse(
            [pos[0] - racimo_radius, pos[1] - racimo_radius,
             pos[0] + racimo_radius, pos[1] + racimo_radius],
            fill=tree_color
        )

    # Racimo izquierdo
    racimo_left_x = tree_center_x - tree_scale * 0.15
    racimo_left_y = leaf_mid + tree_scale * 0.05
    racimo_positions_left = [
        (racimo_left_x, racimo_left_y),
        (racimo_left_x - racimo_radius * 1.5, racimo_left_y + racimo_radius * 2),
        (racimo_left_x + racimo_radius * 1.5, racimo_left_y + racimo_radius * 2),
        (racimo_left_x, racimo_left_y + racimo_radius * 4),
    ]

    for pos in racimo_positions_left:
        draw.ellipse(
            [pos[0] - racimo_radius, pos[1] - racimo_radius,
             pos[0] + racimo_radius, pos[1] + racimo_radius],
            fill=tree_color
        )

    # Racimo derecho
    racimo_right_x = tree_center_x + tree_scale * 0.15
    racimo_right_y = leaf_mid + tree_scale * 0.05
    racimo_positions_right = [
        (racimo_right_x, racimo_right_y),
        (racimo_right_x - racimo_radius * 1.5, racimo_right_y + racimo_radius * 2),
        (racimo_right_x + racimo_radius * 1.5, racimo_right_y + racimo_radius * 2),
        (racimo_right_x, racimo_right_y + racimo_radius * 4),
    ]

    for pos in racimo_positions_right:
        draw.ellipse(
            [pos[0] - racimo_radius, pos[1] - racimo_radius,
             pos[0] + racimo_radius, pos[1] + racimo_radius],
            fill=tree_color
        )

    # Guardar imagen
    img.save(output_path, 'PNG')
    print(f"[OK] Icono creado: {output_path}")
    return output_path


def create_adaptive_icons():
    """
    Crea los íconos para Android adaptive icons
    """
    # Foreground (árbol sin círculo de fondo)
    size = 1024
    img_fg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw_fg = ImageDraw.Draw(img_fg)

    center_x = size // 2
    center_y = size // 2
    tree_color = (0, 168, 107, 255)

    # El adaptive icon necesita 108dp, así que escalamos apropiadamente
    tree_scale = size * 0.45  # Más pequeño para el adaptive
    tree_center_x = center_x
    tree_center_y = center_y

    # Tronco
    trunk_width = tree_scale * 0.08
    trunk_height = tree_scale * 0.35
    draw_fg.rectangle(
        [tree_center_x - trunk_width/2, tree_center_y,
         tree_center_x + trunk_width/2, tree_center_y + trunk_height],
        fill=tree_color
    )

    # Hojas (simplificado)
    leaf_top = tree_center_y - tree_scale * 0.25

    # Hoja central
    draw_fg.polygon([
        (tree_center_x, leaf_top - tree_scale * 0.25),
        (tree_center_x - tree_scale * 0.08, leaf_top),
        (tree_center_x + tree_scale * 0.08, leaf_top)
    ], fill=tree_color)

    # Hojas laterales
    for side in [-1, 1]:
        draw_fg.polygon([
            (tree_center_x, leaf_top),
            (tree_center_x + side * tree_scale * 0.28, leaf_top - tree_scale * 0.12),
            (tree_center_x + side * tree_scale * 0.25, leaf_top - tree_scale * 0.08),
            (tree_center_x + side * tree_scale * 0.08, leaf_top + tree_scale * 0.05)
        ], fill=tree_color)

    # Racimos
    racimo_radius = tree_scale * 0.02
    racimos = [
        (tree_center_x, leaf_top + tree_scale * 0.05),
        (tree_center_x - tree_scale * 0.15, leaf_top + tree_scale * 0.1),
        (tree_center_x + tree_scale * 0.15, leaf_top + tree_scale * 0.1),
    ]

    for pos in racimos:
        draw_fg.ellipse(
            [pos[0] - racimo_radius*2, pos[1] - racimo_radius*2,
             pos[0] + racimo_radius*2, pos[1] + racimo_radius*2],
            fill=tree_color
        )

    img_fg.save('assets/images/adaptive_foreground_icon.png', 'PNG')
    print("[OK] Adaptive foreground creado: assets/images/adaptive_foreground_icon.png")


if __name__ == "__main__":
    # Crear directorio si no existe
    os.makedirs("assets/images", exist_ok=True)

    print("Generando iconos de ClickPalm...")

    # Crear ícono principal
    create_palm_tree_icon(1024, "assets/images/app_launcher_icon.png")

    # Crear adaptive icon
    create_adaptive_icons()

    print("\n[OK] Todos los iconos generados exitosamente!")
    print("\nPasos siguientes:")
    print("1. Ejecuta: flutter pub run flutter_launcher_icons")
    print("2. Los iconos se aplicaran automaticamente a tu app")
