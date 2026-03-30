#!/bin/bash
set -e

# UID/GID 처리 (TrueNAS apps 유저 568 지원)
if [ "$(id -u)" = "0" ]; then
    usermod -u ${PUID:-1000} steam 2>/dev/null || true
    groupmod -g ${PGID:-1000} steam 2>/dev/null || true
    exec gosu steam "$0" "$@"
fi

### 로고 ###
CYAN='\033[0;36m'; WHITE='\033[1;37m'; YELLOW='\033[0;33m'; NC='\033[0m'
echo -e "${CYAN}"
echo "  ____       _                        _     _ "
echo " |  _ \ __ _| |_   _  ___  ___  _ __| | __| |"
echo " | |_) / _\` | \ \ /\ / / _ \/ _ \| '__| |/ _\` |"
echo " |  __/ (_| | |\ V  V / (_) | |_) | |  | | (_| |"
echo " |_|   \__,_|_| \_/\_/ \___/| .__/|_|  |_|\__,_|"
echo "                             |_|                 "
echo -e "${NC}"
echo -e "${WHITE} Dedicated Server${NC}"
echo -e "${YELLOW} by Zerglrisk with Claude Sonnet 4.6${NC}"
echo ""

### 서버 파일 설치/업데이트 ###
INSTALL_DIR="/home/steam/serverfiles"
VERSION_FILE="${INSTALL_DIR}/.version"
echo -e "[Palworld] 서버 파일 확인 중..."

OLD_VER=""
[ -f "${VERSION_FILE}" ] && OLD_VER=$(cat "${VERSION_FILE}")

steamcmd +login anonymous \
    +force_install_dir "${INSTALL_DIR}" \
    +app_update 2394010 validate \
    +quit 2>&1 | \
    if [ "${STEAMCMD_DEBUG:-false}" = "true" ]; then
        cat
    else
        grep -v '^\[.*%\]\|^$\|Verifying\|Downloading\|Extracting\|Installing\|Cleaning'
    fi || true

NEW_VER=$(grep "buildid" "${INSTALL_DIR}/steamapps/appmanifest_2394010.acf" 2>/dev/null \
    | awk -F'"' '{print $4}')

if [ -z "${OLD_VER}" ]; then
    echo -e "[Palworld/INFO] 서버 설치 완료: build ${NEW_VER}"
elif [ "${OLD_VER}" != "${NEW_VER}" ]; then
    echo -e "[Palworld/INFO] 서버 업데이트: build ${OLD_VER} → ${NEW_VER}"
else
    echo -e "[Palworld/INFO] 최신 버전 유지 중: build ${NEW_VER}"
fi
echo "${NEW_VER}" > "${VERSION_FILE}"

### PalWorldSettings.ini 생성 ###
CONFIG_DIR="${INSTALL_DIR}/Pal/Saved/Config/LinuxServer"
mkdir -p "${CONFIG_DIR}"
CONFIG_FILE="${CONFIG_DIR}/PalWorldSettings.ini"

if [ ! -f "${CONFIG_FILE}" ]; then
    cp "${INSTALL_DIR}/DefaultPalWorldSettings.ini" "${CONFIG_FILE}"
    echo -e "[Palworld/INFO] 기본 설정 파일 복사 완료"
fi

### 환경변수 → PalWorldSettings.ini 적용 ###
# Difficulty는 전용 서버에서 미작동 - 공식 문서 권고에 따라 None 고정
apply() {
    local key="$1" val="$2"
    sed -i "s|\(${key}=\)[^,)]*|\1${val}|g" "${CONFIG_FILE}"
}

# 서버 기본
apply "ServerName"          "\"${SERVER_NAME:-Palworld Server}\""
apply "ServerDescription"    "\"${SERVER_DESCRIPTION:-}\""
apply "ServerPassword"       "\"${SERVER_PASSWORD:-}\""
apply "AdminPassword"        "\"${ADMIN_PASSWORD:-ChangeMeAdmin}\""
apply "ServerPlayerMaxNum"   ${MAX_PLAYERS:-32}
apply "PublicPort"           ${PORT:-8211}
apply "PublicIP"             "\"${PUBLIC_IP:-}\""
apply "bAllowClientMod"      ${ALLOW_CLIENT_MOD:-False}
apply "CrossplayPlatforms"   "(${CROSSPLAY_PLATFORMS:-Steam,Xbox,PS5,Mac})"

# 게임플레이 배율
apply "DayTimeSpeedRate"         ${DAY_TIME_SPEED_RATE:-1.000000}
apply "NightTimeSpeedRate"       ${NIGHT_TIME_SPEED_RATE:-1.000000}
apply "ExpRate"                  ${EXP_RATE:-1.000000}
apply "PalCaptureRate"           ${PAL_CAPTURE_RATE:-1.000000}
apply "PalSpawnNumRate"          ${PAL_SPAWN_NUM_RATE:-1.000000}
apply "WorkSpeedRate"            ${WORK_SPEED_RATE:-1.000000}
apply "AutoSaveSpan"             ${AUTO_SAVE_SPAN:-30.000000}
apply "DeathPenalty"             ${DEATH_PENALTY:-All}
apply "bIsPvP"                   ${IS_PVP:-False}
apply "bHardcore"                ${HARDCORE:-False}
apply "bPalLost"                 ${PAL_LOST:-False}
apply "bEnableInvaderEnemy"      ${ENABLE_INVADER_ENEMY:-True}
apply "bEnableFriendlyFire"      ${ENABLE_FRIENDLY_FIRE:-False}
apply "bEnablePlayerToPlayerDamage" ${ENABLE_PLAYER_TO_PLAYER_DAMAGE:-False}
apply "PalEggDefaultHatchingTime" ${PAL_EGG_DEFAULT_HATCHING_TIME:-72.000000}
apply "GuildPlayerMaxNum"        ${GUILD_PLAYER_MAX_NUM:-20}

# 데미지/밸런스 배율
apply "PalDamageRateAttack"       ${PAL_DAMAGE_RATE_ATTACK:-1.000000}
apply "PalDamageRateDefense"      ${PAL_DAMAGE_RATE_DEFENSE:-1.000000}
apply "PlayerDamageRateAttack"    ${PLAYER_DAMAGE_RATE_ATTACK:-1.000000}
apply "PlayerDamageRateDefense"   ${PLAYER_DAMAGE_RATE_DEFENSE:-1.000000}
apply "CollectionDropRate"        ${COLLECTION_DROP_RATE:-1.000000}
apply "EnemyDropItemRate"         ${ENEMY_DROP_ITEM_RATE:-1.000000}
apply "PlayerStomachDecreaceRate" ${PLAYER_STOMACH_DECREASE_RATE:-1.000000}
apply "PlayerStaminaDecreaceRate" ${PLAYER_STAMINA_DECREASE_RATE:-1.000000}
apply "PlayerAutoHPRegeneRate"    ${PLAYER_AUTO_HP_REGEN_RATE:-1.000000}
apply "PalStomachDecreaceRate"    ${PAL_STOMACH_DECREASE_RATE:-1.000000}
apply "PalStaminaDecreaceRate"    ${PAL_STAMINA_DECREASE_RATE:-1.000000}
apply "PalAutoHPRegeneRate"       ${PAL_AUTO_HP_REGEN_RATE:-1.000000}

# REST API / RCON
apply "RESTAPIEnabled"  ${REST_API_ENABLED:-True}
apply "RESTAPIPort"     ${REST_API_PORT:-8212}
apply "RCONEnabled"     ${RCON_ENABLED:-False}
apply "RCONPort"        ${RCON_PORT:-25575}

### 서버 시작 ###
echo -e "[Palworld/INFO] 서버 시작 (포트: ${PORT:-8211}, REST API: ${REST_API_PORT:-8212})"
echo ""

# 멀티스레드 인자 (-useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS 기본)
THREAD_ARGS="-useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS"
[ -n "${WORKER_THREADS:-}" ] && \
    THREAD_ARGS="${THREAD_ARGS} -NumberOfWorkerThreadsServer=${WORKER_THREADS}"

# 커뮤니티 서버 여부
EXTRA_ARGS=""
[ "${COMMUNITY:-false}" = "true" ] && EXTRA_ARGS="-publiclobby"

cd "${INSTALL_DIR}"
exec ./PalServer.sh \
    -port=${PORT:-8211} \
    -queryport=${QUERY_PORT:-27015} \
    -players=${MAX_PLAYERS:-32} \
    ${THREAD_ARGS} \
    ${EXTRA_ARGS}