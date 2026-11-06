# Open Skin Selector

An independent Teardown skin selector by **Luiz-AVcruz**, version **1.2.0**.
Choose your own character during gameplay and retain that preference between
missions, campaign co-op sessions, hosts and game restarts. English is the default;
Brazilian Portuguese is available in Settings.

## Use and installation

Extract `dist/OpenSkinSelector-1.2.0.zip` into Teardown's local mods directory
(`Documents/Teardown/mods`) as the folder **Open Skin Selector** and enable it.
For an existing installation named `OpenSkinSelector`, rename that folder before
extracting the update into it; keep one copy and preserve `id.txt` if published.
The workspace and ZIP filenames may retain the technical spelling without spaces.
Open **Skins** from
the pause menu. Select a character, inspect its details, then press **Apply**.
Closing the menu or pressing Esc cancels only the selection that has not been
applied. An optional menu shortcut can be configured in Settings; none is assigned
initially. About contains authorship, version and licensing information.

Search by name with the native text field. Matching is literal, case-insensitive
and ignores common Portuguese accents. Combine it with All / Game / Mods / Favorites.
Each row has a favorite control: adding or removing a favorite does not select or
apply that skin. Favorites are personal and persist between sessions, including
preferences for temporarily absent skins. Clearing search restores the current
category. Escape closes the menu without applying the draft selection.

Each player chooses only their own skin. The preference lives on that player's
device, not in a profile owned by the host. Keep the mod enabled in subsequent
sessions to restore it. An unregistered or locked skin does not erase the preference;
the game keeps its character until the saved skin becomes available again.
**Follow game selection** removes the mod's preference and releases its current
override, restoring the character captured before that override when available.
After release, the mod no longer forces a character.

The catalog reads registered base-game and mod skins, preserving personal unlocks
and DLC requirements for selection. Participants need the relevant character
assets to see one another's skins. A viewer does not need to have personally
unlocked another player's character, but must have the corresponding assets.
Catalog registration is not proof that a third-party XML or model loads correctly;
asset resolution and visible results must be checked in the game. No models, skins
or proprietary game scripts are bundled. Special abilities,
voices and tools supplied by another character mod remain that mod's responsibility.

Disable other in-game skin changers while testing. **Open Session Panel** is an
independent mod and is not required; this selector changes no health, inventory,
permissions, campaign progress or OSP data. Reload the map after updating scripts.
Normal multiplayer distribution requires matching enabled mod files for everyone;
Workshop publication is a separate action and has not been performed here.

## Options before loading a map

From the main menu, open **Play → Mods**, select **Open Skin Selector** and
choose **Options**. This standalone screen works even with the mod disabled.
Change language or the optional shortcut, disable **Restore skin on entry**
(default: on), or clear the saved skin if it causes trouble. Disabling automatic
restoration keeps your saved skin and favorites; you can still select a skin
manually in a map. The toggle also exists in the in-game Settings and takes effect
on the next map. Clearing a saved skin removes only that preference.

Restart the game after this update so the manager rescans the folder name and new
options entry point. A renamed local folder may need enabling again. No second
copy is required.

## Storage and recovery

All persistent writes belong to `savegame.mod.openskinselector`: `character` is
the personal preferred character ID; `language` and `shortcut` are local UI
preferences; `favorites.<hexadecimal character ID>` stores personal favorites as
boolean values; `auto_restore` controls next-entry restoration (missing means on);
`epoch` is a host-side session counter. Search text is temporary
and is not saved to disk. Existing preferences require no migration. The mod does not write
`savegame.player.character`, character unlocks or the save data of other mods.
There is no migration or dependency on In-Game Skin Changer saves.

For removal, choose **Follow game selection**, disable this mod and reload the map.
Its own preference can remain in the save without affecting gameplay. Do not edit
or delete campaign saves to remove it. Reinstallation restores a retained preference
unless it was cleared with Follow game selection. Local storage is not Steam account
identity or a cloud synchronization service; losing local saves loses the preference.

## Development and distribution

Runtime: Teardown Lua 5.1, scripting version 2. No Python or LuaJIT is needed to play.
Developer checks require Python 3 and LuaJIT:

```sh
python3 tools/check.py
python3 tools/package.py
```

The packager builds a reproducible installation ZIP, a full matching source ZIP and
`SHA256SUMS`, checking archive content against the source files. The source ZIP
contains the Lua, tests, development tools, project instructions, documentation,
previews and licensing notices. There is no compilation, obfuscation or minification.
Source repository: [https://github.com/Luiz-AVcruz/Open-Skin-Selector-OSS](https://github.com/Luiz-AVcruz/Open-Skin-Selector-OSS). Distribute the complete matching source
archive alongside the installation archive according to the license.

`mod/WORKSHOP-DESCRIPTION.txt` is the canonical release description; the same words
are stored in `info.txt` on one line. The previews use the logo supplied by Luiz-AVcruz, fitted proportionally on a black
background: 512 × 512 JPEG for Workshop and 512 × 292 PNG for the mod menu.
They are branding images, not game screenshots.
`id.txt` is excluded from distributions and must be preserved separately when
updating an already published Workshop item.

## Verification

Contract tests exercise isolated server/client contexts, storage across fresh Lua
VMs, delayed requests/replies, entry and session correlation, recycled player IDs,
late joins, missing assets, personal unlocks, respawn and bounded native retries.
UI tests simulate input and layout. These checks **do not prove game rendering,
native character replacement, actual client-side disk persistence or real co-op**.

The implementation uses native `SetPlayerCharacter`; it does not create replacement
bodies or take over locomotion. The installed game implementation was inspected
to understand that boundary. A successful property readback is not proof that the
visible body, hands or animations changed correctly. The server cannot authenticate
the sender of a supplied player ID through the documented `ServerCall` API; this
is a cosmetic mod for normal game clients, not anti-cheat enforcement.

See [project notes and game acceptance checks](Docs/PROJETO.md) for evidence and gaps.

## License

Copyright (C) 2026 **Luiz-AVcruz**. Original code: **AGPL-3.0-or-later** with the
additional permission for integration with the Teardown runtime/API. Read
[LICENSE](LICENSE), [ADDITIONAL-PERMISSION](ADDITIONAL-PERMISSION) and
[source notice](mod/SOURCE.md). This grants no rights to redistribute Teardown or
third-party skin assets.

## Português

Abra **Skins** no menu de pausa, selecione um personagem e clique em **Aplicar**.
Antes de carregar mapa, abra **Jogar → Mods → Open Skin Selector → Opções**.
Ali é possível mudar idioma/atalho, desligar a restauração automática e limpar uma
skin salva problemática sem apagar favoritos. A pasta instalada agora se chama
**Open Skin Selector**, com espaços; mantenha somente uma cópia e confira sua
ativação após reiniciar o jogo.

Em Configurações é possível mudar o idioma e definir um atalho opcional. Esc e
Fechar descartam somente a seleção ainda não aplicada.

Cada pessoa guarda a própria preferência no computador, válida entre missões,
hosts e reinícios. Skins ausentes ou bloqueadas preservam a preferência salva;
**Seguir seleção do jogo** remove essa preferência e encerra a reaplicação.
A pesquisa por nome combina com os filtros Todas/Jogo/Mods/Favoritos e ignora
maiúsculas e acentos portugueses comuns. Marcar um favorito não seleciona nem
aplica a skin. Os favoritos ficam salvos por pessoa, inclusive se uma skin estiver
temporariamente ausente. Outros jogadores precisam dos
assets para ver a skin, sem depender de terem feito o mesmo desbloqueio pessoal.

Extraia o ZIP de instalação na pasta de mods locais e habilite o mod. Desative o
Skin Changer anterior durante o teste e recarregue o mapa após atualizações. O OSP
permanece separado. Os testes automatizados demonstram contratos locais, não uma
partida coop observada. O roteiro de aceitação e os limites estão em `Docs/PROJETO.md`.
