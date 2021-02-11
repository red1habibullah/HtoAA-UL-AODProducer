#! /bin/bash

## This script is used to produce AOD files from a gridpack for
## 2017 data. The CMSSW version is 10_6_X and all four lifetimes are

## Usage: ./runOffGridpack.sh gridpack_file.tar.xz

#For lxplus
# export X509_USER_PROXY=$1
# voms-proxy-info -all
# voms-proxy-info -all -file $1

export BASEDIR=`pwd`
GP_f=$1
GRIDPACKDIR=${BASEDIR}/gridpacks/Production
LHEDIR=${BASEDIR}/lhes
SAMPLEDIR=${BASEDIR}/samples
[ -d ${LHEDIR} ] || mkdir ${LHEDIR}

HADRONIZER="externalLHEProducer_and_PYTHIA8_Hadronizer"
namebase=${GP_f/.tar.xz/}
#nevent=500
nevent=500
amass=10

export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
source $VO_CMS_SW_DIR/cmsset_default.sh

## Loading the latest CMSSW version in consistent with 
export SCRAM_ARCH=slc7_amd64_gcc820

if ! [ -r CMSSW_10_6_20/src ] ; then
    scram p CMSSW CMSSW_10_6_20
fi
cd CMSSW_10_6_20/src
eval `scram runtime -sh`
scram b -j 4
tar xaf ${GRIDPACKDIR}/${GP_f}
sed -i 's/exit 0//g' runcmsgrid.sh
#sed -i 's/^G//g' process/madevent/Cards/run_card.dat

ls -lrth

RANDOMSEED=`od -vAn -N4 -tu4 < /dev/urandom`
##Sometimes the RANDOMSEED is too long for madgraph
RANDOMSEED=`echo $RANDOMSEED | rev | cut -c 3- | rev`

namebase=${namebase}_$RANDOMSEED

mkdir -p Configuration/GenProduction/python/

cp "${BASEDIR}/config/haa_a${amass}_cff.py" Configuration/GenProduction/python/.
eval `scram runtime -sh`
scram b -j 4
echo "0.) Generating GEN for a mass ${amass}"
genfragment=${namebase}_GEN_cfg_${amass}.py

##Modify cmsDriver command with the latest conditions consistent with 
cmsDriver.py Configuration/GenProduction/python/haa_a${amass}_cff.py         \
    --fileout file:${namebase}_${amass}_GEN.root         \
    --mc --eventcontent RAWSIM --datatier GEN --conditions 106X_mc2017_realistic_v8 \
    --beamspot Realistic25ns13TeVEarly2017Collision --step LHE,GEN \
    --era Run2_2017 --nThreads 3 --geometry DB:Extended \
    --customise Configuration/DataProcessing/Utils.addMonitoring         \
    --python_filename ${genfragment} --no_exec -n ${nevent}



#Make each file unique to make later publication possible
# linenumber=`grep -n 'process.source' ${genfragment} | awk '{print $1}'`
# linenumber=${linenumber%:*}
# total_linenumber=`cat ${genfragment} | wc -l`
# bottom_linenumber=$((total_linenumber - $linenumber ))
# tail -n $bottom_linenumber ${genfragment} > tail.py
# cmsDriver.py step3 --filein file:MiniAODSIM.root --fileout file:NanoAODSIM.root --mc --eventcontent NANOEDMAODSIM --datatier NANOAODSIM --conditions 106X_mc2017_realistic_v8 --step NANO --nThreads 8 --era Run2_2017 --python_filename NanoAOD_2017_cfg.py -n 10 --no_exechead -n $linenumber ${genfragment} > head.py
# echo "    firstRun = cms.untracked.uint32(1)," >> head.py
# echo "    firstLuminosityBlock = cms.untracked.uint32($RANDOMSEED)," >> head.py
# cat tail.py >> head.py
# mv head.py ${genfragment}
# rm -rf tail.py

cmsRun -p ${genfragment}

# Step1 is pre-computed, since it takes a while to load all pileup pre-mixed samples
echo "1.) Generating SIM for a mass ${amass}"
cmsDriver.py step2 \
    --filein file:${namebase}_${amass}_GEN.root --fileout file:${namebase}_${amass}_SIM.root \
    --mc --eventcontent RAWSIM --runUnscheduled --datatier GEN-SIM --conditions 106X_mc2017_realistic_v8 \
    --beamspot Realistic25ns13TeVEarly2017Collision --step SIM --nThreads 8 --geometry DB:Extended --era Run2_2017 \
    --python_filename ${namebase}_${amass}_SIM_cfg.py --no_exec \
    --customise Configuration/DataProcessing/Utils.addMonitoring --number ${nevent} || exit $?;

cmsRun -p ${namebase}_${amass}_SIM_cfg.py 


echo "2.) Generating DIGI(premix) for a mass ${amass}" 
cmsDriver.py step3 \
    --filein file:${namebase}_${amass}_SIM.root --fileout file:${namebase}_${amass}_DIGIPremix.root  --pileup_input "dbs:/Neutrino_E-10_gun/RunIISummer20ULPrePremix-UL17_106X_mc2017_realistic_v6-v3/PREMIX" \
    --mc --eventcontent PREMIXRAW --runUnscheduled --datatier GEN-SIM-DIGI --conditions 106X_mc2017_realistic_v6 --step DIGI,DATAMIX,L1,DIGI2RAW --procModifiers premix_stage2 \
    --nThreads 8 --geometry DB:Extended --datamix PreMix --era Run2_2017 --python_filename  ${namebase}_${amass}_DIGIPremix_cfg.py --no_exec \
    --customise Configuration/DataProcessing/Utils.addMonitoring --number ${nevent} || exit $?;


cmsRun -p  ${namebase}_${amass}_DIGIPremix_cfg.py


echo "3.) Generating HLT for a mass ${amass} in new CMSSW"

cd ../../.
export SCRAM_ARCH=slc7_amd64_gcc630
if ! [ -r CMSSW_9_4_14_UL_patch1/src ] ; then
    scram p CMSSW_9_4_14_UL_patch1   
fi
mv CMSSW_10_6_20/src/${namebase}_${amass}_DIGIPremix.root CMSSW_9_4_14_UL_patch1/src/.  

cd CMSSW_9_4_14_UL_patch1/src/
eval `scram runtime -sh`

cmsDriver.py step4 \
--filein file:${namebase}_${amass}_DIGIPremix.root --fileout file:${namebase}_${amass}_HLT.root --mc --eventcontent RAWSIM \
--datatier GEN-SIM-RAW --conditions 94X_mc2017_realistic_v15 --customise_commands 'process.source.bypassVersionCheck = cms.untracked.bool(True)' --step HLT:2e34v40 --nThreads 8 \
--geometry DB:Extended --era Run2_2017 --python_filename  ${namebase}_${amass}_HLT_cfg.py  --no_exec \
--customise Configuration/DataProcessing/Utils.addMonitoring --number ${nevent} || exit $?;

cmsRun -p  ${namebase}_${amass}_HLT_cfg.py




cd ../../.

echo "4.) Generating RECO for a mass ${amass} in previous CMSSW"

export SCRAM_ARCH=slc7_amd64_gcc820
if ! [ -r CMSSW_10_6_20/src ] ; then
    scram p CMSSW CMSSW_10_6_20
fi
mv CMSSW_9_4_14_UL_patch1/src/${namebase}_${amass}_HLT.root CMSSW_10_6_20/src/. 

cd CMSSW_10_6_20/src/
eval `scram runtime -sh`

cmsDriver.py step5 \
--filein file:${namebase}_${amass}_HLT.root  --fileout file:${namebase}_${amass}_recoAOD.root --mc --eventcontent AODSIM --runUnscheduled \
--datatier AODSIM --conditions 106X_mc2017_realistic_v6 --step RAW2DIGI,L1Reco,RECO,RECOSIM --nThreads 8 --geometry DB:Extended \
--era Run2_2017 --python_filename ${namebase}_${amass}_recoAOD_cfg.py --no_exec \
--customise Configuration/DataProcessing/Utils.addMonitoring --number ${nevent} || exit $?;

cmsRun -p  ${namebase}_${amass}_recoAOD_cfg.py

pwd
cmd="ls -arlth *.root"
echo $cmd && eval $cmd

echo "DONE."
echo "ALL Done"
