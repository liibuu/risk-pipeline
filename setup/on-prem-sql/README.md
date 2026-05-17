
Lookup Activity (SELECT table names from DB) → ForEach Activity (loop over results) → Copy Activity

```bash
# Step 1: Install Self-hosted Integration Runtime


# Step 2: Create the SQL Server Linked Service

# Step 3: Create the Copy Pipeline
az datafactory dataset create `
  --resource-group rg-risk-pipeline `
  --factory-name adf-risk-pipeline `
  --dataset-name ds_sqlserver_all `
  --properties `@ds_sqlserver_all.json

az datafactory dataset create `
  --resource-group rg-risk-pipeline `
  --factory-name adf-risk-pipeline `
  --dataset-name ds_adls_landing_all `
  --properties `@ds_adls_landing_all.json

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
  --run-id "e9a339a6-51e6-11f1-b315-7c8ae17039b8"  `
  --query "{status:status, message:message}"


# Step 5: Test & Validate
```
