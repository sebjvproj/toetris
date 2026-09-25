import random, time
from to9sim import TO9, sym, wav
S=sym()
s=TO9('../TOETRIS.BIN')
s.run_frames(60)
s.key(0x0B); s.run_frames(5)
for i in range(9): s.key(0x09); s.run_frames(5)
s.key(0x0D); s.run_frames(40)
B=S['BOARD']
# lignes presque pleines (colonne 9 libre) pour provoquer des effacements
for r in range(12,20):
    for c in range(9): s.mem.ram[B+r*10+c]=1+(r*3+c)%7
# on force l'affichage du plateau en appelant DRAWFIELD via la pause
s.key(0x0D); s.run_frames(20); s.key(0x0D); s.run_frames(20)
s.screenshot('v4_board.png')
# place des I verticaux dans la colonne 9
got=[]
for n in range(12):
    s.mem.ram[S['NEXTP']]=2
    s.run_frames(2)
    if s.peek(S['CURP'])==2:
        if s.peek(S['CURR'])%2==0: s.key(0x20); s.run_frames(6)
        for k in range(6): s.key(0x09); s.run_frames(6)
    s.hold(0x0A, 50); s.run_frames(52)
    got.append(bytes(s.mem.ram[S['LINES']:S['LINES']+2]).hex())
    if n==1: s.screenshot('v4_clear.png')
print('lignes au fil du temps', got)
print('score',bytes(s.mem.ram[S['SCORE']:S['SCORE']+3]).hex(),'niveau',s.peek(S['LEVEL']))
s.screenshot('v4_after.png')
# jeu jusqu'à la fin de partie
for i in range(2500):
    s.run_frames(1)
    if s.cpu.program_counter.value in (S['GO_3'],) or s.peek(S['GOROW'])==20: break
s.run_frames(120); s.screenshot('v4_over.png')
print('record', bytes(s.mem.ram[S['TOPSC']:S['TOPSC']+3]).hex())
s.key(0x0D); s.run_frames(60); s.screenshot('v4_title.png')
