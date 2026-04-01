#!/system/bin/sh
MODPATH="/data/adb/modules/gamehub_termux"
CONFIG="$MODPATH/common/config.cfg"
PROTECTED_FILE="$MODPATH/common/protected.list"

# Cores
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Seus apps críticos originais + sistema
CRITICAL=("android" "com.android.systemui" "com.android.settings" "com.termux" "com.google.android.inputmethod.latin" "com.google.android.gms")

# Garante permissões e pastas
mkdir -p "$MODPATH/common"
touch "$CONFIG" "$PROTECTED_FILE"

pause() {
    echo -n -e "\n${YELLOW}Pressione ENTER para continuar...${NC}"
    read _unused
}

modo_normal() {
    echo -e "${CYAN}Restaurando sistema...${NC}"

    lmk_normal

    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo schedutil > $gov 2>/dev/null
    done

    echo -e "${GREEN}Sistema restaurado!${NC}"
    pause
}

# 🔥 LMKD AGRESSIVO
lmk_agressivo() {
    resetprop sys.lmk.minfree_levels "12288:0,16384:100,20480:200,24576:300,36864:900,49152:950"
}

# 🧠 LMKD NORMAL
lmk_normal() {
    resetprop sys.lmk.minfree_levels "18432:0,23040:100,27648:200,32256:250,55296:900,80640:950"
}

# 🔒 PROTEGER PROCESSOS CRÍTICOS (NÍVEL SISTEMA)
proteger_sistema() {
    PROC_CRITICOS=(
        "system_server"
        "surfaceflinger"
        "servicemanager"
        "hwservicemanager"
        "vndservicemanager"
    )

    for proc in "${PROC_CRITICOS[@]}"; do
        pid=$(pidof $proc)
        if [ ! -z "$pid" ]; then
            echo -1000 > /proc/$pid/oom_score_adj 2>/dev/null
        fi
    done
}

# 🚀 CPU BOOST TOTAL
cpu_boost() {
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance > $gov 2>/dev/null
    done
}

carregar_whitelist() {
    if [ ! -s "$PROTECTED_FILE" ]; then
        echo -e "${YELLOW}Criando/Resetando withe.list...${NC}"
        printf "%s\n" "${CRITICAL[@]}" > "$PROTECTED_FILE"
    fi

    WHITELIST=()
    while read -r line || [ -n "$line" ]; do
    case "$line" in
        \#*|"") continue ;;
    esac
    WHITELIST+=("$(echo "$line" | xargs)")
done < "$PROTECTED_FILE"

    # 3. Garante que os CRITICAL sempre estejam na lista (redundância de segurança)
    for c in "${CRITICAL[@]}"; do
        WHITELIST+=("$c")
    done
}


exterminar_apps() {
    carregar_whitelist
    echo -e "${RED}--- EXTERMINANDO APPS E SERVIÇOS (MODO BRUTO) ---${NC}"
    
    # Pega todos os pacotes do sistema
    TODOS_APPS=$(pm list packages | cut -d: -f2)
    
    for app in $TODOS_APPS; do
        skip=false
        for w in "${WHITELIST[@]}"; do
            if [ "$app" = "$w" ]; then
                skip=true
                break
            fi
        done
        
        if [ "$skip" = false ]; then
            echo "Fechando: $app"
            am force-stop "$app"
        fi
    done

    # Limpeza profunda de memória
    echo -e "${CYAN}Limpando Caches e RAM...${NC}"
    pm trim-caches 999G > /dev/null 2>&1
    echo 3 > /proc/sys/vm/drop_caches
    sync
    echo -e "${GREEN}RAM limpa com sucesso!${NC}"
}

carregar_jogos() {
    NAMES=()
    PKGS=()
    if [ -s "$CONFIG" ]; then
        while IFS="|" read -r name pkg || [ -n "$name" ]; do
            [ -z "$name" ] && continue
            
            NAMES+=("$name")
            PKGS+=("$pkg")
        done <<EOF
$(grep -v '^#' "$CONFIG" | grep -v '^$')
EOF
    fi
}


jogar() {
    echo -e "${CYAN}Resetando ZRAM...${NC}"

    if [ -f /data/adb/modules/ZramTG24/ram.sh ]; then
        sh /data/adb/modules/ZramTG24/ram.sh
        echo -e "${GREEN}ZRAM resetada!${NC}"
    else
        echo -e "${YELLOW}Módulo ZRAM não encontrado, pulando...${NC}"
    fi

    sleep 2

    echo -e "${CYAN}Aplicando otimizações de sistema...${NC}"

    lmk_agressivo
    proteger_sistema
    cpu_boost

    exterminar_apps

    carregar_jogos
    if [ ${#NAMES[@]} -eq 0 ]; then
        echo -e "${RED}Nenhum jogo cadastrado! Vá na opção [3].${NC}"
        pause
        return
    fi

    echo -e "${CYAN}--- SELECIONE O JOGO ---${NC}"
    for i in "${!NAMES[@]}"; do
        echo -e "${GREEN}$((i+1))) ${NAMES[$i]}${NC}"
    done
    echo -n "Escolha o número: "
    read escolha

    idx=$((escolha - 1))
    PKG=${PKGS[$idx]}
    NOME=${NAMES[$idx]}

    if [ -z "$PKG" ]; then
        echo -e "${RED}Opção inválida!${NC}"
        pause
        return
    fi

    echo -e "${GREEN}Abrindo $NOME...${NC}"
    monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
    
    echo "Aguardando inicialização (8s)..."
    sleep 8
    
    PIDS=$(pidof "$PKG")
    if [ ! -z "$PIDS" ]; then
        for p in $PIDS; do
            echo -1000 > "/proc/$p/oom_score_adj"
            renice -n -20 -p "$p"
            ionice -c 1 -n 0 -p "$p"
            taskset -p ff "$p"
        done
        echo -e "${GREEN}Proteção OOM e Boost CPU/IO Aplicados!${NC}"
    else
        echo -e "${RED}Erro: Jogo não detectado.${NC}"
    fi

    echo "Fechando Termux em 5 segundos..."
    sleep 5
    am force-stop com.termux
}

adicionar_jogo() {
    echo -n "Nome do jogo: "
    read nome
    echo -n "Pacote (ex: com.mojang.minecraftpe): "
    read pkg
    echo "$nome|$pkg" >> "$CONFIG"
    echo -e "${GREEN}Jogo adicionado!${NC}"
    pause
}

adicionar_whitelist() {
    echo -n "Pacote para proteger (ex: com.whatsapp): "
    read pkg
    echo "$pkg" >> "$PROTECTED_FILE"
    echo -e "${GREEN}App protegido com sucesso!${NC}"
    pause
}

menu() {
    while true; do
        clear
        echo -e "${CYAN}==== GAME HUB PRO (ROOT) ====${NC}"
        echo -e "${GREEN}[1] ▶ Jogar (Exterminar + Boost)${NC}"
        echo -e "${GREEN}[2] 🧹 Apenas Limpar RAM (Bruto)${NC}"
        echo -e "${YELLOW}[3] ➕ Adicionar Novo Jogo${NC}"
        echo -e "${YELLOW}[4] 🛡 Proteger App (Whitelist)${NC}"
        echo -e "${BLUE}[5] 🧠 Restaurar Sistema (Modo Normal)${NC}"
        echo -e "${RED}[6] ❌ Sair${NC}"
        echo ""
        echo -n "Escolha uma opção: "
        read op
        
        case $op in
            1) jogar ;;
            2) exterminar_apps; pause ;;
            3) adicionar_jogo ;;
            4) adicionar_whitelist ;;
            5) modo_normal ;; 
            6) exit 0 ;; 
            *) echo "Opção inválida!"; sleep 1 ;;
        esac
    done
}

menu
