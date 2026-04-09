#!/system/bin/sh

MODPATH="/data/adb/modules/GameHub-PRO-X"
CONFIG="$MODPATH/common/config.cfg"
PROTECTED_FILE="$MODPATH/common/protected.list"
CACHE_FILE="$MODPATH/common/renderer_cache.cfg"
LOG_DIR="/data/local/tmp/logs"
LOG_FILE="$LOG_DIR/gamehub.log"

mkdir -p "$MODPATH/common" "$LOG_DIR"
touch "$CONFIG" "$PROTECTED_FILE" "$CACHE_FILE"

# Cores
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

exec 3>&1
echo "--- SESSÃO MT6769 $(date) ---" > "$LOG_FILE"
exec 1>>"$LOG_FILE"
exec 2>>"$LOG_FILE"

say() { echo -e "$1" >&3; }
log() { echo "[$(date +%H:%M:%S)] $1" >> "$LOG_FILE"; }

# ============================================================
# DETECTOR INTELIGENTE DE RENDERER
# ============================================================

detectar_suporte_vulkan() {
    local pkg=$1
    
    local cached=$(grep "^$pkg|" "$CACHE_FILE" 2>/dev/null | cut -d'|' -f2)
    if [ -n "$cached" ]; then
        echo "$cached"
        log "Cache hit para $pkg: $cached"
        return 0
    fi
    
    log "Detectando suporte Vulkan para $pkg..."
    
    local apk_path=$(pm path "$pkg" 2>/dev/null | cut -d':' -f2)
    if [ -n "$apk_path" ]; then
        local libs=$(unzip -l "$apk_path" 2>/dev/null | grep -E "lib/.*/libvulkan|lib/.*/libVulkan" | head -1)
        if [ -n "$libs" ]; then
            echo "$pkg|vulkan" >> "$CACHE_FILE"
            log "Detectado: Vulkan (via libs nativas)"
            echo "vulkan"
            return 0
        fi
    fi
    
    local unity_players=$(dumpsys package "$pkg" 2>/dev/null | grep -i "unity" | head -1)
    if [ -n "$unity_players" ]; then
        echo "$pkg|vulkan" >> "$CACHE_FILE"
        log "Detectado: Vulkan (Unity engine)"
        echo "vulkan"
        return 0
    fi
    
    local renderer=$(dumpsys SurfaceFlinger 2>/dev/null | grep -i "vulkan" | head -1)
    if [ -n "$renderer" ]; then
        echo "$pkg|vulkan" >> "$CACHE_FILE"
        log "Detectado: Vulkan (via SurfaceFlinger)"
        echo "vulkan"
        return 0
    fi
    
    local vulkan_known=(
        "com.miHoYo.Yuanshen"
        "com.miHoYo.Nap"
        "com.HoYoverse.hkrpgoversea"
        "com.tencent.tmgp.sgame"
        "com.pubg.imobile"
        "com.gryphline.endfield.gp"
    )
    
    for known in "${vulkan_known[@]}"; do
        if [ "$pkg" = "$known" ]; then
            echo "$pkg|vulkan" >> "$CACHE_FILE"
            log "Detectado: Vulkan (lista conhecida)"
            echo "vulkan"
            return 0
        fi
    done
    
    echo "$pkg|opengl" >> "$CACHE_FILE"
    log "Detectado: OpenGL (padrão)"
    echo "opengl"
    return 0
}

escolher_melhor_renderer() {
    local pkg=$1
    
    say "${CYAN}🔍 Analisando $pkg...${NC}"
    
    local detected=$(detectar_suporte_vulkan "$pkg")
    
    if [ "$detected" = "vulkan" ]; then
        say "${YELLOW}📱 App detectado com suporte Vulkan${NC}"
        say "${GREEN}🔥 Usando VULKAN para máxima performance${NC}"
        echo "vulkan"
        return 0
    else
        say "${CYAN}🖥️ Usando OpenGL (compatibilidade garantida)${NC}"
        echo "opengl"
        return 0
    fi
}

aplicar_renderer() {
    local renderer=$1
    
    if [ "$renderer" = "vulkan" ]; then
        setprop debug.hwui.renderer skiavk
        setprop debug.renderengine.backend skiavkthreaded
        setprop debug.vulkan.layers.enable 0
        setprop debug.vulkan.shders.enable 1
        log "Renderer aplicado: VULKAN"
    else
        setprop debug.hwui.renderer skiagl
        setprop debug.renderengine.backend skiaglthreaded
        log "Renderer aplicado: OPENGL"
    fi
}

# ============================================================
# EXTERMINAR APPS
# ============================================================
exterminar_apps() {
    say "${RED}Otimizando memória...${NC}"
    log "=== INICIANDO LIMPEZA DE APPS ==="
    
    local whitelist=(
        "android"
        "com.android.systemui"
        "com.android.settings"
        "com.termux"
        "com.google.android.inputmethod.latin"
        "com.google.android.gms"
    )
    
    if [ -f "$PROTECTED_FILE" ]; then
        while IFS= read -r line; do
            [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
            whitelist+=("$line")
        done < "$PROTECTED_FILE"
    fi
    
    sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
    
    local all_apps=$(pm list packages 2>/dev/null | cut -d: -f2)
    local count=0
    local killed_apps=""
    
    for app in $all_apps; do
        local skip=false
        for w in "${whitelist[@]}"; do
            if [ "$app" = "$w" ]; then
                skip=true
                break
            fi
        done
        
        if [ "$skip" = false ]; then
            am force-stop "$app" 2>/dev/null && {
                ((count++))
                killed_apps="$killed_apps $app"
                log "Fechado: $app"
            }
        fi
    done
    
    log "Total de apps fechados: $count"
    [ $count -gt 0 ] && log "Apps fechados: $killed_apps"
    
    say "${GREEN}Fechados $count apps${NC}"
}

# ============================================================
# PROTEGER JOGO (COM AFFINITY CORRETA 0xFC)
# ============================================================
proteger_jogo() {
    local pkg=$1
    log "Protegendo $pkg"
    
    for pid in $(pgrep -f "$pkg" 2>/dev/null); do
        if [ -n "$pid" ] && [ "$pid" -gt 0 ]; then
            echo -1000 > "/proc/$pid/oom_score_adj" 2>/dev/null
            echo -17 > "/proc/$pid/oom_adj" 2>/dev/null
            renice -n -20 -p "$pid" 2>/dev/null
            ionice -c 1 -n 0 -p "$pid" 2>/dev/null
            taskset -p 0xFC "$pid" 2>/dev/null
            
            local affinity=$(taskset -p "$pid" 2>/dev/null | cut -d' ' -f6)
            log "PID $pid affinity: $affinity"
            
            say "${GREEN}🛡️ Jogo protegido (PID: $pid, affinity: $affinity)${NC}"
        fi
    done
}

#============================================================
# FUNÇÃO DE DIMINUIR CARGA DA GPU!
#=================================================
restaurar_res() {
    log "Restaurando 720p nativo"
    wm size reset
    wm density reset
}

selecionar_resolucao() {
    say "${CYAN}--- SELEÇÃO DE RESOLUÇÃO (16:9 Adaptado) ---${NC}"
    say "${GREEN}[1] Nativa (720p - Original)${NC}"
    say "${GREEN}[2] Equilíbrio (540p - Recomendado)${NC}"
    say "${YELLOW}[3] Performance (480p)${NC}"
    say "${YELLOW}[4] Modo Batata (360p)${NC}"
    say "${RED}[5] Extremo (240p - Gráfico de PS1)${NC}"
    echo -n "Escolha a resolução: " >&3
    read res_op
    
    case $res_op in
        2) wm size 540x1209 && wm density 200; log "Resolução: 540p" ;;
        3) wm size 480x1074 && wm density 180; log "Resolução: 480p" ;;
        4) wm size 360x806 && wm density 140; log "Resolução: 360p" ;;
        5) wm size 240x537 && wm density 100; log "Resolução: 240p" ;;
        *) wm size reset && wm density reset; log "Resolução: Nativa" ;;
    esac
    say "${GREEN}✓ Resolução aplicada!${NC}"
}

# ============================================================
# FUNÇÃO PRINCIPAL JOGAR
# ============================================================
jogar() {
    say "${CYAN}🚀 Modo Jogo Inteligente${NC}"
    log "=== MODO JOGO INICIADO ==="
    
    local names=()
    local pkgs=()
    
    if [ -f "$CONFIG" ] && [ -s "$CONFIG" ]; then
        while IFS="|" read -r name pkg; do
            [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
            names+=("$name")
            pkgs+=("$pkg")
        done < "$CONFIG"
    fi
    
    if [ ${#names[@]} -eq 0 ]; then
        say "${RED}Nenhum jogo cadastrado!${NC}"
        pause
        return
    fi
    
    say "${CYAN}--- JOGOS DISPONÍVEIS ---${NC}"
    for i in "${!names[@]}"; do
        local pkg_check="${pkgs[$i]}"
        local detected=$(detectar_suporte_vulkan "$pkg_check" 2>/dev/null)
        local icon="🖥️"
        [ "$detected" = "vulkan" ] && icon="🔥"
        say "${GREEN}[$((i+1))] $icon ${names[$i]}${NC}"
    done
    
    echo -n "Escolha: " >&3
    read escolha
    
    local idx=$((escolha - 1))
    if [ $idx -lt 0 ] || [ $idx -ge ${#names[@]} ]; then
        say "${RED}Inválido!${NC}"
        pause
        return
    fi
    
    local pkg="${pkgs[$idx]}"
    local name="${names[$idx]}"
    
    say "${CYAN}═══════════════════════════════════════${NC}"
    say "${CYAN}🔍 ANALISANDO $name${NC}"
    say "${CYAN}═══════════════════════════════════════${NC}"
    
    local best_renderer=$(escolher_melhor_renderer "$pkg")
    
    say ""
    aplicar_renderer "$best_renderer"
    selecionar_resolucao

    if [ "$best_renderer" = "vulkan" ]; then
        say "${GREEN}✅ Vulkan ativado - Performance máxima!${NC}"
    else
        say "${BLUE}✅ OpenGL ativado - Compatibilidade garantida${NC}"
    fi
    
    say ""
    say "${CYAN}⚡ Aplicando otimizações...${NC}"
    
    if [ -f "/data/adb/modules/ZramTG24/ram.sh" ]; then
        sh "/data/adb/modules/ZramTG24/ram.sh" 2>/dev/null
    fi
    
    resetprop sys.lmk.minfree_levels "6144:0,12288:50,16384:100,20480:150,28672:200,40960:300"
    
    for proc in system_server surfaceflinger; do
        for pid in $(pgrep -f "$proc" 2>/dev/null); do
            echo -1000 > "/proc/$pid/oom_score_adj" 2>/dev/null
        done
    done
    
    for policy in /sys/devices/system/cpu/cpufreq/policy*; do
        echo performance > "$policy/scaling_governor" 2>/dev/null
        max_freq=$(cat "$policy/scaling_max_freq" 2>/dev/null)
        [ -n "$max_freq" ] && echo $max_freq > "$policy/scaling_min_freq" 2>/dev/null
    done

    stop logd 2>/dev/null
    setprop persist.sys.pinner.enabled false 2>/dev/null
    log "RAM: Logcat e Pinner desativados"
    # --------------------------------------------------------------------
    
    # Limpeza de apps
    exterminar_apps
    
    say "${GREEN}✅ Otimizações aplicadas!${NC}"
    say ""
    
    say "${GREEN}🎮 Iniciando $name...${NC}"
    monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >2 /dev/null
    
    say "${YELLOW}⏳ Aguardando jogo...${NC}"
    sleep 5
    
    proteger_jogo "$pkg"
    
    say ""
    say "${GREEN}═══════════════════════════════════════${NC}"
    say "${GREEN}✅ $name rodando com $best_renderer!${NC}"
    say "${GREEN}═══════════════════════════════════════${NC}"
    
    log "=== RESUMO DO MODO JOGO ==="
    log "Jogo: $pkg"
    log "Renderer: $best_renderer"
    log "=========================="
    
    sleep 2
    am force-stop com.termux 2>/dev/null
    pkill -f "com.termux" 2>/dev/null
    
    log "Modo jogo finalizado para $pkg com $best_renderer"
}

# ============================================================
# DEMAIS FUNÇÕES
# ============================================================
limpar_cache() {
    rm -f "$CACHE_FILE"
    say "${GREEN}✓ Cache de detecção limpo!${NC}"
    log "Cache limpo"
    pause
}

adicionar_jogo_manual() {
    echo -n "Nome do jogo: " >&3
    read nome
    echo -n "Pacote (ex: com.HoYoverse.Nap): " >&3
    read pkg
    echo "$nome|$pkg" >> "$CONFIG"
    say "${GREEN}✓ Jogo adicionado!${NC}"
    rm -f "$CACHE_FILE"
    say "${YELLOW}⚠️ Cache limpo - detecção será refeita na próxima vez${NC}"
    pause
}

adicionar_whitelist() {
    echo -n "Pacote para proteger: " >&3
    read pkg
    echo "$pkg" >> "$PROTECTED_FILE"
    say "${GREEN}✓ App protegido!${NC}"
    pause
}

modo_normal() {
    say "${CYAN}Restaurando sistema...${NC}"
    restaurar_padrao
    restaurar_res
    for policy in /sys/devices/system/cpu/cpufreq/policy*; do
        echo schedutil > "$policy/scaling_governor" 2>/dev/null
    done
    say "${GREEN}Sistema restaurado!${NC}"
    pause
}

adicionar_jogo_auto() {
    say "${CYAN}═══════════════════════════════════════${NC}"
    say "${CYAN}   DETECTANDO JOGOS INSTALADOS${NC}"
    say "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    # Detecta jogos
    local jogos=$(pm list packages -3 | cut -d: -f2 | grep -iE "game|rovio|robtop|roblox|hoyoverse|netease|ea.*game|supercell|chess|juggle|gameloft|tencent|mihoyo|gryphline|endfield" | grep -v "hoyolab\|adobe.reader" | sort)
    
    if [ -z "$jogos" ]; then
        say "${RED}⚠️ Nenhum jogo detectado!${NC}"
        pause
        return
    fi
    
    local i=1
    local pkg_array=()
    
    while IFS= read -r pkg; do
        case $pkg in
            com.raongames.growcastle) nome="🌲 Grow Castle" ;;
            com.rovio.battlebay) nome="⚓ Battle Bay" ;;
            com.robtopx.geometryjump) nome="⬛ Geometry Jump" ;;
            com.roblox.client) nome="🧱 Roblox" ;;
            com.HoYoverse.hkrpgoversea) nome="✨ Honkai: Star Rail" ;;
            com.gryphline.endfield.gp) nome="🎯 Endfield" ;;
            com.netease.newspike) nome="🔫 Blood Strike" ;;
            com.ea.game.pvz2_row) nome="🌱 Plants vs Zombies 2" ;;
            com.gamovation.chessclubpilot) nome="♟️ Chess Club" ;;
            com.supercell.clashroyale) nome="👑 Clash Royale" ;;
            com.chess) nome="♞ Chess.com" ;;
            com.block.juggle) nome="🧩 Block Juggle" ;;
            com.supercell.clashofclans) nome="🏰 Clash of Clans" ;;
            *) nome="🎮 $(echo $pkg | cut -d. -f3)" ;;
        esac
        
        # Verifica se já está no config
        if grep -q "|$pkg$" "$CONFIG" 2>/dev/null; then
            status="${GREEN}✓${NC}"
        else
            status="${YELLOW}○${NC}"
        fi
        
        say "$status ${GREEN}[$i]${NC} $nome"
        say "    ${CYAN}📦 $pkg${NC}"
        echo ""
        
        pkg_array+=("$pkg")
        i=$((i + 1))
    done <<< "$jogos"
    
    say "${CYAN}═══════════════════════════════════════${NC}"
    say "${YELLOW}[0] Voltar | [T] Adicionar Todos${NC}"
    echo -n "Escolha: " >&3
    read escolha
    
    [ "$escolha" = "0" ] && return
    
    if [ "$escolha" = "T" ] || [ "$escolha" = "t" ]; then
        for pkg in "${pkg_array[@]}"; do
            if ! grep -q "|$pkg$" "$CONFIG" 2>/dev/null; then
                nome_app=$(echo "$pkg" | cut -d. -f3)
                echo "$nome_app|$pkg" >> "$CONFIG"
                say "${GREEN}✓ Adicionado: $pkg${NC}"
            fi
        done
        rm -f "$CACHE_FILE"
        say "${GREEN}✅ Todos adicionados!${NC}"
        pause
        return
    fi
    
    if [ "$escolha" -ge 1 ] && [ "$escolha" -le ${#pkg_array[@]} ]; then
        pkg_escolhido="${pkg_array[$((escolha-1))]}"
        
        if grep -q "|$pkg_escolhido$" "$CONFIG" 2>/dev/null; then
            say "${RED}⚠️ Jogo já cadastrado!${NC}"
        else
            nome_app=$(echo "$pkg_escolhido" | cut -d. -f3)
            echo "$nome_app|$pkg_escolhido" >> "$CONFIG"
            rm -f "$CACHE_FILE"
            say "${GREEN}✅ Jogo adicionado!${NC}"
        fi
    else
        say "${RED}⚠️ Opção inválida!${NC}"
    fi
    
    pause
}

pause() {
    say "\n${YELLOW}Pressione ENTER para continuar...${NC}"
    read _unused <&3
}

# ============================================================
# MENU PRINCIPAL
# ============================================================
menu() {
    while true; do
        clear >&3
        say "${CYAN}═══════════════════════════════════════${NC}"
        say "${CYAN}   GAME HUB PRO  V3${NC}"
        say "${CYAN}   Renderer: Auto${NC}"
        say "${CYAN}   DEV: Irryoff${NC}"
        say "${CYAN}═══════════════════════════════════════${NC}"
        say ""
        say "${GREEN}[1] 🎮 JOGAR${NC}"
        say "${GREEN}[2] 🧹 Limpar RAM${NC}"
        say "${YELLOW}[3] ➕ Adicionar Jogo Auto${NC}"
        say "${YELLOW}[4] ✍🏻 Adicionar jogo manual${NC}"
        say "${YELLOW}[5] 🛡 Proteger App${NC}"
        say "${BLUE}[6] 🔄 Restaurar Sistema${NC}"
        say "${BLUE}[7] 🗑️ Limpar Cache de Detecção${NC}"
        say "${RED}[8] ❌ Sair${NC}"
        echo -n "➜ " >&3
        read op <&3
        
        case $op in
            1) jogar ;;
            2) exterminar_apps; pause ;;
            3) adicionar_jogo_auto ;;
            4) adcionar_jogo_manual ;;
            5) adicionar_whitelist ;;
            6) modo_normal ;;
            7) limpar_cache ;;
            8) exit 0 ;;
            *) say "${RED}Opção inválida!${NC}" ;;
        esac
    done
}

menu
