
Lookup Activity (SELECT table names from DB) → ForEach Activity (loop over results) → Copy Activity

```bash
# Step 1: Install Self-hosted Integration Runtime


# Step 2: Create the SQL Server Linked Services: onlinebanking, customerprofile, products
az datafactory linked-service create `
  --resource-group rg-risk-pipeline `
  --factory-name adf-risk-pipeline `
  --linked-service-name ls_adls_landing `
  --properties `@ls_adls_landing.json

az datafactory linked-service create `
  --resource-group rg-risk-pipeline `
  --factory-name adf-risk-pipeline `
  --linked-service-name ls_sqlserver_onlinebanking `
  --properties `@ls_sqlserver_onlinebanking.json

az datafactory linked-service create `
  --resource-group rg-risk-pipeline `
  --factory-name adf-risk-pipeline `
  --linked-service-name ls_sqlserver_customerprofile `
  --properties `@ls_sqlserver_customerprofile.json  

az datafactory linked-service create `
  --resource-group rg-risk-pipeline `
  --factory-name adf-risk-pipeline `
  --linked-service-name ls_sqlserver_products `
  --properties `@ls_sqlserver_products.json


# Step 3: Create the Copy Pipeline: onlinebanking, customerprofile, products
az datafactory dataset create `
  --resource-group rg-risk-pipeline `
  --factory-name adf-risk-pipeline `
  --dataset-name ds_adls_landing `
  --properties `@ds_adls_landing.json

az datafactory dataset create `
  --resource-group rg-risk-pipeline `
  --factory-name adf-risk-pipeline `
  --dataset-name ds_sqlserver_onlinebanking `
  --properties `@ds_sqlserver_onlinebanking.json

az datafactory dataset create `
  --resource-group rg-risk-pipeline `
  --factory-name adf-risk-pipeline `
  --dataset-name ds_sqlserver_customerprofile `
  --properties `@ds_sqlserver_customerprofile.json

az datafactory dataset create `
  --resource-group rg-risk-pipeline `
  --factory-name adf-risk-pipeline `
  --dataset-name ds_sqlserver_products `
  --properties `@ds_sqlserver_products.json

az datafactory pipeline create `
  --resource-group rg-risk-pipeline `
  --factory-name adf-risk-pipeline `
  --pipeline-name pl_foreach_copy_all `
  --pipeline `@pl_foreach_copy_all.json

# Step 4: Run
az datafactory pipeline create-run `
  --resource-group rg-risk-pipeline `
  --factory-name adf-risk-pipeline `
  --pipeline-name pl_foreach_copy_all

az datafactory pipeline-run show `
  --resource-group rg-risk-pipeline `
  --factory-name adf-risk-pipeline `
  --run-id "7a7f5f6c-5203-11f1-aa35-7c8ae17039b8" `
  --query "{status:status, message:message}"

az datafactory activity-run query-by-pipeline-run `
  --resource-group rg-risk-pipeline `
  --factory-name adf-risk-pipeline `
  --run-id "583aa60b-5202-11f1-94e7-7c8ae17039b8" `
  --last-updated-after "2026-01-01T00:00:00Z" `
  --last-updated-before "2026-12-31T00:00:00Z" `
  --query "value[?activityName=='BranchOnDatabase'].{status:status, error:error}" `
  --output json


# Step 5: Test & Validate
sqlcmd -S localhost -E -C -Q "ALTER LOGIN sa WITH PASSWORD = '<password>', CHECK_POLICY = OFF; ALTER LOGIN sa ENABLE;"

```

aa

```sql
-- Create the login at server level (if not exists)
CREATE LOGIN adf_user WITH PASSWORD = '<password>', CHECK_POLICY = OFF;

-- Create the user in your specific database
USE <your-actual-db-name>;
CREATE USER adf_user FOR LOGIN adf_user;
ALTER ROLE db_datareader ADD MEMBER adf_user;
```

reset
```bash
# Delete all pipelines
az datafactory pipeline list `
  --resource-group rg-risk-pipeline `
  --factory-name adf-risk-pipeline `
  --query "[].name" -o tsv | ForEach-Object {
    az datafactory pipeline delete `
      --resource-group rg-risk-pipeline `
      --factory-name adf-risk-pipeline `
      --pipeline-name $_ --yes
}

# Delete all datasets
az datafactory dataset list `
  --resource-group rg-risk-pipeline `
  --factory-name adf-risk-pipeline `
  --query "[].name" -o tsv | ForEach-Object {
    az datafactory dataset delete `
      --resource-group rg-risk-pipeline `
      --factory-name adf-risk-pipeline `
      --dataset-name $_ --yes
}

# Delete all linked services
az datafactory linked-service list `
  --resource-group rg-risk-pipeline `
  --factory-name adf-risk-pipeline `
  --query "[].name" -o tsv | ForEach-Object {
    az datafactory linked-service delete `
      --resource-group rg-risk-pipeline `
      --factory-name adf-risk-pipeline `
      --linked-service-name $_ --yes
}
```
