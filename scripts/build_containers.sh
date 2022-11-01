#!/bin/bash

# Only needed if you want to build your own version of the container images, otherwise skip.

# Docker Hub Setup
DOCKERHUB_USER=kevingbb

# Setup ACR (OPTIONAL)
RG="RESOURCE_GROUP_GOES_HERE"
ACR_NAME="ACR_GOES_HERE"
az acr login -n $ACR_NAME

# Build Store App
cd /workspaces/lunchbytesNov2022/storeapp
npm install
node app.js
docker build -t $DOCKERHUB_USER/storeapp:v1.1 .
docker push $DOCKERHUB_USER/storeapp:v1.1
# (OPTIONAL)
az acr build --registry $ACR_NAME --image storeapp:v0.1 --file Dockerfile .

# Build Queue Reader App
cd /workspaces/lunchbytesNov2022/queuereader
dotnet restore
dotnet run
docker build -t $DOCKERHUB_USER/queuereader:v1.1 .
docker push $DOCKERHUB_USER/queuereader:v1.1
# (OPTIONAL)
az acr build --registry $ACR_NAME --image queuereader:v0.1 --file Dockerfile .

# Build HTTP API App
cd /workspaces/lunchbytesNov2022/httpapi
dotnet restore
dotnet run
docker build -t $DOCKERHUB_USER/httpapi:v1.1 .
docker push $DOCKERHUB_USER/httpapi:v1.1
# (OPTIONAL)
az acr build --registry $ACR_NAME --image httpapi:v0.1 --file Dockerfile .
# Build HTTP API App v2 with Queue Fix
cd /workspaces/lunchbytesNov2022/httpapi
dotnet restore
dotnet run
docker build -t $DOCKERHUB_USER/httpapi:v1.2 .
docker push $DOCKERHUB_USER/httpapi:v1.2
# (OPTIONAL)
az acr build --registry $ACR_NAME --image httpapi:v0.1 --file Dockerfile .

# Build Operational API App
cd /workspaces/lunchbytesNov2022/ca-operational-api
pip install -r requirements.txt
python app.py
docker build -t $DOCKERHUB_USER/ca-operational-api:v1.1 .
docker push $DOCKERHUB_USER/ca-operational-api:v1.1
# (OPTIONAL)
az acr build --registry $ACR_NAME --image ca-operational-api:v0.1 --file Dockerfile .

# Build Operational Dashboard App
cd /workspaces/lunchbytesNov2022/ca-operational-dashboard
npm install
npm run start
docker build -t $DOCKERHUB_USER/ca-operational-dashboard:v1.1 .
docker run -it -p 3000:80 --rm \
  --env REACT_APP_API=dashboardapi \
  --env CONTAINER_APP_ENV_DNS_SUFFIX=livelybeach-dcd08a0b.northeurope.azurecontainerapps.io  \
  --name nginx $DOCKERHUB_USER/ca-operational-dashboard:v1.1
cat /usr/share/nginx/html/env_config.js
docker push $DOCKERHUB_USER/ca-operational-dashboard:v1.1
# (OPTIONAL)
az acr build --registry $ACR_NAME --image ca-operational-dashboard:v0.1 --file Dockerfile .
