"""Enregistre un tour complet de chaque musique (sortie CNA) : musique_<n>.wav"""
import importlib.util, io, contextlib, os
from to9sim import TO9, sym, wav
S = sym()
spec = importlib.util.spec_from_file_location('music', '../music.py'); music = importlib.util.module_from_spec(spec)
cwd = os.getcwd()
with contextlib.redirect_stdout(io.StringIO()): spec.loader.exec_module(music)
os.chdir(cwd)
s = TO9('../TOETRIS.BIN')
s.run_frames(60)
print('fréquence du son :', {0: 2500, 1: 2000, 2: 1667, 3: 1250, 4: 0}[s.peek(S['SLOWSND'])], 'Hz')
s.key(0x0A); s.run_frames(6)                 # ligne MUSIQUE
for i, (key, mel, bass, name) in enumerate(music.SONGS):
    if i: s.key(0x09); s.run_frames(3)
    length = sum(d for _, d in music.expand(mel))
    c0 = s.cpu.cycles; s.run_frames(length + 20)
    fn = f"musique_{name.split()[0].lower()}.wav"
    print(f'{fn} : {wav(s, fn, c0, s.cpu.cycles):.0f} s')
