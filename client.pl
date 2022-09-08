#!/usr/bin/perl

use IO::Socket;
use Switch;

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

$SIG{INT} = sub
{
    sendmsg($client, 3, "");
    ($cmd, $msg) = readmsg($client);
    print "$msg\n";
    $client->close;
    print "\n";
    exit;
};

my $host = "localhost";
my $port = 6666;

$client = IO::Socket::INET->new(
    PeerAddr => $host,
    PeerPort => $port,
    Proto    => 'tcp',
    Type     => SOCK_STREAM)
    or die "$!\n";

$client->autoflush(1);

sendmsg($client, 1, "");
($cmd, $msg) = readmsg($client);
print "$msg\n";

for (;;) {

    print <<MENU
1 - узнать адреса клиента и сервера.
2 - узнать текущее время.
3 - Отправить файл без изменений
4 - Отправить файл с переводом чисел из арабской в римскую системы счисления
5 - Отправить файл с переводом чисел из римской в арабскую системы счисления
6 - Скачать файл с сервера
7 - файлы на сервере
<Ctrl>+<C> - Выход
Введите номер команды:
MENU
    ;
    chomp($cmd = <STDIN>);
    switch($cmd)
    {
        case 1 {
            sendmsg($client, 6, "");
            ($cmd, $_) = readmsg($client);
            m/client (.+)\nserver (.+)/s;
            print "Адрес клиента: $1\nАдрес сервера: $2\n";
            sendmsg($client, 5, "Адрес узнал");
        }

        case 2
        {
            sendmsg($client, 8, "");
            ($cmd, $_) = readmsg($client);
            m/(\d+)\.(\d+)\.(\d+) (\d+):(\d+):(\d+)/s;
            print "Текущие дата и время:\nГод: $3\nМесяц: $2\nДень: $1\nЧас: $4\nМинута:
			$5\nСекунда: $6\n";
            sendmsg($client, 5, "Время узнал");
        }

        case 3
        {
            print "Отправка файла серверу\nВведите путь к файлу на клиенте: ";
            chomp($file = <STDIN>);
            print "Введите путь к файлу на сервере: ";
            chomp($serv_file = <STDIN>);
            sendmsg($client, 10, $serv_file);

            print "Client path --> $file";
            print "Server path --> $serv_file";

            open FILE, "< $file" or (warn "$!\n", next);
            $msg = "";
            $msg .= $_ while (<FILE>);
            close FILE;
            sendmsg($client, 13, $msg);
            ($cmd, $msg) = readmsg($client);
            print "Ответ от сервера: $msg\n";
        }

        case 4
        {
            print "Отправка файла серверу\nВведите путь к файлу на клиенте: ";
            chomp($file = <STDIN>);
            print "Введите путь к файлу на сервере: ";
            chomp($serv_file = <STDIN>);
            sendmsg($client, 11, $serv_file);
            open FILE, "<$file" or (warn "$!\n", next);
            $msg = "";
            $msg .= $_ while (<FILE>);
            close FILE;
            sendmsg($client, 13, $msg);
            ($cmd, $msg) = readmsg($client);
            print "Ответ от сервера: $msg\n";
        }

        case 5
        {
            print "Отправка файла серверу\nВведите путь к файлу на клиенте: ";
            chomp($file = <STDIN>);
            print "Введите путь к файлу на сервере: ";
            chomp($serv_file = <STDIN>);
            sendmsg($client, 12, $serv_file);
            open FILE, "<$file" or (warn "$!\n", next);
            $msg = "";
            $msg .= $_ while (<FILE>);
            close FILE;
            sendmsg($client, 13, $msg);
            ($cmd, $msg) = readmsg($client);
            print "Ответ от сервера: $msg\n";
        }

        case 6
        {
            print "Прием файла с сервера\nВведите путь к файлу на сервере: ";
            chomp($serv_file = <STDIN>);
            print "Введите путь к файлу на клиенте: ";
            chomp($file = <STDIN>);
            sendmsg($client, 15, $serv_file);
            ($cmd, $msg) = readmsg($client);
            open FILE, ">$file";
            print FILE $msg;
            close FILE;
            sendmsg($client, 5, "Файл принят");
        }
        case 7
        {
            print "Файлы с сервера\n";
            print "---------------------------\n";
            sendmsg($client, 16, "");
            ($cmd, $msg) = readmsg($client);
            print $msg;
            print "\n\n---------------------------\n";
            print "\n\n\n\n";
        }
        else
        {
            print "Неизвестная комманда\n";
        }
    }
}
