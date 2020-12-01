# Template for easy build and deploy of docker images to kubernetes

This template is a way to get started with docker and kubernetes as well as Github Actions. We assume you have a docker container ready to be built and deployed.

### Prerequisites
All this needs to be done **BEFORE** you run the script mentioned below.  
You need to install:
  * [Azure-cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)  
    * run `az login <NRK-email>`
  * [KubeCtl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
    * Get config to your cluster from [this list](https://confluence.nrk.no/display/PLAT/Liste+over+kubernetes+clustre+og+config)
  * [Create the namespace](https://confluence.nrk.no/display/PLAT/Liste+over+kubernetes+clustre+og+config) in the choosen cluster with the mknamespace app corresponding to the cluster to deploy to

**WARNING**

We are assuming that you are creating a new namespace, hence you have the correct permissions on that namespace (admin).
If you choose to use this template on an existing namespace, might be that your permissions have to be adjusted for the scripts to work correctly.

### Getting started
To get started:  
  * Click the green button with the text "**Use this template**" and fill in the required information to create your new repository ([naming strategy for repos in NRK](https://blåbok.intern-we.drift.azure.nrk.cloud/Standarder/RFC-9-reponavngiving.html))
  * Clone your new repo
  * Edit the Dockerfile and insert the magic you have done for your wonderful app. (You don't have to do this at this point, but you can). 
  * Run `.github/scripts/run.sh`: the scripts does some important things:
    * It populates the template for a master branch pipeline with the kubernetes cluster of your choice, the namespace of your choice, the name of the app and so on.
    * It populates the template for a kubernetes deployment of the named app with the corresponding variables.
    * It creates Azure ServicePrincipal to push to plattform registry and Kubernetes Service Account to deploy to kubernetes cluster and returns the snippets you have to cut and paste into the "secrets" section of your repo. In this picture ![In this picture](/images/secrets.png) you are given an example: K8S_SA_SECRET , REGISTRY_USERNAME and REGISTRY_PASSWORD must be in place,you have to create these secrets manually in the GUI and call them *exactly* like them. Populate them with the corresponding jsons / yaml you get from the script. 
  * Git commit your changes and push them upstream. This should start a master build and deployment of your app: in the "Actions" section of your repository you can see the output of your pipeline.



### More pipelines!
  * If you later on decide you want a "test" pipeline, you will have to populate the corresponding pipeline variables. You can find a test pipeline in the .github directory ("docker-build-push-test.yaml"), you will have to populate the following variables (use the master pipeline as a guide):
    * K8S_API_URL: this is the address of the API of the cluster you are going to use. We assume that this will be a different cluster than the one you used for your master branch, but we populated it with the same to begin with. This means that if you don't edit this value, you will deploy your test pods in the same namespace that you used for the master branch. If you want to use another namespace instead, create a namespace on the cluster of your choice, log in to the second cluster using the azure-cli or gcloud commands, and you can then fetch the API_URL using the script fetch_api.sh in the scripts directory.
    * K8S_NAMESPACE: the namespace in the test cluster of your choice (of course you need to create it, if you haven't yet).
    * Once the namespace is created, log in the new cluster for your test pipeline using the appropriate tools, and get into the namespace you are going to use.
    * You will have to add to add new secret for your test pipeline, so you will need a corresponding secret manually created in the "secrets" section of your github repository. Again, use the picture as a reference, and edit docker-build-push-test.yaml to match it. Run the script k8s_serviceaccount.sh, it will output the necessary data you will have to use to create the corresponding secret in the GUI.
  * Repeat the process for even more pipelines.
    
### Various
Keep in mind that this is just a sample and a "get started"-template.  
If you want to do more, please see the documentation of Github Actions to read up on more advanced things to do with your workflow.  
