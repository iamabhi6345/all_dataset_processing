from abhishek.config_schemas.data_processing_config_schema import DataProcessingConfig
from abhishek.utils.config_utils import get_config, get_pickle_config ,custom_instantiate
from abhishek.utils.gcp_utils import access_secret_version
from abhishek.utils.data_utils import get_raw_data_with_version
from hydra.utils import instantiate
from dask.distributed import Client, LocalCluster  
from pathlib import Path
from abhishek.utils.utils import get_logger
import dask.dataframe as dd
from abhishek.utils.io_utils import write_yaml_file
from abhishek.config_schemas.data_processing.dataset_cleaners_schema import DatasetCleanerManagerConfig
import gc
import os
# @get_config(config_path="../configs", config_name="data_processing_config")
# def data_process(config: DataProcessingConfig) -> None:
#     from omegaconf import OmegaConf 
#     print(5*"\n")
#     print(OmegaConf.to_yaml(config))
#     print(5*"\n")
#     # print(config)
#     return 

#     github_access_token = access_secret_version(config.infrastructure.project_id,config.github_access_token_secret_id)
#     get_raw_data_with_version(
#         version=config.version,
#         data_local_save_dir=config.data_local_save_dir,
#         dvc_remote_repo=config.dvc_remote_repo,
#         dvc_data_folder=config.dvc_data_folder,
#         github_user_name=config.github_user_name,
#         github_access_token=github_access_token
#     )
#     # print(github_access_token)
    
    
    
    
    
def process_raw_data(
    df_partition: dd.core.DataFrame, dataset_cleaner_manager: DatasetCleanerManagerConfig
) -> dd.core.Series:
    processed_partition: dd.core.Series = df_partition["text"].apply(dataset_cleaner_manager)
    return processed_partition

    
@get_pickle_config(config_path="abhishek/configs/automatically_generated", config_name="data_processing_config")
def process_data(config: DataProcessingConfig) -> None:
    
    # print("\n\n\nokay\n")
    # print(config)
    # print("\n")
    # return 
    logger = get_logger(Path(__file__).name)
    logger.info("Processing raw data...")

    processed_data_save_dir = config.processed_data_save_dir 

    cluster = custom_instantiate(config.dask_cluster) 
    client = Client(cluster)

    try:
       
        dataset_reader_manager = instantiate(config.dataset_reader_manager)
        dataset_cleaner_manager = instantiate(config.dataset_cleaner_manager) 

        df = dataset_reader_manager.read_data(config.dask_cluster.n_workers) 

        logger.info("Cleaning data...")
        df = df.assign(cleaned_text=df.map_partitions(process_raw_data, dataset_cleaner_manager=dataset_cleaner_manager, meta=("text", "object"))) 
        df = df.compute()

        train_parquet_path = os.path.join(processed_data_save_dir, "train.parquet") 
        dev_parquet_path = os.path.join(processed_data_save_dir, "dev.parquet") 
        test_parquet_path = os.path.join(processed_data_save_dir, "test.parquet") 

        df[df["split"] == "train"].to_parquet(train_parquet_path)
        df[df["split"] == "dev"].to_parquet(dev_parquet_path)
        df[df["split"] == "test"].to_parquet(test_parquet_path)

        docker_info = {"docker_image": config.docker_image_name, "docker_tag": config.docker_image_tag}
        docker_info_save_path = os.path.join(processed_data_save_dir, "docker_info.yaml")

        write_yaml_file(docker_info_save_path, docker_info)
        
        logger.info("Data processing finished!")
    finally:
        logger.info("Closing dask client and cluster...")
        # client.close()  # type: ignore
        # cluster.close()


if __name__ == "__main__":
    process_data()  # type: ignore
    