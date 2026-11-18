#!/bin/bash

BASENAME="$(basename "$0")"
RED="\x1B[31m"
YELLOW="\x1B[33m"
RESET="\x1B[0m"
BACKGROUND_PIDS=()
CONTAINER=""
VERBOSE=0
ARGUMENTS=()

for argument in "$@"; do
	if [[ ${argument} == "--verbose" ]]; then
		VERBOSE=1
	else
		ARGUMENTS+=("${argument}")
	fi
done
set -- "${ARGUMENTS[@]}"

function error()
{
	echo -e "${RED}${BASENAME}::[ERROR]:${RESET} $1"
}

function warning()
{
	echo -e "${YELLOW}${BASENAME}::[WARNING]:${RESET} $1"
}

function abort()
{
	trap - INT TERM
	test "${#BACKGROUND_PIDS[@]}" -eq 0 || kill -KILL "${BACKGROUND_PIDS[@]}" 2>/dev/null
	test -z "${CONTAINER}" || docker rm --force "${CONTAINER}" >/dev/null 2>&1
	error "aborted"
	exit 130
}

trap abort INT TERM

function latest_releases()
{
	local remote="$1"
	local prefix="$2"
	local majors="$3"
	local releases

	# shellcheck disable=SC2312
	releases="$(git ls-remote --tags "${remote}" "${prefix}*" \
| sed --quiet "s|.*refs/tags/${prefix}\([0-9]\+\.[0-9]\+\.[0-9]\+\)\$|\1|p" \
| sort --version-sort \
| awk -F. '{ latest[$1] = $0 } END { for (major in latest) { print latest[major] } }' \
| sort --version-sort \
| tail --lines "${majors}")"

	test -n "${releases}" || { error "no release tags matched '${prefix}*' at ${remote}"; exit 1; }

	echo "${releases}"
}

function sample_metrics()
{
	local log="$1"
	local timestamp
	local pid
	local nlwp
	local pcpu
	local rss
	local comm
	local hwm
	local processes
	local process

	while true; do
		printf -v timestamp '%(%Y-%m-%dT%H:%M:%S%z)T' -1
		processes="$(ps -eo pid=,nlwp=,pcpu=,rss=,comm= --sort=-rss)"
		mapfile -t -n 5 processes <<<"${processes}"
		{
			echo "time ${timestamp}"
			echo "loadavg $(</proc/loadavg)"
			grep --extended-regexp '^(MemAvailable|SwapFree):' /proc/meminfo
			for process in "${processes[@]}"; do
				read -r pid nlwp pcpu rss comm <<<"${process}"
				hwm="$(grep '^VmHWM:' "/proc/${pid}/status" 2>/dev/null)"
				echo "process ${comm} pid ${pid} nlwp ${nlwp} pcpu ${pcpu} rss_kb ${rss} ${hwm}"
			done
		} >>"${log}"
		sleep 1
	done
}

function summarize()
{
	if [[ ${VERBOSE} -eq 1 ]]; then
		cat
	else
		grep --line-buffered --extended-regexp '^#[0-9]+ (\[|DONE|CACHED|ERROR)|^ERROR'
	fi
}

function build_image()
{
	local tag="$1"
	local dockerfile="$2"
	local log="build/metrics/${tag//[\/:]/_}.log"
	local build_log="build/metrics/${tag//[\/:]/_}.build.log"
	local metrics_pid
	local status

	shift 2

	mkdir --parents build/metrics
	: >"${log}"
	sample_metrics "${log}" &
	metrics_pid=$!
	BACKGROUND_PIDS+=("${metrics_pid}")

	echo "building ${tag}, full log in ${build_log}"
	# shellcheck disable=SC2312
	docker build --progress=plain "$@" --tag "${tag}" --file "${dockerfile}" . 2>&1 \
| tee "${build_log}" \
| summarize
	status="${PIPESTATUS[0]}"

	kill "${metrics_pid}"
	wait "${metrics_pid}" 2>/dev/null
	BACKGROUND_PIDS=()
	echo "metrics for ${tag} in ${log}, build output in ${build_log}"
	test "${status}" -eq 0 || { error "building ${tag} failed, see ${build_log}"; exit 1; }
}

function export_image()
{
	local kind="$1"
	local version="$2"
	local tag="nkavid/${kind}:${version}"
	local destination="build/export/${kind}_${version}.tar"
	local status

	if ! docker image inspect "${tag}" >/dev/null 2>&1; then
		warning "${tag} not built, skipping export"
		return 0
	fi

	mkdir --parents build/export
	CONTAINER="$(docker create "${tag}" /none)" \
|| { error "creating container from ${tag} failed"; exit 1; }

	docker cp "${CONTAINER}:/opt" - >"${destination}"
	status=$?

	docker rm "${CONTAINER}" >/dev/null
	CONTAINER=""
	test "${status}" -eq 0 || { error "exporting ${tag} failed"; exit 1; }

	sha256sum "${destination}" >"${destination}.sha256" \
|| { error "hashing ${destination} failed"; exit 1; }
	cat "${destination}.sha256"
}

if [[ $1 == "lint" ]]; then
	set -x
	for dockerfile in docker/*.dockerfile; do
		docker run --rm --init -i -v "${PWD}/.hadolint.yaml:/.hadolint.yaml" hadolint/hadolint <"${dockerfile}"
	done
	{ set +x; } &>/dev/null
fi

if [[ $1 == "latest" ]]; then
	echo "gcc"
	latest_releases "https://github.com/gcc-mirror/gcc.git" "releases/gcc-" 4

	echo "llvm"
	latest_releases "https://github.com/llvm/llvm-project.git" "llvmorg-" 4
fi

if [[ $1 == "stages" ]]; then
	if [[ $2 == "image" ]]; then
		KIND="$3"
		VERSION="$4"
		if [[ ${KIND} != "gcc" && ${KIND} != "llvm" ]] || test -z "${VERSION}"; then
			error "usage: $0 stages image <gcc|llvm> <version>"
			exit 1
		fi

		build_image "nkavid/shared_base_ubuntu_22.04" "docker/ubuntu.dockerfile"

		build_image "nkavid/sysroot:0.0.1" "docker/sysroot.dockerfile"

		build_image "nkavid/${KIND}:${VERSION}" "docker/${KIND}.dockerfile" \
--build-arg "${KIND^^}_VERSION=${VERSION}"
	fi

	if [[ $2 == "export" ]]; then
		if [[ $3 == "all" ]]; then
			IMAGES="$(docker image ls --format '{{.Repository}} {{.Tag}}' \
--filter reference='nkavid/gcc' --filter reference='nkavid/llvm')" \
|| { error "listing nkavid images failed"; exit 1; }
			test -n "${IMAGES}" || { error "no nkavid/gcc or nkavid/llvm images found"; exit 1; }
		else
			if [[ $3 != "gcc" && $3 != "llvm" ]] || test -z "$4"; then
				error "usage: $0 stages export <gcc|llvm> <version> | all"
				exit 1
			fi
			IMAGES="nkavid/$3 $4"
		fi

		while read -r REPOSITORY VERSION; do
			KIND="${REPOSITORY#nkavid/}"
			echo "exporting nkavid/${KIND}:${VERSION}"
			export_image "${KIND}" "${VERSION}"
		done <<<"${IMAGES}"
	fi

	if [[ $2 == "check" ]]; then
		mkdir --parents build

		BASE_IMAGE="debian:13"
		UID_NUMBER="$(id -u)"
		GID_NUMBER="$(id -g)"
		USER_ID="${UID_NUMBER}:${GID_NUMBER}"

		# TODO centralize where toolchain kind semver is declared
		# to be used here, with build call, and compare with check
		for TOOLCHAIN in "gcc 12.5.0 g++" "gcc 13.4.0 g++" "llvm 22.1.8 clang++" "llvm 23.1.3 clang++"; do
			read -r KIND VERSION COMPILER <<<"${TOOLCHAIN}"
			IMAGE_TAG="nkavid/${KIND}:${VERSION}"
			PREFIX_PATH="/mnt/opt/nkavid/${KIND}/${KIND}_${VERSION}"

			docker run --rm --init --user "${USER_ID}" \
--mount "type=image,source=${IMAGE_TAG},target=/mnt,readonly" \
"${BASE_IMAGE}" "${PREFIX_PATH}/bin/${COMPILER}" --version \
|| { error "${KIND} ${VERSION} toolchain not usable"; exit 1; }

			docker run --rm --init --user "${USER_ID}" \
--mount "type=image,source=${IMAGE_TAG},target=/mnt,readonly" \
-v "${PWD}/dummy:/dummy:ro" -v "${PWD}/build:/build" \
"${BASE_IMAGE}" "${PREFIX_PATH}/bin/${COMPILER}" /dummy/hello.cpp -o "/build/hello_${KIND}_${VERSION}" \
|| { error "${KIND} ${VERSION} cannot compile dummy/hello.cpp"; exit 1; }
		done
	fi
fi
