#!/usr/bin/perl -w

use IO::Socket;
use Socket;
use Sys::Hostname;
use Switch;
use Cwd qw(cwd);

$root_dir = "./";
$nums = [
    [ "", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX" ],
    [ "", "X", "XX", "XXX", "XL", "L", "LX", "LXX", "LXXX", "XC" ],
    [ "", "C", "CC", "CCC", "CD", "D", "DC", "DCC", "DCCC", "CM" ],
    [ "", "M", "MM", "MMM" ]
];

%nums = (
    "I" => 1,
    "V" => 5,
    "X" => 10,
    "L" => 50,
    "C" => 100,
    "D" => 500,
    "M" => 1000
);

$SIG{INT} = sub

{
    close($server);
    exit;
};

my $port = 6666;

$server = IO::Socket::INET->new(Type => SOCK_STREAM,
    LocalPort                        => $port,
    Listen                           => SOMAXCONN,
    Reuse                            => 1) or die "$!\n";

sub readmsg($) {
    my $client = shift;
    $_ = <$client>;
    m/cmd=(\d+)\s+length=(\d+)\n(.*)/s;
    my $cmd = $1;
    my $length = $2;
    my $msg = $3;
    my $d = length $msg;
    while ($d < $length) {
        my $m = <$client>;
        $msg .= $m;
        $d = length $msg;
    }
    chomp($msg);
    return ($cmd, $msg);
}

sub sendmsg($$$) {
    my ($client, $cmd, $msg) = @_;
    $msg .= "\n";
    my $length = length $msg;
    print $client "cmd=$cmd length=$length\n$msg";
}

sub a2r($) {
    my $a = shift;
    my $r = "";
    my $i = 0;
    $r = $nums->[$i++][($a % 10, $a = int($a / 10))[0] ] . $r for 0 .. 3;
    return $r;
}

sub r2a($) {
    my $r = shift;
    my $l = length($r);
    my $a = $nums{substr($r, $l - 1, 1)};
    my $pred = $a;
    my $num;
    $a += (($num = $nums{substr($r, $_, 1)}) * (($num < $pred) ? -1 : 1), $pred = $num)[0] for reverse
        0 .. ($l - 2);
    return $a;
}

NEWCLIENT:
while ($client = $server->accept()) {
    $client->autoflush(1);
    while (1) {
        ($cmd, $msg) = readmsg $client;
        switch($cmd)
        {

            case 1
            {
                print "Подключился клиент\n";
                sendmsg($client, 2, "Сервер подтвердил подключение");
            }

            case 3
            {
                print "Отключился клиент\n";
                sendmsg($client, 4, "Сервер подтвердил отключение");
                close($client);
                next NEWCLIENT;
            }

            case 5
            {
                print "Клиент подтвердил получение данных: $msg\n";
            }

            case 6
            {
                print "Клиент запросил данные об адресах\n";
                $client_ip = $client->peerhost;
                $client_port = $client->peerport;
                $server_ip = inet_ntoa(inet_aton(hostname()));;
                $server_port = $port;
                print "ip --> $client_ip, port --> $client_port, server_ip --> $server_ip, server_port --> $server_port";
                sendmsg($client, 7, "client $client_ip:$client_port\nserver $server_ip:$server_port");
            }

            case 8
            {
                print "Клиент запросил дату и время\n";
                ($sec, $min, $h, $d, $m, $y) = localtime;
                $y += 1900;
                $m++;
                sendmsg($client, 9, "\[$d.$m.$y $h:$min:$sec\]");
            }

            case 10
            {
                print "Клиент передает файл без изменений. Путь: $root_dir$msg\n";
                $path = "$root_dir$msg";
                $ss = 0;
                print "final path $path";
            }

            case 11
            {
                print "Клиент передает файл с переводом из арабской в римскую. Путь:$root_dir$msg\n";
                $path = $root_dir . $msg;
                $ss = 1;
            }

            case 12
            {
                print "Клиент передает файл с переводом из римской в арабскую. Путь:$root_dir$msg\n";
                $path = $root_dir . $msg;
                $ss = 2;
            }

            case 13
            {
                print "Прием файла от клиента\n";
                $msg =~ s/(\b\d+\b)/a2r($1)/ge if ($ss == 1);
                $msg =~ s/\b((?i)M{0,3}(D?C{0,3}|C[DM])(L?X{0,3}|X[LC])(I[VX]|V?I{0,3}))\b/r2a($1)/ge if ($ss == 2);
                open FILE, ">$path";
                print FILE $msg;
                close FILE;
                sendmsg($client, 14, "Файл принят");
            }

            case 15
            {
                print "Передача файла $root_dir$msg клиенту\n";
                open FILE, "<$root_dir$msg";
                $msg = "";
                $msg .= $_ while (<FILE>);
                close FILE;
                sendmsg($client, 16, $msg);
            }

            case 16
            {
                print "Получена комнада на чтение файлов в каталоге\n";
                $currentPath = cwd;
                opendir my($dh), $currentPath or die "Couldn't open dir $currentPath: $!";
                my @files = <*>; 
                my $strFiles = "";

                foreach $file (@files) {
                    $strFiles = "$strFiles\n$file";
                }

                print "Просмотрены файлы\n $strFiles\n";
                closedir $dh;
                sendmsg($client, 17, $strFiles);
            }

            else
            {
                print "Неизвестная комманда\n";
            }
        }
    }
}
