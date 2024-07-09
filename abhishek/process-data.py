from abhishek.config_schemas.data_processing_config_schema import DataProcessingConfig
from abhishek.utils.config_utils import get_config
from abhishek.utils.gcp_utils import access_secret_version
from abhishek.utils.data_utils import get_raw_data_with_version

from hydra.utils import instantiate 


@get_config(config_path="../configs", config_name="data_processing_config")
def data_process(config: DataProcessingConfig) -> None:
    from omegaconf import OmegaConf 
    print(5*"\n")
    print(OmegaConf.to_yaml(config))
    print(5*"\n")
    # print(config)
    return 

    github_access_token = access_secret_version(config.infrastructure.project_id,config.github_access_token_secret_id)
    get_raw_data_with_version(
        version=config.version,
        data_local_save_dir=config.data_local_save_dir,
        dvc_remote_repo=config.dvc_remote_repo,
        dvc_data_folder=config.dvc_data_folder,
        github_user_name=config.github_user_name,
        github_access_token=github_access_token
    )
    # print(github_access_token)

if __name__ == "__main__":
    data_process()  # type: ignore
    