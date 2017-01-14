# Jupyter container used for Galaxy IPython (+other kernels) Integration
# From Björn A. Grüning, bjoern.gruening@gmail.com
#
# VERSION   0.1

FROM jupyter/minimal-notebook:4.0

MAINTAINER Anne Fouilloux, annefou@geo.uio.no

ENV DEBIAN_FRONTEND noninteractive

# Install system libraries first as root
USER root

# Spark dependencies
ENV APACHE_SPARK_VERSION 2.0.2
ENV HADOOP_VERSION 2.7

# Apache Spark installation

RUN cd /tmp && \
        wget -q http://d3kbcqa49mib13.cloudfront.net/spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz && \
        echo "e6349dd38ded84831e3ff7d391ae7f2525c359fb452b0fc32ee2ab637673552a *spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" | sha256sum -c - && \
        tar xzf spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz -C /usr/local && \
        rm spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz
RUN cd /usr/local && ln -s spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} spark

# Mesos dependencies
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF && \
    DISTRO=debian && \
    CODENAME=jessie && \
    echo "deb http://repos.mesosphere.io/${DISTRO} ${CODENAME} main" > /etc/apt/sources.list.d/mesosphere.list && \
    apt-get -y update && \
    apt-get --no-install-recommends -y --force-yes install mesos=0.25.0-0.2.70.debian81 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Spark and Mesos config
ENV SPARK_HOME /usr/local/spark
ENV PYTHONPATH $SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.3-src.zip
ENV MESOS_NATIVE_LIBRARY /usr/local/lib/libmesos.so
ENV SPARK_OPTS --driver-java-options=-Xms1024M --driver-java-options=-Xmx4096M --driver-java-options=-Dlog4j.logLevel=info
# RSpark config
ENV R_LIBS_USER $SPARK_HOME/R/lib

RUN apt-get -qq update && apt-get install --no-install-recommends -y libcurl4-openssl-dev libxml2-dev \
    apt-transport-https python-dev libc-dev pandoc pkg-config liblzma-dev libbz2-dev libpcre3-dev \
    build-essential libblas-dev liblapack-dev gfortran libzmq3-dev libyaml-dev libxrender1 fonts-dejavu \
    libfreetype6-dev libpng-dev net-tools procps libreadline-dev wget software-properties-common octave \
    # Julia dependencies
    julia libnettle4 \
    # for converting latex to pdf
    perl-Tk                           \
    # IHaskell dependencies
    zlib1g-dev libtinfo-dev libcairo2-dev libpango1.0-dev && \
    apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Glasgow Haskell Compiler
RUN add-apt-repository -y ppa:hvr/ghc && \
    sed -i s/jessie/trusty/g /etc/apt/sources.list.d/hvr-ghc-jessie.list && \
    apt-get update && apt-get install -y cabal-install-1.22 ghc-7.8.4 happy-1.19.4 alex-3.1.3 && \
    apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Ruby dependencies
RUN add-apt-repository -y  ppa:brightbox/ruby-ng && \
    sed -i s/jessie/trusty/g  /etc/apt/sources.list.d/brightbox-ruby-ng-jessie.list && apt-get update && \
    apt-get install -y --no-install-recommends ruby2.2 ruby2.2-dev libtool autoconf automake gnuplot-nox libsqlite3-dev \
    libatlas-base-dev libgsl0-dev libmagick++-dev imagemagick && \
    ln -s /usr/bin/libtoolize /usr/bin/libtool && \
    apt-get purge -y software-properties-common && \
    apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN gem install --no-rdoc --no-ri rbczmq sciruby-full 

ENV PATH /home/$NB_USER/.cabal/bin:/opt/cabal/1.22/bin:/opt/ghc/7.8.4/bin:/opt/happy/1.19.4/bin:/opt/alex/3.1.3/bin:$PATH

USER jovyan

# Install Python 3.5 (dependency for  spylon kernel)
RUN conda install --yes python=3.5 && conda clean -yt

# Python packages
RUN conda config --add channels r && conda install --yes numpy pandas scikit-learn scikit-image matplotlib scipy seaborn sympy rpy2 \
    biopython cython patsy statsmodels cloudpickle dill numba bokeh && conda clean -yt && pip install --no-cache-dir bioblend

# Now for a python2 environment
RUN conda create -p $CONDA_DIR/envs/python2 python=2.7 ipykernel numpy pandas scikit-learn rpy2 \
    biopython scikit-image matplotlib scipy seaborn sympy cython patsy statsmodels cloudpickle dill numba bokeh && conda clean -yt && \
    /bin/bash -c "source activate python2 && pip install --no-cache-dir bioblend galaxy-ie-helpers"

# python package for HDF4 data
RUN conda config --add channels conda-forge && conda install --yes pyhdf && conda clean -yt

RUN $CONDA_DIR/envs/python2/bin/python \
    $CONDA_DIR/envs/python2/bin/ipython \
    kernelspec install-self --user

# IRuby
RUN iruby register

# R packages
RUN conda config --add channels r && conda install --yes r-irkernel r-plyr r-devtools r-rcurl r-dplyr r-ggplot2 \
    r-caret rpy2 r-tidyr r-shiny r-rmarkdown r-forecast r-stringr r-rsqlite r-reshape2 r-nycflights13 r-randomforest && conda clean -yt

# IJulia and Julia packages
RUN julia -e 'Pkg.add("IJulia")' && \
    julia -e 'Pkg.add("Gadfly")' && julia -e 'Pkg.add("RDatasets")'

# IHaskell + IHaskell-Widgets + Dependencies for examples
RUN cabal update && \
    CURL_CA_BUNDLE='/etc/ssl/certs/ca-certificates.crt' curl 'https://www.stackage.org/lts-2.22/cabal.config?global=true' >> ~/.cabal/config && \
    cabal install cpphs && \
    cabal install gtk2hs-buildtools && \
    cabal install ihaskell-0.8.0.0 --reorder-goals && \
    cabal install ihaskell-widgets-0.2.2.1 HTTP Chart Chart-cairo && \
     ~/.cabal/bin/ihaskell install && \
    rm -fr $(echo ~/.cabal/bin/* | grep -iv ihaskell) ~/.cabal/packages ~/.cabal/share/doc ~/.cabal/setup-exe-cache ~/.cabal/logs

USER $NB_USER

# Apache Toree kernel
RUN pip --no-cache-dir install https://dist.apache.org/repos/dist/dev/incubator/toree/0.2.0/snapshots/dev1/toree-pip/toree-0.2.0.dev1.tar.gz
RUN jupyter toree install --user

# Spylon-kernel
RUN pip --no-cache-dir install "spylon-kernel==0.1.2"
RUN python -m spylon_kernel install --user

USER jovyan

# Extra Kernels
RUN pip install --user --no-cache-dir bash_kernel bioblend octave_kernel galaxy-ie-helpers && \
    python -m bash_kernel.install && \
    # add galaxy-ie-helpers to PATH
    echo 'export PATH=/home/jovyan/.local/bin:$PATH' >> /home/jovyan/.bashrc 

ADD ./startup.sh /startup.sh
ADD ./monitor_traffic.sh /monitor_traffic.sh
ADD ./get_notebook.py /get_notebook.py

USER root

# /import will be the universal mount-point for Jupyter
# The Galaxy instance can copy in data that needs to be present to the Jupyter webserver
RUN mkdir /import

#RUN echo 'export PATH=/opt/conda/bin:$PATH' > /home/jupyter/.profile
#RUN echo 'export PYTHONPATH=/home/jupyter/py/:$PYTHONPATH' >> /home/jupyter/.profile

RUN rm /etc/profile.d/conda.sh

# Create user and group with the same UID and GID as the Galaxy main docker container.
#RUN groupadd -r jupyter -g 1450 && \
#    useradd -u 1450 -r -g jupyter -d /home/jupyter -c "Jupyter user" jupyter && \
#    chown jupyter:jupyter /home/jupyter

# We can get away with just creating this single file and Jupyter will create the rest of the
# profile for us.
RUN mkdir -p /home/$NB_USER/.ipython/profile_default/startup/
RUN mkdir -p /home/$NB_USER/.jupyter/custom/

COPY ./ipython-profile.py /home/$NB_USER/.ipython/profile_default/startup/00-load.py
#ADD ./ipython_notebook_config.py /home/$NB_USER/.jupyter/jupyter_notebook_config.py
COPY jupyter_notebook_config.py /home/$NB_USER/.jupyter/

ADD ./custom.js /home/$NB_USER/.jupyter/custom/custom.js
ADD ./custom.css /home/$NB_USER/.jupyter/custom/custom.css
ADD ./default_notebook.ipynb /home/$NB_USER/notebook.ipynb

# ENV variables to replace conf file
ENV DEBUG=false \
    GALAXY_WEB_PORT=10000 \
    NOTEBOOK_PASSWORD=none \
    CORS_ORIGIN=none \
    DOCKER_PORT=none \
    API_KEY=none \
    HISTORY_ID=none \
    REMOTE_HOST=none \
    GALAXY_URL=none

RUN chown -R $NB_USER:users /home/$NB_USER/ /import

USER jovyan

WORKDIR /import

# Jupyter will run on port 8888, export this port to the host system

# Start Jupyter Notebook
CMD /startup.sh
