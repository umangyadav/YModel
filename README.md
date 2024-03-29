# This repository has been transferred to ROCmSoftwarePlatform and will no longer be maintained. https://github.com/ROCmSoftwarePlatform/YModel-Scripts

# YModel 

This repo contains scripts to download and extract models from UIF models repository. 

Provides scripts to validate if YModel feature on limited set of models for each ROCm release. 

Script can also do entire UIF modelzoo testing with MIGraphX. 

## How to run
1. Download UIF modelzoo. Run `python3 download_uif_models.py --modelzoo-url "web/url/to/model/zoo/"` This would also extract all model fils and put them into folder named `YModelTesting`.  You can skip this step if you already have models downloaded. 
2. To validate YModel feature run `bash run_ymodel.sh "validate_ymodel" "enable_tuning" /path/to/model_dir /path/to/migraphx-driver`.  This would only run models listed inside `ymodel_validate_onnx.txt` and `ymodel_validate_tf.txt`.  
3. To run full UIF model suite, run `bash run_ymodel.sh "UIF" "enable_tuning" /path/to/model_dir /path/to/migraphx-driver`. This would run models listed inside `uif_onnx.txt` and `uif_tf.txt`. 

## Results
After running either step 2 or 3, it would produce two `.csv` files. One with `_perf.csv` and other `_compile.csv`. 

For step 2 of `validate_ymodel` , throughput field of both `.csv` files should be within `1-2%`  margin of each other for each model individually. 

## Running inside Docker
- Make sure to set NUMA bindings otherwise large memory transfers for larger models could result in un-even throughput rates. 

- Run docker without `--shm-size` set. 

- If it segfaults on BERT or GPT, try changing Batch size by replacing batch_size here by lower number: `@input_ids batch_size 1024` 
