# YModel 

This repo contains scripts to download and extract models from UIF models repository. 

Provides scripts to validate if YModel feature on limited set of models for each ROCm release. 

Script can also do entire UIF modelzoo testing with MIGraphX. 

## How to run
1. Download UIF modelzoo. Run `python3 download_uif_models.py` This would also extract all model fils and put them into folder named `YModelTesting`. 
2. To validate YModel feature run `bash validate_ymodel.sh "validate_ymodel"`.  This would only run models listed inside `ymodel_validate_onnx.txt` and `ymodel_validate_tf.txt`. 
3. To run full UIF model suite, run `bash validate_ymodel.sh "UIF"`. This would run models listed inside `uif_onnx.txt` and `uif_tf.txt`. 

