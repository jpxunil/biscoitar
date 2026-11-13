# Gera o esqueleto de layout das telas como .tscn. Rodar de novo SOBRESCREVE ajustes feitos no editor.
C = {"NIGHT":"Color(0.075, 0.07, 0.16, 1)","NAVY":"Color(0.13, 0.13, 0.3, 1)","GRAPE":"Color(0.42, 0.22, 0.86, 1)",
     "VIOLET":"Color(0.62, 0.36, 1, 1)","CREAM":"Color(0.97, 0.94, 0.84, 1)","BROWN":"Color(0.36, 0.22, 0.16, 1)",
     "TAN":"Color(0.78, 0.6, 0.4, 1)","OUT":"Color(0.05, 0.045, 0.1, 1)","COIN":"Color(1, 0.8, 0.25, 1)","DIM":"Color(0.66, 0.69, 0.84, 1)"}
KIT = {"panel":"res://ui/kit/ink_panel.gd","button":"res://ui/kit/ink_button.gd","bg":"res://ui/kit/ink_backdrop.gd","label":"res://ui/kit/ink_label.gd"}
BASE = {"panel":"Control","button":"Button","bg":"Control","label":"Label"}

def scene(path, script, nodes, extra_scripts={}):
    scripts = dict(KIT); scripts.update(extra_scripts); scripts["root"] = script
    for k in extra_scripts: BASE[k] = "Control"
    ids = {k:str(i+1) for i,k in enumerate(scripts)}
    out = ['[gd_scene load_steps=%d format=3]\n' % (len(scripts)+1)]
    for k,p in scripts.items():
        out.append('[ext_resource type="Script" path="%s" id="%s"]' % (p, ids[k]))
    out.append('')
    out.append('[node name="%s" type="Control"]' % path.split('/')[-1].replace('.tscn','').title().replace('_',''))
    out += ['layout_mode = 3','anchors_preset = 15','anchor_right = 1.0','anchor_bottom = 1.0','script = ExtResource("%s")' % ids["root"],'']
    for n in nodes:
        name, parent, kind, rect, props = n
        typ = BASE.get(kind, kind)
        out.append('[node name="%s" type="%s" parent="%s"]' % (name, typ, parent))
        if kind == "bg":
            out += ['layout_mode = 1','anchors_preset = 15','anchor_right = 1.0','anchor_bottom = 1.0','mouse_filter = 2']
        elif rect:
            x,y,w,h = rect
            out += ['layout_mode = 0','offset_left = %.1f' % x,'offset_top = %.1f' % y,'offset_right = %.1f' % (x+w),'offset_bottom = %.1f' % (y+h)]
        if kind in scripts and kind in KIT or kind in extra_scripts:
            out.append('script = ExtResource("%s")' % ids[kind])
        if kind in ("panel",):
            out.append('mouse_filter = 2')
        for k,v in props.items():
            if isinstance(v, str) and v in C: v = C[v]
            elif isinstance(v, str) and not v.startswith(("Color(","Vector2(","ExtResource")) : v = '"%s"' % v
            elif isinstance(v, bool): v = "true" if v else "false"
            out.append('%s = %s' % (k, v))
        out.append('')
    open(path,'w').write('\n'.join(out))

def lab(name,parent,rect,text,px,color="CREAM",**kw):
    p={"text":text,"px":px,"color":color}; p.update(kw); return (name,parent,"label",rect,p)
def txt(name,parent,rect,text,px,color="CREAM",**kw):
    p={"text":text,"theme_override_font_sizes/font_size":px,"theme_override_colors/font_color":color,"mouse_filter":2}; p.update(kw); return (name,parent,"Label",rect,p)
def pan(name,parent,rect,fill,seed,**kw):
    p={"fill":fill,"shape_seed":seed}; p.update(kw); return (name,parent,"panel",rect,p)
def btn(name,parent,rect,text,fill,fg,px,seed):
    return (name,parent,"button",rect,{"text":text,"fill":fill,"fg":fg,"font_px":px,"shape_seed":seed})
def box(name,parent,rect,kind="Control",**kw):
    return (name,parent,kind,rect,kw)

# ---------------- título
scene("ui/screens/title_screen.tscn","res://ui/screens/title_screen.gd",[
  ("Bg",".","bg",None,{}),
  pan("LogoPanel",".",(70,110,660,250),"GRAPE",21,rotation=-0.05),
  lab("Logo1","LogoPanel",(40,18,600,110),"BORA",100,"CREAM"),
  lab("Logo2","LogoPanel",(40,118,600,110),"BISCOITAR",100,"COIN"),
  pan("TagPanel",".",(110,380,360,50),"OUT",5,rotation=-0.03),
  txt("Tag","TagPanel",(18,10,330,30),"um jogador, quatro heróis, uma boss",17,"CREAM"),
  btn("BtnBosses",".",(820,210,380,92),"BOSSES","COIN","OUT",40,5),
  btn("BtnGear",".",(840,324,380,92),"GEAR","CREAM","OUT",40,9),
  btn("BtnShop",".",(820,438,380,92),"LOJA","GRAPE","CREAM",40,13),
  pan("ShopLock",".",(880,536,280,38),"OUT",7),
  txt("ShopLockText","ShopLock",(14,7,260,26),"vença um boss pra abrir",15,"DIM"),
  pan("Wallet",".",(60,610,330,64),"NAVY",15),
  box("CoinIcon","Wallet",(18,16,32,32)),
  lab("Coins","Wallet",(58,10,100,44),"0",28,"COIN"),
  box("TicketIcon","Wallet",(176,16,32,32)),
  lab("Tickets","Wallet",(216,10,100,44),"0",28,"VIOLET"),
])

# ---------------- bosses
scene("ui/screens/boss_screen.tscn","res://ui/screens/boss_screen.gd",[
  ("Bg",".","bg",None,{}),
  pan("TitlePanel",".",(40,24,330,88),"NAVY",4,rotation=-0.02),
  lab("Title","TitlePanel",(26,10,300,70),"BOSSES",52,"CREAM"),
  box("List",".",(46,150,1188,420),"HBoxContainer",**{"theme_override_constants/separation":18}),
  btn("BtnBack",".",(46,614,200,72),"VOLTAR","CREAM","OUT",26,7),
  btn("BtnConfirm",".",(900,606,334,88),"CONFIRMAR","COIN","OUT",34,5),
])

# ---------------- cartas
scene("ui/screens/cards_screen.tscn","res://ui/screens/cards_screen.gd",[
  ("Bg",".","bg",None,{}),
  pan("TitlePanel",".",(34,18,300,92),"NAVY",4,rotation=-0.02),
  lab("Title","TitlePanel",(22,4,270,60),"CARTAS",46,"CREAM"),
  txt("BossName","TitlePanel",(24,60,270,24),"MINI-CHAN",15,"COIN"),
  btn("BtnPrev",".",(372,26,64,76),"<","CREAM","OUT",40,6),
  box("HeroStrip",".",(446,20,700,88),"HBoxContainer",**{"theme_override_constants/separation":10,"alignment":1}),
  btn("BtnNext",".",(1156,26,64,76),">","CREAM","OUT",40,11),
  pan("EquipPanel",".",(34,124,770,384),"NAVY",8),
  txt("LabPurple","EquipPanel",(24,8,200,20),"ÉPICAS",13,"VIOLET"),
  txt("LabGold","EquipPanel",(284,8,200,20),"RARAS",13,"COIN"),
  txt("LabWhite","EquipPanel",(24,196,200,20),"COMUNS",13,"CREAM"),
  txt("LabItem","EquipPanel",(536,196,200,20),"ITEM ON HOLD",13,"Color(0.3, 0.9, 1, 1)"),
  box("PurpleRow","EquipPanel",(24,30,226,152),"HBoxContainer",**{"theme_override_constants/separation":10}),
  box("GoldRow","EquipPanel",(284,30,344,152),"HBoxContainer",**{"theme_override_constants/separation":10}),
  box("WhiteRow","EquipPanel",(24,218,462,152),"HBoxContainer",**{"theme_override_constants/separation":10}),
  box("ItemRow","EquipPanel",(536,218,108,152),"HBoxContainer",**{"theme_override_constants/separation":10}),
  pan("HeroPanel",".",(826,124,420,384),"GRAPE",12),
  pan("FaceFrame","HeroPanel",(22,22,176,176),"OUT",3),
  box("Face","HeroPanel/FaceFrame",(8,8,160,160),"TextureRect",expand_mode=1,stretch_mode=6,mouse_filter=2),
  lab("HeroName","HeroPanel",(214,26,200,56),"TANK",40,"OUT"),
  txt("HeroRole","HeroPanel",(216,84,196,24),"Tanque",17,"OUT"),
  pan("HpTag","HeroPanel",(214,124,150,44),"OUT",9),
  lab("HeroHp","HeroPanel/HpTag",(14,4,130,36),"HP 160",24,"CREAM"),
  pan("BlurbPanel","HeroPanel",(22,216,376,146),"CREAM",14),
  txt("HeroBlurb","HeroPanel/BlurbPanel",(18,14,340,120),"...",17,"OUT",autowrap_mode=3),
  btn("BtnBack",".",(34,646,124,62),"VOLTAR","CREAM","OUT",20,7),
  pan("HandPanel",".",(172,522,740,188),"BROWN",17),
  txt("LabHand","HandPanel",(22,6,300,20),"SUAS CARTAS",13,"CREAM"),
  btn("HandPrev","HandPanel",(8,76,34,60),"<","CREAM","OUT",24,4),
  box("HandRow","HandPanel",(48,28,644,152),clip_contents=False),
  btn("HandNext","HandPanel",(698,76,34,60),">","CREAM","OUT",24,5),
  pan("Details",".",(930,522,316,112),"CREAM",19),
  lab("CardName","Details",(16,6,290,32),"",21,"OUT"),
  txt("CardMeta","Details",(18,36,290,18),"",12,"Color(0.36, 0.22, 0.16, 1)"),
  txt("CardDesc","Details",(18,54,284,54),"",13,"OUT",autowrap_mode=3),
  btn("BtnReady",".",(930,644,316,66),"READY FOR BATTLE","COIN","OUT",25,5),
])

# ---------------- loja
scene("ui/screens/shop_screen.tscn","res://ui/screens/shop_screen.gd",[
  ("Bg",".","bg",None,{"stripe_a":"Color(0.5, 0.2, 0.75, 1)","base":"Color(0.06, 0.055, 0.12, 1)"}),
  pan("TitlePanel",".",(34,18,250,92),"GRAPE",4,rotation=-0.03),
  lab("Title","TitlePanel",(26,8,220,74),"LOJA",56,"CREAM"),
  pan("Wallet",".",(930,26,316,64),"NAVY",15),
  box("CoinIcon","Wallet",(18,16,32,32)),
  lab("Coins","Wallet",(58,10,100,44),"0",28,"COIN"),
  box("TicketIcon","Wallet",(170,16,32,32)),
  lab("Tickets","Wallet",(210,10,100,44),"0",28,"VIOLET"),
  ("Vendor",".","vendor",(40,250,320,360),{}),
  pan("Bubble",".",(34,128,330,112),"CREAM",23),
  txt("BubbleText","Bubble",(18,12,296,88),"...",17,"OUT",autowrap_mode=3),
  box("Tabs",".",(386,124,520,50),"HBoxContainer",**{"theme_override_constants/separation":8}),
  pan("GridPanel",".",(380,184,520,470),"NAVY",8),
  box("Scroll","GridPanel",(18,16,490,440),"ScrollContainer",horizontal_scroll_mode=0),
  box("Grid","GridPanel/Scroll",None,"GridContainer",columns=4,**{"theme_override_constants/h_separation":12,"theme_override_constants/v_separation":14}),
  pan("Details",".",(920,128,326,430),"CREAM",19),
  box("CardSpot","Details",(22,20,108,152)),
  lab("CardName","Details",(140,20,180,88),"",22,"OUT",autowrap_mode=3),
  txt("CardMeta","Details",(142,112,180,40),"",13,"Color(0.36, 0.22, 0.16, 1)",autowrap_mode=3),
  txt("CardWho","Details",(22,184,290,22),"",14,"Color(0.36, 0.22, 0.16, 1)"),
  txt("CardDesc","Details",(22,212,286,130),"",16,"OUT",autowrap_mode=3),
  pan("PriceTag","Details",(22,360,282,50),"OUT",9),
  box("PriceIcon","Details/PriceTag",(14,9,32,32)),
  lab("Price","Details/PriceTag",(56,5,220,40),"",26,"COIN"),
  btn("BtnBuy",".",(920,572,326,86),"COMPRAR","GRAPE","CREAM",36,8),
  btn("BtnBack",".",(40,636,180,66),"VOLTAR","CREAM","OUT",24,7),
], {"vendor":"res://ui/screens/vendor.gd"})
print("ok")
