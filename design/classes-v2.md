# Classes v2 — especificação (resumo fiel do documento do autor, 2026-11-13)

Resumo de trabalho do documento de classes que o autor mandou. Os números são os dele.
Cada classe tem **exatamente 6 slots**. O atalho é do slot, não da habilidade.
Estado da implementação no fim do arquivo.

## 1. Malpractice (era Gothic Nurse) — tank de sangue, rebalanceamento

- Renomear pra **Malpractice**.
- Está tank demais: **menos vida**.
- **Perde mais vida com os próprios ataques.**
- Fantasia: errar o parry ou usar mal os cooldowns = morrer de dano sozinha. "De papel".
- Recompensa: acertar os parries, recuperar a vida antes de morrer, passar bastante tempo com
  vida baixa pra aproveitar a passiva de **mais dano com vida baixa**.

## 2. Paladino — tank, complexidade mínima

Espada e escudo. O boneco mais fácil do jogo: sem gauge, combo, stacks, preparação ou recurso.
"Cavaleiro com um escudo enorme, extremamente difícil de matar."

| Slot | Habilidade | Recarga | Funcionamento |
|---|---|---:|---|
| 1 | Golpe de Juramento | 1,5 s | Ataque básico de espada. |
| 2 | Baque do Escudo | 8 s | Dano + interrompe (ainda não existe skill interrompível no jogo). |
| 3 | Provocação | 15 s | Provoca e força a atenção da boss. |
| 4 | Solo Consagrado | 18 s | Área sagrada que dá dano em inimigos próximos. |
| 5 | Égide | 25 s | Mitigação de 60% por alguns segundos + regeneração de vida. |
| 6 | Muralha da Fé | 60 s | Protege o grupo todo: mitigação de 20%. |

Visual: Égide = ergue o escudo, barreira dourada enorme na frente do corpo. Muralha da Fé =
cruz gigante sobre o grupo, todos numa luz dourada, **durante 3 s**.

## 3. Assassina — melee DPS, baixa complexidade

Rápida, agressiva, simples. Sem resets, venenos ou debuffs. A graça é a velocidade.

| Slot | Habilidade | Recarga | Funcionamento |
|---|---|---:|---|
| 1 | Talho Relâmpago | 0,6 s | Básico muito rápido. A cada 3 ataques o jogo pede outro LADO da boss: 3 na direita (consome 3 buffs RIGHT, +150% de dano no Talho), depois 3 na esquerda, pra sempre. Indicador visual do lado na boss, só quando se joga de Assassina. |
| 2 | Passo Rasante | 5 s | Avança atravessando o inimigo com um corte (só inimigos dentro da arena). |
| 3 | Garras Cruzadas | 6 s | Três cortes consecutivos muito rápidos. |
| 4 | Dança Carmesim | 12 s | Gira com as lâminas, dano em volta. |
| 5 | Golpe de Misericórdia | 15 s | Corte muito forte. Pode ser usado como parry (aí não dá dano; não salva de execute). |
| 6 | Frenesi da Fera | 60 s | 8 s de velocidade de ataque muito maior + 15% de dano. Boneco roxo com aura. |

Visual: Talho com animação curtíssima · Passo Rasante deixa rastro verde · Garras Cruzadas
mostra três silhuetas · Dança Carmesim deixa imagens residuais · Frenesi vira quase um borrão.

## 4. Soulflame (era Healer) — healer acessível

Pequena entidade de chama vital. Curas parecem pequenos milagres. Sem gauge nem segunda rotação.

| Slot | Habilidade | Recarga | Funcionamento |
|---|---|---:|---|
| 1 | Fagulha Espiritual | 1 s | Pequena chama no inimigo. |
| 2 | Toque de Brasa | GCD | Cura direta num aliado. Cast de 1,5 s. |
| 3 | Lareira Celestial | 18 s | Fogueira espiritual no chão: cura aliados próximos por 8 s. |
| 4 | Manto de Cinzas | 20 s | Escudo de chamas num aliado. |
| 5 | Asa da Fênix | 30 s | Grande cura instantânea num aliado. |
| 6 | Renascimento | 60 s | Fênix atravessa o campo: cura todos, dano médio na boss e DoT leve de 6/s. |

Visual: Lareira = fogueira azul-esverdeada; quem está dentro solta partículas de fogo.
Renascimento: a fogueira vira uma fênix enorme que voa pelo grupo.

## 5. Soulburner (NOVA) — ranged DPS, baixa-média complexidade

Anjo de fogo celestial. Uma interação define a classe: marcar e estourar.

| Slot | Habilidade | Recarga | Funcionamento |
|---|---|---:|---|
| 1 | Brasas do Firmamento | 1 s | Projétil de fogo. Básico. |
| 2 | Marca do Zênite | 12 s | Halo no inimigo por 10 s; é um DoT leve. |
| 3 | Lança Serafim | 8 s | Lança que cai no inimigo. Sem marca: quase nada. Com marca: remove a marca; dano ALTO se usada perto do fim do DoT, MÉDIO se no começo. |
| 4 | Rasante Incandescente | 10 s | Dash rápido que deixa uma explosão de fogo. |
| 5 | Chuva de Brasas | 20 s | Chuva de chamas numa área: DoT de 15 s. |
| 6 | Juízo Solar | 60 s | Sol gigante explode. Se marcado: mais dano e DoT médio de 15 s (NÃO consome a marca). |

**Debuffs de DoT visíveis embaixo da vida da boss, com timer embaixo do ícone** (vale pra todos).

## 6. Maga — "MAGE, artilharia arcana", ranged DPS, baixa complexidade

Atiradora: dispara, recarrega munição mágica, dispara. Nada de cast longo.

| Slot | Habilidade | Recarga | Funcionamento |
|---|---|---:|---|
| 1 | Disparo Rúnico | 1 s | Básico. |
| 2 | Rainbow Shots | 0,3 s entre tiros (sem recarga de 8 s) | Cada uso gasta 1 bala guardada, dano relativamente alto. Com EXATAMENTE 3 balas: gasta as 3 num tiro forte e ela leva um empurrão longo pra trás. |
| 3 | Ricochete Prismático | 8 s | Ricocheteia entre inimigos. Com 1 inimigo: boss → ela (cura um pouco, o excedente vira escudo) → boss…, 0,5 s por ida, no máximo 4 s, só em alcance melee da boss. |
| 4 | Tiro Perfurante | 12 s | Projétil concentrado em linha reta. |
| 5 | Salva Astral | 20 s | Sequência rápida de projéteis: consome 3 balas, área, e dá escudo nela. |
| 6 | Canhão Estelar | 60 s | Canhão enorme. Guardar TODAS as balas pra cá dá dano MUITO alto: mais que gastar as 7 soltas e mais que o canhão sozinho. |

**Passiva Rainbow Shots:** 1 bala a cada 8 s, máximo 7, mostrada embaixo da skill. Cada bala tem
uma COR e dá dano médio + um efeito (aguentar mais, mais dano, DoT, recuperar vida, dash no
próximo tiro). Dá pra ver pela cor qual é a próxima.

## 7. Apotecário (NOVA) — healer com rotação ofensiva (inspiração: Sage/Scholar)

Tanatopraxia, medicina legal, alquimia. Recurso: **Vestígios** (máx. 3). DoT: **Decomposição**.

- Decomposição dura 8 s; Necropsia tem recarga de 7 s. Renovar com **1 s restante** dá 1 Vestígio.
  Expirou ou reaplicou depois: sem Vestígio.
- Sem Decomposição no inimigo, o básico passa de 1 s pra 3 s de recarga.

| Slot | Habilidade | Recarga | Funcionamento |
|---|---|---:|---|
| 1 | Incisão | 1 s (3 s sem Decomposição) | Básico, dano moderado. Com Decomposição no alvo, cura um pouco o **Paciente** (último aliado que recebeu Sutura). |
| 2 | Necropsia | 7 s | Dano direto alto + Decomposição 8 s. |
| 3 | Sutura | cast 1,5 s | Cura individual considerável. Marca o Paciente por 15 s. |
| 4 | Solução Hemostática | 20 s | Em aliado: escudo de ~18% da vida máx. por 8 s. Em inimigo (só com 3 Vestígios e Decomposição): aplica **Contaminação**. |
| 5 | Tanatopraxia | 45 s | Normal (Nuvem Conservante): cura forte em área + regen 8 s; com 3 Vestígios pode gastá-los pra potencializar. Boss com Contaminação (Nuvem Tóxica): dano inicial + ticks em área, consome 3 Vestígios e a Contaminação. |
| 6 | Estabilização | 60 s | Grande cura instantânea individual; amplificada com o alvo abaixo de 25%. |

O documento também pede uma **análise crítica de design** desse kit (sinergia, rotação e
recargas, balanceamento, profundidade, melhorias) sem aumentar o número de habilidades.

## 8. Sleepwalker (NOVA) — ranged DPS, a classe mais difícil (high risk / high reward)

Dois modos: **Acordado** (prepara) e **Dormindo** (executa, IMÓVEL e ainda vulnerável).
6 botões: 5 de combate + transformação (slot 6, recarga 3 s).

**Torpor** (0–100): gerado acordado, gasto dormindo, perde 1/s acordado. Sem Torpor pra próxima
habilidade dormindo = acorda e perde o resto. **Vulnerabilidade Onírica**: até 8 stacks, +2% de
dano cada (16%), 30 s.

Acordado:

| Slot | Habilidade | Recarga | Dano | Torpor | Efeito |
|---|---|---:|---:|---:|---|
| 1 | Bocejo | 2 s (1 s com Perto do Sonho) | 50 | +4 | Básico. Acerta as Frestas. |
| 2 | Puxar o Lençol | 15 s | 60 | +8 | +2 stacks. Abre a janela de 1 s pro slot 3. |
| 3 | Visitantes debaixo da Cama | 15 s | 120 | +12 | 3 criaturas, +1 stack cada, deixa Migalhas. Janela de 1 s pro slot 4. |
| 4 | Senhor Travesseiro | 15 s | 140 | +16 | Come as Migalhas, +2 stacks, Travesseiro Cheio. Janela de 1 s pro slot 5. |
| 5 | A Cama Caiu! | 15 s | 200 | +24 | Consome Travesseiro Cheio (bônus grande), 8º stack, ativa Ecos do Pesadelo. |
| 6 | Sono Profundo | 3 s | | | Transforma. |

- Três janelas de **1 s** (mostrar no HUD como pop-up). Cada interação perfeita: +5 Torpor.
  Perder a janela: sem bônus de dano/Torpor/stacks.
- **Ecos do Pesadelo** (depois de A Cama Caiu! perfeita): 4 Frestas em +1, +4, +7, +10 s, cada
  uma aberta por 0,5 s; acertar com Bocejo dá dano médio extra. Som de invocação + um "PA!" na
  abertura; o indicador visual funciona sem áudio.

Dormindo (ordem obrigatória; a próxima da ordem brilha, como combo de FFXIV):

| Slot | Habilidade | Torpor | Dano |
|---|---|---:|---:|
| 1 | A Mordida dos Mil | 5 | 100 (recarga 18 s; aplica Pesadelo Persistente 20 s) |
| 2 | Senhor Travesseiro: Devorador | 10 | 150 |
| 3 | O Abraço Impossível | 15 | 200 |
| 4 | A Porta Errada | 20 | 250 |
| 5 | A Casa que Engole | 50 | 600 (+ escudo de 8% da vida máx. nos aliados por 5 s; acorda sozinho) |
| 6 | Acordar | | Cancela e perde o Torpor restante. |

- **Pesadelo Persistente**: único DoT, 20 s, só pela Mordida. Com menos de 5 Torpor a Mordida sai
  de graça com dano muito reduzido e ainda aplica o DoT; sem 10 Torpor pro slot 2, acorda depois
  de 1 s ("sem Torpor necessário, acordando").
- **Perto do Sonho**: buff dado ao aplicar/renovar o DoT; todas as recargas −1 s. Renovação
  perfeita (nos últimos 2 s do DoT): 20 s de buff; cedo, tarde ou primeira aplicação: 10 s;
  expirou: perde. A skill brilha nesses 2 s.
- HUD só de Sleepwalker: gauge de Torpor em cima das skills (com marcas de custo), 8 indicadores
  de Vulnerabilidade com timer, ícone do DoT embaixo da vida da boss, buff Perto do Sonho.
- Meta de conta: ciclo perfeito de 14 s = 60 + 15 + 40 (10 Bocejos) − 14 = 101 Torpor.

## 9. Ringstar (NOVA) — melee DPS, muito fácil

Boxeadora / estrela pop / magical girl com luvas mágicas gigantes. Sem gauge nem recurso.

| Slot | Habilidade | Recarga | Funcionamento |
|---|---|---:|---|
| 1 | Jab Estelar | GCD 2 s | Dano moderado. Fortalece o 2. |
| 2 | Direto de Campeã | GCD 2 s | Sem fortalecer: dano mínimo e NÃO fortalece o 3. Fortalecido: dano cheio e fortalece o 3. |
| 3 | Gancho Meteoro | GCD 2 s | Sem fortalecer: dano mínimo. Fortalecido: dano alto; reinicia a sequência. |
| 4 | Contagem Regressiva | 14 s, oGCD | Dash até o inimigo, arena luminosa em volta DELA. Buff de 15 s: GCD vira 1 s e +10% de dano. |
| 5 | SUPERSTAR! | 20 s, oGCD | Projéteis gigantes à distância, dano alto em área. |
| 6 | Nocaute Final | 60 s | Luva colossal, dano altíssimo. |

- Slots 1–3 dividem o GCD. Botão fortalecido **brilha**. GCD errado no meio perde o
  fortalecimento; oGCDs no meio não quebram a sequência.

## Perguntas em aberto

- **Party (DECIDIDO pelo autor em 2026-11-13): 4 LIVRES.** O jogador escolhe quaisquer 4 das 9 classes, sem obrigar tank/healer. Falta implementar (tela de party + código que hoje assume lugar 0 = tank).
  Antes: hoje são 4 lugares fixos (tank, healer, 2 DPS) e só a tank é escolhida. Com 9
  classes (2 tanks, 2 healers, 5 DPS) precisa de uma escolha de party. O design tem a prancha
  "Party" (escolher 4).
- **Arte:** as classes novas não têm retrato nem ilustração.
- **IA:** como cada kit novo se comporta quando o herói não é o controlado.

## Estado da implementação

- [x] Base: 6 slots por herói (barra do HUD, atalhos, recargas)
- [x] Malpractice — nome, 80 de vida, golpes custam vida (SELF_COST), +60% de dano com vida baixa (LOW_HP_BONUS), parry ajustado pra ainda aguentar o Esmagar. Teste: ui/tests/test_classes.gd
- [x] Paladino — os 6 slots da ficha, Égide com barreira dourada e regeneração, Muralha da Fé com a cruz de 3 s, Solo Consagrado. Interromper do Baque fica pra quando existir cast interrompível
- [x] Assassina — os 6 slots; Talho com 3 golpes de cada lado (+150%) e marca no chão; Passo Rasante atravessa a boss; Misericórdia com janela de parry de 0,35 s. Dano por golpe é proposta minha
- [x] Soulflame — os 6 slots; Lareira (8 s, 7/s), Manto, Asa da Fênix (110), Renascimento (cura 70, dano 90, DoT 6/s por 12 s). O Reviver saiu do kit: o Renascimento também levanta quem caiu (adição minha)
- [x] Maga — os 6 slots sem cast; balas Rainbow (1 a cada 8 s, máx. 7, 5 cores com efeito), tiro triplo com recuo, Ricochete perto da boss, Salva (3 balas), Canhão que rende mais com balas guardadas
- [x] Debuffs de DoT embaixo da vida da boss (game.add_dot / hud._tick_dots)
- [x] Soulburner (herói 5, chave "burner") — marca + Lança que cresce com a idade da marca (90 a 190), Rasante, Chuva, Juízo Solar. Retrato provisório
- [x] Apotecário (herói 7, chave "apothecary") — kit da ficha, Vestígios, Paciente, Hemostática em aliado ou boss, Tanatopraxia clínica/tóxica, IA de healer (HEAL_SLOTS). Análise de design em design/apotecario-analise.md (sugestões NÃO aplicadas)
- [x] Sleepwalker (herói 8, chave "sleepwalker") — dois modos (kit()), Torpor, Vulnerabilidade Onírica, janelas de 1 s, Ecos do Pesadelo com som gerado, Pesadelo Persistente e Perto do Sonho. Danos da ficha × SW_SCALE (0,45)
- [x] Ringstar (herói 6, chave "ringstar") — sequência Jab/Direto/Gancho com GCD dividido, botão fortalecido brilha, Contagem Regressiva, SUPERSTAR!, Nocaute Final. Retrato provisório
- [x] Party livre e fluxo de entrada: PLAY -> saves (4 slots, user://save_N.json) -> cafeteria (scripts/lobby.gd) -> bosses -> cartas -> luta. Teste: ui/tests/test_party.gd (rodar SEM argumentos)

## Atualização: ritmo do Sleepwalker, Nocaute Final, gauge da Malpractice, ícones (2026-11-13)

Vale o que está aqui quando divergir das fichas acima.

- **Sleepwalker**: toda habilidade conjura 1,25 s parado (0,75 s com Perto do Sonho); só Acordar é na hora, e é
  o único botão que interrompe uma conjuração. A janela de 1 s da sequência vale pra quem COMEÇA a conjurar
  dentro dela. Torpor acordado: 3 / 5 / 7 / 9 / 12, +6 por janela acertada (ciclo perfeito ≈ 50; a sequência
  do sonho custa 100). Punição ao acordar, sem agir mas podendo andar: 2 s sem ter usado nada, 1 s tendo usado
  só A Mordida dos Mil, 3 s largando a sequência no meio; fechar com A Casa que Engole não pune.
  SW_SCALE subiu de 0,45 pra 0,62 pra compensar o ritmo mais lento.
- **Ringstar, Nocaute Final**: salto de 0,8 s até perto da boss, dano em área (raio 7) na aterrissagem. No ar ela
  passa por cima de hazard com `"low": true` (ataque rente ao chão; nenhum boss usa ainda) e continua levando
  os outros ataques.
- **Malpractice**: os acúmulos do Blood Party viraram o gauge de Sangue, em cima da barra. Gauge cheio: cada
  golpe direto devolve 4% da vida máxima. Bônus de vida baixa: +75% (era +60%).
- **Habilidade de destaque** (`"big": true` em SKILLS): uma por herói. Quando o jogador usa, o HUD mostra brilho
  nas bordas e a arte do personagem à direita (hud.skill_cut). IA não dispara.
- **Ícones e fichas**: `assets/skills/<chave>_<slot>.svg` (59 arquivos; Modo Dormindo em `<chave>_s<slot>.svg`),
  textos em `scripts/skill_info.gd`, usados pela barra da luta, pelo tooltip e pela tela SKILLS do menu.
- **Sleepwalker, ajustes seguintes**: a sequência acordada só vale começando no Puxar o Lençol (a janela da
  próxima só abre depois de um passo acertado; habilidade solta não dá bônus nem acende nada). Acordar depois
  de usar só a Mordida custa 15 de Torpor, não tudo. Fresta acertada: +4 de Torpor. Ao chegar em 100, o Torpor
  segura cheio por 3 s antes de voltar a cair.
- **Cartas novas**: nenhuma carta é equipada sozinha. Ela entra na coleção marcada como NOVA pro herói que a
  conquistou (`Knowledge.fresh`, salvo no save): selo na carta até passar o mouse nela, aviso no rosto do herói
  até a última ser vista.
- **Maga, artilharia arcana (rework)**: limite de 8 Rainbow Shots. Salva Astral sem recarga: consome 3 balas e só
  acende com 3 ou mais. Ricochete Prismático só volta nela com o escudo da Salva de pé (e perto da boss).
  Tiro Perfurante marca a boss por 2 s; Salva, Canhão ou Disparo fortalecido estouram a marca (+60, uma vez;
  o Canhão usa a marca ao começar o preparo). Canhão Estelar conjura 2 s parada; com exatamente 8 balas vira
  o supercanhão arco-íris (+180, 2 s presa no lugar, dano em 8 batidas). Ela ganhou uma pistola de cristal.
- **Soulburner, fogo celestial (rework visual)**: paleta verde-marinho / ciano / menta / branco; asas no boneco.
  Marca do Zênite com halo que fica mais luminoso conforme a marca acaba. Lança Serafim com 1 s de cast (o dano
  é travado no começo do cast) e queda de 0,35 s. Chuva de Brasas cai de verdade pelos 15 s. Juízo Solar: 1 s
  subindo (preso), sol leva 2 s até a boss (dano no impacto; a marca vale na hora do uso), 1,5 s flutuando já
  podendo agir. Recargas e danos não mudaram.
- **Maga, Fada Astral**: Salva Astral com exatamente 6 balas (o botão brilha) gasta as 6 e solta a fada: 15 s perto
  da boss, 6 de dano por segundo. Com ela em campo o Ricochete quica entre a boss e a fada, e cada bala que a
  fada recebe cura a party em 5% da vida máxima (o excedente vira escudo). Canhão com 8 balas brilha em arco-íris.
  Rainbow Shots não sai sem balas.
- **Velocidade de andar** (só pra quem o jogador controla; a IA fica na base): Assassina e Malpractice 100%;
  Sleepwalker e Apotecário 35%; os outros 60%. A Nuvem Conservante do Apotecário dá +60% à party por 8 s.
- **Reviver**: Soulflame, simples: Asa da Fênix com alguém caído revive com 50% (o escolhido no card primeiro).
  Apotecário, em etapas: Sutura no caído escolhido no card prepara o corpo (vira o Paciente); Estabilização com
  3 Vestígios reanima o Paciente com 40%. A IA do Apotecário não faz isso sozinha.
- **Soulburner**: nos últimos 2 s da Marca do Zênite o halo estoura de brilho e o botão da Lança acende; a
  Lança conjurada aí é a Lança Perfeita (fogo em volta, coluna de luz no impacto).
- **Assassina (ajustes)**: Frenesi também corta pela metade a recarga do Passo Rasante e das Garras. Garras
  Cruzadas: 3 de dano por corte, divide a recarga com o Talho (0,6 s) e abre o Ferimento (12 s: +15% de dano da
  party inteira na boss). Dança Carmesim: 95 de dano, 15 s, o boneco gira. Golpe de Misericórdia: 22 s, salto
  em espiral de 1 s até a boss, de qualquer distância; atingida no salto ela apara e o corte não sai; em
  Frenesi não toma dano, o corte sai e dá +50%.
- **Malpractice (visual e Ultimate)**: seringa gigante e escudo médico modelados no boneco (unit.syringe,
  unit.med_shield), prontos pra pendurar no modelo definitivo. Blood Party agora dura 10 s: joga o escudo fora e
  se injeta; começa com 1 de vida, não morre enquanto dura, dano x2, recargas pela metade, rouba 25% do dano
  causado, cura e escudo de fora não entram, e morre no fim se a vida não estiver cheia. O slot do parry vira a
  Extração (1 s na boss, +40% da vida máxima, 4 s de recarga). A aura de dano antiga saiu.
- **Ringstar**: Contagem Regressiva dá +44% de velocidade de movimento.
- **Foco por clique na luta**: um clique no card ou no boneco 3D foca o herói (círculo em volta dele); dois cliques
  trocam o controle. Caído só pode ser focado.
- **Soulflame**: todas as habilidades conjuram 1,2 s; Fagulha e Toque de Brasa com 2 s de recarga. Renascimento
  com uma Lareira acesa: a fênix nasce dela e a Lareira fica forte (12 de cura por segundo, raio 7, 14 s).
- **Malpractice, Bloodbath (slot 6)**: 10 de Sangue; chove sangue em volta dela (raio 6): 20% menos dano por 10 s em
  quem for coberto. Abre 2 s pra escolher UMA habilidade fortalecida (Poke: rajada 3 s; Blood Taste: janela em
  dobro; Consumed: +20% de vida, regeneração e Compartilhamento de Sangue na party). No Blood Party: de graça,
  raio em dobro, três cargas, DoT Pure Blood (não alimenta o roubo de vida) e a Extração fortalecida carrega 2,5 s
  e explode. Blood Taste só dá Sangue no parry bem-sucedido. No Blood Party a tela pulsa vermelho e roxo.
- **Soulflame, Renascimento**: 3 s de cast; a fênix nasce, grita e voa devagar até a boss, largando fogo no chão.
  Cura e reviver no nascimento; dano e DoT na chegada.
- **Assassina**: duas adagas no boneco. Frenesi de 12 s com a tela pulsando roxo; quando acaba, o botão vira a
  Última Dança por 2 s (bônus, sem recarga): 14 cortes de 20 e um X de 220, intocável, abre o Ferimento.
  Golpe de Misericórdia é a execução: até +80% conforme a boss perde vida; +25% com Ferimento, que ele renova.
- **Cliques na luta**: slots da barra e o Limit Break são clicáveis.

## Rodada: Rotação, Assassina, barra arrumável e Soulburner

- **Carta Rotação** (`dps`): com ela, o herói na mão da IA joga o kit de verdade (`_ai_rotation` / `_rot_pick`
  em `scripts/game.gd`), cada habilidade saindo de 0,3 a 2 s depois de voltar (`AI_REACT`), com 50% do dano
  do jogador (`AI_ROT_MULT`). Larga a conjuração se uma mecânica chamar. Pra liberar (`rot_ok`), em 25 s
  corridos: DPS >= `DPS_GOAL`; básico parado no máximo 35% do tempo; cada habilidade de `ROT_SLOTS` usada;
  atraso médio depois de voltar <= 3 s; nenhuma parada há mais de 6 s.
- **Assassina**: Talho 1,3 s de recarga (0,6 s com Ferimento na boss); Garras 3x2 de dano; em Frenesi cada
  Talho tira 0,3 s da Dança e do Misericórdia, os dois botões brilham roxo, a Dança vira furacão (+40%).
  Misericórdia: arremessa a adaga, se puxa, crava (40%) e mergulha (60%); em Frenesi vai girando como serra.
  Última Dança: 0,5 s agachada, cortes horizontais longos com a tela clareando, X, e o Corte Final que
  devolve 45% do dano causado no Frenesi (dano direto).
- **Barra arrumável**: na tela SKILLS, segurar e arrastar uma linha em cima de outra troca as posições
  (R restaura). Fica em `Knowledge.layouts`, por herói e por save; teclas são das posições.
- **Soulburner**: Brasas com 1 s de cast e 2 s de recarga contando do começo do cast; Juízo Solar brilha
  verde quando está pronto e a boss tem a Marca do Zênite. Meta de DPS da Rotação dele: 34 -> 26.
