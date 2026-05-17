from azure.storage.blob import BlobServiceClient
from dotenv import load_dotenv
import os

load_dotenv()
client = BlobServiceClient.from_connection_string(os.environ["AZURE_STORAGE_CONNECTION_STRING"])
container = client.get_container_client("risk-data")

for blob in container.list_blobs(name_starts_with="landing/"):
    print(blob.name)