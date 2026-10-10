import sys
import subprocess
try:
    from PIL import Image, ImageChops
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow"])
    from PIL import Image, ImageChops

def trim(im):
    bg = Image.new(im.mode, im.size, im.getpixel((0,0)))
    diff = ImageChops.difference(im, bg)
    diff = ImageChops.add(diff, diff, 2.0, -100)
    bbox = diff.getbbox()
    if bbox:
        return im.crop(bbox)
    return im

def strip_logos(im):
    gray = im.convert("L")
    width, height = gray.size
    rows = []
    for y in range(height):
        is_blank = all(gray.getpixel((x, y)) > 245 for x in range(width))
        rows.append(is_blank)
    start_y = None
    end_y = None
    for y in range(height):
        if not rows[y]:
            if start_y is None:
                start_y = y
        else:
            if start_y is not None and (y - start_y > 15):
                end_y = y
                break
    if start_y is not None and end_y is not None:
        return im.crop((0, start_y, width, end_y))
    return im

im = Image.open('C:/scamundo/assets/images/logo.png')
im = trim(im)
im = strip_logos(im)
im = trim(im)
im.save('C:/scamundo/assets/images/logo_final.png')
print('Successfully processed image with Python Pillow!')
