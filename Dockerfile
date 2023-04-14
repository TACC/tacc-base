ARG CUDA=11.2.2
FROM nvidia/cuda:${CUDA}-cudnn8-runtime-ubuntu18.04
ARG CUDA

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential \
        bison \
        ca-certificates \
        curl \
        cuda-command-line-tools-$(cut -f1,2 -d- <<< ${CUDA//./-}) \
        gfortran \
        less \
        lbzip2 \
        libibverbs-dev \
        libnuma-dev \
        libibmad-dev \
        libibumad-dev \
        librdmacm-dev \
        libxml2-dev \
        libfabric-dev \
        wget \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get autoremove -y \
    && apt-get clean

########################################
# Install conda
########################################

ENV CONDA_DIR=/opt/conda
ENV PATH=${CONDA_DIR}/bin:${PATH}
# Download and install miniforge
RUN wget -q -P /tmp https://github.com/conda-forge/miniforge/releases/download/23.1.0-0/Miniforge3-23.1.0-0-Linux-x86_64.sh \
    && bash /tmp/Miniforge3-23.1.0-0-Linux-x86_64.sh -b -p $CONDA_DIR \
    && rm /tmp/Miniforge3-23.1.0-0-Linux-x86_64.sh \
    && conda config --system --set auto_update_conda false \
    && conda config --system --set show_channel_urls true \
    && conda config --system --set default_threads 4 \
    && conda install --yes --no-update-deps python=3.9 \
    && ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh 

########################################
# Install CUDA and PT
########################################
RUN conda install --yes --no-update-deps -c pytorch \
    cudatoolkit=$(cut -f1,2 -d. <<< ${CUDA}) \
    cudnn=8.1 \
    pytorch==1.12.1 \
    torchvision==0.13.1 \
    torchtext==0.13.1 \
    pytorch-lightning==2.0.1.post0 \
    transformers==4.27.4

########################################
# Install Jupyter and Misc
########################################
RUN conda install --yes --no-update-deps \
    h5py==3.8.0 \
    ipykernel==6.22.0 \
    jupyter==1.0.0 \
    jupyterlab==3.6.3 \
    matplotlib==3.7.1 \
    mock==5.0.1 \
    scipy==1.10.1 \
    scikit-learn==1.2.2 \
    scikit-image==0.20.0 \
    cython==0.29.34 \
    && find ${CONDA_DIR} -follow -type f -name '*.a' -delete \
    && find ${CONDA_DIR} -follow -type f -name '*.pyc' -delete \
    && conda clean -ay

########################################
# Install TF
########################################
RUN pip install tensorflow==2.11.0

########################################
# Install mpi
########################################
# Install mvapich2-2.3
ARG MAJV=2
ARG MINV=3
ARG BV=.7
ARG DIR=mvapich${MAJV}-${MAJV}.${MINV}${BV}

RUN curl http://mvapich.cse.ohio-state.edu/download/mvapich/mv${MAJV}/${DIR}.tar.gz | tar -xzf - \
    && cd ${DIR} \
    && ./configure \
	--with-device=ch3 \
	--with-ch3-rank-bits=32 \
	--enable-fortran=yes \
	--enable-cxx=yes \
	--enable-romio \
	--enable-fast=O3 \
    #&& make -j $(($(nproc --all 2>/dev/null || echo 2) - 2)) \
    && make \
    && make install \
    && cd ../ && rm -rf ${DIR} \
    && rm -rf /usr/local/share/doc/mvapich2

# Add hello world
COPY extras/hello.c /tmp/hello.c
RUN mpicc /tmp/hello.c -o /usr/local/bin/hellow \
    && rm /tmp/hello.c

# Build benchmark programs
COPY extras/install_benchmarks.sh /tmp/install_benchmarks.sh
RUN bash /tmp/install_benchmarks.sh

# Test installation
RUN MV2_SMP_USE_CMA=0 mpirun -n 2 hellow

CMD ["/bin/bash"]
