#!/usr/bin/perl
use strict;


sub fUsage
{
    print( "Simple wrapper for Windows' notepad.exe to\n"
         . "  1st  edit Unix files with LF endings with notepad.exe\n"
         . "  2nd  enable the usage of notepad.exe inside\n"
         . "       all versions of \"git for Windows\"\n\n"
         . "Start with " . $0 . " FileName\n\n"
         . "Enable it inside \"git for Windows\" with\n"
         . "    git config --global core.editor " . $0 . "\n"
         . "if " . $0 . " is always accessible on this system.\n"
         );
    exit( __LINE__ % 100 / 2 );  # Just end with error code ne 0.
}


sub fFilWritArrRepl {
    my $pFilNam = shift or die "File name parameter not supplied";
    my $pLinArr = shift or die "Pointer to line array not supplied";
    my $pFind   = shift or die "Find string not supplied";
    my $pRepl   = shift or die "Replace string not supplied";
    my $lLin = "";
    open( my $lFilHdl, ">", $pFilNam ) or die "Could not open File for writing " . $pFilNam;
    for my $lLin ( @$pLinArr ) {
        $lLin =~ s/$pFind/$pRepl/;
        # print( $lFilHdl $lLin );
    }
    print( $lFilHdl @$pLinArr );
    close( $lFilHdl );
}


sub fFilIntoArr {
    my $pFilNam = shift or die "File name parameter not supplied";
    my $pLinArr = shift or die "Pointer to line array not supplied";
    my $lLin = "";
    open( my $lFilHdl, "<", $pFilNam ) or die "Could not open File for reading " . $pFilNam;
    while( my $lLin = <$lFilHdl> ) {
        push( @$pLinArr, $lLin );
    }
    close( $lFilHdl );
}


sub fLsHexDump {
    my $pFilNam = shift or die "File name parameter not supplied";
    if ( defined( $ENV{ 'DEBUG_NOTPAD' } ) ) {
        system( "ls -l " . $pFilNam );
        system( "hexdump -C " . $pFilNam );
    }
}


if ( -1 == $#ARGV ) {
    fUsage();
}

my ( $lFilNam, $lCmd, $lRet, $lTextArr ) = ( "", "", 0, [] );

for my $lElem ( @ARGV ) {
    print( $lElem . "\n" );
    if ( "" eq $lFilNam && -f $lElem ) {
        $lFilNam = $lElem;
    }
}

if ( "" eq $lFilNam ) {
    print( "No valid file name supplied\n" );
    exit( __LINE__ % 100 / 2 );  # Just end with error code ne 0.
}

fLsHexDump( $lFilNam );

# Read file content into memory
fFilIntoArr( $lFilNam, $lTextArr );

# # Write file content with CRLF
fFilWritArrRepl( $lFilNam, $lTextArr, "\n", "\r\n" );
delete @$lTextArr[0 .. $#$lTextArr];

fLsHexDump( $lFilNam );

# Start Notepad with file
if ( "linux" ne $^O ) {
    $lCmd = "notepad " . $lFilNam;
} else {
    # $lCmd = "echo \"Do nothing, this is linux.\"";
    $lCmd = "vi " . $lFilNam;
}
print( $lCmd . "\n" );
my $lRet = system( $lCmd );
if ( $lRet ) {
    print( "notepad.exe returned with error value " . $lRet . "\n" );
    exit( $lRet );
}

fLsHexDump( $lFilNam );

# 2015-09-12 - did not work under msys, only under Linux.
# Read file content from Notepad into memory and replace CRLF
fFilIntoArr( $lFilNam, $lTextArr );

# Write file content with LF, stripped from CRLF.
fFilWritArrRepl( $lFilNam, $lTextArr, "\r\n", "\n" );

fLsHexDump( $lFilNam );

# system( "perl -de 0" );

exit( $lRet );
