#!/bin/bash

DRIVER=/home/umayadav/repo/AMDMIGraphX/build/bin/driver
#DRIVER=/long_pathname_so_that_rpms_can_package_the_debug_info/data/driver/AMDMIGraphX/build/bin/driver

echo "Printing ENV"
env
echo ""

CURR_DIR=$(pwd)

is_validate_ymodel = $1

resultsfile=$CURR_DIR/results_with

if [ $is_validate_ymodel == "validate_ymodel" ] 
then
    echo "Running validation of YModel feature"
    export MIGRAPHX_DISABLE_MIOPEN_FUSION=1
    onnx_list="ymodel_validate_onnx.txt"
    tf_list="ymodel_validate_tf.txt"
	resultsfile+="_validate_ymodel"
elif [ $is_validate_ymodel == "UIF" ]
then
    echo "Runnning testing of UIF models"
    onnx_list="uif_onnx.txt"
    tf_list="uif_tf.txt"
	resultsfile+="_uif_testing"
else 
    echo "Please pass either \"validate_ymodel\" or \"UIF\" flag to script."
    exit
fi

if [ -z "$MIGRAPHX_DISABLE_MIOPEN_FUSION" ]
then
    echo "Fusion enabled"
	resultsfile+="_with_fusion"
else
    echo "Fusion disabled"
	resultsfile+="_without_fusion"
fi

function run_script() {
    is_compile = $1
    if [ $is_compile != "compile" ] 
    then 
        echo "Running MXR Files...." 
        unset MIOPEN_USER_DB_PATH
        unset MIOPEN_FIND_ENFORCE
        mv $HOME/.config/miopen $HOME
        resultsfile+="_perf.csv"
    else 
        echo "Compiling and generating MXR files...."
        resultsfile+="_compile.csv"
    fi

    echo dir "," onnx_file "," params "," total time "," hip::copy_to_gpu "," hip::copy_from_gpu "," hip::sync_stream "," throughput | tee -a $resultsfile

    ulimit -n 1000000

    counter=0

    while read dir onnx params
    do
        echo $dir/$onnx
        model_params=$(echo $params | tr -d '"')
        echo $model_params
        pushd $dir
        base=`basename $onnx .onnx`
        counter=$((counter+1))
        mxr_file=${base}${counter}.mxr
        out_file=${base}${counter}.perf_tuning.out
        echo $mxr_file
        if [ $is_compile -eq 1 ]
        then
            $DRIVER compile --onnx $onnx $model_params --enable-offload-copy --binary --output $mxr_file 
        else
            rm -rf $HOME/.config/miopen
            $DRIVER perf --migraphx $mxr_file $model_params --enable-offload-copy  > $out_file 2>&1
        fi
        total_time=`grep 'Total time' $out_file | awk '{ print $3 }' | sed s/ms//g`
        copy_to_gpu=`grep 'hip::copy_to_gpu:' $out_file | awk '{ print $6 }' | sed s/ms,//g`
        copy_from_gpu=`grep 'hip::copy_from_gpu:' $out_file | awk '{ print $6 }' | sed s/ms,//g`
        sync_stream=`grep 'hip::sync_stream:' $out_file | awk '{ print $6 }' | sed s/ms,//g`
        rate=`grep 'Rate' $out_file | awk '{ print $2 }' | sed 's/\'/'sec//g'`
        echo $dir "," $onnx "," $params "," $total_time "," $copy_to_gpu "," $copy_from_gpu "," $sync_stream "," $rate | tee -a $resultsfile
        popd
    done < $onnx_list 

    while read dir pb params
    do
        echo $dir/$pb
        model_params=$(echo $params | tr -d '"')
        echo $model_params
        pushd $dir
        base=`basename $pb .pb`
        counter=$((counter+1))
        mxr_file=${base}${counter}.mxr
        out_file=${base}${counter}.perf_tuning.out
        echo $mxr_file
        if [ $is_compile -eq 1 ]
        then
            $DRIVER compile --tf $pb $model_params --enable-offload-copy --binary --output $mxr_file 
        else
            rm -rf $HOME/.config/miopen
            $DRIVER perf --migraphx $mxr_file $model_params --enable-offload-copy  > $out_file 2>&1
        fi
        total_time=`grep 'Total time' $out_file | awk '{ print $3 }' | sed s/ms//g`
        copy_to_gpu=`grep 'hip::copy_to_gpu:' $out_file | awk '{ print $6 }' | sed s/ms,//g`
        copy_from_gpu=`grep 'hip::copy_from_gpu:' $out_file | awk '{ print $6 }' | sed s/ms,//g`
        sync_stream=`grep 'hip::sync_stream:' $out_file | awk '{ print $6 }' | sed s/ms,//g`
        rate=`grep 'Rate' $out_file | awk '{ print $2 }' | sed 's/\'/'sec//g'`
        echo $dir "," $pb "," $params "," $total_time "," $copy_to_gpu "," $copy_from_gpu "," $sync_stream "," $rate | tee -a $resultsfile
        popd
    done < $tf_list
}

run_script "compile"
run_script "perf"

if [ -d $HOME/miopen ]
then 
    echo "Moving back tuning database"
    mv $HOME/miopen $HOME/.config/
fi

unset MIOPEN_FIND_ENFORCE
unset MIGRAPHX_DISABLE_MIOPEN_FUSION

echo "Printing ENV:"
env
echo "finished running"
