#!/bin/sh
# Reconstruit TOETRIS.BIN, TOETRIS0.BIN (sans son) et la disquette TOETRIS.fd
set -e
cd "$(dirname "$0")"
python3 gfx.py
python3 music.py
lwasm --6809 --decb -o TOETRIS.BIN --list=toetris.lst --symbols toetris.asm
# version sans son : SNDENABLE = 0, retrouvé par son adresse dans les segments du binaire
python3 - <<'PY'
sym = {l.split()[2]: int(l.split()[3], 16) for l in open('toetris.lst', errors='replace') if l.startswith('[ G]')}
b = bytearray(open('TOETRIS.BIN', 'rb').read()); i = 0; a = sym['SNDENABLE']
while b[i] == 0:                                   # segment : 00, longueur, adresse, données
    n, org = b[i+1] << 8 | b[i+2], b[i+3] << 8 | b[i+4]
    if org <= a < org + n: b[i + 5 + a - org] = 0; break
    i += 5 + n
else: raise SystemExit('SNDENABLE introuvable dans TOETRIS.BIN')
open('TOETRIS0.BIN', 'wb').write(b)
PY
python3 make_fd.py TOETRIS.BIN TOETRIS.fd TOETRIS0.BIN
