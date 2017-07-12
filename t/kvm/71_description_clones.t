use warnings;
use strict;

use Data::Dumper;
use Test::More;
use Test::SQL::Data;

use lib 't/lib';
use Test::Ravada;

my $test = Test::SQL::Data->new(config => 't/etc/sql.conf');

use_ok('Ravada');
my $FILE_CONFIG = 't/etc/ravada.conf';
my $RVD_FRONT= rvd_front($test->connector, $FILE_CONFIG);

my %ARG_CREATE_DOM = (
      KVM => [ id_iso => 1 ]
);

my @VMS = reverse keys %ARG_CREATE_DOM;
init($test->connector);
my $USER = create_user("foo","bar");
my $DISPLAY_IP = '99.1.99.1';

our $TIMEOUT_SHUTDOWN = 10;

################################################################
sub test_create_domain {
    my $vm_name = shift;

    my $vm = rvd_back->search_vm($vm_name);
    ok($vm,"I can't find VM $vm_name") or return;

    my $name = new_domain_name();

    if (!$ARG_CREATE_DOM{$vm_name}) {
        diag("VM $vm_name should be defined at \%ARG_CREATE_DOM");
        return;
    }
    my @arg_create = @{$ARG_CREATE_DOM{$vm_name}};

    my $domain;
    eval { $domain = $vm->create_domain(name => $name
                    , id_owner => $USER->id
                    , @{$ARG_CREATE_DOM{$vm_name}})
    };

    ok($domain,"No domain $name created with ".ref($vm)." ".($@ or '')) or return;
    ok($domain->name
        && $domain->name eq $name,"Expecting domain name '$name' , got "
        .($domain->name or '<UNDEF>')
        ." for VM $vm_name"
    );

    return $domain;
}

sub test_files_base {
    my $domain = shift;
    my $n_expected = shift;

    my @files = $domain->list_files_base();

    ok(scalar @files == $n_expected,"Expecting $n_expected files base , got "
            .scalar @files);
    return;
}

sub touch_mtime {
    for my $disk (@_) {

        my @stat0 = stat($disk);

        sleep 2;
        utime(undef, undef, $disk) or die "$! $disk";
        my @stat1 = stat($disk);

        die "$stat0[9] not before $stat1[9] for $disk" if $stat0[0] && $stat0[9] >= $stat1[9];
    }

}

sub test_devices_clone {
    my $vm_name = shift;
    my $domain = shift;

    my @volumes = $domain->list_volumes();
    ok(scalar(@volumes),"[$vm_name] domain ".$domain->name
        ." Expecting at least 1 volume cloned "
        ." got ".scalar(@volumes)) or exit;
    for my $disk (@volumes ) {
        ok(-e $disk,"Checking volume ".Dumper($disk)." exists") or exit;
    }
}

sub test_display {
    my ($vm_name, $domain) = @_;

    my $display;
    $domain->start($USER) if !$domain->is_active;
    eval { $display = $domain->display($USER)};
    is($@,'');
    ok($display,"Expecting a display URI, got '".($display or '')."'") or return;

    my ($ip) = $display =~ m{^\w+://(.*):\d+} if defined $display;

    ok($ip,"Expecting an IP , got ''") or return;

    ok($ip ne '127.0.0.1', "[$vm_name] Expecting IP no '127.0.0.1', got '$ip'") or exit;


    # only test this for Void, it will fail on real VMs
    return if $vm_name ne 'Void';

    $Ravada::CONFIG->{display_ip} = $DISPLAY_IP;
    eval { $display = $domain->display($USER) };
    is($@,'');
    ($ip) = $display =~ m{^\w+://(.*):\d+};

    my $expected_ip =  Ravada::display_ip();
    ok($expected_ip,"[$vm_name] Expecting display_ip '$DISPLAY_IP' , got none in config "
        .Dumper($Ravada::CONFIG)) or exit;

    ok($ip eq $expected_ip,"Expecting display IP '$expected_ip', got '$ip'");

}

sub test_prepare_base_active {
    my $vm_name = shift;

    my $domain = test_create_domain($vm_name);

    ok(!$domain->is_base,"Domain ".$domain->name." should not be base") or return;
    eval { $domain->start($USER) if !$domain->is_active() };
    ok(!$@,$@) or exit;
    eval { $domain->resume($USER)  if $domain->is_paused()  };
    ok(!$@,$@);

    ok($domain->is_active,"[$vm_name] Domain ".$domain->name." should be active") or return;
    ok(!$domain->is_paused,"[$vm_name] Domain ".$domain->name." should not be paused") or return;

    eval{ $domain->prepare_base($USER) };
    ok(!$@,"[$vm_name] Prepare base, expecting error='', got '$@'") or exit;

    ok($domain->is_active,"[$vm_name] Domain ".$domain->name." should be active") or return;
    ok(!$domain->is_paused,"[$vm_name] Domain ".$domain->name
                            ." should not be paused after prepare base") or return;
}

sub test_prepare_base {
    my $vm_name = shift;
    my $domain = shift;
    
    my $vm = rvd_back->search_vm($vm_name);
    ok($vm,"I can't find VM $vm_name") or return;
    
    test_files_base($domain,0);
    $domain->shutdown_now($USER)    if $domain->is_active();

    eval { $domain->prepare_base( $USER) };
    ok(!$@, $@);
    ok($domain->is_base);
    is($domain->is_active(),0);

    eval { $domain->prepare_base( $USER) };
    my $description = "This is a description test";
    add_description($domain, $description);

    ok($@ && $@ =~ /already/i,"[$vm_name] Don't prepare if already "
        ."prepared and file haven't changed "
        .". Error: ".($@ or '<UNDEF>'));
    ok($domain->is_base);

    test_files_base($domain,1);

    my @disk = $domain->disk_device();
    $domain->shutdown(user => $USER)    if $domain->is_active;

    touch_mtime(@disk);

    eval { $domain->prepare_base( $USER) };
    is($@,'');
    ok($domain->is_base);

    my $name_clone = new_domain_name();

    my $domain_clone;

    eval { $domain_clone = $vm->create_domain(
        name => $name_clone
        ,id_owner => $USER->id
        ,id_base => $domain->id
        ,vm => $vm_name
        ,description => $domain->description
        );
    };
    ok(!$@,"Clone domain, expecting error='' , got='".($@ or '')."'") or exit;
    ok($domain_clone,"Trying to clone from ".$domain->name." to $name_clone");
    test_devices_clone($vm_name, $domain_clone);
    test_display($vm_name, $domain_clone);

    #ok($domain_clone->id_base && $domain_clone->id_base == $domain->id
    #    ,"[$vm_name] Expecting id_base=".$domain->id." got ".($domain_clone->id_base or '<UNDEF>')) or exit;

    my $domain_clone2 = $RVD_FRONT->search_clone(
         id_base => $domain->id,
        id_owner => $USER->id
    );
    ok($domain_clone2,"Searching for clone id_base=".$domain->id." user=".$USER->id
        ." expecting domain , got nothing "
        ." ".Dumper($domain_clone)) or exit;

    if ($domain_clone2) {
        ok( $domain_clone2->name eq $domain_clone->name
        ,"Expecting clone name ".$domain_clone->name." , got:".$domain_clone2->name
        );

        ok($domain_clone2->id eq $domain_clone->id
        ,"Expecting clone id ".$domain_clone->id." , got:".$domain_clone2->id
        );
    }

    touch_mtime(@disk);
    eval { $domain->prepare_base($USER) };
    ok($@ && $@ =~ /has \d+ clones/i
        ,"[$vm_name] Don't prepare if there are clones ".($@ or '<UNDEF>'));
    ok($domain->is_base);

    $domain_clone->remove($USER);

    touch_mtime(@disk);
    eval { $domain->prepare_base($USER) };

    ok(!$@,"[$vm_name] Error preparing base after clone removed :'".($@ or '')."'");
    ok($domain->is_base,"[$vm_name] Expecting domain is_base=1 , got :".$domain->is_base);

    $domain->is_base(0);
    ok(!$domain->is_base,"[$vm_name] Expecting domain is_base=0 , got :".$domain->is_base);

    $domain->is_base(1);
    ok($domain->is_base,"[$vm_name] Expecting domain is_base=1 , got :".$domain->is_base);

}

sub add_description {
    my $domain = shift;
    my $description = shift;
    my $name = $domain->name;

    $domain->description($description);
}

sub test_description {
    my $vm_name = shift;

    diag("Testing add description $vm_name");
    my $vm =rvd_back->search_vm($vm_name);
    my $domain = test_create_domain($vm_name);

    test_prepare_base($vm_name, $domain);
    test_prepare_base_active($vm_name);

    my $description = "This is a description test";
    #add_description($domain, $description);

    my $domain2 = rvd_back->search_domain($domain->name);
    ok ($domain2->get_description eq $description, "I can't find description");
}

sub test_remove_base {
    my $vm_name = shift;

    my $domain = test_create_domain($vm_name);
    ok($domain,"Expecting domain, got NONE") or return;

    my @files0 = $domain->list_files_base();
    ok(!scalar @files0,"Expecting no files base, got ".Dumper(\@files0)) or return;

    $domain->prepare_base($USER);
    ok($domain->is_base,"Domain ".$domain->name." should be base") or return;

    my @files = $domain->list_files_base();
    ok(scalar @files,"Expecting files base, got ".Dumper(\@files)) or return;

    $domain->remove_base($USER);
    ok(!$domain->is_base,"Domain ".$domain->name." should be base") or return;

    for my $file (@files) {
        ok(!-e $file,"Expecting file base '$file' removed" );
    }

    my @files_deleted = $domain->list_files_base();
    is(scalar @files_deleted,0);

    my $sth = $test->dbh->prepare(
        "SELECT count(*) FROM file_base_images"
        ." WHERE id_domain = ?"
    );
    $sth->execute($domain->id);
    my ($count) = $sth->fetchrow;
    $sth->finish;

    is($count,0,"[$vm_name] Count files base after remove base domain");

}

#######################################################

#######################################################

clean();

my $vm_name = 'KVM';
my $vm = rvd_back->search_vm($vm_name);
my $description = 'This is a description test';

SKIP: {

    my $msg = "SKIPPED: No virtual managers found";
    if ($vm && $vm_name =~ /kvm/i && $>) {
        $msg = "SKIPPED: Test must run as root";
        $vm = undef;
    }
    skip($msg,10)   if !$vm;

    test_description($vm_name);
    test_remove_base($vm_name);
}

clean();

done_testing();