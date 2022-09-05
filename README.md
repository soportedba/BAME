# BAME
BAME, Business Analytics Made Easy project

## Objectives
* k8s´s based project to be run on any type of infrastructure/provider (Azure, AWS, on-premisse)
* Open source tools and frameworks
	* Pentaho https://sourceforge.net/projects/pentaho/
	* Portofino https://sourceforge.net/projects/portofino/
	* PostgreSQL https://www.postgresql.org/
	* Facturascripts https://github.com/FacturaScripts/docker-facturascripts
* Easy creation of dimensions and indicators through web interface
* ETL integration to create the DatawareHouse automatically
* Using the Kimball´s best practices for DatawareHousing  https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/
* Totally parametrized
* Modular (can install any of the components)
* Example aplication deployment to get data from (Facturascripts)

## Notes
* Tests done with local k8s enviroment from Docker Desktop, some properties should need to be changed to make the deployments work properly for other k8s environments.

## Pending work
* Parameters in configmap yaml files, try to use Helm for even more templated deployments

## Building
Will list all the component deployments.

* Utilities
Deploy utilities pod, with postgresql/mysql clients, dnsutils, wget, curl, adminer
```
kubectl apply -f BAMEUtilities/utilities.configmap.yaml
kubectl apply -f BAMEUtilities/utilities.yaml
```

* PostgreSQL (for DWH)
Deploy PostgreSQL to be used as DWH repository
```
kubectl apply -f BAMEDatabase/postgres.configmap.yaml
kubectl apply -f BAMEDatabase/postgres.storage.yaml
kubectl apply -f BAMEDatabase/postgres.yaml
```
Check configmap, pv, pvc, connect to postgresql container in pod
```
kubectl describe configmaps
kubectl get pv postgres-pv-volume
kubectl get pvc postgres-pv-claim
kubectl exec -it pod/postgres-0 -- /bin/bash
```

* MySQL (for app)
Deploy MySQL to be used as main application repository (Facturascripts)
```
kubectl apply -f BAMEDatabase/mysql.configmap.yaml
kubectl apply -f BAMEDatabase/mysql.storage.yaml
kubectl apply -f BAMEDatabase/mysql.yaml
```
Check configmap, pv, pvc, connect to mysql container in pod
```
kubectl describe configmaps
kubectl get pv mysql-pv-volume
kubectl get pvc mysql-pv-claim
kubectl exec -it pod/mysql-0 -- /bin/bash
```

## Accessing
Currently, access to resources is defined by NodePort, so to access to internal resources like MySQL, PostgreSQL, adminer ... you need to check the assigned local port:
```
kubectl get service
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP    PORT(S)          AGE
kubernetes       ClusterIP   10.96.0.1       <none>         443/TCP          124m
mysql            NodePort    10.106.250.4    192.168.0.34   3306:32762/TCP   116m
postgres         NodePort    10.104.56.37    192.168.0.34   5432:30636/TCP   121m
utilities        NodePort    10.106.128.12   192.168.0.34   8080:31255/TCP   119m
```
So, to access postgresql database you can use: 192.168.0.34:30636 externally from k8s, or name "postgres" with default port: 5432 if accessing internally from k8s.

