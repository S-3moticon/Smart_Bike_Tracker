import subprocess
import os
from PIL import Image, ImageDraw

def create_app_icon():
    """Create app icon PNG files from design"""
    
    # Create a 512x512 app icon
    size = 512
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Background circle (primary color)
    padding = 36
    draw.ellipse([padding, padding, size-padding, size-padding], fill='#2C5F7C')
    
    # Create bike shape (simplified for visibility at small sizes)
    center_x = size // 2
    center_y = size // 2
    
    # White bike silhouette
    white = '#FFFFFF'
    
    # Rear wheel
    wheel_radius = 50
    wheel_thickness = 10
    rear_x = center_x - 80
    rear_y = center_y + 40
    draw.ellipse([rear_x - wheel_radius, rear_y - wheel_radius, 
                  rear_x + wheel_radius, rear_y + wheel_radius], 
                 outline=white, width=wheel_thickness)
    
    # Front wheel
    front_x = center_x + 80
    front_y = center_y + 40
    draw.ellipse([front_x - wheel_radius, front_y - wheel_radius, 
                  front_x + wheel_radius, front_y + wheel_radius], 
                 outline=white, width=wheel_thickness)
    
    # Frame triangle
    frame_points = [
        (center_x - 40, center_y - 20),  # rear bottom
        (center_x + 40, center_y - 20),  # front bottom
        (center_x, center_y - 80),       # top (seat)
    ]
    draw.polygon(frame_points, outline=white, width=12)
    
    # Seat
    seat_width = 50
    seat_height = 16
    draw.ellipse([center_x - seat_width//2, center_y - 115 - seat_height//2,
                  center_x + seat_width//2, center_y - 115 + seat_height//2],
                 fill=white)
    
    # Handlebars
    draw.line([center_x + 40, center_y - 20, center_x + 50, center_y - 45], 
              fill=white, width=10)
    draw.line([center_x + 35, center_y - 45, center_x + 65, center_y - 45], 
              fill=white, width=10)
    
    # GPS waves (light blue)
    gps_color = '#82CFFF'
    draw.arc([center_x - 30, center_y - 160, center_x + 30, center_y - 140], 
             200, 340, fill=gps_color, width=6)
    draw.arc([center_x - 40, center_y - 175, center_x + 40, center_y - 155], 
             200, 340, fill=gps_color, width=5)
    draw.arc([center_x - 50, center_y - 190, center_x + 50, center_y - 170], 
             200, 340, fill=gps_color, width=4)
    
    # Location pin (accent)
    pin_x = center_x + 100
    pin_y = center_y - 100
    pin_size = 30
    # Draw pin shape
    draw.ellipse([pin_x - pin_size//2, pin_y - pin_size//2,
                  pin_x + pin_size//2, pin_y + pin_size//2],
                 fill='#82CFFF')
    # Pin point
    pin_points = [
        (pin_x - pin_size//2, pin_y),
        (pin_x + pin_size//2, pin_y),
        (pin_x, pin_y + pin_size)
    ]
    draw.polygon(pin_points, fill='#82CFFF')
    # Inner circle
    draw.ellipse([pin_x - pin_size//4, pin_y - pin_size//4,
                  pin_x + pin_size//4, pin_y + pin_size//4],
                 fill='#2C5F7C')
    
    # Save main icon
    img.save('assets/icon/app_icon.png', 'PNG')
    print("Created app_icon.png")
    
    # Create foreground icon for adaptive icon (just the bike without background)
    fg_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    fg_draw = ImageDraw.Draw(fg_img)
    
    # Same bike drawing but smaller to fit adaptive icon safe zone
    scale = 0.7
    
    # Rear wheel
    wheel_radius = int(50 * scale)
    rear_x = center_x - int(80 * scale)
    rear_y = center_y + int(40 * scale)
    fg_draw.ellipse([rear_x - wheel_radius, rear_y - wheel_radius, 
                     rear_x + wheel_radius, rear_y + wheel_radius], 
                    outline=white, width=int(wheel_thickness * scale))
    
    # Front wheel
    front_x = center_x + int(80 * scale)
    front_y = center_y + int(40 * scale)
    fg_draw.ellipse([front_x - wheel_radius, front_y - wheel_radius, 
                     front_x + wheel_radius, front_y + wheel_radius], 
                    outline=white, width=int(wheel_thickness * scale))
    
    # Frame triangle
    frame_points = [
        (center_x - int(40 * scale), center_y - int(20 * scale)),
        (center_x + int(40 * scale), center_y - int(20 * scale)),
        (center_x, center_y - int(80 * scale)),
    ]
    fg_draw.polygon(frame_points, outline=white, width=int(12 * scale))
    
    # Seat
    seat_width = int(50 * scale)
    seat_height = int(16 * scale)
    fg_draw.ellipse([center_x - seat_width//2, center_y - int(115 * scale) - seat_height//2,
                     center_x + seat_width//2, center_y - int(115 * scale) + seat_height//2],
                    fill=white)
    
    # Handlebars
    fg_draw.line([center_x + int(40 * scale), center_y - int(20 * scale), 
                  center_x + int(50 * scale), center_y - int(45 * scale)], 
                 fill=white, width=int(10 * scale))
    fg_draw.line([center_x + int(35 * scale), center_y - int(45 * scale), 
                  center_x + int(65 * scale), center_y - int(45 * scale)], 
                 fill=white, width=int(10 * scale))
    
    # GPS waves
    fg_draw.arc([center_x - int(30 * scale), center_y - int(160 * scale), 
                 center_x + int(30 * scale), center_y - int(140 * scale)], 
                200, 340, fill='#82CFFF', width=int(6 * scale))
    
    # Save foreground icon
    fg_img.save('assets/icon/app_icon_foreground.png', 'PNG')
    print("Created app_icon_foreground.png")
    
    print("\nApp icons created successfully!")
    print("Run 'flutter pub get' and then 'flutter pub run flutter_launcher_icons' to generate all icon sizes")

if __name__ == "__main__":
    # Check if PIL is installed
    try:
        from PIL import Image, ImageDraw
        create_app_icon()
    except ImportError:
        print("Installing Pillow library...")
        subprocess.run(["pip", "install", "Pillow"])
        from PIL import Image, ImageDraw
        create_app_icon()