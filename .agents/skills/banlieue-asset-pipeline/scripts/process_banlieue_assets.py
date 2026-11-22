import argparse
import json
import os
import re
import sys
from collections import deque
import numpy as np
from PIL import Image, ImageDraw, ImageFilter


MODULAR_W = 256
MODULAR_H = 526
MODULAR_CX = 128
CANON_CHIN_Y = 101

EXISTING_PAWN_SPECS: dict[str, dict] = {
    "leader_pawn.png": {
        "head": "leader", "top": "bleu_atelier", "bottom": "jean_atelier_boots",
        "chin_y": 103, "collar_y": 124, "waist_y": 265,
    },
    "player_02_pawn.png": {
        "head": "player_02", "top": "parka_dalle", "bottom": "jean_revers_baskets",
        "chin_y": 99, "collar_y": 126, "waist_y": 262, "flank_coat_y": 304, "side_hair_max_y": 108,
    },
    "player_03_pawn.png": {
        "head": "player_03", "top": "blouson_jean", "bottom": "pantalon_velours_ville",
        "chin_y": 95, "collar_y": 118, "waist_y": 262, "side_hair_max_y": 106,
    },
    "player_04_pawn.png": {
        "head": "player_04", "top": "bomber_bordeaux", "bottom": "pantalon_toile_baskets",
        "chin_y": 96, "collar_y": 116, "waist_y": 262,
    },
    "player_05_pawn.png": {
        "head": "player_05", "top": "velours_ocre", "bottom": "jean_brut_bottines",
        "chin_y": 100, "collar_y": 128, "waist_y": 266, "side_hair_max_y": 112, "strip_light_collar": True,
    },
    "player_06_pawn.png": {
        "head": "player_06", "top": "coupe_vent_lycee", "bottom": "jean_delave_baskets",
        "chin_y": 100, "collar_y": 118, "waist_y": 262, "waist_bot_y": 265,
    },
    "karim_pawn.png": {
        "head": "karim", "top": "veste_survet", "bottom": "bas_survet_baskets",
        "chin_y": 102, "collar_y": 124, "waist_y": 266, "waist_bot_y": 270,
    },
    "nadia_pawn.png": {
        "head": "nadia", "top": "duffle_coat", "bottom": "jean_noir_rangers",
        "chin_y": 101, "collar_y": 110, "waist_y": 262, "waist_bot_y": 265, "side_hair_max_y": 112, "strip_orange_phones": True,
    },
    "ludo_pawn.png": {
        "head": "ludo", "top": "blouson_college", "bottom": "jean_baskets_toile",
        "chin_y": 111, "collar_y": 130, "waist_y": 274, "waist_bot_y": 276, "dy_top": -6, "hands_in_pockets": True,
    },
    "franck_pawn.png": {
        "head": "franck", "top": "veste_citroen", "bottom": "pantalon_chantier",
        "chin_y": 101, "collar_y": 102, "waist_y": 271, "waist_bot_y": 275,
    },
    "manu_pawn.png": {
        "head": "manu", "top": "perfecto_manu", "bottom": "jean_revers_santiags",
        "chin_y": 103, "collar_y": 123, "waist_y": 265,
    },
    "zoe_pawn.png": {
        "head": "zoe", "top": "cuir_kepon", "bottom": "pantalon_tartan_docs",
        "chin_y": 103, "collar_y": 124, "waist_y": 258, "dy_top": -2, "hip_cx": 101, "hands_in_pockets": True,
    },
}


def convert_to_png(src_path: str, dst_path: str, mode_label: str = "ASSET") -> None:
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    img = Image.open(src_path).convert("RGBA")
    img.save(dst_path, "PNG")
    print(f"{mode_label} SAVED: {dst_path} ({img.size[0]}x{img.size[1]})")


def _flood_from_mask(seed_mask: np.ndarray, eligible: np.ndarray) -> np.ndarray:
    h, w = eligible.shape
    visited = seed_mask.copy()
    ys, xs = np.where(seed_mask)
    q = deque(zip(ys.tolist(), xs.tolist()))
    while q:
        cy, cx = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and eligible[ny, nx]:
                visited[ny, nx] = True
                q.append((ny, nx))
    return visited


def cutout_clean_pawn(src_path: str, dst_path: str, strip_standee: bool = False, char_h: int = 500) -> None:
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    img = Image.open(src_path).convert("RGBA")
    arr = np.array(img, dtype=np.int32)
    h, w, _ = arr.shape

    rgb = arr[:, :, :3]
    r = rgb[:, :, 0]
    g = rgb[:, :, 1]
    b = rgb[:, :, 2]
    luma = 0.299 * r + 0.587 * g + 0.114 * b
    chroma = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)

    # 1. Estimer le fond chroma-magenta (#FF00FF) aux 4 coins et flood-fill depuis les bords
    corners = np.concatenate([
        arr[:8, :8, :3].reshape(-1, 3),
        arr[:8, -8:, :3].reshape(-1, 3),
        arr[-8:, :8, :3].reshape(-1, 3),
        arr[-8:, -8:, :3].reshape(-1, 3),
    ], axis=0)
    bg_rgb = np.median(corners, axis=0)
    dist = np.sqrt(np.sum((rgb - bg_rgb) ** 2, axis=2))
    is_magenta = (r - g > 24) & (b - g > 24) & (np.minimum(r, b) > g + 18)
    is_strong_magenta = (r - g > 48) & (b - g > 48) & (np.minimum(r, b) > g + 40)
    elig_bg = (dist < 130.0) & (is_magenta | (dist < 65.0))

    seed_border = np.zeros((h, w), dtype=bool)
    seed_border[0, :] = elig_bg[0, :]
    seed_border[-1, :] = elig_bg[-1, :]
    seed_border[:, 0] = elig_bg[:, 0]
    seed_border[:, -1] = elig_bg[:, -1]
    seed_all = seed_border | (is_strong_magenta & elig_bg)
    bg_mask = _flood_from_mask(seed_all, elig_bg)

    fg_ys, _ = np.where(~bg_mask)
    if len(fg_ys) == 0:
        raise RuntimeError(f"Empty foreground in {src_path}")
    fg_ymin, fg_ymax = int(fg_ys.min()), int(fg_ys.max())
    span_h = max(1, fg_ymax - fg_ymin)

    base_transparent = bg_mask

    # Optionnel : retrait socle gris + papier creme si source en mode standee
    if strip_standee:
        band_top = max(0, fg_ymax - int(0.070 * span_h))
        in_band = np.zeros((h, w), dtype=bool)
        in_band[band_top:, :] = True

        bottom_core = np.zeros((h, w), dtype=bool)
        bottom_core[max(0, fg_ymax - int(0.042 * span_h)):, :] = True

        is_cream_barrier = (r > 182) & (g > 174) & (b > 156) & (chroma < 46) & (luma > 176.0)
        seed_pedestal = (bg_mask & in_band) | (bottom_core & (~bg_mask) & (chroma < 20) & (luma > 48.0) & (luma < 126.0))
        elig_pedestal = in_band & (~bg_mask) & (~is_cream_barrier) & (luma < 168.0) & (chroma < 26) & ((r - b) < 14)
        pedestal_visited = _flood_from_mask(seed_pedestal, elig_pedestal)
        pedestal_mask = pedestal_visited & (~bg_mask)

        ped_border = (
            np.roll(pedestal_mask, shift=(-1, 0), axis=(0, 1))
            | np.roll(pedestal_mask, shift=(1, 0), axis=(0, 1))
            | np.roll(pedestal_mask, shift=(0, -1), axis=(0, 1))
            | np.roll(pedestal_mask, shift=(0, 1), axis=(0, 1))
            | np.roll(pedestal_mask, shift=(-2, 0), axis=(0, 1))
            | np.roll(pedestal_mask, shift=(2, 0), axis=(0, 1))
        ) & (~pedestal_mask) & (~bg_mask) & in_band & (~is_cream_barrier) & ((r - b) < 14)
        pedestal_mask |= ped_border & ((luma < 150.0) | ((r - g > 14) & (b - g > 14)))

        is_cream_paper = (r > 186) & (g > 178) & (b > 160) & (chroma < 46) & (luma > 180.0)
        base_transparent = _flood_from_mask(bg_mask | pedestal_mask, is_cream_paper)

    # 2. Nettoyage 1-2px de frange claire/magenta collée au trait d'encre noir
    adj1 = (
        np.roll(base_transparent, shift=(-1, 0), axis=(0, 1))
        | np.roll(base_transparent, shift=(1, 0), axis=(0, 1))
        | np.roll(base_transparent, shift=(0, -1), axis=(0, 1))
        | np.roll(base_transparent, shift=(0, 1), axis=(0, 1))
    ) & (~base_transparent)
    fringe1 = adj1 & (((luma > 142.0) & (chroma < 42)) | ((r - g > 14) & (b - g > 14)))
    final_transparent = base_transparent | fringe1

    adj2 = (
        np.roll(final_transparent, shift=(-1, 0), axis=(0, 1))
        | np.roll(final_transparent, shift=(1, 0), axis=(0, 1))
        | np.roll(final_transparent, shift=(0, -1), axis=(0, 1))
        | np.roll(final_transparent, shift=(0, 1), axis=(0, 1))
    ) & (~final_transparent)
    final_transparent |= adj2 & (luma > 168.0) & (chroma < 34)

    out = arr.copy().astype(np.uint8)
    out[final_transparent, 3] = 0

    # Despill residual magenta sur les pixels de bord survivants
    edge_survivor = (
        np.roll(final_transparent, shift=(-1, 0), axis=(0, 1))
        | np.roll(final_transparent, shift=(1, 0), axis=(0, 1))
        | np.roll(final_transparent, shift=(0, -1), axis=(0, 1))
        | np.roll(final_transparent, shift=(0, 1), axis=(0, 1))
    ) & (~final_transparent) & (r - g > 12) & (b - g > 12)
    if np.any(edge_survivor):
        avg_g = np.clip(g[edge_survivor], 0, 255)
        out[edge_survivor, 0] = avg_g.astype(np.uint8)
        out[edge_survivor, 2] = avg_g.astype(np.uint8)

    # 3. Garder uniquement la composante connexe principale (zéro speckle)
    opaque = out[:, :, 3] > 20
    mid_y, mid_x = (fg_ymin + fg_ymax) // 2, w // 2
    oys, oxs = np.where(opaque)
    if len(oys) == 0:
        raise RuntimeError(f"Empty sprite after cleanup for {src_path}")
    d2 = (oys - mid_y) ** 2 + (oxs - mid_x) ** 2
    idx_min = int(np.argmin(d2))
    seed_main = np.zeros((h, w), dtype=bool)
    seed_main[oys[idx_min], oxs[idx_min]] = True
    main_comp = _flood_from_mask(seed_main, opaque)
    out[~main_comp, 3] = 0

    # 4. Tight crop + resize a char_h=500 + padding transparent (16px cotes/haut, 10px bas = 526px)
    ys, xs = np.where(out[:, :, 3] > 20)
    ymin, ymax = int(ys.min()), int(ys.max()) + 1
    xmin, xmax = int(xs.min()), int(xs.max()) + 1
    cropped = Image.fromarray(out[ymin:ymax, xmin:xmax], mode="RGBA")
    cw, ch = cropped.size
    new_w = max(1, round(cw * (char_h / float(ch))))
    resized = cropped.resize((new_w, char_h), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (new_w + 32, char_h + 26), (0, 0, 0, 0))
    canvas.paste(resized, (16, 16))
    canvas.save(dst_path, "PNG")
    print(f"CLEAN PAWN SAVED: {dst_path} ({canvas.size[0]}x{canvas.size[1]})")


def _add_2px_outline(im: Image.Image, outline_rgb: tuple[int, int, int]) -> Image.Image:
    alpha = im.getchannel("A")
    dilated = alpha.filter(ImageFilter.MaxFilter(5))
    ring_arr = np.array(dilated, dtype=np.uint8)
    base_arr = np.array(im, dtype=np.uint8)
    res = np.zeros_like(base_arr)
    mask_ring = ring_arr > 90
    res[mask_ring, 0] = outline_rgb[0]
    res[mask_ring, 1] = outline_rgb[1]
    res[mask_ring, 2] = outline_rgb[2]
    res[mask_ring, 3] = 235
    out_im = Image.fromarray(res, mode="RGBA")
    out_im.alpha_composite(im)
    return out_im


def _make_shadow_4h(im: Image.Image, target_h: int) -> tuple[Image.Image, int]:
    pw, ph = im.size
    scale = target_h / float(max(1, ph - 26))
    sw = max(1, round(pw * scale))
    sh = max(1, round(ph * scale))
    small = im.resize((sw, sh), Image.Resampling.LANCZOS)
    shadow_alpha = (np.array(small.getchannel("A"), dtype=np.float32) * 0.42).astype(np.uint8)
    shad_rgba = np.zeros((sh, sw, 4), dtype=np.uint8)
    shad_rgba[:, :, 2] = 10
    shad_rgba[:, :, 3] = shadow_alpha
    shad_im = Image.fromarray(shad_rgba, mode="RGBA")

    proj_h = max(1, round(sh * 0.30))
    skew_x = round(sh * 0.48)
    transformed = shad_im.transform(
        (sw + skew_x, proj_h),
        Image.Transform.AFFINE,
        (1.0, skew_x / float(proj_h), -skew_x, 0.0, sh / float(proj_h), 0.0),
        resample=Image.Resampling.BILINEAR,
    )
    return transformed, round(sw * 0.5)


def make_preview(backdrop_path: str, pawn_paths: list[str], out_path: str, target_h: int = 162) -> None:
    bg = Image.open(backdrop_path).convert("RGBA").resize((870, 650), Image.Resampling.LANCZOS)
    slots = [
        (412, 360, (242, 140, 40)),
        (356, 376, (235, 45, 45)),
        (468, 376, (242, 237, 222)),
    ]
    items = sorted(zip(pawn_paths, slots), key=lambda t: t[1][1])
    for p, (fx, fy, ocol) in items:
        im = Image.open(p).convert("RGBA")
        pw, ph = im.size
        scale = target_h / float(max(1, ph - 26))
        nw, nh = max(1, round(pw * scale)), max(1, round(ph * scale))
        im_r = im.resize((nw, nh), Image.Resampling.LANCZOS)
        shad_im, foot_ox = _make_shadow_4h(im, target_h)
        bg.alpha_composite(shad_im, (int(fx - foot_ox), int(fy - 3)))
        im_out = _add_2px_outline(im_r, ocol)
        foot_y = round((ph - 10) * scale)
        bg.alpha_composite(im_out, (int(fx - nw // 2), int(fy - foot_y)))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    bg.convert("RGB").save(out_path, "PNG")
    print(f"PREVIEW SAVED: {out_path}")


def _shift_to_canonical(src_arr: np.ndarray, dx: int, dy: int) -> np.ndarray:
    """Replace un tableau RGBA source sur le canevas canonique 256x526 après décalage (dx, dy)."""
    canvas = np.zeros((MODULAR_H, MODULAR_W, 4), dtype=np.uint8)
    sh, sw, _ = src_arr.shape
    for sy in range(sh):
        ty = sy + dy
        if 0 <= ty < MODULAR_H:
            x0_s = max(0, -dx)
            x1_s = min(sw, MODULAR_W - dx)
            if x1_s > x0_s:
                canvas[ty, x0_s + dx:x1_s + dx] = src_arr[sy, x0_s:x1_s]
    return canvas


def _measure_landmarks(arr: np.ndarray) -> dict[str, int]:
    """Détecte les repères anatomiques (hip_cx, neck_cx, neck_y, chin_y) d'un pion RGBA."""
    a = arr[:, :, 3] > 30
    r = arr[:, :, 0].astype(np.int32)
    g = arr[:, :, 1].astype(np.int32)
    b = arr[:, :, 2].astype(np.int32)
    luma = 0.299 * r + 0.587 * g + 0.114 * b

    hip_xs = np.where(a[330:356])[1]
    hip_cx = int(round((int(hip_xs.min()) + int(hip_xs.max())) / 2.0)) if len(hip_xs) else arr.shape[1] // 2

    best_ny, best_nw = 92, 999
    for y in range(72, 122):
        xs = np.where(a[y])[0]
        if len(xs) and (int(xs[-1]) - int(xs[0])) < best_nw:
            best_nw = int(xs[-1]) - int(xs[0])
            best_ny = y
    nxs = np.where(a[best_ny])[0]
    neck_cx = int(round((int(nxs[0]) + int(nxs[-1])) / 2.0)) if len(nxs) else hip_cx

    chin_y = 101
    for y in range(max(82, best_ny - 2), min(116, best_ny + 22)):
        sl = slice(max(0, neck_cx - 5), min(arr.shape[1], neck_cx + 6))
        if np.any(a[y, sl]) and float(np.median(luma[y, sl])) < 72.0:
            chin_y = y
            break

    return {"hip_cx": hip_cx, "neck_cx": neck_cx, "neck_y": best_ny, "chin_y": chin_y}


def _skin_mask(arr: np.ndarray) -> np.ndarray:
    """Construit un masque booléen heuristique des pixels de peau (visage, cou et mains)."""
    a = arr[:, :, 3] > 30
    r = arr[:, :, 0].astype(np.int32)
    g = arr[:, :, 1].astype(np.int32)
    b = arr[:, :, 2].astype(np.int32)
    luma = 0.299 * r + 0.587 * g + 0.114 * b
    return a & (r > 95) & (r > g + 5) & (g >= b - 2) & ((r - b) > 12) & (luma > 68)


def _keep_main_component_near(mask: np.ndarray, seed_y: int, seed_x: int) -> np.ndarray:
    """Conserve uniquement la composante connexe la plus proche du point (seed_y, seed_x)."""
    ys, xs = np.where(mask)
    if len(ys) == 0:
        return mask
    d2 = (ys - seed_y) ** 2 + (xs - seed_x) ** 2
    i0 = int(np.argmin(d2))
    seed = np.zeros_like(mask, dtype=bool)
    seed[ys[i0], xs[i0]] = True
    return _flood_from_mask(seed, mask)


def split_pawn_to_modular(
    src_path: str,
    head_dst: str,
    top_dst: str,
    bottom_dst: str,
    cfg: dict | None = None,
) -> None:
    """Découpe un pion 526 px détouré en 3 calques alignés 256x526 RGBA (tête, haut+bras, bas+pieds)."""
    cfg = cfg or {}
    im = Image.open(src_path).convert("RGBA")
    src = np.array(im, dtype=np.uint8)
    # Nettoyer les petits trous magenta enfermés à l'intérieur du sprite (lacets, interstices bras/jambes)
    rm, gm, bm = src[:, :, 0].astype(np.int32), src[:, :, 1].astype(np.int32), src[:, :, 2].astype(np.int32)
    inner_mag = (src[:, :, 3] > 20) & (rm - gm > 28) & (bm - gm > 28) & (np.minimum(rm, bm) > gm + 20)
    if np.any(inner_mag):
        src = src.copy()
        src[inner_mag, 3] = 0

    lm = _measure_landmarks(src)

    hip_cx = int(cfg.get("hip_cx", lm["hip_cx"]))
    neck_cx = int(cfg.get("neck_cx", lm["neck_cx"]))
    chin_y = int(cfg.get("chin_y", lm["chin_y"]))
    collar_y = int(cfg.get("collar_y", 122))
    waist_y = int(cfg.get("waist_y", 265))
    dy_top = int(cfg.get("dy_top", 0))
    waist_bot_y = int(cfg.get("waist_bot_y", waist_y + dy_top))
    flank_coat_y = int(cfg.get("flank_coat_y", waist_y))
    side_hair_max_y = int(cfg.get("side_hair_max_y", 101))
    hands_in_pockets = bool(cfg.get("hands_in_pockets", False))
    overlap_side = str(cfg.get("arm_overlap_side", "right"))

    dx_head = MODULAR_CX - neck_cx
    dy_head = max(-14, min(10, CANON_CHIN_Y - chin_y))
    dx_body = MODULAR_CX - hip_cx

    # --- 1. TÊTE (256x526) ---
    head_arr = _shift_to_canonical(src, dx_head, dy_head)
    shifted_collar_y = max(106, min(136, collar_y + dy_head))
    head_arr[138:, :, 3] = 0
    for x in range(MODULAR_W):
        dist_c = abs(x - MODULAR_CX)
        if dist_c > 38:
            max_y = 98
        elif dist_c > 16:
            max_y = min(side_hair_max_y, 118)
        else:
            max_y = min(135, max(108, shifted_collar_y - 1))
        if max_y + 1 < 138:
            head_arr[max_y + 1:138, x, 3] = 0

    if cfg.get("strip_light_collar", False):
        hluma = 0.299 * head_arr[:, :, 0] + 0.587 * head_arr[:, :, 1] + 0.114 * head_arr[:, :, 2]
        bad_fluff = (np.arange(MODULAR_H)[:, None] >= 100) & (np.abs(np.arange(MODULAR_W)[None, :] - MODULAR_CX) > 14) & (hluma > 118)
        head_arr[bad_fluff, 3] = 0
    if cfg.get("strip_orange_phones", False):
        r_h = head_arr[:, :, 0].astype(np.int32)
        b_h = head_arr[:, :, 2].astype(np.int32)
        bad_org = (np.arange(MODULAR_H)[:, None] >= 95) & (np.abs(np.arange(MODULAR_W)[None, :] - MODULAR_CX) > 14) & (r_h > 105) & ((r_h - b_h) > 28)
        head_arr[bad_org, 3] = 0

    # Étendre proprement la colonne centrale du cou jusqu'à y=136 avec la teinte de peau du menton/cou
    h_skin = _skin_mask(head_arr)
    sample_skin = head_arr[max(84, CANON_CHIN_Y - 12):CANON_CHIN_Y + 4, MODULAR_CX - 14:MODULAR_CX + 15]
    sample_mask = h_skin[max(84, CANON_CHIN_Y - 12):CANON_CHIN_Y + 4, MODULAR_CX - 14:MODULAR_CX + 15]
    if np.any(sample_mask):
        skin_rgb = np.median(sample_skin[sample_mask][:, :3], axis=0).astype(np.uint8)
    else:
        skin_rgb = np.array([212, 168, 134], dtype=np.uint8)
    neck_shadow = np.clip(skin_rgb.astype(np.int32) - np.array([28, 30, 26]), 25, 255).astype(np.uint8)

    for y in range(CANON_CHIN_Y + 2, 137):
        half_w = 14 if y < 114 else (13 if y < 126 else 12)
        t = (y - (CANON_CHIN_Y + 2)) / 34.0
        for x in range(MODULAR_CX - half_w - 1, MODULAR_CX + half_w + 2):
            if head_arr[y, x, 3] > 40:
                continue
            dx_n = abs(x - MODULAR_CX)
            if dx_n >= half_w:
                head_arr[y, x] = [18, 16, 15, 255]
            elif t < 0.25 or x < MODULAR_CX - 2:
                head_arr[y, x] = [neck_shadow[0], neck_shadow[1], neck_shadow[2], 255]
            else:
                head_arr[y, x] = [skin_rgb[0], skin_rgb[1], skin_rgb[2], 255]

    head_ok = _keep_main_component_near(head_arr[:, :, 3] > 20, 62, MODULAR_CX)
    head_arr[~head_ok, 3] = 0

    # --- 2. BAS + PIEDS (256x526) ---
    bot_src = _shift_to_canonical(src, dx_body, 0)
    bot_arr = bot_src.copy()
    wy_bot = max(254, min(288, waist_bot_y))
    bot_arr[:wy_bot, :, 3] = 0

    anchor_L_list, anchor_R_list = [], []
    for ay in range(328, 349):
        axs = np.where(bot_arr[ay, :, 3] > 40)[0]
        if len(axs):
            anchor_L_list.append(int(axs[0]))
            anchor_R_list.append(int(axs[-1]))
    thigh_L_base = int(np.median(anchor_L_list)) if anchor_L_list else (MODULAR_CX - 48)
    thigh_R_base = int(np.median(anchor_R_list)) if anchor_R_list else (MODULAR_CX + 48)

    # Couleur médiane de référence du pantalon/jupe sur le haut de cuisse propre (y=328..338)
    ref_patch = bot_arr[328:338, thigh_L_base + 6:thigh_R_base - 6]
    ref_luma = 0.299 * ref_patch[:, :, 0] + 0.587 * ref_patch[:, :, 1] + 0.114 * ref_patch[:, :, 2]
    ref_valid = (ref_patch[:, :, 3] > 40) & (ref_luma > 35)
    thigh_ref_rgb = np.median(ref_patch[ref_valid][:, :3], axis=0) if np.any(ref_valid) else np.array([58, 72, 86])

    if not hands_in_pockets:
        bot_skin = _skin_mask(bot_arr)
        for y in range(wy_bot, 330):
            prog = (330 - y) / float(max(1, 330 - wy_bot))
            est_L = int(round(thigh_L_base - prog * 2.0))
            est_R = int(round(thigh_R_base + prog * 1.0))

            row_op = bot_arr[y, :, 3] > 40
            cut_L = est_L
            if overlap_side == "right":
                in_t = False
                s_t = 0
                best_gap = None
                for x in range(max(0, thigh_L_base - 35), MODULAR_CX):
                    if not row_op[x] and not in_t:
                        in_t = True
                        s_t = x
                    elif row_op[x] and in_t:
                        in_t = False
                        if x - s_t >= 1 and s_t > 45:
                            best_gap = x
                if best_gap is not None and abs(best_gap - est_L) <= 10:
                    cut_L = best_gap
                cut_R = est_R
            else:
                # Mirroir (ex: concierge) : bras gauche de l'image chevauche le bord gauche, droite séparée
                in_t = False
                s_t = 0
                best_gap_r = None
                for x in range(MODULAR_CX, min(MODULAR_W, thigh_R_base + 35)):
                    if not row_op[x] and not in_t:
                        in_t = True
                        s_t = x
                    elif row_op[x] and in_t:
                        in_t = False
                        if x < thigh_R_base + 30:
                            best_gap_r = s_t - 1
                cut_R = best_gap_r if (best_gap_r is not None and abs(best_gap_r - est_R) <= 10) else est_R

            bot_arr[y, :cut_L, 3] = 0
            bot_arr[y, cut_R + 1:, 3] = 0

            # Nettoyer peau + manchettes/doigts sur le bord chevauché et combler proprement
            if overlap_side == "right":
                scan_x0, scan_x1 = MODULAR_CX + 24, cut_R + 1
                bad_cols = []
                for x in range(scan_x0, scan_x1):
                    if bot_arr[y, x, 3] <= 40:
                        continue
                    pix = bot_arr[y, x, :3].astype(np.float32)
                    cdist = float(np.linalg.norm(pix - thigh_ref_rgb))
                    if bot_skin[y, x] or (x >= cut_R - 14 and cdist > 44.0) or (x >= cut_R - 10 and np.mean(pix) < 35.0):
                        bad_cols.append(x)
                if bad_cols:
                    hx_min = max(MODULAR_CX + 26, min(bad_cols) - 2)
                    for fx in range(hx_min, cut_R - 1):
                        sx = max(MODULAR_CX + 10, hx_min - 3 - ((fx - hx_min) % 5))
                        if bot_arr[y, sx, 3] > 40:
                            bot_arr[y, fx, :3] = bot_arr[y, sx, :3]
                        else:
                            bot_arr[y, fx, :3] = np.clip(thigh_ref_rgb, 0, 255).astype(np.uint8)
                        bot_arr[y, fx, 3] = 255
                    bot_arr[y, cut_R - 1:cut_R + 1] = [18, 16, 15, 255]
            else:
                scan_x0, scan_x1 = cut_L, MODULAR_CX - 24
                bad_cols = []
                for x in range(scan_x0, scan_x1):
                    if bot_arr[y, x, 3] <= 40:
                        continue
                    pix = bot_arr[y, x, :3].astype(np.float32)
                    cdist = float(np.linalg.norm(pix - thigh_ref_rgb))
                    if bot_skin[y, x] or (x <= cut_L + 14 and cdist > 44.0) or (x <= cut_L + 10 and np.mean(pix) < 35.0):
                        bad_cols.append(x)
                if bad_cols:
                    hx_max = min(MODULAR_CX - 26, max(bad_cols) + 2)
                    for fx in range(cut_L + 2, hx_max + 1):
                        sx = min(MODULAR_CX - 10, hx_max + 3 + ((hx_max - fx) % 5))
                        if bot_arr[y, sx, 3] > 40:
                            bot_arr[y, fx, :3] = bot_arr[y, sx, :3]
                        else:
                            bot_arr[y, fx, :3] = np.clip(thigh_ref_rgb, 0, 255).astype(np.uint8)
                        bot_arr[y, fx, 3] = 255
                    bot_arr[y, cut_L:cut_L + 2] = [18, 16, 15, 255]

    # Nettoyer les pans de chemise au centre (ex: Ludo) puis étendre le haut par réflexion verticale texturée (~8-10 px)
    if cfg.get("hands_in_pockets", False):
        for cy in range(wy_bot, min(wy_bot + 16, MODULAR_H)):
            row_r = bot_arr[cy]
            c_xs = np.where(row_r[:, 3] > 40)[0]
            if len(c_xs) < 20:
                continue
            rx0_c, rx1_c = int(c_xs[0]), int(c_xs[-1])
            clean_band = row_r[max(rx0_c + 4, MODULAR_CX - 34):max(rx0_c + 12, MODULAR_CX - 22), :3]
            if len(clean_band) == 0:
                continue
            clean_med = np.median(clean_band, axis=0).astype(np.float32)
            for cx in range(MODULAR_CX - 22, MODULAR_CX + 23):
                if cx <= rx0_c + 2 or cx >= rx1_c - 2:
                    continue
                if row_r[cx, 3] > 40:
                    pix = row_r[cx, :3].astype(np.float32)
                    if float(np.linalg.norm(pix - clean_med)) > 40.0:
                        sx_clean = max(rx0_c + 5, MODULAR_CX - 32 + ((cx - (MODULAR_CX - 22)) % 9))
                        bot_arr[cy, cx] = bot_arr[cy, sx_clean]

    ref_y = min(MODULAR_H - 1, wy_bot + 2)
    ref_xs = np.where(bot_arr[ref_y, :, 3] > 40)[0]
    if len(ref_xs):
        rx0, rx1 = max(thigh_L_base - 2, int(ref_xs[0])), min(thigh_R_base + 2, int(ref_xs[-1]))
        ext_top = max(238 if overlap_side == "left" else 252, wy_bot - 10)
        for ey in range(ext_top, wy_bot):
            src_y = min(MODULAR_H - 1, wy_bot + 1 + (wy_bot - ey))
            bot_arr[ey, rx0:rx1 + 1] = bot_arr[src_y, rx0:rx1 + 1]
            # Garde contour noir latéral propre sur les bords remontés
            if bot_arr[ey, rx0, 3] > 40:
                bot_arr[ey, rx0:rx0 + 2] = [18, 16, 15, 255]
            if bot_arr[ey, rx1, 3] > 40:
                bot_arr[ey, rx1 - 1:rx1 + 1] = [18, 16, 15, 255]

    bot_ok = _keep_main_component_near(bot_arr[:, :, 3] > 20, 400, MODULAR_CX)
    bot_arr[~bot_ok, 3] = 0

    # --- 3. HAUT + BRAS (256x526) ---
    top_arr = _shift_to_canonical(src, dx_body, dy_top)
    top_collar_y = max(98, min(136, collar_y + dy_top))
    top_waist_y = waist_y + dy_top
    top_flank_y = flank_coat_y + dy_top

    top_arr[:88, :, 3] = 0
    t_skin = _skin_mask(top_arr)
    for y in range(88, min(134, top_collar_y)):
        half_face = 26 if y < 101 else 16
        for x in range(max(0, MODULAR_CX - half_face), min(MODULAR_W, MODULAR_CX + half_face + 1)):
            if y < 100 or t_skin[y, x] or abs(x - MODULAR_CX) <= 13:
                top_arr[y, x, 3] = 0

    if hands_in_pockets:
        top_arr[top_waist_y:, :, 3] = 0
    else:
        for y in range(top_waist_y, MODULAR_H):
            if y > 326:
                top_arr[y, :, 3] = 0
                continue
            prog = (326 - y) / float(max(1, 326 - top_waist_y))
            row_op = top_arr[y, :, 3] > 40
            if overlap_side == "right":
                cut_L = int(round(thigh_L_base - prog * 2.0))
                in_t = False
                s_t = 0
                best_gap_l = None
                for x in range(max(0, thigh_L_base - 35), MODULAR_CX):
                    if not row_op[x] and not in_t:
                        in_t = True
                        s_t = x
                    elif row_op[x] and in_t:
                        in_t = False
                        if s_t > 45:
                            best_gap_l = s_t
                if best_gap_l is not None and abs(best_gap_l - cut_L) <= 10:
                    cut_L = best_gap_l

                cut_R = int(round(thigh_R_base - 14.0 + prog * 4.0))
                hand_r = np.where(t_skin[y, MODULAR_CX + 26:])[0]
                if len(hand_r):
                    cut_R = min(cut_R, int(hand_r[0]) + MODULAR_CX + 26 - 2)
            else:
                cut_L = int(round(thigh_L_base + 14.0 - prog * 4.0))
                hand_l = np.where(t_skin[y, :MODULAR_CX - 26])[0]
                if len(hand_l):
                    cut_L = max(cut_L, int(hand_l[-1]) + 2)
                in_t = False
                s_t = 0
                best_gap_r = None
                for x in range(MODULAR_CX, min(MODULAR_W, thigh_R_base + 35)):
                    if not row_op[x] and not in_t:
                        in_t = True
                        s_t = x
                    elif row_op[x] and in_t:
                        in_t = False
                        if x < thigh_R_base + 30:
                            best_gap_r = x
                cut_R = best_gap_r if (best_gap_r is not None and abs(best_gap_r - thigh_R_base) <= 10) else int(round(thigh_R_base + prog * 2.0))

            if y <= top_flank_y and top_flank_y > top_waist_y:
                center_L = max(cut_L, MODULAR_CX - 22)
                center_R = min(cut_R, MODULAR_CX + 22)
                top_arr[y, center_L:center_R + 1, 3] = 0
            else:
                top_arr[y, cut_L:cut_R + 1, 3] = 0

    top_ok = _keep_main_component_near(top_arr[:, :, 3] > 20, 185, MODULAR_CX)
    top_arr[~top_ok, 3] = 0

    for dst, arr_out in ((head_dst, head_arr), (top_dst, top_arr), (bottom_dst, bot_arr)):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        Image.fromarray(arr_out, mode="RGBA").save(dst, "PNG")
    print(f"SPLIT MODULAR: {os.path.basename(src_path)} -> {os.path.basename(head_dst)}, {os.path.basename(top_dst)}, {os.path.basename(bottom_dst)}")


def compose_modular_rgba(head_path: str, top_path: str, bottom_path: str) -> Image.Image:
    """Assemble une preview PIL 256x526 selon l'ordre exact 4 passes utilisé par Godot (bas -> cou -> haut -> tête)."""
    canvas = Image.new("RGBA", (MODULAR_W, MODULAR_H), (0, 0, 0, 0))
    b_im = Image.open(bottom_path).convert("RGBA") if bottom_path and os.path.exists(bottom_path) else None
    t_im = Image.open(top_path).convert("RGBA") if top_path and os.path.exists(top_path) else None
    h_im = Image.open(head_path).convert("RGBA") if head_path and os.path.exists(head_path) else None

    if b_im is not None:
        canvas.alpha_composite(b_im)
    if h_im is not None:
        # Dessin du cou (y=96..143) derrière le col et le t-shirt du haut
        neck_crop = h_im.crop((0, 96, MODULAR_W, 144))
        canvas.alpha_composite(neck_crop, (0, 96))
    if t_im is not None:
        canvas.alpha_composite(t_im)
    if h_im is not None:
        # Dessin du visage/cheveux (y=0..102) et des longueurs latérales devant les épaules
        upper_crop = h_im.crop((0, 0, MODULAR_W, 102))
        canvas.alpha_composite(upper_crop, (0, 0))
        hair_l = h_im.crop((0, 102, 104, 136))
        hair_r = h_im.crop((152, 102, MODULAR_W, 136))
        canvas.alpha_composite(hair_l, (0, 102))
        canvas.alpha_composite(hair_r, (152, 102))
    return canvas


def split_all_existing_pawns(game_root: str) -> None:
    """Découpe en lot les 12 pions complets historiques de game/assets/pawns/ vers assets/modular/."""
    pawns_dir = os.path.join(game_root, "assets", "pawns")
    mod_dir = os.path.join(game_root, "assets", "modular")
    for fname, spec in EXISTING_PAWN_SPECS.items():
        src_p = os.path.join(pawns_dir, fname)
        if not os.path.exists(src_p):
            print(f"SKIP missing pawn: {src_p}")
            continue
        split_pawn_to_modular(
            src_p,
            os.path.join(mod_dir, "heads", f"{spec['head']}.png"),
            os.path.join(mod_dir, "tops", f"{spec['top']}.png"),
            os.path.join(mod_dir, "bottoms", f"{spec['bottom']}.png"),
            cfg=spec,
        )


def make_modular_preview(game_root: str, combos_json: str, out_path: str) -> None:
    """Génère une planche-contact visuelle combinant têtes, hauts et bas avec simulation contour 2 px."""
    mod_dir = os.path.join(game_root, "assets", "modular")
    if combos_json and os.path.exists(combos_json):
        with open(combos_json, "r", encoding="utf-8") as f:
            combos = json.load(f)
    else:
        combos = [
            ("leader", "bleu_atelier", "jean_atelier_boots", "Leader orig"),
            ("karim", "veste_survet", "bas_survet_baskets", "Karim orig"),
            ("nadia", "duffle_coat", "jean_noir_rangers", "Nadia orig"),
            ("franck", "veste_citroen", "pantalon_chantier", "Franck orig"),
            ("manu", "perfecto_manu", "jean_revers_santiags", "Manu orig"),
            ("zoe", "cuir_kepon", "pantalon_tartan_docs", "Zoe orig"),
            ("ludo", "blouson_college", "jean_baskets_toile", "Ludo orig"),
            ("player_02", "parka_dalle", "jean_revers_baskets", "P02 orig"),
            ("player_04", "bomber_bordeaux", "pantalon_toile_baskets", "P04 orig"),
            ("player_05", "velours_ocre", "jean_brut_bottines", "P05 orig"),
            ("leader", "veste_survet", "pantalon_tartan_docs", "Mix L+Sur+Tar"),
            ("player_04", "bleu_atelier", "jean_delave_baskets", "Mix P4+Bleu+J"),
            ("player_05", "bomber_bordeaux", "jean_atelier_boots", "Mix P5+Bom+Bot"),
            ("karim", "parka_dalle", "pantalon_chantier", "Mix K+Parka+Ch"),
            ("zoe", "veste_citroen", "bas_survet_baskets", "Mix Z+Cit+Sur"),
            ("nadia", "blouson_jean", "jean_revers_santiags", "Mix N+Jean+San"),
        ]
    cols = 4
    rows = (len(combos) + cols - 1) // cols
    cell_w, cell_h = 266, 560
    sheet = Image.new("RGB", (cols * cell_w, rows * cell_h), (28, 30, 36))
    draw = ImageDraw.Draw(sheet)
    for idx, entry in enumerate(combos):
        hid, tid, bid, label = entry
        comp = compose_modular_rgba(
            os.path.join(mod_dir, "heads", f"{hid}.png"),
            os.path.join(mod_dir, "tops", f"{tid}.png"),
            os.path.join(mod_dir, "bottoms", f"{bid}.png"),
        )
        outlined = _add_2px_outline(comp, (242, 140, 40) if idx % 2 == 0 else (238, 232, 218))
        cx = (idx % cols) * cell_w + 5
        cy = (idx // cols) * cell_h + 26
        sheet.paste(outlined.convert("RGB"), (cx, cy), outlined.getchannel("A"))
        draw.text((cx + 8, (idx // cols) * cell_h + 6), label, fill=(245, 220, 160))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    sheet.save(out_path, "PNG")
    print(f"MODULAR PREVIEW SAVED: {out_path} ({sheet.size[0]}x{sheet.size[1]})")


def _check_modular_png(fp: str, label: str, errors: list[str]) -> None:
    """Valide qu'un PNG modulaire existe, est en RGBA, mesure 256x526 et conserve ses coins transparents."""
    if not os.path.exists(fp):
        errors.append(f"Missing {label}: {fp}")
        return
    im = Image.open(fp)
    if im.mode != "RGBA":
        errors.append(f"{label} not RGBA: {fp}")
    w, h = im.size
    if w != MODULAR_W or h != MODULAR_H:
        errors.append(f"Expected {MODULAR_W}x{MODULAR_H} for {label} ({fp}), got {w}x{h}")
    alpha = im.getchannel("A")
    if alpha.getpixel((0, 0)) != 0 or alpha.getpixel((w - 1, h - 1)) != 0:
        errors.append(f"Transparent corners missing in {label}: {fp}")


def validate_project(game_root: str) -> int:
    errors: list[str] = []

    def load_j(rel: str):
        with open(os.path.join(game_root, rel), "r", encoding="utf-8") as f:
            return json.load(f)

    chars_j = load_j("data/characters.json")
    idf_j = load_j("data/world/idf.json")
    dlgs_j = load_j("data/dialogues.json")
    encs_j = load_j("data/timeline_encounters.json")
    load_j("data/radio_fm.json")
    equip_path = os.path.join(game_root, "data/equipment.json")
    equip_j = load_j("data/equipment.json") if os.path.exists(equip_path) else {"skills_catalog": [], "equipment": []}

    char_ids = {c["id"] for c in chars_j["characters"]}
    dlg_ids = set(dlgs_j["dialogues"].keys())
    enc_ids = set(encs_j["encounters"].keys())
    valid_skill_ids = {sk.get("id", "") for sk in equip_j.get("skills_catalog", []) if sk.get("id", "")}
    valid_slots = {"look_top", "look_bottom", "tool", "fetish"}
    equip_by_id = {}
    for eq in equip_j.get("equipment", []):
        eid = eq.get("id", "")
        slot = eq.get("slot", "")
        if slot not in valid_slots:
            errors.append(f"Invalid equipment slot '{slot}' on {eid}")
        if eid:
            equip_by_id[eid] = eq
        if slot in ("look_top", "look_bottom"):
            sp = eq.get("sprite", "")
            if not sp or not sp.startswith("res://"):
                errors.append(f"Missing or invalid sprite path on {slot} equipment {eid}: {sp}")
            else:
                _check_modular_png(os.path.join(game_root, sp[6:]), f"equipment.{eid}.sprite", errors)

    valid_equip_ids = set(equip_by_id.keys())
    valid_action_ids = {
        act.get("id", "")
        for eq in equip_j.get("equipment", [])
        for act in eq.get("unlocks_actions", [])
        if isinstance(act, dict) and act.get("id", "")
    }

    valid_statuses = {"playable", "locked", "undescribed"}
    reg_ids = {idf_j.get("id", "idf")}
    dept_ids = set()
    city_ids = set()
    interiors_list = []

    def load_res(res_p: str, owner: str):
        if not res_p.startswith("res://"):
            errors.append(f"Invalid res:// path in {owner}: {res_p}")
            return None
        fp = os.path.join(game_root, res_p[6:])
        if not os.path.exists(fp):
            errors.append(f"Missing referenced JSON {res_p} in {owner}")
            return None
        with open(fp, "r", encoding="utf-8") as f:
            return json.load(f)

    for dc in idf_j.get("children", []):
        if dc.get("status") not in valid_statuses:
            errors.append(f"Invalid status in idf child {dc.get('id')}")
        cf = dc.get("child_file", "")
        if cf:
            dept_j = load_res(cf, f"idf/{dc.get('id')}")
            if dept_j:
                dept_ids.add(dept_j.get("id", ""))
                db_p = dept_j.get("backdrop", "")
                if db_p and (not db_p.startswith("res://") or not os.path.exists(os.path.join(game_root, db_p[6:]))):
                    errors.append(f"Missing map backdrop {db_p} in {dept_j.get('id')}")
                for cc in dept_j.get("children", []):
                    if cc.get("status") not in valid_statuses:
                        errors.append(f"Invalid status in dept child {cc.get('id')}")
                    ccf = cc.get("child_file", "")
                    if ccf:
                        city_j = load_res(ccf, f"{dept_j.get('id')}/{cc.get('id')}")
                        if city_j:
                            city_ids.add(city_j.get("id", ""))
                            cb_p = city_j.get("backdrop", "")
                            if cb_p and (not cb_p.startswith("res://") or not os.path.exists(os.path.join(game_root, cb_p[6:]))):
                                errors.append(f"Missing map backdrop {cb_p} in {city_j.get('id')}")
                            for bc in city_j.get("children", []):
                                if bc.get("status") not in valid_statuses:
                                    errors.append(f"Invalid status in city child {bc.get('id')}")
                                inf = bc.get("interior_file", "")
                                if inf:
                                    int_j = load_res(inf, f"{city_j.get('id')}/{bc.get('id')}")
                                    if int_j:
                                        interiors_list.append(int_j)

    ib_p = idf_j.get("backdrop", "")
    if ib_p and (not ib_p.startswith("res://") or not os.path.exists(os.path.join(game_root, ib_p[6:]))):
        errors.append(f"Missing map backdrop {ib_p} in idf")

    loc_ids = {l["id"] for l in interiors_list}

    for c in chars_j["characters"]:
        cid = c["id"]
        port_p = c.get("portrait", "")
        if not port_p or not port_p.startswith("res://") or not os.path.exists(os.path.join(game_root, port_p[6:])):
            errors.append(f"Missing or invalid portrait for {cid}: {port_p}")
        app = c.get("appearance", {})
        if not isinstance(app, dict):
            errors.append(f"Missing appearance dict for {cid}")
        else:
            for ak in ("head", "default_top", "default_bottom"):
                ap = app.get(ak, "")
                if not ap or not ap.startswith("res://"):
                    errors.append(f"Invalid appearance.{ak} for {cid}: {ap}")
                else:
                    _check_modular_png(os.path.join(game_root, ap[6:]), f"{cid}.appearance.{ak}", errors)
        def_eq = c.get("default_equipment", {})
        if isinstance(def_eq, dict) and def_eq:
            for sl, iid in def_eq.items():
                if sl not in valid_slots:
                    errors.append(f"Invalid default_equipment slot '{sl}' on {cid}")
                elif iid:
                    if iid not in equip_by_id:
                        errors.append(f"Unknown default_equipment item '{iid}' on {cid}")
                    elif equip_by_id[iid].get("slot") != sl:
                        errors.append(f"Slot mismatch for {cid}.{sl} = {iid} (expected {equip_by_id[iid].get('slot')})")

    pending_assets: list[str] = []
    profiles_path = os.path.join(game_root, "data/player_profiles.json")
    if os.path.exists(profiles_path):
        prof_j = load_j("data/player_profiles.json")
        for p_entry in prof_j.get("portraits", []):
            pid = p_entry.get("id", "?")
            port_p = p_entry.get("portrait", "")
            if not port_p or not port_p.startswith("res://") or not os.path.exists(os.path.join(game_root, port_p[6:])):
                errors.append(f"Missing portrait for player profile {pid}: {port_p}")
            for ak in ("head", "default_top", "default_bottom"):
                ap = p_entry.get(ak, "")
                if not ap or not ap.startswith("res://"):
                    errors.append(f"Invalid {ak} for player profile {pid}: {ap}")
                else:
                    _check_modular_png(os.path.join(game_root, ap[6:]), f"profile.{pid}.{ak}", errors)
        for arch in prof_j.get("archetypes", []):
            aid = arch.get("id", "")
            for req_k in ("id", "title", "story", "specialty_id"):
                if not str(arch.get(req_k, "")).strip():
                    errors.append(f"Missing {req_k} in archetype {aid or '?'}")
            de = arch.get("default_equipment", {})
            if isinstance(de, dict):
                for sl, iid in de.items():
                    if sl not in valid_slots:
                        errors.append(f"Invalid archetype default_equipment slot '{sl}' on {aid}")
                    elif iid:
                        if iid not in equip_by_id:
                            errors.append(f"Unknown archetype equipment '{iid}' on {aid}")
                        elif equip_by_id[iid].get("slot") != sl:
                            errors.append(f"Slot mismatch on {aid}.{sl} = {iid}")

    for enc_id, enc_d in encs_j.get("encounters", {}).items():
        for en in enc_d.get("enemies", []):
            eid = en.get("id", "?")
            ep = en.get("portrait", "")
            if not ep or not ep.startswith("res://") or not os.path.exists(os.path.join(game_root, ep[6:])):
                errors.append(f"Missing enemy portrait in {enc_id}/{eid}: {ep}")
            eapp = en.get("appearance", {})
            if not isinstance(eapp, dict):
                errors.append(f"Missing enemy appearance in {enc_id}/{eid}")
            else:
                for ak in ("head", "top", "bottom"):
                    ap = eapp.get(ak, "")
                    if not ap or not ap.startswith("res://"):
                        errors.append(f"Invalid enemy appearance.{ak} in {enc_id}/{eid}: {ap}")
                    else:
                        _check_modular_png(os.path.join(game_root, ap[6:]), f"encounter.{enc_id}.{eid}.{ak}", errors)

    for l in interiors_list:
        lid = l["id"]
        if int(l.get("grid_w", 0)) < 4 or int(l.get("grid_h", 0)) < 4:
            errors.append(f"Invalid grid dimensions in interior {lid}")
        if l.get("render_mode", "") not in ("backdrop", "modular"):
            errors.append(f"Invalid render_mode in interior {lid}")
        if "lights" not in l or not isinstance(l["lights"], list):
            errors.append(f"Missing lights list in location {lid}")
        for nid in l.get("neighbors", {}):
            if nid not in loc_ids:
                errors.append(f"Unknown neighbor {nid} in {lid}")
        for hs in l.get("hotspots", []):
            did = hs.get("dialogue_id", "")
            if did and did not in dlg_ids:
                errors.append(f"Unknown hotspot dialogue_id {did} in {lid}")
        for ex in l.get("exits", []):
            tl = int(ex.get("target_level", 0))
            if tl < 1 or tl > 4:
                errors.append(f"Invalid exit target_level {tl} in {lid}")
        for occ in l.get("occluders", []):
            tex_p = occ.get("texture", "")
            poly_px = occ.get("polygon_px", [])
            if tex_p:
                if not tex_p.startswith("res://") or not os.path.exists(os.path.join(game_root, tex_p[6:])):
                    errors.append(f"Missing occluder texture {tex_p} in {lid}")
            elif not (isinstance(poly_px, list) and len(poly_px) >= 3):
                errors.append(f"Invalid occluder polygon_px in {lid}: {occ.get('id')}")
        for npc in l.get("npcs", []):
            cid = npc.get("char_id", "")
            did = npc.get("dialogue_id", "")
            if cid not in char_ids:
                errors.append(f"Unknown NPC char_id {cid} in {lid}")
            if did and did not in dlg_ids:
                errors.append(f"Unknown NPC dialogue_id {did} in {lid}")
        b = l.get("backdrop", "")
        if b and not os.path.exists(os.path.join(game_root, b[6:])):
            errors.append(f"Missing backdrop {b} in {lid}")

    for did, dnode in dlgs_j["dialogues"].items():
        if dnode.get("speaker_id", "") not in char_ids:
            errors.append(f"Unknown speaker_id in dialogue {did}")
        for ch in dnode.get("choices", []):
            nxt = ch.get("next", "")
            if nxt and nxt not in dlg_ids:
                errors.append(f"Unknown next dialogue {nxt} in {did}")
            fnxt = ch.get("fail_next", "")
            if fnxt and fnxt not in dlg_ids:
                errors.append(f"Unknown fail_next dialogue {fnxt} in {did}")
            cond = ch.get("conditions", {})
            if isinstance(cond, dict):
                req_act = cond.get("require_action", "")
                if req_act and valid_action_ids and req_act not in valid_action_ids:
                    errors.append(f"Unknown require_action {req_act} in {did}")
                req_it = cond.get("require_item", "")
                if req_it and valid_equip_ids and req_it not in valid_equip_ids:
                    errors.append(f"Unknown require_item {req_it} in {did}")
            sc = ch.get("skill_check", {})
            if isinstance(sc, dict) and sc:
                sk = sc.get("skill", "")
                if valid_skill_ids and sk not in valid_skill_ids:
                    errors.append(f"Unknown skill_check skill {sk} in {did}")
                dc_val = sc.get("dc", 0)
                if not isinstance(dc_val, int) or dc_val < 4:
                    errors.append(f"Invalid skill_check dc {dc_val} in {did}")
            for eff_key in ("effects", "fail_effects", "flaw_extra_effects"):
                eff = ch.get(eff_key, {})
                if not isinstance(eff, dict):
                    continue
                if "move_to" in eff and eff["move_to"] not in loc_ids:
                    errors.append(f"Unknown move_to in {eff_key} of {did}")
                if "recruit" in eff and eff["recruit"] not in char_ids:
                    errors.append(f"Unknown recruit in {eff_key} of {did}")
                if "start_encounter" in eff and eff["start_encounter"] not in enc_ids:
                    errors.append(f"Unknown start_encounter in {eff_key} of {did}")
                if "grant_item" in eff and valid_equip_ids and eff["grant_item"] not in valid_equip_ids:
                    errors.append(f"Unknown grant_item {eff['grant_item']} in {eff_key} of {did}")

    res_pattern = re.compile(r"res://([A-Za-z0-9_./-]+)")
    gd_count = 0
    for dirpath, _, filenames in os.walk(game_root):
        if "banlieue" in dirpath.split(os.sep):
            continue
        for fn in filenames:
            fp = os.path.join(dirpath, fn)
            if fn.endswith((".gd", ".tscn", ".godot", ".gdshader")):
                with open(fp, "r", encoding="utf-8") as f:
                    txt = f.read()
                if "autoload" in dirpath and fn.endswith(".gd") and re.search(r"^\s*class_name\b", txt, re.M):
                    errors.append(f"Autoload has class_name: {fp}")
                if fn.endswith(".gd"):
                    gd_count += 1
                    for ln_no, line in enumerate(txt.splitlines(), 1):
                        if ":=" in line and (".get(" in line or "JSON.parse_string" in line or ".call(" in line or "[" in line.split(":=", 1)[1]):
                            errors.append(f"Risky := on Variant at {fp}:{ln_no}: {line.strip()}")
                for m in res_pattern.finditer(txt):
                    rel = m.group(1)
                    if not os.path.exists(os.path.join(game_root, rel)):
                        errors.append(f"Missing res:// path {rel} referenced in {fp}")

    if errors:
        print("VALIDATION ERRORS:")
        for e in errors:
            print(" -", e)
        return 1
    if pending_assets:
        print(f"PENDING ASSETS ({len(pending_assets)}):")
        for pa in pending_assets:
            print(" -", pa)
    print(
        f"VALIDATION PASSED: {len(reg_ids)} regions, {len(dept_ids)} depts, {len(city_ids)} cities, "
        f"{len(loc_ids)} interiors, {len(char_ids)} chars, {len(dlg_ids)} dialogues, {gd_count} scripts — 0 errors."
    )
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", required=True, choices=["portrait", "clean_pawn", "backdrop", "preview", "split_pawn", "split_all_pawns", "preview_modular", "validate"])
    parser.add_argument("--src", default="")
    parser.add_argument("--dst", default="")
    parser.add_argument("--head-dst", default="")
    parser.add_argument("--top-dst", default="")
    parser.add_argument("--bottom-dst", default="")
    parser.add_argument("--collar-y", type=int, default=122)
    parser.add_argument("--waist-y", type=int, default=265)
    parser.add_argument("--cfg-json", default="")
    parser.add_argument("--combos-json", default="")
    parser.add_argument("--strip-standee", action="store_true")
    parser.add_argument("--backdrop", default="")
    parser.add_argument("--pawns", nargs="*", default=[])
    parser.add_argument("--height", type=int, default=162)
    parser.add_argument("--game-root", default=r"e:\JDR\BANLIEUE\game")
    args = parser.parse_args()

    if args.mode == "portrait":
        convert_to_png(args.src, args.dst, "PORTRAIT")
    elif args.mode == "backdrop":
        convert_to_png(args.src, args.dst, "BACKDROP")
    elif args.mode == "clean_pawn":
        cutout_clean_pawn(args.src, args.dst, strip_standee=args.strip_standee)
    elif args.mode == "split_pawn":
        cfg_d = {"collar_y": args.collar_y, "waist_y": args.waist_y}
        if args.cfg_json:
            cfg_d.update(json.loads(args.cfg_json))
        split_pawn_to_modular(args.src, args.head_dst, args.top_dst, args.bottom_dst, cfg=cfg_d)
    elif args.mode == "split_all_pawns":
        split_all_existing_pawns(args.game_root)
    elif args.mode == "preview_modular":
        make_modular_preview(args.game_root, args.combos_json, args.dst)
    elif args.mode == "preview":
        make_preview(args.backdrop, args.pawns, args.dst, target_h=args.height)
    elif args.mode == "validate":
        sys.exit(validate_project(args.game_root))
