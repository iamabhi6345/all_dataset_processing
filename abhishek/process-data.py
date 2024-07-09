from abhishek.config_schemas.config_schema import Config
from abhishek.utils.config_utils import get_config
from abhishek.utils.gcp_utils import access_secret_version

@get_config(config_path="../configs", config_name="config")
def data_process(config: Config) -> None:
    # print(config)
    github_access_token = access_secret_version("iamabhi45","github-access-token")
    print(github_access_token)

if __name__ == "__main__":
    data_process()  # type: ignore
    