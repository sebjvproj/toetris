from to9sim import TO9, sym
S=sym()
for ovh in (0, 60, 150, 300, 600):
    s=TO9('../TOETRIS.BIN', mon_overhead=ovh)
    s.run_frames(200)
    print('surcoût',ovh,'-> niveau son',s.peek(S['SLOWSND']),'(0=2500 1=2000 2=1667 3=1250 4=coupé) latch',s.tlatch,'FRAME',s.peek(S['FRAME']),'/200 bord',s.border)
s=TO9('../TOETRIS.BIN', timept=False); s.run_frames(200); print('sans TIMEPT -> niveau',s.peek(S['SLOWSND']))
