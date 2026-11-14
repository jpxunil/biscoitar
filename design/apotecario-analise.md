# Apotecário — análise de design

Resposta ao pedido de análise crítica que está na ficha da classe (ver `classes-v2.md`).
O kit foi implementado **como a ficha descreve**; nada do que está em "Sugestões" foi aplicado.
Os números citados são os que estão no jogo hoje (`scripts/game.gd`, bloco "Kit do Apotecário").

## Resumo

O núcleo funciona: bater mantém um aliado de pé, e o mesmo recurso paga ou uma cura grande ou
um burst de dano. O ponto fraco é a **geração de Vestígios**: do jeito que os números estão, ela
não exige o timing que a ficha promete e o recurso fica parado no máximo durante boa parte do
ciclo. O resto são ajustes.

## A. Sinergia das seis habilidades

- **Incisão + Necropsia + Sutura** é o melhor trio do kit. A Sutura não é só uma cura: ela
  escolhe o Paciente, e a partir daí cada Incisão cura. Isso faz o jogador querer voltar a bater
  logo depois de curar, que é exatamente a fantasia.
- **Sutura e Estabilização não são redundantes.** Uma compete com a rotação (1,5 s parado), a
  outra é instantânea e rara. Papéis diferentes.
- **Solução Hemostática é o elo fraco.** Um botão só serve a aliado e a inimigo, e a ficha não
  diz como o jogador escolhe. No jogo ficou assim: com um aliado escolhido (F1–F4) vai nele; sem
  aliado escolhido, com 3 Vestígios e Decomposição ativa, vai na boss. Funciona, mas é uma regra
  que o jogador precisa aprender, e errar o alvo custa 20 s.
- **A conversão da Tanatopraxia é a melhor ideia da classe.** Ela transforma "tenho recurso
  sobrando" numa decisão, em vez de um botão de dano que se aperta sempre.

## B. Rotação e recargas

**O problema da janela de 1 s.** A Decomposição dura 8 s e a Necropsia recarrega em 7 s. Então a
Necropsia só fica disponível quando falta exatamente 1 s, que já é a janela. Consequências:

- É impossível renovar cedo demais: a recarga não deixa.
- Quem aperta Necropsia assim que ela acende ganha o Vestígio sempre.
- O único jeito de errar é atrasar mais de 1 s.

Ou seja, hoje a mecânica pune atraso, não recompensa precisão. Compare com a Mordida do
Sleepwalker, onde a habilidade fica pronta 1 s **antes** da janela e o jogador precisa resistir.

**Vestígios sobram.** Um Vestígio a cada 7 s dá 3 em 21 s (28 s contando a primeira aplicação).
A Tanatopraxia, que é o único gasto, recarrega em 45 s. São uns 17 s por ciclo com o recurso no
máximo, sem nada para fazer com ele.

**Sutura contra a janela.** A Sutura leva 1,5 s e a janela tem 1 s. Começar uma Sutura perto da
renovação faz perder o Vestígio. Essa tensão é boa (curar tem custo ofensivo real), mas é mais
dura do que parece no papel.

**Tempo morto.** Não há. Entre duas Necropsias cabem seis Incisões, e sempre há uma recarga
voltando. O GCD de 1 s da Incisão é o padrão do jogo (todo ataque básico tem 1 s), então não
destoa.

**Luta de 3 a 5 minutos.** São de 4 a 6 Tanatopraxias. Se todas forem tóxicas, o jogador nunca
usa a cura em área; se todas forem clínicas, a classe vira uma healer comum. O interessante é a
mistura, e os números atuais permitem as duas.

## C. Balanceamento

Dano por segundo aproximado, rotação limpa, sem curar ninguém:

| Fonte | DPS |
|---|---:|
| Incisão (16 por segundo) | 16 |
| Necropsia (60 a cada 7 s) | 8,6 |
| Decomposição (6 por segundo) | 6 |
| Nuvem Tóxica (120 + 160 a cada 45 s) | 6,2 |
| **Total** | **~37** |

- **Contra as outras classes:** a Soulflame faz uns 12 de dano por segundo; as classes de DPS
  ficam entre 60 e 90. O Apotecário fica em mais ou menos metade de um DPS. É alto para healer,
  e é o que a ficha pede. O preço está nas curas: não tem reviver, não tem cura em área barata e
  a cura direta exige parar.
- **Proporção Incisão / Necropsia:** hoje é cerca de 2 para 1 em dano por segundo (16 contra
  8,6, ou 14,6 contando o DoT junto com a Necropsia). Está bom: a Necropsia importa sem que a
  Incisão vire enfeite.
- **Cura do Paciente:** 4 por Incisão, ou seja, 4 por segundo num aliado só. A boss bate 3 por
  segundo na tank com o golpe básico. Sozinha, a cura passiva quase anula o dano básico na tank.
  É forte; eu baixaria para 3.
- **Tóxica contra clínica:** a tóxica soma uns 17% ao dano da classe. A clínica cura 60 em todos
  (108 gastando Vestígios). A tóxica não torna a cura irrelevante, porque a cura é a única área
  do kit. O risco é o contrário: em luta difícil, a tóxica nunca ser usada.
- **Boss invulnerável ou fora de alcance:** é o pior caso da classe. A Decomposição expira, a
  cadeia de Vestígios quebra e a Incisão vai para 3 s. Três punições por algo que o jogador não
  controla.

## D. Profundidade

- **Iniciante:** aperta Necropsia quando acende, bate com Incisão, cura com Sutura. Já funciona,
  e o Paciente recompensa sem precisar entender o sistema.
- **Experiente:** encaixa a Sutura logo depois de uma Necropsia para não perder a janela; usa a
  Hemostática um pouco antes do golpe grande, porque 8 s de escudo é curto; decide com
  antecedência se os próximos 3 Vestígios vão para cura ou para a boss.
- **O que falta:** uma decisão frequente. Hoje a escolha grande aparece uma vez a cada 45 s.

## E. Sugestões (sem aumentar o número de habilidades)

1. **Dar timing de verdade à janela.** Decomposição de 9 s com Necropsia de 7 s: a habilidade
   acende com 2 s sobrando e o Vestígio só vem no último segundo. Passa a existir o erro de
   apertar cedo.
2. **Dar mais saída para os Vestígios.** Por exemplo: Sutura ou Estabilização gastam 1 Vestígio
   para sair mais fortes (Sutura sem conjuração, Estabilização com escudo). O recurso deixa de
   ficar parado e aparece uma decisão a cada poucos segundos.
3. **Tirar a ambiguidade da Hemostática.** Regra única e visível: o botão mostra na barra em
   quem vai cair (nome do aliado ou "BOSS"), e muda de cor quando a versão ofensiva está
   liberada.
4. **Não punir o que o jogador não controla.** Congelar o tempo da Decomposição enquanto a boss
   estiver invulnerável, e só aplicar a Incisão lenta depois da primeira Necropsia da luta.
5. **Baixar a cura do Paciente** de 4 para 3 por Incisão.
6. **Alargar a janela para 1,5 s**, igual à conjuração da Sutura, se a sugestão 1 não for
   adotada. Assim uma Sutura bem encaixada não custa o Vestígio.

A ordem importa: a 1 e a 2 mudam como a classe se joga; as outras são acabamento.
