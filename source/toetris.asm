****************************************************************
*  TOetris  -  jeu de blocs pour Thomson TO9, version "Saint-Basile"
*  Assembleur 6809 (lwasm) - mode 160x200 16 couleurs
*  Règles et rotations de la version Game Boy (1989), graphismes et sons TO9.
*
*  Chargement (BASIC 128) :  RUN"TOETRIS"
****************************************************************

* --- moniteur
PUTC    EQU     $E803
GETC    EQU     $E806
STATUS  EQU     $6019           ; bit5 = appel de TIMEPT à chaque IRQ timer
TIMEPT  EQU     $6027           ; routine utilisateur de l'IRQ timer (appelée par JMP)
IRQEXIT EQU     $E830           ; retour au moniteur à la fin de cette routine

* --- matériel
PCR     EQU     $E7C1           ; 6846 : bit3 = buzzer (CP2)
PRC     EQU     $E7C3           ; 6846 : bit0 = banque RAMA(1)/RAMB(0)
TCR     EQU     $E7C5           ; 6846 : contrôle du timer
TMSB    EQU     $E7C6           ; 6846 : latch du timer (16 bits)
KTEST   EQU     $E7C8           ; PIA système : bit0 = touche enfoncée
JOYDIR  EQU     $E7CC           ; PIA jeux : directions (0 = appuyé)
JOYBTN  EQU     $E7CD           ; PIA jeux : bits0-5 = CNA, bit6 = bouton 1
JOYCRA  EQU     $E7CE
JOYCRB  EQU     $E7CF
PALDAT  EQU     $E7DA
PALIDX  EQU     $E7DB
VMODE   EQU     $E7DC
BORDER  EQU     $E7DD
GATE7   EQU     $E7E7           ; bit7 = 1 pendant les lignes affichées

NROWS   EQU     20

* actions clavier
ACT_L   EQU     1
ACT_R   EQU     2
ACT_DN  EQU     3
ACT_UP  EQU     4
ACT_CW  EQU     5
ACT_CCW EQU     6
ACT_ST  EQU     7
ACT_MUS EQU     8
ACT_GH  EQU     9
ACT_PX  EQU     10

* cases
T_EMPTY EQU     0
T_GHOST EQU     8               ; + id pièce (0..6)
T_FLASH EQU     15
T_GREY  EQU     16

        ORG     $A000
****************************************************************
START   BRA     START1
SNDENABLE FCB   1               ; 0 = version sans son (TOETRIS0), voir build.sh
START1  LDB     #$14            ; curseur invisible
        JSR     PUTC
        JSR     INITVARS
        LDA     #8              ; correspondance palette TO9 (voir SETPAL)
        STA     PALX
        LDA     #$7B            ; bitmap 16 couleurs
        STA     VMODE
        LDA     #16
        STA     FADEK
        JSR     SETPAL          ; tout noir le temps d'effacer
        JSR     CLS
        CLR     FADEK
        JSR     SETPAL
        LDA     #9              ; tour bleu : démarrage
        STA     BORDER
        JSR     INITJOY

****************************************************************
* Écran titre + menu
****************************************************************
TITLE   JSR     BLACKOUT
        LDX     #LZ_TITLE_A
        LDY     #LZ_TITLE_B
        JSR     SHOWSCR
        JSR     DRAWMENU
        JSR     FADEIN
        TST     SNDREADY        ; 1re fois : initialisation du son
        BNE     TI1
        INC     SNDREADY
        LDA     #4              ; tour rouge : son en cours d'initialisation
        STA     BORDER
        TST     SNDENABLE
        BEQ     TI0
        JSR     SNDINIT
TI0     CLR     BORDER
TI1     JSR     MUSSTART
MN_LOOP JSR     WAITVBL
        JSR     INPUT
        LDA     IN_UP
        BEQ     MN1
        LDA     MSEL
        BEQ     MN1
        DEC     MSEL
        JSR     MENUBEEP
MN1     LDA     IN_DN
        BEQ     MN2
        LDA     MSEL
        CMPA    #2
        BEQ     MN2
        INC     MSEL
        JSR     MENUBEEP
MN2     LDA     IN_L
        BEQ     MN3
        LDA     #-1
        JSR     MENUCHG
MN3     LDA     IN_R
        BEQ     MN4
        LDA     #1
        JSR     MENUCHG
MN4     LDA     IN_UP
        ORA     IN_DN
        ORA     IN_L
        ORA     IN_R
        BEQ     MN5
        JSR     DRAWMENUL
MN5     LDA     IN_START
        ORA     IN_CW
        BEQ     MN_LOOP
        JMP     NEWGAME

MENUBEEP
        LDX     #SFX_MENU
        LDA     #SP_MENU
        JMP     PLAYSFX

* A = +1 / -1 sur la ligne MSEL
MENUCHG STA     TMPA
        JSR     MENUBEEP
        LDB     MSEL
        BNE     MC1
        LDA     STARTLV         ; niveau 0..9
        ADDA    TMPA
        CMPA    #10
        BHS     MC9
        STA     STARTLV
        RTS
MC1     CMPB    #1
        BNE     MC2
        LDA     MUSSEL          ; musique 0..NSONGS (NSONGS = aucune)
        ADDA    TMPA
        CMPA    #NSONGS+1
        BHS     MC9
        STA     MUSSEL
        JMP     MUSSTART
MC2     LDA     SNDMODE         ; sortie 0..1
        EORA    #1
        STA     SNDMODE
        JMP     SETSNDOUT
MC9     RTS

* cadre du menu + toutes les lignes
DRAWMENU
        LDA     #10
        LDB     #60
        STB     TMPB
        LDB     #84
        STB     FY
        LDB     #68
        STB     FH
        CLR     FV
        LDB     TMPB
        JSR     FILLP
        LDB     #1
        STB     FH
        LDB     #$CC
        STB     FV
        LDB     TMPB
        JSR     FILLP           ; haut
        LDB     #151
        STB     FY
        LDB     TMPB
        JSR     FILLP           ; bas
        LDB     #84
        STB     FY
        LDB     #68
        STB     FH
        LDB     #$C0
        STB     FV
        LDA     #10
        LDB     #1
        JSR     FILLP           ; gauche
        LDB     #$0C
        STB     FV
        LDA     #69
        LDB     #1
        JSR     FILLP           ; droite
        LDX     #S_REC
        LDA     #13
        LDB     #136
        JSR     MTEXT
        LDA     #3
        STA     TFG
        LDA     #39
        STA     TXP
        LDA     #136
        STA     TXY
        LDX     #TOPSC
        LDB     #3
        JSR     SHOWBCD
* les trois lignes réglables
DRAWMENUL
        LDX     #S_NIV
        LDA     #13
        LDB     #92
        CLR     TMPC            ; ligne 0
        JSR     MLABEL
        LDA     STARTLV
        INCA
        STA     MTMP
        LDA     #$FF
        STA     MTMP+1
        LDX     #MTMP
        LDA     #39
        LDB     #92
        JSR     MTEXT
        LDX     #S_MUS
        LDA     #13
        LDB     #106
        INC     TMPC
        JSR     MLABEL
        LDX     #S_M0
        LDA     MUSSEL
        LDB     #MNAMEW
        MUL
        LEAX    D,X
        LDA     #39
        LDB     #106
        JSR     MTEXT
        LDX     #S_OUT
        LDA     #13
        LDB     #120
        INC     TMPC
        JSR     MLABEL
        LDX     #S_O0
        LDA     SNDMODE
        LDB     #7
        MUL
        LEAX    D,X
        LDA     #39
        LDB     #120
        JMP     MTEXT

* étiquette de menu : dorée si c'est la ligne choisie
MLABEL  PSHS    A
        LDA     #3
        STA     TFG
        LDA     TMPC
        CMPA    MSEL
        BNE     ML1
        LDA     #12
        STA     TFG
ML1     PULS    A
        BRA     MTEXT1
* texte du menu (blanc sur noir) : X=chaîne, A=paire, B=ligne
MTEXT   PSHS    A
        LDA     #3
        STA     TFG
        PULS    A
MTEXT1  STA     TXP
        STB     TXY
        CLR     TBG
        LDA     #2
        STA     TVS
        JMP     DRAWSTR

****************************************************************
* Partie
****************************************************************
NEWGAME JSR     BLACKOUT
        LDX     #LZ_GAME_A
        LDY     #LZ_GAME_B
        JSR     SHOWSCR
        LDX     #BOARD          ; BOARD, SCR, OVL se suivent
NG1     CLR     ,X+
        CMPX    #OVL+200
        BNE     NG1
        LDX     #STATS
        LDB     #7
NG2     CLR     ,X+
        DECB
        BNE     NG2
        CLR     SCORE
        CLR     SCORE+1
        CLR     SCORE+2
        CLR     LINES
        CLR     LINES+1
        CLR     LINESB
        CLR     LINESB+1
        LDA     STARTLV
        STA     LEVEL
        JSR     SHOWSTATS
        CLRA
NG3     JSR     SHOWSTAT        ; les 7 compteurs à 00
        INCA
        CMPA    #7
        BNE     NG3
        JSR     FADEIN
        JSR     RNDPIECE
        STA     NEXTP
        CLR     PCVIS
        JSR     SPAWN
        LBCS    GAMEOVER

GLOOP   JSR     WAITVBL
        JSR     INPUT
        TST     IN_START
        BEQ     GL0
        JSR     PAUSE
GL0     TST     IN_MUS          ; M : coupe / remet la musique
        BEQ     GL0A
        JSR     MUSTOGGLE
GL0A    TST     IN_GH           ; G : pièce fantôme
        BEQ     GL0B
        LDA     GHOSTON
        EORA    #1
        STA     GHOSTON
        JSR     CURTOT
        JSR     MOVEPC
GL0B    LDA     IN_CW
        ORA     IN_UP
        BEQ     GL1
        JSR     CURTOT
        LDA     TR
        INCA
        ANDA    #3
        STA     TR
        JSR     TRYROT
GL1     TST     IN_CCW
        BEQ     GL2
        JSR     CURTOT
        LDA     TR
        DECA
        ANDA    #3
        STA     TR
        JSR     TRYROT
GL2     TST     IN_L
        BEQ     GL3
        JSR     CURTOT
        DEC     TX
        JSR     TRYSHIFT
GL3     TST     IN_R
        BEQ     GL4
        JSR     CURTOT
        INC     TX
        JSR     TRYSHIFT
GL4     TST     HOLDDN
        BNE     GL4A
        CLR     SDBLOCK
        BRA     GL5
GL4A    TST     SDBLOCK
        BNE     GL5
        LDA     SDCNT
        BEQ     GL4B
        DEC     SDCNT
        BRA     GL5
GL4B    LDA     #2
        STA     SDCNT
        JSR     DROP
        BCS     GLLOCK
        INC     SDROWS
        JSR     SETGRAV
        LBRA    GLOOP
GL5     DEC     GRAVCNT
        LBNE    GLOOP
        JSR     SETGRAV
        JSR     DROP
        LBCC    GLOOP
GLLOCK  JSR     LOCK
        LDB     #2
        JSR     WAITN
        JSR     SPAWN
        LBCC    GLOOP
        JMP     GAMEOVER

TRYROT  JSR     FITS
        BCS     TRR9
        JSR     MOVEPC
        LDX     #SFX_ROT
        LDA     #SP_ROT
        JSR     PLAYSFX
TRR9    RTS

TRYSHIFT
        JSR     FITS
        BCS     TRS9
        JSR     MOVEPC
        LDX     #SFX_MOVE
        LDA     #SP_MOVE
        JSR     PLAYSFX
TRS9    RTS

SPAWN   LDA     NEXTP
        STA     CURP
        JSR     RNDPIECE
        STA     NEXTP
        JSR     DRAWNEXT
        LDX     #STATS          ; statistiques
        LDB     CURP
        LDA     B,X
        CMPA    #$99
        BEQ     SPS1
        ADDA    #1
        DAA
        STA     B,X
SPS1    LDA     CURP
        JSR     SHOWSTAT
        LDA     CURP
        STA     TP
        CLR     TR
        CLR     TY
        LDA     #4
        STA     TX
        CLR     PCVIS
        JSR     FITS
        BCS     SPF
        JSR     MOVEPC
        JSR     SETGRAV
        CLR     SDROWS
        LDA     #1
        STA     SDBLOCK
        CLR     SDCNT
        ANDCC   #$FE
SPF     RTS

SETGRAV PSHS    B,X
        LDB     LEVEL
        CMPB    #20
        BLS     SG1
        LDB     #20
SG1     LDX     #GRAVTAB
        LDA     B,X
        STA     GRAVCNT
        PULS    B,X,PC

RNDPIECE
        PSHS    B
        LDB     #3
        STB     RTRY
RP1     JSR     RANDOM
        JSR     RANDOM
        JSR     RANDOM
        LDA     RNDSEED+1
        ANDA    #7
        CMPA    #7
        BEQ     RP1
        CMPA    NEXTP
        BNE     RP2
        DEC     RTRY
        BNE     RP1
RP2     PULS    B,PC

DROP    JSR     CURTOT
        INC     TY
        JSR     FITS
        BCS     DR9
        JSR     MOVEPC
        ANDCC   #$FE
DR9     RTS

CURTOT  PSHS    D
        LDD     CURP
        STD     TP
        LDD     CURY
        STD     TY
        PULS    D,PC

SWAPT   PSHS    D,X
        LDD     TP
        LDX     CURP
        STD     CURP
        STX     TP
        LDD     TY
        LDX     CURY
        STD     CURY
        STX     TY
        PULS    D,X,PC

* 4 cases de la pièce T* -> tampon U (ligne, colonne, tuile)
GETCELLS
        PSHS    D,X,U
        LDA     TP
        LDB     #4
        MUL
        ADDB    TR
        LDA     #12
        MUL
        LDX     #PIECES
        LEAX    D,X
        LDA     #4
        STA     GCCNT
GC1     LDA     ,X+
        ADDA    TY
        STA     ,U+
        LDA     ,X+
        ADDA    TX
        STA     ,U+
        LDA     ,X+
        STA     ,U+
        DEC     GCCNT
        BNE     GC1
        PULS    D,X,U,PC

* C=1 si la pièce T* ne tient pas
FITS    PSHS    D,X,U
        LDU     #CBUF
        JSR     GETCELLS
        LDA     #4
        STA     FTCNT
FT1     LDA     ,U
        LDB     1,U
        CMPB    #10
        BHS     FTBAD
        TSTA
        BMI     FT2
        CMPA    #NROWS
        BHS     FTBAD
        JSR     BOARDADR
        TST     ,X
        BNE     FTBAD
FT2     LEAU    3,U
        DEC     FTCNT
        BNE     FT1
        ANDCC   #$FE
        PULS    D,X,U,PC
FTBAD   ORCC    #1
        PULS    D,X,U,PC

* décalage vertical de la pièce fantôme pour les cases NBUF -> GOFF
GHOSTOFF
        PSHS    D,X,Y,U
        CLR     GOFF
        TST     GHOSTON
        BEQ     GO9
        LDU     #NBUF           ; pointeurs plateau de chaque case (ligne >= -2)
        LDX     #GPTR
        LDY     #GROW
        LDA     #4
        STA     GOCNT
GP1     LDA     ,U
        STA     ,Y+
        ADDA    #2
        LDB     #10
        MUL
        ADDB    1,U
        ADCA    #0
        ADDD    #BOARD-20
        STD     ,X++
        LEAU    3,U
        DEC     GOCNT
        BNE     GP1
GO1     LDX     #GPTR
        LDU     #GROW
        LDB     #4
GO2     LDY     ,X
        LEAY    10,Y
        STY     ,X++
        LDA     ,U
        INCA
        STA     ,U+
        BMI     GO3
        CMPA    #NROWS
        BHS     GO9
        TST     ,Y
        BNE     GO9
GO3     DECB
        BNE     GO2
        INC     GOFF
        BRA     GO1
GO9     PULS    D,X,Y,U,PC

* affiche la pièce en T* (et son fantôme) : on met à jour la couche OVL
* puis on ne redessine que les cases dont le contenu affiché (SCR) change
MOVEPC  PSHS    D,X,Y,U
        LDU     #NBUF
        JSR     GETCELLS
        JSR     GHOSTOFF
        LDX     #NBUF           ; NGBUF = NBUF décalé de GOFF lignes
        LDU     #NGBUF
        LDB     #4
MV1     LDA     ,X+
        ADDA    GOFF
        STA     ,U+
        LDA     ,X+
        STA     ,U+
        LDA     ,X+
        ADDA    #T_GHOST-1
        STA     ,U+
        DECB
        BNE     MV1
        TST     PCVIS
        BEQ     MV3
        JSR     SWAPT           ; anciennes cases : pièce + fantôme
        LDU     #OBUF
        JSR     GETCELLS
        JSR     SWAPT
        LDX     #OBUF
        LDU     #OGBUF
        LDB     #4
MV2     LDA     ,X+
        ADDA    OLDGOFF
        STA     ,U+
        LDA     ,X+
        STA     ,U+
        LDA     ,X+
        STA     ,U+
        DECB
        BNE     MV2
        LDU     #OBUF           ; retire l'ancienne pièce de la couche
        LDA     #8
        CLRB
        JSR     SETOVL
MV3     LDU     #NGBUF          ; fantôme puis pièce (la pièce gagne)
        LDA     #4
        LDB     #1
        JSR     SETOVL
        LDU     #NBUF
        LDA     #4
        JSR     SETOVL
        TST     PCVIS
        BEQ     MV4
        LDU     #OBUF
        LDA     #8
        JSR     REFRESH
MV4     LDU     #NBUF
        LDA     #8
        JSR     REFRESH
        LDD     TP
        STD     CURP
        LDD     TY
        STD     CURY
        LDA     GOFF
        STA     OLDGOFF
        LDA     #1
        STA     PCVIS
        PULS    D,X,Y,U,PC

* A cases du tampon U dans OVL : B=0 efface, sinon met la tuile de la case
SETOVL  PSHS    D,X,U
        STA     OVCNT
        STB     OVMODE
SO1     LDA     ,U
        BMI     SO2
        LDB     1,U
        JSR     CIDX
        LDX     #OVL
        ABX
        CLRA
        TST     OVMODE
        BEQ     SO1A
        LDA     2,U
SO1A    STA     ,X
SO2     LEAU    3,U
        DEC     OVCNT
        BNE     SO1
        PULS    D,X,U,PC

* redessine les A cases du tampon U si leur contenu affiché change
REFRESH PSHS    D,X,U
        STA     OVCNT
RF1     LDA     ,U
        BMI     RFN
        LDB     1,U
        JSR     CIDX
        LDX     #OVL
        ABX
        LDA     ,X
        BNE     RF2
        LDX     #BOARD
        ABX
        LDA     ,X
RF2     LDX     #SCR
        ABX
        CMPA    ,X
        BEQ     RFN
        PSHS    A
        LDA     ,U
        STA     PROW
        LDB     1,U
        PULS    A
        JSR     PUTCELL
RFN     LEAU    3,U
        DEC     OVCNT
        BNE     RF1
        PULS    D,X,U,PC

* A=ligne (0..19), B=col -> B = ligne*10+col (A préservé)
CIDX    PSHS    A,X
        LDX     #ROW10
        LDA     A,X
        PSHS    B
        ADDA    ,S+
        TFR     A,B
        PULS    A,X,PC
ROW10   FCB     0,10,20,30,40,50,60,70,80,90,100,110,120,130,140,150,160,170,180,190

LOCK    JSR     CURTOT
        LDU     #CBUF
        JSR     GETCELLS
        LDA     #4
        STA     LKCNT
LK1     LDA     ,U
        BMI     LK2
        LDB     1,U
        JSR     BOARDADR
        LDA     2,U
        STA     ,X
LK2     LEAU    3,U
        DEC     LKCNT
        BNE     LK1
        CLR     PCVIS
        LDX     #OVL
        LDB     #200
LK2B    CLR     ,X+
        DECB
        BNE     LK2B
        LDB     SDROWS
        BEQ     LK3
        LDX     #BCD1
LKS     JSR     ADDBCD
        DECB
        BNE     LKS
LK3     JSR     CHECKLINES
        LDA     NFULL
        BNE     LK4
        LDX     #SFX_LOCK
        LDA     #SP_LOCK
        JSR     PLAYSFX
        BRA     LKEND
LK4     LDX     #SFX_LINE
        LDA     #SP_LINE
        LDB     NFULL
        CMPB    #4
        BNE     LK5
        LDX     #SFX_QUAD
        LDA     #SP_QUAD
LK5     JSR     PLAYSFX
        JSR     FLASHLINES
        JSR     COLLAPSE
        JSR     DRAWDIFF
        LDA     NFULL
        DECA
        LDB     #3
        MUL
        LDX     #LPTS
        ABX
        LDB     LEVEL
        INCB
LKP     JSR     ADDBCD
        DECB
        BNE     LKP
        LDB     NFULL
LKL     LDA     LINES+1
        ADDA    #1
        DAA
        STA     LINES+1
        LDA     LINES
        ADCA    #0
        DAA
        STA     LINES
        LDX     LINESB
        LEAX    1,X
        STX     LINESB
        DECB
        BNE     LKL
        LDA     LEVEL
        STA     TMPA
        JSR     CALCLEVEL
        LDA     LEVEL
        CMPA    TMPA
        BEQ     LKEND
        LDX     #SFX_LEVEL
        LDA     #SP_LEVEL
        JSR     PLAYSFX
LKEND   JMP     SHOWSTATS

ADDBCD  PSHS    A
        LDA     SCORE+2
        ADDA    2,X
        DAA
        STA     SCORE+2
        LDA     SCORE+1
        ADCA    1,X
        DAA
        STA     SCORE+1
        LDA     SCORE
        ADCA    ,X
        DAA
        STA     SCORE
        BCC     AB1
        LDA     #$99
        STA     SCORE
        STA     SCORE+1
        STA     SCORE+2
AB1     PULS    A,PC

CALCLEVEL
        LDD     LINESB
        CLR     TMPL
CL1     SUBD    #10
        BLO     CL2
        INC     TMPL
        BRA     CL1
CL2     LDA     TMPL
        CMPA    #20
        BLS     CL3
        LDA     #20
CL3     CMPA    LEVEL
        BLS     CL4
        STA     LEVEL
CL4     RTS

CHECKLINES
        CLR     NFULL
        LDX     #BOARD
        LDY     #ROWFLG
        LDA     #NROWS
        STA     CKCNT
CK1     CLR     ,Y
        LDB     #10
CK2     TST     ,X+
        BEQ     CK3
        DECB
        BNE     CK2
        INC     ,Y
        INC     NFULL
        BRA     CK4
CK3     DECB
        ABX
CK4     LEAY    1,Y
        DEC     CKCNT
        BNE     CK1
        RTS

FLASHLINES
        LDA     #7
        STA     FLCNT
FL1     CLR     PROW
FL2     LDX     #ROWFLG
        LDB     PROW
        TST     B,X
        BEQ     FL4
        CLRB
FL3     LDA     PROW
        JSR     BOARDADR
        LDA     ,X
        PSHS    B
        LDB     FLCNT
        ANDB    #1
        PULS    B
        BEQ     FL3A
        LDA     #T_FLASH
FL3A    JSR     PUTCELL
        INCB
        CMPB    #10
        BNE     FL3
FL4     INC     PROW
        LDA     PROW
        CMPA    #NROWS
        BNE     FL2
        LDB     #4
        JSR     WAITN
        DEC     FLCNT
        BNE     FL1
        RTS

COLLAPSE
        LDA     #NROWS-1
        STA     DSTR
        STA     SRCR
CO1     LDB     SRCR
        LDX     #ROWFLG
        TST     B,X
        BNE     CO3
        LDA     SRCR
        CMPA    DSTR
        BEQ     CO2
        CLRB
        JSR     BOARDADR
        TFR     X,Y
        LDA     DSTR
        JSR     BOARDADR
        LDB     #10
COC     LDA     ,Y+
        STA     ,X+
        DECB
        BNE     COC
CO2     DEC     DSTR
CO3     DEC     SRCR
        BPL     CO1
CO4     LDA     DSTR
        BMI     CO5
        CLRB
        JSR     BOARDADR
        LDB     #10
COZ     CLR     ,X+
        DECB
        BNE     COZ
        DEC     DSTR
        BRA     CO4
CO5     RTS

DRAWFIELD
        PSHS    D
        CLRA
DF1     CLRB
DF2     JSR     DRAWBC
        INCB
        CMPB    #10
        BNE     DF2
        INCA
        CMPA    #NROWS
        BNE     DF1
        PULS    D,PC

* redessine seulement les cases dont l'affichage (SCR) diffère du plateau
* (ne convient pas si l'écran a été modifié sans SCR : boîte de pause)
DRAWDIFF
        PSHS    D,X,U
        CLR     PROW
        LDX     #BOARD
        LDU     #SCR
DD1     CLRB
DD2     LDA     ,X+
        CMPA    ,U+
        BEQ     DD3
        JSR     PUTCELL
DD3     INCB
        CMPB    #10
        BNE     DD2
        INC     PROW
        LDA     PROW
        CMPA    #NROWS
        BNE     DD1
        PULS    D,X,U,PC

* score / lignes / niveau
SHOWSTATS
        LDA     #3
        STA     TFG
        LDA     #1
        STA     TBG
        LDA     #2
        STA     TVS
        LDA     #7
        STA     TXP
        LDA     #27
        STA     TXY
        LDX     #SCORE
        LDB     #3
        JSR     SHOWBCD
        LDA     #9
        STA     TXP
        LDA     #63
        STA     TXY
        LDX     #LINES
        LDB     #2
        JSR     SHOWBCDN
        LDA     LEVEL
        JSR     BIN2BCD
        STA     TMPB
        LDA     #11
        STA     TXP
        LDA     #99
        STA     TXY
        LDX     #TMPB
        LDB     #1
        JMP     SHOWBCD

* compteur de la pièce A dans le panneau STATS
SHOWSTAT
        PSHS    D,X
        LDX     #STATROW
        LDB     A,X
        LDA     #8
        MUL
        ADDB    #STATY
        STB     TXY
        LDA     #STATX/2
        STA     TXP
        LDA     #13
        STA     TFG
        LDA     #1
        STA     TBG
        STA     TVS
        LDX     #STATS
        LDA     ,S
        LEAX    A,X
        LDB     #1
        JSR     SHOWBCDZ
        PULS    D,X,PC

BIN2BCD PSHS    B
        CLRB
BB1     CMPA    #10
        BLO     BB2
        SUBA    #10
        ADDB    #$10
        BRA     BB1
BB2     PSHS    B
        ADDA    ,S+
        PULS    B,PC

* nombres BCD : X=adresse, B=nb d'octets, TXP/TXY/TFG/TBG/TVS
* SHOWBCD  : zéros de tête remplacés par des blancs
* SHOWBCDN : idem mais sur 3 chiffres (lignes : on saute le 1er chiffre)
* SHOWBCDZ : tous les chiffres
SHOWBCDZ
        LDA     #1
        STA     SBLEAD
        BRA     SBC0
SHOWBCDN
        CLR     SBLEAD
        LDA     #1
        STA     SBSKIP
        BRA     SBC1
SHOWBCD CLR     SBLEAD
SBC0    CLR     SBSKIP
SBC1    PSHS    D,X
        STB     SBCNT
        ASLB
        STB     SBND
        JSR     GLUT
SB1     LDA     ,X
        LSRA
        LSRA
        LSRA
        LSRA
        BSR     SBDIG
        LDA     ,X+
        ANDA    #$0F
        BSR     SBDIG
        DEC     SBCNT
        BNE     SB1
        PULS    D,X,PC
SBDIG   DEC     SBND
        TST     SBSKIP
        BEQ     SBD0
        CLR     SBSKIP
        RTS
SBD0    TST     SBLEAD
        BNE     SBD2
        TSTA
        BNE     SBD1
        TST     SBND
        BEQ     SBD2
        CLRA                    ; blanc
        BRA     SBD3
SBD1    INC     SBLEAD
SBD2    INCA                    ; glyphe du chiffre = chiffre + 1
SBD3    JSR     DRAWGLYPH
        INC     TXP
        INC     TXP
        RTS

DRAWNEXT
        PSHS    D,X,U
        LDD     TP
        PSHS    D
        LDD     TY
        PSHS    D
        LDA     #58             ; efface l'intérieur du cadre
        LDB     #24
        STB     FY
        LDB     #28
        STB     FH
        LDB     #$11
        STB     FV
        LDB     #19
        JSR     FILLP
        LDA     NEXTP
        STA     TP
        CLR     TR
        CLR     TY
        LDA     #1
        STA     TX
        LDU     #CBUF
        JSR     GETCELLS
        LDA     #4
        STA     DNCNT
DN3     LDA     ,U              ; y = NY + 9*ligne
        LDB     #9
        MUL
        ADDB    #NY
        STB     CY
        LDA     1,U             ; paire = NX/2 + 3*col
        LDB     #3
        MUL
        ADDB    #NX/2
        STB     CP
        LDA     2,U
        JSR     DRAWTILE
        LEAU    3,U
        DEC     DNCNT
        BNE     DN3
        PULS    D
        STD     TY
        PULS    D
        STD     TP
        PULS    D,X,U,PC

* boîte de texte dans le puits : X = chaîne 1, Y = chaîne 2
FIELDBOX
        PSHS    X,Y
        LDA     #27
        LDB     #72
        STB     FY
        LDB     #44
        STB     FH
        CLR     FV
        LDB     #26
        JSR     FILLP
        LDB     #1
        STB     FH
        LDB     #$CC
        STB     FV
        LDA     #27
        LDB     #26
        JSR     FILLP
        LDB     #115
        STB     FY
        LDA     #27
        LDB     #26
        JSR     FILLP
        LDB     #72
        STB     FY
        LDB     #44
        STB     FH
        LDB     #$C0
        STB     FV
        LDA     #27
        LDB     #1
        JSR     FILLP
        LDB     #$0C
        STB     FV
        LDA     #52
        LDB     #1
        JSR     FILLP
        LDA     #12
        STA     TFG
        CLR     TBG
        LDA     #2
        STA     TVS
        PULS    X
        JSR     CENTER
        LDA     #80
        STA     TXY
        JSR     DRAWSTR
        PULS    X
        CMPX    #0
        BEQ     FB9
        LDA     #3
        STA     TFG
        JSR     CENTER
        LDA     #98
        STA     TXY
        JSR     DRAWSTR
FB9     RTS
* centre la chaîne X dans le puits -> TXP
CENTER  PSHS    X
        CLRB
CE1     LDA     ,X+
        CMPA    #$FF
        BEQ     CE2
        INCB
        BRA     CE1
CE2     ASLB                    ; 2 paires par caractère
        NEGB
        ADDB    #30             ; 30 paires dans le puits
        LSRB
        ADDB    #PX/2
        STB     TXP
        PULS    X,PC

PAUSE   CLR     MUSON
        JSR     SNDSILENCE
        CLRA
PA0     CLRB
PA0B    STA     PROW
        PSHS    A
        LDA     #T_EMPTY
        JSR     PUTCELL
        PULS    A
        INCB
        CMPB    #10
        BNE     PA0B
        INCA
        CMPA    #NROWS
        BNE     PA0
        LDX     #S_PAUSE
        LDY     #S_ENTER
        JSR     FIELDBOX
PA1     JSR     WAITVBL
        JSR     INPUT
        TST     IN_START
        BEQ     PA1
        JSR     DRAWFIELD
        CLR     PCVIS
        JSR     CURTOT
        JSR     MOVEPC
        LDA     MUSSEL
        CMPA    #NSONGS
        BEQ     PA9
        LDA     MUSWANT
        STA     MUSON
PA9     RTS

GAMEOVER
        CLR     MUSON
        JSR     SNDSILENCE
        LDX     #SFX_OVER
        LDA     #SP_OVER
        JSR     PLAYSFX
        CLR     GOROW
GO_1    LDA     GOROW
        STA     PROW
        CLRB
GO_2    LDA     #T_GREY
        JSR     PUTCELL
        INCB
        CMPB    #10
        BNE     GO_2
        LDB     #2
        JSR     WAITN
        INC     GOROW
        LDA     GOROW
        CMPA    #NROWS
        BNE     GO_1
        LDB     #30
        JSR     WAITN
        LDX     #S_GAME
        LDY     #S_OVER
        JSR     FIELDBOX
        JSR     INSERTTOP
        LDB     #25
        JSR     WAITN
GO_3    JSR     WAITVBL
        JSR     INPUT
        LDA     IN_START
        ORA     IN_CW
        BEQ     GO_3
        JMP     TITLE

INSERTTOP
        LDA     SCORE
        ORA     SCORE+1
        ORA     SCORE+2
        BEQ     IT9
        LDX     #TOPSC
        JSR     CMP3
        BLS     IT9
        LDA     SCORE
        STA     ,X
        LDA     SCORE+1
        STA     1,X
        LDA     SCORE+2
        STA     2,X
IT9     RTS
CMP3    LDA     SCORE
        CMPA    ,X
        BNE     CM9
        LDA     SCORE+1
        CMPA    1,X
        BNE     CM9
        LDA     SCORE+2
        CMPA    2,X
CM9     RTS

****************************************************************
* Entrées
****************************************************************
INPUT   PSHS    D,X,Y,U
        CLR     IN_L
        CLR     IN_R
        CLR     IN_CW
        CLR     IN_CCW
        CLR     IN_UP
        CLR     IN_DN
        CLR     IN_START
        CLR     IN_MUS
        CLR     IN_GH
        LDA     KTEST
        BITA    #1
        BNE     IPK1
        CLR     LASTACT
IPK1    LDA     KEYAGE
        CMPA    #60
        BHS     IPK2
        INC     KEYAGE
        BRA     IPK3
IPK2    CLR     LASTACT
IPK3    JSR     GETC
        TSTB
        LBEQ    IPHELD
        JSR     KEYACT
        TSTA
        LBEQ    IPHELD
        CLR     KEYAGE
        CMPA    LASTACT
        LBEQ    IPHELD
        STA     LASTACT
        LDB     #20
        STB     KDAS
        LDX     #INFLAGS-1      ; action n -> drapeau n
        CMPA    #ACT_PX
        BEQ     IPPX
        LEAX    A,X
        INC     ,X
        BRA     IPHELD
IPPX    LDA     PALX            ; C : autre correspondance de palette
        EORA    #8
        STA     PALX
        JSR     SETPAL
IPHELD  LDA     LASTACT
        CMPA    #ACT_L
        BEQ     IPH2
        CMPA    #ACT_R
        BNE     IPJ
IPH2    DEC     KDAS
        BNE     IPJ
        LDB     #8
        STB     KDAS
        CMPA    #ACT_L
        BNE     IPH3
        INC     IN_L
        BRA     IPJ
IPH3    INC     IN_R
IPJ     TST     JOYOK
        BEQ     IPH
        LDA     JOYDIR
        COMA
        ANDA    #$0F
        TFR     A,B
        ANDB    #$03
        CMPB    #$03
        BEQ     IPJBAD
        TFR     A,B
        ANDB    #$0C
        CMPB    #$0C
        BEQ     IPJBAD
        LDB     JOYBTN
        BITB    #$40
        BNE     IPJ2
        ORA     #$10
        BRA     IPJ2
IPJBAD  CLRA
IPJ2    STA     JCUR
        LDB     JPREV
        COMB
        ANDB    JCUR
        STB     JNEW
        STA     JPREV
        BITB    #$01
        BEQ     IPJ3
        INC     IN_UP
IPJ3    BITB    #$02
        BEQ     IPJ4
        INC     IN_DN
IPJ4    BITB    #$10
        BEQ     IPJ5
        INC     IN_CW
IPJ5    ANDA    #$0C
        BEQ     IPH
        BITB    #$0C
        BEQ     IPJ6
        LDB     #20
        STB     DASCNT
        BRA     IPJ7
IPJ6    DEC     DASCNT
        BNE     IPH
        LDB     #8
        STB     DASCNT
IPJ7    BITA    #$04
        BEQ     IPJ8
        INC     IN_L
        BRA     IPH
IPJ8    INC     IN_R
IPH     CLR     HOLDDN
        LDA     LASTACT
        CMPA    #ACT_DN
        BEQ     IPH1
        TST     JOYOK
        BEQ     IPX
        LDA     JCUR
        BITA    #$02
        BEQ     IPX
IPH1    INC     HOLDDN
IPX     PULS    D,X,Y,U,PC

* B = code clavier -> A = action
KEYACT  LDX     #KEYTAB
KA1     LDA     ,X++
        BEQ     KA9
        CMPB    -2,X
        BNE     KA1
        LDA     -1,X
        RTS
KA9     CLRA
        RTS
KEYTAB  FCB     $08,ACT_L,$09,ACT_R,$0A,ACT_DN,$0B,ACT_UP,$0D,ACT_ST,$20,ACT_CW
        FCB     'A,ACT_CW,'a,ACT_CW,'Z,ACT_CCW,'z,ACT_CCW,'W,ACT_CCW,'w,ACT_CCW
        FCB     'X,ACT_CCW,'x,ACT_CCW,'Q,ACT_L,'q,ACT_L,'D,ACT_R,'d,ACT_R
        FCB     'S,ACT_DN,'s,ACT_DN,'M,ACT_MUS,'m,ACT_MUS,'G,ACT_GH,'g,ACT_GH
        FCB     'C,ACT_PX,'c,ACT_PX,0

INITJOY CLR     JOYOK
        LDA     JOYCRA
        ORA     #$04
        STA     JOYCRA
        LDB     JOYCRA
        ANDA    #$3F
        ANDB    #$3F
        PSHS    A
        CMPB    ,S+
        BNE     IJ9
        LDA     #1
        STA     JOYOK
IJ9     LDA     JOYCRB          ; port B : bits 0-5 en sortie (CNA)
        ANDA    #$FB
        STA     JOYCRB
        LDA     #$3F
        STA     JOYBTN
        LDA     JOYCRB
        ORA     #$04
        STA     JOYCRB
        CLR     JOYBTN
        RTS

****************************************************************
* Son : IRQ timer du 6846 -> 2 voix carrées sur le CNA 6 bits
****************************************************************
* le son démarre à 200 Hz, on mesure le coût d'une IRQ, puis on choisit :
* 2500 Hz, 1667 Hz, 1250 Hz ou pas de son, pour garder >= ~50 % du processeur
SNDINIT PSHS    CC
        ORCC    #$50
        CLR     MUSON
        CLR     VOL1
        CLR     VOL2
        JSR     SETSNDOUT
        LDA     #50
        STA     SNDDIV
        STA     DIVREL
        LDD     #4999           ; 200 Hz : sans danger quel que soit le moniteur
        STD     TMSB
        LDA     #$42
        STA     TCR
        LDA     STATUS
        ORA     #$20
        STA     STATUS
        PULS    CC
        ORCC    #$10
        JSR     COUNT2
        STX     TMPW            ; B : tours sans IRQ (2 images)
        ANDCC   #$EF
        JSR     COUNT2
        LDD     TMPW
        STX     TMPW2
        SUBD    TMPW2
        BCC     SI0
        LDD     #0
SI0     STD     TMPW2           ; D1 = tours perdus (4 x 2 IRQ)
        LDD     TMPW
        LSRA
        RORB
        LSRA
        RORB
        LSRA
        RORB
        LSRA
        RORB
        LSRA
        RORB
        STD     TMPW3           ; B/32
        CLR     SLOWSND         ; SLOWSND 0 = 2500 Hz, 1 = 2000, 2 = 1667, 3 = 1250, 4 = coupé
        CMPD    TMPW2
        BLO     SI1
        LDX     #399            ; 2500 Hz (<= 39 % du processeur)
        LDA     #50
        BRA     SI5
SI1     INC     SLOWSND
        LDD     TMPW3
        LSRA
        RORB
        ADDD    TMPW3           ; B/32 + B/64
        CMPD    TMPW2
        BLO     SI2
        LDX     #499            ; 2000 Hz (<= 47 %) : joue encore A5 et B5
        LDA     #40
        BRA     SI5
SI2     INC     SLOWSND
        LDD     TMPW3
        ASLB
        ROLA
        STD     TMPW3           ; B/16
        CMPD    TMPW2
        BLO     SI3
        LDX     #599            ; 1667 Hz (<= 52 %)
        LDA     #33
        BRA     SI5
SI3     INC     SLOWSND
        LDD     TMPW3
        LSRA
        RORB
        LSRA
        RORB
        ADDD    TMPW3           ; B/16 + B/64
        CMPD    TMPW2
        BLO     SI4
        LDX     #799            ; 1250 Hz (<= 49 %)
        LDA     #25
        BRA     SI5
SI4
        ORCC    #$50            ; trop lent : pas de son, timer à 50 Hz
        LDA     STATUS
        ANDA    #$DF
        STA     STATUS
        LDD     #19999
        STD     TMSB
        LDA     #4
        STA     SLOWSND
        ANDCC   #$AF
        RTS
SI5     ORCC    #$50
        STA     SNDDIV
        STA     DIVREL
        STX     TMSB
        ANDCC   #$AF
        RTS
COUNT2  JSR     COUNTFR
        STX     TMPW3
        JSR     COUNTFR
        TFR     X,D
        ADDD    TMPW3
        TFR     D,X
        RTS
* X = nombre de tours de boucle pendant une image
COUNTFR JSR     WAITVBL         ; début du retour trame : bit7 = 0
        LDX     #0
CF1     LEAX    1,X
        CMPX    #12000
        BHS     CF9
        LDA     GATE7
        BPL     CF1             ; retour trame
CF2     LEAX    1,X
        CMPX    #12000
        BHS     CF9
        LDA     GATE7
        BMI     CF2             ; lignes affichées
CF9     RTS

SNDRATE_N EQU   1000000/SNDRATE-1

* appelée par le moniteur à chaque IRQ timer (version CNA)
SNDIRQ  PSHS    D
        LDD     PH1
        ADDD    INC1
        STD     PH1
        LDB     VOL1
        TSTA
        BMI     SQ1
        CLRB
SQ1     STB     MIX
        LDD     PH2
        ADDD    INC2
        STD     PH2
        LDB     VOL2
        TSTA
        BMI     SQ2
        CLRB
SQ2     ADDB    MIX
        STB     JOYBTN
        DEC     SNDDIV
        BEQ     SQT
        PULS    D
        JMP     IRQEXIT
SQT     LDA     DIVREL
        STA     SNDDIV
        PSHS    X
        JSR     SEQTICK
        PULS    X
        PULS    D
        JMP     IRQEXIT
* version buzzer : son à 1 bit sur CP2 du 6846
SNDIRQB PSHS    D
        LDD     PH1
        ADDD    INC1
        STD     PH1
        LDB     VOL1
        TSTA
        BMI     SB1Q
        CLRB
SB1Q    STB     MIX
        LDD     PH2
        ADDD    INC2
        STD     PH2
        LDB     VOL2
        TSTA
        BMI     SB2Q
        CLRB
SB2Q    ADDB    MIX
        LDA     PCR
        ANDA    #$F7
        CMPB    #16
        BLO     SB3Q
        ORA     #$08
SB3Q    STA     PCR
        DEC     SNDDIV
        BEQ     SQT
        PULS    D
        JMP     IRQEXIT

* choisit la routine d'IRQ selon SNDMODE
SETSNDOUT
        PSHS    CC,X
        ORCC    #$50
        LDX     #SNDIRQ
        TST     SNDMODE
        BEQ     SSO1
        LDX     #SNDIRQB
        CLR     JOYBTN
SSO1    STX     TIMEPT
        PULS    CC,X,PC

* séquenceur (50 fois par seconde)
SEQTICK PSHS    Y
        TST     MUSON
        LBEQ    SQM9
* voix 1 : mélodie
        DEC     M1CNT
        BNE     SQ1E
        LDX     M1PTR
        LDY     #M1LOOP
        JSR     SEQRD
        STB     M1CNT
        STX     M1PTR
        TSTA                    ; (0 = silence)
        BEQ     SQ1Z
        SUBA    MELTR           ; transposition de la mélodie (MUSSTART)
SQ1Z    JSR     NOTEINC
        STD     INC1
        LDA     #30
        TST     INC1
        BNE     SQ1V
        TST     INC1+1
        BNE     SQ1V
        CLRA
SQ1V    STA     VOL1
        BRA     SQ2S
SQ1E    LDA     M1CNT           ; dernière image de la note : petit silence
        CMPA    #1
        BNE     SQ1D
        CLR     VOL1
        BRA     SQ2S
SQ1D    LDA     VOL1            ; décroissance jusqu'à 14
        CMPA    #14
        BLS     SQ2S
        DEC     VOL1
* voix 2 : basse (muette pendant un bruitage)
SQ2S    DEC     M2CNT
        BNE     SQ2E
        LDX     M2PTR
        LDY     #M2LOOP
        JSR     SEQRD
        STB     M2CNT
        STX     M2PTR
        TST     SFXPTR
        LBNE    SQM9
        JSR     NOTEINC
        STD     INC2
        LDA     #22
        TST     INC2
        BNE     SQ2V
        TST     INC2+1
        BNE     SQ2V
        CLRA
SQ2V    STA     VOL2
        LBRA    SQM9
SQ2E    TST     SFXPTR
        LBNE    SQM9
        LDA     M2CNT
        CMPA    #1
        BNE     SQ2D
        CLR     VOL2
        LBRA    SQM9
SQ2D    LDA     VOL2
        CMPA    #12
        LBLS    SQM9
        DEC     VOL2
* bruitage (voix 2)
SQM9    LDX     SFXPTR
        BEQ     SQS9
        DEC     SFXCNT
        BNE     SQS9
        LDA     ,X+
        CMPA    #$FE
        BEQ     SQSE
        LDB     ,X+
        STB     SFXCNT
        STX     SFXPTR
        JSR     NOTEINC
        STD     INC2
        LDA     #28
        STA     VOL2
        BRA     SQS9
SQSE    CLR     SFXPTR
        CLR     SFXPTR+1
        CLR     SFXPRIO
        CLR     VOL2
SQS9    PULS    Y,PC

* événement suivant d'une voix : X = pointeur, Y = bloc de la voix
* (0 LOOP début du morceau, 2 profondeur, 3 transposition, 4 pile de 2 retours)
* -> A = note transposée (0 = silence), B = durée
* codes : $FB t transposer de t demi-tons, $FC fin de motif, $FD adr jouer le motif
*         (2 niveaux au plus), $FF retour au début du morceau
SEQRD   LDA     ,X+
        CMPA    #$FB
        BLO     SR8
        BEQ     SRTR
        CMPA    #$FD
        BLO     SRRET
        BEQ     SRCALL
        LDX     ,Y              ; $FF : au début
        CLR     2,Y
        CLR     3,Y
        BRA     SEQRD
SRTR    LDA     ,X+
        STA     3,Y
        BRA     SEQRD
SRCALL  LDD     ,X++
        PSHS    D
        LDB     2,Y
        INC     2,Y
        ASLB
        ADDB    #4
        STX     B,Y
        PULS    X
        BRA     SEQRD
SRRET   DEC     2,Y
        LDB     2,Y
        ASLB
        ADDB    #4
        LDX     B,Y
        BRA     SEQRD
SR8     TSTA
        BEQ     SR9
        ADDA    3,Y
SR9     LDB     ,X+
        RTS

* A = note MIDI (0 = silence) -> D = incrément de phase
* au-delà de la moitié de la fréquence d'échantillonnage (incrément >= $8000)
* la note serait repliée (fausse) : on la descend d'une octave jusqu'à ce qu'elle passe
NOTEINC TSTA
        BNE     NI1
        CLRB
        RTS
NI1     PSHS    X
NI2     STA     NINOTE
        SUBA    #NOTEBASE
        TFR     A,B
        CLRA
        ASLB
        ROLA
        LDX     #NOTETAB
        LEAX    D,X
        LDD     ,X
        TST     SLOWSND
        BEQ     NI3
        STD     NITMP
        LDA     SLOWSND
        CMPA    #2
        BHI     NI2B
        BEQ     NI2A
        LDD     NITMP           ; x 1,25 (2000 Hz)
        LSRA
        RORB
        LSRA
        RORB
        ADDD    NITMP
        BCS     NI4             ; dépassement 16 bits
        BRA     NI3
NI2A    LDD     NITMP           ; x 1,5 (1667 Hz)
        LSRA
        RORB
        ADDD    NITMP
        BCS     NI4
        BRA     NI3
NI2B    LDD     NITMP           ; x 2
        ASLB
        ROLA
        BCS     NI4
NI3     TSTA
        BPL     NI9
NI4     LDA     NINOTE          ; trop aiguë : octave plus bas
        SUBA    #12
        BRA     NI2
NI9     PULS    X,PC

* lance un bruitage X de priorité A (s'il n'en masque pas un plus important)
PLAYSFX PSHS    CC,D
        ORCC    #$50
        LDB     SFXPTR
        ORB     SFXPTR+1
        BEQ     PS1
        CMPA    SFXPRIO
        BLO     PS9
PS1     STX     SFXPTR
        STA     SFXPRIO
        LDA     #1
        STA     SFXCNT
PS9     PULS    CC,D,PC

* (re)lance la musique choisie
MUSSTART
        PSHS    CC,D,X
        ORCC    #$50
        CLR     MUSON
        CLR     VOL1
        CLR     VOL2
        LDA     MUSSEL
        CMPA    #NSONGS
        BHS     MS9
        LDB     #5
        MUL
        LDX     #SONGTAB        ; voix 1, voix 2, note la plus aiguë
        ABX
        LDD     2,X
        STD     M2PTR
        STD     M2LOOP
        LDB     4,X
        LDX     ,X
        STX     M1PTR
        STX     M1LOOP
        CLR     M1LOOP+2        ; profondeur et transposition des voix
        CLR     M1LOOP+3
        CLR     M2LOOP+2
        CLR     M2LOOP+3
* mélodie trop aiguë pour la fréquence choisie : toute la voix une octave plus bas
* (plutôt que de ne descendre que les notes trop hautes, ce qui casse l'air)
        CLR     MELTR
        LDX     #LIMNOTE
        PSHS    A
        LDA     SLOWSND
        LDA     A,X
        PSHS    A
MS1A    CMPB    ,S
        BLS     MS1B
        SUBB    #12
        LDA     MELTR
        ADDA    #12
        STA     MELTR
        BRA     MS1A
MS1B    LEAS    1,S
        PULS    A
        LDA     #1
        STA     M1CNT
        STA     M2CNT
        STA     MUSON
MS9     LDA     MUSON
        STA     MUSWANT
        PULS    CC,D,X,PC

MUSTOGGLE
        LDA     MUSSEL
        CMPA    #NSONGS
        BEQ     MT9
        LDA     MUSWANT
        EORA    #1
        STA     MUSWANT
        STA     MUSON
        BNE     MT9
        JSR     SNDSILENCE
MT9     RTS

SNDSILENCE
        PSHS    CC
        ORCC    #$50
        CLR     VOL1
        TST     SFXPTR
        BNE     SS1
        CLR     VOL2
SS1     PULS    CC,PC

****************************************************************
* Temps
****************************************************************
WAITVBL PSHS    A,X
        LDX     #1250
WV1     LDA     GATE7
        BMI     WV2
        LEAX    -1,X
        BNE     WV1
        BRA     WV3
WV2     LDX     #1250
WV2B    LDA     GATE7
        BPL     WV3
        LEAX    -1,X
        BNE     WV2B
WV3     INC     FRAME
        JSR     RANDOM
        PULS    A,X,PC

WAITN   PSHS    B
WN1     JSR     WAITVBL
        DEC     ,S
        BNE     WN1
        PULS    B,PC

RANDOM  PSHS    D
        LDD     RNDSEED
        LSRA
        RORB
        BCC     RN1
        EORA    #$B4
RN1     STD     RNDSEED
        PULS    D,PC

****************************************************************
* Affichage
****************************************************************
INITVARS
        LDX     #VARS
IV1     CLR     ,X+
        CMPX    #VARSEND
        BLO     IV1
        LDD     #$ACE1
        STD     RNDSEED
        LDA     #1
        STA     GHOSTON
        LDX     #ROWADR         ; adresses des 200 lignes
        LDD     #$4000
IV2     STD     ,X++
        ADDD    #40
        CMPX    #ROWADR+400
        BLO     IV2
        RTS

* palette avec assombrissement FADEK (0 = normal, 16 = noir)
* le TO9 range l'entrée k dans la couleur k xor 8 : on écrit PAL[k xor PALX]
SETPAL  PSHS    D,X,Y
        CLR     PALIDX
        CLRB
SP1     PSHS    B
        EORB    PALX
        ASLB
        LDX     #PALETTE
        ABX
        LDA     ,X              ; VVVVRRRR
        ANDA    #$0F
        SUBA    FADEK
        BPL     SP2
        CLRA
SP2     STA     TMPA
        LDA     ,X
        LSRA
        LSRA
        LSRA
        LSRA
        SUBA    FADEK
        BPL     SP3
        CLRA
SP3     ASLA
        ASLA
        ASLA
        ASLA
        ORA     TMPA
        STA     PALDAT
        LDA     1,X             ; bleu
        SUBA    FADEK
        BPL     SP4
        CLRA
SP4     STA     PALDAT
        PULS    B
        INCB
        CMPB    #16
        BNE     SP1
        PULS    D,X,Y,PC

CLS     PSHS    CC
        ORCC    #$50
        LDA     PRC
        ORA     #1
        STA     PRC
        BSR     CLS1
        LDA     PRC
        ANDA    #$FE
        STA     PRC
        BSR     CLS1
        PULS    CC,PC
CLS1    LDX     #$4000
        LDD     #0
CLS2    STD     ,X++
        CMPX    #$5F40
        BLO     CLS2
        RTS

BLACKOUT
        LDA     #16
        STA     FADEK
        JMP     SETPAL

FADEIN  LDA     #12
        STA     FADEK
FI1     JSR     SETPAL
        LDB     #2
        JSR     WAITN
        LDA     FADEK
        SUBA    #4
        STA     FADEK
        BPL     FI1
        CLR     FADEK
        JMP     SETPAL

* décompresse un écran : X = banque A, Y = banque B
SHOWSCR PSHS    CC
        ORCC    #$50
        LDA     PRC
        ORA     #1
        STA     PRC
        LDU     #$4000
        JSR     UNLZ
        LDA     PRC
        ANDA    #$FE
        STA     PRC
        TFR     Y,X
        LDU     #$4000
        JSR     UNLZ
        PULS    CC,PC

UNLZ
UL1     CMPU    #$5F40
        BHS     ULX
        LDB     ,X+
        BMI     ULM
        INCB
UL2     LDA     ,X+
        STA     ,U+
        DECB
        BNE     UL2
        BRA     UL1
ULM     ANDB    #$7F
        ADDB    #3
        STB     ULCNT
        LDD     ,X++
        STD     ULDIST
        PSHS    X
        TFR     U,D
        SUBD    ULDIST
        TFR     D,X
        LDB     ULCNT
UL3     LDA     ,X+
        STA     ,U+
        DECB
        BNE     UL3
        PULS    X
        BRA     UL1
ULX     RTS

* A = paire (0..79), B = ligne -> X = adresse, banque choisie (détruit B)
* à appeler IRQ masquées
PADDR   PSHS    A
        LDX     #ROWADR
        ABX
        ABX
        LDX     ,X
        LDB     ,S
        LSRB
        ABX
        LDA     PRC
        BCS     PAB
        ORA     #1
        BRA     PAS
PAB     ANDA    #$FE
PAS     STA     PRC
        PULS    A,PC

* tuile A (6x9) en paire CP, ligne CY
DRAWTILE
        PSHS    D,X,U
        LDB     #27
        MUL
        ADDD    #CELLS
        TFR     D,U
        LDA     CP
        STA     DTP
        LDA     #3
        STA     DTCNT
DT1     PSHS    CC
        ORCC    #$50
        LDA     DTP
        LDB     CY
        BSR     PADDR
        LDA     ,U+
        STA     ,X
        LDA     ,U+
        STA     40,X
        LDA     ,U+
        STA     80,X
        LDA     ,U+
        STA     120,X
        LDA     ,U+
        STA     160,X
        LDA     ,U+
        STA     200,X
        LDA     ,U+
        STA     240,X
        LDA     ,U+
        STA     280,X
        LDA     ,U+
        STA     320,X
        PULS    CC
        INC     DTP
        DEC     DTCNT
        BNE     DT1
        PULS    D,X,U,PC

* tuile A dans la case (PROW, B) du puits
PUTCELL PSHS    D,X
        PSHS    A
        PSHS    B
        ASLB
        ADDB    ,S+
        ADDB    #PX/2
        STB     CP
        LDA     PROW
        LDB     #9
        MUL
        ADDB    #PY
        STB     CY
        PULS    A
        JSR     DRAWTILE
        LDA     PROW            ; mémorise la tuile affichée
        LDB     1,S
        JSR     CIDX
        LDX     #SCR
        ABX
        LDA     ,S
        STA     ,X
        PULS    D,X,PC

* redessine la case (A=ligne, B=col) selon le plateau
DRAWBC  PSHS    D,X
        STA     PROW
        JSR     BOARDADR
        LDA     ,X
        JSR     PUTCELL
        PULS    D,X,PC

BOARDADR
        PSHS    D
        PSHS    B
        LDB     #10
        MUL
        ADDB    ,S+
        ADCA    #0
        LDX     #BOARD
        LEAX    D,X
        PULS    D,PC

* remplit B paires à partir de la paire A, lignes FY..FY+FH-1, octet FV
FILLP   PSHS    D,X
        STA     FPP
        STB     FPN
FP1     PSHS    CC
        ORCC    #$50
        LDA     FPP
        LDB     FY
        JSR     PADDR
        LDA     FV
        LDB     FH
FP2     STA     ,X
        LEAX    40,X
        DECB
        BNE     FP2
        PULS    CC
        INC     FPP
        DEC     FPN
        BNE     FP1
        PULS    D,X,PC

* table fond/texte pour la police : LUT[i] (i = 2 bits, gauche/droite)
GLUT    PSHS    D
        LDA     TBG
        ASLA
        ASLA
        ASLA
        ASLA
        PSHS    A
        ORA     TBG
        STA     LUT
        LDA     ,S
        ORA     TFG
        STA     LUT+1
        LDA     TFG
        ASLA
        ASLA
        ASLA
        ASLA
        STA     ,S
        ORA     TBG
        STA     LUT+2
        PULS    A
        ORA     TFG
        STA     LUT+3
        PULS    D,PC

* chaîne X ($FF = fin) en TXP/TXY
DRAWSTR PSHS    D,X
        JSR     GLUT
DS1     LDA     ,X+
        CMPA    #$FF
        BEQ     DS9
        JSR     DRAWGLYPH
        INC     TXP
        INC     TXP
        BRA     DS1
DS9     PULS    D,X,PC

* glyphe A (3x5) en TXP/TXY, hauteur TVS lignes par ligne de glyphe
DRAWGLYPH
        PSHS    D,X,Y,U
        LDB     #5
        MUL
        ADDD    #FONT
        TFR     D,U
        LDY     #LUT
        CLR     GCOL
DG1     PSHS    CC
        ORCC    #$50
        LDA     TXP
        ADDA    GCOL
        LDB     TXY
        JSR     PADDR
        LDA     #5
        STA     GCNT
DG2     LDA     ,U+
        TST     GCOL
        BNE     DG3
        LSRA                    ; colonne 0 : pixels 0 et 1
        BRA     DG4
DG3     ANDA    #1              ; colonne 1 : pixel 2 puis espace
        ASLA
DG4     LDA     A,Y
        LDB     TVS
DG5     STA     ,X
        LEAX    40,X
        DECB
        BNE     DG5
        DEC     GCNT
        BNE     DG2
        PULS    CC
        LEAU    -5,U
        INC     GCOL
        LDA     GCOL
        CMPA    #2
        BNE     DG1
        PULS    D,X,Y,U,PC

****************************************************************
* Données
****************************************************************
BCD1    FCB     $00,$00,$01
LPTS    FCB     $00,$00,$40,$00,$01,$00,$00,$03,$00,$00,$12,$00
* note MIDI la plus aiguë jouable selon SLOWSND (sous la moitié de la fréquence)
*               2500 Hz : D#6, 2000 : B5, 1667 : G#5, 1250 : D#5, coupé
LIMNOTE FCB     87,83,80,75,127
GRAVTAB FCB     44,41,38,34,31,28,23,18,14,9,8,8,7,6,5,5,4,4,3,3,3
INFLAGS EQU     IN_L            ; les drapeaux suivent l'ordre des actions

        INCLUDE "gfx.asm"
        INCLUDE "music.asm"
ENDCODE

****************************************************************
* Variables
****************************************************************
        ORG     $DB10           ; variables tout en haut (elles finissent juste sous $E000)
VARS
IN_L    RMB     1               ; ordre = ACT_L..ACT_GH
IN_R    RMB     1
IN_DN   RMB     1
IN_UP   RMB     1
IN_CW   RMB     1
IN_CCW  RMB     1
IN_START RMB    1
IN_MUS  RMB     1
IN_GH   RMB     1
FRAME   RMB     1
RNDSEED RMB     2
LASTACT RMB     1
KEYAGE  RMB     1
KDAS    RMB     1
HOLDDN  RMB     1
SDBLOCK RMB     1
SDCNT   RMB     1
JOYOK   RMB     1
JCUR    RMB     1
JPREV   RMB     1
JNEW    RMB     1
DASCNT  RMB     1
PALX    RMB     1
FADEK   RMB     1
MSEL    RMB     1
STARTLV RMB     1
TP      RMB     1
TR      RMB     1
TY      RMB     1
TX      RMB     1
CURP    RMB     1
CURR    RMB     1
CURY    RMB     1
CURX    RMB     1
NEXTP   RMB     1
PCVIS   RMB     1
GHOSTON RMB     1
GOFF    RMB     1
OLDGOFF RMB     1
GOCNT   RMB     1
GPTR    RMB     8
GROW    RMB     4
GRAVCNT RMB     1
SDROWS  RMB     1
SCORE   RMB     3
LINES   RMB     2
LINESB  RMB     2
LEVEL   RMB     1
STATS   RMB     7
TOPSC   RMB     3
TMPA    RMB     1
TMPB    RMB     1
TMPC    RMB     1
TMPL    RMB     1
TMPW    RMB     2
TMPW2   RMB     2
TMPW3   RMB     2
NITMP   RMB     2
NINOTE  RMB     1
MTMP    RMB     2
NFULL   RMB     1
ROWFLG  RMB     NROWS
FLCNT   RMB     1
DSTR    RMB     1
SRCR    RMB     1
GOROW   RMB     1
PROW    RMB     1
CP      RMB     1
CY      RMB     1
DTP     RMB     1
DTCNT   RMB     1
FY      RMB     1
FH      RMB     1
FV      RMB     1
FPP     RMB     1
FPN     RMB     1
TXP     RMB     1
TXY     RMB     1
TFG     RMB     1
TBG     RMB     1
TVS     RMB     1
LUT     RMB     4
GCOL    RMB     1
GCNT    RMB     1
SBCNT   RMB     1
SBND    RMB     1
SBLEAD  RMB     1
SBSKIP  RMB     1
GCCNT   RMB     1
FTCNT   RMB     1
OVCNT   RMB     1
OVMODE  RMB     1
LKCNT   RMB     1
DNCNT   RMB     1
CKCNT   RMB     1
RTRY    RMB     1
ULCNT   RMB     1
ULDIST  RMB     2
* son
SNDMODE RMB     1               ; 0 = CNA, 1 = buzzer
SLOWSND RMB     1
SNDREADY RMB    1
SNDDIV  RMB     1
DIVREL  RMB     1
PH1     RMB     2
INC1    RMB     2
VOL1    RMB     1
PH2     RMB     2
INC2    RMB     2
VOL2    RMB     1
MIX     RMB     1
MUSSEL  RMB     1
MUSON   RMB     1
MUSWANT RMB     1
MELTR   RMB     1               ; transposition de la mélodie (demi-tons)
M1PTR   RMB     2
M1CNT   RMB     1
M1LOOP  RMB     8               ; bloc de voix (voir SEQRD)
M2PTR   RMB     2
M2CNT   RMB     1
M2LOOP  RMB     8
SFXPTR  RMB     2
SFXCNT  RMB     1
SFXPRIO RMB     1
* tampons
CBUF    RMB     12
NBUF    RMB     12
NGBUF   RMB     12              ; doit suivre NBUF
OBUF    RMB     12
OGBUF   RMB     12              ; doit suivre OBUF
BOARD   RMB     200
SCR     RMB     200             ; tuile affichée dans chaque case
OVL     RMB     200             ; pièce + fantôme par-dessus le plateau
ROWADR  RMB     400
VARSEND

        IFGT    ENDCODE-VARS
        ERROR   "le code déborde sur les variables : remonter l'ORG de VARS"
        ENDC
        IFGT    VARSEND-$E000
        ERROR   "les variables dépassent $DFFF"
        ENDC

        END     START
