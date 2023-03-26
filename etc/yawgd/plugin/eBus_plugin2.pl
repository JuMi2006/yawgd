###############################################################################
## eBus_plugin2.pl
## v0.1 (2023-03-18), by XueSheng
## 
## Description:
## Read ebus via telnet and write to knx and rrd.
##
## Input:	- telnet (ebus)
##		- Read GA
##
## Output:	- Write GA
##		- RRD
###############################################################################
## 
## Dependencies: none.
##
###############################################################################
## ToDo:
## - ...?
## - Dokumentation/Kommentare ergänzen
##
###############################################################################

# COMPILE_PLUGIN

#$plugin_info{$plugname.'_cycle'} = 0;
#return "deactivated";

use Net::Telnet ();

######################
## begin definition ##
######################

# run cycle
$plugin_info{$plugname.'_cycle'} = 60;

# total time to get all parameters of queue (seconds)
my $time_total_queue = 90;

# debug messages (0: off, 1: basic, 2: debug, 3: all)
our $debug = 2;

# config
my $config = '/etc/yawgd/yawgd-ebusd.csv';

# telnet config
our $ip = 'localhost';
our $port = '8888';

# use default cycle if error_cnt exceeded (ebusd not available)
my $error_cnt = 10;

######################
##  end definition  ##
######################  

# MAIN Code
plugin_log($plugname, "start evaluation, msg{'apci'}: $msg{'apci'}, msg{'dst'}: $msg{'dst'}, msg{'data'}: $msg{'data'}, msg{'repeated'}: $msg{'repeated'}, initflag: $plugin_initflag") if ($debug >= 2);

# define vars
my (%ebus_read, %ebus_write, @queue);

######################
# read config
# check if script was changed or daemon restarted and subscribe GAs
if (($plugin_info{$plugname.'_lastsaved'} > $plugin_info{$plugname.'_last'}) or (!$plugin_initflag)) {
   plugin_log($plugname, "Force Update: config change/restart");
   
   # open config
   open (my $fh, "<", $config) or die "$config $!";
   
   # Read line by line
   while (<$fh>) {
      # skip if line commented
      next if ($_ =~ /^#/);

      # remove newline '\n'
      chomp;

      # fill array
      my @array = split(/;/, $_);
      my ($ga,$dpt,$rrd_type,$rrd_step,$type,$cmd,$comment) = @array;
      
      # ebus_read
      if ($type ne "w" && $ga) {
         # force is added for initial run
         $ebus_read{$ga} = {dpt => $dpt, rrd_type => $rrd_type, rrd_step => $rrd_step, type => $type, cmd => $cmd, comment => $comment, force => 1};
	 plugin_log($plugname, "[config, ebus_read] ga=$ga, dpt=$dpt, rrd_type=$rrd_type, rrd_step=$rrd_step, type=$type, cmd=$cmd, comment=$comment") if ($debug >= 2);
	 push(@queue, $ga);

	 # subscribe to read
	 if ($ga) {
            $plugin_subscribe_read{$ga}{$plugname} = 1;
	    plugin_log($plugname, "[config, ebus_read] subscribed $ga") if ($debug >= 2);
	 }
      }

      # ebus_write
      if ($type eq "w" && $ga) {
        $ebus_write{$ga} = {dpt => $dpt, rrd_type => $rrd_type, rrd_step => $rrd_step, type => $type, cmd => $cmd, comment => $comment};
	 plugin_log($plugname, "[config, ebus_write] ga=$ga, dpt=$dpt, rrd_type=$rrd_type, rrd_step=$rrd_step, type=$type, cmd=$cmd, comment=$comment") if ($debug >= 2);
	
	# subscribe to write
	if ($ga) {
           $plugin_subscribe_write{$ga}{$plugname} = 1;
	   plugin_log($plugname, "[config, ebus_write] subscribed $ga") if ($debug >= 2);
	}
      }
   }

   # close file
   close($fh) or die "$config: $!";
   
   # reset plugin_cache and save arrays
   delete $plugin_cache{$plugname};
   $plugin_cache{$plugname}{ebus_read} = \%ebus_read;
   $plugin_cache{$plugname}{ebus_write} = \%ebus_write;
   $plugin_cache{$plugname}{queue} = \@queue;
   plugin_log($plugname, "[config] saved config to cache") if ($debug >= 1);

} else {
   # load arrays from cache
   %ebus_read = %{$plugin_cache{$plugname}{ebus_read}};
   %ebus_write = %{$plugin_cache{$plugname}{ebus_write}};
   @queue = @{$plugin_cache{$plugname}{queue}};
   plugin_log($plugname, "[config] loaded config from cache") if ($debug >= 1);
}

######################
# dynamic cycle
# early exit if ebusd unavailable

# initialize error counter
$plugin_cache{$plugname}{'telnet_error'} = 0 unless $plugin_cache{$plugname}{'telnet_error'};

# check if port is open (2 sec timeout!)
`/bin/nc -zw10 $ip $port > /dev/null 2>&1`;
if (${^CHILD_ERROR_NATIVE} == 0) {
   # ebusd online
   plugin_log($plugname, "[main] ebusd online") if ($debug >= 2);
   
   # reset error counter
   $plugin_cache{$plugname}{'telnet_error'} = 0;
} else {
   # ebusd offline
   plugin_log($plugname, "[main] ebusd offline") if ($debug >= 2);
   
   # increase error counter
   $plugin_cache{$plugname}{'telnet_error'}++;
}

# dynamic cycle
if ($plugin_cache{$plugname}{'telnet_error'} > $error_cnt) {
   plugin_log($plugname, "[main] no dynamic cycle, ebusd unavailable since $plugin_cache{$plugname}{'telnet_error'} starts") if ($debug >= 1);
} else {
   $plugin_info{$plugname.'_cycle'} = $time_total_queue/(@queue+1);
   plugin_log($plugname, "[main] setting cycle to $plugin_info{$plugname.'_cycle'}") if ($debug >= 1);
}

return "[main] early exit because ebusd unavailable." if ($plugin_cache{$plugname}{'telnet_error'} > 0);

######################
# GroupValue_Read
if ($msg{'dst'} && $ebus_read{$msg{'dst'}} && ($msg{'apci'} eq 'A_GroupValue_Read')) {
   plugin_log($plugname, "[GroupValue_Read] msg{dst}=$msg{'dst'}, cmd=$ebus_read{$msg{'dst'}}{'cmd'}") if ($debug >= 2);

   my $retval = ebusctl('read -n -c '.$ebus_read{$msg{'dst'}}{'cmd'});
   
   if ($retval =~ /error/) {
      plugin_log($plugname, "[GroupValue_Read] got error, retval: $retval");
   } else {
      # knx_write
      plugin_log($plugname, "[GroupValue_Read] knx_write, respond to read ($retval).") if ($debug >= 1);
      knx_write($msg{'dst'}, $retval, $ebus_read{$msg{'dst'}}{'dpt'}, 1);
      $plugin_cache{$plugname}{$msg{'dst'}} = $retval;
   }

######################
# GroupValue_Write
} elsif ($msg{'dst'} && $ebus_write{$msg{'dst'}} && ($msg{'apci'} eq 'A_GroupValue_Write')) {
   plugin_log($plugname, "[GroupValue_Write] msg{dst}=$msg{'dst'}, msg{value}=$msg{'value'}, cmd=$ebus_write{$msg{'dst'}}{'cmd'}") if ($debug >= 2);

   my $retval = ebusctl('write -c '.$ebus_write{$msg{'dst'}}{'cmd'}.' '.$msg{'value'});
   if ($retval =~ /error/) {
      plugin_log($plugname, "[GroupValue_Write] got error, retval: $retval");
   } else {
      plugin_log($plugname, "[GroupValue_Write] message sent to ebus ($msg{'value'}), retval=$retval") if ($debug >= 2);
      
      # check for response
      # get corresponding ebus_read item
      foreach my $key (keys %ebus_read) {
         # skip if no match
         next unless ($ebus_write{$msg{'dst'}}{'cmd'} eq $ebus_read{$key}{'cmd'});
         plugin_log($plugname, "[GroupValue_Write] trying to get ebus response (match found: $key)") if ($debug >=2);
         
         # read ebus 
         my $retval = ebusctl('read -n -c '.$ebus_read{$key}{'cmd'});
         
         if ($retval =~ /error/) {
            plugin_log($plugname, "[GroupValue_Read] got error, retval: $retval");
         } else {
            # knx_write
            if ($plugin_cache{$plugname}{$key} && ($plugin_cache{$plugname}{$key} eq $retval)) {
               plugin_log($plugname, "[GroupValue_Write] no knx_write, retval is unchanged ($retval).") if ($debug >= 2);
            } else {
               plugin_log($plugname, "[GroupValue_Write] knx_write, retval changed ($retval).") if ($debug >= 2);
               knx_write($key, $retval, $ebus_read{$key}{'dpt'});
   	    $plugin_cache{$plugname}{$key} = $retval;
            }
         }
      }
   }
   
######################
# GroupValue_Response
} elsif ($msg{'dst'} && ($msg{'apci'} eq 'A_GroupValue_Response')) {
   plugin_log($plugname, "[GroupValue_Response] msg{dst}=$msg{'dst'}, do nothing.") if ($debug >= 2);

######################
# Cyclic 
} else {
   plugin_log($plugname, "[Cyclic] ga=$queue[0], cmd=$ebus_read{$queue[0]}{'cmd'}, force=$ebus_read{$queue[0]}{'force'}") if ($debug >= 2);
   
   my $retval;
   if ($ebus_read{$queue[0]}{'force'} == 1) {
      # force ebus read if config changed or plugin init
      $retval = ebusctl('read -f -n -c '.$ebus_read{$queue[0]}{'cmd'});
      # initial read done, reset force
      $ebus_read{$queue[0]}{'force'} = 0;
   } else {
      $retval = ebusctl('read -n -c '.$ebus_read{$queue[0]}{'cmd'});
   }
   
   if ($retval =~ /error/) {
      plugin_log($plugname, "[Cyclic] got error, retval: $retval");
   } else {
      # knx_write
      if ($plugin_cache{$plugname}{$queue[0]} && ($plugin_cache{$plugname}{$queue[0]} eq $retval)) {
         plugin_log($plugname, "[Cyclic] no knx_write, retval is unchanged ($retval).") if ($debug >= 2);
      } else {
         plugin_log($plugname, "[Cyclic] knx_write, retval changed ($retval).") if ($debug >= 2);
         knx_write($queue[0], $retval, $ebus_read{$queue[0]}{'dpt'});
	 $plugin_cache{$plugname}{$queue[0]} = $retval;
      }
      
      # update rrd
      if ($ebus_read{$queue[0]}{rrd_type} eq "c"){
         # COUNTER
         my $rrd_name = $ebus_read{$queue[0]}{'cmd'};
         $rrd_name =~ s/ /_/g;
         
         plugin_log($plugname, "[Cyclic] update rrd (COUNTER), rrd_name=$rrd_name ($retval).") if ($debug >= 2);
         update_rrd("eBus_".$rrd_name,"",$retval,"COUNTER",$ebus_read{$queue[0]}{rrd_step})

      } elsif ($ebus_read{$queue[0]}{rrd_type} eq "g"){
         # GAUGE
	 my $rrd_name = $ebus_read{$queue[0]}{'cmd'};
         $rrd_name =~ s/ /_/g;
         
	 plugin_log($plugname, "[Cyclic] update rrd (GAUGE), rrd_name=$rrd_name ($retval).") if ($debug >= 2);
         update_rrd ("eBus_".$rrd_name,"",$retval);

      }
      
      # update queue (put first item to the last position)
      plugin_log($plugname, "[Cyclic] queue (current): @queue") if ($debug >= 3);
      push(@queue, shift(@queue));
      $plugin_cache{$plugname}{queue} = \@queue;
      plugin_log($plugname, "[Cyclic] queue (new): @queue") if ($debug >= 3);
      plugin_log($plugname, "[Cyclic] updated queue and saved to cache") if ($debug >= 1);
   }
      
}

plugin_log($plugname, "The End") if ($debug >= 2);

return;

#################
##  functions  ##
#################

#################
# ebusctl
sub ebusctl {
   my $cmd = shift;
   my $t = new Net::Telnet (Timeout => 4, port => $port, Prompt => '/\n/', Errmode => 'return');
   $t->open($ip) or return ("[ebusctl] Could not connect to localhost:8888 (error: $!)");
   
   plugin_log($plugname, "[ebusctl] sending '$cmd'") if ($debug >= 2);
   my @answer = $t->cmd($cmd) or return ("[ebusctl] Connection timeout (error: $!)");
   plugin_log($plugname, "[ebusctl] received answer '@answer'") if ($debug >= 2);
   $t->close;
   
   return $answer[0];
}
