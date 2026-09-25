"""Graphismes TO9 : fonds (titre, jeu) compressés LZ, cases 6x9, police 3x5 -> gfx.asm"""
import os, sys
os.chdir(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, '.')
from maqlib import *

# ---------- constantes de mise en page (partagées avec l'assembleur) ----------
PX, PY = 50, 10            # coin du puits
NX, NY = 126, 30           # case (0,0) de l'aperçu "suivant" (pivot en colonne 1)
SCORE_XY = (14, 27); LINES_XY = (20, 63); LEVEL_XY = (22, 99)
STAT_X, STAT_Y0 = 136, 75  # chiffres des stats (police simple hauteur)
STAT_ORDER = 'TJZOSLI'
COLOR = {'Z': 4, 'L': 5, 'O': 6, 'S': 7, 'I': 8, 'J': 9, 'T': 10}
PIECE_ORDER = 'LJIOZST'    # ordre de la table des pièces (ids 0..6)

def panel(s, x, y, w, h, title):
    s.rect(x, y, w, h, 1); s.frame(x, y, w, h, 12); s.frame(x+1, y+1, w-2, h-2, 14)
    s.rect(x+2, y+2, w-4, 12, 14)
    text(s, x + (w - textw(title)) // 2, y + 3, title, 12)

def game_bg():
    g = Scr(0); sky(g, 0, 200, 45, seed=9)
    g.rect(0, 188, W, 12, 13)
    tower(g, 6, 164, 26, 24); tower(g, 128, 164, 26, 24)
    dome(g, 19, 164, 9, 4, 3, 14); dome(g, 141, 164, 9, 9, 6, 1)
    g.rect(PX-3, PY-3, 66, 186, 12); g.rect(PX-2, PY-2, 64, 184, 14); g.rect(PX-1, PY-1, 62, 182, 0)
    for r in range(20):
        for c in range(10): g.px(PX+c*6+3, PY+r*9+4, 11)
    panel(g, 4, 10, 42, 30, 'SCORE'); panel(g, 4, 46, 42, 30, 'LIGNES'); panel(g, 4, 82, 42, 30, 'NIVEAU')
    panel(g, 114, 10, 42, 44, 'SUIVANT'); panel(g, 114, 60, 42, 70, 'STATS')
    yy = 76
    for p in STAT_ORDER:
        for dx, dy in SH[p]: g.rect(118+dx*3, yy+dy*3, 3, 3, COLOR[p])
        yy += 8
    return g

def title_bg():
    t = Scr(0); sky(t, 0, 200, 70)
    t.rect(0, 186, W, 14, 13)
    for x in range(0, W, 3): t.px(x, 186-(x*7) % 3, 13)
    basil(t, 186)
    L = {'T': ['111','010','010','010','010'], 'E': ['111','100','110','100','111'], 'R': ['110','101','110','101','101'],
         'I': ['1','1','1','1','1'], 'S': ['011','100','010','001','110'], 'O': ['111','101','101','101','111']}
    name = 'TOETRIS'; cols = [12, 12, 4, 5, 6, 8, 10]     # « TO » en or (Thomson), le reste aux couleurs des pièces
    width = sum(len(L[ch][0]) * 6 + 4 for ch in name) - 4
    x = (W - width) // 2 + 1; y = 14                   # +1 : se compresse mieux
    for n, ch in enumerate(name):
        g = L[ch]
        for r, row in enumerate(g):
            for k, b in enumerate(row):
                if b == '1': cell(t, x+k*6, y+r*9, cols[n])
        x += len(g[0])*6 + 4
    text(t, (W - textw('THOMSON TO9')) // 2, 64, 'THOMSON TO9', 12, 0)
    t.rect(18, 188, 124, 12, 0); t.frame(18, 188, 124, 12, 12)
    msg = 'APPUIE SUR ENTRÉE'; text(t, (W - textw(msg)) // 2 + 1, 189, msg, 3)
    return t

# ---------- conversion vers les deux banques (2 pixels par octet) ----------
def banks(s):
    A = bytearray(); B = bytearray()
    for y in range(200):
        row = s.p[y]
        for g in range(40):
            A.append(row[4*g] << 4 | row[4*g+1]); B.append(row[4*g+2] << 4 | row[4*g+3])
    return bytes(A), bytes(B)

def lz(data):
    """c<$80 : c+1 littéraux ; c>=$80 : copie de (c&$7F)+3 octets à distance d (16 bits)
    Découpage optimal (programmation dynamique) : même format, ~7 % plus petit qu'un choix glouton."""
    n = len(data)
    # plus longue correspondance (longueur, distance) à chaque position
    table = {}; ml = [(0, 0)] * n
    for i in range(n):
        key = data[i:i+3]; best = (0, 0)
        if len(key) == 3:
            for j in reversed(table.get(key, [])):
                l = 0
                while i+l < n and l < 130 and data[j+l] == data[i+l]: l += 1
                if l > best[0]: best = (l, i - j)
                if l == 130: break
            table.setdefault(key, []).append(i)
        ml[i] = best
    # coût minimal pour atteindre i ; état = 0 après une copie, k = k littéraux en cours
    INF = 10**9
    cost = [dict() for _ in range(n + 1)]; cost[0] = {0: (0, None)}
    for i in range(n):
        for st, (c, _) in list(cost[i].items()):
            ns, nc = (1, c + 2) if st in (0, 128) else (st + 1, c + 1)
            if nc < cost[i+1].get(ns, (INF,))[0]: cost[i+1][ns] = (nc, (i, st, None))
            L, d = ml[i]
            for l in range(3, L + 1):
                if c + 3 < cost[i+l].get(0, (INF,))[0]: cost[i+l][0] = (c + 3, (i, st, (l, d)))
    st = min(cost[n], key=lambda s: cost[n][s][0]); ops = []; i = n
    while i > 0:
        bk = cost[i][st][1]; ops.append(bk); i, st = bk[0], bk[1]
    out = bytearray(); lit = bytearray()
    def flush():
        nonlocal lit
        while lit:
            ch = lit[:128]; out.append(len(ch) - 1); out.extend(ch); lit = lit[128:]
    for i, _, m in reversed(ops):
        if m is None: lit.append(data[i])
        else: flush(); out.append(0x80 | (m[0] - 3)); out += m[1].to_bytes(2, 'big')
    flush()
    return bytes(out)

def unlz(c, n):
    o = bytearray(); i = 0
    while len(o) < n:
        b = c[i]; i += 1
        if b < 0x80: o += c[i:i+b+1]; i += b+1
        else:
            l = (b & 0x7F) + 3; d = c[i] << 8 | c[i+1]; i += 2
            for _ in range(l): o.append(o[-d])
    return bytes(o)

# ---------- cases 6x9 : 3 colonnes de paires x 9 lignes ----------
def cell_img(kind, c):
    s = Scr(0)
    if kind == 'fill': cell(s, 0, 0, c)
    elif kind == 'ghost': s.frame(0, 0, 6, 9, c); s.px(3, 4, 11)
    elif kind == 'empty': s.px(3, 4, 11)
    cols = []
    for p in range(3):
        cols += [s.p[y][2*p] << 4 | s.p[y][2*p+1] for y in range(9)]
    return cols

if __name__ == '__main__':
    out = ["* Généré par gfx.py - ne pas éditer"]
    def db(label, data, per=16):
        if label: out.append(label)
        for i in range(0, len(data), per):
            out.append("        FCB " + ",".join(f"${b:02X}" for b in data[i:i+per]))
    for name, ev in [('PX', PX), ('PY', PY), ('NX', NX), ('NY', NY), ('STATX', STAT_X), ('STATY', STAT_Y0),
                     ('SCOREX', SCORE_XY[0]), ('SCOREY', SCORE_XY[1]), ('LINESX', LINES_XY[0]), ('LINESY', LINES_XY[1]),
                     ('LEVELX', LEVEL_XY[0]), ('LEVELY', LEVEL_XY[1])]:
        out.append(f"{name:8s}EQU {ev}")
    total = 0
    for nm, scr in [('TITLE', title_bg()), ('GAME', game_bg())]:
        scr.save(f'bg_{nm.lower()}.png')
        for bk, data in zip('AB', banks(scr)):
            c = lz(data); assert unlz(c, len(data)) == data
            db(f"LZ_{nm}_{bk}", c); total += len(c)
            print(nm, bk, len(data), '->', len(c))
    # cases : 0 vide, 1..7 pleines (ids 0..6 + 1), 8..14 fantômes, 15 flash, 16 gris
    tiles = [cell_img('empty', 0)]
    tiles += [cell_img('fill', COLOR[p]) for p in PIECE_ORDER]
    tiles += [cell_img('ghost', COLOR[p]) for p in PIECE_ORDER]
    tiles += [cell_img('fill', 3), cell_img('fill', 13)]
    db("CELLS", sum(tiles, []), 27)
    # police 3x5 : ' ' 0-9 A-Z < > : - . !
    chars = ' 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ<>:-.!'
    F['<'] = '001010100010001'; F['>'] = '100010001010100'
    for ch in 'JKQWZ': F.setdefault(ch, {'J': '001001001101010', 'K': '101101110101101', 'Q': '010101101110011', 'W': '101101111111101', 'Z': '111001010100111'}[ch])
    font = []
    for ch in chars:
        g = F[ch]; font += [int(g[r*3:r*3+3], 2) for r in range(5)]
    out.append('FONTCH  FCC "' + chars + '"')
    out.append(f'NFONT   EQU {len(chars)}')
    db("FONT", font, 15)
    # pièces : 4 rotations x 4 cases (ligne, colonne, tuile) ; rotations relevées sur le Game Boy
    raw = {
     'L': [[(3,3),(3,4),(3,5),(4,3)],[(2,3),(2,4),(3,4),(4,4)],[(2,5),(3,3),(3,4),(3,5)],[(2,4),(3,4),(4,4),(4,5)]],
     'J': [[(3,3),(3,4),(3,5),(4,5)],[(2,4),(3,4),(4,3),(4,4)],[(2,3),(3,3),(3,4),(3,5)],[(2,4),(2,5),(3,4),(4,4)]],
     'I': [[(3,3),(3,4),(3,5),(3,6)],[(1,4),(2,4),(3,4),(4,4)]]*2,
     'O': [[(3,4),(3,5),(4,4),(4,5)]]*4,
     'Z': [[(3,3),(3,4),(4,4),(4,5)],[(2,4),(3,3),(3,4),(4,3)]]*2,
     'S': [[(3,4),(3,5),(4,3),(4,4)],[(2,3),(3,3),(3,4),(4,4)]]*2,
     'T': [[(3,3),(3,4),(3,5),(4,4)],[(2,4),(3,3),(3,4),(4,4)],[(2,4),(3,3),(3,4),(3,5)],[(2,4),(3,4),(3,5),(4,4)]]}
    pieces = []
    for i, p in enumerate(PIECE_ORDER):
        for r in range(4):
            for a, b in raw[p][r]: pieces += [(a-3) & 255, (b-4) & 255, i+1]
    db("PIECES", pieces, 12)
    db("STATROW", [STAT_ORDER.index(p) for p in PIECE_ORDER])
    # chaînes (index de glyphes, fin = $FF)
    STR = {'S_NIV': 'NIVEAU', 'S_MUS': 'MUSIQUE', 'S_OUT': 'SORTIE', 'S_REC': 'RECORD',
           # noms des musiques (même ordre que SONGS dans music.py, puis « aucune »)
           'S_M0': 'KOROBEINIKI', 'S_M1': 'MENUET', 'S_M2': 'ODE A LA JOIE', 'S_M3': 'AUCUNE',
           'S_O0': 'CNA   ', 'S_O1': 'BUZZER',
           'S_PAUSE': 'PAUSE', 'S_GAME': 'GAME', 'S_OVER': 'OVER', 'S_ENTER': 'ENTREE'}
    MNW = max(len(v) for k, v in STR.items() if k.startswith('S_M') and k[3:].isdigit())
    out.append(f'MNAMEW  EQU {MNW + 1}')        # noms complétés à la même largeur
    for k, v in STR.items():
        if k.startswith('S_M') and k[3:].isdigit(): v = v.ljust(MNW)
        db(k, [chars.index(ch) for ch in v] + [0xFF], 20)
    # palette : octet 1 = VVVVRRRR, octet 2 = 000TBBBB
    pal = []
    for r, g, b in PAL: pal += [(g << 4) | r, b]
    db("PALETTE", pal, 8)
    open('gfx.asm', 'w').write("\n".join(out) + "\n")
    print('total fonds compressés', total, 'octets')
