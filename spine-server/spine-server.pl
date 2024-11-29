#!/usr/bin/env perl

use v5.36;

use utf8;

no strict 'vars';

use Socket;
use JSON;
use Encode qw{decode};

use File::Slurp;
use Data::Dumper;

sub perform_doc_request($doc) {
  my $out = `perldoc -T -f $doc`;

  my $enc = encode_json {'output' => $out};

  print NEW_SOCKET "$enc";
}

sub perform_eval_request($to_eval) {
  my $out;
  my $res;
  do {
    local *STDOUT;
    open STDOUT, ">>", \$out;

    $res = eval "$to_eval";
  };

  ## Process errors:
  # $@ is the error value of the eval
  my $enc;
  if ($@) {
    chomp $@;
    $enc = encode_json {'error' => "$@"};
  } elsif ($out) {
    my $out_utf8 = decode('UTF-8', $out);
    $enc = encode_json {'output' => "$out_utf8", 'result' => "$res"};
  } else {
    $enc = encode_json {'result' => "$res"};
  }

  print NEW_SOCKET "$enc";
}


sub perform_load_request($fname) {
  my $script = read_file(glob($fname), {binmode => ':utf8'});
  print $script;
  perform_eval_request $script;
}


sub perform_request($req) {
  my $request = decode_json $req;

  exists $request->{'eval'} and
    perform_eval_request $request->{'eval'};

  exists $request->{'load'} and
    perform_load_request $request->{'load'};

  exists $request->{'doc'} and
    perform_doc_request $request->{'doc'};
}

sub start_server {
  my $port = shift || 43659;
  my $proto = getprotobyname('tcp');
  my $server = "localhost";

  socket(SOCKET, PF_INET, SOCK_STREAM, $proto)
    or die "Can't open socket $!\n";
  setsockopt(SOCKET, SOL_SOCKET, SO_REUSEADDR, 1)
    or die "Can't set socket option to SO_REUSEADDR $!\n";

  bind( SOCKET, pack_sockaddr_in($port, inet_aton($server)))
    or die "Can't bind to port $port! \n";

  listen(SOCKET, 5) or die "listen: $!";
  print "SERVER started on port $port\n";

  my $client_addr;
  while ($client_addr = accept(NEW_SOCKET, SOCKET)) {
    NEW_SOCKET->autoflush();
    while (my $line = <NEW_SOCKET>) {
      perform_request "$line";
      print NEW_SOCKET (eval "$line");
    }
    close NEW_SOCKET;
  }

}



sub main {
  start_server;
}


main;
