#Not intended for Pull request
import os,sys


mh=["125","250","500","750","1000"]

hamap ={
    "125":["3.6","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19","20","21"],
    "250":["5","10","15","20"],
    "500":["5","10","15","20","25"],
    "750":["10","15","20","25","30"],
    "1000":["10","20","30","40","50"]
}
    
for m_h in mh:
    for m_a in hamap[m_h]:
        a_string=m_a
        h_string=m_h
        fDir=os.getcwd()
        print fDir
        fname= "haa_h"+h_string+"_a"+a_string+"_cff.py"
        f = open(fDir +"/" +fname,"w")
        f.writelines("""import FWCore.ParameterSet.Config as cms
externalLHEProducer = cms.EDProducer("ExternalLHEProducer",
                                     args = cms.vstring('/afs/cern.ch/user/r/rhabibul/HtoAA-UL-Production_New/HtoAA-UL-AODProducer/condor/gridpacks/Production/ggh01_M"""+h_string+"""_Toa01a01_M"""+a_string+"""_Tomumutautau_slc7_amd64_gcc700_CMSSW_10_6_19_tarball.tar.xz'),
    nEvents = cms.untracked.uint32(100),
    numberOfParameters = cms.uint32(1),
    outputFile = cms.string('cmsgrid_final.lhe'),
    scriptName = cms.FileInPath('GeneratorInterface/LHEInterface/data/run_generic_tarball_cvmfs.sh')
)

import FWCore.ParameterSet.Config as cms

from Configuration.Generator.Pythia8CommonSettings_cfi import *
from Configuration.Generator.Pythia8CUEP8M1Settings_cfi import *
from Configuration.Generator.MCTunes2017.PythiaCP5Settings_cfi import *
from Configuration.Generator.PSweightsPythia.PythiaPSweightsSettings_cfi import *

generator = cms.EDFilter("Pythia8HadronizerFilter",
    maxEventsToPrint = cms.untracked.int32(1),
    pythiaPylistVerbosity = cms.untracked.int32(1),
    filterEfficiency = cms.untracked.double(1.0),
    pythiaHepMCVerbosity = cms.untracked.bool(False),
    comEnergy = cms.double(13000.),
    PythiaParameters = cms.PSet(
        pythia8CommonSettingsBlock,
        pythia8CP5SettingsBlock,
        pythia8PSweightsSettingsBlock,
        parameterSets = cms.vstring('pythia8CommonSettings,
                                    'pythia8CP5Settings',
                                    'pythia8PSweightsSettings',
                                    )
    )
)
""")
        


        
        
        
        
