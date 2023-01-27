# aks-bicep-templates
Collection of bicep templates to deploy AKS with different setups

Clone the repo, go to the directory of the scenario you want, and run:

```
az deployment sub create   --name southcentralus -l <LOCATION>  --template-file main.bicep
```

Note: Currently all files are referencing southcentralus location, but it can be change using params.