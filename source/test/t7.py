from to9sim import TO9, sym
S=sym()
for kw in [dict(timept=False), dict(vsync_ok=False), dict(joystick=False), dict(mon_overhead=250)]:
    s=TO9('../TOETRIS.BIN', **kw)
    s.run_frames(80); s.key(0x0D); s.run_frames(60)
    for i in range(6): s.key(0x08 if i%2 else 0x20); s.run_frames(8)
    s.run_frames(100)
    print(kw, 'FRAME', s.peek(S['FRAME']), 'lent', s.peek(S['SLOWSND']), 'joy', s.peek(S['JOYOK']), 'pièce y', s.peek(S['CURY']), 'stats', bytes(s.mem.ram[S['STATS']:S['STATS']+7]).hex(), 'pc', hex(s.cpu.program_counter.value))
