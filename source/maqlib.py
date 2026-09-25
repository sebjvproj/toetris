# Maquettes TO9 : 160x200, 16 couleurs (niveaux TO9 0-15 par composante), rendu 4:3
from PIL import Image
import math, random
W,H=160,200
LV=[round(255*(v/15)**(1/2.8)) for v in range(16)]
# palette : (R,V,B) en niveaux TO9
PAL=[(0,0,0),     # 0 noir
     (0,0,1),     # 1 bleu nuit
     (1,1,3),     # 2 bleu nuit clair
     (15,15,15),  # 3 blanc
     (15,1,1),    # 4 rouge  (Z)
     (15,6,0),    # 5 orange (L)
     (15,14,0),   # 6 jaune  (O)
     (1,12,1),    # 7 vert   (S)
     (0,12,15),   # 8 cyan   (I)
     (2,3,15),    # 9 bleu   (J)
     (11,1,14),   # 10 violet (T)
     (3,3,5),     # 11 gris-bleu (grille / ombre)
     (15,11,1),   # 12 or (textes, dorures)
     (7,7,10),    # 13 gris clair (neige, cadres)
     (4,0,0),     # 14 bordeaux (ombre des coupoles)
     (0,3,0)]     # 15 vert sombre
RGB=[tuple(LV[c] for c in p) for p in PAL]
class Scr:
    def __init__(s,bg=0): s.p=[[bg]*W for _ in range(H)]
    def px(s,x,y,c):
        if 0<=x<W and 0<=y<H: s.p[y][x]=c
    def rect(s,x,y,w,h,c):
        for j in range(y,y+h):
            for i in range(x,x+w): s.px(i,j,c)
    def frame(s,x,y,w,h,c):
        s.rect(x,y,w,1,c); s.rect(x,y+h-1,w,1,c); s.rect(x,y,1,h,c); s.rect(x+w-1,y,1,h,c)
    def save(s,name):
        im=Image.new('RGB',(W,H)); im.putdata([RGB[c] for row in s.p for c in row])
        im.resize((W*5,H*3),Image.NEAREST).save(name)
        used=set(c for row in s.p for c in row); return len(used)
# police 3x5
F={'A':'010101111101101','B':'110101110101110','C':'011100100100011','D':'110101101101110','E':'111100110100111',
'F':'111100110100100','G':'011100101101011','H':'101101111101101','I':'111010010010111','L':'100100100100111',
'M':'101111111101101','N':'110101101101101','O':'010101101101010','P':'110101110100100','R':'110101110101101',
'S':'011100010001110','T':'111010010010010','U':'101101101101111','V':'101101101101010','X':'101101010101101',
'Y':'101101010010010','0':'111101101101111','1':'010110010010111','2':'110001010100111','3':'110001010001110',
'4':'101101111001001','5':'111100110001110','6':'011100111101111','7':'111001010010010','8':'111101111101111',
'9':'111101111001110',' ':'000000000000000','-':'000000111000000','.':'000000000000010',':':'000010000010000',
'É':'111100110100111','!':'010010010000010','©':'111101101101111','/':'001001010100100'}
def text(s,x,y,t,c,sh=None,vs=2):
    for ch in t:
        g=F.get(ch,F[' '])
        for r in range(5):
            for k in range(3):
                if g[r*3+k]=='1':
                    for d in range(vs):
                        if sh is not None: s.px(x+k+1,y+r*vs+d+1,sh)
                        s.px(x+k,y+r*vs+d,c)
        x+=4
    return x
def textw(t): return len(t)*4-1
# une case de pièce 6x9 : reflet en haut/gauche, ombre en bas/droite
def cell(s,x,y,c,w=6,h=9):
    s.rect(x,y,w,h,c)
    s.rect(x,y,w,1,3); s.rect(x,y,1,h,3)
    s.rect(x,y+h-1,w,1,0); s.rect(x+w-1,y,1,h,0)
    s.px(x+1,y+1,3)
SH={'I':[(0,0),(1,0),(2,0),(3,0)],'O':[(0,0),(1,0),(0,1),(1,1)],'T':[(0,0),(1,0),(2,0),(1,1)],
    'S':[(1,0),(2,0),(0,1),(1,1)],'Z':[(0,0),(1,0),(1,1),(2,1)],'L':[(0,0),(1,0),(2,0),(0,1)],'J':[(0,0),(1,0),(2,0),(2,1)]}
COL={'Z':4,'L':5,'O':6,'S':7,'I':8,'J':9,'T':10}
def sky(s,y0,y1,stars=40,seed=3):
    # dégradé tramé noir -> bleu nuit -> bleu nuit clair
    bay=[[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]]
    for y in range(y0,y1):
        t=(y-y0)/(y1-y0)*2
        for x in range(W):
            lo,hi=(0,1) if t<1 else (1,2); f=t if t<1 else t-1
            s.px(x,y,hi if bay[y%4][x%4]/16<f else lo)
    random.seed(seed)
    for _ in range(stars):
        x,y=random.randrange(W),random.randrange(y0,y0+(y1-y0)*2//3); s.px(x,y,3 if random.random()<.3 else 13)
def dome(s,cx,base,r,c1,c2,shade,drum=4):
    # tambour
    s.rect(cx-r+2,base-drum,2*r-3,drum,13); s.rect(cx-r+2,base-drum,2*r-3,1,3)
    base-=drum
    ry=r*1.7; k=int(ry*1.4)
    for y in range(0,int(ry)+k+1):
        if y<=ry: w=r*math.sqrt(max(0,1-((ry-y)/ry)**2))*1.08
        else: w=r*1.08*(1-(y-ry)/k)**1.8
        for x in range(int(round(cx-w)),int(round(cx+w))+1):
            u=(x-cx)/r
            stripe=int(math.floor(u*2.2+y/ry*1.5))%2
            c=c1 if stripe else c2
            if u>0.45: c=shade
            if u<-0.55 and stripe and y<ry: c=3
            s.px(x,base-y,c)
    top=base-(int(ry)+k)
    s.rect(cx,top-6,1,6,12); s.rect(cx-1,top-4,3,1,12)
def tower(s,x,y,w,h,c=14,win=12):
    s.rect(x,y,w,h,4); s.rect(x+w-2,y,2,h,14)          # brique + ombre
    for j in range(y+2,y+h,9): s.rect(x,j,w,1,13)       # corniches blanches
    for j in range(y+5,y+h-3,18):
        for i in range(x+3,x+w-4,7):
            s.rect(i,j,2,6,0); s.px(i,j,4); s.px(i+1,j,4); s.rect(i,j+1,2,1,1)   # fenêtres cintrées
    s.rect(x,y,w,2,13)
def basil(s,base):
    tower(s,16,base-34,22,34); tower(s,122,base-34,22,34)
    tower(s,40,base-24,20,24); tower(s,100,base-24,20,24)
    tower(s,58,base-56,44,56)
    tower(s,73,base-80,14,24)                     # clocher central
    dome(s,80,base-80,5,7,6,15,3)
    dome(s,27,base-34,9,4,3,14); dome(s,133,base-34,9,9,6,1)
    dome(s,50,base-24,7,6,7,15); dome(s,110,base-24,7,8,3,2)
    dome(s,66,base-56,7,7,3,15); dome(s,94,base-56,7,10,6,14)

