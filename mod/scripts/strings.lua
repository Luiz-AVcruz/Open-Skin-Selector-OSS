-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
OSS = OSS or {}

local translations = {
    en = {
        app="Open Skin Selector", pause="Skins", close="Close", skins="Skins", settings="Settings", about="About",
        options_title="Mod options", enabled="On", disabled="Off", auto_restore="Restore skin on entry",
        auto_restore_hint="Applies when entering the next map. Manual selection still works; your saved skin and favorites are kept.",
        saved_skin="Saved skin", no_saved_skin="No saved preference", clear_saved_skin="Clear saved skin",
        clear_saved_skin_hint="Use this if a saved skin causes trouble. Favorites and game progress are kept.",
        saved_skin_cleared="Saved skin cleared. Favorites were kept.", options_hint="These settings work without loading a map, even while the mod is disabled.",
        all="All", game="Game", mods="Mods", favorites="Favorites", search_placeholder="Search skins...",
        favorite_add_short="+ Fav", favorite_saved_short="Fav", skin="Skin", current="Current", saved="Saved", pending="Selected",
        no_skins="No skins are available in this category.", no_description="No description was provided for this skin.", app_about="Choose your own character and keep that choice between sessions.", choose="Select a skin to see its details.", unavailable="Unavailable",
        available="Available", installed="Installed", unavailable_label="Unavailable", selected="Selected", current_label="In use",
        saved_label="Saved preference", apply="Apply", following_game="Follow game selection", applied="Skin preference saved.",
        follow_done="The game now controls your character selection.", idle="Choose a skin and apply it.", saved_status="Preference saved on this device.",
        waiting_session="Waiting for the session to accept the skin...", waiting_catalog="Waiting for the character list...",
        status_unavailable="That skin is not available right now. Your saved preference is kept.",
        release_failed="Preference cleared, but the previous character was not restored. Try Follow game selection again or reload the map.", applying="Applying skin...",
        status_applied="The game confirmed the character selection.", session_accepted="The session accepted your selection.", apply_failed="The game did not apply the skin. Your saved choice is kept.",
        session_timeout="No confirmation from the session. Check that everyone has this mod enabled.", rejected="The session could not use that skin.",
        status_following_game="Following the game's character selection.", settings_title="Settings", language="Language", english="English",
        portuguese="Português (Brasil)", shortcut="Menu shortcut", set_shortcut="Set shortcut", clear="Clear", capture="Press a key. Esc cancels.",
        shortcut_saved="Shortcut saved.", shortcut_cleared="Shortcut cleared.", invalid_key="That key is reserved or unavailable.",
        about_title="About", version="Version %s", author="Luiz-AVcruz", license="AGPL-3.0-or-later",
        permission="Includes the Teardown runtime/API permission.", source="Source: github.com/Luiz-AVcruz/Open-Skin-Selector-OSS",
        workshop="Workshop builds require matching mod files for all players.", details="Details", origin_game="Base game", origin_mod="Mod",
        status="Status", retry_catalog="Refresh list", applying_note="The game confirms character changes through its native character API.",
    },
    pt = {
        app="Open Skin Selector", pause="Skins", close="Fechar", skins="Skins", settings="Configurações", about="Sobre",
        options_title="Opções do mod", enabled="Ativado", disabled="Desativado", auto_restore="Restaurar skin ao entrar",
        auto_restore_hint="Vale ao entrar no próximo mapa. A seleção manual continua disponível; sua skin salva e os favoritos são mantidos.",
        saved_skin="Skin salva", no_saved_skin="Nenhuma preferência salva", clear_saved_skin="Limpar skin salva",
        clear_saved_skin_hint="Use se uma skin salva causar problema. Os favoritos e o progresso do jogo são mantidos.",
        saved_skin_cleared="Skin salva removida. Os favoritos foram mantidos.", options_hint="Estas opções funcionam sem carregar mapa, inclusive com o mod desativado.",
        all="Todas", game="Jogo", mods="Mods", favorites="Favoritos", search_placeholder="Buscar skins...",
        favorite_add_short="+ Fav", favorite_saved_short="Fav", skin="Skin", current="Atual", saved="Salva", pending="Selecionada",
        no_skins="Não há skins disponíveis nesta categoria.", no_description="Esta skin não tem descrição.", app_about="Escolha seu personagem e mantenha a preferência entre partidas.", choose="Selecione uma skin para ver os detalhes.", unavailable="Indisponível",
        available="Disponível", installed="Instalada", unavailable_label="Indisponível", selected="Selecionada", current_label="Em uso",
        saved_label="Preferência salva", apply="Aplicar", following_game="Seguir seleção do jogo", applied="Preferência salva.",
        follow_done="O jogo agora controla a seleção de personagem.", idle="Escolha uma skin e aplique.", saved_status="Preferência salva neste computador.",
        waiting_session="Aguardando confirmação da sessão...", waiting_catalog="Aguardando a lista de personagens...",
        status_unavailable="Essa skin não está disponível agora. A preferência foi mantida.",
        release_failed="Preferência removida, mas o personagem anterior não foi restaurado. Use Seguir seleção do jogo novamente ou recarregue o mapa.", applying="Aplicando skin...",
        status_applied="O jogo confirmou a seleção do personagem.", session_accepted="A sessão aceitou sua escolha.", apply_failed="O jogo não aplicou a skin. Sua escolha salva foi mantida.",
        session_timeout="A sessão não confirmou. Confira se todos estão com este mod ativado.", rejected="A sessão não conseguiu usar essa skin.",
        status_following_game="Usando a seleção de personagem do jogo.", settings_title="Configurações", language="Idioma", english="English",
        portuguese="Português (Brasil)", shortcut="Atalho do menu", set_shortcut="Definir atalho", clear="Limpar", capture="Pressione uma tecla. Esc cancela.",
        shortcut_saved="Atalho salvo.", shortcut_cleared="Atalho removido.", invalid_key="Essa tecla é reservada ou indisponível.",
        about_title="Sobre", version="Versão %s", author="Luiz-AVcruz", license="AGPL-3.0-or-later",
        permission="Inclui permissão para o runtime/API do Teardown.", source="Fontes: github.com/Luiz-AVcruz/Open-Skin-Selector-OSS",
        workshop="No Workshop, todos precisam usar os mesmos arquivos do mod.", details="Detalhes", origin_game="Jogo base", origin_mod="Mod",
        status="Estado", retry_catalog="Atualizar lista", applying_note="O jogo confirma as trocas pela API nativa de personagem.",
    },
}

function OSS.text(key, ...)
    local lang = GetString(OSS.root .. "language")
    if lang ~= "pt" then lang = "en" end
    local value = translations[lang][key] or translations.en[key] or key
    if select("#", ...) > 0 then return string.format(value, ...) end
    return value
end

OSS.translations = translations
