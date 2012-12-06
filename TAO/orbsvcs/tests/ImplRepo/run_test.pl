eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}'

    & eval 'exec perl -S $0 $argv:q'
    if 0;

# $Id$
# -*- perl -*-

###############################################################################

use lib "$ENV{ACE_ROOT}/bin";
use PerlACE::TestTarget;
use File::Copy;

$debug_level = '0';
$srv_debug_level = '0';
my $test_debug_level = '2';
my $num_srvr = 1;
my $replica = 0;
my $all_tests = 0;

foreach $i (@ARGV) {
    if ($i eq '-debug') {
        $debug_level = '10';
        $srv_debug_level = '10';
    }
    elsif ($i eq '-tdebug') {
        $test_debug_level = 10;
    }
    elsif ($i eq '-tsilent') {
        $test_debug_level = 0;
    }
    elsif ($i eq '-servers') {
      $num_srvr = 3;
    }
    elsif ($i eq '-replica') {
      $num_srvr = 2;
      $replica = 1;
    }
    elsif ($i eq '-all') {
      $all_tests = 1;
    }
}

my $tgt_num = 0;
my $imr = PerlACE::TestTarget::create_target (++$tgt_num) || die "Create target $tgt_num failed\n";
my $act = PerlACE::TestTarget::create_target (++$tgt_num) || die "Create target $tgt_num failed\n";
my $ti = PerlACE::TestTarget::create_target (++$tgt_num) || die "Create target $tgt_num failed\n";
my $n_srv = PerlACE::TestTarget::create_target (++$tgt_num) || die "Create target $tgt_num failed\n";
my $n_cli = PerlACE::TestTarget::create_target (++$tgt_num) || die "Create target $tgt_num failed\n";
my $bin_imr = PerlACE::TestTarget::create_target (++$tgt_num) || die "Create target $tgt_num failed\n";
my $bin_act = PerlACE::TestTarget::create_target (++$tgt_num) || die "Create target $tgt_num failed\n";
my @a_cli;
my @a_srv;
my @p_srv;
my $index;
for ($index = 0; $index < $num_srvr; ++$index) {
  push(@a_cli, PerlACE::TestTarget::create_target (++$tgt_num)) || die "Create a_cli target $tgt_num failed\n";
  push(@a_srv, PerlACE::TestTarget::create_target (++$tgt_num)) || die "Create a_srv target $tgt_num failed\n";
  push(@p_srv, PerlACE::TestTarget::create_target (++$tgt_num)) || die "Create p_srv target $tgt_num failed\n";
}

my $replica_imr;
my $replica_act;
my $replica_ti;
if ($replica) {
    $replica_imr = PerlACE::TestTarget::create_target (++$tgt_num) || die "Create replica_imr target $tgt_num failed\n";
    $replica_act = PerlACE::TestTarget::create_target (++$tgt_num) || die "Create replica_act target $tgt_num failed\n";
    $replica_ti = PerlACE::TestTarget::create_target (++$tgt_num) || die "Create replica_ti target $tgt_num failed\n";
    $replica_imr->AddLibPath ("$ENV{ACE_ROOT}/lib");
}

$imr->AddLibPath ("$ENV{ACE_ROOT}/lib");

my $imriorfile = "imr_locator.ior";
my $actiorfile = "imr_activator.ior";
my $primaryiorfile = "ImR_ReplicaPrimary.ior";
my $backupiorfile = "ImR_ReplicaBackup.ior";
my $replica_imriorfile = "replica_imr_locator.ior";
my $replica_actiorfile = "replica_imr_activator.ior";
my $nesteaiorfile = "nestea.ior";
my $nestea_dat = "nestea.dat";

my $n_cli_nesteaiorfile = $n_cli->LocalFile ($nesteaiorfile);

my $refstyle = " -ORBObjRefStyle URL";
my $protocol = "iiop";
my $imr_host = $imr->HostName ();
my $port = 12345;
my $endpoint = "-ORBEndpoint " . "$protocol" . "://:" . $port;

$IMR = $imr->CreateProcess ("../../ImplRepo_Service/tao_imr_locator");
$ACT = $act->CreateProcess ("../../ImplRepo_Service/tao_imr_activator");
$TI = $ti->CreateProcess ("$ENV{ACE_ROOT}/bin/tao_imr");

# We want the tao_imr executable to be found exactly in the path
# given, without being modified by the value of -ExeSubDir.
# So, we tell its Process object to ignore the setting of -ExeSubDir.

$TI->IgnoreExeSubDir (1);

if ($replica) {
    $replica_IMR = $replica_imr->CreateProcess ("../../ImplRepo_Service/tao_imr_locator");
    $replica_ACT = $replica_act->CreateProcess ("../../ImplRepo_Service/tao_imr_activator");
    $replica_TI = $replica_ti->CreateProcess ("$ENV{ACE_ROOT}/bin/tao_imr");
    $replica_TI->IgnoreExeSubDir (1);
}

my @airplaneiorfile;
my @a_cli_airplaneiorfile;
for ($index = 0; $index < $num_srvr; ++$index) {
  push(@airplaneiorfile, "airplane$index.ior");
  push(@a_cli_airplaneiorfile, $a_cli[$index]->LocalFile ($airplaneiorfile[$index]));
}

sub create_acli {
    my $select = shift;
    return $a_cli[$select]->CreateProcess ("airplane_client", " -k file://$a_cli_airplaneiorfile[$select] ");
}

sub create_ncli {
    return $n_cli->CreateProcess ("nestea_client", " -k file://$n_cli_nesteaiorfile ");
}

my @A_SRV;
my @a_srv_name;
my @A_SRV_cmd;
my @imr_A_SRV_cmd;
my @P_SRV;
my @P_SRV_cmd;
my @imr_P_SRV_cmd;
for ($index = 0; $index < $num_srvr; ++$index) {
  push(@a_srv_name, "airplane_server$index");
  push(@A_SRV, $a_srv[$index]->CreateProcess ("airplane_server"));
  my $p_srv_name = "persist server$index";
  push(@P_SRV, $p_srv[$index]->CreateProcess ($p_srv_name));

  push(@A_SRV_cmd, $A_SRV[$index]->Executable());
  push(@imr_A_SRV_cmd, $imr->LocalFile ($A_SRV_cmd[$index]));
  push(@P_SRV_cmd, $P_SRV[$index]->Executable());
  push(@imr_P_SRV_cmd, $imr->LocalFile ($P_SRV_cmd[$index]));
}

my @A_CLI;
for ($index = 0; $index < $num_srvr; ++$index) {
  push(@A_CLI, create_acli($index));
}
my $N_SRV = $a_cli[0]->CreateProcess ("nestea_server");
my $N_CLI = create_ncli();

my $N_SRV_cmd = $N_SRV->Executable();
my $imr_N_SRV_cmd = $imr->LocalFile ($N_SRV_cmd);

sub setup_repo {
    my $repo_ref = shift;
    my $the_imr = shift;
    my $the_IMR = shift;
    my $the_imriorfile = shift;
    my $the_act = shift;
    my $the_ACT = shift;
    my $the_actiorfile = shift;
    my $the_ti = shift;
    my $the_TI = shift;
    my $port = shift;
    my $backingstore_flag = shift;
    my $the_replicaiorfile = shift;
    my $explicit_act = shift;

    my $the_imr_imriorfile = $the_imr->LocalFile ($the_imriorfile);
    my $the_act_imriorfile = $the_act->LocalFile ($the_imriorfile);
    my $the_ti_imriorfile = $the_ti->LocalFile ($the_imriorfile);
    my $the_act_actiorfile = $the_act->LocalFile ($the_actiorfile);
    my $the_imr_replicaiorfile = $the_imr->LocalFile ($the_replicaiorfile);

    $repo_ref->{imr} = $the_imr;
    $repo_ref->{IMR} = $the_IMR;
    $repo_ref->{imriorfile} = $the_imriorfile;
    $repo_ref->{imr_imriorfile} = $the_imr_imriorfile;
    $repo_ref->{imr_endpoint_flag} = "-ORBEndpoint iiop://:$port ";
    if ($replica) {
        $repo_ref->{imr_backing_store_flag} =
          $backingstore_flag . " " . $the_imr->LocalFile (".") . " ";
    }
    $repo_ref->{replicaiorfile} = $the_replicaiorfile;
    $repo_ref->{imr_replicaiorfile} = $the_imr_replicaiorfile;

    $repo_ref->{act} = $the_act;
    $repo_ref->{ACT} = $the_ACT;
    $repo_ref->{actiorfile} = $the_actiorfile;
    $repo_ref->{act_imriorfile} = $the_act_imriorfile;
    $repo_ref->{act_actiorfile} = $the_act_actiorfile;
    if (defined($explicit_act)) {
        $repo_ref->{server_act_flag} = "-l $explicit_act ";
        $repo_ref->{act_explicit_flag} = "-n $explicit_act ";
    }

    $repo_ref->{ti} = $the_ti;
    $repo_ref->{TI} = $the_TI;
    $repo_ref->{ti_imriorfile} = $the_ti_imriorfile;
}

# Helper subroutines

sub cleanup_replication {
    my $dir = shift;
    if (!defined($dir)) {
        $dir = ".";
    }

    my $listings = "$dir/imr_listing.xml";
    if (open FILE, "<$listings") {
        while (<FILE>) {
            if ($_ =~ /fname="([^"]+)"?/) {
                my $file = "$dir/$1";
                test_info("deleting $file\n");
                $imr->DeleteFile ($file);
            }
        }
        close FILE;
    }
    test_info("deleting $listings\n");
    $imr->DeleteFile ("$listings");
    $imr->DeleteFile ("$dir/$primaryiorfile");
    $imr->DeleteFile ("$dir/$backupiorfile");
}

sub test_info {
    if ($test_debug_level < 10) {
        return;
    }

    my $info = shift;
    print "$info";
}

sub kill_imr {
    $IMR->Kill (); $IMR->TimedWait (1);
    if ($replica) {
      $replica_IMR->Kill (); $replica_IMR->TimedWait (1);
    }
}

sub kill_act {
    $ACT->Kill (); $ACT->TimedWait (1);
    if ($replica) {
      $replica_ACT->Kill (); $replica_ACT->TimedWait (1);
    }
}

###############################################################################

sub wait_for_imr {
    my $repo_ref = shift;
    my $filekey = shift;

    if (!defined($filekey)) {
        $filekey = "imriorfile";
    }
    my $imr_only = ($filekey eq "imriorfile");

    if ($repo_ref->{imr}->WaitForFileTimed (
                $repo_ref->{$filekey},
                $repo_ref->{imr}->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <" .
          $repo_ref->{"imr_$filekey"} . ">\n";
        kill_imr();
        return 1;
    }
    if ($repo_ref->{imr}->GetFile ($repo_ref->{$filekey}) == -1) {
        print STDERR "ERROR: cannot retrieve file <" .
          $repo_ref->{"imr_$filekey"} . ">\n";
        kill_imr();
        return 1;
    }
    if (!$imr_only) {
        if ($repo_ref->{act}->PutFile ($repo_ref->{$filekey}) == -1) {
            print STDERR "ERROR: cannot set file <" .
              $repo_ref->{"act_$filekey"} . ">\n";
            kill_imr();
            return 1;
        }
        if ($repo_ref->{ti}->PutFile ($repo_ref->{$filekey}) == -1) {
            print STDERR "ERROR: cannot set file <" .
              $repo_ref->{"act_$filekey"} . ">\n";
            kill_imr();
            return 1;
        }
    }
    return 0;
}

# The Tests

###############################################################################

sub kill_then_timed_wait
{
  my $srvrs = shift;
  my $time = shift;
  my $length = scalar(@{$srvrs});
  for ($index = 0; $index < $length; ++$index) {
    $srvrs->[$index]->Kill (); $srvrs->[$index]->TimedWait (1);
  }
}

sub airplane_test
{
    my $status = 0;

    my @a_srv_airplaneiorfile;
    for ($index = 0; $index < $num_srvr; ++$index) {
        push(@a_srv_airplaneiorfile, $a_srv[$index]->LocalFile ($airplaneiorfile[$index]));
        $a_srv[$index]->DeleteFile ($airplaneiorfile[$index]);
        $a_cli[$index]->DeleteFile ($airplaneiorfile[$index]);

        $A_SRV[$index]->Arguments (
          "-o $a_srv_airplaneiorfile[$index] $refstyle -ORBDebugLevel " .
          "$srv_debug_level -s $a_srv_name[$index]");
        $A_SRV_status = $A_SRV[$index]->Spawn ();
        if ($A_SRV_status != 0) {
            print STDERR "ERROR: Airplane Server returned $A_SRV_status\n";
            return 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        if ($a_srv[$index]->WaitForFileTimed ($airplaneiorfile[$index],$a_srv[$index]->ProcessStartWaitInterval()) == -1) {
            print STDERR "ERROR: cannot find file <$a_srv_airplaneiorfile[$index]>\n";
            kill_then_timed_wait(\@A_SRV, 1);
            return 1;
        }
        if ($a_srv[$index]->GetFile ($airplaneiorfile[$index]) == -1) {
            print STDERR "ERROR: cannot retrieve file <$a_srv_airplaneiorfile[$index]>\n";
            kill_then_timed_wait(\@A_SRV, 1);
            return 1;
        }
        if ($a_cli[$index]->PutFile ($airplaneiorfile[$index]) == -1) {
            print STDERR "ERROR: cannot set file <$a_cli_airplaneiorfile[$index]>\n";
            kill_then_timed_wait(\@A_SRV, 1);
            return 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        $A_CLI_status = $A_CLI[$index]->SpawnWaitKill ($a_cli[$index]->ProcessStartWaitInterval());
        if ($A_CLI_status != 0) {
            print STDERR "ERROR: Airplane Client returned $A_CLI_status\n";
            $status = 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        $A_SRV_status = $A_SRV[$index]->TerminateWaitKill ($a_srv[$index]->ProcessStopWaitInterval());
        if ($A_SRV_status != 0) {
            print STDERR "ERROR: Airplane Server returned $A_SRV_status\n";
            $status = 1;
        }

        $a_srv[$index]->DeleteFile ($airplaneiorfile[$index]);
        $a_cli[$index]->DeleteFile ($airplaneiorfile[$index]);
    }
    return $status;
}

###############################################################################

sub nestea_test
{
    my $status = 0;

    my $n_srv_nesteaiorfile = $n_srv->LocalFile ($nesteaiorfile);
    $n_srv->DeleteFile ($nesteaiorfile);
    $n_cli->DeleteFile ($nesteaiorfile);

    $N_SRV->Arguments ("-o $n_srv_nesteaiorfile $refstyle -ORBDebugLevel " .
                       "$srv_debug_level");
    $N_SRV_status = $N_SRV->Spawn ();
    if ($N_SRV_status != 0) {
        print STDERR "ERROR: Nestea Server returned $N_SRV_status\n";
        return 1;
    }
    if ($n_srv->WaitForFileTimed ($nesteaiorfile,$n_srv->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$n_srv_nesteaiorfile>\n";
        $N_SRV->Kill (); $N_SRV->TimedWait (1);
        return 1;
    }
    if ($n_srv->GetFile ($nesteaiorfile) == -1) {
        print STDERR "ERROR: cannot retrieve file <$n_srv_nesteaiorfile>\n";
        $N_SRV->Kill (); $N_SRV->TimedWait (1);
        return 1;
    }
    if ($n_cli->PutFile ($nesteaiorfile) == -1) {
        print STDERR "ERROR: cannot set file <$n_cli_nesteaiorfile>\n";
        $N_SRV->Kill (); $N_SRV->TimedWait (1);
        return 1;
    }

    $N_CLI_status = $N_CLI->SpawnWaitKill ($n_cli->ProcessStartWaitInterval());
    if ($N_CLI_status != 0) {
        print STDERR "ERROR: Nestea Client returned $N_CLI_status\n";
        $status = 1;
    }

    $N_SRV_status = $N_SRV->TerminateWaitKill ($n_srv->ProcessStopWaitInterval());
    if ($N_SRV_status != 0) {
        print STDERR "ERROR: Nestea Server returned $N_SRV_status\n";
        $status = 1;
    }

    $n_srv->DeleteFile ($nesteaiorfile);
    $n_cli->DeleteFile ($nesteaiorfile);

    return $status;
}

sub nt_service_test_i
{
    my ($imr_initref, $BIN_ACT, $BIN_IMR) = @_;

    my $a_srv_airplaneiorfile = $a_srv[0]->LocalFile ($airplaneiorfile[0]);

    print "Installing TAO ImR Services\n";
    $BIN_ACT->Arguments ("-c install $imr_initref -d $test_debug_level -ORBDebugLevel $debug_level");
    $BIN_IMR->Arguments ("-c install -d $test_debug_level -orbendpoint iiop://:8888");

    $BIN_IMR_status = $BIN_IMR->SpawnWaitKill ($bin_imr->ProcessStartWaitInterval());
    if ($BIN_IMR_status != 0) {
        print STDERR "ERROR: ImR Service returned $BIN_IMR_status\n";
        return 1;
    }

    $BIN_ACT_status = $BIN_ACT->SpawnWaitKill ($bin_act->ProcessStartWaitInterval());
    if ($BIN_ACT_status != 0) {
        print STDERR "ERROR: ImR Activator returned $BIN_ACT_status\n";
        return 1;
    }

    # Starting the activator will also start the locator
    print "Starting TAO Implementation Repository Services\n";
    # Starting the activator should start the ImR automatically
    #system("net start taoimr 2>&1");
    system("net start taoimractivator 2>&1");

    # No need to specify imr_initref or -orbuseimr 1 for servers spawned by activator
    $TI->Arguments ("$imr_initref add $a_srv_name[0] -c \"$imr_A_SRV_cmd[0] -s $a_srv_name[0]\" ".
                    "-w \"$ENV{ACE_ROOT}/lib\"");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr add $a_srv_name[0] returned $TI_status\n";
        return 1;
    }

    $TI->Arguments ("$imr_initref list -v");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr list -v returned $TI_status\n";
        return 1;
    }

    $TI->Arguments ("$imr_initref ior $a_srv_name[0] -f $a_srv_airplaneiorfile");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr ior $a_srv_name[0] returned $TI_status\n";
        return 1;
    }
    if ($a_srv[0]->WaitForFileTimed ($airplaneiorfile[0],$a_srv[0]->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$a_srv_airplaneiorfile>\n";
        kill_then_timed_wait(\@A_SRV, 1);
        return 1;
    }
    if ($a_srv[0]->GetFile ($airplaneiorfile[0]) == -1) {
        print STDERR "ERROR: cannot retrieve file <$a_srv_airplaneiorfile>\n";
        kill_then_timed_wait(\@A_SRV, 1);
        return 1;
    }
    if ($a_cli[0]->PutFile ($airplaneiorfile[0]) == -1) {
        print STDERR "ERROR: cannot set file <$a_cli_airplaneiorfile[$index]>\n";
        kill_then_timed_wait(\@A_SRV, 1);
        return 1;
    }

    $A_CLI_status = $A_CLI[0]->SpawnWaitKill ($a_cli[0]->ProcessStartWaitInterval()+5);
    if ($A_CLI_status != 0) {
        print STDERR "ERROR: airplane client returned $A_CLI_status\n";
        kill_then_timed_wait(\@A_SRV, 1);
        return 1;
    }

    $TI->Arguments ("$imr_initref shutdown $a_srv_name[0]");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval()+5);
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr shutdown $a_srv_name[0] returned $TI_status\n";
        kill_then_timed_wait(\@A_SRV, 1);
        return 1;
    }

    return 0;
}

sub nt_service_test
{
    my $result = 0;

    my $a_srv_airplaneiorfile = $a_srv[0]->LocalFile ($airplaneiorfile[0]);
    $a_srv[0]->DeleteFile ($airplaneiorfile[0]);
    $a_cli[0]->DeleteFile ($airplaneiorfile[0]);

    my $bin_imr_host = $bin_imr->HostName ();

    # Just to show that it's possible, this test uses corbaloc instead of ior file.
    my $imr_initref = "-orbinitref ImplRepoService=corbaloc::$bin_imr_host:8888/ImplRepoService";

    # To avoid having to ensure that they LocalSystem account has the correct path
    # we simply copy the imr executables to the same directory as the DLL's.
    my $BIN_IMR = $bin_imr->CreateProcess ("$ENV{ACE_ROOT}/lib/tao_imr_locator","");
    my $BIN_ACT = $bin_act->CreateProcess ("$ENV{ACE_ROOT}/lib/tao_imr_activator","");
    $BIN_IMR->IgnoreExeSubDir(1);
    $BIN_ACT->IgnoreExeSubDir(1);

    print "Copying ImplRepo services to the same location as the dlls.\n";
    $bin_imr->DeleteFile ($BIN_IMR->Executable ());
    copy ($IMR->Executable (), $BIN_IMR->Executable ());
#    chmod(0755, $BIN_IMR->Executable ());
    $bin_act->DeleteFile ($BIN_ACT->Executable ());
    copy ($ACT->Executable (), $BIN_ACT->Executable ());
#    chmod(0755, $BIN_ACT->Executable ());

    print "Stopping any existing TAO ImR Services\n";
    system("net stop taoimractivator > nul 2>&1");
    system("net stop taoimr > nul 2>&1");

    print "Removing any existing TAO ImR Services\n";
    $BIN_ACT->Arguments ("-c remove");
    $BIN_IMR->Arguments ("-c remove");
    $BIN_ACT_status = $BIN_ACT->SpawnWaitKill ($bin_act->ProcessStartWaitInterval());
    if ($BIN_ACT_status < 0) {
        print STDERR "ERROR: BIN Activator returned $BIN_ACT_status\n";
    }
    $BIN_IMR_status = $BIN_IMR->SpawnWaitKill ($bin_imr->ProcessStartWaitInterval());
    if ($BIN_IMR_status < 0) {
        print STDERR "ERROR: BIN ImR Service returned $BIN_IMR_status\n";
    }

    $result = nt_service_test_i ($imr_initref, $BIN_ACT, $BIN_IMR);

    print "Stopping TAO Implementation Repository Service\n";
    system("net stop taoimractivator 2>&1");
    system("net stop taoimr 2>&1");

    print "Removing TAO ImR Services\n";
    $BIN_ACT->Arguments ("-c remove");
    $BIN_ACT_status = $BIN_ACT->SpawnWaitKill ($bin_act->ProcessStartWaitInterval());
    if ($BIN_ACT_status != 0) {
        print STDERR "ERROR: BIN Activator returned $BIN_ACT_status\n";
    }
    $BIN_IMR->Arguments ("-c remove");
    $BIN_IMR_status = $BIN_IMR->SpawnWaitKill ($bin_imr->ProcessStartWaitInterval());
    if ($BIN_IMR_status != 0) {
        print STDERR "ERROR: BIN ImR Service returned $BIN_IMR_status\n";
    }

    print "Removing tao_imr_locator copy.\n";
    $bin_imr->DeleteFile ($BIN_IMR->Executable ());
    $bin_act->DeleteFile ($BIN_ACT->Executable ());

    $a_srv[0]->DeleteFile ($airplaneiorfile[0]);
    $a_cli[0]->DeleteFile ($airplaneiorfile[0]);

    return $result;
}

###############################################################################

sub airplane_ir_test
{
    my $status = 0;

    if ($srv_debug_level < 2 && $replica) {
        $srv_debug_level = 2;
    }

    my $imr_port = 10001 + $imr->RandomPort ();
    print "\n\nimr_port=$imr_port\n";
    my %repo;
    setup_repo(\%repo, $imr, $IMR, $imriorfile, $act, $ACT, $actiorfile, $ti,
      $TI, $imr_port, "-primary", $backupiorfile);

    my %backup_repo;
    if ($replica) {
        setup_repo(\%backup_repo, $replica_imr, $replica_IMR,
          $replica_imriorfile, $replica_act, $replica_ACT, $replica_actiorfile,
          $replica_ti, $replica_TI, $imr_port + 1, "-backup",
          $primaryiorfile, "non_default_act");
    }

    my @repo_for_srvr;
    for ($index = 0; $index < $num_srvr; ++$index) {
        if ($index == ($num_srvr - 1) && $replica) {
            push(@repo_for_srvr, \%backup_repo);
        }
        else {
            push(@repo_for_srvr, \%repo);
        }

        push(@a_srv_imriorfile, $a_srv[$index]->LocalFile ($repo_for_srvr[$index]->{imriorfile}));
        push(@imr_airplaneiorfile, $repo_for_srvr[$index]->{imr}->LocalFile ($airplaneiorfile[$index]));
        push(@a_srv_airplaneiorfile, $a_srv[$index]->LocalFile ($airplaneiorfile[$index]));
        $a_srv[$index]->DeleteFile ($repo_for_srvr[$index]->{imriorfile});
        $a_srv[$index]->DeleteFile ($airplaneiorfile[$index]);
        $a_cli[$index]->DeleteFile ($airplaneiorfile[$index]);
        $repo_for_srvr[$index]->{imr}->DeleteFile ($airplaneiorfile[$index]);
    }
    $imr->DeleteFile ($imriorfile);
    $act->DeleteFile ($imriorfile);
    $ti->DeleteFile ($imriorfile);
    $act->DeleteFile ($actiorfile);
    if ($replica) {
        $replica_imr->DeleteFile ($replica_imriorfile);
        $replica_act->DeleteFile ($replica_imriorfile);
        $replica_ti->DeleteFile ($replica_imriorfile);
        $replica_act->DeleteFile ($replica_actiorfile);
    }

    print "\n\nstarting IMR\n";
    $repo{IMR}->Arguments ("-d $test_debug_level -o $repo{imr_imriorfile} " .
      "$refstyle $repo{imr_backing_store_flag} $repo{imr_endpoint_flag}");
    $IMR_status = $repo{IMR}->Spawn ();
    if ($IMR_status != 0) {
        print STDERR "ERROR: ImR Service returned $IMR_status\n";
        return 1;
    }
    if ($replica) {
        if (wait_for_imr(\%backup_repo, "replicaiorfile")) {
            return 1;
        }
        print "\n\nstarting backup IMR\n";
        $backup_repo{IMR}->Arguments ("-d $test_debug_level -o " .
          "$backup_repo{imr_imriorfile} $refstyle " .
          "$backup_repo{imr_backing_store_flag} " .
          "$backup_repo{imr_endpoint_flag}");
        $replica_IMR_status = $backup_repo{IMR}->Spawn ();
        if ($replica_IMR_status != 0) {
            print STDERR "ERROR: ImR Service replica returned $replica_IMR_status\n";
            return 1;
        }
        if (wait_for_imr(\%repo, "replicaiorfile")) {
            return 1;
        }
        print "started backup IMR\n";
    }
    if (wait_for_imr(\%repo)) {
        return 1;
    }
    print "started IMR\n";

    for ($index = 0; $index < $num_srvr; ++$index) {
        if ($a_srv[$index]->PutFile ($repo_for_srvr[$index]->{imriorfile}) == -1) {
            print STDERR "ERROR: cannot set file <$a_srv_imriorfile[$index]>\n";
            kill_imr();
            return 1;
        }
    }

    print "\n\nstarting ACT\n";
    $repo{ACT}->Arguments ("-d $test_debug_level -o $repo{act_actiorfile} " .
      "-ORBInitRef ImplRepoService=file://$repo{act_imriorfile} $refstyle " .
      $repo{act_explicit_flag});
    $ACT_status = $repo{ACT}->Spawn ();
    if ($ACT_status != 0) {
        print STDERR "ERROR: ImR Activator returned $ACT_status\n";
        return 1;
    }

    if ($repo{act}->WaitForFileTimed (
                  $repo{actiorfile},
                  $repo{act}->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <" .
          $repo{act_actiorfile} . ">\n";
        kill_act();
        kill_imr();
        return 1;
    }
    print "started ACT\n";

    if ($replica) {
        print "\n\nstarting non-default ACT\n";
        $backup_repo{ACT}->Arguments (
          "-d $test_debug_level -o $backup_repo{act_actiorfile} $refstyle " .
          "-ORBInitRef ImplRepoService=file://$backup_repo{act_imriorfile} " .
          $backup_repo{act_explicit_flag});
        $ACT_status = $backup_repo{ACT}->Spawn ();
        if ($ACT_status != 0) {
            print STDERR "ERROR: ImR Activator replica returned $ACT_status\n";
            return 1;
        }
    }

    if ($replica) {
        if ($backup_repo{act}->WaitForFileTimed (
                  $backup_repo{actiorfile},
                  $backup_repo{act}->ProcessStartWaitInterval()) == -1) {
            print STDERR "ERROR: cannot find file <" .
              $backup_repo{act_actiorfile} . ">\n";
            kill_act();
            kill_imr();
            return 1;
        }
        print "started non-default ACT\n";
    }

    # No need to specify imr_initref or -orbuseimr 1 for servers spawned by activator
    # Can use update to add servers.
    for ($index = 0; $index < $num_srvr; ++$index) {
        print "\n\nstarting TI $index\n";
        $repo_for_srvr[$index]->{TI}->Arguments ("-ORBInitRef ImplRepoService" .
          "=file://$repo_for_srvr[$index]->{ti_imriorfile} $refstyle " .
          "update $a_srv_name[$index] -c \"$imr_A_SRV_cmd[$index] " .
          "-o $imr_airplaneiorfile[$index] -s $a_srv_name[$index]\" " .
          "$repo_for_srvr[$index]->{server_act_flag} ");
        $TI_status = $repo_for_srvr[$index]->{TI}->SpawnWaitKill (
          $repo_for_srvr[$index]->{ti}->ProcessStartWaitInterval());
        if ($TI_status != 0) {
            print STDERR "ERROR: tao_imr ($index) returned $TI_status\n";
            kill_act();
            kill_imr();
            return 1;
        }
        print "stopped TI $index\n";

        print "\n\nstarting srv $index\n";
        $A_SRV[$index]->Arguments (
          "-ORBUseIMR 1 -o $a_srv_airplaneiorfile[$index] $refstyle ".
          "-ORBInitRef ImplRepoService=file://$a_srv_imriorfile[$index] ".
          "-ORBDebugLevel $srv_debug_level -s $a_srv_name[$index] ");
        $A_SRV_status = $A_SRV[$index]->Spawn ();
        if ($A_SRV_status != 0) {
            print STDERR "ERROR: Airplane Server returned $A_SRV_status\n";
            return 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        if ($a_srv[$index]->WaitForFileTimed ($airplaneiorfile[$index],$a_srv[$index]->ProcessStartWaitInterval()) == -1) {
            print STDERR "ERROR: cannot find file <$a_srv_airplaneiorfile[$index]>\n";
            kill_then_timed_wait(\@A_SRV, 1);
            kill_act();
            kill_imr();
            return 1;
        }
        if ($a_srv[$index]->GetFile ($airplaneiorfile[$index]) == -1) {
            print STDERR "ERROR: cannot retrieve file <$a_srv_airplaneiorfile[$index]>\n";
            kill_then_timed_wait(\@A_SRV, 1);
            kill_act();
            kill_imr();
            return 1;
        }
        if ($a_cli[$index]->PutFile ($airplaneiorfile[$index]) == -1) {
            print STDERR "ERROR: cannot set file <$a_cli_airplaneiorfile[$index]>\n";
            kill_then_timed_wait(\@A_SRV, 1);
            kill_act();
            kill_imr();
            return 1;
        }
        print "\n\nstarted srv $index\n\n";
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        print "\n\nstarting client $index\n";
        $A_CLI_status = $A_CLI[$index]->Spawn ();
        if ($A_CLI_status != 0) {
            print STDERR "ERROR: Airplane Client $index failed to spawn returning $A_CLI_status\n";
            $status = 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        $A_CLI_status = $A_CLI[$index]->WaitKill ($a_cli[$index]->ProcessStartWaitInterval());
        if ($A_CLI_status != 0) {
            print STDERR "ERROR: Airplane Client $index returned $A_CLI_status\n";
            $status = 1;
        }
        print "\n\nstopped client $index\n\n\n";
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        print "\n\nstarting TI $index (2)\n";
        $repo_for_srvr[$index]->{TI}->Arguments ("-ORBInitRef " .
          "ImplRepoService=file://$repo_for_srvr[$index]->{ti_imriorfile} " .
          "$refstyle shutdown $a_srv_name[$index]");

        $TI_status = $repo_for_srvr[$index]->{TI}->SpawnWaitKill (
          $repo_for_srvr[$index]->{ti}->ProcessStartWaitInterval());
        if ($TI_status != 0) {
            print STDERR "ERROR: tao_imr 1 ($index) returned $TI_status\n";
            $status = 1;
        }
        print "stopped TI $index (2)\n";
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        print "\n\nstarting client $index\n";
        # This client should force a new airplane_server to be started
        $A_CLI_status = $A_CLI[$index]->SpawnWaitKill (
          $a_cli[$index]->ProcessStartWaitInterval());
        if ($A_CLI_status != 0) {
            print STDERR "ERROR: restarted Airplane Client $index returned " .
              "$A_CLI_status\n";
            $status = 1;
        }
        print "stopped client $index\n";

        print "\n\nstarting client $index\n";
        $repo_for_srvr[$index]->{TI}->Arguments ("-ORBInitRef " .
          "ImplRepoService=file://$repo_for_srvr[$index]->{ti_imriorfile} " .
          "$refstyle shutdown $a_srv_name[$index]");

        $TI_status = $repo_for_srvr[$index]->{TI}->SpawnWaitKill (
          $repo_for_srvr[$index]->{ti}->ProcessStartWaitInterval());
        if ($TI_status != 0) {
            print STDERR "ERROR: tao_imr 2 ($index) returned $TI_status\n";
            $status = 1;
        }
        print "stopped client $index\n";
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        print "\n\nkilling srv $index\n";
        $A_SRV_status = $A_SRV[$index]->WaitKill ($a_srv[$index]->ProcessStopWaitInterval());
        if ($A_SRV_status != 0) {
            print STDERR "ERROR: Airplane Server returned $A_SRV_status\n";
            $status = 1;
        }
        print "stopped srv $index\n";
    }

    print "\n\nkilling ACT\n";
    $ACT_status = $repo{ACT}->TerminateWaitKill (
      $repo{act}->ProcessStopWaitInterval());
    if ($ACT_status != 0) {
        print STDERR "ERROR: Activator returned $ACT_status\n";
        $status = 1;
    }
    print "stopped ACT\n";

    if ($replica) {
        print "\n\nkilling non-default ACT\n";
        $ACT_status = $backup_repo{ACT}->TerminateWaitKill (
          $backup_repo{act}->ProcessStopWaitInterval());
        if ($ACT_status != 0) {
            print STDERR "ERROR: replica Activator returned $ACT_status\n";
            $status = 1;
        }
        print "stopped non-default ACT\n";
    }

    print "\n\nkilling IMR\n";
    $IMR_status = $repo{IMR}->TerminateWaitKill (
      $repo{imr}->ProcessStopWaitInterval());
    if ($IMR_status != 0) {
        print STDERR "ERROR: ImR returned $IMR_status\n";
        $status = 1;
    }
    print "stopped IMR\n";

    if ($replica) {
        print "\n\nkilling backup IMR\n";
        $IMR_status = $backup_repo{IMR}->TerminateWaitKill (
          $backup_repo{imr}->ProcessStopWaitInterval());
        if ($IMR_status != 0) {
            print STDERR "ERROR: replica ImR returned $IMR_status\n";
            $status = 1;
        }
        print "stopped backup IMR\n";
    }

    $repo{imr}->DeleteFile ($repo{imriorfile});
    $repo{act}->DeleteFile ($repo{imriorfile});
    $repo{ti}->DeleteFile ($repo{imriorfile});
    $repo{act}->DeleteFile ($repo{actiorfile});

    if ($replica) {
        $backup_repo{imr}->DeleteFile (
          $backup_repo{imriorfile});
        $backup_repo{act}->DeleteFile (
          $backup_repo{imriorfile});
        $backup_repo{ti}->DeleteFile (
          $backup_repo{imriorfile});
        $backup_repo{act}->DeleteFile (
          $backup_repo{actiorfile});
        cleanup_replication($backing_store);
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        $repo_for_srvr[$index]->{imr}->DeleteFile (
          $airplaneiorfile[$index]);
        $a_srv[$index]->DeleteFile (
          $repo_for_srvr[$index]->{imriorfile});
        $a_srv[$index]->DeleteFile ($airplaneiorfile[$index]);
        $a_cli[$index]->DeleteFile ($airplaneiorfile[$index]);
    }
    return $status;
}

###############################################################################

sub nestea_ir_test
{
    my $status = 0;

    my $imr_imriorfile = $imr->LocalFile ($imriorfile);
    my $act_imriorfile = $act->LocalFile ($imriorfile);
    my $ti_imriorfile = $ti->LocalFile ($imriorfile);
    my $n_srv_imriorfile = $n_srv->LocalFile ($imriorfile);
    my $act_actiorfile = $act->LocalFile ($actiorfile);
    my $imr_nesteaiorfile = $imr->LocalFile ($nesteaiorfile);
    my $n_srv_nesteaiorfile = $n_srv->LocalFile ($nesteaiorfile);
    $imr->DeleteFile ($imriorfile);
    $act->DeleteFile ($imriorfile);
    $ti->DeleteFile ($imriorfile);
    $n_srv->DeleteFile ($imriorfile);
    $act->DeleteFile ($actiorfile);
    $imr->DeleteFile ($nesteaiorfile);
    $n_srv->DeleteFile ($nesteaiorfile);
    $n_cli->DeleteFile ($nesteaiorfile);

    $IMR->Arguments ("-d $test_debug_level -o $imr_imriorfile $refstyle");
    $IMR_status = $IMR->Spawn ();
    if ($IMR_status != 0) {
        print STDERR "ERROR: ImR Service returned $IMR_status\n";
        return 1;
    }
    if ($imr->WaitForFileTimed ($imriorfile,
                                $imr->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$imr_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($imr->GetFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot retrieve file <$imr_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($act->PutFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot set file <$act_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($ti->PutFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot set file <$ti_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($n_srv->PutFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot set file <$n_srv_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    $ACT->Arguments (
      "-d $test_debug_level -o $act_actiorfile -orbobjrefstyle URL ".
      "-ORBInitRef ImplRepoService=file://$act_imriorfile");
    $ACT_status = $ACT->Spawn ();
    if ($ACT_status != 0) {
        print STDERR "ERROR: ImR Activator returned $ACT_status\n";
        return 1;
    }
    if ($act->WaitForFileTimed ($actiorfile,$act->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$act_actiorfile>\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    $N_SRV->Arguments (
      "-ORBUseIMR 1 -o $n_srv_nesteaiorfile -orbobjrefstyle URL ".
      "-ORBInitRef ImplRepoService=file://$n_srv_imriorfile ".
      "-ORBDebugLevel $srv_debug_level");
    $N_SRV_status = $N_SRV->Spawn ();
    if ($N_SRV_status != 0) {
        print STDERR "ERROR: Nestea Server returned $N_SRV_status\n";
        return 1;
    }
    if ($n_srv->WaitForFileTimed ($nesteaiorfile,$n_srv->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$n_srv_nesteaiorfile>\n";
        $N_SRV->Kill (); $N_SRV->TimedWait (1);
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($n_srv->GetFile ($nesteaiorfile) == -1) {
        print STDERR "ERROR: cannot retrieve file <$n_srv_nesteaiorfile>\n";
        $N_SRV->Kill (); $N_SRV->TimedWait (1);
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($n_cli->PutFile ($nesteaiorfile) == -1) {
        print STDERR "ERROR: cannot set file <$n_cli_nesteaiorfile>\n";
        $N_SRV->Kill (); $N_SRV->TimedWait (1);
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    $N_CLI_status = $N_CLI->SpawnWaitKill ($n_cli->ProcessStartWaitInterval());
    if ($N_CLI_status != 0) {
        print STDERR "ERROR: Nestea Client 1 returned $N_CLI_status\n";
        $N_SRV->Kill (); $N_SRV->TimedWait (1);
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    $TI->Arguments ("-orbobjrefstyle URL -ORBInitRef ImplRepoService=file://$ti_imriorfile ".
                    " shutdown nestea_server");

    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr 1 returned $TI_status\n";
        $N_SRV->Kill (); $N_SRV->TimedWait (1);
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    $N_SRV_status = $N_SRV->WaitKill ($n_srv->ProcessStopWaitInterval());
    if ($N_SRV_status != 0) {
        print STDERR "ERROR: Nestea Server returned $N_SRV_status\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    # No need to specify imr_initref or -orbuseimr 1 for servers spawned by activator
    $TI->Arguments ("-orbobjrefstyle URL -ORBInitRef ImplRepoService=file://$ti_imriorfile ".
                    "update nestea_server -l $imr_host ".
                    "-c \"$imr_N_SRV_cmd -o $imr_nesteaiorfile\"");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr returned $TI_status\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    # This should cause the activator to spawn another server.
    $N_CLI_status = $N_CLI->SpawnWaitKill ($n_cli->ProcessStartWaitInterval()+5);
    if ($N_CLI_status != 0) {
        print STDERR "ERROR: Nestea Client 2 returned $N_CLI_status\n";
        $status = 1;
    }

    $TI->Arguments ("-orbobjrefstyle URL -ORBInitRef ImplRepoService=file://$ti_imriorfile ".
                    "shutdown nestea_server");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr 1 returned $TI_status\n";
        $status = 1;
    }

    # This should destroy the POA, causing another to be created the next time
    # the server is spawned.
    $TI->Arguments ("-orbobjrefstyle URL -ORBInitRef ImplRepoService=file://$ti_imriorfile ".
                         "remove nestea_server");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr 1 returned $TI_status\n";
        $status = 1;
    }

    # No need to specify imr_initref or -orbuseimr 1 for servers spawned by activator
    $TI->Arguments ("-orbobjrefstyle URL -ORBInitRef ImplRepoService=file://$ti_imriorfile ".
                    "add nestea_server -c \"$imr_N_SRV_cmd -o $imr_nesteaiorfile\"");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr 1 returned $TI_status\n";
        $status = 1;
    }

    # This should cause the activator to spawn another server.
    $N_CLI_status = $N_CLI->SpawnWaitKill ($n_cli->ProcessStartWaitInterval()+5);
    if ($N_CLI_status != 0) {
        print STDERR "ERROR: Nestea Client 2 returned $N_CLI_status\n";
        $status = 1;
    }

    # This call should block until the server shuts down
    $TI->Arguments ("-orbobjrefstyle URL -ORBInitRef ImplRepoService=file://$ti_imriorfile ".
                         "shutdown nestea_server");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr 1 returned $TI_status\n";
        $status = 1;
    }

    $ACT_status = $ACT->TerminateWaitKill ($act->ProcessStopWaitInterval());
    if ($ACT_status != 0) {
        print STDERR "ERROR: Activator returned $ACT_status\n";
        $status = 1;
    }

    $IMR_status = $IMR->TerminateWaitKill ($imr->ProcessStopWaitInterval());
    if ($IMR_status != 0) {
        print STDERR "ERROR: ImR returned $IMR_status\n";
        $status = 1;
    }

    $imr->DeleteFile ($imriorfile);
    $act->DeleteFile ($imriorfile);
    $ti->DeleteFile ($imriorfile);
    $n_srv->DeleteFile ($imriorfile);
    $act->DeleteFile ($actiorfile);
    $imr->DeleteFile ($nesteaiorfile);
    $n_srv->DeleteFile ($nesteaiorfile);
    $n_cli->DeleteFile ($nesteaiorfile);

    return $status;
}

###############################################################################

sub perclient
{
    my $status = 0;

    my $imr_imriorfile = $imr->LocalFile ($imriorfile);
    my $act_imriorfile = $act->LocalFile ($imriorfile);
    my $ti_imriorfile = $ti->LocalFile ($imriorfile);
    my $act_actiorfile = $act->LocalFile ($actiorfile);
    my $imr_nesteaiorfile = $imr->LocalFile ($nesteaiorfile);
    $imr->DeleteFile ($imriorfile);
    $act->DeleteFile ($imriorfile);
    $ti->DeleteFile ($imriorfile);
    $act->DeleteFile ($actiorfile);
    $imr->DeleteFile ($nesteaiorfile);
    $n_cli->DeleteFile ($nesteaiorfile);

    my $imr_host = $imr->HostName ();

    # specify an endpoint so that we can use corbaloc url for the client.
    $IMR->Arguments (
      "-d $test_debug_level -orbendpoint iiop://:8888 ".
      "-o $imr_imriorfile $refstyle -ORBDebugLevel $debug_level");
    $IMR_status = $IMR->Spawn ();
    if ($IMR_status != 0) {
        print STDERR "ERROR: ImR Service returned $IMR_status\n";
        return 1;
    }
    if ($imr->WaitForFileTimed ($imriorfile,
                                $imr->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$imr_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($imr->GetFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot retrieve file <$imr_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($act->PutFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot set file <$act_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($ti->PutFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot set file <$ti_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    $ACT->Arguments ("-d $test_debug_level -o $act_actiorfile ".
                     "-orbobjrefstyle URL -ORBInitRef ImplRepoService=file://$act_imriorfile");
    $ACT_status = $ACT->Spawn ();
    if ($ACT_status != 0) {
        print STDERR "ERROR: ImR Activator returned $ACT_status\n";
        return 1;
    }
    if ($act->WaitForFileTimed ($actiorfile,$act->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$act_actiorfile>\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    # No need to specify imr_initref or -orbuseimr 1 for servers spawned by activator
    $TI->Arguments ("-orbobjrefstyle URL -ORBInitRef ImplRepoService=file://$ti_imriorfile ".
                    "add nestea_server -a PER_CLIENT ".
                    "-c \"$imr_N_SRV_cmd -o $imr_nesteaiorfile\"");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr returned $TI_status\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    $N_CLI->Arguments("-k corbaloc::$imr_host:8888/nestea_server");

    # Running the client should start a server instance
    $N_CLI_status = $N_CLI->SpawnWaitKill ($n_cli->ProcessStartWaitInterval()+5);
    if ($N_CLI_status != 0) {
        print STDERR "ERROR: Nestea Client 1 returned $N_CLI_status\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($n_cli->WaitForFileTimed ($nesteaiorfile,$a_cli[0]->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$a_cli_nesteaiorfile>\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    $a_cli[0]->DeleteFile ($nesteaiorfile);

    $N_CLI->Arguments("-s -k corbaloc::$imr_host:8888/nestea_server");

    # Running the client again should start another server instance
    $N_CLI_status = $N_CLI->SpawnWaitKill ($n_cli->ProcessStartWaitInterval()+5);
    if ($N_CLI_status != 0) {
        print STDERR "ERROR: Nestea Client 1 returned $N_CLI_status\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($n_cli->WaitForFileTimed ($nesteaiorfile,$a_cli[0]->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$a_cli_nesteaiorfile>\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    # Note : We have to wait long enough for the first server to self-destruct
    # or it will print out an exception when it can't notify the imr of its shutdown.
    sleep 20;

    $ACT_status = $ACT->TerminateWaitKill ($act->ProcessStopWaitInterval());
    if ($ACT_status != 0) {
        print STDERR "ERROR: Activator returned $ACT_status\n";
        $status = 1;
    }

    $IMR_status = $IMR->TerminateWaitKill ($imr->ProcessStopWaitInterval());
    if ($IMR_status != 0) {
        print STDERR "ERROR: ImR returned $IMR_status\n";
        $status = 1;
    }

    $imr->DeleteFile ($imriorfile);
    $act->DeleteFile ($imriorfile);
    $ti->DeleteFile ($imriorfile);
    $act->DeleteFile ($actiorfile);
    $imr->DeleteFile ($nesteaiorfile);
    $n_cli->DeleteFile ($nesteaiorfile);

    return $status;
}

###############################################################################

sub shutdown_repo
{
    my $status = 0;

    my $testrepo = "test.repo";

    my $imr_imriorfile = $imr->LocalFile ($imriorfile);
    my $act_imriorfile = $act->LocalFile ($imriorfile);
    my $ti_imriorfile = $ti->LocalFile ($imriorfile);
    my $act_actiorfile = $act->LocalFile ($actiorfile);
    my $imr_testrepo = $imr->LocalFile ($testrepo);
    $imr->DeleteFile ($imriorfile);
    $act->DeleteFile ($imriorfile);
    $ti->DeleteFile ($imriorfile);
    $act->DeleteFile ($actiorfile);
    $imr->DeleteFile ($testrepo);

    # Specify an endpoint so that we can restart on the same port.
    # Specify persistence so that we can test that shutdown-repo -a works after reconnect
    $IMR->Arguments ("-p $imr_testrepo -d 1 -orbendpoint iiop://:8888 -o $imr_imriorfile $refstyle ".
                     "-ORBDebugLevel $debug_level");
    $IMR_status = $IMR->Spawn ();
    if ($IMR_status != 0) {
        print STDERR "ERROR: ImR Service returned $IMR_status\n";
        return 1;
    }
    if ($imr->WaitForFileTimed ($imriorfile,
                                $imr->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$imr_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($imr->GetFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot retrieve file <$imr_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($act->PutFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot set file <$act_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($ti->PutFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot set file <$ti_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    $ACT->Arguments ("-d 1 -o $act_actiorfile ".
                     "-orbobjrefstyle URL -ORBInitRef ImplRepoService=file://$act_imriorfile");
    $ACT_status = $ACT->Spawn ();
    if ($ACT_status != 0) {
        print STDERR "ERROR: ImR Activator returned $ACT_status\n";
        return 1;
    }
    if ($act->WaitForFileTimed ($actiorfile,$act->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$act_actiorfile>\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    # Kill the ImR, but leave the activator running
    $TI->Arguments ("-orbobjrefstyle URL -ORBInitRef ImplRepoService=file://$ti_imriorfile ".
                    "shutdown-repo");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr returned $TI_status\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    $IMR_status = $IMR->WaitKill ($imr->ProcessStopWaitInterval());
    if ($IMR_status != 0) {
        print STDERR "ERROR: ImR returned $IMR_status\n";
        return 1;
    }

    $imr->DeleteFile ($imriorfile);

    $IMR_status = $IMR->Spawn ();
    if ($IMR_status != 0) {
        print STDERR "ERROR: ImR Service returned $IMR_status\n";
        return 1;
    }
    if ($imr->WaitForFileTimed ($imriorfile,
                                $imr->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$imr_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($imr->GetFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot retrieve file <$imr_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($ti->PutFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot set file <$ti_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    $TI->Arguments ("-orbobjrefstyle URL -ORBInitRef ImplRepoService=file://$ti_imriorfile ".
                    "shutdown-repo -a");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr returned $TI_status\n";
        $status = 1;
    }

    $ACT_status = $ACT->TerminateWaitKill ($act->ProcessStopWaitInterval());
    if ($ACT_status != 0) {
        print STDERR "ERROR: Activator returned $ACT_status\n";
        $status = 1;
    }

    $IMR_status = $IMR->TerminateWaitKill ($imr->ProcessStopWaitInterval());
    if ($IMR_status != 0) {
        print STDERR "ERROR: ImR returned $IMR_status\n";
        $status = 1;
    }

    $imr->DeleteFile ($imriorfile);
    $act->DeleteFile ($imriorfile);
    $ti->DeleteFile ($imriorfile);
    $act->DeleteFile ($actiorfile);
    $imr->DeleteFile ($testrepo);

    return $status;
}

###############################################################################

sub persistent_ir_test
{
    my $backing_store_flag = shift;
    my $status = 0;

    if ($srv_debug_level == 0) {
        $srv_debug_level = 1;
    }

    test_info("persistent_ir_test start\n");

    my $backing_store;
    if ($backing_store_flag eq "-p") {
        $backing_store = "test.repo";
    } elsif ($backing_store_flag eq "-y") {
        $backing_store = ".";
    } elsif ($backing_store_flag eq "-x") {
        $backing_store = "imr_backing_store.xml";
    }

    my $imr_imriorfile = $imr->LocalFile ($imriorfile);
    my $imr_storefile;
    if (defined($backing_store)) {
        $imr_storefile = $imr->LocalFile ($backing_store);
    }
    my $act_imriorfile = $act->LocalFile ($imriorfile);
    my $ti_imriorfile = $ti->LocalFile ($imriorfile);
    my $act_actiorfile = $act->LocalFile ($actiorfile);

    my @a_srv_imriorfile;
    my @imr_airplaneiorfile;
    my @a_srv_airplaneiorfile;
    for ($index = 0; $index < $num_srvr; ++$index) {
        push(@a_srv_imriorfile, $a_srv[$index]->LocalFile ($imriorfile));
        push(@imr_airplaneiorfile, $imr->LocalFile ($airplaneiorfile[$index]));
        push(@a_srv_airplaneiorfile, $a_srv[$index]->LocalFile ($airplaneiorfile[$index]));
        $a_srv[$index]->DeleteFile ($imriorfile);
        $a_srv[$index]->DeleteFile ($airplaneiorfile[$index]);
        $a_cli[$index]->DeleteFile ($airplaneiorfile[$index]);
        $imr->DeleteFile ($airplaneiorfile[$index]);
    }
    $imr->DeleteFile ($imriorfile);
    # passing "-e" flag to clear persistent storage on startup
    $act->DeleteFile ($imriorfile);
    $ti->DeleteFile ($imriorfile);
    $act->DeleteFile ($actiorfile);

    ## Be sure to start the ImR on a consistent endpoint, so that any created IORs
    ## remain valid even if the ImR restarts.
    my $imr_arguments = "-orbendpoint iiop://:8888 $backing_store_flag $imr_storefile -d $test_debug_level -o $imr_imriorfile $refstyle ";
    $IMR->Arguments ("$imr_arguments -e ");
    test_info("starting IMR=" . $IMR->CommandLine() . "\n");
    $IMR_status = $IMR->Spawn ();
    if ($IMR_status != 0) {
        print STDERR "ERROR: ImR Service returned $IMR_status\n";
        return 1;
    }
    if ($imr->WaitForFileTimed ($imriorfile,
                                $imr->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$imr_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($imr->GetFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot retrieve file <$imr_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($act->PutFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot set file <$act_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($ti->PutFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot set file <$ti_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        if ($a_srv[$index]->PutFile ($imriorfile) == -1) {
            print STDERR "ERROR: cannot set file <$a_srv_imriorfile[$index]>\n";
            $IMR->Kill (); $IMR->TimedWait (1);
            return 1;
        }
    }

    $ACT->Arguments ("-d $test_debug_level -o $act_actiorfile -ORBInitRef ImplRepoService=file://$act_imriorfile");
    test_info("starting ACT=" . $ACT->CommandLine() . "\n");
    $ACT_status = $ACT->Spawn ();
    if ($ACT_status != 0) {
        print STDERR "ERROR: ImR Activator returned $ACT_status\n";
        return 1;
    }

    if ($act->WaitForFileTimed ($actiorfile,$act->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$act_actiorfile>\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($act->GetFile ($actiorfile) == -1) {
        print STDERR "ERROR: cannot retrieve file <$act_actiorfile>\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        $p_srv[$index]->DeleteFile ($P_SRV_cmd[$index]);
        # Copy the server to a path with spaces to ensure that these
        # work corrrectly.
        copy ($A_SRV_cmd[$index], $P_SRV_cmd[$index]);
        chmod(0755, $P_SRV_cmd[$index]);
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        # No need to specify imr_initref or -orbuseimr 1 for servers spawned by activator
        $TI->Arguments (
          "-ORBInitRef ImplRepoService=file://$ti_imriorfile ".
          "add $a_srv_name[$index] -c \"\\\"$imr_P_SRV_cmd[$index]\\\" " .
          "$refstyle -s $a_srv_name[$index]\"");
        test_info("starting TI=" . $TI->CommandLine() . "\n");
        $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
        if ($TI_status != 0) {
            print STDERR "ERROR: tao_imr ($index) returned $TI_status\n";
            $p_srv[$index]->DeleteFile ($P_SRV_cmd[$index]);
            $ACT->Kill (); $ACT->TimedWait (1);
            $IMR->Kill (); $IMR->TimedWait (1);
            return 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        ## This will write out the imr-ified IOR. Note : If you don't use -orbendpoint
        ## when starting the ImR, then this IOR will no longer be valid when the ImR
        ## restarts below. You can fix this by creating a new valid IOR, or starting
        ## the ImR on a consistent endpoint.
        $A_SRV[$index]->Arguments (
          "-o $a_srv_airplaneiorfile[$index] -ORBUseIMR 1 $refstyle ".
          "-ORBInitRef ImplRepoService=file://$a_srv_imriorfile[$index] ".
          "-ORBDebugLevel $srv_debug_level -s $a_srv_name[$index]");
        test_info("starting $a_srv_name[$index]=" .
          $A_SRV[$index]->CommandLine() . "\n");
        $A_SRV_status = $A_SRV[$index]->Spawn ();
        if ($A_SRV_status != 0) {
            print STDERR "ERROR: Airplane Server returned $A_SRV_status\n";
            return 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        if ($a_srv[$index]->WaitForFileTimed (
                  $airplaneiorfile[$index],
                  $a_srv[$index]->ProcessStartWaitInterval()) == -1) {
            print STDERR
              "ERROR: cannot find file <$a_srv_airplaneiorfile[$index]>\n";
            kill_then_timed_wait(\@A_SRV, 1);
            $ACT->Kill (); $ACT->TimedWait (1);
            $IMR->Kill (); $IMR->TimedWait (1);
            return 1;
        }
        if ($a_srv[$index]->GetFile ($airplaneiorfile[$index]) == -1) {
            print STDERR
              "ERROR: cannot retrieve file <$a_srv_airplaneiorfile[$index]>\n";
            kill_then_timed_wait(\@A_SRV, 1);
            $ACT->Kill (); $ACT->TimedWait (1);
            $IMR->Kill (); $IMR->TimedWait (1);
            return 1;
        }
        if ($a_cli[$index]->PutFile ($airplaneiorfile[$index]) == -1) {
            print STDERR "ERROR: cannot set file <$a_cli_airplaneiorfile[$index]>\n";
            kill_then_timed_wait(\@A_SRV, 1);
            $ACT->Kill (); $ACT->TimedWait (1);
            $IMR->Kill (); $IMR->TimedWait (1);
            return 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        test_info("starting client for $a_srv_name[$index]=" .
          $A_CLI[$index]->CommandLine() . "\n");
        $A_CLI_status = $A_CLI[$index]->Spawn ();
        if ($A_CLI_status != 0) {
            print STDERR
              "ERROR: Airplane Client ($index) failed to spawn returning $A_CLI_status\n";
            kill_then_timed_wait(\@A_SRV, 1);
            $ACT->Kill (); $ACT->TimedWait (1);
            $IMR->Kill (); $IMR->TimedWait (1);
            return 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        test_info("killing client for $a_srv_name[$index]\n");
        $A_CLI_status = $A_CLI[$index]->WaitKill ($a_cli[$index]->ProcessStartWaitInterval());
        if ($A_CLI_status != 0) {
            print STDERR "ERROR: Airplane Client ($index) returned $A_CLI_status\n";
            kill_then_timed_wait(\@A_SRV, 1);
            $ACT->Kill (); $ACT->TimedWait (1);
            $IMR->Kill (); $IMR->TimedWait (1);
            return 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        $TI->Arguments ("-ORBInitRef ImplRepoService=file://$ti_imriorfile ".
                        "shutdown $a_srv_name[$index]");
        test_info("starting TI=" . $TI->CommandLine() . "\n");
        $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
        if ($TI_status != 0) {
            print STDERR "ERROR: tao_imr shutdown returned $TI_status\n";
            kill_then_timed_wait(\@A_SRV, 1);
            $ACT->Kill (); $ACT->TimedWait (1);
            $IMR->Kill (); $IMR->TimedWait (1);
            return 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        test_info("killing $a_srv_name[$index]\n");
        $A_SRV_status = $A_SRV[$index]->WaitKill ($a_srv[$index]->ProcessStartWaitInterval());
        if ($A_SRV_status != 0) {
            print STDERR "ERROR: Airplane Server returned $A_SRV_status\n";
            $ACT->Kill (); $ACT->TimedWait (1);
            $IMR->Kill (); $IMR->TimedWait (1);
            return 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        test_info("starting client for $a_srv_name[$index]\n");
        # Should cause the activator to spawn another server.
        $A_CLI_status = $A_CLI[$index]->Spawn ();
        if ($A_CLI_status != 0) {
            print STDERR "ERROR: Airplane Client 2 ($index) failed to spawn returning $A_CLI_status\n";
            $ACT->Kill (); $ACT->TimedWait (1);
            $IMR->Kill (); $IMR->TimedWait (1);
            return 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        test_info("killing client for $a_srv_name[$index]\n");
        # Should cause the activator to spawn another server.
        $A_CLI_status = $A_CLI[$index]->WaitKill ($a_cli[$index]->ProcessStartWaitInterval());
        if ($A_CLI_status != 0) {
            print STDERR "ERROR: Airplane Client 2 ($index) returned $A_CLI_status\n";
            $ACT->Kill (); $ACT->TimedWait (1);
            $IMR->Kill (); $IMR->TimedWait (1);
            return 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        # Shutdown airplane_server
        $TI->Arguments ("-ORBInitRef ImplRepoService=file://$ti_imriorfile ".
                        "shutdown $a_srv_name[$index]");
        test_info("starting TI=" . $TI->CommandLine() . "\n");
        $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
        if ($TI_status != 0) {
            print STDERR "ERROR: tao_imr shutdown 2 ($index) returned $TI_status\n";
            $ACT->Kill (); $ACT->TimedWait (1);
            $IMR->Kill (); $IMR->TimedWait (1);
            return 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        test_info("killing IMR=" . $IMR->CommandLine() . "\n");
        $IMR_status = $IMR->TerminateWaitKill ($imr->ProcessStopWaitInterval());
        if ($IMR_status != 0) {
            print STDERR "ERROR: ImR returned $IMR_status\n";
            $ACT->Kill (); $ACT->TimedWait (1);
            return 1;
        }
    }

    # Unlink so that we can wait on them again to know the server started.
    $imr->DeleteFile ($imriorfile);
    $act->DeleteFile ($imriorfile);
    $ti->DeleteFile ($imriorfile);

    for ($index = 0; $index < $num_srvr; ++$index) {
        $a_srv[$index]->DeleteFile ($imriorfile);
    }

    print "Restarting Implementation Repository.\n";
    $IMR->Arguments ("$imr_arguments ");
    test_info("restarting IMR=" . $IMR->CommandLine() . "\n");
    $IMR_status = $IMR->Spawn ();
    if ($IMR_status != 0) {
        print STDERR "ERROR: ImR Service returned $IMR_status\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        return 1;
    }
    if ($imr->WaitForFileTimed ($imriorfile,
                                $imr->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$imr_imriorfile>\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($imr->GetFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot retrieve file <$imr_imriorfile>\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($act->PutFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot set file <$act_imriorfile>\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($ti->PutFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot set file <$ti_imriorfile>\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        if ($a_srv[$index]->PutFile ($imriorfile) == -1) {
            print STDERR "ERROR: cannot set file <$a_srv_imriorfile[$index]>\n";
            $ACT->Kill (); $ACT->TimedWait (1);
            $IMR->Kill (); $IMR->TimedWait (1);
            return 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        test_info("starting client for $a_srv_name[$index]\n");
        # Should cause the activator to spawn another server.
        $A_CLI_status = $A_CLI[$index]->Spawn ();
        if ($A_CLI_status != 0) {
            print STDERR "ERROR: Airplane Client 3 ($index) failed to spawn returning $A_CLI_status\n";
            $status = 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        test_info("killing client for $a_srv_name[$index]\n");
        # Should cause the activator to spawn another server.
        $A_CLI_status = $A_CLI[$index]->WaitKill ($a_cli[$index]->ProcessStartWaitInterval()+5);
        if ($A_CLI_status != 0) {
            print STDERR "ERROR: Airplane Client 3 ($index) returned $A_CLI_status\n";
            $status = 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        # Shutdown airplane_server
        $TI->Arguments ("-ORBInitRef ImplRepoService=file://$ti_imriorfile ".
                        "shutdown $a_srv_name[$index]");
        test_info("starting TI=" . $TI->CommandLine() . "\n");
        $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
        if ($TI_status != 0) {
            print STDERR "ERROR: tao_imr shutdown 3 returned $TI_status\n";
            $status = 1;
        }
    }

    for ($index = 0; $index < $num_srvr; ++$index) {
        test_info("killing ACT\n");
        $ACT_status = $ACT->TerminateWaitKill ($act->ProcessStopWaitInterval());
        if ($ACT_status != 0) {
            print STDERR "ERROR: Activator returned $ACT_status\n";
            $status = 1;
        }
    }

    test_info("killing IMR\n");
    $IMR_status = $IMR->TerminateWaitKill ($imr->ProcessStopWaitInterval());
    if ($IMR_status != 0) {
        print STDERR "ERROR: ImR returned $IMR_status\n";
        $status = 1;
    }

    if (!defined($backing_store)) {
        # startup ImR with "-e" flag to ensure cleanup of registry entries
        $IMR->Arguments ("$imr_arguments -e");
        test_info("starting IMR=" . $IMR->CommandLine() . "\n");
        $IMR_status = $IMR->Spawn ();
        if ($IMR_status != 0) {
            print STDERR "ERROR: ImR Service returned $IMR_status\n";
            return 1;
        }

        $IMR->TimedWait ($imr->ProcessStartWaitInterval());

        test_info("killing IMR\n");
        $IMR_status = $IMR->TerminateWaitKill ($imr->ProcessStopWaitInterval());
        if ($IMR_status != 0) {
            print STDERR "ERROR: ImR returned $IMR_status\n";
            $status = 1;
        }
    }
    elsif ($backing_store_flag eq "-y") {
        cleanup_replication($backing_store);
    }
    else {
        $imr->DeleteFile ($backing_store);
    }
    $imr->DeleteFile ($imriorfile);
    $act->DeleteFile ($imriorfile);
    $ti->DeleteFile ($imriorfile);
    $act->DeleteFile ($actiorfile);
    for ($index = 0; $index < $num_srvr; ++$index) {
        $imr->DeleteFile ($airplaneiorfile[$index]);
        $a_srv[$index]->DeleteFile ($imriorfile);
        $a_srv[$index]->DeleteFile ($airplaneiorfile[$index]);
        $a_cli[$index]->DeleteFile ($airplaneiorfile[$index]);
        $p_srv[$index]->DeleteFile ($P_SRV_cmd[$index]);
    }

    return $status;
}

###############################################################################

sub both_ir_test
{
    my $status = 0;

    my $imr_imriorfile = $imr->LocalFile ($imriorfile);
    my $act_imriorfile = $act->LocalFile ($imriorfile);
    my $ti_imriorfile = $ti->LocalFile ($imriorfile);
    my $a_srv_imriorfile = $a_srv[0]->LocalFile ($imriorfile);
    my $n_srv_imriorfile = $n_srv->LocalFile ($imriorfile);
    my $act_actiorfile = $act->LocalFile ($actiorfile);
    my $a_srv_airplaneiorfile = $a_srv[0]->LocalFile ($airplaneiorfile[0]);
    my $n_srv_nesteaiorfile = $n_srv->LocalFile ($nesteaiorfile);
    my $n_cli_nesteaiorfile = $n_cli->LocalFile ($nesteaiorfile);
    $imr->DeleteFile ($imriorfile);
    $act->DeleteFile ($imriorfile);
    $ti->DeleteFile ($imriorfile);
    $a_srv[0]->DeleteFile ($imriorfile);
    $n_srv->DeleteFile ($imriorfile);
    $act->DeleteFile ($actiorfile);
    $a_srv[0]->DeleteFile ($airplaneiorfile[0]);
    $a_cli[0]->DeleteFile ($airplaneiorfile[0]);
    $n_srv->DeleteFile ($nesteaiorfile);
    $n_cli->DeleteFile ($nesteaiorfile);

    $IMR->Arguments ("-d $test_debug_level -t 10 -o $imr_imriorfile $refstyle");
    $IMR_status = $IMR->Spawn ();
    if ($IMR_status != 0) {
        print STDERR "ERROR: ImR Service returned $IMR_status\n";
        return 1;
    }
    if ($imr->WaitForFileTimed ($imriorfile,
                                $imr->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$imr_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($imr->GetFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot retrieve file <$imr_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($act->PutFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot set file <$act_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($ti->PutFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot set file <$ti_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($a_srv[0]->PutFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot set file <$a_srv_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($n_srv->PutFile ($imriorfile) == -1) {
        print STDERR "ERROR: cannot set file <$n_srv_imriorfile>\n";
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    $ACT->Arguments ("-e 16384 -o $act_actiorfile ".
                     "-ORBInitRef ImplRepoService=file://$act_imriorfile ".
                     "$refstyle -d $test_debug_level");
    $ACT_status = $ACT->Spawn ();
    if ($ACT_status != 0) {
        print STDERR "ERROR: ImR Activator returned $ACT_status\n";
        return 1;
    }
    if ($act->WaitForFileTimed ($actiorfile,$act->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$act_actiorfile>\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    ## Note : It's crucial NOT to write out an IOR file when the activator
    ## starts the server, or at least to write out a different file name
    ## than the IOR files we're using for the clients. Otherwise a client
    ## may attempt to use a partially written file.
    # No need to specify imr_initref or -orbuseimr 1 for servers spawned by activator
    $TI->Arguments ("-ORBInitRef ImplRepoService=file://$ti_imriorfile ".
                    "add nestea_server -c \"$imr_N_SRV_cmd $refstyle\"");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr returned $TI_status\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    # No need to specify imr_initref or -orbuseimr 1 for servers spawned by activator
    $TI->Arguments ("-ORBInitRef ImplRepoService=file://$ti_imriorfile ".
                    "add $a_srv_name[0] -c \"$imr_A_SRV_cmd[0] $refstyle -s $a_srv_name[0]\"");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr returned $TI_status\n";
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    $N_SRV->Arguments (" -o $n_srv_nesteaiorfile -ORBUseIMR 1 ".
                       "-ORBInitRef ImplRepoService=file://$n_srv_imriorfile ".
                       "$refstyle ".
                       "-ORBDebugLevel $srv_debug_level");
    $N_SRV_status = $N_SRV->Spawn ();
    if ($N_SRV_status != 0) {
        print STDERR "ERROR: Nestea Server returned $N_SRV_status\n";
        $N_SRV->Kill (); $N_SRV->TimedWait (1);
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($n_srv->WaitForFileTimed ($nesteaiorfile,$n_srv->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$n_srv_nesteaiorfile>\n";
        $N_SRV->Kill (); $N_SRV->TimedWait (1);
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($n_srv->GetFile ($nesteaiorfile) == -1) {
        print STDERR "ERROR: cannot retrieve file <$n_srv_nesteaiorfile>\n";
        $N_SRV->Kill (); $N_SRV->TimedWait (1);
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($n_cli->PutFile ($nesteaiorfile) == -1) {
        print STDERR "ERROR: cannot set file <$n_cli_nesteaiorfile>\n";
        $N_SRV->Kill (); $N_SRV->TimedWait (1);
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    $A_SRV[0]->Arguments (
      " -o $a_srv_airplaneiorfile -ORBUseIMR 1 ".
      "-ORBInitRef ImplRepoService=file://$n_srv_imriorfile ".
      "$refstyle -ORBDebugLevel $srv_debug_level -s $a_srv_name[0]");
    $A_SRV_status = $A_SRV[0]->Spawn ();
    if ($A_SRV_status != 0) {
        print STDERR "ERROR: Airplane Server returned $A_SRV_status\n";
        kill_then_timed_wait(\@A_SRV, 1);
        $N_SRV->Kill (); $N_SRV->TimedWait (1);
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($a_srv[0]->WaitForFileTimed ($airplaneiorfile[0],$a_srv[0]->ProcessStartWaitInterval()) == -1) {
        print STDERR "ERROR: cannot find file <$a_srv_airplaneiorfile>\n";
        kill_then_timed_wait(\@A_SRV, 1);
        $N_SRV->Kill (); $N_SRV->TimedWait (1);
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($a_srv[0]->GetFile ($airplaneiorfile[0]) == -1) {
        print STDERR "ERROR: cannot retrieve file <$a_srv_airplaneiorfile>\n";
        kill_then_timed_wait(\@A_SRV, 1);
        $N_SRV->Kill (); $N_SRV->TimedWait (1);
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }
    if ($a_cli[0]->PutFile ($airplaneiorfile[0]) == -1) {
        print STDERR "ERROR: cannot set file <$a_cli_airplaneiorfile[$index]>\n";
        kill_then_timed_wait(\@A_SRV, 1);
        $N_SRV->Kill (); $N_SRV->TimedWait (1);
        $ACT->Kill (); $ACT->TimedWait (1);
        $IMR->Kill (); $IMR->TimedWait (1);
        return 1;
    }

    my @a_clients;
    my @n_clients;

    for (1 .. 5) {
       push @a_clients, &create_acli();
       push @n_clients, &create_ncli();
    }

    print "\n## Spawning multiple simultaneous clients with both servers running.\n";
    map $_->Spawn(), @a_clients;
    map $_->Spawn(), @n_clients;
    map $_->WaitKill($a_cli[0]->ProcessStopWaitInterval()), @a_clients;
    map $_->WaitKill($n_cli->ProcessStopWaitInterval()), @n_clients;

    $TI->Arguments ("-ORBInitRef ImplRepoService=file://$n_srv_imriorfile ".
                    "shutdown nestea_server");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr returned $TI_status\n";
        $status = 1;
    }

    $TI->Arguments ("-ORBInitRef ImplRepoService=file://$n_srv_imriorfile ".
                    "shutdown $a_srv_name[0]");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr returned $TI_status\n";
        $status = 1;
    }

    $A_SRV_status = $A_SRV[0]->WaitKill ($a_srv[0]->ProcessStopWaitInterval());
    if ($A_SRV_status != 0) {
        print STDERR "ERROR: Airplane Server returned $A_SRV_status\n";
        $status = 1;
    }
    $N_SRV_status = $N_SRV->WaitKill ($n_srv->ProcessStopWaitInterval());
    if ($N_SRV_status != 0) {
        print STDERR "ERROR: Nestea Server returned $N_SRV_status\n";
        $status = 1;
    }

    print "\n\n\n\n## Spawning multiple simultaneous clients with no servers running.\n";

    map $_->Spawn(), @a_clients;
    map $_->Spawn(), @n_clients;
    map $_->WaitKill($a_cli[0]->ProcessStopWaitInterval()), @a_clients;
    map $_->WaitKill($n_cli->ProcessStopWaitInterval()), @n_clients;

    $TI->Arguments ("-ORBInitRef ImplRepoService=file://$n_srv_imriorfile ".
                    "shutdown nestea_server");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr returned $TI_status\n";
        $status = 1;
    }

    $TI->Arguments ("-ORBInitRef ImplRepoService=file://$n_srv_imriorfile ".
                    "shutdown $a_srv_name[0]");
    $TI_status = $TI->SpawnWaitKill ($ti->ProcessStartWaitInterval());
    if ($TI_status != 0) {
        print STDERR "ERROR: tao_imr returned $TI_status\n";
        $status = 1;
    }

    $ACT_status = $ACT->TerminateWaitKill ($act->ProcessStopWaitInterval());
    if ($ACT_status != 0) {
        print STDERR "ERROR: Activator returned $ACT_status\n";
        $status = 1;
    }

    $IMR_status = $IMR->TerminateWaitKill ($imr->ProcessStopWaitInterval());
    if ($IMR_status != 0) {
        print STDERR "ERROR: ImR returned $IMR_status\n";
        $status = 1;
    }

    $imr->DeleteFile ($imriorfile);
    $act->DeleteFile ($imriorfile);
    $ti->DeleteFile ($imriorfile);
    $a_srv[0]->DeleteFile ($imriorfile);
    $n_srv->DeleteFile ($imriorfile);
    $act->DeleteFile ($actiorfile);
    $a_srv[0]->DeleteFile ($airplaneiorfile[0]);
    $a_cli[0]->DeleteFile ($airplaneiorfile[0]);
    $n_srv->DeleteFile ($nesteaiorfile);
    $n_cli->DeleteFile ($nesteaiorfile);

    return $status;
}

###############################################################################
###############################################################################

# Parse the arguments

my $ret = 0;
my $test_num = 0;

my @tests = ("airplane", "airplane_ir", "nestea", "nestea_ir",
             "both_ir", "persistent_ir", "persistent_ir_hash",
             "persistent_ir_shared");
my @nt_tests = ("nt_service_ir", "persistent_ir_registry");

my $i;
if ($all_tests) {
    push(@ARGV, @tests);
}

if ($#ARGV == -1) {
    $ret = both_ir_test();
}

my $append = "";
for ($i = 0; $i <= $#ARGV; $i++) {
    if ($ARGV[$i] eq "-h" || $ARGV[$i] eq "-?") {
        print "run_test [options] test\n";
        print "\n";
        print "options            \n";
        print "    -debug         -- set debug_level to 10\n";
        print "    -tdebug        -- set the tests debug level to 10\n";
        print "    -all           -- causes all tests to run (except nt_service_ir and\n";
        print "                      persistent_ir_registry)\n";
        print "    -servers       -- run tests with more than 1 server and client\n";
        print "    -replica       -- run tests with more than 1 server and client interacting\n";
        print "                      with replicated ImR Locators\n";
        print "test               -- Runs a specific test:\n";
        my $indent = "                         ";
        print "$indent";
        my $count = 0;
        my @all_tests = @tests;
        push(@all_tests, @nt_tests);
        foreach my $test (@all_tests) {
          if (++$count > 1) {
              print ",$append";
          }
          print "$test";
          $append = "";
          if ($count % 3 == 0) {
              $append = "\n$indent";
          }
        }
        print "\n";
        exit 1;
    }
    elsif ($ARGV[$i] eq "airplane") {
        $ret = airplane_test ();
    }
    elsif ($ARGV[$i] eq "airplane_ir") {
        $ret = airplane_ir_test ();
    }
    elsif ($ARGV[$i] eq "nt_service_ir") {
        $ret = nt_service_test ();
    }
    elsif ($ARGV[$i] eq "nestea") {
        $ret = nestea_test ();
    }
    elsif ($ARGV[$i] eq "nestea_ir") {
        $ret = nestea_ir_test ();
    }
    elsif ($ARGV[$i] eq "both_ir") {
        $ret = both_ir_test ();
    }
    elsif ($ARGV[$i] eq "persistent_ir") {
        $ret = persistent_ir_test ("-x");
    }
    elsif ($ARGV[$i] eq "persistent_ir_hash") {
        $ret = persistent_ir_test ("-p");
    }
    elsif ($ARGV[$i] eq "persistent_ir_registry") {
        $ret = persistent_ir_test ("-r");
    }
    elsif ($ARGV[$i] eq "persistent_ir_shared") {
        $ret = persistent_ir_test ("-y");
    }
    elsif ($ARGV[$i] eq "perclient") {
        $ret = perclient();
    }
    elsif ($ARGV[$i] eq "shutdown") {
        $ret = shutdown_repo();
    }
    elsif ($ARGV[$i] !~ /^-/) {
        print "run_test: Unknown Option: ".$ARGV[$i]."\n";
    }
    if ($ret != 0) {
        last;
    }
}

exit $ret;
