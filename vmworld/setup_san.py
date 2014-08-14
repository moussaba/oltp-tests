#!/usr/bin/env python

#RTSLIB Test Script

from math import *
from rtslib import *
from tcm_dump import tcm_full_backup
from subprocess import * 
import lvm
import os
import sys
import time
import argparse
import subprocess
import glob
import yaml
from SSHClient import SSHClient
from TCommand import TCommand


class San:
    """
    The module San configures a linux target based LIO. It takes a yaml file as an argument.  The module 
    creates LVM volumes and instantiates iscsi targets based on the config data. If desired, it will also generate
    initiator target lists, copy them to the initiators, connect the LUNs on the initiators and run a
    fio based performance test.

    For more information on all available commands:

    usage: setup_san.py [-h] [-cg] [-lg] [-R RAMDISK] [-S] [-T] [-C CONFIG] [-ct]
                        [-dt] [-xt] [-dct] [-F]

    Create LVM backed LUNS and iser targets
     optional arguments:
      -h, --help            show this help message and os._exit
      -S, --showtargets     Show configured targets
      -T, --create_targets  Create targets
      -C CONFIG, --config CONFIG
                            Use config file
     Volume Management:
      -cg, --create_vg      Create Volume Groups
      -lg, --list_vg        List volume group and associated logical volumes
     LUNS Management:
      -R RAMDISK, --ramdisk RAMDISK
                            Create RAMDISK targets
     Initiator Management:
      -ct, --copy_targets   Copy Target files to initiators
      -dt, --disconnect_targets
                            Unmount Targets on initiators
      -xt, --connect_targets
                            Mount Targets on initiators
      -dct, --copy_disc_con_targets
                            Mount Targets on initiators
      -F, --run_fio         Run Fio on Initiators
    """

    def __init__(self,fabric_type='iser'):
        """
        Instantiates LIO python API object and creates command line infrastructure.
        @type fabric_type: string
        @param fabric_type: The type of fabric being used (iscsi, FC, etc...)
        """


        self.__create_commands(fabric_type)
        try:
            self.rts = root.RTSRoot()
        except OSError:
            print "LIO not started! run  /sbin/start_lio.sh"
            os._exit(0)





    def __create_commands(self,fabric_type='iser'):
        """
        Defines all commands available via the command line

        @type fabric_type: string
        @param fabric_type: The type of fabric being used (iscsi, FC, etc...)
        """

        self.parser = argparse.ArgumentParser(description="Create LVM backed LUNS and iser targets")
        lvm_group = self.parser.add_argument_group(title="Volume Management")
        lvm_group_mutex = lvm_group.add_mutually_exclusive_group()
        lvm_group_mutex.add_argument("-cg","--create_vg",action='store_true',help="Create Volume Groups")
        lvm_group_mutex.add_argument("-lg","--list_vg",action='store_true',help="List volume group and associated logical volumes")
        luns_group = self.parser.add_argument_group(title="LUNS Management")
        luns_group_mutex = luns_group.add_mutually_exclusive_group()
        luns_group_mutex.add_argument("-R","--ramdisk",type=int,help="Create RAMDISK targets")
        self.parser.add_argument("-S","--showtargets",action="store_true",help="Show configured targets")
        self.parser.add_argument("-T","--create_targets",action="store_true",help="Create targets")
        self.parser.add_argument("-ft","--target_interfaces",action="store_true",help="Configure target interfaces")
        self.parser.add_argument("-C","--config",type=str,help="Use config file")
        initiators_group = self.parser.add_argument_group(title="Initiator Management")
        #initiators_group_mutex = initiators_group.add_mutually_exclusive_group()
        initiators_group.add_argument("-fi","--initiator_interfaces",action='store_true',help="Configure Network Interfaces on initiators")
        initiators_group.add_argument("-ct","--copy_targets",action='store_true',help="Copy Target files to initiators")
        initiators_group.add_argument("-dt","--disconnect_targets",action='store_true',help="Unmount Targets on initiators")
        initiators_group.add_argument("-xt","--connect_targets",action='store_true',help="Mount Targets on initiators")
        initiators_group.add_argument("-dct","--copy_disc_con_targets",action='store_true',help="Mount Targets on initiators")
        initiators_group.add_argument("-F","--run_fio",action='store_true',help="Run Fio on Initiators")
        self.args = self.parser.parse_args()

        if len(sys.argv) <= 1:
            #print usage
            self.parser.print_help()
            os._exit(0)

    def process_commands(self,fabric_type='iser'):
        """
            Processes command line parameters. For more information on available commands:

            python setup_san.py --help

            @type fabric_type: string
            @param fabric_type: The type of fabric being used (iscsi, FC, etc...)
        """


        if self.args.config:
            configfile = self.args.config
        else:
            configfile = "/etc/santa/config.yaml" if os.path.isfile("/etc/santa/config.yaml") else ""
            if not configfile:
               configfile = "./config.yaml" if os.path.isfile("./config.yaml") else ""
            if not configfile:
                print "No configuration provided. Exiting !!!"
                os._exit(0)

        self.__load_yaml(configfile)

        if self.args.showtargets:
            self.print_portals()
            os._exit(0)

        if self.args.list_vg:
            self.list_volume_groups()
            os._exit(0)

        if self.args.target_interfaces:
            self.set_target_interfaces()
            os._exit(0)

        if self.args.initiator_interfaces:
            self.set_initiator_interfaces()
            os._exit(0)

        if self.args.create_vg:
            self.create_volume_groups(fabric_type)
        
        if self.args.create_targets:
            self.clear_rts_config(fabric_type)
            self.create_targets(fabric_type)

        if self.args.copy_targets:
            self.generate_targetlist(True)

        if self.args.connect_targets:
            self.connect_targets()

        if self.args.disconnect_targets:
            self.disconnect_targets()

        if self.args.run_fio:
            self.__run_fio()


    def create_targets(self,fabric_type):
        """
            Creates LIO targets and saves the target configuration.  It assumes the existence of iblock
            datastores. Currently creating targets resests all target assignments so you would lose
	    prior configurations. We will eventually add the ability to save the current state and 
            incrementally add targets.


            @type fabric_type: string
            @param fabric_type: The type of fabric being used (iscsi, FC, etc...)
        """
        if fabric_type =='iser' or fabric_type == 'iscsi':      
            self.create_cfg_iser_targets()
            self.generate_targetlist()
            self.backup_config()
        else:
            print 'Fabric not implemented yet'


    def create_volume_groups(self,fabric_type):
        """
            Creates an LVM volume group, creates logical volumes and instantiates iblock datastores
            based on config.yaml data. Uses physical devices defined in the config file to create the volume group.

            @type fabric_type: string
            @param fabric_type: The type of fabric being used (iscsi, FC, etc...)
        """
        #Improve later such that we only clear the configuration 
        #associated with the provided fabric and volume name
        if self.args.create_vg:
            self.clear_rts_config(fabric_type)
            self.delete_backing_stores()
            if self.args.ramdisk:
                print "Creating Ramdisks"
                for vg in self.config['target']['vgroup']:
                    vgcfg = self.config['target']['vgroup']
                    lvs = vgcfg[vg]['logical_volumes']
                    self.__create_ramdisk_backstores(rdsize=self.args.ramdisk,numvols=int(lvs))
            else:
                print "Creating Volgroups"
                for vg in self.config['target']['vgroup']:
                    vgcfg = self.config['target']['vgroup']
                    self.create_vg(vgcfg[vg]['physical_devices'],vg)
                    self.create_logical_vols(vg,vgcfg[vg]['logical_volumes'])
                    print "Create iblock datastores"
                    self.create_iblock_backstores_lvm(vg)

    def showtargets(self):
        """
            Prints out the list of configured targes on the server.
        """
        self.generate_targetlist()

    # Load YAML config file and store in class object
    def __load_yaml(self,configfile):
        cfile = open(configfile,"r")

        self.config = yaml.load(cfile)
        #for k in config:
        #    print config[k]

    #Dump information about PV
    def print_pv(self,pv):
        """
            Prints detailed information about the LVM physical device

            @type pv: pv object from lvm API
            @param pv: Physical volume object
        """
        print 'PV name: ', pv.getName(), ' ID: ', pv.getUuid(), 'Size: ', pv.getSize()

    def list_volume_groups(self):
        """
            Outputs the list of LVM Volume groups present in the system

        """
        vg_names = lvm.listVgNames()
        for vg_i in vg_names:
            self.print_vg(vg_i)
    
    def print_vg(self,vg_name):
        """
            Prints detailed information about the LVM volume group

            @type vg_name: string
            @param vg_name: Name of the Volume Group
        """
        #Open read only
        vg = lvm.vgOpen(vg_name, 'r')

        print 'Volume group:', vg_name, 'Size: ', vg.getSize()

        #Retrieve a list of Physical volumes for this volume group
        pv_list = vg.listPVs()

        #Print out the physical volumes
        for p in pv_list:
            self.print_pv(p)

        #Get a list of logical volumes in this volume group
        lv_list = vg.listLVs()
        if len(lv_list):
            for l in lv_list:
                print 'LV name: ', l.getName(), ' ID: ', l.getUuid()
        else:
            print 'No logical volumes present!'

        vg.close()

    def remove_vg(self,name):
        """
            Deletes the volume group and all logical volumes associated with the volume

            @type name: string
            @param name: Name of the volume group
        """

        vg = lvm.vgOpen(name,'w')

        pvs = vg.listPVs()

        pe_devices = []

        #Remove all logical volumes
        for l in vg.listLVs():
            l.remove()

        for p in pvs:
            pe_devices.append(p.getName())


        for pv in pe_devices:
            vg.reduce(pv)

        vg.remove()
        vg.close()



    def create_vg(self,pvs,volname):
        """
            Creates a LVM volume group. Takes a list of phyiscal devices as input

            @type pvs: List of strings
            @param pvs: List of physical devices to use for the Volume Group

            @type volname: string
            @param volname: Name of Volume Group
        """

        if not "sanvol" in volname:
            print "Volume Group must be named sanvol...."
            os._exit(0)

	#BUG with removal code, force user to remove from command line before creating a
	#volume group of the same name
        try:
            vg = lvm.vgOpen(volname,'w')
            print "Volume group " + volname + " already exists. Delete it before proceeding. To delete: \n"
	    print "#/etc/init.d/target stop\n#sudo vgremove volname\n#/etc/init.d/target start\n\n Try again"
            vg.close()
	    os._exit(0)
        except:
           	print "%s not found creating " % volname

        physdevices = ""
        for p in pvs:
            physdevices = physdevices + "/dev/%s " % p

        #cmd = "vgcreate %s %s" % (volname,physdevices)
        #process = subprocess.Popen(cmd,shell=True,stdout=subprocess.PIPE)
        #process.wait()
        #time.sleep(10)

        vg = lvm.vgCreate(volname)
        for p in pvs:
            vg.extend("/dev/%s" %p)

        self.print_vg(volname)


    def remove_logical_vols(self,volname):
        """
            Deletes all logical volumes in a volume group

            @type volname: string
            @param volname: Volume Group Name
        """
        try:
            vg = lvm.vgOpen(volname,'w')
        except:
            print("Failed to open LVM volume")
            return

        lv_list = vg.listLVs()
        if len(lv_list) > 0:
            #print "Removing all lvs"
            for lv_i in lv_list:
                lv_i.deactivate()
                lv_i.remove()
        else:
            print "No logical volumes found"
        
        vg.close()

    def create_logical_vols(self,volname,count):
        """
            Creates logical volumes using a volume group as a container. Logical volumes are all equally
            sized based on the count requested. This can be improved in the future by providing an array of
            sizes for all desired volumes.

            @type volname: string
            @param volname: Volume Group Name

            @type count: integer
            @param count: Number of Logical Volumes to create
        """

        #print 'Creating ',count,' backing stores'

        vg = lvm.vgOpen(volname,'w')
        vg_size = vg.getSize() 

        if vg_size/count < 10:
            print "Too many luns, minimum LUN size is 10GB"
            return 0
        else:
            lunsize = vg_size/count - 10*1024*1024
            for i in range(0, count):
                lv = vg.createLvLinear('LUN_%s%d' %(volname,i),lunsize)
                #if lv:
                #   print 'New lv, id=',lv.getUuid(),' name=',lv.getName()
                
        vg.close()

    def delete_targets(self,fabric_type):
        """
            Delete configured targets from LIO.

            @type fabric_type: string
            @param fabric_type: The type of fabric being used (iscsi, FC, etc...)
        """
        fabric = FabricModule(fabric_type)
        #print 'Deleting',fabric_type,'Targets'
        for t in fabric.targets:
            try:
                t.delete()
            except RTSLibNotInCFS:
                return
                #print 'Target',t.wwn,' already deleted'

    def print_targets(self,fabric_type):
        """
            Prints target WWN configured in LIO

            @type fabric_type: string
            @param fabric_type: The type of fabric being used (iscsi, FC, etc...)
        """
        fabric = FabricModule(fabric_type)
        for t in fabric.targets:
            print t.wwn
        

    def print_portals(self,ip="none",outfile="none"):
        """
            Prints detailed target data including WWN, IP, PORT

            @type ip: string
            @param ip: If this parameter is specified it will print all targes on the same subnet
        """
        fabric = FabricModule('iscsi')
        #for np in rts.network_portals:
        #   print np.ip_address,':',np.port
        portals=[]
        for t in fabric.targets:
            for tpg in t.tpgs:
                for np in tpg.network_portals:
                    if ip != "none":
                        if self.__get_subnet(np.ip_address) != self.__get_subnet(ip):
                            continue
                    portals.append("%s,%s,%s" % (np.ip_address,np.port,t.wwn))

        portals.sort()
        for p in portals:
            print p
        return portals


    def generate_targetlist(self,copy=False):
        """
            Generates initiator specific target files and copies them to the iniitiator if requested.  This
            assumes that the initiator has been configured to accept 

            @type copy: bool
            @param copy: If this parameter is set to true it will copy the generated target list file to the initiator
        """

        assigned_targets = []
        for initiator in self.config['initiators']:
            target_filename = "./targets_%s.txt" % initiator
            f = open("./targets_%s.txt" % initiator,'w')
            for iface in self.config['initiators'][initiator]['interfaces']:
                portals = self.print_portals(iface)
                luns_config = self.config['initiators'][initiator]['luns']
                luns = 0
                for p in portals:
                    if p not in assigned_targets and luns < int(luns_config):
                        f.write(p+"\n")
                        assigned_targets.append(p)
                        luns += 1
            f.close()
            if copy:
                ssh = SSHClient(initiator,"jenkins")
                ssh.copy(target_filename,"~/santa/targets.txt")



    def connect_targets(self):
        """
            Runs the target connection script on the iniatiator to map the drives.
        """

        for initiator in self.config['initiators']:
            ssh = SSHClient(initiator,"jenkins")
            ssh.execute("cd ~/santa/; sudo python initiator.py -T ")
            ssh.execute("cd ~/santa/; sudo bash ./connect.sh")
            ssh.execute("cat /proc/partitions")

    def disconnect_targets(self):
        """
            Disconnect all mapped targets on the initiator
        """
        for initiator in self.config['initiators']:
            ssh = SSHClient(initiator,"jenkins")
            ssh.execute("sudo iscsiadm -m session --logout ")
            ssh.execute("sudo rm -rf /var/lib/iscsi/ifaces/*")
            ssh.execute("sudo rm -rf /var/lib/iscsi/nodes/*")
            ssh.execute("sudo rm -rf /var/lib/iscsi/send_targets/*")

    def __run_fio(self):
        threads = []
        tid = 1
        cmd = "cd ~/santa/;sudo python initiator.py -F;sudo bash ./run_ioscripts.sh | tee run.out"
        for initiator in self.config['initiators']:
            t = TCommand(tid,initiator,cmd)
            tid += 1
            t.start()
            threads.append(t)
        for t in threads:
            t.join()
        print "Run Complete"


    def write_iface_script(self,interfaces,host="localhost"):

        for iface in interfaces:
	    print iface
            outfile = "/tmp/ifcfg-%s" % iface['adapter']

            f = open(outfile,'w')

            f.write('DEVICE="%s"\n' % iface['adapter'])
            f.write('HWADDR=%s\n' % iface['mac'])
            f.write('ONBOOT=yes\n')
            f.write('NM_CONTROLLED=no\n')
            f.write('TYPE=Ethernet\n')
            f.write('BOOTPROTO=static\n')
            f.write('NAME="System %s"\n' % iface['adapter'])
            f.write('IPADDR=%s\n' % iface['ip'])
            f.write('NETMASK=255.255.255.0\n')
            f.close()
        
            if host != "localhost":
                ssh = SSHClient(host,"jenkins")
                ssh.copy("~/tmp/ifcfg-%s.txt" % iface['adapter'],"/etc/sysconfig/network-scripts")
            else:
               cmd = "sudo mv /tmp/ifcfg-%s /etc/sysconfig/network-scripts"  % iface['adapter']
               process = subprocess.Popen(cmd,shell=True,stdout=subprocess.PIPE)
               process.wait()

    def start_iface(self,host,adapter="eth2"):

        cmd  = "sudo ifdown %s;sudo ifup %s" % (adapter,adapter)
        if host != "localhost":
            ssh = SSHClient(host,"jenkins")
            ssh.execute(cmd)
        else:
            process = subprocess.Popen(cmd,shell=True,stdout=subprocess.PIPE)
            process.wait()



    def set_initiator_interfaces(self):
	print self.config['initiators']
        for initiator in self.config['initiators']:
	    print initiator
	    print self.config['initiators'][initiator]
            self.write_iface_script(self.config['initiators'][initiator]['interfaces'],initiator)
            for iface in self.config['initiators'][initiator]['interfaces']:
                self.start_iface(initiator,iface['adapter'])

    def set_target_interfaces(self):
            self.write_iface_script(self.config['target']['targets']['interfaces'],"localhost")
            interfaces = self.config['target']['targets']['interfaces']
            for iface in interfaces:
                self.start_iface("localhost",iface['adapter'])


    def __get_subnet(self,ip):
        return ip.split(".")[2]

    #Delete  all backing stores
    def delete_backing_stores(self):
        for bs in self.rts.backstores:
            bs.delete()



    def clear_rts_config(self,fabric_type='iser'):
        """
            Clears all targets associated with a particular fabric.

            @type fabric_type: string
            @param fabric_type: The type of fabric being used (iscsi, FC, etc...)
        """
        print "Clearing RTS Config"
        self.delete_targets(fabric_type)
        #print_targets(rts)
        #self.__remove_logical_vols(volname)


    def create_iblock_backstores_lvm(self,volname):
        """
            Creates iblock datastores for LIO target

            @type volname: string
            @param volname: Volume Group Name
        """
        vg = lvm.vgOpen(volname)
        lv_list = vg.listLVs()

        #bs_idx should not be repeated
        try:
            bs_idx = len(self.rts.backstores) 
        except:
            bs_idx=0


        if len(lv_list) > 0:
            print "Creating %d iblockstores" % len(lv_list)
            for lv_i in lv_list:
                #print 'Creating back store for %s' % lv_i.getName()
                bs = IBlockBackstore(bs_idx,mode="create")
                bs_idx += 1
                try:
                    path = '/dev/'+ volname + '/' +lv_i.getName()
                    so = IBlockStorageObject(bs,lv_i.getName(),path,gen_wwn=True)
                except:
                    bs.delete()
                    raise
        
    def __create_iblock_backstores_partitions(self,numluns):

        if len(partitions) >= numluns:
            bs_idx = 0
            for p in partitions:
                bs = IBlockBackstore(bs_idx,mode="create")
                try:
                    so = IBlockStorageObject(bs,"LUN_%d" % bs_idx,p,gen_wwn=True)
                except:
                    bs.delete()
                    raise
                bs_idx += 1
                if bs_idx == numluns:
                    break
        else:
            print("Failed to create iblock datastores, check number of partitions.")    
            os._exit(0)

    def __create_ramdisk_backstores(self,rdsize,numvols):
        bs_idx = 0

        if numvols > 0:
            #print "Creating %d rdmcpstores" % numvols
            for i in range(0,numvols):
                #print 'Creating back store for %s' % lv_i.getName()
                bs = RDMCPBackstore(bs_idx,mode="create")
                bs_idx += 1
                try:
                    so = RDMCPStorageObject(bs,"ramdisk_%d" % i,gen_wwn=True,size=rdsize*1024*1024*1024)
                except:
                    print "Error creating RAMDISK Drive % d" % i
                    bs.delete()
                    raise
        

    def __create_iser_targets(self,numtargets,numluns,port=3260):
        #fabric = FabricModule('iser')
        fabric = FabricModule('iscsi')
        ip_idx = 0
        bsi = iter(self.rts.backstores)
        luns_per_target = numluns / numtargets
        
        print "Creating iser targets"

        for t_i in range(0,numtargets):
            target = Target(fabric)
            tpg = TPG(target,1)
            tpg.enable = 1
            tpg.set_attribute("authentication","0")
            tpg.set_attribute("demo_mode_write_protect","0")
            tpg.set_attribute("generate_node_acls","1")
            tpg.set_attribute("cache_dynamic_acls","1")
            tpg.set_attribute("default_cmdsn_depth","64")
            #Cycle through all interfaces
            interfaces = self.config['target']['interfaces']
            ip_idx = ip_idx % len(interfaces)
            portal = NetworkPortal(tpg,interfaces[ip_idx],port)
            try:
                portal._set_iser_attr(1)
            except RTSLibError:
                print 'iser not supported'
            except IOError:
                print "IP address not found!"
                os._exit(0)
            for lpt in range(0,luns_per_target):
                bsitem = bsi.next().storage_objects[0]
                lun = tpg.lun(lpt,bsitem,"my_lun_%d" % lpt)
            #node_acl = tpg.node_acl(target.wwn)
            #mapped_lun = node_acl.mapped_lun(0,0, False)
            ip_idx += 1
            port += 1



    def create_cfg_iser_targets(self,port=3260):
        """
            Creates iser targets assuming the existence of a config.yaml file and preconfigured
            LVM volumes and iblock datastores

            @type port: integer
            @param port: Staring port number for iser target
        """
        #fabric = FabricModule('iser')
        fabric = FabricModule('iscsi')
        bsi = iter(self.rts.backstores)
        
        targets = []        
        print "Creating iser targets stores"


        # Sort targets per IP address for port assignment
        for t in self.config['target']['targets']:
            targets.append(t)
        targets.sort()    

        #for t in self.config['target']['targets']:
        for t in targets:
            numluns = int(self.config['target']['targets'][t]['luns'])
            for l in range(0,numluns):
                target = Target(fabric)
                tpg = TPG(target,1)
                tpg.enable = 1
                tpg.set_attribute("authentication","0")
                tpg.set_attribute("demo_mode_write_protect","0")
                tpg.set_attribute("generate_node_acls","1")
                tpg.set_attribute("cache_dynamic_acls","1")
                tpg.set_attribute("default_cmdsn_depth","64")
                #Cycle through all interfaces
                portal = NetworkPortal(tpg,t,port)
                try:
                    portal._set_iser_attr(1)
                except RTSLibError:
                    print 'iser not supported'
                except IOError:
                    print "IP address not found!"
                    target.delete()
                    os._exit(0)
                bsitem = bsi.next().storage_objects[0]
                if bsitem is None:
                    print "No more luns to assign!"
                    break
                lun = tpg.lun(l,bsitem,"my_lun_%d" % l)
                port +=     1

    def backup_config(self):
        """
            Saves the LIO configuration to file.
        """
        tcm_full_backup(None,None,'1',None)


san = San(fabric_type='iscsi')
san.process_commands(fabric_type='iscsi')

