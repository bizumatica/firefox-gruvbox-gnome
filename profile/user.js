/*****************************************************************************
 * USER.JS AGNÓSTICO — Firefox / Floorp / Zen Browser
 * Base: Betterfox (yokoffing/Betterfox), última release que consultei: 152
 * Revisado em 06/10/2026 para Firefox 157.
 * Foco: leveza, zero telemetria, compatibilidade multi-fork, hardware modesto.
 *
 * COMO USAR
 * ---------
 * 1. Feche o navegador por completo antes de editar.
 * 2. Copie para a pasta do perfil (about:support > Pasta do perfil)
 *    ou, no Zen portátil, para Data/profile/user.js.
 * 3. Reabra e confira em about:support > "Preferências Modificadas".
 * 4. Faça backup do perfil antes de aplicar.
 *
 * COMO FUNCIONA
 * -------------
 * - O user.js é reaplicado a CADA inicialização: mudar uma pref pela
 *   interface não persiste enquanto a linha existir aqui.
 * - Para desfazer uma pref: apague a linha E clique em "Redefinir" no
 *   about:config (apagar a linha sozinho não restaura o padrão).
 * - O formato NÃO é JavaScript: só linhas user_pref("nome", valor);
 *   com valores literais. Não há variáveis nem condicionais.
 *
 * MARCAÇÕES
 * ---------
 * [FF-UI]       só tem efeito visível em Firefox/Floorp (o Zen substitui o componente)
 * [ZEN-CUIDADO] pode conflitar com recursos nativos do Zen; revise antes
 * [VERIFICAR]   pref que não consegui confirmar na versão atual; confira
 *               no about:config se ela existe (nome em negrito = existe)
 *****************************************************************************/

/*****************************************************************************
 *****************************************************************************
 **                                                                         **
 **   >>>  ESCOLHA O PERFIL DE MEMÓRIA — MEXA SÓ AQUI  <<<                  **
 **                                                                         **
 **   Deixe SÓ UM dos dois blocos ativo (sem "//" no começo das linhas)     **
 **   e o outro comentado (com "//"). Para trocar: comente um, descomente   **
 **   o outro, reinicie o navegador.                                        **
 **                                                                         **
 *****************************************************************************
 *****************************************************************************/

/* ==== PERFIL A — 8 GB de RAM ou mais, com SSD  [ATIVO] ====================
 * Cache em RAM: menos escrita em disco, navegação mais ágil.             */
// user_pref("browser.cache.disk.enable", false);
// user_pref("media.memory_cache_max_size", 65536);

/* ==== PERFIL B — 6 GB de RAM ou menos, ou HDD  [DESLIGADO] ================
 * Cache em disco: poupa RAM. Para usar: COMENTE as 2 linhas do Perfil A
 * acima e TIRE o "//" das linhas abaixo.                                  */
user_pref("browser.cache.disk.enable", true);
user_pref("browser.cache.disk.capacity", 358400);   // ~350 MB (em KB)
user_pref("media.memory_cache_max_size", 32768);
user_pref("browser.sessionstore.max_tabs_undo", 5);
/* Extra para máquinas bem fracas (economiza RAM, mas deixa a troca entre
 * muitas abas mais lenta). Descomente só se ainda estiver pesado: */
// user_pref("dom.ipc.processCount", 2);

/*****************************************************************************
 * FASTFOX — desempenho (moderado)
 * O próprio Betterfox removeu a maior parte dessas prefs por ganho pequeno
 * e voltou só com algumas "de baixo risco" na 152. Aqui ficam as seguras.
 *****************************************************************************/
user_pref("gfx.content.skia-font-cache-size", 20);
user_pref("content.notify.interval", 100000);

/** Cache de mídia ***/
user_pref("media.cache_readahead_limit", 3600);
user_pref("media.cache_resume_threshold", 1800);

/** Cache de imagem ***/
user_pref("image.mem.decode_bytes_at_a_time", 32768);

/** Rede ***/
user_pref("network.buffer.cache.size", 65535);
user_pref("network.buffer.cache.count", 48);
user_pref("network.http.max-connections", 1800);
user_pref("network.http.max-persistent-connections-per-server", 10);
user_pref("network.http.max-urgent-start-excessive-connections-per-host", 5);
user_pref("network.http.request.max-start-delay", 5);

/** REMOVIDAS nesta revisão (ver lista de mudanças):
 *  gfx.canvas.accelerated.cache-size   → o Betterfox agora a trata como RESET;
 *       valor alto consome mais memória. Redefina no about:config.
 *  javascript.options.baselinejit.threshold → compila mais cedo, gasta mais
 *       CPU/RAM; prejudica justamente máquinas fracas.
 *  network.dnsCacheExpiration (3600)   → cache de DNS de 1h pode manter
 *       endereço velho após mudança; ganho mínimo (o SO também faz cache).
 ***/

/*****************************************************************************
 * SECUREFOX — privacidade e segurança
 *****************************************************************************/
/** Proteção contra rastreamento ***/
user_pref("browser.contentblocking.category", "strict");
user_pref("browser.download.start_downloads_in_tmp_dir", true);
user_pref("browser.uitour.enabled", false);
user_pref("privacy.globalprivacycontrol.enabled", true);

/** OCSP, CSP, certificados ***/
user_pref("security.OCSP.enabled", 0);
user_pref("privacy.antitracking.isolateContentScriptResources", true);
user_pref("security.csp.reporting.enabled", false);

/** SSL / TLS ***/
user_pref("security.ssl.treat_unsafe_negotiation_as_broken", true);
user_pref("browser.xul.error_pages.expert_bad_cert", true);
user_pref("security.tls.enable_0rtt_data", false);

/** Cache em disco x RAM: definido no bloco "ESCOLHA O PERFIL" no topo. ***/
user_pref("browser.privatebrowsing.forceMediaMemoryCache", true);
user_pref("browser.sessionstore.interval", 60000);

/** Histórico ***/
user_pref("privacy.history.custom", true);

/** Carregamento especulativo (privacidade > velocidade percebida) ***/
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.dns.disablePrefetchFromHTTPS", true);
user_pref("browser.urlbar.speculativeConnect.enabled", false);
user_pref("browser.places.speculativeConnect.enabled", false);
user_pref("network.prefetch-next", false);

/** Barra de endereço / busca ***/
user_pref("browser.urlbar.trimHttps", true);
user_pref("browser.urlbar.untrimOnUserInteraction.featureGate", true);
user_pref("browser.search.separatePrivateDefault.ui.enabled", true);
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.quicksuggest.enabled", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("browser.urlbar.groupLabels.enabled", false);
user_pref("browser.formfill.enable", false);
user_pref("network.IDN_show_punycode", true);

/** HTTPS-Only
 *  Mais estrito que o Betterfox (que usa HTTPS-First). Intranets, sistemas
 *  legados e equipamentos de rede costumam ser só HTTP e vão mostrar um aviso
 *  a cada acesso (dá para prosseguir). Se incomodar, troque as duas linhas
 *  por:  user_pref("dom.security.https_first", true);  ***/
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_error_page_user_suggestions", true);

/** Senhas / formulários
 *  [ZEN-CUIDADO] Não desliga o gerenciador de senhas; só endurece a captura. ***/
user_pref("signon.formlessCapture.enabled", false);
user_pref("signon.privateBrowsingCapture.enabled", false);
user_pref("network.auth.subresource-http-auth-allow", 1);
user_pref("editor.truncate_user_pastes", false);

/** Extensões: impede extensões instaladas fora do perfil (escopos de sistema) ***/
user_pref("extensions.enabledScopes", 5);

/** Referer ***/
user_pref("network.http.referer.XOriginTrimmingPolicy", 2);

/** Containers ***/
user_pref("privacy.userContext.ui.enabled", true);

/** Diversos ***/
user_pref("pdfjs.enableScripting", false);
user_pref("browser.safebrowsing.downloads.remote.enabled", false);

/** Permissões / Mozilla
 *  Bloqueia por padrão pedidos de notificação e localização. Sites que
 *  precisem (mapas, por exemplo) ficam bloqueados até você liberar no
 *  cadeado da barra de endereço. ***/
user_pref("permissions.default.desktop-notification", 2);
user_pref("permissions.default.geo", 2);
user_pref("geo.provider.network.url", "https://beacondb.net/v1/geolocate");
user_pref("browser.search.update", false);
user_pref("permissions.manager.defaultsUrl", "");
user_pref("extensions.getAddons.cache.enabled", false);

/*****************************************************************************
 * ZERO TELEMETRIA
 *****************************************************************************/
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.usage.uploadEnabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.server", "data:,");
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("toolkit.telemetry.coverage.opt-out", true);
user_pref("toolkit.coverage.opt-out", true);
user_pref("toolkit.coverage.endpoint.base", "");
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);

/** Experimentos / testes A-B ***/
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("app.normandy.enabled", false);
user_pref("app.normandy.api_url", "");

/** Relatórios de falha ***/
user_pref("breakpad.reportURL", "");
user_pref("browser.tabs.crashReporting.sendReport", false);

/*****************************************************************************
 * PESKYFOX — limpeza de interface
 *****************************************************************************/
/** UI da Mozilla ***/
user_pref("extensions.getAddons.showPane", false);
user_pref("extensions.htmlaboutaddons.recommendations.enabled", false);
user_pref("browser.discovery.enabled", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);
user_pref("browser.preferences.moreFromMozilla", false);
user_pref("browser.aboutConfig.showWarning", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.aboutwelcome.enabled", false);

/** [FF-UI] Perfis nativos (o Zen tem sistema próprio) ***/
user_pref("browser.profiles.enabled", true);

/** Bloqueio de recursos de IA (Firefox 148+) ***/
user_pref("browser.ai.control.default", "blocked");
user_pref("browser.ml.enable", false);
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.chat.menu", false);
user_pref("browser.tabs.groups.smart.enabled", false);
user_pref("browser.ml.linkPreview.enabled", false);

/** Tela cheia: sem transição nem aviso ***/
user_pref("full-screen-api.transition-duration.enter", "0 0");
user_pref("full-screen-api.transition-duration.leave", "0 0");
user_pref("full-screen-api.warning.timeout", 0);

/** Barra de endereço ***/
user_pref("browser.urlbar.trending.featureGate", false);

/** [FF-UI] Nova aba (o Zen usa a própria) ***/
user_pref("browser.newtabpage.activity-stream.default.sites", "");
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
user_pref("browser.newtabpage.activity-stream.showWeather", false); // [VERIFICAR]

/** Downloads / PDF ***/
user_pref("browser.download.manager.addToRecentDocs", false);
user_pref("browser.download.open_pdf_attachments_inline", true);

/** Abas / busca ***/
user_pref("browser.bookmarks.openInTabClosesMenu", false);
user_pref("findbar.highlightAll", true);

/** Windows apenas ***/
user_pref("browser.privateWindowSeparation.enabled", false);

/*****************************************************************************
 * TEMA / CUSTOMIZAÇÃO (userChrome.css, userContent.css, firefox-gnome-theme)
 *****************************************************************************/
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true); // obrigatório
user_pref("svg.context-properties.content.enabled", true);              // obrigatório p/ ícones do tema GNOME (sem isso ficam pretos)
user_pref("browser.compactmode.show", true); // [FF-UI] opção "Compacto" no Personalizar; pode alterar medidas do tema GNOME

/** Opções do firefox-gnome-theme (booleanos; descomente as que quiser) ***/
// user_pref("gnomeTheme.hideSingleTab", true);
// user_pref("gnomeTheme.normalWidthTabs", true);
// user_pref("gnomeTheme.tabsAsHeaderbar", true);
// user_pref("gnomeTheme.bookmarksToolbarUnderTabs", true);

/*****************************************************************************
 * HARDWARE MODESTO (opcional) — todas comentadas
 * São mudanças mais agressivas. Ative uma de cada vez e teste.
 *****************************************************************************/

/** (Cache em disco e nº de processos: veja "ESCOLHA O PERFIL" no topo.)

 *  Limita o cache de memória (útil com o cache em disco desligado).
 *  Unidade: KB; -1 = automático. ***/
// user_pref("browser.cache.memory.capacity", 131072); // ~128 MB

/** Menos animações de interface ***/
// user_pref("toolkit.cosmeticAnimations.enabled", false);
// user_pref("browser.tabs.animate", false);
// user_pref("browser.fullscreen.animate", false);
// user_pref("ui.prefersReducedMotion", 1); // força "reduzir movimento" no Firefox e nos sites
//   (o CSS Gruvbox e o tema GNOME já desligam transições quando isso está ativo)

/** Aceleração de GPU: só se notar travamentos ou artefatos de vídeo.
 *  Em versões atuais o WebRender não pode ser desligado; a saída é
 *  desativar a aceleração ou usar o modo por software. ***/
// user_pref("layers.acceleration.disabled", true);
// user_pref("gfx.webrender.software", true);

/** Descarregar abas antigas quando a memória acabar ***/
// user_pref("browser.tabs.unloadOnLowMemory", true); // [VERIFICAR] pode já ser o padrão

/*****************************************************************************
 * SMOOTHFOX (opcional): rolagem. Deixe vazio para o padrão do navegador.
 * Guia: https://github.com/yokoffing/Betterfox/blob/main/Smoothfox.js
 *****************************************************************************/

/*****************************************************************************
 * SEUS OVERRIDES PESSOAIS
 * O que você quiser sobrescrever vai aqui, DEPOIS de todas as seções acima.
 *****************************************************************************/

/*****************************************************************************
 * FIM DO ARQUIVO
 *****************************************************************************/
