import random, time
from to9sim import TO9, sym, wav
S=sym()
s=TO9('../TOETRIS.BIN')
s.run_frames(40)
c0=s.cpu.cycles; s.run_frames(650); print('wav korobeiniki %.1fs'%wav(s,'korobeiniki.wav',c0,s.cpu.cycles))
# menu : musique -> Menuet
s.key(0x0A); s.run_frames(6); s.key(0x09); s.run_frames(8)
c0=s.cpu.cycles; s.run_frames(600); print('wav menuet %.1fs'%wav(s,'menuet.wav',c0,s.cpu.cycles))
s.screenshot('v2_menu.png')
s.key(0x09); s.run_frames(6); s.key(0x08); s.run_frames(6)     # Aucune puis retour Menuet
s.key(0x0B); s.run_frames(6)
for i in range(3): s.key(0x09); s.run_frames(6)                # niveau 3
s.key(0x0D); s.run_frames(40); s.screenshot('v2_game0.png')
print('level',s.peek(S['LEVEL']),'musique',s.peek(S['MUSSEL']))
B=S['BOARD']
for r in range(16,20):
    for c in range(9): s.mem.ram[B+r*10+c]=1+(r+c)%7
s.mem.ram[S['NEXTP']]=2
random.seed(2)
t=time.time()
for i in range(500):
    if random.random()<0.12: s.key(random.choice([0x08,0x09,0x20,0x0B]))
    s.run_frames(1)
    if i==250: s.screenshot('v2_game1.png')
print('score',bytes(s.mem.ram[S['SCORE']:S['SCORE']+3]).hex(),'lignes',bytes(s.mem.ram[S['LINES']:S['LINES']+2]).hex(),'stats',bytes(s.mem.ram[S['STATS']:S['STATS']+7]).hex(),'%.0fs'%(time.time()-t))
s.screenshot('v2_game2.png')
