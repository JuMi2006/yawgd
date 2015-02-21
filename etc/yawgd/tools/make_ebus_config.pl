#!/usr/bin/perl
#perl /root/make_ebus_config.pl -i /root/ebus2/ebusd/vaillant.csv -o /tmp/test2.csv
# makes config from ebusd cvs-files
# M.Hirsch
# 2013

use warnings;
use strict;
use Getopt::Std;

getopts('o:i:h:', \my %opts) or die "Please specify paths for config files!\n -i select ebusd-configfile (input) \n -o select plugin output-file (output) \n\nThe input file can be created by calling ebusd with the --dumpconfig argument, e.g.\n'ebusd --dumpconfig --logareas='\n";
if ($opts{h}) {print "Please specify paths for config files!\n -i select ebusd-configfile (input) \n -o select plugin output-file (output) \n\nThe input file can be created by calling ebusd with the --dumpconfig argument, e.g.\n'ebusd --dumpconfig --logareas='\n"; exit;}
if (!$opts{i} or !$opts{o}) {die "Please specify paths for config files!\n -i select ebusd-configfile (input) \n -o select plugin output-file (output) \n";}
my $config = $opts{i};
print "Input: $config\n";
my $final_cfg = $opts{o};
print "Output $final_cfg\n";

### READ CONFIG
my @cmds;
open (GETCFG,"<$config") || die $!;
while (<GETCFG>){
  if ($_ =~ /\#/) {
    #if ($debug){plugin_log($plugname,"skipped line");}
  } else {
    #if ($debug){plugin_log($plugname,"line $_");}
    my @array = split (/,/,$_);
    my $type = $array[0];
    my $class = $array[1];
    my $name = $array[2];
    my $comment = $array[3];
    my $elements = (@array - 8) / 6;
    my $prefix = $class." ".$name;
    my $cmd;
    my $comm;
    my $pos = 8;
    my $cnt = 0;
    for (my $i=0; $i < $elements; $i++, $pos+=6) {
      if (substr($array[$pos+2], 0, 3) ne "IGN") {
        $cnt++;
      }
    }
    $pos = 8;
    for (my $i=0; $i < $elements; $i++, $pos+=6) {
      if (substr($array[$pos+2], 0, 3) ne "IGN") {
        if ($cnt>1 && $array[$pos]) {
          $cmd = $prefix." ".$array[$pos];
        } else {
          $cmd = $prefix;
        }
        if ($array[$pos+5]) {
          $comm = $comment." ".$array[$pos+5];
        } else {
          $comm = $comment;
        }
        chomp $comm;
        #print $type." ".$cmd." ".$comment."\n";
        push @cmds,{type => $type, cmd => $cmd, comment => $comm};
      }
    }
  }
}
close GETCFG;

open (WRITECFG,'>',$final_cfg) || die "Can not open file $final_cfg: $!";;
print
"\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#
\#\#\# I N F O \#\#\#
\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\n";
print "All commands are disabled through \"\#\" by default\n";

print "\#GA;DPT;RRD_TYPE;RRD_STEP;TYPE;CMD;COMMENT\n";
print WRITECFG "\#GA;DPT;RRD_TYPE;RRD_STEP;TYPE;CMD;COMMENT\n";
foreach my $cmd (@cmds){
  print WRITECFG "\#;;;;$cmd->{type};$cmd->{cmd};$cmd->{comment} \n";
  print "\#;;;;$cmd->{type};$cmd->{cmd};$cmd->{comment} \n";
}
close WRITECFG;
