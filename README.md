# Elemental Idle Runner

## Visao geral

Elemental Idle Runner e um auto-battler 2D side-scroller. O Avatar ataca automaticamente inimigos elementais, enquanto o jogador escolhe o elemento, coleta essencias e ativa bonus de dano. A partida comeca apenas com Fogo; os demais elementos sao liberados por nivel de XP.

O projeto usa Godot 4.7, GDScript e recursos nativos da Godot. A cena principal e `res://scenes/Main.tscn`.

## Como executar

1. Abra o projeto na Godot 4.7.
2. Abra `scenes/Main.tscn` para inspecionar a arena.
3. Pressione `F6` para executar a cena ou `F5` para executar o projeto.
4. Erros de script aparecem no painel inferior **Debugger** da Godot. Erros de execucao tambem aparecem no console da sessao.

## Estrutura do projeto

### Cenas

- `scenes/Main.tscn`: fundo, tiles do chao e instancia do Avatar. A HUD, o spawn, as waves e as telas de estado sao montados por `scripts/main.gd`.
- `scenes/Player.tscn`: Avatar e seu `Sprite2D`.
- `scenes/Enemy.tscn`: inimigo reutilizavel e seu `Sprite2D`.
- `scenes/Projectile.tscn`: raiz do projétil. O sprite e criado por `projectile.gd` para escolher a textura elemental.
- `scenes/Essence.tscn`: essencia e seu `Sprite2D`.
- `scenes/DebugPanel.tscn`: painel de debug reutilizavel.

### Scripts

- `scripts/main.gd`: coordena a partida, waves, spawn, combate automatico, HUD, telas, derrota e reinicio.
- `scripts/player.gd`: vida, selecao elemental, dano, alcance, recargas, bonus, XP e niveis.
- `scripts/enemy.gd`: vida, movimento, cor elemental, contato, efeitos, feedback e morte.
- `scripts/projectile.gd`: movimento, textura, impacto e aplicacao do efeito elemental.
- `scripts/essence.gd`: deslocamento da essencia.
- `scripts/debug_panel.gd`: pausa, velocidade, spawn manual, XP de teste e reinicio.

### Assets

Os SVGs ficam em `assets/characters`, `assets/projectiles`, `assets/items` e `assets/environment`.

## Onde ajustar o balanceamento

As propriedades exportadas podem ser alteradas selecionando o no correspondente no Inspector. Valores definidos em arrays exportados ficam no no `Main`.

### Avatar

Selecione a instancia `Player` em `Main.tscn` ou abra `Player.tscn`.

- `max_health`: vida maxima. Aumentar permite sobreviver a mais contatos.
- `fire_damage`, `water_damage`, `earth_damage`, `air_damage`: dano de cada elemento.
- `fire_cooldown`, `water_cooldown`, `earth_cooldown`, `air_cooldown`: tempo entre ataques. Diminuir aumenta a frequencia.
- `fire_range`, `water_range`, `earth_range`, `air_range`: alcance individual dos ataques.
- `level_xp_thresholds`: XP total necessario para os niveis 2 a 5. O valor inicial e `[100, 200, 300, 400]`.
- `element_unlock_levels`: nivel em que cada elemento e liberado. O valor inicial e Fogo 1, Agua 2, Terra 3 e Ar 4.
- `max_level_damage_multiplier`: multiplicador de dano no nivel maximo. O valor inicial e `1.25` (+25%).
- `damage_bonus`, `xp`, `level` e os timers sao estados internos; nao precisam ser editados no Inspector.

Essas propriedades ficam em `scripts/player.gd` e aparecem no Inspector porque usam `@export`.

### Inimigo

Selecione `Enemy.tscn`.

- `max_health`: vida do inimigo. Aumentar torna o inimigo mais resistente.
- `speed`: velocidade de avanco. Aumentar aproxima o inimigo mais rapidamente.
- `contact_damage`: dano causado ao tocar o Avatar.
- `element`: cor identificadora do inimigo quando ele e instanciado.

A wave define o elemento automaticamente; em geral, altere os elementos em `Main`, nao neste valor padrao.

### Essencia

Em `Essence.tscn`, a propriedade `speed` controla a velocidade com que a essencia percorre a esteira.

### Spawn e esteira

No no `Main` de `Main.tscn`:

- `min_spawn_interval`: menor intervalo possivel entre inimigos automaticos.
- `max_spawn_interval`: maior intervalo possivel. Diminuir os dois valores aumenta a frequencia.
- `belt_speed`: velocidade visual do deslocamento das marcas da esteira. O valor inicial e `56.0`, proximo dos `48.0` usados pelos inimigos.

A faixa de spawn inicial e de `1.8` a `2.6` segundos. O gerador usa um novo valor aleatorio a cada inimigo.

### XP e niveis

No no `Main`:

- `min_xp_per_kill` e `max_xp_per_kill`: faixa de XP sorteada a cada inimigo abatido. O valor inicial e de `13` a `20`.

Regras:

- A curva e cumulativa: 100 XP total para o Nivel 2, 200 para o 3, 300 para o 4 e 400 para o 5 (maximo).
- Nivel 1 libera Fogo, Nivel 2 Agua, Nivel 3 Terra e Nivel 4 Ar. O Nivel 5 mostra `MAX` e aplica +25% de dano em todos os elementos, acumulando com o bonus de essencias.
- So inimigos abatidos por ataque dao XP. Inimigos que morrem ao encostar no Avatar contam para a wave, mas nao dao XP. Inimigos gerados pelo debug dao XP se forem abatidos.
- Ao subir de nivel aparece um aviso abaixo dos botoes de elemento. O elemento ativo nao e trocado automaticamente.
- XP e nivel sao mantidos durante a sessao: Game Over, `Jogar novamente` e `Reiniciar partida` nao os zeram. Fechar o jogo zera.

Em uma partida sem dano, o Nivel 2 chega por volta do 7o abate, o 3 por volta do 13o, o 4 por volta do 19o e o 5 por volta do 25o.

### Waves

Ainda no no `Main`:

- `wave_enemy_counts`: quantidade de inimigos de cada wave. O valor inicial e `[5, 7, 8, 10]`.
- `wave_element_options`: elementos permitidos por wave, como `Agua,Terra`.

A ordem dos arrays e:

1. Wave 1: 5 inimigos de Agua.
2. Wave 2: 7 inimigos de Agua ou Terra.
3. Wave 3: 8 inimigos de Fogo.
4. Wave 4: 10 inimigos de Fogo ou Ar.

Nas waves com dois elementos, a escolha e feita novamente a cada spawn.

### HUD, vitoria e derrota

A HUD e construida em `build_hud()` de `scripts/main.gd`. O indicador `Wave X/4`, progresso, vida, nivel, barra de XP, recarga e essencias sao atualizados em `update_hud()`.

As telas reutilizam o painel `defeat_overlay`:

- `show_wave_complete()`: mostra a conclusao e o botao `Proxima wave`.
- `show_final_victory()`: mostra a vitoria final.
- `handle_defeat()`: mostra Game Over e o botao `Tentar novamente`.

## Controles do jogador

- `1`: Fogo.
- `2`: Agua (a partir do Nivel 2).
- `3`: Terra (a partir do Nivel 3).
- `4`: Ar (a partir do Nivel 4).

Elementos bloqueados aparecem com `(NvN)` e o botao fica desabilitado.
- `E`: coleta uma essencia proxima.
- `Q`: consome tres essencias e ativa o bonus manual de dano.
- `F1`: abre ou fecha o painel de debug.

O painel de debug oferece:

- Pausar e continuar.
- Alternar `1x`, `2x` e `3x`.
- Gerar um inimigo manualmente.
- `+100 XP`: adiciona 100 XP (sobe um nivel por clique).
- `Zerar progresso`: volta ao Nivel 1 apenas com Fogo.
- Reiniciar a partida na Wave 1 (mantem XP e nivel).

Inimigos gerados pelo debug nao contam para o total previsto da wave, mas impedem a conclusao enquanto estiverem vivos.

## Fluxo das waves

A partida inicia automaticamente na Wave 1. Cada wave gera somente sua quantidade configurada e para o spawn quando todos foram criados. A conclusao so ocorre depois que todos os inimigos previstos foram derrotados e nao existem inimigos de debug vivos.

Waves intermediarias aguardam o clique em `Proxima wave`. A Wave 4 mostra a tela de vitoria final e nao inicia uma Wave 5. `Tentar novamente` e `Jogar novamente` restauram a partida na Wave 1.

A vida do Avatar, as essencias, o elemento selecionado, o bonus, o XP e o nivel seguem entre waves. O reinicio completo restaura vida, essencias, elemento e bonus, mas mantem XP e nivel.
