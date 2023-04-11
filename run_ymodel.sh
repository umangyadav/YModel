#!/bin/bash

NUM_ARGS=$#
if [ $NUM_ARGS != 4 ]; then
	echo "Please pass exactly four arguments to script, see README.md file for more information on how to run this script"
	exit 1
fi

IS_VALIDATE=$1

TUNE=$2

MODEL_DIR=$3

DRIVER=$4

if [ ! -f $DRIVER ]; then 
	echo "Please provide correct path for the migraphx-driver as forth argument to script"
	exit 1
fi

if [ ! -d $MODEL_DIR ]; then
    echo "$MODEL_DIR is not a valid path to model directory, please pass valid directory path as second argument."
	exit 1
fi

base_resultsfile=$MODEL_DIR/results_with

if [ $IS_VALIDATE == "validate_ymodel" ]; then
    echo "Running validation of YModel feature"
    export MIGRAPHX_DISABLE_MIOPEN_FUSION=1
    onnx_list="ymodel_validate_onnx.txt"
    tf_list="ymodel_validate_tf.txt"
    base_resultsfile+="_validate_ymodel"
elif [ $IS_VALIDATE == "UIF" ]; then
    echo "Runnning testing of UIF models"
    onnx_list="uif_onnx.txt"
    tf_list="uif_tf.txt"
    base_resultsfile+="_uif_testing"
else
    echo "Please pass either \"validate_ymodel\" or \"UIF\" flag to script."
    exit 1
fi

if [ $TUNE == "enable_tuning" ]; then
    echo "Tuning is enabled"
    base_resultsfile+="_tuned"
elif [ $TUNE == "disable_tuning" ]; then
    echo "Tuning is disabled"
    base_resultsfile+="_untuned"
else
    echo "Please pass either \"enable_tuning\" or \"disable_tuning\" flag to script as third argument."
    exit 1
fi

if [ -z "$MIGRAPHX_DISABLE_MIOPEN_FUSION" ]; then
    echo "Fusion enabled"
    base_resultsfile+="_with_fusion"
else
    echo "Fusion disabled"
    base_resultsfile+="_without_fusion"
fi

function enable_miopen_logging() {
    export MIOPEN_LOG_LEVEL=6
    export MIOPEN_ENABLE_LOGGING=1
    export MIOPEN_ENABLE_LOGGING_CMD=1
}

function disable_miopen_logging() {
    unset MIOPEN_LOG_LEVEL
    unset MIOPEN_ENABLE_LOGGING
    unset MIOPEN_ENABLE_LOGGING_CMD
}

function disable_user_tuning() {
    unset MIOPEN_FIND_ENFORCE
    unset MIOPEN_USER_DB_PATH
    rm -rf $HOME/.config/miopen
    disable_miopen_logging
}

function enable_user_tuning() {
	if [ $TUNE == "enable_tuning" ]; then
    	export MIOPEN_FIND_ENFORCE=3
    	enable_miopen_logging
	else 
    	echo "Tuning is disabled"	
	fi
}

function print_env() {
    echo $1
    echo ""
    env
    echo ""
}

print_env "ENV as existed before running script"

function run_script() {
    is_compile=$1
    if [ $is_compile != "compile" ]; then
        echo "Running MXR Files...."
        disable_user_tuning
        resultsfile="${base_resultsfile}_perf.csv"
    else
        echo "Compiling and generating MXR files...."
        enable_user_tuning
        resultsfile="${base_resultsfile}_compile.csv"
    fi

    print_env "Printing ENV before eval or compile"

    echo dir "," onnx_file "," params "," total time "," hip::copy_to_gpu "," hip::copy_from_gpu "," hip::sync_stream "," throughput | tee -a $resultsfile

    ulimit -n 1000000

    counter=0

    while read dir onnx params; do
        echo $MODEL_DIR/$dir/$onnx
        model_params=$(echo $params | tr -d '"')
        echo $model_params
        pushd $MODEL_DIR/$dir
        base=$(basename $onnx .onnx)
        counter=$((counter + 1))
        mxr_file=${base}${counter}.mxr
        out_file=${base}${counter}.perf_tuning.out
        echo $mxr_file
        if [ $is_compile == "compile" ]; then
            $DRIVER compile --onnx $onnx $model_params --enable-offload-copy --binary --output $mxr_file
        else
            disable_user_tuning
        fi
        $DRIVER perf --migraphx $mxr_file $model_params --enable-offload-copy >$out_file 2>&1
        total_time=$(grep 'Total time' $out_file | awk '{ print $3 }' | sed s/ms//g)
        copy_to_gpu=$(grep 'hip::copy_to_gpu:' $out_file | awk '{ print $6 }' | sed s/ms,//g)
        copy_from_gpu=$(grep 'hip::copy_from_gpu:' $out_file | awk '{ print $6 }' | sed s/ms,//g)
        sync_stream=$(grep 'hip::sync_stream:' $out_file | awk '{ print $6 }' | sed s/ms,//g)
        rate=$(grep 'Rate' $out_file | awk '{ print $2 }' | sed 's/\'/'sec//g')
        echo $dir "," $onnx "," $params "," $total_time "," $copy_to_gpu "," $copy_from_gpu "," $sync_stream "," $rate | tee -a $resultsfile
        popd
    done <$onnx_list

    while read dir pb params; do
        echo $MODEL_DIR/$dir/$pb
        model_params=$(echo $params | tr -d '"')
        echo $model_params
        pushd $MODEL_DIR/$dir
        base=$(basename $pb .pb)
        counter=$((counter + 1))
        mxr_file=${base}${counter}.mxr
        out_file=${base}${counter}.perf_tuning.out
        echo $mxr_file
        if [ $is_compile == "compile" ]; then
            $DRIVER compile --tf $pb $model_params --enable-offload-copy --binary --output $mxr_file
        else
            disable_user_tuning
        fi
        $DRIVER perf --migraphx $mxr_file $model_params --enable-offload-copy >$out_file 2>&1
        total_time=$(grep 'Total time' $out_file | awk '{ print $3 }' | sed s/ms//g)
        copy_to_gpu=$(grep 'hip::copy_to_gpu:' $out_file | awk '{ print $6 }' | sed s/ms,//g)
        copy_from_gpu=$(grep 'hip::copy_from_gpu:' $out_file | awk '{ print $6 }' | sed s/ms,//g)
        sync_stream=$(grep 'hip::sync_stream:' $out_file | awk '{ print $6 }' | sed s/ms,//g)
        rate=$(grep 'Rate' $out_file | awk '{ print $2 }' | sed 's/\'/'sec//g')
        echo $dir "," $pb "," $params "," $total_time "," $copy_to_gpu "," $copy_from_gpu "," $sync_stream "," $rate | tee -a $resultsfile
        popd
    done <$tf_list
}

run_script "compile"

if [ -d $HOME/.config/miopen_tuned_user_db ]; then
    echo "removing older copy of tuned user db"
    rm -rf $HOME/.config/miopen_tuned_user_db
fi

mv $HOME/.config/miopen $HOME/.config/miopen_tuned_user_db

run_script "perf"

### cleanup
if [ -d $HOME/.config/miopen_tuned_user_db ]; then
    echo "Moving back tuning database"
    mv $HOME/.config/miopen_tuned_user_db $HOME/.config/miopen
fi

disable_miopen_logging
rm -rf $(find -iname "*.mxr")
rm -rf $(find -iname "*.out")
unset MIGRAPHX_DISABLE_MIOPEN_FUSION

print_env "Printing ENV after running script"
echo "finished running"
