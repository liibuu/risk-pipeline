from azure.storage.blob import BlobServiceClient
from dotenv import load_dotenv
import os

load_dotenv()

def clean_curated_mart():
    client = BlobServiceClient.from_connection_string(os.environ["AZURE_STORAGE_CONNECTION_STRING"])
    container = client.get_container_client("risk-data")

    deleted = 0
    for prefix in ["curated/", "mart/"]:
        for blob in container.list_blobs(name_starts_with=prefix):
            container.delete_blob(blob.name)
            deleted += 1

    print(f"Deleted {deleted} blobs from curated/ and mart/")

if __name__ == "__main__":
    clean_curated_mart()