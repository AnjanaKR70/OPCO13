from PIL import Image, ImageChops
import os
import shutil

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
        # average pixel values or check if any pixel is < 250
        is_blank = all(gray.getpixel((x, y)) > 245 for x in range(width))
        rows.append(is_blank)
    
    start_y = None
    end_y = None
    for y in range(height):
        if not rows[y]:
            if start_y is None:
                start_y = y
        else:
            if start_y is not None and (y - start_y > 10):
                end_y = y
                break
    
    if start_y is not None and end_y is not None:
        return im.crop((0, start_y, width, end_y))
    return im

im = Image.open('C:/scamundo/assets/images/logo.png')
im = trim(im)
im = strip_logos(im)
im = trim(im)
im.save('C:/scamundo/assets/images/logo.png')
print("Saved cleanly to logo.png!")

# Copy to web build folder as well
dst = 'C:/scamundo/build/web/assets/assets/images/logo.png'
if os.path.exists('C:/scamundo/build/web/assets/assets/images'):
    shutil.copy('C:/scamundo/assets/images/logo.png', dst)
    print("Copied to build/web")
