# -*- coding: utf8 -*-

import time
import sys
import os
import subprocess
import platform
import multiprocessing
import threading
import thread
import shutil


#===============================================================================
import os

plik_csv = open('files_for_sim.lst', 'w')


PATH = sys.argv[0]
PATH = os.path.dirname(PATH)
PATH = os.path.abspath(PATH)
print "Sciezka: " + PATH
pliki = os.listdir(PATH)
pierwszyPlik = 1
for nazwa_pliku in pliki:
    if nazwa_pliku.find('.v') != -1:
        plik_csv.write(nazwa_pliku+"\n");
plik_csv.close()
                
            
            
            










