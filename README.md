# Elemental Idle Runner

## Visao geral

Elemental Idle Runner e um auto-battler 2D side-scroller feito com Godot 4.7 e GDScript. O Avatar escolhe elementos, ataca automaticamente, coleta essencias manualmente e atravessa uma campanha de cinco regioes.

A cena principal e `res://scenes/Main.tscn`.

## Como executar

1. Abra a pasta na Godot 4.7.
2. Pressione `F5` para iniciar o projeto ou `F6` com `Main.tscn` aberta.
3. Consulte o painel **Debugger** e o console da Godot para erros de execucao.

A campanha comeca pela tela inicial, no botao `Iniciar jornada`.

## Estrutura

### Cenas

- `scenes/Main.tscn`: fundo, tiles, Avatar e coordenacao da campanha. HUD e telas sao criadas por `main.gd`.
- `scenes/Player.tscn`: Avatar, `Sprite2D` e `HealthBar`.
- `scenes/Enemy.tscn`: inimigo reutilizavel, `Sprite2D` e barra de vida individual.
- `scenes/Projectile.tscn`: projeteis elementais; textura e impacto sao configurados por `projectile.gd`.
- `scenes/Essence.tscn`: essencia coletavel.
- `scenes/DebugPanel.tscn`: controles de teste.
- `scenes/ShopPanel.tscn`: loja de melhorias da sessao.
- `scenes/Tornado.tscn` e `scenes/MudPatch.tscn`: efeitos visuais de melhorias.

### Scripts principais

- `scripts/main.gd`: campanha, waves, spawn, combate, HUD, mapas, transicoes, Game Over e vitoria.
- `scripts/player.gd`: vida, elementos, recargas, XP, niveis e melhorias.
- `scripts/enemy.gd`: vida, movimento, elementos, status, dano e morte.
- `scripts/projectile.gd`: movimento e sinal de impacto.
- `scripts/essence.gd`: movimento da essencia.
- `scripts/debug_panel.gd`: pausa, velocidade, spawn manual, XP e reinicio.
- `scripts/shop_panel.gd` e `scripts/upgrade_catalog.gd`: loja e catalogo de melhorias.
- `scripts/tornado.gd`, `scripts/mud_patch.gd` e `scripts/area_effect.gd`: efeitos especiais visuais.

### Assets

- Personagens: `assets/characters/`.
- Projeteis: `assets/projectiles/`.
- Essencia: `assets/items/`.
- Mapas: `assets/environment/water/`, `earth/`, `fire/`, `air/` e `equilibrium/`.

Cada mapa possui `background.svg` e `ground.svg`.

## Campanha de cinco fases

As configuracoes ficam como propriedades exportadas no no `Main` de `Main.tscn`, em `scripts/main.gd`:

```gdscript
wave_enemy_counts = [5, 7, 8, 10, 12]
wave_element_options = ["Agua", "Terra", "Fogo", "Ar", "Fogo,Agua,Terra,Ar"]
```

As waves sao:

1. **Floresta de Agua**: 5 inimigos de Agua.
2. **Montanha de Terra**: 7 inimigos de Terra.
3. **Vulcao de Fogo**: 8 inimigos de Fogo.
4. **Templo do Ar**: 10 inimigos de Ar.
5. **Santuario do Equilibrio**: 12 inimigos, escolhidos entre os quatro elementos a cada spawn.

Uma wave so termina quando todos os inimigos previstos foram gerados e derrotados, e nao existem inimigos de debug vivos. A proxima fase so inicia pelo botao `Proxima fase`.

O mapa e trocado por `apply_map()` e usa um fade curto durante a transicao. A Wave 5 termina com a tela de vitoria; nao existe Wave 6.

## Repetir a fase atual

O botao `Tentar novamente` do Game Over chama `retry_current_wave()`:

- Mantem a wave em que o Avatar morreu.
- Limpa inimigos, projeteis e efeitos da tentativa anterior.
- Restaura a vida e as recargas do Avatar.
- Restaura as essencias existentes no inicio da wave.
- Descarta essencias coletadas somente durante a tentativa perdida.
- Zera os contadores locais da wave.

A vida atual e os demais recursos permanecem entre fases quando o jogador avanca normalmente. O reinicio do painel de debug inicia uma nova campanha na Wave 1.

## Barras de vida

`Player.tscn` e `Enemy.tscn` possuem um `ProgressBar` filho chamado `HealthBar`.

- A barra do Avatar tem aproximadamente 84 pixels.
- A barra dos inimigos tem aproximadamente 54 pixels.
- Nenhuma barra exibe numeros.
- O valor usa `health` e `max_health` reais.
- Verde: acima de 50%.
- Amarelo: entre 25% e 50%.
- Vermelho: abaixo de 25%.

Para mudar a posicao ou o tamanho, selecione `HealthBar` na cena correspondente. As cores e estilos sao criados em `setup_health_bar()` dos scripts `player.gd` e `enemy.gd`. A barra do inimigo e ocultada no inicio de `die()`.

## Balanceamento

### Avatar

No `Player` de `Player.tscn` ou `Main.tscn`:

- `max_health`: vida maxima.
- `fire_damage`, `water_damage`, `earth_damage`, `air_damage`: dano base.
- `fire_cooldown`, `water_cooldown`, `earth_cooldown`, `air_cooldown`: tempo entre ataques.
- `fire_range`, `water_range`, `earth_range`, `air_range`: alcance.
- `level_xp_thresholds`: XP necessario para os niveis seguintes.
- `element_unlock_levels`: nivel de liberacao de Agua, Terra e Ar.
- `max_level_damage_multiplier`: bonus de dano no nivel maximo.
- `water_slow_factor`, `water_slow_duration`, `earth_stun_duration` e `air_push_distance`: efeitos basicos.

Diminuir cooldown aumenta a frequencia de ataques; aumentar `max_health` permite sobreviver a mais contatos.

### Inimigo

Em `Enemy.tscn`:

- `max_health`: vida padrao.
- `speed`: velocidade de movimento.
- `contact_damage`: dano de contato.
- `element`: cor e elemento padrao.

O `Main` substitui `element` quando cria inimigos de uma wave.

### Spawn e esteira

No no `Main`:

- `min_spawn_interval` e `max_spawn_interval`: faixa dos intervalos aleatorios.
- `belt_speed`: velocidade visual da esteira, inicialmente `56.0`.
- A velocidade base dos inimigos esta em `Enemy.tscn` como `48.0`.

O spawn nao e um `Timer`: `enemy_timer` e decrementado em `_process()` e recebe novo valor aleatorio apos cada inimigo.

### Essencias, XP e loja

- `Essence.tscn`: `speed` controla a movimentacao da essencia.
- `Main`: `min_xp_per_kill` e `max_xp_per_kill` controlam XP por abate.
- `Player`: `element_xp`, `level_xp_thresholds` e `upgrade_levels` controlam progressao da sessao.
- `upgrade_catalog.gd`: nomes, custos e valores das melhorias.

A tecla `P` abre a loja e pausa a simulacao. O painel de debug possui controles de XP, vida dos inimigos e zerar progresso.

## Controles

- `1`, `2`, `3`, `4`: selecionar Fogo, Agua, Terra e Ar quando liberados.
- `E`: coletar essencia proxima.
- `Q`: consumir tres essencias e ativar bonus manual.
- `P`: abrir/fechar loja.
- `Esc`: fechar loja.
- `F1`: abrir/fechar painel de debug.

O painel de debug permite pausar, alternar `1x`, `2x` e `3x`, gerar inimigo, testar XP, ajustar vida dos inimigos e reiniciar a campanha na Wave 1.

## Telas e fluxo

- `show_start_screen()`: tela inicial e botao `Iniciar jornada`.
- `show_wave_complete()`: mostra regiao concluida e proxima regiao.
- `handle_defeat()`: mostra Game Over e `Tentar novamente`.
- `show_final_victory()`: encerra a campanha e oferece `Jogar novamente`.
- `build_hud()` e `update_hud()`: constroem e atualizam a HUD de combate.

Todas as telas reutilizam `defeat_overlay`, mantendo a interface simples e consistente.

## Animacoes e feedback visual

O Avatar e os inimigos usam um ciclo procedural de caminhada em seus scripts. As pernas visuais `LegLeft` e `LegRight` alternam a rotacao enquanto o personagem esta ativo. O sprite tambem recebe uma oscilacao pequena, sem alterar a posicao logica usada pelo combate.

A prioridade visual e: morte, dano, ataque, caminhada e parado. Tweens anteriores sao encerrados antes de iniciar uma reacao concorrente. Dano interrompe ataque/caminhada temporariamente; ao terminar, o personagem retorna ao ciclo. Inimigos atordoados param a caminhada e inimigos mortos interrompem o processamento antes do fade de morte.

- Avatar: `play_attack_feedback()` e `play_damage_feedback()` em `scripts/player.gd`.
- Inimigo: `play_damage_feedback()` e `die()` em `scripts/enemy.gd`.
- Membros visuais: `LegLeft` e `LegRight` em `Player.tscn` e `Enemy.tscn`.

## HUD atual

A HUD principal e construida em `build_hud()` de `scripts/main.gd`:

- Superior esquerdo: nivel, XP, wave, regiao e barra de progresso da fase.
- Superior direito: contador compacto de essencias e botao `P Loja`.
- Parte inferior: quatro botoes compactos com icones SVG e teclas `1` a `4`; o botao selecionado recebe escala e destaque.
- Dica contextual: `E Coletar`, `Q Bonus` e `F1 Debug`; E e Q ganham destaque quando podem ser usados.
- Bonus: painel visual temporario, exibido somente enquanto o bonus estiver ativo.

A vida do Avatar foi removida da HUD principal porque continua visivel na `HealthBar` flutuante de `Player.tscn`. Os textos de recarga tambem nao sao adicionados visualmente; os timers continuam funcionando em `player.gd`.

A HUD nao possui um painel permanente separado para o elemento selecionado: a selecao e indicada diretamente pelo botao elemental correspondente.

Os icones elementais ficam em `assets/elements/` e sao associados pela constante `ELEMENT_TEXTURES` de `main.gd`. Para trocar um icone, substitua o SVG mantendo o mesmo caminho ou atualize essa constante.
