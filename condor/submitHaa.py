#!/usr/bin/env python

import os, sys
import getpass

'''Usage: ./submit.py <LHE/gridpack filename> year [njobs]
'''

def buildSubmit(infile, workpath, mode, uid, user, year, mass):
    '''A series of actions to prepare submit dir'''

    stageOutPiece = '''
remoteDIR="/eos/user/s/shigginb/HAA_ntuples/ggha01a01Tomumutautau_2017_dtau_%s"
for f in `ls *AOD*.root`; do
    cmd="xrdcp -vf $f root://eosuser.cern.ch/$remoteDIR/$f"
    echo $cmd && eval $cmd
done'''% mass

    os.makedirs(workpath+'/submit/conf')
    os.system('cp conf/* %s/submit/conf/' % workpath)
    try:
        if mode=='lhe':
            os.makedirs(workpath+'/submit/mgLHEs')
            os.system('cp mgLHEs/%s %s/submit/mgLHEs' % (infile, workpath))
            os.system('cp replaceLHELifetime.py %s/submit' % workpath)
            os.system('cp runOffLHE.sh %s/submit' % workpath)
            with open('%s/submit/runOffLHE.sh' % workpath, 'a') as f:
                f.write(stageOutPiece)
        else:
            os.makedirs(workpath+'/submit/gridpacks')
            os.system('cp gridpacks/Production/%s %s/submit/gridpacks' % (infile, workpath))
            #os.system('cp replaceLHELifetime.py %s/submit' % workpath)

            os.system('cp  runGridpack%sHAA_%s_CondorLxplus.sh %s/submit' % (year,mass,workpath))
            with open('%s/submit/runGridpack%sHAA_%s_CondorLxplus.sh' % (workpath,year,mass), 'a') as f:
                f.write(stageOutPiece)
    except:
        print "%s probably not exist." % infile
        cmd = ['ls -lrth '+s for s in ('.', 'mgLHES', 'gridpacks')]
        for c in cmd:
            print cmd
            os.system(cmd)
        raise


    #os.system('cp /tmp/x509up_u%d %s/x509up' % (uid, workpath))
    print "Tarring up submit..."
    os.chdir(workpath)
    os.system('tar -chzf submit.tgz submit')
    os.chdir('..')



def buildExec(infile, workpath, cert, mode, year, mass):
    '''Given the workpath, write a exec.sh in it, to be used by condor'''

    execF = '''#!/bin/bash

export HOME=${PWD}

tar xvaf submit.tgz
cd submit
sh %s.sh %s %s
cd ${HOME}
rm -r submit/

exit 0'''
    with open(workpath + '/exec.sh', 'w') as f:
        # Deduce decay length [mm] from gridpack name..
        # e.g. SIDMmumu_Mps-200_MZp-1p2_ctau-0p1.tar.xz
        # e.g. SIDMmumu_Mps-202_MZp-1p2_ctau-0p01.lhe.gz
        #ctau = '0'
        #if 'iDM' in infile:
        #    nameTags = infile.split('.')[0].split('_')
        #    for t in nameTags:
        #        if 'ctau' in t:
        #            ctau = t.split('-', 1)[-1]
        #            ctau = str( float(ctau.replace('p','.')))# [ANDRE]in mm already *10 )

        if mode == 'lhe':
            f.write(execF % ('runOffLHE', infile+' '+ctau))
        else:
            f.write(execF % (('runGridpack%sHAA_%s_CondorLxplus' % (year,mass)), cert, infile))

#

def buildCondor(process, workpath, logpath, uid, user, njobs=1):
    '''build the condor file, return the abs path'''

    condorF = '''universe = vanilla
executable = {0}/exec.sh
should_transfer_files = YES
when_to_transfer_output = ON_EXIT
transfer_input_files = {0}/submit.tgz
transfer_output_files = ""
input = /dev/null
log = {1}/$(Cluster)_$(Process).log
rank = Mips
request_memory = 8000
arguments = $(Proxy_path) $(Process)
#on_exit_hold = (ExitBySignal == True) || (ExitCode != 0)
#notify_user = {2}@cern.ch
Proxy_path = /afs/cern.ch/user/s/shigginb/private/x509up
+AccountingGroup = "analysis.{2}"
+AcctGroup = "analysis  "
+ProjectName = "HiggsExoticSimulation"
+JobFlavour = "tomorrow"
queue {3}'''.format(workpath, logpath, user, njobs)
    condorFN = 'condor_%s.jdl' % process
#output = {1}/$(Cluster)_$(Process).out
#error = {1}/$(Cluster)_$(Process).err
#stream_error = True #only place these in for debugging purposes!
#stream_output = True

    with open(logpath + '/' + condorFN, 'w') as jdlfile:
        jdlfile.write(condorF)

    return os.path.join(logpath, condorFN)


if __name__ == "__main__":

    inf = sys.argv[1]
    Mode = 'lhe' if 'lhe' in inf else 'gridpack'
    Process = inf.split('/')[-1].split('.')[0]
    print Process

    if len(sys.argv) < 3:
        print "ERROR! Need at least 2 arguments!"
        print "Usage: ./submit.py <LHE/gridpack filename> year [njobs]"
        sys.exit()
    elif sys.argv[2] != '2017' and sys.argv[2] != '2018':
        print "ERROR! Year (2017/18) is a mandatory argument!"
        print "Usage: ./submit.py <LHE/gridpack filename> year [njobs]"
        sys.exit()

    year = sys.argv[2]
    mass = sys.argv[4]

    Njobs = 1 if len(sys.argv) < 4 else sys.argv[3]
    print "submitting ",Njobs,"  jobs"
    print "a mass ",mass

    Logpath = os.getcwd() + '/Logs'
    if not os.path.isdir(Logpath): os.mkdir(Logpath)
    Workpath = os.getcwd() + '/submissions' + '/submit_' + Process
    if os.path.isdir(Workpath): os.system('rm -rf %s' % Workpath)
    os.mkdir(Workpath)
    Uid = os.getuid()
    User = getpass.getuser()
    Cert = '/afs/cern.ch/user/s/shigginb/private/x509up'
    buildSubmit(infile=inf, workpath=Workpath, mode=Mode, uid=Uid, user=User, year=year, mass=mass)
    buildExec(infile=inf, workpath=Workpath,cert=Cert, mode=Mode, year=year, mass=mass)
    theCondor = buildCondor(process=Process, workpath=Workpath,
            logpath=Logpath, uid=Uid, user=User, njobs=Njobs)
    os.system('condor_submit %s' % theCondor)
