#!/bin/bash
DRIVER=${1:-"/opt/rocm/bin/migraphx-driver"}
MODEL=$2
if [ "$3" ]; then
	PARAMS=$(echo $3 | tr -d '"')
else
	PARAMS=""
fi

MODEL_NAME="$(basename $MODEL)"

echo "Model is ${MODEL_NAME}"
echo "Params to the driver are $PARAMS"

env MIOPEN_ENABLE_LOGGING_CMD=1 $DRIVER run ${MODEL} ${PARAMS} 1> ${MODEL_NAME}_fusion.out 2> ${MODEL_NAME}_fusion.err
env MIOPEN_ENABLE_LOGGING_CMD=1 MIGRAPHX_DISABLE_MIOPEN_FUSION=1 $DRIVER run ${MODEL} ${PARAMS} 1> ${MODEL_NAME}_nofusion.out 2> ${MODEL_NAME}_nofusion.err

fgrep LogCmdConvolution ${MODEL_NAME}_fusion.err | awk '{ $1=""; $2=""; $3=""; print $0 }' > ${MODEL_NAME}_fusion.conv
fgrep LogCmdConvolution ${MODEL_NAME}_nofusion.err | awk '{ $1=""; $2=""; $3=""; print $0 }' > ${MODEL_NAME}_nofusion.conv
rm -rf ${MODEL_NAME}_fusion.err
rm -rf ${MODEL_NAME}_fusion.out
rm -rf ${MODEL_NAME}_nofusion.err
rm -rf ${MODEL_NAME}_nofusion.out
