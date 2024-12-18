# Artifacts for GogetaFS@FAST'25

This repository contains the artifacts for the paper "Don't Maintain Twice, It's Alright: Merged Metadata Management in Deduplication File System with GogetaFS" accepted by FAST'25. 

The artifacts are extended from the [Light-Dedup](https://github.com/Light-Dedup) project, with the same hardware and software requirements. The user can refer to the [Light-Dedup](https://github.com/Light-Dedup) for setups.

- [Artifacts for GogetaFS@FAST'25](#artifacts-for-gogetafsfast25)
  - [1. Quick Start](#1-quick-start)
    - [1.1 Prerequisites](#11-prerequisites)
    - [1.2 Usage of the GogteaFS repository](#12-usage-of-the-gogteafs-repository)
    - [1.3 One-click "run\_all.sh"](#13-one-click-run_allsh)
  - [2. Step-by-Step reproducing](#2-step-by-step-reproducing)
    - [2.1 Output Results](#21-output-results)
    - [2.2 Reproducing Tables](#22-reproducing-tables)
    - [2.3 Reproducing Figures](#23-reproducing-figures)
    - [2.4 Reproducing Z-SSD results](#24-reproducing-z-ssd-results)
  - [3. Branches Corresponding to the Paper](#3-branches-corresponding-to-the-paper)
    - [3.1 Light-Dedup-J (GogetaFS for PM) repository](#31-light-dedup-j-gogetafs-for-pm-repository)
    - [3.2 NV-Dedup repository](#32-nv-dedup-repository)
    - [3.3 GogetaFS (for SSD) repository](#33-gogetafs-for-ssd-repository)


## 1. Quick Start
### 1.1 Prerequisites

- Kernel: Tested with Linux kernel 5.1.0 modified by [SplitFS](https://github.com/rohankadekodi/SplitFS-5.1).

- OS: CentOS Stream 8 (Ubuntu should work too).

- Server with PMs. A server with at least one Intel PM equipped (256GiB). 

- Sufficient memory. Reproducing experiments requires much memory because caching the compiled Linux kernel source code (the copy workload) requires about 15--20 GiB, and the operating system itself and GogetaFS all require significant memory usage.

### 1.2 Usage of the GogteaFS repository

To reproduce the experiments, the user is required to get the repositories listed below:

- GogetaFS for PM: [https://github.com/GogetaFS/Light-Dedup-J.git](https://github.com/GogetaFS/Light-Dedup-J.git).
- GogetaFS for SSD: [https://github.com/GogetaFS/GogetaFS.git](https://github.com/GogetaFS/GogetaFS.git).
- Evaluation tools and scripts on PM: [https://github.com/GogetaFS/tests.git](https://github.com/GogetaFS/tests.git).
- Evaluation tools and scripts on SSD: [https://github.com/GogetaFS/GogetaFS-Tests.git](https://github.com/GogetaFS/GogetaFS-Tests.git).
- NV-Dedup source code: [https://github.com/GogetaFS/nv-dedup.git](https://github.com/GogetaFS/nv-dedup.git).
- f2fs source code: [https://github.com/GogetaFS/f2fs.git](https://github.com/GogetaFS/f2fs.git).

You should run the following command to organize them so that the scripts can work correctly:

```bash
#!/bin/bash
cd <Your directory>
git clone https://github.com/GogetaFS/tests.git GogetaFS-AE
cd GogetaFS-AE

git clone https://github.com/GogetaFS/Light-Dedup-J.git
git clone https://github.com/GogetaFS/nvm_tools-J.git
git clone https://github.com/GogetaFS/nv-dedup.git

mkdir SSD-emu && cd SSD-emu
git clone https://github.com/GogetaFS/f2fs.git
git clone https://github.com/GogetaFS/GogetaFS.git
git clone https://github.com/GogetaFS/GogetaFS-Tests.git
```

### 1.3 One-click "run_all.sh"

We provide `run_all.sh` that can automatically install the required software, run all the experiments involved in the paper, draw all the figures in our paper, and build similar Latex tables presented in our paper:

```bash
bash ./run_all.sh
```

Note that we configure the tested pmem to /dev/pmem0 as default. The corresponding pmem_id is retrieved automatically from the *ipmctl*. 

**Also NOTE: Running all the experiments might require about one day or longer. You can run the `bash ./run_all.sh` in `tmux` to keep on the progress**

## 2. Step-by-Step reproducing

### 2.1 Output Results

We focus on introducing the files in the directories with prefixes "FIG" and "TABLE". The raw output files are mostly named with the prefix "performance-comparison-table" or "xx-table", which can be obtained by running `bash test.sh`. `plot.ipynb` and `craft-latex-table.py` scripts are provided for drawing figures and building latex table, respectively. Some tables require further calculation on raw output, such as calculating extra read/write bytes per block in Table 2. Thus, we provide `process.py` script to automatically process the raw output files. Each experiment can be conducted many times just by passing a `loop` variable to the `test.sh`, and a `agg.sh` script is provided to present the average values. We rename the original file with the suffix "_orig". 

Generally, typical workflows for reproducing figures and tables are presented as follows.

```bash
# General workflow to reproducing tables

cd GogetaFS-AE/tests/TABLExx/
# Step 1. Run Experiment
bash ./test.sh $loop
# Step 2. Aggregate Results
bash agg.sh "$loop"
# Step 3. Calculation on Raw output
if [ -f "process.py" ]; then
    python3 process.py
fi
# Step 4. Building Table
python3 craft-latex-table.py
```

```bash
# General workflow to reproducing figures.

cd GogetaFS-AE/tests/FIGxx/
# Step 1. Run Experiment
bash ./test.sh $loop
# Step 2. Aggregate Results
bash agg.sh "$loop"
# Step 3. Drawing Figures
ipython plot.ipynb
```

In the following sections, we consider the `loop`| as 1 by default for brevity. 

### 2.2 Reproducing Tables

**Table 2: I/O amplification comparison**. The corresponding script for Table 2 is presented in  `GogetaFS-AE/tests/TABLE_AgingSystem/test.sh`. To run the script, the user should make a few modifications: **(1) Find out tested PMEM id**. Running the command  `sudo ipmctl show -performance` can obtain the specific PMEM id (the first DimmID belongs to /dev/pmem0, the second DimmID belongs to /dev/pmem1, and so on). In our case, our tested PMEM id is 0x20 (the default PMEM device is /dev/pmem0). **(2) Pass corresponding PMEM id**. Pass the corresponding PMEM id queried in step (1) to the `test.sh` script. For example:  `bash ./test.sh 0x20`. **Note that the PMEM id should also be passed to the test scripts for Table 5**. Here, **if the user uses one-click command, we automatically select the first PMEM for experiemnts**. The extra reads/writes are calculated by subtracting golden branch `volatile-fpentry`'s READ/WRITE, and thus RPB/WPB can be accordingly obtained. For convenience, we have created a Python script, `process.py` to automatically calculate the final results. Besides, `craft-latex-table.py` script is also added to build Table 2. In summary, the overall process is:

The overall process is:

```bash
# Reproducing Table 2.

cd GogetaFS-AE/tests/TABLE_AgingSystem/
sudo ipmctl show -performance
# select the DIMM id for pmem0, e.g., 0x20
bash ./test.sh 0x20
# calculating results
python3 process.py
# build Table 2
python3 craft-latex-table.py
```

Note that the above process outputs two files: latex-table-4096 and latex-table-2097152, which correspond to 4KiB and 2MiB I/O respectively. Users are required to manually copy the content to the final latex table.

**Table 3: Recovery overheads**. The corresponding script is presented in `GogetaFS-AE/tests/TABLE_RECOVERY/test.sh`. Similarly, to reproduce this table, one can follow the commands:

```shell
# Reproducing Table 6.

cd GogetaFS-AE/tests/TABLE5_RECOVERY/
bash ./test.sh
# formatting time
bash agg.sh 1
# build Table 6
python3 craft-latex-table.py
```

### 2.3 Reproducing Figures
**Figure 2: Throughput comparison among exsiting DedupFSes**. The corresponding script is presented in `GogetaFS-AE/tests/FIG_MOTIVATION/test-fio.sh`. The output results are presented in "performance-comparison-table-fio". The user can use "plot.ipynb" to plot the figure: `FIG-MOTIVATION-BW.pdf`.

**Figure 3: Approximate deduplication overheads breakdown**. The corresponding script is presented in `GogetaFS-AE/tests/FIG_MOTIVATION/test-fio-breakdown.sh`. The output results are presented in "performance-comparison-table-fio-breakdown". The user can use "plot.ipynb" to plot the figure: `FIG-MOTIVATION.pdf`.

**Figure 5: The space overheads of LFP entries**. The corresponding script is presented in `GogetaFS-AE/tests/FIG_MetaSpaceOverhead/ploy.ipynb`. Simply run the script to obtain the figure: `FIG-SpaceOverhead.pdf`.

**Figure 7: Performance comparison between SFP and OFT**. We use the same script as in Figure 9 (later introduced). The corresponding script is presented in `GogetaFS-AE/tests/FIG_FIO/test-continuous-all-dram.sh`. To obtain the figure, the user can use `plot.ipynb` (in the last cell) to plot the figure: `FIG-IO-SFPvsOET.pdf`.

**Figure 9: FIO write throughput comparison under sufficient memory**. The corresponding script is presented in `GogetaFS-AE/tests/FIG_FIO/test-all-dram.sh`. The output results are presented in `performance-comparison-table-4K-all-dram` and `performance-comparison-table-continuous-all-dram`. The user can use `plot.ipynb` to plot the figure: `FIG-IO-ALL-DRAM.pdf`.

**Figure 10: I/O throughput comparison under real-world scenarios**. The corresponding script is presented in `GogetaFS-AE/tests/FIG_RealWorld/test-all-dram.sh`. The output results are presented in `performance-comparison-table-cp-all-dram` and `performance-comparison-table-trace-all-dram`. The user can use `plot.ipynb` to plot the figure: `FIG-REAL-ALL-DRAM.pdf`.

The ***OSLab*** trace can be downloaded at <https://github.com/Light-Dedup/tests/releases/tag/homes-2022-fall-50>. 

**Figure 11: Approximate deduplication time breakdown**. The corresponding scripts are presented in `GogetaFS-AE/tests/FIG_DedupBreakdown/test-fio.sh` and `GogetaFS-AE/tests/FIG_DedupBreakdown/test-real.sh`. The output results are presented in `performance-comparison-table-fio` and `performance-comparison-table-real`. The user can use `plot.ipynb` to plot the figure: `FIG-DedupBreakdown.pdf`.

**Figure 12: I/O throughput comparison under constrained memory**. The corresponding script is presented in `GogetaFS-AE/tests/FIG_Hybrid/test.sh`. The results are composed of four parts: `performance-comparison-table-4K-hybrid`, `performance-comparison-table-continuous-hybrid`, `performance-comparison-table-cp-hybrid`, and `performance-comparison-table-trace-hybrid`. The user can use `plot.ipynb` to plot the figure: `FIG-REAL-ALL-Hybrid.pdf`.

**Figure 13: I/O throughput comparison of emulated logging (left) and mobile trace (right) under scarce memory**. The corresponding scripts are presented in `GogetaFS-AE/tests/FIG_FIO/test-all-pm.sh` and `GogetaFS-AE/tests/FIG_RealWorld/test-trace-all-pm.sh`. The results are composed of three parts. Under `FIG_FIO`, `performance-comparison-table-4K-all-pm`, `performance-comparison-table-continuous-all-pm`, and under `FIG_RealWorld`, `performance-comparison-table-trace-all-pm`. The user should run `plot.ipynb` (using the cell named `All-PM-Embedded`) in `FIG_FIO` to plot the figure: `FIG-REAL-ALL-PM.pdf`.

### 2.4 Reproducing Z-SSD results

- We reproduce the Z-SSD results using [FEMU](git@github.com:MoatLab/FEMU.git) environment. 

- We install a Ubuntu 20.04 LTS image with the kernel version 5.4.0-189-generic. 

- We modify femu/build-femu/run-nossd.sh to run the Z-SSD experiments:

    ```bash
    #!/bin/bash
    # Huaicheng Li <huaicheng@cs.uchicago.edu>
    # Run FEMU with no SSD emulation logic, (e.g., for SCM/Optane emulation)

    # Image directory
    IMGDIR=$HOME/
    # Virtual machine disk image
    OSIMGF=$IMGDIR/ub20.qcow2


    if [[ ! -e "$OSIMGF" ]]; then
        echo ""
        echo "VM disk image couldn't be found ..."
        echo "Please prepare a usable VM image and place it as $OSIMGF"
        echo "Once VM disk image is ready, please rerun this script again"
        echo ""
        exit
    fi

    # enable performance mode
    echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

    sudo ./qemu-system-x86_64 \
        -name "FEMU-NoSSD-VM" \
        -enable-kvm \
        -cpu host \
        -smp 36 \
        -m 32G \
        -device virtio-scsi-pci,id=scsi0 \
        -device scsi-hd,drive=hd0 \
        -drive file=$OSIMGF,if=none,aio=native,cache=none,format=qcow2,id=hd0 \
        -device femu,queues=64,devsz_mb=32768,id=nvme0 \
        -net user,hostfwd=tcp::2333-:22 \
        -net nic,model=virtio \
        -nographic \
        -qmp unix:./qmp-sock,server,nowait
    ```

- Inside femu, using `scp` to copy `GogetaFS-AE/SSD-emu/*` to the VM, supposing the directory is `/home/user/SSD-emu`.

- Run the following commands to reproduce the Z-SSD results:

    ```bash
    cd /home/user/SSD-emu/GogetaFS-Tests
    bash run_all.sh
    ```
- The final figures should be stored in the `/home/user/SSD-emu/GogetaFS-Tests/FIG_FIO/FIG-Port.pdf`.

## 3. Branches Corresponding to the Paper

### 3.1 Light-Dedup-J (GogetaFS for PM) repository

- *nova-pipe*: NOVA file system, the baseline.

- *nova-pipe-failure*: NOVA file system with failure recovery.

- *denova*: DeNova file system.

- *denova-non-crypto*: DeNova without using crypto hash.

- *nova-pipe-dedup*: Light-Dedup file system.

- *nova-pipe-dedup-failure*: Light-Dedup file system with failure recovery.

- *light-fs-dedup-64bit-fp*: GogetaFS with non-secure mode (default).

- *light-fs-dedup-64bit-fp-failure*: GogetaFS with failure recovery.

- *light-fs-dedup*: GogetaFS with secure mode.

- *light-fs-dedup-disable-dedup*: GogetaFS with deduplication disabled.

- *light-fs-dedup-super*: GogetaFS with super-fingerprint (SFP).

- *light-fs-dedup-regulate*: GogetaFS with regulated memory (Figure 8b with mem>0 and Figure 8d with mem=0).

- *light-fs-dedup-pm-table*: GogetaHybrid (Figure 8c).
 
- *light-fs-dedup-pm-table-persistence*: Light-Dedup with memory regulation (corresponding to Light-Dedup in Figure 12).

- *light-fs-dedup-pm-all*: GogetaSHT (Figure 8e), which is GogetaFS using static hash table for all-in-PM organization.

- *light-fs-dedup-pm-all-persistence*: SHT, GogetaSHT without LFP entries.

### 3.2 NV-Dedup repository

- *master*: NV-Dedup with the original implementation.

- *non-crypto*: NV-Dedup without using crypto hash.

### 3.3 GogetaFS (for SSD) repository

- *main*: GogetaFS for SSD.

- *lightdedup*: Light-Dedup proted to SSD.

- *hfdedup*: HF-Dedupe reproduced on SSD.

- *SmartDedup*: SmartDedup reproduced on SSD.
  