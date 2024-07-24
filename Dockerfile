ARG IMAGE=intersystemsdc/irishealth-community:2020.3.0.200.0-zpm
ARG IMAGE=intersystemsdc/iris-community:2020.4.0.547.0-zpm
ARG IMAGE=containers.intersystems.com/intersystems/iris:2021.1.0.215.0
ARG IMAGE=intersystemsdc/iris-community
FROM $IMAGE

WORKDIR /home/irisowner/irisdev/

## install git
## USER root
##RUN apt update && apt-get -y install git
##USER ${ISC_PACKAGE_MGRUSER}

ARG TESTS=0
ARG MODULE="isc-dev"
ARG NAMESPACE="USER"

RUN --mount=type=bind,src=.,dst=. \
    #pip3 install -r requirements.txt && \
    iris start IRIS && \
	iris session IRIS < iris.script && \
    ([ $TESTS -eq 0 ] || iris session iris -U $NAMESPACE "##class(%ZPM.PackageManager).Shell(\"test $MODULE -v -only\",1,1)") && \
    iris stop IRIS quietly
