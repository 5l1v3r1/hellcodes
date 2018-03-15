#!/usr/bin/perl

use 5.10.0;

use strict;
use warnings;

no warnings 'experimental';

use LWP::UserAgent;
use LWP::ConnCache;

use HTTP::Request;
use HTTP::Cookies;
use HTTP::Response;
use HTTP::Headers;

# Settings
my $template_file = 'src/templates/test_php.tpl';
my $public_web_directory = '/var/www/html';
my $url_base = "http://127.0.0.1/";
my $php_file = "functest.php";
my $output_file = "php_test.log";

my $function = $ARGV[0] or die("Usage: perl $0 <FUNCTION> <FUZZ_LIST>\n");
my $fuzz_list_file = $ARGV[1] or die("Usage: perl $0 <FUNCTION> <FUZZ_LIST>\n");

my $browser = LWP::UserAgent->new();
$browser->protocols_allowed( [qw( http https ftp ftps )] );
$browser->requests_redirectable(['GET', 'POST', 'HEAD', 'OPTIONS']);
$browser->conn_cache(LWP::ConnCache->new());

if($function) {
   my @template_code = ();
   
   if($function !~ /{{ARG1}}/i) {
       die("The function call must contain at least the '{{ARG1}}' keyword somewhere .\n");
   } else {
       $function =~ s/{{ARG([1-9])}}/\$_GET\["arg$1"\]/gi;
   }
   
   my $efunction = $function;

   $efunction =~ s/"/\\\"/gi;
   $efunction =~ s/\$/\\\$/gi;

   my $replacements_data = {
      FUNCTION => $function,
      EFUNCTION => $efunction,
      OUTPUT_FILE => $output_file,
   };
   
   if(!-f $template_file) {
      die"[-] Template file not found .\n";
   } else {
      my @content = readFile($template_file);
      
      foreach my $line (@content) {
          chomp $line;
          if($line =~ /{{.*\}}/) {
             
             foreach my $replacement_var (keys %{ $replacements_data }) {
                my $replacement_value = $replacements_data->{$replacement_var};

                if($line =~ /{{$replacement_var}}/i) {
                   $line =~ s/{{$replacement_var}}/$replacement_value/gi;
                }
             }
          }
          push(@template_code, $line);
      }
      
      if(!-d $public_web_directory) {
         # Ask user for it
      }
      
      if(-f "$public_web_directory/$output_file") {
          system("sudo rm -rf $public_web_directory/$output_file ; sudo touch $public_web_directory/$output_file ; sudo chmod 777 $public_web_directory/$output_file");
      }
      
      writeFile("$public_web_directory/$php_file", @content);
   }

   if(-f $fuzz_list_file) {
        my @content = readFile($fuzz_list_file);
        my @urls = ();
      
        foreach my $line (@content) {
            # Format: value1,value2,.. => function($arg1 = value1, $arg2 = value2, ...) 
             my $value = '';
             my $argnum = 1;
             chomp $line;
         
            if($line =~ /^(?:[^,]+),.*$/i) {
                foreach my $item_value (split(',', $line)) {
                    if($item_value) {
                        $value .= "arg$argnum=$item_value&";
                        $argnum++;
                    }
                }
            } else {
                my $item_value = $line; 
                if($item_value) {
                    $value = "arg$argnum=$item_value&";
                }
            }
            push(@urls, $url_base . $php_file . '?' . $value) if($value);
        }
        
        if(0+@urls) {
            my @requests = ();
            my @responses = ();
            foreach my $url (@urls) {
                push(@requests, HTTP::Request->new('GET', $url));
            }
            
            print "   [INFO] Sending " . (0+@requests) . " requests ...\n";
            foreach my $request (@requests) {
                print "   [REQUEST] " . $request->uri . "\n";
                push(@responses, $browser->request($request));
            }
            
            if(-f "$public_web_directory/$output_file") {
                my $output = join("\n", readFile("$public_web_directory/$output_file", 1));
                print "\n\nResults :\n$output\n";
            } else {
                print "[-] Couldn't read the output file .\n";
            }
        }
   } else {
      print "[-] The fuzz file provided was not found on this system .\n";
   }
} else {
   print "[-] Invalid value given for the function .\n";
}

sub readFile {
   my ( $file ) =  @_;
   
   my @content = ();
   my @final_content = ();

   open(FILE, "<", $file) or die("[-] Couldn't read file : $file\n");
   @content = <FILE>;
   close FILE;

   foreach my $line (@content) {
      chomp $line;
      push(@final_content, $line);
   }
   
   return @final_content;
}

sub writeFile {
    my ( $file, @content ) = @_;
    open(FILE, ">", $file) or die("[-] Couldn't open file : " . $file . " (" . $@ . ')');

    foreach my $line (@content) {
        print FILE $line . "\n" if($line);
    }
    close FILE;
}
