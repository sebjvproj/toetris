"""Tests avec vérifications : centrage des textes, notes (repliement), coût de DRAWFIELD.
Lancer depuis source/test après build.sh :  python3 t_fix.py"""
import sys, os
from to9sim import TO9, sym
S = sym()
RET = 0xF100                     # adresse de retour sentinelle
fails = []

def check(ok, msg):
    print(('OK   ' if ok else 'ÉCHEC') + ' ' + msg)
    if not ok: fails.append(msg)

def call(s, addr, a=0, b=0, x=0, max_cyc=2_000_000):
    """appelle une routine (JSR) et rend le nombre de cycles"""
    cpu = s.cpu
    sp = cpu.system_stack_pointer.value - 2
    s.mem.ram[sp] = RET >> 8; s.mem.ram[sp + 1] = RET & 0xFF
    cpu.system_stack_pointer.set(sp)
    cpu.accu_a.set(a); cpu.accu_b.set(b); cpu.index_x.set(x)
    cpu.program_counter.set(addr)
    c0 = cpu.cycles
    while cpu.program_counter.value != RET:
        cpu.get_and_call_next_op()
        if cpu.cycles - c0 > max_cyc: raise RuntimeError('routine sans fin')
    return cpu.cycles - c0

def booted():
    s = TO9('../TOETRIS.BIN', timept=False)   # pas d'IRQ : appels directs sans parasites
    s.run_frames(40)
    return s

# ---------- 1. centrage de la boîte du puits ----------
s = booted()
for lab in ('S_PAUSE', 'S_GAME', 'S_OVER', 'S_ENTER'):
    n = 0
    while s.mem.ram[S[lab] + n] != 0xFF: n += 1
    call(s, S['CENTER'], x=S[lab])
    txp = s.peek(S['TXP'])
    # le texte occupe 4n-1 pixels ; le puits va de x=50 à x=109 (centre 79,5)
    x0 = txp * 2; centre = x0 + (4 * n - 1 - 1) / 2
    check(abs(centre - 79.5) <= 2, f'{lab:8s} {n} car. : TXP={txp} x={x0}..{x0+4*n-2} centre {centre:.1f} (puits 79,5)')

# ---------- 2. lecture des morceaux par le vrai SEQRD 6809 = ce que prévoit music.py ----------
import math, importlib.util, io, contextlib
spec = importlib.util.spec_from_file_location('music', '../music.py')
music = importlib.util.module_from_spec(spec)
cwd = os.getcwd()
with contextlib.redirect_stdout(io.StringIO()): spec.loader.exec_module(music)   # (réécrit music.asm à l'identique)
os.chdir(cwd)

def walk(s, start, block, ticks):
    """lit une voix avec SEQRD jusqu'à `ticks` : liste (note, durée)"""
    s.mem.ram[block:block + 8] = bytes([start >> 8, start & 0xFF]) + bytes(6)
    x, out, tot = start, [], 0
    while tot < ticks:
        cpu = s.cpu; cpu.index_y.set(block)
        call(s, S['SEQRD'], x=x)
        x = cpu.index_x.value
        out.append((cpu.accu_a.value, cpu.accu_b.value)); tot += cpu.accu_b.value
    return out

notes = set()
for i, (key, mel, bass, name) in enumerate(music.SONGS):
    for v, evs in (('V1', mel), ('V2', bass)):
        want = list(music.expand(evs))
        length = sum(d for _, d in want)
        got = walk(s, S[f'{key}_{v}'], S['M1LOOP'], 2 * length)   # deux tours : teste le retour au début
        check(got == want * 2, f'{name:13s} voix {v[1]} : {len(want)} notes, {length/50:.0f} s, lecture 6809 conforme')
        notes |= {n for n, _ in got if n}
for k in S:
    if k.startswith('SFX_'):
        a = S[k]
        while s.mem.ram[a] != 0xFE:
            if s.mem.ram[a]: notes.add(s.mem.ram[a])
            a += 2

# ---------- 2b. aucune note au-delà de la moitié de la fréquence d'échantillonnage ----------
rates = {0: 2500, 1: 2000, 2: 2500 / 1.5, 3: 1250}
for slow, rate in rates.items():
    s.mem.ram[S['SLOWSND']] = slow
    bad = []
    for n in sorted(notes):
        call(s, S['NOTEINC'], a=n)
        inc = s.cpu.accu_d.value
        f = inc * rate / 65536                      # fréquence réellement produite
        want = 440 * 2 ** ((n - 69) / 12)
        octv = round(math.log2(f / want) * 12) if f else None
        if inc >= 0x8000 or octv not in (0, -12, -24): bad.append((n, inc, round(f)))
    check(not bad, f'{rate:6.0f} Hz : {len(notes)} notes, fausses/repliées = {bad}')
s.mem.ram[S['SLOWSND']] = 0

# ---------- 2c. mélodie : transposée d'un bloc (octave), jamais de note isolée ----------
for slow, rate in rates.items():
    s.mem.ram[S['SLOWSND']] = slow
    for sel, (key, mel, bass, name) in enumerate(music.SONGS):
        s.mem.ram[S['MUSSEL']] = sel
        call(s, S['MUSSTART'])
        tr = s.peek(S['MELTR'])
        tune = [n for n, _ in music.expand(mel) if n]
        shifts = set()
        for n in set(tune):
            call(s, S['NOTEINC'], a=n - tr)
            f = s.cpu.accu_d.value * rate / 65536
            shifts.add(round(math.log2(f / (440 * 2 ** ((n - 69) / 12))) * 12))
        fits_higher = tr >= 12 and 440 * 2 ** ((max(tune) - tr + 12 - 69) / 12) < rate / 2
        check(len(shifts) == 1 and not fits_higher,
              f'{rate:6.0f} Hz {name:13s} : transposition {-tr:+d}, décalages entendus {sorted(shifts)}')
s.mem.ram[S['SLOWSND']] = 0; s.mem.ram[S['MUSSEL']] = 0

# ---------- 3. coût du redessin du puits après une ligne ----------
s = booted()
s.key(0x0D); s.run_frames(60)                  # une partie démarre
B = S['BOARD']
for r in range(15, 20):
    for c in range(10): s.mem.ram[B + r * 10 + c] = 1 + (r + c) % 7
cyc_full = call(s, S['DRAWFIELD'])             # plateau affiché = plateau (SCR à jour)
for c in range(10): s.mem.ram[B + 19 * 10 + c] = 0   # une ligne change
if 'DRAWDIFF' in S:
    cyc_diff = call(s, S['DRAWDIFF'])
    scr_ok = bytes(s.mem.ram[S['SCR']:S['SCR'] + 200]) == bytes(s.mem.ram[B:B + 200])
    check(scr_ok, 'DRAWDIFF : écran = plateau')
    check(cyc_diff < cyc_full / 5, f'DRAWFIELD {cyc_full} cycles, DRAWDIFF {cyc_diff} cycles (1 ligne changée)')
else:
    check(False, f'DRAWDIFF absent (DRAWFIELD {cyc_full} cycles = {cyc_full/20000:.1f} images)')

# ---------- 4. après de vrais effacements en jeu, l'écran = un redessin complet ----------
s = TO9('../TOETRIS.BIN')
s.run_frames(60); s.key(0x0D); s.run_frames(40)
for r in range(14, 20):
    for c in range(9): s.mem.ram[B + r * 10 + c] = 1 + (r * 3 + c) % 7
s.key(0x0D); s.run_frames(20); s.key(0x0D); s.run_frames(20)   # pause : redessin du plateau
lines0 = bytes(s.mem.ram[S['LINES']:S['LINES'] + 2])
for n in range(8):                              # des I verticaux dans la colonne 9
    s.mem.ram[S['NEXTP']] = 2
    s.run_frames(2)
    if s.peek(S['CURP']) == 2:
        if s.peek(S['CURR']) % 2 == 0: s.key(0x20); s.run_frames(6)
        for k in range(6): s.key(0x09); s.run_frames(6)
    s.hold(0x0A, 50); s.run_frames(52)
lines1 = bytes(s.mem.ram[S['LINES']:S['LINES'] + 2])
check(lines1 != lines0, f'des lignes ont été effacées ({lines0.hex()} -> {lines1.hex()})')
s.mem.ram[S['OVL']:S['OVL'] + 200] = bytes(200)        # sans la pièce en cours
vram = lambda: [bytes(v) for v in s.mem.vram]
cyc = call(s, S['DRAWDIFF']); v_diff = vram()
call(s, S['DRAWFIELD']); v_full = vram()
# SCR doit refléter exactement l'écran : DRAWDIFF efface aussi pièce et fantôme
diff = sum(a != b for x, y in zip(v_diff, v_full) for a, b in zip(x, y))
check(diff == 0, f'écran après effacements vs redessin complet : {diff} octets diffèrent')

# ---------- 5. menu : les morceaux se choisissent, changer en plein motif ne dérègle rien ----------
s = TO9('../TOETRIS.BIN')
s.run_frames(60)
sp0 = s.cpu.system_stack_pointer.value
s.key(0x0A); s.run_frames(6)                          # ligne MUSIQUE
seen = []
for i in range(len(music.SONGS) + 2):                 # droite jusqu'à « aucune » (et une de trop)
    s.run_frames(137)                                 # joue un peu : on est au milieu d'un motif
    seen.append(s.peek(S['MUSSEL']))
    s.key(0x09); s.run_frames(8)
seen.append(s.peek(S['MUSSEL']))
check(seen == list(range(len(music.SONGS) + 1)) + [len(music.SONGS)] * 2, f'MUSSEL au fil des appuis : {seen}')
s.key(0x08); s.run_frames(8)                          # retour sur le dernier morceau
s.screenshot('fix_menu.png')
check(s.peek(S['MUSON']) == 1 and s.peek(S['MUSSEL']) == len(music.SONGS) - 1, 'dernier morceau relancé')
t = TO9('../TOETRIS.BIN', timept=False); t.run_frames(40)
for blk in ('M1LOOP', 'M2LOOP'):                      # voix en plein motif, transposée
    t.mem.ram[S[blk] + 2] = 2; t.mem.ram[S[blk] + 3] = 0xF4
t.mem.ram[S['MUSSEL']] = 1; call(t, S['MUSSTART'])
check(all(t.peek(S[b] + k) == 0 for b in ('M1LOOP', 'M2LOOP') for k in (2, 3)),
      'MUSSTART en plein motif : profondeur et transposition remises à 0')
s.run_frames(3000)                                    # 1 minute de musique : la pile ne dérive pas
check(s.cpu.system_stack_pointer.value == sp0 and s.peek(S['M1LOOP'] + 2) <= 2 and s.peek(S['M2LOOP'] + 2) <= 2,
      f'pile stable après 1 min ({sp0:04X} -> {s.cpu.system_stack_pointer.value:04X})')

print('\n' + ('TOUT EST OK' if not fails else f'{len(fails)} ÉCHEC(S)'))
sys.exit(1 if fails else 0)
