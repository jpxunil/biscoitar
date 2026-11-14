"""Artes dos personagens: tira o fundo branco e gera <key>_art.webp (corpo inteiro, transparente)
e <key>_face.png (retrato 5:7 sobre a cor do herói). A associação é pelo NOME do arquivo."""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

# Uso: python tools/portraits.py <pasta com os PNGs originais> [pasta de saida]
# Depois rode o Godot com --import pra ele enxergar os arquivos novos.
import os
SRC = sys.argv[1].rstrip("/\\") + "/"
OUT = (sys.argv[2].rstrip("/\\") + "/") if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "portraits") + "/"

# arquivo -> (chave do herói, centro do rosto x, y, largura do recorte) em pixels do arquivo original
MAP = {
    "Paladin.png": ("tank", 494, 700, 255, (77, 128, 255)),
    "SOULFLAME.png": ("healer", 478, 450, 380, (60, 190, 150)),
    "ASSASSINA.png": ("assassina", 290, 285, 300, (150, 80, 220)),
    "MAGE.png": ("maga", 548, 484, 330, (255, 170, 70)),
    "MALPRACTICE.png": ("nurse", 236, 296, 175, (92, 102, 242)),
    "SOULBURNER.png": ("burner", 268, 222, 250, (240, 130, 70)),
    "RINGSTAR.png": ("ringstar", 420, 590, 320, (255, 115, 190)),
    "APOTHECARY.png": ("apothecary", 432, 590, 280, (70, 160, 130)),
    "SLEEPWALKER.png": ("sleepwalker", 612, 646, 300, (120, 130, 230)),
}


# Vãos de fundo que ficam FECHADOS dentro da figura (entre o braço e o corpo, entre as pernas, dentro da
# fumaça): o preenchimento a partir das bordas não chega neles, então cada um ganha um ponto-semente aqui,
# em pixels do arquivo original. O branco que é da personagem (luvas, roupa, olhos) não entra na lista.
HOLES = {
    "APOTHECARY.png": [(391, 384)],
    "MALPRACTICE.png": [(179, 326), (178, 375), (202, 439)],
    "SOULFLAME.png": [(547, 661)],
    "ASSASSINA.png": [(340, 471), (328, 456), (271, 752), (271, 763)],
    "MAGE.png": [(433, 368), (460, 490)],
    "SOULBURNER.png": [(229, 356)],
}


def cut(path):
    im = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    low = im.min(axis=2)
    white = low >= 236
    lab, _ = ndimage.label(white)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    edge = edge[edge != 0]
    extra = [lab[y, x] for (x, y) in HOLES.get(os.path.basename(path), []) if lab[y, x] != 0]
    bg = np.isin(lab, list(edge) + extra)
    alpha = np.where(bg, 0.0, 1.0).astype(np.float32)
    # borda: pixels claros colados no fundo viram meio transparentes (o serrilhado some sem halo branco)
    near = ndimage.binary_dilation(bg, iterations=2) & ~bg
    soft = np.clip((255.0 - low) / 60.0, 0.0, 1.0)
    alpha = np.where(near, np.minimum(alpha, np.maximum(soft, 0.15)), alpha)
    a3 = np.maximum(alpha, 0.05)[..., None]
    col = np.where(near[..., None], np.clip((im - 255.0 * (1.0 - a3)) / a3, 0, 255), im)
    out = np.dstack([col, alpha * 255.0]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


for name, (key, fx, fy, fw, bgc) in MAP.items():
    rgba = cut(SRC + name)
    box = rgba.split()[3].point(lambda v: 255 if v > 24 else 0).getbbox()
    art = rgba.crop((max(box[0] - 6, 0), max(box[1] - 6, 0), min(box[2] + 6, rgba.width), min(box[3] + 6, rgba.height)))
    if art.height > 1200:
        art = art.resize((round(art.width * 1200 / art.height), 1200), Image.LANCZOS)
    art.save(OUT + key + "_art.webp", quality=92, method=6)
    # retrato: recorte 5:7 em volta do rosto, sobre a cor do herói com uma faixa diagonal mais escura
    fh = fw * 7 / 5
    x0, y0 = round(fx - fw / 2), round(fy - fh * 0.5)
    crop = rgba.crop((x0, y0, x0 + round(fw), y0 + round(fh))).resize((240, 336), Image.LANCZOS)
    back = Image.new("RGBA", (240, 336), bgc + (255,))
    yy, xx = np.mgrid[0:336, 0:240]
    band = ((xx + yy) > 330).astype(np.uint8) * 46
    dark = Image.fromarray(np.dstack([np.zeros((336, 240, 3), np.uint8), band]), "RGBA")
    back = Image.alpha_composite(back, dark)
    back = Image.alpha_composite(back, crop)
    back.convert("RGB").save(OUT + key + "_face.png")
    print(key, "art", art.size, "de", name)
