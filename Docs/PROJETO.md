# Open Skin Selector

## Objetivo e decisões

Mod independente de escolha de personagem por **Luiz-AVcruz**, versão **1.2.1**.
O usuário quer manter a skin entre partidas, principalmente na campanha coop,
com código próprio modificável e redistribuível e documentação equivalente à do
Open Session Panel. A estrutura documental parte do Template-Projeto, sem copiar
o histórico Git. Não há dependência entre os dois mods.

Decisões confirmadas: cada pessoa altera somente a própria skin; preferência
pessoal única entre hosts, solo e coop, também após fechar o jogo; selecionar e
aplicar são ações separadas; Esc fecha sem aplicar um rascunho. Inglês padrão e
português brasileiro, autoria pelo nickname, AGPLv3 ou posterior com permissão
adicional para o runtime/API do Teardown, como no OSP. O responsável informou o repositório GitHub do projeto como destino para o fonte.
Publicação no Workshop continua separada do envio ao GitHub.

Fora do escopo: controlar a skin de terceiros pelo menu, desbloquear personagens,
fornecer skins/modelos/vozes/ferramentas, implementar animação própria, integrar
perfis do OSP, migrar preferências do mod anterior ou sincronizar dados pela nuvem.

## Responsabilidades e caminho principal

Lua 5.1, scripting version 2, sem dependências instaláveis para jogar. `main.lua`
inclui somente scripts próprios. Nenhum script do jogo ou do Skin Changer foi copiado.

- **Catálogo:** lê `characters`, incluindo entradas diretas do jogo e entradas
  aninhadas de mods. Resolve textos localizados e remove tags de apresentação.
  Separa presença no catálogo de disponibilidade para escolha pessoal. Os caminhos de prefab são resolvidos pelo motor; `HasFile` não é usado como gate de seleção porque a equivalência com os aliases de `Spawn` não foi demonstrada.
  Personagens da família são disponíveis por padrão; demais personagens respeitam
  flags e chaves de desbloqueio. Não executa a validação do menu nativo, que também
  escreve na seleção nativa. Entradas ocultas desbloqueadas continuam elegíveis.
- **Cliente:** guarda preferência, faz a seleção e aplica escolhas aceitas pela API
  nativa. Não cria corpos, não muda colisões nem atualiza locomotion. A interface
  apresenta atual/salva/rascunho separadamente e trabalha sobre o mesmo catálogo.
- **Servidor:** mantém o estado da sessão e publica um snapshot em `shared.oss`.
  Cada entrada de jogador recebe um marcador; a sessão recebe epoch e componente
  aleatório para distinguir mapas e hosts. A revisão de escolha cresce por entrada.
  Remoções eliminam escolhas antigas, inclusive no reaproveitamento de IDs.

`server.ossChoose(player, session, join, revision, characterId)` aceita somente
jogador existente, sessão/entrada atuais, revisão válida e ID registrado, ou ID
vazio para liberar a escolha. Não aceita caminhos XML pela rede. Desbloqueios são
pessoais: o host não deve rejeitar uma escolha porque não fez o desbloqueio daquele
convidado. A seleção pessoal é verificada no cliente; espectadores precisam dos
assets, não do mesmo progresso.

O cliente recebe `client.ossReply` correlacionado à sessão/entrada/revisão. O
snapshot correspondente também comprova aceitação se a resposta direta se perder.
Mensagens antigas não substituem uma escolha mais nova. Os pedidos são idempotentes
e repetidos por até oito segundos; aplicação nativa é tentada a intervalos de meio
segundo por até oito segundos. Timeout não apaga a preferência. Nova escolha,
retorno de asset ou respawn pode permitir recuperação. Estado já confirmado não
gera chamadas contínuas de troca.

## Persistência, ciclo de vida e recuperação

Somente `savegame.mod.openskinselector` recebe escritas persistentes:

| Chave | Responsável e finalidade |
| --- | --- |
| `character` | Cliente: ID da preferência pessoal; ausência significa seguir o jogo. |
| `language` | Cliente: `en` ou `pt`. |
| `shortcut` | Cliente: atalho opcional; vazio significa nenhum. |
| `auto_restore` | Cliente: restaurar ao entrar no próximo mapa; ausência equivale a ativado. |
| `epoch` | Servidor/host: contador para correlação entre mapas. |
| `favorites.<ID em hexadecimal>` | Cliente: favorito pessoal; IDs são codificados byte a byte para não criar nós de registro acidentais. |

Ao iniciar sem preferência, o mod não captura a seleção nativa como nova preferência
salva. Com preferência, espera jogador/sessão/catálogo, anuncia a escolha e reaplica
quando o motor estiver pronto. Ao morrer, adia a aplicação até o retorno à vida.
Ao mudar de mapa/host, cada cliente reapresenta a própria preferência; o servidor
não guarda uma identidade persistente de convidado.

Ausência de registro ou bloqueio pessoal mantém o ID salvo. O registro não prova que todos os XMLs/assets de terceiros carreguem corretamente; isso depende de teste no motor. O corpo do jogo continua em uso se
não houver aplicação possível; a preferência volta a ser elegível quando o catálogo
retorna. Seguir seleção do jogo limpa apenas `character` e libera o estado da sessão.
Se disponível, restaura o personagem capturado antes da primeira intervenção no mapa;
depois disso, nenhuma preferência própria é forçada. A restauração também exige leitura de confirmação e tem tentativas limitadas; falha de liberação usa uma mensagem própria, sem afirmar que a preferência apagada continua salva. Não depende de callback destroy
de mod global. Para remover: seguir jogo, desativar e recarregar mapa.

O armazenamento local do cliente e a ordenação real de scripts precisam ser
observados no motor. A API não oferece autenticação do remetente de `ServerCall`;
as verificações atendem clientes normais, não clientes adulterados. Não há promessa
de anticheat, identidade de conta ou persistência após apagar dados locais.

## Interface e manutenção

Painel adaptado ao canvas, aberto por Skins no menu de pausa, sem atalho inicial.
Lista filtrável em Todas/Jogo/Mods, miniaturas do runtime e detalhes; Configurações
e Sobre são áreas próprias. Cliques consideram o retângulo visível e o pressionamento,
sem depender de acertar o texto nem repetir ao soltar. O clique que abre o painel
não deve selecionar ou aplicar nada dentro dele. Esc cancela captura de atalho antes
de fechar a janela. Não há ilustração gerada nem preview alegando ser screenshot.

Comandos na raiz do projeto:

```sh
python3 tools/check.py
python3 tools/package.py
```

O check expande includes próprios, verifica sintaxe Lua 5.1 com LuaJIT e executa
testes de contratos e o carregamento do entrypoint completo em contextos servidor/cliente separados. O empacotamento usa a biblioteca padrão Python e valida os
arquivos ZIP por conteúdo, CRC e SHA-256; fontes extraídas devem reproduzir os dois
pacotes. Bibliotecas/fontes usadas para preparar miniaturas não são dependências
do runtime nem do empacotamento.

Distribuição: ZIP instalável, ZIP completo de fontes e SHA256SUMS, com documentação,
testes, ferramentas e licenças correspondentes. `id.txt`, dados de execução, backups,
conversas e arquivos proprietários ficam de fora. A descrição canônica do Workshop
e o manifesto devem conter as mesmas palavras. Não há remoto definido nem upload.

## Evidência e aceitação

A implementação do jogo instalado foi lida em `data/script/playerbody.lua`,
`player_characters.lua`, `script_defs.lua` e no modelo do menu de avatares. Isso
fundamenta o uso de troca nativa e a diferença entre desbloqueio e renderização;
não prova o comportamento ao vivo. A revisão independente identificou o uso indevido
de helpers não incluídos e a confusão entre desbloqueio do host e do convidado;
o núcleo passou a usar APIs nativas de enumeração e validação pessoal separada.

O critério de conclusão da implementação local inclui testes, pacotes e instalação;
isso não converte mocks, propriedade lida ou hash em confirmação visual.

Roteiro de aceitação no jogo, com o seletor antigo desativado:

1. Solo: escolher skin, aplicar, conferir corpo/mãos/ferramentas, andar, agachar,
   entrar/sair de veículo, alternar primeira/terceira pessoa e seguir jogo novamente.
2. Coop: dois participantes escolhem skins diferentes; ambos veem as duas escolhas.
   Testar personagem desbloqueado somente por quem o escolheu, com assets instalados
   nos dois computadores. Adicionar terceiro participante depois das escolhas.
3. Campanha: voltar à base, iniciar missão, morrer/renascer e reconectar. Reabrir o
   jogo e entrar com outro host. Cada pessoa mantém sua preferência sem herdar a
   do ocupante anterior de um ID.
4. Remover temporariamente uma skin, carregar partida e conferir mensagem e alternativa
   nativa; restaurar a skin e confirmar recuperação sem ter de escolhê-la novamente.
5. Conferir UI EN/PT, tamanhos de canvas, rolagem, áreas dos botões, captura/limpeza
   de atalho, Esc e fechamento sem aplicar. Repetir junto do OSP habilitado.

Só registrar suporte coop observado depois dessas ações com dois clientes reais.
O mod e seus assets precisam estar disponíveis em versões compatíveis para todos.

Fontes: [API oficial 2.2.0](https://teardowngame.com/modding/api.html),
[SetPlayerCharacter](https://teardowngame.com/modding/api.html#SetPlayerCharacter),
[guia de mods](https://teardowngame.com/modding/). Consulta em 6 de novembro de 2026.

### Revisão do núcleo e limites da entrega inicial

A revisão independente reconferiu as correções de enumeração nativa, desbloqueio
pessoal, mensagens antigas antes do tick de roster, restauração por readback e
baseline nativa vazia. Não apontou outro bug concreto nesse recorte final. Os
cenários foram incorporados aos testes de regressão. O pedido de liberação não
é anunciado como concluído apenas porque o servidor respondeu: o retorno da
aparência anterior também precisa ser confirmado pela propriedade nativa.

O contexto servidor não recebe funções de UI; o entrypoint deve carregar também
sem tabela `client`. Os testes de UI verificam geometria e entrada simuladas, não
screenshots nem cliques observados no Teardown. As prévias usam a logo fornecida pelo autor, ajustada proporcionalmente sobre
fundo preto; não representam a aparência do menu no jogo.

Nenhuma partida foi aberta ou automatizada nesta entrega. Troca visível do corpo,
mãos e animações, persistência no disco real de cada cliente, transições da
campanha e coop com dois computadores continuam pendentes do roteiro acima.
O fonte próprio e a instalação local são preparações verificáveis para esse teste,
sem promessa de compatibilidade visual universal com skins de terceiros.

### Evidência local da versão 1.0.0

- `python3 tools/check.py` passou: sintaxe Lua 5.1, 63 assertivas do núcleo
  (incluindo carregamento do entrypoint servidor/cliente) e testes de interface.
  São assertivas de contratos locais, não 63 cenários executados no motor.
- O teste de UI preserva as transformações de coordenadas de `UiPush`, `UiTranslate`,
  `UiPop` e `UiGetMousePos`. Cobre seleção/aplicação, fechamento sem aplicar, filtros,
  personagens ocultos desbloqueados, retry, liberação durante espera, troca EN/PT,
  captura/cancelamento/limpeza de atalho, clipping e rolagem em viewport estreita.
- Os ZIPs de instalação e fontes incluem as licenças correspondentes e hashes.
  O pacote de fontes é conferido por extração, execução dos checks e reprodução
  dos dois arquivos ZIP. Essa prova depende dos arquivos da distribuição, não de
  scripts ou dados pessoais externos à árvore de fontes.
- Cópia local instalada em pasta própria, com 14 arquivos relidos e comparados ao
  ZIP instalável. O mod do Workshop, a instalação do OSP e os arquivos de save,
  opções e lista de mods permaneceram inalterados. Não houve ativação automática,
  reinício de sessão nem publicação.
- Backup inicial compactado e verificado e recibo de instalação ficam no backup
  central de Teardown do responsável, fora do projeto e dos pacotes.
- Repositório Git local iniciado na branch `main`, sem commits e sem remoto.

Para começar a aceitação: habilitar Open Skin Selector nos mods locais, manter o
seletor antigo desativado e carregar um mapa. Abrir Skins na pausa e realizar os
passos solo e coop do roteiro acima. Essa observação permanece pendente.

### Logo fornecida pelo autor

A logo enviada em 6 de novembro de 2026 substitui as prévias tipográficas iniciais.
O original de 612 × 317 foi preservado. A conversão de formatos e dimensões gera
`mod/preview.jpg` em 512 × 512 (JPEG abaixo de 1 MB) e `mod/preview-menu.png` em
512 × 292, com proporções preservadas, centralização e margens pretas. O nome
público do mod continua Open Skin Selector; o texto da arte fornecida é mantido.

README, descrição canônica e manifesto acompanham a nova origem da imagem, sem
atribuir um processo de criação à logo enviada. A mudança não altera o Lua nem
a versão 1.0.0. Os pacotes e a cópia instalada recebem as novas prévias e metadados.
Não houve publicação no Workshop.

### Interface, pesquisa e favoritos — 1.1.0

O usuário forneceu uma captura real do seletor em uso: o botão de seguir a seleção
do jogo invadia a região da barra lateral; o estado era desenhado sobre as últimas
linhas; nomes longos podiam ocupar o subtítulo da linha. A captura comprova a
renderização dessa interface no motor, sem comprovar corpo/animação nem persistência
entre missões ou coop de dois participantes.

A revisão alinha o rodapé ao conteúdo, reserva espaço exclusivo para a mensagem de
estado e limita o texto de cada linha para preservar a separação entre nome e
metadados. A janela, os detalhes e o rodapé devem continuar acessíveis em EN/PT
nos canvases verificados. A seleção pendente continua exigindo Aplicar.

Pesquisa por nome usa o campo de texto nativo `UiTextInput`, com solicitação de
foco por um frame e leitura de foco retornado pelo motor. `focus=false` não é
tratado como comando de desfoco. O texto não é salvo a cada tecla. A busca é parcial,
literal, sem distinção de maiúsculas e com normalização dos acentos portugueses
comuns; não é anunciado um algoritmo universal de case folding Unicode. Esc fecha
a janela sem aplicar a escolha pendente, inclusive enquanto o campo estiver ativo.
O atalho do menu não deve disputar digitação com o campo.

Cada linha permite favoritar sem selecionar ou aplicar. O filtro Favoritos combina
com a pesquisa. Favoritos são booleans em `savegame.mod.openskinselector.favorites`
por ID codificado em hexadecimal; não dependem da skin atualmente aplicada nem de
ID temporário de jogador. Ausência de entrada significa não favorito. Não há
migração nem limpeza de favoritos de skins que saíram temporariamente do catálogo.
A normalização da busca não é usada para identificar favoritos: IDs diferentes
continuam sendo entradas independentes.

Instalar a atualização com o jogo aberto não atualiza o Lua já carregado. É preciso
recarregar o mapa para observar a revisão. A entrega não reinicia nem automatiza
a partida, e não altera saves, configuração de mods ou os arquivos do OSP.

#### Verificação da revisão 1.1.0

`python3 tools/check.py` passou com 63 assertivas do núcleo/entrypoint e os testes
de interface. O mock do campo nativo mantém foco quando recebe `focus=false`,
como exige o contrato; o teste não depende de uma falsa operação de blur. Os
casos incluem busca literal por `%`, caixa e acentos, pesquisa com filtro de
origem/Favoritos, favoritar/desfavoritar sem selecionar/aplicar, nova instância
Lua, skin favorita ausente/retornando e preservação de configurações alheias.
O layout foi exercitado em 640×480, 1024×768, 1920×1080 e 1440×900.

Prévia simulada renderizada a partir das chamadas de desenho do Lua e das fontes
locais do Teardown: inspecionados EN em 1280×900, PT em 1024×768 e 640×480 e uma
busca preenchida. O rodapé fica na coluna de conteúdo e o estado tem espaço
reservado. Detalhes compactos têm clipping próprio; descrições são omitidas
quando não cabem. Os resultados em `dist/previews/1.1.0-*.png` são simulações,
sem thumbs de skins, não screenshots do jogo nem prova de foco nativo observado.

A atualização local preserva arquivos de Workshop, saves/configuração e OSP.
O jogo aberto não foi fechado ou recarregado automaticamente. Recarregar o mapa
é necessário antes de testar cliques, foco/digitação e favoritos no motor. Os
ZIPs atuais são `OpenSkinSelector-1.1.0.zip` e `OpenSkinSelector-1.1.0-source.zip`.

### Opções no gerenciador e nome da cópia local — 1.2.0

O pedido é configurar antes de carregar mapa e corrigir o nome na lista de
habilitar/desabilitar mods. O gerenciador nativo usa `.listname` para essa lista,
enquanto o título detalhado usa `.name`; o log já registrava Open Skin Selector
com espaços, mas a pasta local técnica era OpenSkinSelector. A cópia instalada
e a raiz do ZIP passam a **Open Skin Selector**, sem criar outra cópia. O workspace
continua OpenSkinSelector. Embora o prefixo lógico do código seja estável, o motor adiciona o ID do mod
ao armazenamento físico: uma renomeação pode expor outro perfil. Não se presume
transferência automática dos dados entre IDs. Um novo ID de mod local pode exigir ativação após reiniciar; não
se reescrevem listas de mods com um ID presumido.

`mod/options.lua` é um entrypoint clássico com `draw()`, como especificado no guia
oficial. Inclui somente helpers próprios e traduções, sem `client`, `server`,
catálogo, RPC ou APIs de personagem. O gerenciador o oferece por existir esse
arquivo, independentemente do mod estar habilitado. Idioma e atalho compartilham
as mesmas chaves da interface em partida e uma validação única de atalho.

O controle de restauração automática vem ativado quando não há valor salvo.
Desativá-lo impede o mod de anunciar/aplicar a preferência ao iniciar outro mapa,
sem apagar a skin ou os favoritos. Selecionar manualmente continua possível.
A opção também aparece em Configurações durante o mapa, com efeito na próxima
entrada. Limpar skin salva, disponível no gerenciador, apaga somente `character`;
não executa troca de modelo ou comandos de sessão no menu principal.

Testes locais: sintaxe dos dois entrypoints, 15 assertivas das opções sem contexto
de partida e 66 assertivas do núcleo, além do conjunto de UI. Foram cobertos
idioma/atalho, captura/cancelamento, proteção de teclas de movimento, clipping e
rolagem, recuperação preservando favoritos/progresso, padrão compatível sem chave,
auto-restore desligado em contexto novo e seleção manual continuando no coop
simulado. Isso não é prova de cliques/renderização observados no menu nativo.

Repositório informado pelo responsável:
https://github.com/Luiz-AVcruz/Open-Skin-Selector-OSS.git . Remoto `origin`, branch
`main`, autoria Luiz-AVcruz com email público noreply. O envio inicial usa push
normal, sem force, depois dos checks e da inspeção do conteúdo; não publica no
Workshop. Backups, `id.txt`, artefatos de runtime e dados pessoais não entram no Git.

### Correção de captura de atalho — 1.2.1

Relato no jogo: nas Opções do gerenciador e em Configurações na partida, o pedido
para pressionar uma tecla aparecia, mas uma tentativa encerrava a captura sem
mostrar ou salvar a tecla. O usuário confirmou que o recurso equivalente do OSP
funcionava. A comparação com o OSP instalado e com `input_options_logic.lua` do
jogo mostrou leitura direta de `InputLastPressedKey`, eventos de mouse ignorados
e captura mantida após rejeição. O OSS dependia de `InputPressed("any")` e encerrava
a captura rejeitada; na UI da partida, seu aviso era escrito em um estado que
não aparecia ao lado do controle e podia ser substituído pelo estado da skin.

O helper compartilhado passa a ler eventos físicos específicos e o canal da
última tecla, sem depender de `any`. Isso atende entrega por canais independentes
ou um canal de última entrada ainda indicando mouse. Sem tecla ou com mouse, a
captura continua; Esc cancela; uma tecla rejeitada mostra o valor e mantém a
captura; uma tecla válida salva e confirma o valor. As restrições anteriores de
teclas de movimento são preservadas. A UI lê também no draw para suportar a fase
de entrega de entrada; o estado torna a confirmação idempotente entre tick/draw.
A tecla salva alterna abrir/fechar fora da pesquisa, sem fechar ao ser capturada.

Regressão: os testes atualizados falham contra o código 1.2.0 na captura do
gerenciador quando a última tecla chega sem o flag `any`. Passam com a correção.
Foram incluídos eventos vazios/agregados, mouse, tecla rejeitada seguida de válida,
evento físico com última entrada de mouse, confirmação no draw e mudança no
entrypoint real de opções refletida em um novo contexto real da UI de jogo.
Os testes locais abrangem 23 assertivas das opções, 66 do núcleo e o conjunto UI.
Isso prova os contratos simulados, não o teclado observado em uma partida real;
a causa exata de cada tecla rejeitada no relato ainda não foi registrada no motor.

A inspeção do save local revelou isolamento adicional pelo ID do mod:
`savegame.mod.local-openskinselector.openskinselector` e
`savegame.mod.local-open-skin-selector.openskinselector` são perfis diferentes.
A suposição anterior de independência do nome da pasta estava incorreta. Com o
jogo fechado e backup compactado/verificado, foram recuperados somente os campos
pessoais ausentes `character` e `favorites` do perfil antigo para o destino ainda
novo; valores novos existentes, perfil antigo, OSP e o restante do save foram
preservados. O contador de sessão não foi migrado. A recuperação é local a esta
instalação e não é uma migração automática embutida no mod.

O save usa nomes de nós numéricos aceitos pelo Teardown e rejeitados por parsers
XML convencionais. Para conferir a preservação, somente a representação em
memória normalizou esses nomes. A escrita final inseriu fragmentos originais
apenas no corpo do perfil de destino, sem reserializar ou normalizar o restante
do arquivo. Um recibo com hashes e campos recuperados fica no backup central.

### Descrição no padrão do OSP

A pedido do responsável, a descrição usa o mesmo template do Open Session Panel:
resumo funcional em um parágrafo, Source code e AI Disclosure and Usage. O resumo
foi adaptado ao seletor de skins e o link aponta para Open-Skin-Selector-OSS. O
bloco AI Disclosure and Usage foi copiado integralmente do OSP, sem reescrita.
A versão continua 1.2.1; trata-se apenas de texto e metadados. A cópia instalada
e os pacotes são atualizados juntos; upload ao Workshop é uma etapa separada.
