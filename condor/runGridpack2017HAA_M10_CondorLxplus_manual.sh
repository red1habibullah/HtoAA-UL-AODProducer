#! /bin/bash

## This script is used to produce AOD files from a gridpack for
## 2017 data. The CMSSW version is 10_6_X and all four lifetimes are

## Usage: ./runOffGridpack.sh gridpack_file.tar.xz

#For lxplus
export X509_USER_PROXY=$1
voms-proxy-info -all
voms-proxy-info -all -file $1

export BASEDIR=`pwd`
GP_f=$2
GRIDPACKDIR=${BASEDIR}/gridpacks/Production
LHEDIR=${BASEDIR}/lhes
SAMPLEDIR=${BASEDIR}/samples
[ -d ${LHEDIR} ] || mkdir ${LHEDIR}

HADRONIZER="externalLHEProducer_and_PYTHIA8_Hadronizer"
namebase=${GP_f/.tar.xz/}
#nevent=500
nevent=10
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
#sed -i 's/exit 0//g' runcmsgrid.sh
#sed -i 's/^G//g' process/madevent/Cards/run_card.dat
#sed -i 's/[^[:print:]]//g' process/madevent/Cards/run_card.dat   
ls -lrth

RANDOMSEED=`od -vAn -N4 -tu4 < /dev/urandom`
##Sometimes the RANDOMSEED is too long for madgraph
RANDOMSEED=`echo $RANDOMSEED | rev | cut -c 3- | rev`

echo "0.) Generating LHE"
sh runcmsgrid.sh ${nevent} ${RANDOMSEED} 4
namebase=${namebase}_$RANDOMSEED
cp cmsgrid_final.lhe ${LHEDIR}/${namebase}.lhe
echo "${LHEDIR}/${namebase}.lhe"
#rm -rf *
cd ${BASEDIR}

export SCRAM_ARCH=slc7_amd64_gcc820
if ! [ -r CMSSW_10_6_20/src ] ; then
    scram p CMSSW CMSSW_10_6_20
fi
cd CMSSW_10_6_20/src
#rm -rf *
mkdir -p Configuration/GenProduction/python/

cp "${BASEDIR}/config/haa_a${amass}_cff.py" Configuration/GenProduction/python/.
eval `scram runtime -sh`
scram b -j 4
echo "1.) Generating GEN for a mass ${amass}"
genfragment=${namebase}_GEN_cfg_${amass}.py

##Modify cmsDriver command with the latest conditions consistent with 
# cmsDriver.py Configuration/GenProduction/python/haa_a${amass}_cff.py         \
#     --filein file:${LHEDIR}/${namebase}.lhe         --fileout file:${namebase}_${amass}_GENSIM.root         \
#     --mc --eventcontent RAWSIM --datatier GEN-SIM         --conditions 94X_mc2017_realistic_v11 \
#     --beamspot Realistic25ns13TeVEarly2017Collision         --step GEN,SIM \
#     --era Run2_2017 --nThreads 3         \
#     --customise Configuration/DataProcessing/Utils.addMonitoring         \
#     --python_filename ${genfragment} --no_exec -n ${nevent}

cmsDriver.py Configuration/GenProduction/python/haa_a${amass}_cff.py         \
    --fileout file:${namebase}_${amass}_GEN.root \
    --mc --eventcontent RAWSIM --datatier GEN --conditions 106X_mc2017_realistic_v8 \
    --beamspot Realistic25ns13TeVEarly2017Collision --step LHE,GEN \
    --era Run2_2017 --nThreads 3 --geometry DB:Extended \
    --customise Configuration/DataProcessing/Utils.addMonitoring         \
    --python_filename ${genfragment} --no_exec -n ${nevent}



#Make each file unique to make later publication possible
linenumber=`grep -n 'process.source' ${genfragment} | awk '{print $1}'`
linenumber=${linenumber%:*}
total_linenumber=`cat ${genfragment} | wc -l`
bottom_linenumber=$((total_linenumber - $linenumber ))
tail -n $bottom_linenumber ${genfragment} > tail.py
head -n $linenumber ${genfragment} > head.py
echo "    firstRun = cms.untracked.uint32(1)," >> head.py
echo "    firstLuminosityBlock = cms.untracked.uint32($RANDOMSEED)," >> head.py
cat tail.py >> head.py
mv head.py ${genfragment}
rm -rf tail.py

echo "IT HAS BEEN DONE!"
cmsRun -p ${genfragment}

# Step1 is pre-computed, since it takes a while to load all pileup pre-mixed samples
# echo "2.) Generating DIGI-RAW-HLT for a mass ${amass}"

# cmsDriver.py step1 \
# --filein file:${namebase}_${amass}_GENSIM.root --fileout file:${namebase}_${amass}_DIGIRAW.root \
# --pileup_input dbs:/Neutrino_E-10_gun/RunIISummer17PrePremix-MCv2_correctPU_94X_mc2017_realistic_v9-v1/GEN-SIM-DIGI-RAW \
# --mc --eventcontent PREMIXRAW --datatier GEN-SIM-RAW --conditions 94X_mc2017_realistic_v11 \
# --step DIGIPREMIX_S2,DATAMIX,L1,DIGI2RAW,HLT:2e34v40 --nThreads 8 --datamix PreMix \
# --era Run2_2017 --python_filename ${namebase}_${amass}_DIGIRAW_cfg.py --no_exec \
# --customise Configuration/DataProcessing/Utils.addMonitoring --number ${nevent} || exit $?;

# cmsRun -p ${namebase}_${amass}_DIGIRAW_cfg.py

# echo "3.) Generating AOD for a mass ${amass}"
# cmsDriver.py step2 \
# --filein file:${namebase}_${amass}_DIGIRAW.root --fileout file:${namebase}_${amass}_recoAOD.root --mc \
# --eventcontent AODSIM --runUnscheduled --datatier AODSIM --conditions 94X_mc2017_realistic_v11 \
# --step RAW2DIGI,RECO,RECOSIM,EI --nThreads 8 --era Run2_2017 \
# --python_filename ${namebase}_${amass}_recoAOD_cfg.py --no_exec \
# --customise Configuration/DataProcessing/Utils.addMonitoring -n ${nevent} || exit $?;

# cmsRun -p ${namebase}_${amass}_recoAOD_cfg.py

# echo "4.) Generating MINIAOD"
# cmsDriver.py step1 --filein file:${namebase}_${amass}_recoAOD.root --fileout file:${namebase}_${amass}_miniAOD.root \
# --mc --eventcontent MINIAODSIM --runUnscheduled --datatier MINIAODSIM \
# --conditions 94X_mc2017_realistic_v14 --step PAT --nThreads 4 --scenario pp \
# --era Run2_2017,run2_miniAOD_94XFall17 --python_filename ${namebase}_${amass}_miniAOD_cfg.py --no_exec \
# --customise Configuration/DataProcessing/Utils.addMonitoring -n ${nevent} || exit $?;
# cmsRun -p ${namebase}_${amass}_miniAOD_cfg.py

# echo "5.) Generating NANOAOD in new CMSSW"
# cd ../../.

# export SCRAM_ARCH=slc7_amd64_gcc820
# if ! [ -r CMSSW_10_2_22/src ] ; then
#     scram p CMSSW CMSSW_10_2_22
# fi
# mv CMSSW_9_4_9/src/${namebase}_${amass}_miniAOD.root CMSSW_10_2_22/src/.
# cd CMSSW_10_2_22/src
# eval `scram runtime -sh`

# cmsDriver.py   --filein file:${namebase}_${amass}_miniAOD.root --fileout file:${namebase}_${amass}_nanoAOD.root \
# --eventcontent NANOAODSIM \
# --customise Configuration/DataProcessing/Utils.addMonitoring --datatier NANOAODSIM \
# --conditions 102X_mc2017_realistic_v8 --step NANO  --era Run2_2017,run2_nanoAOD_94XMiniAODv2 \
# --no_exec --mc \
# --python_filename ${namebase}_${amass}_nanoAOD_cfg.py -n ${nevent} || exit $?;
# cmsRun -p ${namebase}_${amass}_nanoAOD_cfg.py


pwd
cmd="ls -arlth *.root"
echo $cmd && eval $cmd

echo "DONE."
echo "ALL Done"
