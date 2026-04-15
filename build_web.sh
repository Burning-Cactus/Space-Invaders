OUT_DIR="build/web"
mkdir -p $OUT_DIR

# export EMSDK_QUIET=1
[[ -f "$EMSDK/emsdk_env.sh" ]] && . "$EMSDK/emsdk_env.sh"

odin build src/web -target:js_wasm32 -build-mode:obj -define:RAYLIB_WASM_LIB=env.o -define:RAYGUI_WASM_LIB=env.o -out:$OUT_DIR/game.wasm.o

# Odin root is a command
ODIN_PATH=$(odin root)

cp $ODIN_PATH/core/sys/wasm/js/odin.js $OUT_DIR

files="$OUT_DIR/game.wasm.o ${ODIN_PATH}/vendor/raylib/wasm/libraylib.a ${ODIN_PATH}/vendor/raylib/wasm/libraygui.a"

flags="-sUSE_GLFW=3 -sWASM_BIGINT -sEXPORTED_RUNTIME_METHODS='HEAPF32' -sWARN_ON_UNDEFINED_SYMBOLS=0 -sASSERTIONS --shell-file src/web/index.html --preload-file assets -sASYNCIFY"

emcc -o $OUT_DIR/index.html $files $flags

rm $OUT_DIR/game.wasm.o

echo "Web build created in ${OUT_DIR}"
