#!/bin/bash
set -e

# 컬러 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;97m'
NC='\033[0m'

log_info()  { echo -e "[$(date '+%H:%M:%S')] ${GREEN}[Palworld/INFO]${NC} ${WHITE}$1${NC}"; }
log_warn()  { echo -e "[$(date '+%H:%M:%S')] ${YELLOW}[Palworld/WARN]${NC} ${WHITE}$1${NC}"; }
log_error() { echo -e "[$(date '+%H:%M:%S')] ${RED}[Palworld/ERROR]${NC} ${WHITE}$1${NC}"; }

# root로 실행된 경우에만 유저 변경 후 재실행
if [ "$(id -u)" = "0" ]; then
    echo -e "Setting up user permissions (PUID=${PUID:-1000}, PGID=${PGID:-1000})..."
    usermod -u ${PUID:-1000} steam
    groupmod -g ${PGID:-1000} steam
    chown -R steam:steam /home/steam
    log_info "Restarting as steam user..."
    exec gosu steam "$0" "$@"
fi

log_info "Running as: $(id)"

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

log_info "서버 파일 확인 중..."

OLD_VER=""
[ -f "${VERSION_FILE}" ] && OLD_VER=$(cat "${VERSION_FILE}")

if [ "${STEAMCMD_DEBUG:-false}" = "true" ]; then
    steamcmd +force_install_dir "${INSTALL_DIR}" \
        +login anonymous \
        +app_update 2394010 validate \
        +quit
else
    steamcmd +force_install_dir "${INSTALL_DIR}" \
        +login anonymous \
        +app_update 2394010 validate \
        +quit 2>&1 | grep -E "^Error|^Failed|fully installed|up to date" || true
fi

NEW_VER=$(grep "buildid" "${INSTALL_DIR}/steamapps/appmanifest_2394010.acf" 2>/dev/null \
    | awk -F'"' '{print $4}')

if [ -z "${OLD_VER}" ]; then
    log_info "서버 설치 완료: build ${NEW_VER}"
elif [ "${OLD_VER}" != "${NEW_VER}" ]; then
    log_info "서버 업데이트: build ${OLD_VER} → ${NEW_VER}"
else
    log_info "최신 버전 유지 중: build ${NEW_VER}"
fi
echo "${NEW_VER}" > "${VERSION_FILE}"

### PalWorldSettings.ini 생성 ###
CONFIG_DIR="${INSTALL_DIR}/Pal/Saved/Config/LinuxServer"
mkdir -p "${CONFIG_DIR}"
CONFIG_FILE="${CONFIG_DIR}/PalWorldSettings.ini"

if [ ! -f "${CONFIG_FILE}" ]; then
    cp "${INSTALL_DIR}/DefaultPalWorldSettings.ini" "${CONFIG_FILE}"
    log_info "기본 설정 파일 복사 완료"
else
    log_info "기존 설정 파일 사용"
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
sed -i "s|CrossplayPlatforms=([^)]*)[^,)]*|CrossplayPlatforms=(${CROSSPLAY_PLATFORMS:-Steam,Xbox,PS5,Mac})|g" "${CONFIG_FILE}"

# 게임플레이 배율
apply "DayTimeSpeedRate"          ${DAY_TIME_SPEED_RATE:-1.000000}
apply "NightTimeSpeedRate"        ${NIGHT_TIME_SPEED_RATE:-1.000000}
apply "ExpRate"                   ${EXP_RATE:-1.000000}
apply "PalCaptureRate"            ${PAL_CAPTURE_RATE:-1.000000}
apply "PalSpawnNumRate"           ${PAL_SPAWN_NUM_RATE:-1.000000}
apply "WorkSpeedRate"             ${WORK_SPEED_RATE:-1.000000}
apply "AutoSaveSpan"              ${AUTO_SAVE_SPAN:-30.000000}
apply "DeathPenalty"              ${DEATH_PENALTY:-All}
apply "bIsPvP"                    ${IS_PVP:-False}
apply "bHardcore"                 ${HARDCORE:-False}
apply "bPalLost"                  ${PAL_LOST:-False}
apply "bEnableInvaderEnemy"       ${ENABLE_INVADER_ENEMY:-True}
apply "bEnableFriendlyFire"       ${ENABLE_FRIENDLY_FIRE:-False}
apply "bEnablePlayerToPlayerDamage" ${ENABLE_PLAYER_TO_PLAYER_DAMAGE:-False}
apply "PalEggDefaultHatchingTime"  ${PAL_EGG_DEFAULT_HATCHING_TIME:-72.000000}
apply "GuildPlayerMaxNum"         ${GUILD_PLAYER_MAX_NUM:-20}

# 데미지/밸런스 배율
apply "PalDamageRateAttack"        ${PAL_DAMAGE_RATE_ATTACK:-1.000000}
apply "PalDamageRateDefense"       ${PAL_DAMAGE_RATE_DEFENSE:-1.000000}
apply "PlayerDamageRateAttack"     ${PLAYER_DAMAGE_RATE_ATTACK:-1.000000}
apply "PlayerDamageRateDefense"    ${PLAYER_DAMAGE_RATE_DEFENSE:-1.000000}
apply "CollectionDropRate"         ${COLLECTION_DROP_RATE:-1.000000}
apply "EnemyDropItemRate"          ${ENEMY_DROP_ITEM_RATE:-1.000000}
apply "PlayerStomachDecreaceRate"  ${PLAYER_STOMACH_DECREASE_RATE:-1.000000}
apply "PlayerStaminaDecreaceRate"  ${PLAYER_STAMINA_DECREASE_RATE:-1.000000}
apply "PlayerAutoHPRegeneRate"     ${PLAYER_AUTO_HP_REGEN_RATE:-1.000000}
apply "PalStomachDecreaceRate"     ${PAL_STOMACH_DECREASE_RATE:-1.000000}
apply "PalStaminaDecreaceRate"     ${PAL_STAMINA_DECREASE_RATE:-1.000000}
apply "PalAutoHPRegeneRate"        ${PAL_AUTO_HP_REGEN_RATE:-1.000000}

# REST API / RCON
apply "RESTAPIEnabled"  ${REST_API_ENABLED:-False}
apply "RESTAPIPort"     ${REST_API_PORT:-8212}
apply "RCONEnabled"     ${RCON_ENABLED:-False}
apply "RCONPort"        ${RCON_PORT:-25575}

log_info "설정 파일 적용 완료"

### 서버 시작 ###
# 멀티스레드 인자 (-useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS 기본)
THREAD_ARGS="-useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS"
if [ -n "${WORKER_THREADS:-}" ]; then
    THREAD_ARGS="${THREAD_ARGS} -NumberOfWorkerThreadsServer=${WORKER_THREADS}"
    log_info "워커 스레드 수: ${WORKER_THREADS}"
fi

# 커뮤니티 서버 여부
EXTRA_ARGS=""
if [ "${COMMUNITY:-false}" = "true" ]; then
    EXTRA_ARGS="-publiclobby"
    log_warn "커뮤니티 서버 모드 활성화 — 서버 목록에 공개됩니다"
fi

if [ "${REST_API_ENABLED:-false}" = "true"  ]; then
    log_info "서버 시작 중 (포트: ${PORT:-8211}, 쿼리: ${QUERY_PORT:-27015}, REST API: ${REST_API_PORT:-8212})"
else
	log_info "서버 시작 중 (포트: ${PORT:-8211}, 쿼리: ${QUERY_PORT:-27015})"
fi


echo ""

cd "${INSTALL_DIR}"
exec ./PalServer.sh \
    -port=${PORT:-8211} \
    -queryport=${QUERY_PORT:-27015} \
    -players=${MAX_PLAYERS:-32} \
    ${THREAD_ARGS} \
    ${EXTRA_ARGS}