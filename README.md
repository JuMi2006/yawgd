#yawgd
Der yawgd ist im Kern der gleiche Daemon der auch auf dem original WireGate läuft. 
Es wurden einige Veränderungen und neue Funktionen hinzugefügt, weiterhin wurden Abhängigkeiten gelöst:
* Counter-RRDs werden besser unterstützt
* erweiterte Syntax für das Aufrufen von Plugins in Abhängigkeit von KNX/EIB-Telegrammen
* vollständig anpassbare: Logfiles+Pfade, Plugin-Pfade etc.
* interne Speicherüberwachung da es ggf. Memleaks gibt (Plattformabhängig)

##Dateistruktur
Im Kern besteht dieser für ein Fremdsystem (non WireGate) aus der folgenden Dateistruktur.

Die Teile die schon Bestandteil des WireGates sind markiere ich im folgenden mit einem "*".


**/etc/init.d/yawgd**

Hier sind i.d.R. Keine Änderungen erforderlich.
Dies ist das init-script für den yawgd. Dieser lässt sich später einfach mit /etc/init.d/yawgd start starten. Ein Neustart oder stop wird durch /etc/init.d/yawgd restart bzw. /etc/init.d/yawgd stop erreicht.

**/etc/yawgd/**

Das Hauptverzeichnis des yawgd. Hier werden die Konfigurationsdateien, die Plugin-Datenbank und im Unterverzeichnis die Plugins abgelegt.

**/etc/yawgd/plugin/**

Dies ist das Verzeichnis in dem die mehr oder weniger bekannten WireGate-Plugins abgelegt werden.

**/etc/logrotate.d/yawgd**

Hier sind i.d.R. Keine Änderungen erforderlich.
Diese Datei enthält die notwendigen infos für einen laufenden logrotate … Der logrotate wird dringend empfohlen. Auf dem WireGate und den meisten Systemen sicherlich schon installiert.

**/usr/sbin/yawgd.pl**

Hier sind i.d.R. Keine Änderungen erforderlich.
Das ist der eigentliche yawgd.

**/usr/lib/perl5***

Hier sind i.d.R. Keine Änderungen erforderlich.
Lediglich die Datei EIBConnection.pm muss vorhanden sein.*

##Konfiguration
Folgende Dateien müssen angepasst werden damit der yawgd grundsätzlich funktioniert:

**/etc/yawgd/yawgd.conf**

Enthält die globale config für den yawgd. 
<pre>
### Global Settings ###
# name of yawgd – recommend not to change
name = yawgd
# path to init-script  – recommend not to change
init_script = /etc/init.d/yawgd
# max. Memory usage of yawgd. If reached yawgd restart through itself by init-script
mem_max = 20

### RRD Settings ###
# directory where rrds will be saved
rrd_dir = /var/www/rrd/
# global cycle of sending values to rrd  – recommend not to change
cycle = 240
# global rrd-heartbeat 300 is equal to rrd-tools default  – recommend not to change
rrd_interval = 300
# some settings for people who know wha they do
rra1_row = 2160
rra5_row = 2016
rra15_row = 2880
rra180_row= 8760

### KNX/EIB Settings ###
# eib enables/disables EIB/KNX 
eib = 1
# URL of eibd, can be in network or local.
eib_url = ip:192.168.2.220:6720
#eib_url = local:/tmp/eib
eib_mininterval = 10
# eib_logging enables/disables EIB/KNX Logging
eib_logging = 1
# eiblogfile is path and name of the EIB/KNX Logfile
eiblogfile = /var/log/yawgd-eib.log

### Plugin ###
#name of the plugin-Database
plugin_db_name = plugin_database.db
#path to plugin-Database
plugin_db_path = /etc/yawgd/
#path of the plugin directory
plugin_path = /etc/yawgd/plugin/
# path and name of the Plugin-Logfile
plugin_logfile = /var/log/yawgd-plugin.log

### Ramdisk/Temp ###
#path to /tmp or ramdisk 
ramdisk = /tmp/
#creates a alive for use with monit
alive = /tmp/yawgd.alive

#udp_port = 13001
#udp_ip = 172.30.40.50
</pre>

**/etc/yawgd/eibga.conf**
Hier müssen die Gruppenadressen eingetragen werden auf die ein Plugin reagieren soll. 
Statt einer weiteren Datei wäre auch ein Symlink für Wiregate-Benutzer mit gleichem Namen denkbar.
Die Gruppenadressen müssen in diesem Format gespeichert werden:

<pre>
[0/5/0]
DPTId = 6
DPTSubId = 6.020
name = WP-Betrieb

[0/5/1]
DPTId = 1
DPTSubId = 1.001
name = Status HZ-WW

</pre>

##yawgd starten
Der yawgd lässt sich noch mit folgenden Optionen starten:
<pre>
perl /usr/sbin/yawgd.pl -d	                #Debug-Modus
perl /usr/sbin/yawgd.pl -c /path/to/yawgd.conf	#separates config file
perl /usr/sbin/yawgd.pl -e /path/to/eibga.conf	#separate eibga.conf
</pre>

##Abhängigkeiten/Installation

Grundsätzlich liegt ein Debian-Package bereit. Dies ist nicht zwangsläufig der letzte Stand der Entwicklung.

Auf einem „Standard-Linux“ sollten sich sämtliche Abhängigkeiten (eibd ausgenommen) mit folgendem auflösen lassen.

<pre>
apt-get install libmath-round-perl libmath-basecalc-perl librrds-perl libproc-pid-file-perl libproc-daemon-perl
</pre>

Lediglich die EIBConnection.pm ist neben den yawgd Dateien im System zu ergänzen, liegt aber im richtigen Ordner im SVN bzw. ist Teil des Packages.*

#Plugins
Die Plugins entsprechen den WireGate-Plugins. Lediglich im Handling mit Sockets gibt es bislang Einschränkungen.

##eBus-Plugin
Diese Plugin verbindet den ebusd mit dem yawgd und stellt so Daten von eBus-Heizgeräten auf dem KNX-Bus zur Verfügung.
Die Beispielkonfiguration bezieht sich auf Vaillant Wärmepumpen.

Das Plugin ist aufgrund der Nutzung von erweiterten Funktionen nicht als WireGate Plugin nutzbar.

Für dieses Plugin ist eine eibga.conf nicht erforderlich.

In Plugin selbst ist der Pfad zu eBus_plugin.conf „hard“ in der sub readconf auf /etc/yawgd/eBus_plugin.conf festgelegt. 
Wer diese woanders liegen haben will muss dort Hand anlegen. 

**/etc/yawgd/eBus_plugin.conf**
<pre>
#### Einstellungen
$config = "/etc/yawgd/yawgd-ebusd.csv";
$ip = 'localhost';		#IP des ebusd
$port = '8888';			#Port des ebusd
$base_time = 180; 	        #Abrufzyklus
$send_change_only = 1;          #Werte nur bei Änderung senden (global)
$debug = "";
#### Ende Einstellungen
</pre>
Eigentlich ist das schon selbsterklärend. ''$ip'' und ''$port'' sind IP-Adresse und Port des ebusd. Mit der Variablen ''$base_time'' wird die festgelegt wie oft jeder abzurufende Wert gesendet wird. Fürs debuggen gibt es noch ''$debug''.

Die eigentliche Konfiguration der eBus-Befehle erfolgt in einer CSV-Datei. Der Pfad dazu wird in ''$config'' angegeben.

**/etc/yawgd/yawgd-ebus.csv**
<pre>
#GA;DPT;RRD_TYPE;RRD_STEP;TYPE;CMD;COMMENT
0/5/120;1;;;set;hw mode;WW/ Betriebsmodus 
0/5/121;9;;;set;hw temp;WW/ Solltemperatur 
0/5/111;1;;;set;short cir2_party;Quick/ Party-Modus 
0/5/110;1;;;set;short cir2_mode;Quick/ Heizkreis Betriebsmodus 
0/5/123;1;;;set;short hw_load;Quick - WW Speicherladung 
0/5/202;9;g;;get;ci cir2_set_temp;Heizkreis2-Solltemperatur 
0/5/203;12;c;24;get;ci yield_transfer;Mitternacht Übertragswert Energieertrag 
0/5/206;12;c;0.5;get;mv yield_sum;Energieertrag 
0/5/204;9;g;;get;mv brine_in temp;Quellentemperatur 
0/5/205;9;g;;get;mv brine_out temp;Austrittstemperatur 
0/5/201;9;g;;get;mv VF2_temp temp;Vorlauftemperatur VF2 
0/5/200;9;g;;get;mv at_temp temp;Aussentempertur 
0/5/102;9;g;;get;cir2 rt_day;Heizkreis – Raumsolltemperatur 
0/5/101;9;g;;set;cir2 rt_day;Heizkreis – Raumsolltemperatur
</pre>

Die CSV kann man sich automatisch aus einer ebusd-csv erstellen lassen. 

Dafür gibt es unter /etc/yawgd/tools das Perl-Script make_ebus_config.pl. 

Der Aufruf erfolgt mit den Parametern -i und -o welche Input und Output angeben.

Beispiel:
perl /etc/yawgd/tools/make_config.pl -i /etc/ebusd/vaillant.csv -o /etc/yawgd/yawgd-ebus.csv

Damit erhalten wir eine csv mit sämtlichen Befehlen die die Datei vaillant.csv enthält. Diese kann nun mit einem Editor um GA,DPT,RRD_type und RRD_step erweitert werden. 
Bei SET Kommandos handelt es sich um GAs die vom Plugin abboniert werden und deren Inhalt dann an den ebusd übergeben werden. DPT sollte der passende Datentyp sein.
RRD_type gibt an ob es sich um ein COUNTER oder GAUGE RRD handelt (c bzw. g). Mit RRD_step kann man bei einem COUNTER-RRD den Zeitraum in Stunden festlegen. I.d.R. Handelt es sich ja um Tagesverbräuch und damit „24“.
Hier mal eine kleine fertige Test-Konfiguration. Nicht benötigte Elemente kann man mit # auskommentieren oder löschen. Sofern kein RRD_type oder eine GA eingetragen wurde werden diese auch ignoriert.

Für das setzen von Werten (SET) kann/sollte eine Rückmeldeadresse beim entsprechenden GET-Befehl eingetragen werden. Diese wird dann automatisch zyklisch mit ausgelesen und nach jedem SET aktualisiert.

Sofern sich das Plugin jetzt im Plugin-Ordner befindet sollte das jetzt alles laufen.

RRDs werden automatisch erstellt und gefüllt.
Die Werte werden auf die entsprechenden Gruppenadressen gesendet.

