"""Film de démonstration : ../../apercus/toetris.gif
Écran titre (2 s) puis 25 s d'une partie jouée par un pilote automatique : heuristique classique
(hauteur, lignes complétées, trous, relief) avec anticipation de la pièce suivante, et jeu « Tetris »
(puits à droite gardé libre pour le I, pile propre à gauche).
Tout est déterministe : même binaire -> même GIF. Le moment de l'appui sur ENTRÉE fixe la suite des
pièces (le générateur avance à chaque image) ; ENTER_AT a été choisi parmi quelques essais pour
montrer une ligne simple puis un Tetris (4 lignes) : à revoir si le jeu change.
Lancer depuis n'importe où, après build.sh :  python3 film.py"""
import os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from to9sim import TO9, sym

BIN = os.path.join(HERE, '..', 'TOETRIS.BIN')
LST = os.path.join(HERE, '..', 'toetris.lst')
OUT = os.path.normpath(os.path.join(HERE, '..', '..', 'apercus', 'toetris.gif'))

S = sym(LST)
ENTER_AT = 182             # image de l'appui sur ENTRÉE (titre affiché dès l'image 45)
TITLE_LEN = 100            # 2 s de titre/menu filmées avant ENTRÉE
GAME_LEN = 1250            # 25 s de jeu après ENTRÉE (fondu, puis la partie)
STEP = 3                   # une action (rotation / déplacement) toutes les 3 images
THINK = 3                  # temps de « réflexion » à l'apparition d'une pièce
SKIP = 2                   # une image sur 2 dans le GIF (25 images/s, 40 ms)
SCALE = 2                  # 640x480 : 4:3, comme TO9.screenshot()

K_LEFT, K_RIGHT, K_DOWN, K_CW, K_CCW, K_ENTER = 0x08, 0x09, 0x0A, 0x20, ord('Z'), 0x0D
W, H = 10, 20

# ---------------------------------------------------------------- pièces lues dans le binaire
def s8(v): return v - 256 if v > 127 else v

def load_pieces(sim):
    """PIECES : 7 pièces x 4 rotations x 4 cases (ligne, colonne, tuile)"""
    p = []
    for k in range(7):
        rots = []
        for r in range(4):
            a = S['PIECES'] + (k * 4 + r) * 12
            rots.append(tuple((s8(sim.peek(a + 3 * i)), s8(sim.peek(a + 3 * i + 1))) for i in range(4)))
        p.append(rots)
    return p

# ---------------------------------------------------------------- pilote automatique
def fits(board, cells, y, x):
    for dy, dx in cells:
        r, c = y + dy, x + dx
        if not 0 <= c < W or r >= H: return False
        if r >= 0 and board[r][c]: return False
    return True

def place(board, cells, y, x):
    b = [row[:] for row in board]
    for dy, dx in cells:
        if y + dy < 0: return None, 0              # dépasse en haut : perdu
        b[y + dy][x + dx] = 1
    kept = [row for row in b if not all(row)]
    n = H - len(kept)
    return [[0] * W for _ in range(n)] + kept, n

def features(board):
    heights, holes = [], 0
    for c in range(W):
        h = 0
        for r in range(H):
            if board[r][c]:
                if not h: h = H - r
            elif h: holes += 1
        heights.append(h)
    return heights, holes

def reward(lines, before):
    """lignes : on attend le Tetris (4 lignes) tant que la pile est basse"""
    if max(features(before)[0]) >= 10: return 2 * lines
    return (0, -0.5, 1, 2, 12)[lines]

def shape(board):
    """jeu « Tetris » : puits à droite (colonne 9) gardé libre pour le I, pile propre à gauche"""
    heights, holes = features(board)
    stack = heights[:W - 1]
    bump = sum(abs(stack[i] - stack[i + 1]) for i in range(W - 2))
    deep = sum(max(0, min(stack[i - 1] if i else 99, stack[i + 1] if i < W - 2 else 99) - stack[i] - 2)
               for i in range(W - 1))                      # puits secondaires (il faudrait un I)
    return (-0.15 * sum(stack) - 6 * holes - 0.4 * bump - 2 * deep
            - 2.5 * heights[W - 1] - 3 * max(0, max(heights) - 12))

def placements(board, rots, r0, y0, x0):
    """(rotation, colonne, plateau après, lignes) atteignables : rotations sur place puis déplacements"""
    out = []
    shapes = set()
    for d in (0, 1, -1, 2):                         # rotations les plus courtes d'abord
        r = (r0 + d) % 4
        if rots[r] in shapes: continue
        shapes.add(rots[r])
        ok = True; rr = r0
        for _ in range(abs(d)):
            rr = (rr + (1 if d > 0 else -1)) % 4
            if not fits(board, rots[rr], y0, x0): ok = False; break
        if not ok: continue
        for x0s, step in ((x0, -1), (x0 + 1, 1)):  # vers la gauche (x0 compris), puis la droite
            x = x0s
            while fits(board, rots[r], y0, x):
                y = y0
                while fits(board, rots[r], y + 1, x): y += 1
                b, n = place(board, rots[r], y, x)
                if b is not None: out.append((r, x, b, n))
                x += step
    return out

def choose(board, pieces, cur, r0, y0, x0, nxt):
    best = None
    for r, x, b1, n1 in placements(board, pieces[cur], r0, y0, x0):
        s2 = max((reward(n2, b1) + shape(b2) for _, _, b2, n2 in placements(b1, pieces[nxt], 0, 0, 4)),
                 default=-1e9)                          # meilleure suite avec la pièce suivante
        score = reward(n1, board) + s2
        if best is None or score > best[0]: best = (score, r, x)
    return best[1:] if best else (r0, x0)

class Pilot:
    def __init__(self, sim):
        self.sim = sim
        self.pieces = load_pieces(sim)
        self.spawned = False
        self.target = None
        self.phase = 'idle'
        self.wait = 0
        self.last = None; self.tries = 0
        self.npieces = 0
        sim.hooks[S['SPAWN']] = self.on_spawn
        sim.hooks[S['GLOOP']] = self.on_gloop

    def on_spawn(self, sim): self.spawned = True

    def on_gloop(self, sim):                       # pièce en place, on réfléchit
        if not self.spawned: return
        self.spawned = False
        pk = sim.peek
        board = [[pk(S['BOARD'] + r * W + c) for c in range(W)] for r in range(H)]
        self.target = choose(board, self.pieces, pk(S['CURP']), pk(S['CURR']),
                             s8(pk(S['CURY'])), pk(S['CURX']), pk(S['NEXTP']))
        self.phase = 'release'; self.npieces += 1

    def press(self, code, frames=1):
        s = self.sim; f = s.frame
        s.keys[f] = code
        s.held_until = f + frames

    def tick(self):
        """appelé au début de chaque image"""
        s = self.sim; pk = s.peek
        if self.phase == 'release':                # lâche la descente rapide de la pièce précédente
            s.keys.clear(); s.pending.clear(); s.held_until = s.frame
            self.phase = 'move'; self.wait = THINK; self.last = None; self.tries = 0
        elif self.phase == 'move':
            if self.wait: self.wait -= 1; return
            tr, tx = self.target
            state = (pk(S['CURR']), pk(S['CURX']))
            if state == self.last:
                self.tries += 1
                if self.tries > 2: self.phase = 'drop'; return   # bloqué : on pose là
            else: self.last = state; self.tries = 0
            r, x = state
            if r != tr: self.press(K_CW if (tr - r) % 4 <= 2 else K_CCW)
            elif x != tx: self.press(K_LEFT if tx < x else K_RIGHT)
            else: self.phase = 'drop'; self.dropf = s.frame
            if self.phase == 'move': self.wait = STEP - 1
        if self.phase == 'drop':                   # touche bas maintenue (répétition entretenue)
            if (s.frame - self.dropf) % 20 == 0: s.keys[s.frame] = K_DOWN
            s.held_until = s.frame + 1000

# ---------------------------------------------------------------- image
def frame_image(sim):
    A = np.frombuffer(b''.join(a for a, _ in sim.beam), np.uint8).reshape(200, 40)
    B = np.frombuffer(b''.join(b for _, b in sim.beam), np.uint8).reshape(200, 40)
    idx = np.stack((A >> 4, A & 15, B >> 4, B & 15), axis=2).reshape(200, 160)
    im = Image.fromarray(idx.astype(np.uint8), 'P')
    im.putpalette([v for c in sim.palette_rgb() for v in c])
    # pixel TO9 = 2 x 1.2 : 160x200 -> 320x240 (4:3), puis échelle SCALE
    return im.resize((320 * SCALE, 240 * SCALE), Image.NEAREST)

def main():
    s = TO9(BIN)
    s.beam_on()
    frames = []
    s.run_frames(ENTER_AT - TITLE_LEN)
    pilot = None
    clears = []                                # (secondes depuis ENTRÉE, lignes)
    s.hooks[S['FLASHLINES']] = lambda s: clears.append(((s.frame - ENTER_AT) / 50, s.peek(S['NFULL'])))
    total = TITLE_LEN + GAME_LEN
    for i in range(total):
        if i == TITLE_LEN:
            s.key(K_ENTER)
            pilot = Pilot(s)
        if pilot: pilot.tick()
        s.run_frames(1)
        if i % SKIP == 0: frames.append(frame_image(s))
    lines = int(bytes(s.mem.ram[S['LINES']:S['LINES'] + 2]).hex())
    score = int(bytes(s.mem.ram[S['SCORE']:S['SCORE'] + 3]).hex())
    print(f'{pilot.npieces} pièces, {lines} lignes, score {score}, niveau {s.peek(S["LEVEL"])}')
    print('lignes effacées (s après ENTRÉE, nombre) :', [(round(t, 1), n) for t, n in clears])
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    frames[0].save(OUT, save_all=True, append_images=frames[1:], duration=20 * SKIP, loop=0,
                   optimize=False, disposal=1)
    print(f'{OUT} : {len(frames)} images, {len(frames) * 20 * SKIP / 1000:.1f} s, '
          f'{os.path.getsize(OUT) / 1e6:.2f} Mo')

if __name__ == '__main__':
    main()
