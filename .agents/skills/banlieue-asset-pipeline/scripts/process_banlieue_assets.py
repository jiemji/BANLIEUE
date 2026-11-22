import argparse
import json
import os
import re
import sys
from collections import deque
import numpy as np
from PIL import Image, ImageFilter


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
    valid_equip_ids = {eq.get("id", "") for eq in equip_j.get("equipment", []) if eq.get("id", "")}
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
        for key in ("portrait", "pawn"):
            res_p = c.get(key, "")
            if res_p:
                if not res_p.startswith("res://"):
                    errors.append(f"Invalid {key} path for {cid}: {res_p}")
                else:
                    fp = os.path.join(game_root, res_p[6:])
                    if not os.path.exists(fp):
                        errors.append(f"Missing {key} file for {cid}: {fp}")
                    elif key == "pawn":
                        im = Image.open(fp)
                        if im.mode != "RGBA":
                            errors.append(f"Pawn not RGBA: {fp}")
                        w, h = im.size
                        if h != 526:
                            errors.append(f"Expected pawn height 526 for {fp}, got {h}")
                        alpha = im.getchannel("A")
                        if alpha.getpixel((0, 0)) != 0 or alpha.getpixel((w - 1, h - 1)) != 0:
                            errors.append(f"Pawn transparent padding missing in {fp}")

    pending_assets: list[str] = []
    profiles_path = os.path.join(game_root, "data/player_profiles.json")
    if os.path.exists(profiles_path):
        prof_j = load_j("data/player_profiles.json")
        for p_entry in prof_j.get("portraits", []):
            pid = p_entry.get("id", "?")
            is_pending = bool(p_entry.get("pending_asset", False))
            for key in ("portrait", "pawn"):
                res_p = p_entry.get(key, "")
                if not res_p or not res_p.startswith("res://"):
                    errors.append(f"Invalid {key} path for player profile {pid}: {res_p}")
                    continue
                fp = os.path.join(game_root, res_p[6:])
                if not os.path.exists(fp):
                    if is_pending:
                        pending_assets.append(f"{pid}.{key} ({res_p})")
                    else:
                        errors.append(f"Missing {key} file for player profile {pid}: {fp}")
                elif key == "pawn":
                    im = Image.open(fp)
                    if im.mode != "RGBA":
                        errors.append(f"Player pawn not RGBA: {fp}")
                    w, h = im.size
                    if h != 526:
                        errors.append(f"Expected player pawn height 526 for {fp}, got {h}")
                    alpha = im.getchannel("A")
                    if alpha.getpixel((0, 0)) != 0 or alpha.getpixel((w - 1, h - 1)) != 0:
                        errors.append(f"Player pawn transparent padding missing in {fp}")
        for arch in prof_j.get("archetypes", []):
            aid = arch.get("id", "")
            for req_k in ("id", "title", "story", "specialty_id"):
                if not str(arch.get(req_k, "")).strip():
                    errors.append(f"Missing {req_k} in archetype {aid or '?'}")

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
    parser.add_argument("--mode", required=True, choices=["portrait", "clean_pawn", "backdrop", "preview", "validate"])
    parser.add_argument("--src", default="")
    parser.add_argument("--dst", default="")
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
    elif args.mode == "preview":
        make_preview(args.backdrop, args.pawns, args.dst, target_h=args.height)
    elif args.mode == "validate":
        sys.exit(validate_project(args.game_root))
