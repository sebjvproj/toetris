"""Musiques et bruitages -> music.asm
Format voix : paires (note MIDI, durée en 1/50 s) ; note 0 = silence ; plus des commandes :
  $FB t     transposer les notes suivantes de t demi-tons (état de la voix, remis à 0 au début)
  $FC       fin de motif (retour)
  $FD adr   jouer le motif adr (2 niveaux d'imbrication au plus)
  $FF       retour au début du morceau
Format bruitage : paires (note, durée) terminées par $FE.
Arrangements originaux d'airs du domaine public."""
import os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
RATE = 2500                     # fréquence d'échantillonnage (IRQ timer)
NOTEBASE, NOTEMAX = 24, 96      # étendue de NOTETAB
N = {'C':0,'C#':1,'D':2,'D#':3,'E':4,'F':5,'F#':6,'G':7,'G#':8,'A':9,'A#':10,'B':11}
def m(n):                       # 'E5' -> 76
    if n == 'r': return 0
    name, oct = n[:-1], int(n[-1]); return 12*(oct+1) + N[name]

# ---- petit langage : notes 'E5:2' (durée en unités), T(t) transposition, C('MOTIF') appel
def seq(s, unit):
    out = []
    for tok in s.split():
        n, d = tok.split(':'); t = float(d) * unit
        assert t == int(t) and 0 < t < 256, tok
        out.append(('n', m(n), int(t)))
    return out
def T(t): return [('t', t)]
def C(name): return [('c', name)]
PAT = {}                        # motifs : nom -> événements (sans le $FC final)
def pat(name, *parts):
    PAT[name] = sum(parts, []); return name

def expand(evs, depth=0, st=None):
    """déroule comme le 6809 : (note jouée, durée) ; vérifie l'imbrication"""
    st = st if st is not None else {'t': 0}
    for e in evs:
        if e[0] == 'n':
            n = e[1] + st['t'] if e[1] else 0
            yield n, e[2]
        elif e[0] == 't': st['t'] = e[1]
        else:
            assert depth < 2, f'motif {e[1]} : plus de 2 niveaux'
            yield from expand(PAT[e[1]], depth + 1, st)

# ===== A : Korobeiniki (chant populaire russe) - croche = 10/50 s =====
E = 10
pat('KO_A', seq('''E5:2 B4:1 C5:1 D5:2 C5:1 B4:1   A4:2 A4:1 C5:1 E5:2 D5:1 C5:1
                   B4:3 C5:1 D5:2 E5:2             C5:2 A4:2 A4:2 r:2''', E))
pat('KO_B', seq('''r:1 D5:2 F5:1 A5:2 G5:1 F5:1    E5:3 C5:1 E5:2 D5:1 C5:1
                   B4:2 B4:1 C5:1 D5:2 E5:2        C5:2 A4:2 A4:2 r:2''', E))
KO_TUNE = C('KO_A') + C('KO_B')
# basse : une mesure-type (sur mi) transposée pour chaque accord de la grille
KO_GRID = [0, 5, 0, 5, -2, -4, 0, 5]           # mi la mi la ré do mi la
def grid(name, fig, g):
    ev, cur = [], None
    for t in g:
        if t != cur: ev += T(t); cur = t
        ev += C(fig)
    return pat(name, ev)
pat('KO_OCT', seq('E2:1 E3:1 ' * 4, E))       # octaves battues
pat('KO_WLK', seq('E2:2 B2:2 E3:2 B2:2', E))   # basse en noires (couplet 3)
grid('KO_BO', 'KO_OCT', KO_GRID)
grid('KO_BW', 'KO_WLK', KO_GRID)
# 4 couplets : deux fois le thème, une fois une octave plus bas sur une basse en noires, une fois le thème
KORO_MEL = KO_TUNE + KO_TUNE + T(-12) + KO_TUNE + T(0) + KO_TUNE
KORO_BASS = C('KO_BO') + C('KO_BO') + C('KO_BW') + C('KO_BO')

# ===== B : Menuet en sol (Petzold, attribué à Bach) - noire = 24/50 s =====
Q = 24
pat('ME_A', seq('''D5:1 G4:.5 A4:.5 B4:.5 C5:.5  D5:1 G4:1 G4:1  E5:1 C5:.5 D5:.5 E5:.5 F#5:.5  G5:1 G4:1 G4:1
                   C5:1 D5:.5 C5:.5 B4:.5 A4:.5  B4:1 C5:.5 B4:.5 A4:.5 G4:.5''', Q))
pat('ME_B', seq('''B5:1 G5:.5 A5:.5 B5:.5 G5:.5  A5:1 D5:.5 E5:.5 F#5:.5 D5:.5  G5:1 E5:.5 F#5:.5 G5:.5 D5:.5
                   C#5:1 B4:.5 C#5:.5 A4:1  A4:.5 B4:.5 C#5:.5 D5:.5 E5:.5 F#5:.5  G5:1 F#5:1 E5:1
                   F#5:1 A4:1 C#5:1  D5:3
                   D5:1 G4:.5 F#4:.5 G4:1  E5:1 G4:.5 F#4:.5 G4:1  D5:1 C5:1 B4:1  A4:.5 G4:.5 F#4:.5 G4:.5 A4:1
                   D4:.5 E4:.5 F#4:.5 G4:.5 A4:.5 B4:.5  C5:1 B4:1 A4:1  B4:.5 D5:.5 G4:1 F#4:1  G4:3''', Q))
pat('ME_AB', seq('G3:3 B3:3 C4:3 B3:3 A3:3 G3:3', Q))
pat('ME_BB', seq('''G3:3 F#3:3 E3:3 A2:3  D3:3 E3:3 A2:1 C#3:1 A2:1  D3:1 A2:1 D2:1
                    B3:3 C4:3 B3:1 A3:1 G3:1  D3:3  G2:3 A2:1 G2:1 F#2:1  D3:3  G2:2 r:1''', Q))
# forme A A B B (les deux reprises du menuet)
MEN_MEL = (C('ME_A') + seq('F#4:1 G4:.5 A4:.5 B4:.5 G4:.5  A4:3', Q) +
           C('ME_A') + seq('A4:1 B4:.5 A4:.5 G4:.5 F#4:.5  G4:3', Q) + C('ME_B') + C('ME_B'))
MEN_BASS = (C('ME_AB') + seq('D4:1 B3:1 G3:1  D3:1 F#3:1 D3:1', Q) +
            C('ME_AB') + seq('C4:1 D4:1 D3:1  G2:2 r:1', Q) + C('ME_BB') + C('ME_BB'))

# ===== C : Ode à la joie (Beethoven, 9e symphonie) en ré - noire = 22/50 s =====
Q = 22
pat('OD_P', seq('F#5:1 F#5:1 G5:1 A5:1  A5:1 G5:1 F#5:1 E5:1  D5:1 D5:1 E5:1 F#5:1', Q))
pat('OD_M', C('OD_P') + seq('F#5:1.5 E5:.5 E5:2', Q) + C('OD_P') + seq('E5:1.5 D5:.5 D5:2', Q) +
    seq('''E5:1 E5:1 F#5:1 D5:1  E5:1 F#5:.5 G5:.5 F#5:1 D5:1  E5:1 F#5:.5 G5:.5 F#5:1 E5:1  D5:1 E5:1 A4:2''', Q) +
    C('OD_P') + seq('E5:1.5 D5:.5 D5:2', Q))
# basse : ré (0) ou la (-5) par mesure ; mesures 8, 12 et 16 écrites à part
pat('OD_F1', seq('D3:1 A3:1 F#3:1 A3:1', Q))   # arpège
pat('OD_F2', seq('D3:2 A2:2', Q))              # blanches (2e fois)
def ode_bass(name, fig, end8, end12):
    ev, cur = [], None
    def bars(g):
        nonlocal ev, cur
        for t in g:
            if t != cur: ev += T(t); cur = t
            ev += C(fig)
    bars([0, -5, 0, -5, 0, -5, 0]); ev += T(0) + seq(end8, Q); cur = 0
    bars([-5, -5, -5]); ev += T(0) + seq(end12, Q); cur = 0
    bars([0, -5, 0]); ev += T(0) + seq(end8, Q); cur = 0
    return pat(name, ev)
ode_bass('OD_B1', 'OD_F1', 'A2:1 E3:1 D3:2', 'D3:1 F#3:1 A2:2')
ode_bass('OD_B2', 'OD_F2', 'A2:2 D3:2', 'D3:2 A2:2')
ODE_MEL = C('OD_M') + C('OD_M')
ODE_BASS = C('OD_B1') + C('OD_B2')

SONGS = [('KORO', KORO_MEL, KORO_BASS, 'Korobeiniki'), ('MEN', MEN_MEL, MEN_BASS, 'Menuet'),
         ('ODE', ODE_MEL, ODE_BASS, 'Ode a la joie')]

# ---------- vérifications ----------
maxnote = {}
for key, mel, bass, name in SONGS:
    em, eb = list(expand(mel)), list(expand(bass))
    a, b = sum(d for _, d in em), sum(d for _, d in eb)
    assert a == b, f'{name} : mélodie {a} ticks, basse {b} ticks  <-- DÉCALAGE'
    notes = [n for n, _ in em + eb if n]
    assert NOTEBASE <= min(notes) and max(notes) <= NOTEMAX, f'{name} : note hors table'
    maxnote[key] = max(n for n, _ in em if n)
    print(f'{name}: {a} ticks = {a/50:.0f} s')

SFX = {
 'MOVE':   (1, [79, 1]),
 'ROT':    (1, [72, 1, 79, 1]),
 'LOCK':   (2, [43, 2, 36, 2]),
 'LINE':   (4, [72, 3, 76, 3, 79, 3, 84, 5]),
 'QUAD':   (5, [72, 3, 76, 3, 79, 3, 84, 3, 79, 3, 84, 3, 88, 8]),
 'LEVEL':  (5, [79, 4, 0, 1, 84, 4, 0, 1, 91, 8]),
 'OVER':   (6, [67, 8, 62, 8, 58, 8, 55, 20]),
 'MENU':   (1, [84, 2]),
}

# ---------- sortie ----------
out = ["* Généré par music.py - ne pas éditer", f"SNDRATE EQU {RATE}"]
def db(label, data, per=16):
    out.append(label)
    for i in range(0, len(data), per):
        out.append("        FCB " + ",".join(f"${b:02X}" for b in data[i:i+per]))
def voice(label, evs, end):
    """événements -> lignes FCB / FDB"""
    out.append(label); buf = []
    def flush():
        for i in range(0, len(buf), 16):
            out.append("        FCB " + ",".join(f"${b:02X}" for b in buf[i:i+16]))
        buf.clear()
    for e in evs:
        if e[0] == 'n': buf += [e[1], e[2]]
        elif e[0] == 't': buf += [0xFB, e[1] & 0xFF]
        else: buf.append(0xFD); flush(); out.append(f"        FDB {e[1]}")
    buf.append(end); flush()
for name, evs in PAT.items():
    voice(name, evs, 0xFC)
for key, mel, bass, _ in SONGS:
    voice(f'{key}_V1', mel, 0xFF); voice(f'{key}_V2', bass, 0xFF)
out.append(f"NSONGS  EQU {len(SONGS)}")
out.append("SONGTAB")                   # voix 1, voix 2, note la plus aiguë de la mélodie
for key, *_ in SONGS:
    out.append(f"        FDB {key}_V1,{key}_V2")
    out.append(f"        FCB {maxnote[key]}")
for k, (prio, d) in SFX.items():
    out.append(f"SP_{k:7s}EQU {prio}")
    db('SFX_' + k, d + [0xFE])
# incréments de phase 16 bits pour les notes MIDI 24..96
inc = [round(440 * 2 ** ((n - 69) / 12) * 65536 / RATE) for n in range(NOTEBASE, NOTEMAX + 1)]
assert max(inc) < 65536
out.append(f"NOTEBASE EQU {NOTEBASE}")
out.append("NOTETAB")
for i in range(0, len(inc), 8):
    out.append("        FDB " + ",".join(f"${v:04X}" for v in inc[i:i+8]))
open('music.asm', 'w').write("\n".join(out) + "\n")
