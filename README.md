# aks-bicep-templates
Collection of bicep templates to deploy AKS with different setups

Clone the repo, go to the directory of the scenario you want, and run:

```
az deployment sub create   --name aks-kubenet-custom-vnet -l southcentralus  --template-file main.bicep
```
